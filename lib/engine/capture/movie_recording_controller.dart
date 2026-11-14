import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/ptp_opcodes.dart';

/// 相机当前的拍摄模式（拍照 / 录像）。
///
/// [lockedByPhysicalLever] 是 Z 30 这类带实体拍照-录像拨杆的机型特有的状态：
/// App 改不了 `0xD1A6`，只能提示用户去拨杆。
enum CameraCaptureMode { photo, video, lockedByPhysicalLever }

/// 录像生命周期。
enum MovieRecordingPhase {
  idle,
  starting,
  recording,
  stopping,

  /// 已发停止指令，正在等相机把文件写完（0xC108）。
  finalizing,
}

/// 录像控制所需的相机能力。
///
/// 单独抽一个接口而不是塞进 `CameraDriver`：录制只有部分机型支持，
/// 而且这样单测不必实现整个驱动。
abstract class MovieRecordingDriver {
  bool get isConnected;

  /// 相机是否声明支持 `0x920A / 0x920B`。
  bool get supportsMovieRecording;

  /// 相机事件码广播（`0xC108 MovieRecordComplete` 等）。
  Stream<int> get eventCodes;

  Future<void> startMovieRecording();
  Future<void> stopMovieRecording();

  /// `0xD1A6`：0=拍照 1=录像；读不到返回 null。
  Future<int?> readLiveViewSelector();
  Future<void> setLiveViewSelector(int value);

  /// `0xD0A4`：禁录原因位掩码；读不到返回 null。
  Future<int?> readMovieRecProhibition();
}

/// `0xD0A4` 位掩码的语义。
class MovieProhibition {
  const MovieProhibition(this.mask);

  final int mask;

  bool get isBlocked => mask != 0;

  bool isSet(int bit) => (mask & (1 << bit)) != 0;

  /// Z 30 顶部拨杆不在视频档：这是唯一需要改变交互而不是报错的原因。
  bool get needsPhysicalLever => isSet(13);

  /// 展开成位序号列表，供 UI 逐条提示。
  List<int> get reasons {
    final out = <int>[];
    for (var bit = 0; bit < 32; bit++) {
      if (isSet(bit)) out.add(bit);
    }
    return out;
  }
}

