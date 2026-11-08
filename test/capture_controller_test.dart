import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/capture_controller.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/protocol/camera_driver.dart';

import 'helpers/fake_capture_driver.dart';

Future<void> _frameSleep(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 1));

CaptureController _controller(
  FakeCaptureDriver driver,
  LiveViewController liveView, {
  void Function(CameraFileItem file)? onCaptured,
  Duration confirmTimeout = const Duration(milliseconds: 300),
}) {
  return CaptureController(
    driver: driver,
    liveView: liveView,
    onCaptured: onCaptured,
    confirmTimeout: confirmTimeout,
    pollInterval: const Duration(milliseconds: 1),
    sleep: (_) async {},
  );
}

void main() {
  test('拍到新文件时返回 Confirmed 并触发回调', () async {
    final driver = FakeCaptureDriver();
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    CameraFileItem? captured;

    final controller = _controller(driver, liveView,
        onCaptured: (file) => captured = file);

    final outcome = await controller.capture();

    expect(outcome, isA<CaptureConfirmed>());
    expect((outcome as CaptureConfirmed).file.fileName, startsWith('DSC_'));
    expect(captured, isNotNull);
    expect(driver.calls, contains('capture'));
  });

  test('超时未出现新文件时返回 Unconfirmed，且不回调', () async {
    final driver = FakeCaptureDriver()..producePhotoOnCapture = false;
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    var called = false;

    final controller = _controller(driver, liveView,
        onCaptured: (_) => called = true,
        confirmTimeout: const Duration(milliseconds: 30));

    final outcome = await controller.capture();

    expect(outcome, isA<CaptureUnconfirmed>());
    expect(called, isFalse, reason: '没拿到文件就不能入队');
  });

  test('相机拒绝快门时返回 Rejected 与响应码', () async {
    final driver = FakeCaptureDriver()..captureRejectCode = 0x2019;
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    final controller = _controller(driver, liveView);

    final outcome = await controller.capture();

    expect(outcome, isA<CaptureRejected>());
    expect((outcome as CaptureRejected).responseCode, 0x2019);
  });

  test('不支持遥控快门时直接返回 0x2005，不发送快门指令', () async {
    final driver = FakeCaptureDriver(supportsCapture: false);
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    final controller = _controller(driver, liveView);

    final outcome = await controller.capture();

    expect(outcome, isA<CaptureRejected>());
    expect((outcome as CaptureRejected).responseCode, 0x2005);
    expect(driver.calls, isNot(contains('capture')));
  });

  test('未连接时抛异常而不是假装拍过', () async {
    final driver = FakeCaptureDriver()
      ..state = CameraConnectionState.disconnected;
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    final controller = _controller(driver, liveView);

    await expectLater(controller.capture(), throwsStateError);
    expect(driver.calls, isNot(contains('capture')));
  });

  test('取景中拍摄会先退出取景再按快门，结束后恢复', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    await liveView.start();
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final controller = _controller(driver, liveView);
    final outcome = await controller.capture();

    expect(outcome, isA<CaptureConfirmed>());

    final endIndex = driver.calls.indexOf('endLiveView');
    final captureIndex = driver.calls.indexOf('capture');
    expect(endIndex, isNonNegative);
    expect(captureIndex, greaterThan(endIndex),
        reason: '必须先退出取景再释放快门');

    final restarts =
        driver.calls.where((c) => c == 'startLiveView').length;
    expect(restarts, greaterThanOrEqualTo(2));
    await liveView.stop();
  });

  test('enqueue=false 时不触发回调', () async {
    final driver = FakeCaptureDriver();
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    var called = false;
    final controller = _controller(driver, liveView,
        onCaptured: (_) => called = true);

    final outcome = await controller.capture(enqueue: false);

    expect(outcome, isA<CaptureConfirmed>());
    expect(called, isFalse);
  });

  test('拍摄进行中再次调用会被拒绝', () async {
    final driver = FakeCaptureDriver();
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    final controller = _controller(driver, liveView);

    final first = controller.capture();
    await expectLater(controller.capture(), throwsStateError);
    await first;
  });
}
