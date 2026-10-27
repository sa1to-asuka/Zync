import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/watermark/watermark_renderer.dart';
import 'package:zync/engine/watermark/watermark_template.dart';

img.Image _photoLike(int w, int h) {
  final frame = img.Image(width: w, height: h);
  var seed = 86421357;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final n = seed % 100;
      frame.setPixelRgb(
        x,
        y,
        (x * 255 ~/ w + n).clamp(0, 255),
        (y * 255 ~/ h + n).clamp(0, 255),
        ((x + y) % 255),
      );
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
    dir = Directory.systemTemp.createTempSync('zync_wm_style_');
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async => dir.path);
    AppSettings.instance.resetForTest();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    AppSettings.instance.resetForTest();
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Windows 上后台设置落盘可能仍持有短暂文件句柄，清理失败不影响测试结论。
    }
  });

  testWidgets('边框色与字体色会改变所有剩余无边框模板', (tester) async {
    final source = _photoLike(240, 180);
    final result = await tester.runAsync(() async {
      final image = await _toUiImage(source);
      try {
        Future<Uint8List> export(
          WatermarkTemplate template, {
          Color? card,
          Color? text,
        }) async {
          final r = await WatermarkRenderer.exportWatermarkedPhoto(
            sourceImage: image,
            metadata: _meta,
            template: template,
            cardColorOverride: card,
            textColorOverride: text,
          );
          return r.file.readAsBytesSync();
        }

        final inPhotoPlain = await export(WatermarkTemplate.inPhotoOverlay);
        final inPhotoColor = await export(
          WatermarkTemplate.inPhotoOverlay,
          card: const Color(0xFF37C6FF),
          text: const Color(0xFFFFD100),
        );
        final gradientPlain = await export(WatermarkTemplate.gradientCaption);
        final gradientColor = await export(
          WatermarkTemplate.gradientCaption,
          card: const Color(0xFF37C6FF),
          text: const Color(0xFFFFD100),
        );
        final minimalPlain = await export(WatermarkTemplate.minimalLine);
        final minimalColor = await export(
          WatermarkTemplate.minimalLine,
          card: const Color(0xFF37C6FF),
          text: const Color(0xFFFFD100),
        );
        return [
          inPhotoPlain,
          inPhotoColor,
          gradientPlain,
          gradientColor,
          minimalPlain,
          minimalColor,
        ];
      } finally {
        image.dispose();
      }
    });

    expect(result, isNotNull);
    final bytes = result!;
    expect(bytes[1], isNot(equals(bytes[0])));
    expect(bytes[3], isNot(equals(bytes[2])));
    expect(bytes[5], isNot(equals(bytes[4])));
  });

  testWidgets('字号、字距、行距、字重与线条厚度会改变成品', (tester) async {
    final source = _photoLike(240, 180);
    final result = await tester.runAsync(() async {
      final image = await _toUiImage(source);
      try {
        Future<Uint8List> export({
          WatermarkTemplate template = WatermarkTemplate.magazineCover,
          double title = 1.0,
          double meta = 1.0,
          double letter = 1.0,
          double line = 1.0,
          double border = 1.0,
          WatermarkFontWeight weight = WatermarkFontWeight.auto,
          List<String> customLines = const [],
          double customScale = 1.0,
        }) async {
          final r = await WatermarkRenderer.exportWatermarkedPhoto(
            sourceImage: image,
            metadata: _meta,
            template: template,
            titleTextScale: title,
            metaTextScale: meta,
            letterSpacingScale: letter,
            lineSpacingScale: line,
            borderThicknessScale: border,
            fontWeight: weight,
            customLines: customLines,
            customTextScale: customScale,
          );
          return r.file.readAsBytesSync();
        }

        final plain = await export();
        final typography = await export(
          title: 1.35,
          meta: 0.8,
          letter: 1.4,
          line: 1.2,
          weight: WatermarkFontWeight.black,
        );
        final borderPlain = await export(
            template: WatermarkTemplate.darkGlassBlur);
        final borderThick = await export(
          template: WatermarkTemplate.darkGlassBlur,
          border: 2.0,
        );
        final customPlain = await export(
          customLines: const ['© 2026 Zync'],
          customScale: 1.0,
        );
        final customLarge = await export(
          customLines: const ['© 2026 Zync'],
          customScale: 1.4,
        );
        return [plain, typography, borderPlain, borderThick, customPlain, customLarge];
      } finally {
        image.dispose();
      }
    });

    expect(result, isNotNull);
    final bytes = result!;
    expect(bytes[1], isNot(equals(bytes[0])));
    expect(bytes[3], isNot(equals(bytes[2])));
    expect(bytes[5], isNot(equals(bytes[4])));
  });

  testWidgets('水印标量设置可持久化并归一化非法值', (tester) async {
    final s = AppSettings.instance;
    s.updateWatermarkStyle(
      cardColorValue: 0xFF123456,
      textColorValue: 0xFFFFFFFF,
      titleTextScale: 1.25,
      metaTextScale: 9.0,
      customLine1: '© 2026 Zync',
      fontWeightIndex: 99,
      opacity: 0.1,
    );

    expect(s.watermarkCardColorValue, 0xFF123456);
    expect(s.watermarkTitleTextScale, 1.25);
    expect(s.watermarkMetaTextScale, 1.5);
    expect(s.watermarkFontWeightIndex, 0);
    expect(s.watermarkOpacity, 0.5);

    await tester.runAsync(() async {
      await s.save();
      s.resetForTest();
      await s.load();
    });

    expect(s.watermarkCardColorValue, 0xFF123456);
    expect(s.watermarkTextColorValue, 0xFFFFFFFF);
    expect(s.watermarkCustomLine1, '© 2026 Zync');
    expect(s.watermarkMetaTextScale, 1.5);
    expect(s.watermarkFontWeightIndex, 0);
    expect(s.watermarkOpacity, 0.5);
  });
}
