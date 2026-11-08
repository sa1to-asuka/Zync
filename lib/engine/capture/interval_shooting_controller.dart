import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../protocol/camera_driver.dart';

enum IntervalShootingState { idle, waiting, capturing, paused, done, failed }

class IntervalShootingConfig {
  final Duration interval;
  final int shotCount; // 0 表示不限张数
  final Duration startDelay;
  final bool stopOnError;
  final bool keepLiveView;

  const IntervalShootingConfig({
    this.interval = const Duration(seconds: 5),
    this.shotCount = 10,
    this.startDelay = Duration.zero,
    this.stopOnError = true,
    this.keepLiveView = false,
  });
}

/// 间隔拍摄（定时拍摄）控制器。
///
/// 快门完全复用 [CaptureController] 的既有流程：停取景 → `0x100E` →
/// 等新对象 → 恢复取景，因此「边拍边传」对间隔拍摄同样生效。
class IntervalShootingController extends ChangeNotifier {
  IntervalShootingController({
    required Future<CaptureOutcome> Function() capture,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  })  : _capture = capture,
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final Future<CaptureOutcome> Function() _capture;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  IntervalShootingState _state = IntervalShootingState.idle;
  IntervalShootingConfig? _config;
  int _attempts = 0;
  int _confirmed = 0;
  DateTime? _nextShotAt;
  CaptureOutcome? _lastOutcome;
  IntervalHint _hint = IntervalHint.none;

  bool _running = false;
  bool _paused = false;
  Future<void>? _loop;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  IntervalShootingState get state => _state;
  IntervalShootingConfig? get config => _config;
  int get shotsAttempted => _attempts;
  int get shotsConfirmed => _confirmed;
  DateTime? get nextShotAt => _nextShotAt;
  CaptureOutcome? get lastOutcome => _lastOutcome;
  IntervalHint get hint => _hint;
  bool get isActive =>
      _state == IntervalShootingState.waiting ||
      _state == IntervalShootingState.capturing ||
      _state == IntervalShootingState.paused;

  Duration get remaining {
    final next = _nextShotAt;
    if (next == null) return Duration.zero;
    final diff = next.difference(_now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Future<void> start(IntervalShootingConfig config) async {
    if (_disposed || isActive) return;
    _config = config;
    _attempts = 0;
    _confirmed = 0;
    _lastOutcome = null;
    _hint = IntervalHint.none;
    _running = true;
    _paused = false;
    _nextShotAt = _now().add(config.startDelay);
    _setState(IntervalShootingState.waiting);
    _loop = _run(config);
  }

  void pause() {
    if (!isActive || _paused) return;
    _paused = true;
    _setState(IntervalShootingState.paused);
  }

  void resume() {
    if (_state != IntervalShootingState.paused) return;
    _paused = false;
    _setState(IntervalShootingState.waiting);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _paused = false;
    final loop = _loop;
    _loop = null;
    _nextShotAt = null;
    if (loop != null) {
      await loop.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    if (!_disposed && _state != IntervalShootingState.failed) {
      _setState(IntervalShootingState.idle);
    }
  }

  Future<void> _run(IntervalShootingConfig config) async {
    try {
      if (!await _waitUntil(_nextShotAt!)) {
        _finish();
        return;
      }

      while (_running) {
        if (config.shotCount > 0 && _attempts >= config.shotCount) break;

        _setState(IntervalShootingState.capturing);
        _attempts++;
        CaptureOutcome outcome;
        try {
          outcome = await _capture();
        } catch (_) {
          // 前置条件不满足（未连接等）：按错误处理，不重试。
          _lastOutcome = const CaptureRejected(0x2002);
          _hint = IntervalHint.captureFailed;
          if (config.stopOnError) {
            _fail();
            return;
          }
          outcome = const CaptureRejected(0x2002);
        }
        _lastOutcome = outcome;

        if (outcome is CaptureConfirmed) {
          _confirmed++;
        } else if (outcome is CaptureUnconfirmed) {
          _hint = IntervalHint.unconfirmed;
        } else if (outcome is CaptureRejected) {
          _hint = IntervalHint.captureFailed;
          if (config.stopOnError) {
            _fail();
            return;
          }
        }

        if (!_running) break;
        if (config.shotCount > 0 && _attempts >= config.shotCount) break;

        _nextShotAt = _now().add(config.interval);
        _setState(IntervalShootingState.waiting);
        if (!await _waitUntil(_nextShotAt!)) break;
      }

      if (_running) {
        _nextShotAt = null;
        _setState(IntervalShootingState.done);
        _running = false;
      } else {
        _finish();
      }
    } catch (_) {
      _fail();
    }
  }

  /// 等待到目标时间；暂停期间原地等待，停止时返回 false。
  Future<bool> _waitUntil(DateTime target) async {
    while (true) {
      if (!_running || _disposed) return false;
      if (_paused) {
        await _sleep(const Duration(milliseconds: 100));
        continue;
      }
      final remaining = target.difference(_now());
      if (remaining <= Duration.zero) return true;
      // 100ms 一片：既能及时响应停止，也让测试里的假时钟推进得够细。
      final slice = remaining < const Duration(milliseconds: 100)
          ? remaining
          : const Duration(milliseconds: 100);
      _notifyThrottled();
      await _sleep(slice);
    }
  }

  void _finish() {
    _nextShotAt = null;
    if (!_disposed) _setState(IntervalShootingState.idle);
  }

  void _fail() {
    _running = false;
    _nextShotAt = null;
    if (!_disposed) _setState(IntervalShootingState.failed);
  }

  void _setState(IntervalShootingState next) {
    if (_state == next) {
      _notifyThrottled();
      return;
    }
    _state = next;
    _notify(force: true);
  }

  /// 倒计时每秒刷新几次就够，没必要每 100ms 重建界面。
  void _notifyThrottled() {
    final now = _now();
    if (now.difference(_lastNotify) < const Duration(milliseconds: 250)) return;
    _notify();
  }

  void _notify({bool force = false}) {
    if (_disposed) return;
    _lastNotify = _now();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    super.dispose();
  }
}

/// 一次间隔序列结束时的提示分类。
enum IntervalHint { none, unconfirmed, captureFailed }
