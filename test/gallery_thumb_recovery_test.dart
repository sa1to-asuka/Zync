import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 每个 handle 第一次请求缩略图返回空，模拟查看器大图下载期间的瞬时失败。
class _FlakyThumbDriver extends FakeDriver {
  _FlakyThumbDriver() : super(payload: _jpegBytes());

  final Map<int, int> calls = <int, int>{};
  final List<CameraFileItem> items = [
    for (var i = 1; i <= 6; i++)
      CameraFileItem(
        handle: 0x3000 + i,
        storageId: 1,
        format: 0x3801,
        size: 4096,
        fileName: 'DSC_010$i.JPG',
        captureDate: '20261011T100000',
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
  Future<Uint8List> getThumbnail(int handle) async {
    final count = (calls[handle] ?? 0) + 1;
    calls[handle] = count;
    return count == 1 ? Uint8List(0) : _jpegBytes();
  }
}

Uint8List _jpegBytes() {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 180, 120, 60);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  late Directory directory;
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  const native = MethodChannel('com.zync.app/native_camera');

  setUp(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('zync_thumb_retry_');
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

  testWidgets('瞬时返回空的缩略图会自动重试并显示', (tester) async {
    tester.view.physicalSize = const Size(400, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final driver = _FlakyThumbDriver();
    final downloads = DownloadManager(driver: driver);
    final shoot =
        ShootAndTransferController(driver: driver, downloadManager: downloads);
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

    final card = find.byKey(const ValueKey<String>('DSC_0101'));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    expect(card, findsOneWidget);
    // 兜底图标为 Icons.photo；重试成功后不应再出现。
    expect(find.byIcon(Icons.photo), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
