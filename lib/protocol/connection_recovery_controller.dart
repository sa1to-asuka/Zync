import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'ptp_ip_client.dart';

/// 断线恢复阶段。
enum RecoveryPhase {
  /// 没有在恢复，连接正常或用户已主动断开。
  idle,

  /// 等待网络回来 / 等待退避计时结束。
  waitingForNetwork,

  /// 端口探活中（相机刚被唤醒时 TCP 端口可能还没起来）。
  probing,

  /// 正在重建 PTP/IP 会话。
  reconnecting,

  /// 会话已恢复，正在重新读取能力并重启取景 / 续传队列。
  restoringSession,

  /// 恢复成功。
  connected,

  /// 用尽总预算，放弃自动恢复。
  exhausted,
}

/// 退避梯度（秒）。掉线初期相机多半只是瞬时抖动，快速重试收益最高；
/// 后面拉长到 30 秒，避免在相机真的关机时每 2 秒空转一次。
const List<int> kRecoveryBackoffSeconds = <int>[2, 4, 8, 15, 30];

/// 第 [attempt] 次（0 起）重试前应等待的时长。
Duration recoveryBackoffFor(int attempt, {List<int>? schedule}) {
  final list = schedule ?? kRecoveryBackoffSeconds;
  if (list.isEmpty) return Duration.zero;
  final index = attempt.clamp(0, list.length - 1);
  return Duration(seconds: list[index]);
}

/// 默认总恢复预算：180 秒内没连上就交给用户手动处理。
const Duration kRecoveryTotalBudget = Duration(seconds: 180);

/// 单次连接尝试的上限，超过即判定该次失败并进入下一次退避。
const Duration kRecoveryAttemptTimeout = Duration(seconds: 30);

/// TCP 端口探活：相机休眠唤醒后 15740 端口往往晚几秒才可用，
/// 直接做 PTP/IP 握手会拿到一个看起来很吓人的握手超时。
Future<bool> probeCameraPort(
  String host,
  int port, {
  Duration timeout = const Duration(milliseconds: 600),
}) async {
  try {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

/// 相机掉线后的自动重连状态机。
///
/// 设计要点：
/// - **单飞**：命令通道与事件通道可能同时报错，`notifyUnexpectedDisconnect`
///   用 in-flight 标志合并成同一次恢复事务。
/// - **可取消**：用户点「断开」或 App 退出时 `cancel()`，所有在途等待立刻作废。
/// - **总预算**：超过 [totalBudget] 还没恢复就置为 [RecoveryPhase.exhausted]，
///   把决定权交回用户，而不是无休止地在后台重试耗电。
class ConnectionRecoveryController extends ChangeNotifier {
  ConnectionRecoveryController({
    required Future<void> Function() reconnect,
    required Future<void> Function() restoreSession,
    Future<void> Function()? waitForNetwork,
    Future<bool> Function()? probe,
    this.totalBudget = kRecoveryTotalBudget,
    this.attemptTimeout = kRecoveryAttemptTimeout,
    List<int>? backoffSeconds,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
  })  : _reconnect = reconnect,
        _restoreSession = restoreSession,
        _waitForNetwork = waitForNetwork,
        _probe = probe,
        _backoffSeconds = backoffSeconds ?? kRecoveryBackoffSeconds,
        _sleep = sleep ?? ((d) => Future<void>.delayed(d)),
        _now = now ?? DateTime.now;

  final Future<void> Function() _reconnect;
  final Future<void> Function() _restoreSession;
  final Future<void> Function()? _waitForNetwork;
  final Future<bool> Function()? _probe;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;
  final List<int> _backoffSeconds;
  final Duration totalBudget;
  final Duration attemptTimeout;

  RecoveryPhase _phase = RecoveryPhase.idle;
  RecoveryPhase get phase => _phase;

  int _attempt = 0;
  int get attempt => _attempt;

  String _lastError = '';
  String get lastError => _lastError;

  bool _running = false;
  bool get isRecovering => _running;

  /// 递增令牌：`cancel()` 与新的恢复事务都会让它变化，
  /// 在途计时器醒来后发现令牌不符就直接返回，不会和新事务抢连接。
  int _generation = 0;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  void _setPhase(RecoveryPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    notifyListeners();
  }

  /// 传输层报告被动掉线。重复调用会被合并。
  void notifyUnexpectedDisconnect() {
    if (_running) return;
    unawaited(_run());
  }

  Future<void> _run() async {
    _running = true;
    _attempt = 0;
    _elapsed = Duration.zero;
    _lastError = '';
    final token = ++_generation;
    final startedAt = _now();

    try {
      while (true) {
        if (token != _generation) return;

        _elapsed = _now().difference(startedAt);
        if (_elapsed > totalBudget) {
          _setPhase(RecoveryPhase.exhausted);
          return;
        }

        _setPhase(RecoveryPhase.waitingForNetwork);

        // 网络本身的等待（Android 侧 Wi-Fi 断开会先挂起），只做一次。
        if (_waitForNetwork != null) {
          try {
            await _waitForNetwork();
          } catch (_) {}
          if (token != _generation) return;
        }

        final backoff = recoveryBackoffFor(_attempt, schedule: _backoffSeconds);
        if (backoff > Duration.zero) {
          await _sleep(backoff);
          if (token != _generation) return;
        }

        _attempt++;
        _elapsed = _now().difference(startedAt);

        if (_probe != null) {
          _setPhase(RecoveryPhase.probing);
          final reachable = await _probe();
          if (token != _generation) return;
          if (!reachable) {
            _lastError = '相机端口未就绪';
            if (_elapsed > totalBudget) {
              _setPhase(RecoveryPhase.exhausted);
              return;
            }
            continue;
          }
        }

        _setPhase(RecoveryPhase.reconnecting);
        try {
          await _reconnect().timeout(attemptTimeout);
        } on PtpInitFailException catch (e) {
          // 相机明确拒绝配对身份 (InitFail 1) 或被其他设备占用 (InitFail 2)：
          // 继续重试只会消耗电量并顶死相机会话槽位，立即停止自动重连交由用户处理。
          _lastError = e.message;
          if (token != _generation) return;
          _setPhase(RecoveryPhase.exhausted);
          return;
        } catch (e) {
          _lastError = '$e';
          if (token != _generation) return;
          if (_elapsed > totalBudget) {
            _setPhase(RecoveryPhase.exhausted);
            return;
          }
          continue;
        }
        if (token != _generation) return;

        // 握手成功：清掉之前几次尝试留下的错误，UI 才能显示「已恢复」。
        _lastError = '';
        _setPhase(RecoveryPhase.restoringSession);
        try {
          await _restoreSession();
        } catch (e) {
          // 会话已经建立，恢复取景 / 队列失败不应再触发一次重连。
          _lastError = '$e';
        }
        if (token != _generation) return;

        _setPhase(RecoveryPhase.connected);
        return;
      }
    } finally {
      if (token == _generation) _running = false;
    }
  }

  /// 用户主动断开 / 退出页面：作废所有在途恢复。
  void cancel() {
    if (!_running && _phase == RecoveryPhase.idle) return;
    _generation++;
    _running = false;
    _attempt = 0;
    _elapsed = Duration.zero;
    _setPhase(RecoveryPhase.idle);
  }

  /// 恢复成功后再回到空闲态（保留最后状态供 UI 读一眼）。
  void acknowledge() {
    if (_phase == RecoveryPhase.connected) _setPhase(RecoveryPhase.idle);
  }

  @override
  void dispose() {
    _generation++;
    _running = false;
    super.dispose();
  }
}
