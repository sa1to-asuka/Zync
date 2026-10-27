import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/constants/colors.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/core/utils/lru_image_cache.dart';
import 'package:zync/engine/editor/photo_edit_controller.dart';
import 'package:zync/engine/editor/photo_edit_engine.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/engine/update/app_update_manager.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/camera_native_bridge.dart';
import 'package:zync/ui/screens/connect_screen.dart';
import 'package:zync/ui/screens/gallery_screen.dart';
import 'package:zync/ui/screens/photo_editor_screen.dart';
import 'package:zync/ui/screens/watermark_screen.dart';
import 'package:zync/ui/widgets/photo_edit_preview.dart';
import 'package:zync/ui/widgets/photo_edit_tools.dart';
import 'download_integrity_test.dart' show FakeDriver;

class CountingDriver extends FakeDriver {
  CountingDriver(Uint8List payload) : super(payload: payload);
  int downloads = 0;
  Completer<Uint8List>? gate;
  @override
  Future<Uint8List> downloadFullObject(int handle, int totalSize,
      {Function(int, int)? onProgress}) async {
    downloads++;
    if (gate != null) return gate!.future;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return super.downloadFullObject(handle, totalSize, onProgress: onProgress);
  }
}

Uint8List photoBytes({int width = 40, int height = 60}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
          x, y, x < width / 2 ? 255 : 0, 0, x < width / 2 ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> waitPreview(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 150; i++) {
    await tester.pump(const Duration(milliseconds: 60));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    if (ready()) return;
  }
  expect(ready(), isTrue, reason: '后台预览应完成');
}

