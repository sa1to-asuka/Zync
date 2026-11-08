import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/interval_shooting_controller.dart';
import 'package:zync/protocol/camera_driver.dart';

CameraFileItem _file(int index) => CameraFileItem(
      handle: index,
      storageId: 0x00010001,
      format: 0x3801,
      size: 4096,
      fileName: 'DSC_$index.JPG',
      captureDate: '20261107T120000',
    );

/// 假时钟 + 会让出事件循环的 sleep：既不需要真实等待，
/// 又允许测试在每一小片之间插入 pause / stop。
class _Harness {
  _Harness(this.onCapture);

  final Future<CaptureOutcome> Function(int shot, DateTime at) onCapture;

  DateTime now = DateTime(2026, 1, 1, 12);
  int shots = 0;
  final List<DateTime> shotTimes = <DateTime>[];

  late final IntervalShootingController controller = IntervalShootingController(
    capture: () {
      shots++;
      shotTimes.add(now);
      return onCapture(shots, now);
    },
    now: () => now,
    sleep: (duration) async {
      now = now.add(duration);
      await Future<void>.delayed(Duration.zero);
    },
  );

  Future<void> settle() async {
    for (var i = 0; i < 20000; i++) {
      if (!controller.isActive) return;
      await Future<void>.delayed(Duration.zero);
    }
  }
}

void main() {
  test('按配置拍满张数后进入 done', () async {
    final h = _Harness((shot, _) async => CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 5),
      shotCount: 3,
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.done);
    expect(h.controller.shotsAttempted, 3);
    expect(h.controller.shotsConfirmed, 3);
  });

  test('开始延时会被计入', () async {
    final h = _Harness((shot, _) async => CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 2),
      shotCount: 1,
      startDelay: Duration(seconds: 10),
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.done);
    expect(h.shotTimes.single.difference(DateTime(2026, 1, 1, 12)).inSeconds,
        greaterThanOrEqualTo(10));
  });

  test('相机拒绝且 stopOnError 时进入 failed 并停手', () async {
    final h = _Harness((_, __) async => const CaptureRejected(0x2019));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 1),
      shotCount: 5,
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.failed);
    expect(h.shots, 1);
  });

  test('stopOnError 关闭时继续拍完', () async {
    final h = _Harness((shot, _) async => shot.isOdd
        ? const CaptureRejected(0x2019)
        : CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 1),
      shotCount: 4,
      stopOnError: false,
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.done);
    expect(h.shots, 4);
    expect(h.controller.shotsConfirmed, 2);
  });

  test('未确认的拍摄也继续下一次，并留下提示', () async {
    final h = _Harness((_, __) async => const CaptureUnconfirmed());

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 1),
      shotCount: 2,
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.done);
    expect(h.controller.hint, IntervalHint.unconfirmed);
  });

  test('拍摄抛异常时停止而不是无限重试', () async {
    final h = _Harness((_, __) async => throw StateError('相机未连接'));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 1),
      shotCount: 5,
    ));
    await h.settle();

    expect(h.controller.state, IntervalShootingState.failed);
    expect(h.shots, 1);
  });

  test('stop 会结束序列', () async {
    final h = _Harness((shot, _) async => CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 30),
      shotCount: 100,
    ));
    await Future<void>.delayed(Duration.zero);
    await h.controller.stop();

    expect(h.controller.state, IntervalShootingState.idle);
    expect(h.controller.isActive, isFalse);
    expect(h.shots, lessThan(3));
  });

  test('pause 后不再增长张数，resume 继续', () async {
    final h = _Harness((shot, _) async => CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 10),
      shotCount: 2,
    ));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    h.controller.pause();
    expect(h.controller.state, IntervalShootingState.paused);
    final before = h.controller.shotsAttempted;
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(h.controller.shotsAttempted, before);

    h.controller.resume();
    await h.settle();
    expect(h.controller.state, IntervalShootingState.done);
    expect(h.controller.shotsAttempted, 2);
  });

  test('不限张数时由 stop 结束', () async {
    final h = _Harness((shot, _) async => CaptureConfirmed(_file(shot)));

    await h.controller.start(const IntervalShootingConfig(
      interval: Duration(seconds: 1),
      shotCount: 0,
    ));
    await Future<void>.delayed(Duration.zero);
    await h.controller.stop();

    expect(h.controller.isActive, isFalse);
  });
}
