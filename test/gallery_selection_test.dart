import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 固定 9 张照片（DSC_0001..DSC_0009）的假驱动，按展示顺序升序返回。
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

void main() {
  group('滑动多选选区数学 applyDragRangeToggle', () {
    test('空选中：5→8 得 5,6,7,8', () {
      expect(applyDragRangeToggle(<int>{}, 4, 7), {4, 5, 6, 7});
    });

    test('空选中：5→1 得 1,2,3,4,5', () {
      expect(applyDragRangeToggle(<int>{}, 4, 0), {0, 1, 2, 3, 4});
    });

    test('已选 1–10 时 5→11：取消 5–10、选中 11 ⇒ 1–4 + 11', () {
      final snapshot = <int>{for (var i = 0; i <= 9; i++) i};
      expect(applyDragRangeToggle(snapshot, 4, 10), {0, 1, 2, 3, 10});
    });

    test('多次拖动各自累积：已选 5–8 时再 10→15', () {
      final snapshot = {4, 5, 6, 7};
      final after = applyDragRangeToggle(snapshot, 9, 14);
      expect(after, {4, 5, 6, 7, 9, 10, 11, 12, 13, 14});
    });

    test('区间外保持快照原样（原地不动等价于该项取反）', () {
      final snapshot = {0, 2};
      expect(applyDragRangeToggle(snapshot, 1, 1), {0, 1, 2});
      expect(applyDragRangeToggle(snapshot, 2, 2), {0});
    });
  });

  group('长按滑动多选（相机相册）', () {
    late Directory directory;
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const native = MethodChannel('com.zync.app/native_camera');

    setUp(() async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        directory = await Directory.systemTemp.createTemp('zync_gallery_sel_');
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

    Future<void> settle(WidgetTester tester, Finder ready) async {
      for (var i = 0; i < 80 && ready.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    /// 挂载已连接相机（9 张照片）的相册页，并等待网格就绪。
    Future<({_ListDriver driver, Finder Function(int) card})> mountGallery(
        WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 820);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
            driver: driver,
            downloadManager: downloads,
            shootAndTransferController: shoot),
      ));

      Finder card(int n) => find.byKey(ValueKey<String>('DSC_000$n'));
      await settle(tester, card(5));
      expect(card(5), findsOneWidget);
      expect(tester.takeException(), isNull);
      return (driver: driver, card: card);
    }

    /// 模拟真手指：多段小步移动到目标卡片中心。
    Future<TestGesture> longPressDrag(
      WidgetTester tester, {
      required Offset from,
      required Offset to,
      int steps = 6,
    }) async {
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 1; i <= steps; i++) {
        final p = Offset.lerp(from, to, i / steps)!;
        await gesture.moveTo(p);
        await tester.pump(const Duration(milliseconds: 16));
      }
      return gesture;
    }

    /// 冲掉后台预取缩略图的定时器，避免测试结束时残留挂起定时器。
    Future<void> flushTimers(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
    }
    testWidgets('多段小步长按拖动：5→8 得 4 组，再从 5 拖到 9 反向取消得 1 组', (tester) async {
      final g = await mountGallery(tester);

      var gesture = await longPressDrag(tester,
          from: tester.getCenter(g.card(5)), to: tester.getCenter(g.card(8)));
      await gesture.up();
      await tester.pump();
      expect(find.textContaining('已选择 4 组媒体'), findsOneWidget);

      // 已选 5–8 时再从 5 拖到 9：区间取反 ⇒ 5–8 取消、9 新增 ⇒ 只剩 1 组
      gesture = await longPressDrag(tester,
          from: tester.getCenter(g.card(5)), to: tester.getCenter(g.card(9)));
      await gesture.up();
      await tester.pump();
      expect(find.textContaining('已选择 1 组媒体'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flushTimers(tester);
    });

    testWidgets('只长按不移动：选中该张且不会把它取消', (tester) async {
      final g = await mountGallery(tester);

      final gesture = await tester.startGesture(tester.getCenter(g.card(5)));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();

      expect(find.textContaining('已选择 1 组媒体'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await flushTimers(tester);
    });

  });
}