/// 录像控制状态机。
///
/// 与 [LiveViewController] 的分工：取景帧仍在取景控制器里跑，这里只消费
/// 帧头里的 `isRecording` 标志做**机身侧录像键**的同步（见 [syncRecordingFlag]）。
class MovieRecordingController extends ChangeNotifier {
  MovieRecordingController({
    required this.driver,
    this.finalizeTimeout = const Duration(seconds: 8),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MovieRecordingDriver driver;
  final Duration finalizeTimeout;
  final DateTime Function() _now;

  CameraCaptureMode _mode = CameraCaptureMode.photo;
  CameraCaptureMode get mode => _mode;

  MovieRecordingPhase _phase = MovieRecordingPhase.idle;
  MovieRecordingPhase get phase => _phase;

  bool get isRecording =>
      _phase == MovieRecordingPhase.recording ||
      _phase == MovieRecordingPhase.finalizing;

  MovieProhibition get prohibition => MovieProhibition(_prohibitionMask);
  int _prohibitionMask = 0;

  String? _lastError;
  String? get lastError => _lastError;

  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Timer? _ticker;
  StreamSubscription<int>? _eventSub;
  Completer<void>? _finalizeGate;
  Timer? _finalizeTimer;

  /// 订阅 `0xC108`：封盘完成后才允许下一次停止/开始。
  void attach() {
    _eventSub ??=
        driver.eventCodes.listen(_onEventCode, onError: (_) {});
  }

  void detach() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  void _onEventCode(int code) {
    if (code == PtpOpCodes.eventNikonMovieRecComplete) {
      _completeFinalize();
    }
  }

  /// 读取机身当前模式与禁录原因。
  ///
  /// Z 30 这类带实体拨杆的机型：`0xD1A6` 由拨杆决定，App 写不进去。
  /// 所以**读**才是主路径，写只是「有软开关的机型」上的锦上添花。
  Future<void> refresh() async {
    final selector = await driver.readLiveViewSelector();
    final mask = await driver.readMovieRecProhibition();
    _prohibitionMask = mask ?? 0;
    _selectorReadable = selector != null;

    if (selector != null) {
      // 选择器是权威：读得到就完全按它来。
      _mode = selector == 1
          ? CameraCaptureMode.video
          : (prohibition.needsPhysicalLever
              ? CameraCaptureMode.lockedByPhysicalLever
              : CameraCaptureMode.photo);
    } else if (prohibition.needsPhysicalLever) {
      _mode = CameraCaptureMode.lockedByPhysicalLever;
    } else if (_mode == CameraCaptureMode.lockedByPhysicalLever) {
      // 拨杆已经离开受限位置：不要让界面一直卡在「拨杆不对」。
      _mode = CameraCaptureMode.photo;
    }
    notifyListeners();
  }

  /// 是否读得到 `0xD1A6`。读不到时不能凭它锁死界面。
  bool _selectorReadable = true;
  bool get selectorReadable => _selectorReadable;

  /// 尝试切换拍照/录像模式。
  ///
  /// 返回 false 表示切不过去。注意：**写入失败不一定代表失败**——
  /// Z 30 上 `0xD1A6` 是只读的，拨杆到位后写入仍会被拒，此时应以回读结果为准。
  Future<bool> switchMode(CameraCaptureMode target) async {
    if (target == CameraCaptureMode.lockedByPhysicalLever) return false;
    if (_mode == target) return true;

    try {
      await driver.setLiveViewSelector(
          target == CameraCaptureMode.video ? 1 : 0);
      _mode = target;
      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = '$e';
    }

    // 写入被拒：回读一次，看是不是拨杆已经切过去了。
    await refresh();
    if (_mode == target) {
      _lastError = null;
      return true;
    }

    // 连选择器都读不到（部分固件不支持 0xD1A6）：不要卡死界面，
    // 先让用户进到录像界面，真正不能录时由 0xD0A4 给出具体原因。
    if (!_selectorReadable) {
      _mode = target;
      notifyListeners();
      return true;
    }

    if (_mode != CameraCaptureMode.lockedByPhysicalLever) {
      _mode = CameraCaptureMode.lockedByPhysicalLever;
      notifyListeners();
    }
    return false;
  }

  /// 取景帧头里的 `isRecording`：机身按键开始/停止录像时同步 UI。
  ///
  /// 帧头比指令晚一两帧才反映状态，所以刚进入录制的前几秒不采信
  /// 「false」——否则刚点下开始就会被下一帧打回待机。
  void syncRecordingFlag(bool recording) {
    if (recording) {
      if (_phase == MovieRecordingPhase.recording) return;
      // 我们自己正在启停时，帧头的旧状态没有参考价值。
      if (_phase == MovieRecordingPhase.starting ||
          _phase == MovieRecordingPhase.stopping ||
          _phase == MovieRecordingPhase.finalizing) {
        return;
      }
      _phase = MovieRecordingPhase.recording;
      _startedAt ??= _now();
      _startTicker();
      notifyListeners();
      return;
    }

    if (_phase != MovieRecordingPhase.recording) return;
    final started = _startedAt;
    if (started != null &&
        _now().difference(started) < const Duration(seconds: 3)) {
      return;
    }
    _phase = MovieRecordingPhase.idle;
    _stopTicker(keepElapsed: true);
    notifyListeners();
  }

  Future<bool> startRecording() async {
    if (_phase != MovieRecordingPhase.idle) return false;
    // 选择器读得到时才敢断定「拨杆不在录像档」；读不到就实际试一次，
    // 由相机给出的响应码来判断，不要把用户挡在门外。
    if (_mode == CameraCaptureMode.lockedByPhysicalLever &&
        _selectorReadable) {
      _lastError = 'physicalLever';
      notifyListeners();
      return false;
    }

    _phase = MovieRecordingPhase.starting;
    _lastError = null;
    notifyListeners();

    try {
      await driver.startMovieRecording();
      _phase = MovieRecordingPhase.recording;
      _startedAt = _now();
      _elapsed = Duration.zero;
      _startTicker();
      notifyListeners();
      return true;
    } catch (e) {
      _phase = MovieRecordingPhase.idle;
      _lastError = '$e';
      notifyListeners();
      // 启动失败最常见的两个原因：拨杆不在视频档、卡不可写。
      await refresh();
      return false;
    }
  }

  Future<bool> stopRecording() async {
    if (_phase != MovieRecordingPhase.recording) return false;

    _phase = MovieRecordingPhase.stopping;
    notifyListeners();

    try {
      await driver.stopMovieRecording();
    } catch (e) {
      // 停止指令失败时相机可能已经自己停了，仍按封盘流程走，
      // 否则 UI 会永远停在「录制中」。
      _lastError = '$e';
    }
    _stopTicker(keepElapsed: true);

    _phase = MovieRecordingPhase.finalizing;
    _finalizeGate = Completer<void>();
    _finalizeTimer = Timer(finalizeTimeout, _completeFinalize);
    notifyListeners();

    try {
      await _finalizeGate!.future;
    } catch (_) {}
    return true;
  }

  void _completeFinalize() {
    _finalizeTimer?.cancel();
    _finalizeTimer = null;
    final gate = _finalizeGate;
    _finalizeGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();

    if (_phase == MovieRecordingPhase.finalizing ||
        _phase == MovieRecordingPhase.stopping) {
      _phase = MovieRecordingPhase.idle;
      _startedAt = null;
      notifyListeners();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started == null) return;
      _elapsed = _now().difference(started);
      notifyListeners();
    });
  }

  void _stopTicker({bool keepElapsed = false}) {
    _ticker?.cancel();
    _ticker = null;
    if (!keepElapsed) _elapsed = Duration.zero;
  }

  String get elapsedLabel {
    final d = _elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    detach();
    _stopTicker();
    _finalizeTimer?.cancel();
    final gate = _finalizeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
    super.dispose();
  }
}
