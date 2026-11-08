import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../protocol/camera_driver.dart';
import '../../protocol/ptp_ip_client.dart';
import 'live_view_controller.dart';

enum MfStopReason {
  released,
  stepEnd,
  stepInsufficiency,
  liveViewStopped,
  interrupted,
  timedOut,
  unsupported,
  error,
}

/// 按住连续步进的控制器。
///
/// 与快门的约束正好相反：**手动对焦必须保持取景开启**，所以它不走
/// `LiveViewController.runExclusive`（那条路会发 `0x9202` 关掉取景）。
/// 每步都计入取景在途计数，快门流程会等这一步落地才关闭取景。
class ManualFocusDriveController extends ChangeNotifier {
  ManualFocusDriveController({
    required CameraDriver driver,
    required LiveViewController liveView,
    this.stepsPerTick = 32,
    this.interval = const Duration(milliseconds: 140),
    this.maxHold = const Duration(seconds: 20),
    Future<void> Function(Duration)? sleep,
  })  : _driver = driver,
        _liveView = liveView,
        _sleep = sleep ?? Future<void>.delayed;

  final CameraDriver _driver;
  final LiveViewController _liveView;
  final Future<void> Function(Duration) _sleep;

  final int stepsPerTick;
  final Duration interval;
  final Duration maxHold;

  bool _running = false;
  bool _disposed = false;
  MfDirection? _direction;
  MfStopReason? _lastStopReason;
  Future<void>? _loop;

  bool get isDriving => _running;
  MfDirection? get direction => _direction;
  MfStopReason? get lastStopReason => _lastStopReason;

  bool get canDrive =>
      _driver.isConnected &&
      _driver.supportsManualFocus &&
      _liveView.isRunning;

  Future<void> press(MfDirection direction) async {
    if (_disposed || _running) return;
    if (!canDrive) return;
    _running = true;
    _direction = direction;
    _lastStopReason = null;
    notifyListeners();
    // 不 await：按住期间循环自己跑，松手由 release() 结束。
    _loop = _run(direction);
  }

  Future<void> release() => cancel(reason: MfStopReason.released);

  Future<void> cancel({MfStopReason reason = MfStopReason.interrupted}) async {
    if (!_running) return;
    _running = false;
    final loop = _loop;
    _loop = null;
    if (loop != null) {
      // 等当前这一步落地，避免和随后的快门抢事务。
      await loop.timeout(const Duration(milliseconds: 800), onTimeout: () {});
    }
    try {
      await _driver.cancelFocusDrive();
    } catch (_) {}
    _lastStopReason = reason;
    _direction = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(MfDirection direction) async {
    final startedAt = DateTime.now();
    var reason = MfStopReason.released;

    try {
      while (_running) {
        // 先判暂停：取景被独占操作暂停时状态是 suspended，isRunning 已经为 false，
        // 先查 isRunning 会把「被快门打断」误报成「取景已停止」。
        if (_driver.io.liveViewPaused) {
          reason = MfStopReason.interrupted;
          break;
        }
        if (!_liveView.isRunning) {
          reason = MfStopReason.liveViewStopped;
          break;
        }
        if (DateTime.now().difference(startedAt) >= maxHold) {
          reason = MfStopReason.timedOut;
          break;
        }

        try {
          await _liveView.driveManualFocus(direction, steps: stepsPerTick);
        } on PtpException catch (e) {
          reason = switch (e.responseCode) {
            0x2005 || 0x2006 => MfStopReason.unsupported,
            0xA00C => MfStopReason.stepEnd,
            0xA00E => MfStopReason.stepInsufficiency,
            _ => MfStopReason.error,
          };
          break;
        }
        if (!_running) break;
        await _sleep(interval);
      }
    } finally {
      _running = false;
      _direction = null;
      _lastStopReason = reason;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _running = false;
    super.dispose();
  }
}
