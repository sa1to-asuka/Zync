import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/camera_io_coordinator.dart';

void main() {
  group('CameraIoCoordinator', () {
    test('初始状态不暂停、无在途事务', () {
      final io = CameraIoCoordinator();
      expect(io.liveViewPaused, isFalse);
      expect(io.hasLiveViewInFlight, isFalse);
      expect(io.pauseReasons, isEmpty);
    });

    test('暂停后 waitUntilLiveViewResumed 阻塞，恢复后完成', () async {
      final io = CameraIoCoordinator();
      io.pauseLiveView('capture');

      var resumed = false;
      final waiter = io.waitUntilLiveViewResumed().then((_) => resumed = true);

      await Future<void>.delayed(Duration.zero);
      expect(resumed, isFalse);
      expect(io.liveViewPaused, isTrue);

      io.resumeLiveView('capture');
      await waiter;
      expect(resumed, isTrue);
    });

    test('多个暂停理由必须全部撤销才恢复', () async {
      final io = CameraIoCoordinator();
      io.pauseLiveView('capture');
      io.pauseLiveView('settings');

      io.resumeLiveView('capture');
      expect(io.liveViewPaused, isTrue);

      io.resumeLiveView('settings');
      expect(io.liveViewPaused, isFalse);
    });

    test('重复暂停同一理由不会重复计数', () {
      final io = CameraIoCoordinator();
      io.pauseLiveView('capture');
      io.pauseLiveView('capture');
      io.resumeLiveView('capture');
      expect(io.liveViewPaused, isFalse);
    });

    test('撤销未暂停的理由不会破坏其他暂停', () {
      final io = CameraIoCoordinator();
      io.pauseLiveView('settings');
      io.resumeLiveView('capture');
      expect(io.liveViewPaused, isTrue);
    });

    test('liveViewIdle 等待在途事务落地', () async {
      final io = CameraIoCoordinator();
      io.liveViewTransactionStarted();

      var idle = false;
      final waiter = io.liveViewIdle.then((_) => idle = true);

      await Future<void>.delayed(Duration.zero);
      expect(idle, isFalse);

      io.liveViewTransactionFinished();
      await waiter;
      expect(idle, isTrue);
    });

    test('未开始时 liveViewIdle 立即完成', () async {
      final io = CameraIoCoordinator();
      await io.liveViewIdle.timeout(const Duration(milliseconds: 50));
    });

    test('多余的 finished 不会把计数压到负数', () {
      final io = CameraIoCoordinator();
      io.liveViewTransactionFinished();
      io.liveViewTransactionFinished();
      expect(io.hasLiveViewInFlight, isFalse);
    });

    test('runExclusive 暂停取景、等在途帧落地、结束后恢复', () async {
      final io = CameraIoCoordinator();
      io.liveViewTransactionStarted();

      final order = <String>[];
      final future = io.runExclusive(() async {
        order.add('action');
        return 42;
      });

      await Future<void>.delayed(Duration.zero);
      expect(io.liveViewPaused, isTrue);
      expect(order, isEmpty, reason: '必须等在途事务落地后才执行');

      io.liveViewTransactionFinished();
      expect(await future, 42);
      expect(order, ['action']);
      expect(io.liveViewPaused, isFalse);
    });

    test('独占操作抛异常后仍会恢复取景', () async {
      final io = CameraIoCoordinator();

      await expectLater(
        io.runExclusive(() async => throw StateError('boom')),
        throwsStateError,
      );

      expect(io.liveViewPaused, isFalse, reason: '一次失败不能把取景永久停掉');
    });

    test('reset 清空全部状态并唤醒等待者', () async {
      final io = CameraIoCoordinator();
      io.pauseLiveView('capture');
      io.liveViewTransactionStarted();

      final resumed = io.waitUntilLiveViewResumed();
      final idle = io.liveViewIdle;

      io.reset();

      await resumed.timeout(const Duration(milliseconds: 50));
      await idle.timeout(const Duration(milliseconds: 50));
      expect(io.liveViewPaused, isFalse);
      expect(io.hasLiveViewInFlight, isFalse);
    });
  });
}
