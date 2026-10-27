import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/watermark/watermark_renderer.dart';
import 'package:zync/engine/watermark/watermark_template.dart';

img.Image _photoLike(int w, int h) {
  final frame = img.Image(width: w, height: h);
  var seed = 24681357;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final n = seed % 120;
      frame.setPixelRgb(x, y, (x * 255 ~/ w + n).clamp(0, 255),
          (y * 255 ~/ h + n).clamp(0, 255), ((x + y) % 255));
    }
  }
  return frame;
}

Future<ui.Image> _toUiImage(img.Image frame) async {
  final codec = await ui.instantiateImageCodec(
      Uint8List.fromList(img.encodePng(frame)));
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

const _meta = PhotoMetadata(
  cameraMake: 'Nikon',
  cameraModel: 'Z 30',
  lensModel: 'NIKKOR Z 40mm f/2',
  shutterSpeed: '1/250s',
  aperture: 'f/2.8',
  iso: 'ISO 400',
  focalLength: '40mm',
  capturedDate: '2026.10.14 10:30',
);

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('zync_wm_custom_');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async => dir.path);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets('自定义文字与 Logo 会渲染进导出成品', (tester) async {
    final source = _photoLike(320, 240);
    final logoFrame = img.Image(width: 64, height: 32);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 64; x++) {
        logoFrame.setPixelRgb(x, y, 255, 255, 255);
      }
    }

    final result = await tester.runAsync(() async {
      final img0 = await _toUiImage(source);
      final logo = await _toUiImage(logoFrame);
      try {
        final plain = await WatermarkRenderer.exportWatermarkedPhoto(
          sourceImage: img0,
          metadata: _meta,
          template: WatermarkTemplate.none,
          spacingScale: 1.0,
          showDetails: false,
        );
        final custom = await WatermarkRenderer.exportWatermarkedPhoto(
          sourceImage: img0,
          metadata: _meta,
          template: WatermarkTemplate.none,
          spacingScale: 1.0,
          showDetails: false,
          customLines: const ['© 2026 Zync', 'NIKKOR Z 40mm'],
          customTextScale: 1.4,
          logoImage: logo,
          logoScale: 0.24,
          logoOpacity: 1.0,
        );
        return [plain, custom];
      } finally {
        img0.dispose();
        logo.dispose();
      }
    });

    expect(result, isNotNull);
    final plainBytes = result![0].file.readAsBytesSync();
    final customBytes = result[1].file.readAsBytesSync();
    expect(customBytes.length, isNot(plainBytes.length),
        reason: '叠加自定义图层后成品内容必须变化');
    expect(result[1].file.path, endsWith('.jpg'));
  });

  testWidgets('导出会写回关键拍摄参数 EXIF', (tester) async {
    final source = _photoLike(240, 180);

    final bytes = await tester.runAsync(() async {
      final image = await _toUiImage(source);
      try {
        final r = await WatermarkRenderer.exportWatermarkedPhoto(
          sourceImage: image,
          metadata: _meta,
          template: WatermarkTemplate.none,
          spacingScale: 1.0,
          showDetails: false,
        );
        return r.file.readAsBytesSync();
      } finally {
        image.dispose();
      }
    });

    expect(bytes, isNotNull);
    final tags = await readExifFromBytes(bytes!);
    expect(tags['Image Make']?.printable, 'Nikon');
    expect(tags['Image Model']?.printable, 'Z 30');
    // 方向值 1 在 exif 包里显示为 Horizontal (normal)
    expect(tags['Image Orientation']?.printable, contains('Horizontal'),
        reason: '像素已按方向烘焙，方向必须归 1 以免二次旋转');
    final iso = tags.entries.where((e) => e.key.contains('ISO')).toList();
    expect(iso, isNotEmpty, reason: 'ISO 应写入 EXIF');
    expect(iso.first.value.printable, contains('400'));

    final fNumber = tags.entries.where((e) => e.key.contains('FNumber')).toList();
    expect(fNumber, isNotEmpty, reason: '光圈应写入 EXIF');
    // 光圈以有理数写入（f/2.8 → 14/5），只要求存在且非空
    expect(fNumber.first.value.printable, isNotEmpty);
  });
}
