import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/exif_helper.dart';

Uint8List _jpegWithExposure(int numerator, int denominator) {
  final exif = img.ExifData();
  exif.exifIfd[0x829A] = img.IfdValueRational(numerator, denominator);
  final image = img.Image(width: 8, height: 8)..exif = exif;
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  test('快门速度有理数规范化为 1/xxx s', () async {
    final cases = <List<int>, String>{
      [975447, 100000000]: '1/103s',
      [1, 250]: '1/250s',
      [10, 2500]: '1/250s',
      [10, 1]: '10s',
      [13, 10]: '1.3s',
    };
    for (final entry in cases.entries) {
      final meta = await ExifHelper.parseBytes(
        _jpegWithExposure(entry.key[0], entry.key[1]),
      );
      expect(meta.shutterSpeed, entry.value,
          reason: '${entry.key[0]}/${entry.key[1]}');
    }
  });
}
