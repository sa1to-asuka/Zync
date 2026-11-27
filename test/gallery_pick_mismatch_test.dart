import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/utils/capture_date.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

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
  late Directory directory;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const native = MethodChannel('com.zync.app/native_camera');

  setUp(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('zync_gallery_pick_');
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
    try {
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('compareCaptureDateNewestFirst 按拍摄时间新到旧降序，无日期按句柄降序', () {
    final sorted = [
      (date: '20261124T083000', handle: 0x10),
      (date: '2026:11:26 15:20:10', handle: 0x08),
      (date: '', handle: 0x30),
      (date: '2026.11.25 18:00', handle: 0x20),
      (date: '', handle: 0x40),
    ]..sort(
        (a, b) => compareCaptureDateNewestFirst(
          a.date,
          a.handle,
          b.date,
          b.handle,
        ),
      );

    expect(
      sorted.map((e) => e.handle).toList(),
      equals([0x08, 0x20, 0x10, 0x40, 0x30]),
    );
  });

  testWidgets('相册默认展示全部并移除新照片筛选与角标，点击卡片打开对应照片', (tester) async {
    AppSettings.instance.resetForTest();
    AppSettings.instance.setGalleryFilter('unviewed');
    expect(AppSettings.instance.galleryFilter, equals('all'));

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

    final target = find.byKey(const ValueKey<String>('DSC_0004'));
    for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(target, findsOneWidget);
    expect(find.text('新照片'), findsNothing);
    expect(find.text('新'), findsNothing);

    await tester.tap(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final viewer = tester.widget<FullScreenPhotoViewer>(
      find.byType(FullScreenPhotoViewer),
    );
    expect(
      viewer.groups[viewer.initialIndex].baseName.toUpperCase(),
      'DSC_0004',
    );
  });
}
