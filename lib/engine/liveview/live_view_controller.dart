import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../protocol/camera_driver.dart';
import '../../protocol/camera_io_coordinator.dart';
import '../../protocol/ptp_ip_client.dart';
import 'live_view_analyzer.dart';
import 'live_view_frame_pipeline.dart';
import 'nikon_live_view_packet.dart';

enum LiveViewState { idle, starting, running, suspended, failed }

/// 取景失败的原因。用枚举而不是文案，交给界面做本地化。
enum LiveViewFailure {
  none,
  unsupported,
  exited, // 相机自行退出了取景（0xA00B）
  deviceBusy,
  disconnected,
  timeout,
  unknown,
}

/// 实时取景控制器。
///
/// 循环里**一次只允许一个未落地的 `0x9203`**：传输层是先进先出队列，
/// 如果不等上一帧返回就继续提交，队列会堆积并且相机可能直接拒绝。
/// 独占操作（快门、写入属性）通过 [runExclusive] 暂停取景并发送 `0x9202`。
class LiveViewController extends ChangeNotifier {
  LiveViewController({
    required CameraDriver driver,
    LiveViewFramePipeline? pipeline,
    LiveViewAnalyzer? analysis,
    Duration frameInterval = const Duration(milliseconds: 33),
    Future<void> Function(Duration)? sleep,
  })  : _driver = driver,
        _pipeline = pipeline ?? LiveViewFramePipeline(),
        _analysis = analysis,
        _frameInterval = frameInterval,
        _sleep = sleep ?? Future<void>.delayed;

  static const String _exclusiveReason = 'exclusive';

  final CameraDriver _driver;
  final LiveViewFramePipeline _pipeline;
  final LiveViewAnalyzer? _analysis;
  Duration _frameInterval;
  final Future<void> Function(Duration) _sleep;

  CameraIoCoordinator get _io => _driver.io;

  LiveViewState _state = LiveViewState.idle;
  LiveViewFailure _failure = LiveViewFailure.none;
  bool _stopRequested = true;
  bool _driverLiveViewOpen = false;
  bool _disposed = false;
  Future<void>? _loopFuture;

  double _fps = 0;
  int _frameWidth = 0;
  int _frameHeight = 0;
  int _consecutiveFailures = 0;
  DateTime? _lastFrameAt;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastSequence = -1;

  LiveViewState get state => _state;
  LiveViewFailure get failure => _failure;
  double get fps => _fps;
  int get frameWidth => _frameWidth;
  int get frameHeight => _frameHeight;
  bool get isRunning => _state == LiveViewState.running;

  // ---- 取景帧头遥测（录像状态 / 音频电平）----
  bool _cameraRecording = false;
  bool _hasTelemetry = false;
  int _audioPeakLeft = 0;
  int _audioPeakRight = 0;
  int _audioCurrentLeft = 0;
  int _audioCurrentRight = 0;
  int _headerOrientation = 0;

  /// 机身侧是否正在录像。在机身上按红色录像键时这里也会立刻反映。
  bool get cameraRecording => _cameraRecording;

  /// 当前固件的帧头是否带可解析遥测（短包机型为 false）。
  bool get hasFrameTelemetry => _hasTelemetry;
  int get audioPeakLeft => _audioPeakLeft;
  int get audioPeakRight => _audioPeakRight;
  int get audioCurrentLeft => _audioCurrentLeft;
  int get audioCurrentRight => _audioCurrentRight;
  int get headerOrientation => _headerOrientation;
  bool get isActive =>
      _state == LiveViewState.running ||
      _state == LiveViewState.starting ||
      _state == LiveViewState.suspended;

  ValueListenable<LiveViewFrame?> get frames => _pipeline.frame;

  LiveViewAnalyzer? get analysis => _analysis;

  /// 设置页改了帧率上限后即时生效；下一帧起按新间隔限速。
  void updateFrameInterval(Duration interval) {
    if (interval <= Duration.zero) return;
    _frameInterval = interval;
  }
  int get droppedFrames => _pipeline.droppedFrames;

  /// 开始取景。已在取景中时是空操作。
  Future<void> start() async {
    if (_disposed) return;
    if (_state == LiveViewState.running || _state == LiveViewState.starting) {
      return;
    }
    if (!_driver.isConnected) {
      _fail(LiveViewFailure.disconnected);
      return;
    }
    if (!_driver.supportsLiveView) {
      _fail(LiveViewFailure.unsupported);
      return;
    }

    _stopRequested = false;
    _consecutiveFailures = 0;
    _setState(LiveViewState.starting);
    try {
      await _driver.startLiveView();
      _driverLiveViewOpen = true;
    } catch (e) {
      _fail(_failureFrom(e));
      return;
    }
    if (_disposed || _stopRequested) {
      await _closeDriverLiveView();
      return;
    }
    _setState(LiveViewState.running);
    _loopFuture = _runLoop();
  }

