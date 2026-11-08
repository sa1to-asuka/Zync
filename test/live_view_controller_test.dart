import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/ptp_ip_client.dart';

import 'helpers/fake_capture_driver.dart';

Future<void> _tick([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// 取景循环里的停顿：只让出事件循环，不真的等满一帧间隔。
Future<void> _frameSleep(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  group('LiveViewController 启动与停止', () {
    test('start 后进入 running 并开始拉帧', () async {
      final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await _tick();

      expect(controller.state, LiveViewState.running);
      expect(driver.calls, contains('startLiveView'));
      expect(driver.liveFrameRequests, greaterThan(0));

      await controller.stop();
      expect(driver.calls, contains('endLiveView'));
      expect(controller.state, LiveViewState.idle);
    });

    test('相机不支持取景时不发指令，直接进入 failed', () async {
      final driver = FakeCaptureDriver(supportsLv: false);
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();

      expect(controller.state, LiveViewState.failed);
      expect(controller.failure, LiveViewFailure.unsupported);
      expect(driver.calls, isNot(contains('startLiveView')));
    });

    test('未连接时进入 failed 且原因正确', () async {
      final driver = FakeCaptureDriver()
        ..state = CameraConnectionState.disconnected;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();

      expect(controller.failure, LiveViewFailure.disconnected);
    });

    test('相机返回 0xA00B 时循环干净退出', () async {
      final driver = FakeCaptureDriver()..liveFramesToServe = 2;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await _tick(60);

      expect(controller.state, LiveViewState.failed);
      expect(controller.failure, LiveViewFailure.exited);
    });

    test('startLiveView 抛「不支持」时进入 failed', () async {
      final driver = _ThrowingStartDriver();
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();

      expect(controller.state, LiveViewState.failed);
      expect(controller.failure, LiveViewFailure.unsupported);
    });

    test('重复 start 不会重复发送启动指令', () async {
      final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await controller.start();

      expect(
        driver.calls.where((c) => c == 'startLiveView').length,
        1,
      );
      await controller.stop();
    });

    test('设备忙会重试，连续失败过多次才停', () async {
      final driver = FakeCaptureDriver()
        ..liveFramesToServe = 1000000
        ..liveFrameError =
            PtpException(0x9203, 0x2019, 'busy');
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await _tick(200);

      expect(controller.state, LiveViewState.failed);
      expect(controller.failure, LiveViewFailure.deviceBusy);
    });
  });

  group('LiveViewController 独占', () {
    test('runExclusive 期间不再请求帧，结束后恢复取景', () async {
      final driver = FakeCaptureDriver()..liveFramesToServe = 100000000;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await _tick();

      await controller.runExclusive(() async {
        final atStart = driver.liveFrameRequests;
        await _tick(40);
        expect(driver.liveFrameRequests, atStart, reason: '独占期间不应再拉帧');
      });

      expect(driver.calls, contains('endLiveView'));
      expect(
        driver.calls.where((c) => c == 'startLiveView').length,
        greaterThanOrEqualTo(2),
        reason: '独占结束后应重新进入取景',
      );
      await controller.stop();
    });

    test('独占操作抛异常后仍然恢复取景', () async {
      final driver = FakeCaptureDriver()..liveFramesToServe = 100000000;
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.start();
      await expectLater(
        controller.runExclusive(() async => throw StateError('boom')),
        throwsStateError,
      );
      await _tick();

      expect(
        driver.calls.where((c) => c == 'startLiveView').length,
        greaterThanOrEqualTo(2),
      );
      expect(controller.state, LiveViewState.running);
      await controller.stop();
    });

    test('未取景时 runExclusive 不会发退出/启动指令', () async {
      final driver = FakeCaptureDriver();
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      final result = await controller.runExclusive(() async => 7);

      expect(result, 7);
      expect(driver.calls, isNot(contains('startLiveView')));
      expect(driver.calls, isNot(contains('endLiveView')));
    });
  });

  group('LiveViewController 对焦', () {
    test('focusAt 转发到驱动', () async {
      final driver = FakeCaptureDriver();
      final controller =
          LiveViewController(driver: driver, sleep: _frameSleep);

      await controller.focusAt(2880, 1920);

      expect(driver.calls, contains('af:2880,1920'));
    });
  });
}

class _ThrowingStartDriver extends FakeCaptureDriver {
  _ThrowingStartDriver() : super();

  @override
  Future<void> startLiveView() async {
    calls.add('startLiveView');
    throw PtpException(0x9201, 0x2005, 'unsupported');
  }
}
