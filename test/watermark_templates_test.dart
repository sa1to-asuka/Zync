import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/watermark/camera_brand_emblem.dart';
import 'package:zync/engine/watermark/watermark_painter.dart';
import 'package:zync/engine/watermark/watermark_renderer.dart';
import 'package:zync/engine/watermark/watermark_template.dart';

img.Image _photoLike(int w, int h) {
  final frame = img.Image(width: w, height: h);
  var seed = 13572468;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final n = seed % 110;
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
    dir = Directory.systemTemp.createTempSync('zync_wm_tpl_');
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

  test('新模板与 6 款开源致敬模板都参与排版计算且画布有效', () {
    const templates = [
      WatermarkTemplate.magazineCover,
      WatermarkTemplate.gradientCaption,
      WatermarkTemplate.minimalLine,
      WatermarkTemplate.brandClassicWhite,
      WatermarkTemplate.brandEmblemCenter,
      WatermarkTemplate.blurFloatingShadow,
      WatermarkTemplate.minimalCornerParam,
      WatermarkTemplate.retroTimestamp,
      WatermarkTemplate.geoLocationEditorial,
    ];
    for (final t in templates) {
      final layout = WatermarkCanvasPainter.computeLayout(1200, 800, t, 1.0);
      expect(layout.totalWidth, greaterThan(0), reason: '${t.label} 画布宽度');
      expect(layout.totalHeight, greaterThan(0), reason: '${t.label} 画布高度');
      expect(layout.imageRect.width, greaterThan(0), reason: '${t.label} 图片区');
      expect(layout.imageRect.height, greaterThan(0), reason: '${t.label} 图片区');
      // 卡片类模板画布必须比照片本身大（留出标题/信息区）
      if (t == WatermarkTemplate.magazineCover ||
          t == WatermarkTemplate.brandClassicWhite ||
          t == WatermarkTemplate.brandEmblemCenter ||
          t == WatermarkTemplate.geoLocationEditorial) {
        expect(layout.totalHeight, greaterThan(layout.imageRect.height),
            reason: '${t.label} 应额外留出信息带');
      }
    }
    expect(
      CameraBrandEmblem.detect(const PhotoMetadata(
        cameraMake: 'NIKON CORPORATION',
        cameraModel: 'NIKON Z 8',
      )),
      equals(CameraBrandType.nikon),
    );
    expect(
      CameraBrandEmblem.detect(const PhotoMetadata(
        cameraMake: 'SONY',
        cameraModel: 'ILCE-7RM5',
      )),
      equals(CameraBrandType.sony),
    );
    expect(
      CameraBrandEmblem.detect(const PhotoMetadata(
        cameraMake: 'FUJIFILM',
        cameraModel: 'X100VI',
      )),
      equals(CameraBrandType.fujifilm),
    );
  });

  testWidgets('全部新增模板都能导出成品（含经纬度 EXIF）', (tester) async {
    final source = _photoLike(320, 240);
    const templates = [
      WatermarkTemplate.magazineCover,
      WatermarkTemplate.gradientCaption,
      WatermarkTemplate.minimalLine,
      WatermarkTemplate.brandClassicWhite,
      WatermarkTemplate.brandEmblemCenter,
      WatermarkTemplate.blurFloatingShadow,
      WatermarkTemplate.minimalCornerParam,
      WatermarkTemplate.retroTimestamp,
      WatermarkTemplate.geoLocationEditorial,
    ];
    final gpsMeta = _meta.copyWith(
      latitude: 31.230416,
      longitude: 121.473701,
      altitude: 12.0,
    );

    final sizes = await tester.runAsync(() async {
      final image = await _toUiImage(source);
      try {
        final out = <int>[];
        for (final t in templates) {
          final r = await WatermarkRenderer.exportWatermarkedPhoto(
            sourceImage: image,
            metadata: gpsMeta,
            template: t,
            spacingScale: 1.0,
            showDetails: true,
          );
          out.add(r.byteLength);
        }
        return out;
      } finally {
        image.dispose();
      }
    });

    expect(sizes, isNotNull);
    for (final size in sizes!) {
      expect(size, greaterThan(1000), reason: '每个模板都应产出有效 JPEG');
    }
  });

  testWidgets('内容开关与样式设置会改变成品', (tester) async {
    final source = _photoLike(320, 240);

    final results = await tester.runAsync(() async {
      final image = await _toUiImage(source);
      try {
        Future<Uint8List> export({
          bool showModel = true,
          bool showExposure = true,
          double opacity = 1.0,
          double corner = 1.0,
          Color accent = const Color(0xFFFFD100),
          WatermarkCardTone tone = WatermarkCardTone.auto,
        }) async {
          final r = await WatermarkRenderer.exportWatermarkedPhoto(
            sourceImage: image,
            metadata: _meta,
            template: WatermarkTemplate.magazineCover,
            spacingScale: 1.0,
            showDetails: true,
            showModel: showModel,
            showExposure: showExposure,
            watermarkOpacity: opacity,
            cornerRadiusFactor: corner,
            accentColor: accent,
            cardTone: tone,
          );
          return r.file.readAsBytesSync();
        }

        final baseline = await export();
        return <String, Uint8List>{
          'baseline': baseline,
          'noModel': await export(showModel: false),
          'noExposure': await export(showExposure: false),
          'faded': await export(opacity: 0.7),
          'square': await export(corner: 0.0),
          'cyan': await export(accent: const Color(0xFF37C6FF)),
          'black': await export(tone: WatermarkCardTone.black),
        };
      } finally {
        image.dispose();
      }
    });

    expect(results, isNotNull);
    final base = results!['baseline']!;
    for (final key in ['noModel', 'noExposure', 'faded', 'square', 'cyan', 'black']) {
      expect(results[key], isNot(equals(base)),
          reason: '$key 设置应改变成品像素');
    }
  });
}