  /// 序列拍摄（间隔 / 包围 / 焦点堆叠）期间禁止自动重启取景。
  ///
  /// 每张照片都会走一次「退出取景 → 快门 → 恢复」，如果序列本身已经把取景
  /// 关掉了，就不该在每张之后又把它拉起来——否则相机的屏幕会在整个序列里亮着。
  bool _suppressAutoRestart = false;

  void setAutoRestartSuppressed(bool value) {
    _suppressAutoRestart = value;
  }

  /// 停止取景并释放相机。
  Future<void> stop() async {
    _stopRequested = true;
    final loop = _loopFuture;
    _loopFuture = null;
    if (loop != null) {
      // 单帧的 data-in 最长可能卡 12 秒，界面不能被它拖住。
      await loop.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    await _closeDriverLiveView();
    _pipeline.clear();
    _analysis?.clear();
    _fps = 0;
    if (!_disposed && _state != LiveViewState.idle) {
      _setState(LiveViewState.idle);
    }
  }

  /// 强制让相机退出取景。
  ///
  /// [stop] 只在本端认为「取景开着」时才发 `0x9202`；序列拍摄时状态可能与相机
  /// 实际不同步（例如相机自己重启过取景），于是相机屏幕会一直亮着。
  /// 这里无条件发一次，相机本来就已退出时返回的 0xA00B 直接忽略。
  Future<void> forceClose() async {
    await stop();
    _driverLiveViewOpen = false;
    try {
      await _driver.endLiveView(force: true);
    } catch (_) {
      // 0xA00B（不在取景中）是正常情况。
    }
  }

  /// 独占执行一段相机操作：暂停取景 → 等在途帧落地 → 退出取景 → 执行 → 恢复。
  ///
  /// 释放快门和写设备属性时相机不接受并发的取景轮询，必须先退出。
  Future<T> runExclusive<T>(Future<T> Function() action) async {
    final wasRunning = isActive;
    _io.pauseLiveView(_exclusiveReason);
    try {
      await _io.liveViewIdle;
      if (wasRunning) await _closeDriverLiveView();
      return await action();
    } finally {
      if (wasRunning && !_stopRequested && !_disposed && !_suppressAutoRestart) {
        try {
          await _driver.startLiveView();
          _driverLiveViewOpen = true;
        } catch (e) {
          _fail(_failureFrom(e));
        }
      }
      _io.resumeLiveView(_exclusiveReason);
    }
  }

  /// 触控对焦。取景中的相机允许直接改对焦区域，无需退出取景。
  Future<void> focusAt(int x, int y) => _driver.moveAfArea(x, y);

  /// 触发一次自动对焦并等待结果。
  ///
  /// 返回 `0x2001` 表示已合焦，`0xA002` 表示未合焦。
  /// **不走 [runExclusive]**：对焦必须在取景开启时进行。
  Future<int> autoFocus({Duration timeout = const Duration(seconds: 6)}) async {
    if (!isRunning) throw StateError('自动对焦需要实时取景');
    _io.liveViewTransactionStarted();
    try {
      await _driver.afDrive();
    } finally {
      _io.liveViewTransactionFinished();
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      _io.liveViewTransactionStarted();
      int code;
      try {
        code = await _driver.deviceReady();
      } finally {
        _io.liveViewTransactionFinished();
      }
      // 仍在忙就继续等；其余码都是最终结论。
      if (code != 0x2019) return code;
      await _sleep(const Duration(milliseconds: 120));
      if (!isRunning) break;
    }
    return 0x2019;
  }

  /// 手动对焦步进。同样不退出取景——用户需要边看画面边合焦。
  ///
  /// 计入「取景在途事务」，因此 `CaptureController` 的独占流程会等这一步
  /// 落地后才发送 `0x9202`，不会与关闭取景竞争。
  Future<void> driveManualFocus(MfDirection direction, {int steps = 32}) async {
    if (!isRunning) throw StateError('手动对焦需要实时取景');
    _io.liveViewTransactionStarted();
    try {
      await _driver.mfDrive(direction, steps);
    } finally {
      _io.liveViewTransactionFinished();
    }
  }

  Future<void> cancelFocusDrive() => _driver.cancelFocusDrive();

  Future<void> _runLoop() async {
    while (!_stopRequested && !_disposed) {
      if (_io.liveViewPaused) {
        if (_state != LiveViewState.suspended) {
          _setState(LiveViewState.suspended);
        }
        await _io.waitUntilLiveViewResumed();
        if (_stopRequested) break;
        _setState(LiveViewState.running);
        _lastFrameAt = null;
        continue;
      }

      final startedAt = DateTime.now();
      _io.liveViewTransactionStarted();
      try {
        final payload = await _driver.fetchLiveViewFrame();
        final packet = NikonLiveViewPacket.parse(payload);
        final jpeg = packet.jpeg;
        if (jpeg != null) {
          _recordTelemetry(packet);
          _pipeline.offerJpeg(jpeg);
          // 分析是旁路：同步投递、可丢弃，绝不 await，失败也不影响取景。
          _analysis?.offerJpeg(jpeg);
          _onFrameArrived();
        }
        _consecutiveFailures = 0;
      } on PtpException catch (e) {
        if (!await _handleFailure(e)) break;
      } catch (e) {
        if (!await _handleFailure(e)) break;
      } finally {
        _io.liveViewTransactionFinished();
      }

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _frameInterval) {
        await _sleep(_frameInterval - elapsed);
      }
    }
  }

