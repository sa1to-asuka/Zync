import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/core/utils/lru_image_cache.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 宽屏竖排工具条的统一 key（全屏查看器两种形态共用）。
const _toolbarKey = ValueKey('adaptiveGalleryToolbar');

/// 与实现同源的列数期望：每列约 130dp，夹在 3~8 列。
int _expectedColumns(double availableWidth) =>
    (availableWidth / 130).floor().clamp(3, 8);

/// 固定 9 张照片的假驱动，列表顺序与相册页既有测试保持一致。
class _ListDriver extends FakeDriver {
  _ListDriver() : super(payload: _pngBytes());

  final List<CameraFileItem> items = [
    for (var i = 1; i <= 9; i++)
      CameraFileItem(
        handle: 0x1000 + i,
        storageId: 1,
        format: 0x3801,
        size: 4096,
        fileName: 'DSC_000$i.JPG',
        captureDate: '2026.10.11 10:00',
      ),
  ];

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async =>
      items.reversed.map((e) => e.handle).toList();

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async {
    for (final e in items) {
      if (e.handle == handle) return e;
    }
    return null;
  }

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

Widget _app(Widget child) =>
    MaterialApp(theme: ZyncTheme.lightTheme, home: child);

Future<void> _settle(WidgetTester tester, Finder ready) async {
  for (var i = 0; i < 80 && ready.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// 冲掉后台缩略图预取定时器，避免测试结束时残留挂起定时器。
Future<void> _flushTimers(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
}

void main() {
  testWidgets('相机全屏查看器：宽屏右侧竖排工具条，窄屏回到底部横条', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    final driver = _ListDriver();
    final group = CameraMediaGroup(
      baseName: 'DSC_0001',
      jpegItem: driver.items.first,
    );

    await tester.pumpWidget(_app(FullScreenPhotoViewer(
      groups: [group],
      initialIndex: 0,
      thumbCache: LruImageCache(),
      fullCache: LruImageCache(),
      driver: driver,
      resolveThumb: (file) => driver.getThumbnail(file.handle),
    )));
    await _settle(tester, find.byKey(_toolbarKey));

    expect(find.byKey(_toolbarKey), findsOneWidget,
        reason: '宽屏应把操作栏竖排到右侧');
    final wideRect = tester.getRect(find.byKey(_toolbarKey));
    expect(wideRect.left, greaterThan(1280 * 0.8),
        reason: '竖排工具条应贴在右侧边缘');

    // 同一棵树切到窄屏：竖排消失，回到底部横条
    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_toolbarKey), findsNothing,
        reason: '窄屏必须保持原有底部横条');
    final closeRect = tester.getRect(find.byIcon(Icons.close));
    expect(closeRect.left, closeTo(16, 1), reason: '底部横条保持左侧 16dp 边距');
    expect(closeRect.bottom, closeTo(800 - 12, 1), reason: '底部横条贴屏幕底部');
    expect(tester.takeException(), isNull);
  });

  testWidgets('本地全屏查看器：宽屏右侧竖排工具条，窄屏回到底部横条', (tester) async {
    final dir = Directory.systemTemp.createTempSync('zync_viewer_wide_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    final file = File('${dir.path}/portrait.png')
      ..writeAsBytesSync(_pngBytes());
    final item = ExportedMediaItem(
      file: file,
      fileName: 'portrait.png',
      baseName: 'PORTRAIT',
      size: file.lengthSync(),
      modifiedTime: DateTime(2026, 10, 14),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(
      FullScreenLocalImageViewer(items: [item], initialIndex: 0),
    ));
    await _settle(tester, find.byKey(_toolbarKey));
    expect(find.byKey(_toolbarKey), findsOneWidget);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_toolbarKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('相册网格列数与操作岛形态', () {
    late Directory directory;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const native = MethodChannel('com.zync.app/native_camera');

    setUp(() async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        directory =
            await Directory.systemTemp.createTemp('zync_gallery_adaptive_');
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

    /// 按指定窗口宽度挂载相册页，并等待相机网格就绪。
    Future<void> mountGallery(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;

      final driver = _ListDriver();
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
          key: ValueKey('gallery_$width'),
          driver: driver,
          downloadManager: downloads,
          shootAndTransferController: shoot,
        ),
      ));
      await _settle(tester, find.byKey(const ValueKey<String>('DSC_0005')));
      expect(find.byKey(const ValueKey<String>('DSC_0005')), findsOneWidget);
    }

    testWidgets('网格列数按相册自身可用宽度计算，不再用整窗宽度', (tester) async {
      addTearDown(tester.view.reset);
      for (final width in <double>[1280, 800, 360]) {
        await mountGallery(tester, width);
        final grid = tester.widget<GridView>(find.byType(GridView).first);
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, _expectedColumns(width),
            reason: '窗口宽度 $width 时应为 ${_expectedColumns(width)} 列');
        await _flushTimers(tester);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('多选操作岛：宽屏贴右侧竖排，窄屏保持底部横条', (tester) async {
      addTearDown(tester.view.reset);

      await mountGallery(tester, 1280);
      final wideRect = tester.getRect(find.textContaining('已选择'));
      expect(wideRect.left, greaterThan(1280 * 0.5),
          reason: '宽屏操作岛应贴右侧');
      expect(find.text('同步到手机'), findsOneWidget);
      await _flushTimers(tester);

      await mountGallery(tester, 360);
      final narrowRect = tester.getRect(find.textContaining('已选择'));
      expect(narrowRect.left, lessThan(360 * 0.5),
          reason: '窄屏操作岛应保持底部横条的左对齐');
      expect(find.text('同步到手机'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _flushTimers(tester);
    });

    testWidgets('长按进入多选时恰好触发一次中度触感', (tester) async {
      addTearDown(tester.view.reset);

      final platformCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        platformCalls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await mountGallery(tester, 360);

      final card = find.byKey(const ValueKey<String>('DSC_0005'));
      final gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();

      final vibrates = platformCalls
          .where((c) => c.method == 'HapticFeedback.vibrate')
          .toList();
      expect(vibrates.length, 1, reason: '进入多选只应震动一次，拖动过程不重复');
      expect(vibrates.single.arguments, 'HapticFeedbackType.mediumImpact');
      expect(tester.takeException(), isNull);
      await _flushTimers(tester);
    });
  });
}
