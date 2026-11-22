import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/connect/link_camera_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

const _nativeChannel = MethodChannel('com.zync.app/native_camera');

void main() {
  List<Map<String, dynamic>> mockMdnsCameras = <Map<String, dynamic>>[];
  Map<String, dynamic> mockLanScanResult = <String, dynamic>{
    'hosts': <String>[],
    'scannedSubnets': <String>['192.168.1.0/24'],
    'wifiConnected': true,
    'wifiSsid': 'Home_5G',
    'wifiGateway': '192.168.1.1',
    'hasHotspotInterface': false,
    'respondingPeerCount': 0,
  };

  setUp(() {
    AppSettings.instance.resetForTest();
    mockMdnsCameras = <Map<String, dynamic>>[];
    mockLanScanResult = <String, dynamic>{
      'hosts': <String>[],
      'scannedSubnets': <String>['192.168.1.0/24'],
      'wifiConnected': true,
      'wifiSsid': 'Home_5G',
      'wifiGateway': '192.168.1.1',
      'hasHotspotInterface': false,
      'respondingPeerCount': 0,
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, (call) async {
      return switch (call.method) {
        'getWifiInfo' => <String, dynamic>{
            'connected': false,
            'bound': false,
            'ssid': '',
            'gateway': '192.168.0.1',
            'ip': '192.168.0.2',
          },
        'listUsbDevices' => <dynamic>[
            <String, dynamic>{
              'deviceName': '/dev/bus/usb/001/002',
              'vendorId': 1200,
              'productId': 1,
              'name': 'NIKON Z 30',
              'vendorName': 'Nikon',
              'isNikon': true,
              'isCamera': true,
              'ptpReady': true,
              'hasPermission': true,
              'storageOnly': false,
            },
          ],
        'getLocalIpv4' => '10.0.0.2',
        'discoverPtpCameras' => mockMdnsCameras,
        'scanLanPtpHosts' => mockLanScanResult,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_nativeChannel, null);
  });

  Future<FakeDriver> mount(
    WidgetTester tester, {
    VoidCallback? onConnected,
  }) async {
    final driver = FakeDriver(payload: Uint8List(0));
    driver.state = CameraConnectionState.disconnected;
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: LinkCameraScreen(
        driver: driver,
        onConnected: onConnected ?? () {},
      ),
    ));
    await tester.pumpAndSettle();
    return driver;
  }

  testWidgets('三种连接方式可切换，教程跟随当前方式', (tester) async {
    final lang = L10n.current.localeName;
    await mount(tester);

    expect(find.text(EngineL10n.linkModeHotspot(lang)), findsWidgets);
    expect(find.text(EngineL10n.linkLanConnect(lang)), findsNothing);
    expect(find.textContaining('NIKON_Z30'), findsOneWidget);

    await tester.tap(find.text(EngineL10n.linkModeLan(lang)).first);
    await tester.pumpAndSettle();

    expect(find.text(EngineL10n.linkLanIpLabel(lang)), findsOneWidget);
    expect(find.text(EngineL10n.linkLanConnect(lang)), findsOneWidget);
    expect(find.textContaining('010.151.169.075'), findsWidgets);
    expect(find.text(EngineL10n.linkTutorialTitle(lang)), findsOneWidget);

    await tester.tap(find.text(EngineL10n.linkModeUsb(lang)).first);
    await tester.pumpAndSettle();
    expect(find.text(EngineL10n.linkUsbConnect(lang)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('非法 IP 不发起连接，只给出提示', (tester) async {
    final lang = L10n.current.localeName;
    final driver = await mount(tester);

    await tester.tap(find.text(EngineL10n.linkModeLan(lang)).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).first, '999.1.2.3');
    final connectButton = find.text(EngineL10n.linkLanConnect(lang));
    await tester.ensureVisible(connectButton);
    await tester.pumpAndSettle();
    await tester.tap(connectButton);
    await tester.pump();

    expect(find.text(EngineL10n.linkInvalidIp(lang)), findsOneWidget);
    expect(driver.isConnected, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('默认选中上次使用的连接方式', (tester) async {
    AppSettings.instance.setLastLinkMethod('lan');
    final lang = L10n.current.localeName;
    await mount(tester);
    expect(find.text(EngineL10n.linkLanIpLabel(lang)), findsOneWidget);
  });

  testWidgets('局域网 STA 支持切换同一路由器 / 手机个人热点，并联动教程与诊断', (tester) async {
    AppSettings.instance.setLastLinkMethod('lan');
    final lang = L10n.current.localeName;
    await mount(tester);

    expect(find.text(EngineL10n.linkStaSubModeRouter(lang)), findsOneWidget);
    expect(find.text(EngineL10n.linkStaSubModeHotspot(lang)), findsOneWidget);

    await tester.tap(find.text(EngineL10n.linkStaSubModeHotspot(lang)));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.staSubMode, equals('hotspot'));
    expect(find.text(EngineL10n.linkStaHotspotHint(lang)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自动查找发现 Bonjour 相机显示型号与待配对徽章，未命中时显示类型化诊断',
      (tester) async {
    AppSettings.instance.setLastLinkMethod('lan');
    final lang = L10n.current.localeName;

    // 1. 先测试 Bonjour 命中待配对相机
    mockMdnsCameras = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Z_f_001234',
        'model': 'Nikon Z f',
        'host': '192.168.1.55',
        'port': 15740,
        'pairing': true,
        'source': 'bonjour',
      },
    ];
    await mount(tester);

    final scanBtn = find.text(EngineL10n.linkLanScan(lang));
    await tester.ensureVisible(scanBtn);
    await tester.tap(scanBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Nikon Z f'), findsOneWidget);
    expect(find.text(EngineL10n.linkLanPairingBadge(lang)), findsOneWidget);

    // 2. 再测试网段静默无命中时输出 AP 隔离 / 6GHz 类型化诊断
    mockMdnsCameras = <Map<String, dynamic>>[];
    await tester.tap(scanBtn);
    await tester.pumpAndSettle();

    expect(find.text(EngineL10n.linkStaDiagSilentNetwork(lang)), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('局域网高级选项支持展开并导入合法 32 位配对身份 GUID', (tester) async {
    AppSettings.instance.setLastLinkMethod('lan');
    final lang = L10n.current.localeName;
    await mount(tester);

    final guidHeader =
        find.textContaining(EngineL10n.linkStaGuidSectionTitle(lang));
    await tester.ensureVisible(guidHeader);
    await tester.tap(guidHeader);
    await tester.pumpAndSettle();

    final importBtn = find.text(EngineL10n.linkStaGuidImportBtn(lang));
    await tester.ensureVisible(importBtn);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      '00112233-4455-6677-8899-aabbccddeeff',
    );
    await tester.tap(find.text(EngineL10n.linkStaGuidImportBtn(lang)).last);
    await tester.pumpAndSettle();

    expect(
      AppSettings.instance.ptpClientGuidHex,
      equals('00112233445566778899aabbccddeeff'),
    );
    expect(tester.takeException(), isNull);
  });
}
