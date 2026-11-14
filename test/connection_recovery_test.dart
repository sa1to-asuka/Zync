import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/connection_recovery_controller.dart';

/// 可控时钟：sleep 推进虚拟时间，避免单测真的等 30 秒。
class _Clock {
  DateTime _t = DateTime(2026, 1, 1, 12);
  DateTime now() => _t;
  Future<void> sleep(Duration d) async {
    _t = _t.add(d);
  }
}

Future<void> _waitPhase(
  ConnectionRecoveryController c,
  RecoveryPhase phase,
) async {
  for (var i = 0; i < 500; i++) {
    if (c.phase == phase) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('控制器没有进入 $phase，当前是 ${c.phase}');
}

void main() {
  test('退避表在超出长度后停在最后一档', () {
    expect(recoveryBackoffFor(0), const Duration(seconds: 2));
    expect(recoveryBackoffFor(3), const Duration(seconds: 15));
    expect(recoveryBackoffFor(99), const Duration(seconds: 30));
    expect(
      recoveryBackoffFor(1, schedule: const [7]),
      const Duration(seconds: 7),
    );
    expect(recoveryBackoffFor(0, schedule: const []), Duration.zero);
  });

  test('第一次失败后重试成功，并恢复会话', () async {
    final clock = _Clock();
    var attempts = 0;
    var restored = false;

    final c = ConnectionRecoveryController(
      reconnect: () async {
        attempts++;
        if (attempts == 1) throw StateError('第一次失败');
      },
      restoreSession: () async => restored = true,
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [1, 2],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await _waitPhase(c, RecoveryPhase.connected);

    expect(attempts, 2);
    expect(restored, isTrue);
    expect(c.attempt, 2);
    expect(c.lastError, isEmpty);
  });

  test('端口探活失败时不发起握手，直接进入下一次退避', () async {
    final clock = _Clock();
    var probes = 0;
    var attempts = 0;

    final c = ConnectionRecoveryController(
      reconnect: () async => attempts++,
      restoreSession: () async {},
      probe: () async => ++probes > 1,
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [1],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await _waitPhase(c, RecoveryPhase.connected);

    expect(probes, 2);
    expect(attempts, 1, reason: '第一次探活失败不应进入握手');
  });

  test('超出总预算后放弃，不会无限重试', () async {
    final clock = _Clock();
    var attempts = 0;

    final c = ConnectionRecoveryController(
      reconnect: () async {
        attempts++;
        throw StateError('相机不在线');
      },
      restoreSession: () async {},
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [1],
      totalBudget: const Duration(seconds: 3),
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await _waitPhase(c, RecoveryPhase.exhausted);

    expect(attempts, lessThan(10));
    expect(c.lastError, isNotEmpty);
  });

  test('通道重复报错只触发一次恢复事务', () async {
    final clock = _Clock();
    var attempts = 0;
    final gate = Completer<void>();

    final c = ConnectionRecoveryController(
      reconnect: () async {
        attempts++;
        await gate.future;
      },
      restoreSession: () async {},
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [1],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    c.notifyUnexpectedDisconnect();
    c.notifyUnexpectedDisconnect();
    expect(c.isRecovering, isTrue);

    gate.complete();
    await _waitPhase(c, RecoveryPhase.connected);
    expect(attempts, 1);
  });

  test('cancel 会作废在途恢复，不再走恢复会话', () async {
    final clock = _Clock();
    final gate = Completer<void>();
    var restored = false;

    final c = ConnectionRecoveryController(
      reconnect: () async => gate.future,
      restoreSession: () async => restored = true,
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [1],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await Future<void>.delayed(Duration.zero);
    c.cancel();
    gate.complete();
    await Future<void>.delayed(Duration.zero);

    expect(restored, isFalse);
    expect(c.phase, RecoveryPhase.idle);
  });

  test('恢复成功后 acknowledge 回到空闲态', () async {
    final clock = _Clock();
    final c = ConnectionRecoveryController(
      reconnect: () async {},
      restoreSession: () async {},
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [0],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await _waitPhase(c, RecoveryPhase.connected);
    c.acknowledge();
    expect(c.phase, RecoveryPhase.idle);
  });

  test('恢复会话抛错不影响已建立的连接', () async {
    final clock = _Clock();
    final c = ConnectionRecoveryController(
      reconnect: () async {},
      restoreSession: () async {
        throw StateError('取景重启失败');
      },
      sleep: clock.sleep,
      now: clock.now,
      backoffSeconds: const [0],
    );
    addTearDown(c.dispose);

    c.notifyUnexpectedDisconnect();
    await _waitPhase(c, RecoveryPhase.connected);
    expect(c.lastError, contains('取景'));
  });
}
