import 'dart:async';

/// 相机通道的准入控制。
///
/// `PtpIpClient` / `UsbPtpTransport` 都是「同一时刻只有一个事务」的 FIFO 队列，
/// 因此取景循环只要保证「上一帧落地后才发下一帧」就不会把队列撑爆。
/// 真正需要协调的是**独占操作**：释放快门、写设备属性时相机不接受并发的
/// `GetLiveViewImage`，会返回 `0x2019` 或 `0xA00B`。
///
/// 这里不接管传输层，只在驱动之上加一层显式的暂停/恢复与在途计数，
/// 让 `LiveViewController` 不必知道谁在抢相机。
class CameraIoCoordinator {
  final Set<String> _pauseReasons = <String>{};
  Completer<void>? _resumeCompleter;

  int _liveViewInFlight = 0;
  Completer<void>? _idleCompleter;

  /// 任一暂停理由生效时，取景循环必须在发起下一帧前阻塞。
  bool get liveViewPaused => _pauseReasons.isNotEmpty;

  Set<String> get pauseReasons => Set<String>.unmodifiable(_pauseReasons);

  /// 当前是否还有未落地的取景事务。
  bool get hasLiveViewInFlight => _liveViewInFlight > 0;

  /// 暂停取景。多次调用按理由去重，必须与 [resumeLiveView] 成对使用。
  void pauseLiveView(String reason) {
    final wasPaused = liveViewPaused;
    _pauseReasons.add(reason);
    if (!wasPaused) {
      _resumeCompleter = Completer<void>();
    }
  }

  /// 恢复取景；只有全部理由都撤销后才真正恢复。
  void resumeLiveView(String reason) {
    _pauseReasons.remove(reason);
    if (_pauseReasons.isEmpty) {
      final completer = _resumeCompleter;
      _resumeCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  /// 取景循环在每一帧之前 await 这里。未暂停时立即返回。
  Future<void> waitUntilLiveViewResumed() {
    if (_pauseReasons.isEmpty) return Future<void>.value();
    return (_resumeCompleter ??= Completer<void>()).future;
  }

  void liveViewTransactionStarted() {
    _liveViewInFlight++;
  }

  void liveViewTransactionFinished() {
    if (_liveViewInFlight > 0) _liveViewInFlight--;
    if (_liveViewInFlight == 0) {
      final completer = _idleCompleter;
      _idleCompleter = null;
      if (completer != null && !completer.isCompleted) completer.complete();
    }
  }

  /// 在途取景事务全部落地后完成。
  Future<void> get liveViewIdle {
    if (_liveViewInFlight == 0) return Future<void>.value();
    return (_idleCompleter ??= Completer<void>()).future;
  }

  /// 独占执行一段相机操作：暂停取景 → 等在途帧落地 → 执行 → 恢复。
  ///
  /// 无论 [action] 正常返回还是抛异常，暂停状态都会被撤销，
  /// 否则一次写入失败就会让取景永久停摆。
  Future<T> runExclusive<T>(Future<T> Function() action) async {
    const reason = 'exclusive';
    pauseLiveView(reason);
    try {
      await liveViewIdle;
      return await action();
    } finally {
      resumeLiveView(reason);
    }
  }

  /// 全部清空，用于断开连接时复位。
  void reset() {
    _pauseReasons.clear();
    _liveViewInFlight = 0;
    final resume = _resumeCompleter;
    _resumeCompleter = null;
    if (resume != null && !resume.isCompleted) resume.complete();
    final idle = _idleCompleter;
    _idleCompleter = null;
    if (idle != null && !idle.isCompleted) idle.complete();
  }
}
