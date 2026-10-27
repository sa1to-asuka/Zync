import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/root_scaffold.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 单张照片的假驱动，用于验证相册多选态下的返回行为。
class _OneItemDriver extends FakeDriver {
  _OneItemDriver() : super(payload: _pngBytes());

  final CameraFileItem item = CameraFileItem(
    handle: 0x1001,
    storageId: 1,
    format: 0x3801,
    size: 4096,
    fileName: 'DSC_0001.JPG',
    captureDate: '2026.10.11 10:00',
  );

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async =>
      <int>[item.handle];

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async =>
      handle == item.handle ? item : null;

  @override
  Future<Uint8List> getThumbnail(int handle) async => _pngBytes();
}

Uint8List _pngBytes() {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 200, 100, 50);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 模拟手机返回键 / 返回手势（Android 通过该通道上报 popRoute）。
Future<void> _pressSystemBack(WidgetTester tester) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
}

int _bottomNavIndex(WidgetTester tester) => tester
    .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
    .currentIndex;

int? _railIndex(WidgetTester tester) =>
    tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

void main() {
  testWidgets('手机：非首页 Tab 按返回回到首页，而不是退出应用', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('相机相册'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_bottomNavIndex(tester), 1);

    await _pressSystemBack(tester);

    expect(_bottomNavIndex(tester), 0, reason: '返回应回到首页 Tab，而不是退出应用');
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('平板：左侧导航下按返回同样回到首页', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('水印工坊'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_railIndex(tester), 2);

    await _pressSystemBack(tester);

    expect(_railIndex(tester), 0, reason: '宽屏返回同样先回首页');
    expect(tester.takeException(), isNull);
  });

  testWidgets('首页按返回：先提示「再按一次」，不会立刻退出', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    await _pressSystemBack(tester);

    final hint = find.text('再按一次返回退出 Zync');
    expect(hint, findsOneWidget, reason: '首次返回应给出二次确认提示');
    final rect = tester.getRect(hint);
    expect(rect.bottom, greaterThan(0));
    expect(
        rect.top,
        lessThan(
            tester.view.physicalSize.height / tester.view.devicePixelRatio));
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('相册多选态', () {
    late Directory directory;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const native = MethodChannel('com.zync.app/native_camera');

    setUp(() async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('zync_back_');
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, (call) async => directory.path);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, (call) async {
        if (call.method == 'listSavedMedia') return <Map<String, dynamic>>[];
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, null);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    testWidgets('返回先退出多选模式，而不是离开相册', (tester) async {
      tester.view.physicalSize = const Size(400, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final driver = _OneItemDriver();
      final downloads = DownloadManager(driver: driver);
      final shoot = ShootAndTransferController(
          driver: driver, downloadManager: downloads);
      addTearDown(() {
        shoot.dispose();
        downloads.dispose();
      });

      await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: GalleryScreen(
          driver: driver,
          downloadManager: downloads,
          shootAndTransferController: shoot,
        ),
      ));

      final card = find.byKey(const ValueKey<String>('DSC_0001'));
      for (var i = 0; i < 80 && card.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(card, findsOneWidget);

      final state =
          tester.state<GalleryScreenState>(find.byType(GalleryScreen));
      expect(state.handleSystemBack(), isFalse, reason: '未进入多选时不该消费返回');

      // 长按进入多选
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();
      expect(find.textContaining('已选择 1 组媒体'), findsOneWidget);

      expect(state.handleSystemBack(), isTrue, reason: '多选态应由相册自行消费返回');
      await tester.pump();
      expect(find.textContaining('已选择 0 组媒体'), findsOneWidget,
          reason: '已退出多选：选择计数归零');
      expect(find.text('取消'), findsNothing, reason: '多选态 AppBar 的取消入口应收起');
      expect(find.byType(GalleryScreen), findsOneWidget, reason: '相册仍应停留在原页面');
      expect(tester.takeException(), isNull);
    });
  });
}
