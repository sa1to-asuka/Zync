import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/widgets/grade_thumbnail.dart';

void main() {
  testWidgets('非方形图片也固定采样为 48×48，供预设缩略图使用', (tester) async {
    final image = img.Image(width: 96, height: 54);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, x % 256, y % 256, 80);
      }
    }
    final png = Uint8List.fromList(img.encodePng(image));

    final sample = await tester.runAsync(
      () => sampleGradePixelsFromJpeg(png),
    );

    expect(sample, isNotNull);
    expect(sample!.r.length, kGradeSampleSide * kGradeSampleSide);
    expect(sample.g.length, sample.r.length);
    expect(sample.b.length, sample.r.length);
  });
}
