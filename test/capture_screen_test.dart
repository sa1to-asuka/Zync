import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/capture_controller.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/capture/exposure_settings_controller.dart';
import 'package:zync/engine/capture/interval_shooting_controller.dart';
import 'package:zync/engine/capture/movie_recording_controller.dart';
import 'package:zync/engine/capture/exposure_bracketing_controller.dart';
import 'package:zync/engine/capture/focus_stacking_controller.dart';
import 'package:zync/engine/capture/camera_hdr_controller.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/engine/liveview/manual_focus_drive_controller.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/capture_screen.dart';

import 'helpers/fake_capture_driver.dart';
import 'helpers/pump_app.dart';

Future<void> _frameSleep(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 1));

/// 这些用例只关心拍照路径，序列工具用最小实现占位。
class _NoopBracketPort implements BracketPort {
  @override
  bool get isConnected => true;
  @override
  Future<int?> readBuiltInBracketing() async => 0;
  @override
  Future<List<int>> optionsOf(BracketAxis axis) async => const [0, 1, 2];
  @override
  Future<int?> currentOf(BracketAxis axis) async => 1;
  @override
  Future<bool> write(BracketAxis axis, int raw) async => true;
  @override
  Future<CameraFileItem?> capture() async => null;
  @override
  Future<void> settle(Duration duration) async {}
}

class _NoopFocusPort implements FocusStackPort {
  @override
  bool get isConnected => true;
  @override
  Future<bool> drive(MfDirection direction, int steps) async => true;
  @override
  Future<CameraFileItem?> capture() async => null;
  @override
  Future<void> settle(Duration duration) async {}
}

class _NoopHdrDriver implements HdrDriver {
  @override
  bool get isConnected => true;
  @override
  Future<int?> readUintProperty(int propertyId) async => 0;
  @override
  Future<void> writeUintProperty(int propertyId, int value) async {}
}
class _NoopMovieDriver implements MovieRecordingDriver {
  @override
  bool get isConnected => true;
  @override
  bool get supportsMovieRecording => false;
  @override
  Stream<int> get eventCodes => const Stream.empty();
  @override
  Future<int?> readLiveViewSelector() async => 0;
  @override
  Future<int?> readMovieRecProhibition() async => 0;
  @override
  Future<void> setLiveViewSelector(int value) async {}
  @override
  Future<void> startMovieRecording() async {}
  @override
  Future<void> stopMovieRecording() async {}
}

Widget _build(
  FakeCaptureDriver driver, {
  VoidCallback? onNavigateToConnect,
}) {
  final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
  return CaptureScreen(
    driver: driver,
    liveViewController: liveView,
    captureController: CaptureController(
      driver: driver,
      liveView: liveView,
      confirmTimeout: const Duration(milliseconds: 200),
      pollInterval: const Duration(milliseconds: 1),
      sleep: (_) async {},
    ),
    exposureController: ExposureSettingsController(
      driver: driver,
      liveView: liveView,
      sleep: (_) async {},
    ),
    manualFocusController: ManualFocusDriveController(
      driver: driver,
      liveView: liveView,
      sleep: (_) async {},
    ),
    intervalController: IntervalShootingController(
      capture: () async => const CaptureUnconfirmed(),
      sleep: (_) async {},
    ),
    movieController: MovieRecordingController(driver: _NoopMovieDriver()),
    bracketController: ExposureBracketingController(port: _NoopBracketPort()),
    focusStackController: FocusStackingController(port: _NoopFocusPort()),
    hdrController: CameraHdrController(
      driver: _NoopHdrDriver(),
      capture: () async {},
    ),
    downloadManager: DownloadManager(driver: driver),
    onNavigateToConnect: onNavigateToConnect ?? () {},
  );
}

void main() {
  testWidgets('未连接时显示空状态并可跳转连接页', (tester) async {
    final driver = FakeCaptureDriver()
      ..state = CameraConnectionState.disconnected;
    var navigated = false;

    await pumpZyncApp(
      tester,
      _build(driver, onNavigateToConnect: () => navigated = true),
      surfaceSize: const Size(400, 860),
    );
    await tester.pump();

    expect(find.text('尚未连接相机'), findsOneWidget);

    await tester.tap(find.text('前往连接'));
    await tester.pump();
    expect(navigated, isTrue);
  });

  testWidgets('已连接时显示机身型号、快门与参数胶囊', (tester) async {
    final driver = FakeCaptureDriver();

    await pumpZyncApp(
      tester,
      _build(driver),
      surfaceSize: const Size(400, 860),
    );
    await tester.pump();

    expect(find.text('NIKON Z 30'), findsOneWidget);
    expect(find.text('模式'), findsOneWidget);
    expect(find.text('光圈'), findsOneWidget);
    expect(find.text('快门速度'), findsOneWidget);
    expect(find.text('ISO'), findsOneWidget);
    expect(find.byIcon(Icons.camera), findsOneWidget);
  });

  testWidgets('点击快门会释放快门并提示已拍摄', (tester) async {
    final driver = FakeCaptureDriver();

    await pumpZyncApp(
      tester,
      _build(driver),
      surfaceSize: const Size(400, 860),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.camera));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(driver.calls, contains('capture'));
    expect(find.textContaining('已拍摄'), findsOneWidget);
  });

  testWidgets('相机不支持遥控快门时提示而不发指令', (tester) async {
    final driver = FakeCaptureDriver(supportsCapture: false);

    await pumpZyncApp(
      tester,
      _build(driver),
      surfaceSize: const Size(400, 860),
    );
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.camera));
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(driver.calls, isNot(contains('capture')));
    expect(find.text('当前相机不支持遥控快门。'), findsOneWidget);
  });

  testWidgets('未验证机型显示提示条', (tester) async {
    final driver = FakeCaptureDriver(verifiedBody: false);

    await pumpZyncApp(
      tester,
      _build(driver),
      surfaceSize: const Size(400, 860),
    );
    await tester.pump();

    expect(find.textContaining('已在尼康 Z 30 上验证'), findsOneWidget);
  });

  testWidgets('平板宽度下使用右侧面板布局', (tester) async {
    final driver = FakeCaptureDriver();

    await pumpZyncApp(
      tester,
      _build(driver),
      surfaceSize: const Size(1000, 800),
    );
    await tester.pump();

    expect(find.text('NIKON Z 30'), findsOneWidget);
    expect(find.byIcon(Icons.camera), findsOneWidget);
  });
}