bool previewWidth(WidgetTester tester, int width) {
  final widgets = find.byType(RawImage).evaluate();
  return widgets.isNotEmpty &&
      tester.widget<RawImage>(find.byType(RawImage)).image!.width == width;
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/qa')..createSync(recursive: true);
      File('${directory.path}/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File savedFile;
  var materializations = 0;
  var failRead = false, failOverwrite = false, failRestore = false;
  final rows = <Map<String, dynamic>>[];
  const native = MethodChannel('com.zync.app/native_camera');
  const paths = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('zync_regression_');
      savedFile = File('${directory.path}/phone.png');
      await savedFile.writeAsBytes(photoBytes());
      materializations = 0;
      failRead = false;
      failOverwrite = false;
      failRestore = false;
      rows.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, (call) async => directory.path);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, (call) async {
        switch (call.method) {
          case 'listSavedMedia':
            return rows;
          case 'materializeMedia':
            materializations++;
            await Future<void>.delayed(const Duration(milliseconds: 15));
            if (failRead) throw PlatformException(code: 'MEDIA_READ_FAILED');
            return savedFile.path;
          case 'overwriteMedia':
            if (failRestore)
              throw PlatformException(
                  code: 'OVERWRITE_RESTORE_FAILED', message: '原图恢复失败');
            return !failOverwrite;
          case 'saveMediaToGallery':
            final args = Map<String, dynamic>.from(call.arguments as Map);
            await File(args['srcPath'] as String).copy(savedFile.path);
            return 'content://media/external/file/99';
          case 'getWifiInfo':
            return {
              'connected': true,
              'bound': true,
              'ssid': 'Nikon',
              'ip': '192.168.0.2',
              'gateway': '192.168.0.1'
            };
          default:
            return null;
        }
      });
      await ExportHistoryManager().refresh();
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null);
    directory.deleteSync(recursive: true);
  });
  ExportedMediaItem item([String name = 'DSC_0001.png']) => ExportedMediaItem(
      file: File('missing'),
      fileName: name,
      baseName: name.split('.').first.toUpperCase(),
      size: photoBytes().length,
      modifiedTime: DateTime(2026, 10, 10),
      mediaUri: 'content://media/external/file/71');

  test('临时文件删除后，URI 仍可读取；并发只复制一次', () async {
    final history = ExportHistoryManager();
    final temp = File('${directory.path}/partial');
    await temp.writeAsBytes(photoBytes());
    history.registerExported(
        'DSC_0001.png', temp, 'content://media/external/file/71');
    await temp.delete();
    final media = history.findExportedItem('DSC_0001.png')!;
    final files = await Future.wait(
        [history.ensureLocalFile(media), history.ensureLocalFile(media)]);
    expect(await files.first.readAsBytes(), photoBytes());
    expect(materializations, 1);
  });

  test('重启刷新保留来源关系，RAW 不会抢占 JPG 的匹配', () async {
    final history = ExportHistoryManager();
    rows.addAll([
      {
        'uri': 'content://media/external/file/71',
        'name': 'DSC_0001.JPG',
        'size': 100,
        'modified': 1000,
        'path': ''
      },
      {
        'uri': 'content://media/external/file/72',
        'name': 'DSC_0001.NEF',
        'size': 200,
        'modified': 1000,
        'path': ''
      },
      {
        'uri': 'content://media/external/file/73',
        'name': 'DSC_0001.JPG',
        'size': 100,
        'modified': 1000,
        'path': ''
      },
    ]);
    final key =
        ExportHistoryManager.sourceKey(1, 'DSC_0001.JPG', 100, '20261010');
    await history.recordSource(key, 'content://media/external/images/media/71');
    await history.refresh();
    expect(history.findExportedItem('DSC_0001.JPG', sourceKey: key)!.mediaUri,
        contains('/71'));
    expect(history.findExportedItem('DSC_0001.JPG'), isNull,
        reason: '歧义副本不能随便选');
    expect(history.findExportedItem('DSC_0001.NEF')!.isRaw, isTrue);
  });

  test('本地可用时原图读取不调用相机，并优先于旧缓存', () async {
    final history = ExportHistoryManager();
    history.registerExported(
        'DSC_0001.png', savedFile, 'content://media/external/file/71');
    final bytes = photoBytes(),
        driver = CountingDriver(bytes),
        cache = LruImageCache();
    cache[cameraCacheKey(1, 2)] = Uint8List.fromList([1]);
    final camera = CameraFileItem(
        handle: 2,
        storageId: 1,
        format: 0x3801,
        size: bytes.length,
        fileName: 'DSC_0001.png',
        captureDate: '');
    expect(await fetchFullPhotoBytesSilent(driver, cache, camera), bytes);
    expect(driver.downloads, 0);
  });

  test('未同步的并发原图请求只下载一次', () async {
    final bytes = photoBytes(),
        driver = CountingDriver(bytes),
        cache = LruImageCache();
    final camera = CameraFileItem(
        handle: 7,
        storageId: 1,
        format: 0x3801,
        size: bytes.length,
        fileName: 'UNSYNCED.png',
        captureDate: '');
    final results = await Future.wait([
      fetchFullPhotoBytesSilent(driver, cache, camera),
      fetchFullPhotoBytesSilent(driver, cache, camera)
    ]);
    expect(results.first, bytes);
    expect(driver.downloads, 1);
  });

  test('一段连续手势只产生一个撤销记录', () {
    final controller = PhotoEditController();
    controller.beginGesture();
    controller.update(const PhotoEditTransform(rotationDegrees: 20));
    controller.update(const PhotoEditTransform(rotationDegrees: 40));
    controller.endGesture();
    controller.undo();
    expect(controller.value.rotationDegrees, 0);
    expect(controller.canUndo, isFalse);
    controller.redo();
    expect(controller.value.rotationDegrees, 40);
    controller.dispose();
  });

  test('原图恢复失败不能被当作普通覆盖失败静默另存', () async {
    failRestore = true;
    await expectLater(
        CameraNativeBridge.overwriteMedia(
            'content://media/external/file/71', savedFile.path),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'OVERWRITE_RESTORE_FAILED')));
  });

  test('透视改变梯形，交叉四角被拒绝，自由变换真实改变像素', () {
    final source = img.decodeImage(photoBytes(width: 101, height: 101))!;
    final horizontal = PhotoEditEngine.apply(
        source, const PhotoEditTransform(perspectiveHorizontal: 1));
    expect(horizontal.getPixel(0, 0).a, greaterThan(200),
        reason: '透视边缘必须填满固定画框，不能留下透明黑边');
    expect(horizontal.getPixel(50, 50).a, greaterThan(200));
    final vertical = PhotoEditEngine.apply(
        source, const PhotoEditTransform(perspectiveVertical: 1));
    expect(vertical.getPixel(0, 0).a, greaterThan(200));
    expect(
        PhotoEditEngine.validQuad(
            const PhotoEditTransform(distortTopLeftX: 1.2)),
        isFalse);
    final enlarged =
        PhotoEditEngine.apply(source, const PhotoEditTransform(scale: 2));
    expect(enlarged.getPixel(100, 50).a, greaterThan(250),
        reason: '放大不能再次自动缩小');
    final shifted =
        PhotoEditEngine.apply(source, const PhotoEditTransform(offsetX: .25));
    expect(shifted.getPixel(60, 50).r, greaterThan(200));
  });

  test('竖图手柄以照片矩形定位，不包含两侧留白', () {
    final rect = fittedPhotoRect(const Size(400, 300), const Size(100, 200));
    expect(rect, const Rect.fromLTWH(125, 0, 150, 300));
  });

  test('固定裁切比例在输出像素取整后仍然保持', () {
    final source = img.Image(width: 2001, height: 1337);
    final t = PhotoEditTransform(
        rotationDegrees: 17,
        crop: cropRectForAspect(1, 100, 80),
        cropAspect: 1);
    final result = PhotoEditEngine.apply(source, t);
    expect(result.width, result.height);
    expect(PhotoEditTransform.fromJson(t.toJson()).cropAspect, 1);
  });

  testWidgets('快速连续编辑只展示最新结果', (tester) async {
    final controller = PhotoEditController();
    await tester.runAsync(() async {
      await controller.load(photoBytes(width: 600, height: 400));
      controller.update(const PhotoEditTransform(perspectiveHorizontal: .7));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      controller.update(const PhotoEditTransform(rotationDegrees: 180));
      var correct = false;
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final pixels = await controller.previewImage!
            .toByteData(format: ui.ImageByteFormat.rawRgba);
        if (pixels != null &&
            pixels.getUint8(0) < 20 &&
            pixels.getUint8(2) > 230 &&
            pixels.getUint8(3) > 230) {
          correct = true;
          break;
        }
      }
      expect(correct, isTrue);
      expect(controller.renderError, isNull);
    });
    controller.dispose();
  });

  testWidgets('滑块连续拖动期间立即显示变换，而不是等待后台结束', (tester) async {
    final controller = PhotoEditController();
    await tester.runAsync(() => controller.load(photoBytes()));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 200,
                        height: 300,
                        child: PhotoEditPreview(
                            controller: controller,
                            activeTool: PhotoEditTool.flip)))))));
    controller.beginGesture();
    controller.update(const PhotoEditTransform(flipHorizontal: true));
    await tester.pump();
    expect(controller.previewPending, isTrue);
    expect(find.byType(RawImage), findsNothing, reason: '后台尚未完成时使用即时几何画布');
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes =
            await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final offset = (150 * 200 + 25) * 4;
        expect(bytes!.getUint8(offset + 2), greaterThan(230),
            reason: '水平翻转后左侧立即显示蓝色');
      } finally {
        image.dispose();
      }
    });
    controller.endGesture();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('自由变换缩放后即时画布垫黑幕布而不是原图', (tester) async {
    final controller = PhotoEditController();
    await tester
        .runAsync(() => controller.load(photoBytes(width: 60, height: 40)));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 300,
                        height: 400,
                        child: PhotoEditPreview(
                            controller: controller,
                            activeTool: PhotoEditTool.free)))))));
    controller.beginGesture();
    controller.update(const PhotoEditTransform(scale: 0.5));
    await tester.pump();
    expect(controller.previewPending, isTrue);
    final bytes = (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
    // 照片矩形 300x200 居中于 y=100..300；缩到 0.5 后内容只占中心一半。
    const corner = (120 * 300 + 20) * 4;
    expect(
        bytes[corner] < 20 && bytes[corner + 1] < 20 && bytes[corner + 2] < 20,
        isTrue,
        reason: '缩放露出的底层必须是黑幕布，不能再垫一张原图');
    const center = (200 * 300 + 150) * 4;
    expect(bytes[center] > 150 || bytes[center + 2] > 150, isTrue,
        reason: '中心仍是照片内容');
    controller.endGesture();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('透视预览把等腰梯形画到画框外，且不被后台结果裁回', (tester) async {
    final controller = PhotoEditController();
    await tester
        .runAsync(() => controller.load(photoBytes(width: 60, height: 40)));
    controller.update(const PhotoEditTransform(perspectiveHorizontal: 1));
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                        width: 300,
                        height: 400,
                        child: PhotoEditPreview(
                            controller: controller,
                            activeTool: PhotoEditTool.perspective)))))));
    await tester.pump();
    await waitPreview(tester, () => !controller.previewPending);
    expect(find.byType(RawImage), findsNothing,
        reason: '透视始终用即时画布，后台的画框裁剪结果不能把溢出的梯形裁掉');
    final bytes = (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
      } finally {
        image.dispose();
      }
    }))!;
    bool photoBlue(int x, int y) {
      final i = (y * 300 + x) * 4;
      return bytes[i] < 50 && bytes[i + 1] < 50 && bytes[i + 2] > 200;
    }

    // 画框内接：300x200 居中（y 100..300）。+100 短边贴左，长边向上溢出。
    expect(photoBlue(250, 80), isTrue, reason: '画框右上外侧应露出梯形长边的内容（截图同款溢出）');
    expect(photoBlue(50, 80), isFalse, reason: '短边与画框对齐，左上外侧不应有内容');
    const i = (200 * 300 + 150) * 4;
    expect(bytes[i] < 50 && bytes[i + 2] > 200, isTrue,
        reason: '画框中心仍取到图片内容（右半蓝）');
  });

  testWidgets('高清加载弹窗浅色可读，取消后保留当前页面', (tester) async {
    final bytes = photoBytes(),
        driver = CountingDriver(bytes)..gate = Completer<Uint8List>();
    final camera = CameraFileItem(
        handle: 8,
        storageId: 1,
        format: 0x3801,
        size: bytes.length,
        fileName: 'WAIT.png',
        captureDate: '');
    Uint8List? result;
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await fetchFullPhotoBytesWithDialog(
                          context, driver, LruImageCache(), camera);
                    },
                    child: const Text('加载照片'))))));
    await tester.tap(find.text('加载照片'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.text('加载高清照片中')).style!.color,
        ZyncPalette.light.textPrimary);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    driver.gate!.complete(bytes);
    await tester.pump();
    expect(result, isNull);
    expect(find.text('加载照片'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('后台解码烘焙 EXIF 方向；预览和全尺寸格式保持', () async {
    final source = img.Image(width: 40, height: 20);
    img.fill(source, color: img.ColorRgb8(220, 10, 0));
    source.exif.imageIfd.orientation = 6;
    final worker = PhotoEditWorker();
    try {
      final info = await worker.open(Uint8List.fromList(img.encodeJpg(source)));
      expect(info['width'], 20);
      expect(info['height'], 40);
      final png = await worker.render(
          const PhotoEditTransform(rotationDegrees: 90),
          preview: false);
      final rotated = img.decodePng(png['bytes'] as Uint8List)!;
      expect(rotated.width, 20);
      expect(rotated.height, 40);
      final jpeg = await worker.render(const PhotoEditTransform(),
          preview: false, format: 'jpg');
      expect(img.decodeJpg(jpeg['bytes'] as Uint8List), isNotNull);
    } finally {
      worker.dispose();
    }
  });

  testWidgets('完整编辑器挂载，旋转、撤销与最新请求更新预览', (tester) async {
    final captureKey = GlobalKey();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: RepaintBoundary(
            key: captureKey,
            child: PhotoEditorScreen(item: item(), bytes: photoBytes()))));
    await waitPreview(
        tester, () => find.byType(RawImage).evaluate().isNotEmpty);
    final initial = tester.widget<RawImage>(find.byType(RawImage)).image!;
    expect(initial.width, 40);
    expect(initial.height, 60);
    final shortcut = find.byTooltip('右转 90°');
    expect(find.ancestor(of: shortcut, matching: find.byType(PhotoEditPreview)),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(PhotoEditToolsPanel), matching: shortcut),
        findsNothing);
    final pictureBounds = tester.getRect(find.byType(PhotoEditPreview));
    final shortcutBounds =
        tester.getRect(find.byKey(const ValueKey('photo-transform-shortcuts')));
    expect(pictureBounds.contains(shortcutBounds.topLeft), isTrue);
    expect(pictureBounds.contains(shortcutBounds.bottomRight), isTrue);
    final initialImageRect = tester.getRect(find.byType(RawImage));
    await tester.tap(shortcut);
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    expect(tester.getRect(find.byType(RawImage)), initialImageRect,
        reason: '旋转只能改变图片内容，图片画框不能移动');
    await tester.tap(find.byTooltip('撤销'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    await tester.tap(find.byTooltip('重做'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    await tester.tap(find.byTooltip('撤销'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    await tester.tap(find.byKey(const ValueKey('edit-tool-flip')));
    await tester.pump();
    final flipShortcut = find.byTooltip('水平翻转');
    expect(
        find.ancestor(
            of: flipShortcut, matching: find.byType(PhotoEditPreview)),
        findsOneWidget);
    await tester.tap(flipShortcut);
    await tester.pump();
    expect(
        tester
            .widget<PhotoEditPreview>(find.byType(PhotoEditPreview))
            .controller
            .value
            .flipHorizontal,
        isTrue);
    await tester.tap(find.byTooltip('撤销'));
    await tester.pump();
    expect(
        tester
            .widget<PhotoEditPreview>(find.byType(PhotoEditPreview))
            .controller
            .value
            .flipHorizontal,
        isFalse);
    await tester.tap(find.byTooltip('重做'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    await tester.tap(find.byTooltip('撤销'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    await capture(tester, captureKey, 'editor-light');
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(320, 640);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PhotoEditToolsPanel)).height, 220);
    // 900x430 宽度 ≥ 600 → 平板侧栏布局：工具面板进入右侧侧栏，不再是底部 156 面板。
    tester.view.physicalSize = const Size(900, 430);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('adaptiveSidePanel')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('真实裁切拖拽保持比例，扭曲拖拽累计位移', (tester) async {
    final controller = PhotoEditController();
    await tester.runAsync(() => controller.load(photoBytes()));
    controller.setCropOverlay(true);
    controller
        .update(controller.value.copyWith(crop: cropRectForAspect(1, 40, 60)));
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 400,
                    height: 300,
                    child: PhotoEditPreview(
                        controller: controller,
                        activeTool: PhotoEditTool.crop,
                        cropAspect: 1))))));
    await tester.drag(
        find.byKey(const ValueKey('crop-handle-3')), const Offset(-50, -20));
    final crop = controller.value.crop;
    expect(crop.width * 40 / (crop.height * 60), closeTo(1, .001));
    expect(crop.width, lessThan(1));
    controller.reset();
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 400,
                    height: 300,
                    child: PhotoEditPreview(
                        controller: controller,
                        activeTool: PhotoEditTool.distort))))));
    await tester.drag(
        find.byKey(const ValueKey('distort-handle-0')), const Offset(40, 30));
    expect(controller.value.distortTopLeftX, greaterThan(.15));
    expect(controller.value.distortTopLeftY, greaterThan(.05));
    controller.undo();
    expect(controller.value.hasDistortion, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('工坊仅有上方编辑预览，切换 Tab 保留编辑', (tester) async {
    final captureKey = GlobalKey();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: RepaintBoundary(
            key: captureKey,
            child: WatermarkScreen(initialImageBytes: photoBytes()))));
    await waitPreview(tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
    await tester.tap(find.text('裁切几何'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoEditPreview), findsOneWidget);
    expect(find.text('应用编辑到工作图'), findsNothing);
    final toolBounds = tester.getRect(find.byType(PhotoEditToolsPanel));
    final workshopImageRect = tester.getRect(find.byType(RawImage));
    await tester.tap(find.byTooltip('右转 90°'));
    await tester.pump();
    await waitPreview(tester, () => previewWidth(tester, 40));
    expect(tester.getRect(find.byType(RawImage)), workshopImageRect,
        reason: '工坊旋转也不能改变固定图片画框');
    expect(tester.getRect(find.byType(PhotoEditToolsPanel)), toolBounds,
        reason: '照片横竖变化不能移动或压缩下方面板');
    await tester.tap(find.text('画框版式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('裁切几何'));
    await tester.pumpAndSettle();
    expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 40);
    await capture(tester, captureKey, 'studio-editor-light');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('覆盖失败明确回退另存，保存后记录可读取', (tester) async {
    failOverwrite = true;
    PhotoEditResult? result;
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await Navigator.push<PhotoEditResult>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PhotoEditorScreen(
                                  item: item(), bytes: photoBytes())));
                    },
                    child: const Text('打开编辑'))))));
    await tester.tap(find.text('打开编辑'));
    await tester.pump(const Duration(milliseconds: 300));
    await waitPreview(
        tester, () => find.byType(RawImage).evaluate().isNotEmpty);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('覆盖原图'));
    await tester.pump();
    await waitPreview(tester, () => result != null);
    await tester.pumpAndSettle();
    expect(result!.mode, PhotoEditSaveMode.saveAsCopy);
    expect(result!.overwriteFallback, isTrue);
    expect(result!.fileName, contains('_edit_'));
    expect(result!.file.existsSync(), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('浅色连接成功页与相册筛选按钮文字可读', (tester) async {
    final driver = CountingDriver(photoBytes());
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: ConnectScreen(driver: driver, onConnected: () {})));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('CURRENT CAMERA'));
    expect(label.style!.color, ZyncPalette.light.textSecondary);
    await tester.pumpWidget(const SizedBox());
    final downloads = DownloadManager(driver: driver);
    final shoot =
        ShootAndTransferController(driver: driver, downloadManager: downloads);
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: GalleryScreen(
            driver: driver,
            downloadManager: downloads,
            shootAndTransferController: shoot)));
    await tester.pumpAndSettle();
    final filter = find.text('未同步');
    expect(filter, findsOneWidget);
    expect(tester.widget<Text>(filter).style!.color,
        ZyncPalette.light.textSecondary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    shoot.dispose();
    downloads.dispose();
  });

  testWidgets('更新弹窗在打开时切换主题，正文即时变色', (tester) async {
    final brightness = ValueNotifier(false);
    addTearDown(brightness.dispose);
    await tester.pumpWidget(ValueListenableBuilder<bool>(
        valueListenable: brightness,
        builder: (context, dark, _) => MaterialApp(
            theme: ZyncTheme.lightTheme,
            darkTheme: ZyncTheme.darkTheme,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(
                body: AppUpdateDialog(
                    releaseInfo: AppReleaseInfo(
                        tagName: 'v1.3.0',
                        versionName: '1.3.0',
                        title: '更新',
                        changelog: '修复主题',
                        downloadUrl: '',
                        releasePageUrl: '',
                        sourceName: 'GitHub'))))));
    expect(tester.widget<Text>(find.text('发现新版本')).style!.color,
        ZyncPalette.light.textPrimary);
    brightness.value = true;
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('发现新版本')).style!.color,
        ZyncPalette.dark.textPrimary);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
