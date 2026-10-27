import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/progressive_jpeg.dart';

void main() {
  test('截断 JPEG 也能容错解码出可辨认预览 (渐进预览提速的关键)', () async {
    final source = img.Image(width: 1200, height: 800);
    img.fill(source, color: img.ColorRgb8(30, 90, 200));
    final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 92));

    // 只保留前 35% 字节，模拟 GetPartialObject 局部下载
    final partial = Uint8List.sublistView(jpeg, 0, (jpeg.length * 0.35).round());
    final decoded = await ProgressiveJpeg.decodeLenient(partial);
    expect(decoded, isNotNull, reason: 'image 包应能容错解码截断 JPEG');
    expect(decoded!.width, equals(1200));
    expect(decoded.height, equals(800));
  });

  test('带 EXIF Orientation 的片段解码后方向已被烘焙 (竖拍不躺倒)', () async {
    final source = img.Image(width: 800, height: 400);
    img.fill(source, color: img.ColorRgb8(200, 60, 60));
    source.exif.imageIfd.orientation = 6; // 需顺时针 90°，成品应为 400x800
    final jpeg = Uint8List.fromList(img.encodeJpg(source, quality: 92));
    final decoded = await ProgressiveJpeg.decodeLenient(jpeg);
    expect(decoded, isNotNull);
    expect(decoded!.height, greaterThan(decoded.width),
        reason: 'Orientation=6 必须被烘焙为竖向像素');
  });

  test('非 JPEG 片段返回 null，调用方回退到缩略图', () async {
    final notJpeg = Uint8List.fromList([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]);
    expect(await ProgressiveJpeg.decodeLenient(notJpeg), isNull);
  });
}