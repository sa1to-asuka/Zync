import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/connect_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 可设定镜头参数的假驱动（FakeDriver 默认即为已连接状态）。
class _LensDriver extends FakeDriver {
  _LensDriver(this.params) : super(payload: Uint8List(0));

  CameraExposureParams params;

  @override
  Future<CameraExposureParams> fetchExposureParams() async => params;
}

void main() {
  /// 已连接状态挂载连接页（页面 initState 会读取一次镜头参数）。
  Future<void> mountConnected(WidgetTester tester, _LensDriver driver) async {
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: ConnectScreen(driver: driver, onConnected: () {}),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('连接后展示相机真实镜头参数（不再显示写死的 50-250）', (tester) async {
    final driver = _LensDriver(const CameraExposureParams(
      lensInfo: '16-50mm',
      focalLength: '35mm',
      aperture: 'f/5.6',
    ));
    await mountConnected(tester, driver);

    // 大字与「焦距范围」格都显示真实焦段
    expect(find.text('16-50mm'), findsWidgets);
    expect(find.text('35mm'), findsOneWidget);
    expect(find.text('f/5.6'), findsOneWidget);
    expect(find.text('已识别'), findsOneWidget);
    // 旧的写死占位数据必须消失
    expect(find.textContaining('50-250'), findsNothing);
    expect(find.text('Lens ID 12'), findsNothing);
    expect(find.text('VR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('相机读不到镜头时显示占位与「未读取」', (tester) async {
    final driver = _LensDriver(const CameraExposureParams());
    await mountConnected(tester, driver);

    expect(find.text('未读取'), findsOneWidget);
    expect(find.textContaining('50-250'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('连接页仅显示相机热点与 USB，蓝牙实验入口默认隐藏', (tester) async {
    final driver = _LensDriver(const CameraExposureParams());
    driver.state = CameraConnectionState.disconnected;
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: ConnectScreen(driver: driver, onConnected: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('相机热点'), findsOneWidget);
    expect(find.text('STA 局域网'), findsNothing);
    expect(find.text('USB'), findsOneWidget);
    expect(find.text('蓝牙实验'), findsNothing);

    await tester.tap(find.text('USB'));
    await tester.pumpAndSettle();
    expect(find.text('USB OTG 有线连接'), findsOneWidget);
    expect(find.textContaining('USB'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
