import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/watermark/watermark_renderer.dart';
import 'package:zync/engine/watermark/watermark_template.dart';

/// 造一张「有真实细节」的照片式图：渐变 + 伪随机噪声。
/// 噪声对 PNG 几乎不可压缩，对 JPEG 才是正常照片的压缩率。
img.Image _photoLikeFrame(int w, int h) {
  final frame = img.Image(width: w, height: h);
  var seed = 123456789;
  int next() {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return seed;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final noise = next() % 96 - 48;
      frame.setPixelRgb(
        x,
        y,
        ((x * 255 ~/ w) + noise).clamp(0, 255),
        ((y * 255 ~/ h) + noise).clamp(0, 255),
        (((x ^ y) & 0xFF) + noise).clamp(0, 255),
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

void main() {
  testWidgets('水印导出成品是 JPEG，体积不再膨胀成 PNG', (tester) async {
    final dir = Directory.systemTemp.createTempSync('zync_export_fmt_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async => dir.path);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null));

    const size = 512;
    final frame = _photoLikeFrame(size, size);
    final pngBytes = img.encodePng(frame);

    final result = await tester.runAsync(() async {
      final source = await _toUiImage(frame);
      try {
        return await WatermarkRenderer.exportWatermarkedPhoto(
          sourceImage: source,
          metadata: const PhotoMetadata(cameraModel: 'Z 30'),
          template: WatermarkTemplate.none,
          spacingScale: 1.0,
          showDetails: false,
        );
      } finally {
        source.dispose();
      }
    });

    expect(result, isNotNull);
    final exported = result!;
    expect(exported.file.path, endsWith('.jpg'),
        reason: '成品应为 JPEG，而不是被撑大的 PNG');

    final bytes = exported.file.readAsBytesSync();
    expect(bytes.length, exported.byteLength);
    // JPEG 文件头 SOI / 结尾 EOI
    expect(bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(bytes.sublist(bytes.length - 2), <int>[0xFF, 0xD9]);
    // 同样的照片内容：JPEG 必须明显小于 PNG（这正是用户遇到的 10MB → 20MB 问题）
    expect(exported.byteLength, lessThan(pngBytes.length),
        reason: '照片类内容下 JPEG 应小于 PNG');
    expect(exported.byteLength, lessThan(exported.width * exported.height * 3),
        reason: '不应输出未压缩像素');
  });

  testWidgets('jpegQuality 参数生效：低质量更小', (tester) async {
    final dir = Directory.systemTemp.createTempSync('zync_export_q_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    const paths = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async => dir.path);
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, null));

    final frame = _photoLikeFrame(320, 320);

    final sizes = await tester.runAsync(() async {
      final out = <int>[];
      for (final q in <int>[50, 95]) {
        final source = await _toUiImage(frame);
        try {
          final r = await WatermarkRenderer.exportWatermarkedPhoto(
            sourceImage: source,
            metadata: const PhotoMetadata(cameraModel: 'Z 30'),
            template: WatermarkTemplate.none,
            spacingScale: 1.0,
            showDetails: false,
            jpegQuality: q,
          );
          out.add(r.byteLength);
        } finally {
          source.dispose();
        }
      }
      return out;
    });

    expect(sizes, isNotNull);
    expect(sizes![0], lessThan(sizes[1]),
        reason: 'quality 50 的成品必须小于 quality 95');
  });
}
