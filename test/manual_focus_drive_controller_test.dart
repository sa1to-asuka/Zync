import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/engine/liveview/manual_focus_drive_controller.dart';
import 'package:zync/protocol/camera_driver.dart';

import 'helpers/fake_capture_driver.dart';

Future<void> _frameSleep(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 1));

Future<void> _tick([int ms = 20]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  Future<(FakeCaptureDriver, LiveViewController)> startLiveView(
      FakeCaptureDriver driver) async {
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    await liveView.start();
    await _tick(5);
    return (driver, liveView);
  }

  test('按住近焦会连续发送方向 1，松手后取消', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
      stepsPerTick: 24,
    );

    await mf.press(MfDirection.near);
    await _tick(20);

    expect(mf.isDriving, isTrue);
    expect(driver.mfCalls, isNotEmpty);
    expect(driver.mfCalls.every((c) => c.startsWith('1:')), isTrue);
    expect(driver.mfCalls.first.endsWith(':24'), isTrue);

    await mf.release();
    expect(mf.isDriving, isFalse);
    expect(mf.lastStopReason, MfStopReason.released);
    expect(driver.cancelFocusCalls, greaterThan(0));

    await liveView.stop();
  });

  test('远焦方向为 2', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.far);
    await _tick(15);
    await mf.release();

    expect(driver.mfCalls.every((c) => c.startsWith('2:')), isTrue);
    await liveView.stop();
  });

  test('到达行程尽头时静默停止', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    driver.mfRejectCode = 0xA00C;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.near);
    await _tick(30);

    expect(mf.isDriving, isFalse);
    expect(mf.lastStopReason, MfStopReason.stepEnd);
    await liveView.stop();
  });

  test('相机不支持手动对焦时停止并标记 unsupported', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    driver.mfRejectCode = 0x2005;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.near);
    await _tick(30);

    expect(mf.lastStopReason, MfStopReason.unsupported);
    await liveView.stop();
  });

  test('取景停止后手动对焦循环随之停止', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.near);
    await _tick(10);

    await liveView.stop();
    await _tick(30);
    final callsAfterSettle = driver.mfCalls.length;
    await _tick(30);

    expect(mf.isDriving, isFalse);
    expect(mf.lastStopReason, MfStopReason.liveViewStopped);
    // 停下之后不应该再有新的对焦指令。
    expect(driver.mfCalls.length, callsAfterSettle);
  });

  test('取景被暂停（例如快门）时中断对焦', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.near);
    await _tick(10);
    driver.io.pauseLiveView('exclusive');
    await _tick(30);

    expect(mf.isDriving, isFalse);
    expect(mf.lastStopReason, MfStopReason.interrupted);

    driver.io.resumeLiveView('exclusive');
    await liveView.stop();
  });

  test('未取景时按对焦不会发指令', () async {
    final driver = FakeCaptureDriver();
    final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => _tick(1),
    );

    await mf.press(MfDirection.near);
    await _tick(10);

    expect(mf.isDriving, isFalse);
    expect(driver.mfCalls, isEmpty);
  });

  test('长按到上限会自动停止', () async {
    final driver = FakeCaptureDriver()..liveFramesToServe = 1000000;
    final (_, liveView) = await startLiveView(driver);
    final mf = ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) => Future<void>.delayed(const Duration(milliseconds: 1)),
      maxHold: const Duration(milliseconds: 20),
    );

    await mf.press(MfDirection.near);
    await _tick(80);

    expect(mf.isDriving, isFalse);
    expect(mf.lastStopReason, MfStopReason.timedOut);
    await liveView.stop();
  });
}
