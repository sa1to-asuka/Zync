import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/raw_preview_extractor.dart';

/// 造一张有噪声、JPEG 压缩后足够大的照片式图（噪声保证体积 > 64KB）。
Uint8List _jpegOf(int size) {
  final frame = img.Image(width: size, height: size);
  var seed = 987654321;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      final n = seed % 255;
      frame.setPixelRgb(x, y, n, (n * 7) % 255, (n * 13) % 255);
    }
  }
  return Uint8List.fromList(img.encodeJpg(frame, quality: 95));
}

/// 模拟 NEF：TIFF 头 + 内嵌 JPEG + 尾随数据。
Uint8List _fakeNef(List<Uint8List> embedded) {
  final out = BytesBuilder();
  out.add(List<int>.filled(96, 0x4D)); // TIFF/IFD 占位
  for (final jpeg in embedded) {
    out.add(jpeg);
    out.add(List<int>.filled(24, 0x00));
  }
  out.add(List<int>.filled(64, 0x5A));
  return out.toBytes();
}

void main() {
  testWidgets('从 NEF 提取内嵌 JPEG（多候选取最大可解码）', (tester) async {
    final small = _jpegOf(220);
    final large = _jpegOf(360);
    expect(small.length, greaterThan(64 * 1024), reason: '测试素材需超过最小候选体积');
    expect(large.length, greaterThan(small.length));

    final nef = _fakeNef([small, large]);
    final extracted = await tester.runAsync(
        () => RawPreviewExtractor.extractEmbeddedJpeg(nef));

    expect(extracted, isNotNull);
    expect(extracted!.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(extracted.sublist(extracted.length - 2), <int>[0xFF, 0xD9]);
    expect(extracted.length, large.length, reason: '应取最大的候选');
    expect(extracted.sublist(0, 32), large.sublist(0, 32));
  });

  testWidgets('没有内嵌 JPEG 时返回 null 且不抛异常', (tester) async {
    final junk = Uint8List.fromList(List<int>.generate(200 * 1024, (i) => i % 251));
    final extracted = await tester.runAsync(
        () => RawPreviewExtractor.extractEmbeddedJpeg(junk));
    expect(extracted, isNull);
  });

  testWidgets('截断的 JPEG 候选会被跳过', (tester) async {
    final good = _jpegOf(360);
    // 只保留前半段（无 EOI）的坏候选 + 完整的好候选
    final broken = Uint8List.sublistView(good, 0, good.length ~/ 2);
    final nef = _fakeNef([broken, good]);

    final extracted = await tester.runAsync(
        () => RawPreviewExtractor.extractEmbeddedJpeg(nef));
    expect(extracted, isNotNull);
    expect(extracted!.length, good.length);
  });
}