  /// 返回 false 表示循环应终止。
  Future<bool> _handleFailure(Object error) async {
    _consecutiveFailures++;

    if (error is PtpException) {
      switch (error.responseCode) {
        case 0xA00B:
          // 相机已被机身接管，重试没有意义。
          _fail(LiveViewFailure.exited);
          return false;
        case 0x2005:
        case 0x2006:
          _fail(LiveViewFailure.unsupported);
          return false;
        case 0x2019:
          if (_consecutiveFailures > 5) {
            _fail(LiveViewFailure.deviceBusy);
            return false;
          }
          await _sleep(const Duration(milliseconds: 120));
          return true;
      }
    } else if (error is TimeoutException) {
      if (_consecutiveFailures >= 2) {
        _fail(LiveViewFailure.timeout);
        return false;
      }
      await _sleep(const Duration(milliseconds: 500));
      return true;
    }

    if (_consecutiveFailures > 5) {
      _fail(LiveViewFailure.unknown);
      return false;
    }
    await _sleep(const Duration(milliseconds: 300));
    return true;
  }

  void _recordTelemetry(NikonLiveViewPacket packet) {
    _cameraRecording = packet.isRecording;
    _hasTelemetry = packet.hasTelemetry;
    if (!packet.hasTelemetry) return;
    _audioPeakLeft = packet.peakLeft;
    _audioPeakRight = packet.peakRight;
    _audioCurrentLeft = packet.currentLeft;
    _audioCurrentRight = packet.currentRight;
    _headerOrientation = packet.orientation;
  }

  void _onFrameArrived() {
    final now = DateTime.now();
    final previous = _lastFrameAt;
    _lastFrameAt = now;
    if (previous != null) {
      final deltaMs = now.difference(previous).inMilliseconds;
      if (deltaMs > 0) {
        final instant = 1000 / deltaMs;
        _fps = _fps == 0 ? instant : _fps * 0.8 + instant * 0.2;
      }
    }

    final frame = _pipeline.frame.value;
    if (frame != null && frame.sequence != _lastSequence) {
      _lastSequence = frame.sequence;
      _frameWidth = frame.width;
      _frameHeight = frame.height;
    }

    // 帧率只是状态展示，没必要每帧都通知界面重建。
    if (now.difference(_lastNotify).inMilliseconds >= 250) {
      _notify();
    }
  }

  Future<void> _closeDriverLiveView() async {
    if (!_driverLiveViewOpen) return;
    _driverLiveViewOpen = false;
    try {
      await _driver.endLiveView();
    } catch (_) {}
  }

  LiveViewFailure _failureFrom(Object error) {
    if (error is PtpException) {
      switch (error.responseCode) {
        case 0xA00B:
          return LiveViewFailure.exited;
        case 0x2005:
        case 0x2006:
          return LiveViewFailure.unsupported;
        case 0x2019:
          return LiveViewFailure.deviceBusy;
      }
      return LiveViewFailure.unknown;
    }
    if (error is TimeoutException) return LiveViewFailure.timeout;
    if (error is StateError) return LiveViewFailure.disconnected;
    return LiveViewFailure.unknown;
  }

  void _fail(LiveViewFailure failure) {
    _failure = failure;
    _stopRequested = true;
    _pipeline.clear();
    _analysis?.clear();
    _setState(LiveViewState.failed);
  }

  void _setState(LiveViewState next) {
    if (_state == next) return;
    _state = next;
    _notify();
  }

  void _notify() {
    _lastNotify = DateTime.now();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopRequested = true;
    final loop = _loopFuture;
    _loopFuture = null;
    // 不等待循环：data-in 可能仍在传输中，dispose 必须同步返回。
    loop?.whenComplete(() {
      _closeDriverLiveView();
    });
    _pipeline.dispose();
    super.dispose();
  }
}
