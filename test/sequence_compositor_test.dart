import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/capture/sequence_compositor.dart';

/// 左右两半：一半是黑白竖条（高频），另一半是纯灰（没有细节）。
img.Image _halfSharp({required bool leftIsSharp, int value = 128}) {
  const width = 64;
  const height = 32;
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final isLeft = x < width ~/ 2;
      final sharp = isLeft == leftIsSharp;
      // 用 4 像素宽的方块，否则 1 像素条纹的 Sobel 梯度恒为 0。
      final v = sharp ? ((x ~/ 4).isEven ? 240 : 16) : value;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

img.Image _flat(int value, {int width = 32, int height = 16}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

/// 相邻像素的平均绝对差，作为「这块区域锐不锐」的代理指标。
double _localContrast(img.Image image, int fromX, int toX, int y) {
  var sum = 0.0;
  for (var x = fromX + 1; x < toX; x++) {
    final a = image.getPixel(x - 1, y).r;
    final b = image.getPixel(x, y).r;
    sum += (a - b).abs();
  }
  return sum / (toX - fromX - 1);
}

void main() {
  group('曝光融合', () {
    test('结果落在两张原图的中间，不会直接取某一张', () {
      final dark = _flat(20);
      final bright = _flat(230);

      final fused = SequenceCompositor.fuseExposures([dark, bright]);
      final value = fused.getPixel(10, 8).r;

      expect(value, greaterThan(20));
      expect(value, lessThan(230));
    });

    test('保留有细节的那一帧的纹理', () {
      final textured = _halfSharp(leftIsSharp: true, value: 128);
      final flatBright = _flat(200, width: 64, height: 32);

      final fused = SequenceCompositor.fuseExposures([textured, flatBright]);
      final left = _localContrast(fused, 4, 28, 8);

      expect(left, greaterThan(30), reason: '高对比区域应该保留下来');
    });

    test('两张全黑也不会除零崩溃', () {
      final fused = SequenceCompositor.fuseExposures([_flat(0), _flat(0)]);
      expect(fused.getPixel(4, 4).r, 0);
    });
  });

  group('焦点堆叠', () {
    test('左半清晰、右半清晰的两张合成后两边都清晰', () {
      final leftSharp = _halfSharp(leftIsSharp: true);
      final rightSharp = _halfSharp(leftIsSharp: false);

      final fused =
          SequenceCompositor.fuseFocusStack([leftSharp, rightSharp]);

      expect(_localContrast(fused, 4, 28, 8), greaterThan(40));
      expect(_localContrast(fused, 36, 60, 8), greaterThan(40));
    });

    test('整片无纹理时取中间帧而不是输出黑图', () {
      final fused = SequenceCompositor.fuseFocusStack(
        [_flat(30), _flat(90), _flat(150)],
      );
      expect(fused.getPixel(4, 4).r, 90);
    });
  });

  group('合成入口', () {
    test('少于两张直接失败', () {
      final result = SequenceCompositor.composeFrames(
        [_flat(10)],
        mode: SequenceCompositeMode.exposureFusion,
      );
      expect(result.isSuccess, isFalse);
    });

    test('尺寸不一致的帧会被丢弃，不足两张则失败', () {
      final result = SequenceCompositor.composeFrames(
        [_flat(10, width: 32, height: 16), _flat(10, width: 40, height: 16)],
        mode: SequenceCompositeMode.focusStack,
      );
      expect(result.isSuccess, isFalse);
    });

    test('两张正常帧能产出可解码的 JPEG', () {
      final result = SequenceCompositor.composeFrames(
        [_flat(40), _flat(200)],
        mode: SequenceCompositeMode.exposureFusion,
      );
      expect(result.isSuccess, isTrue);
      expect(result.width, 32);
      expect(result.height, 16);
      expect(img.decodeJpg(result.bytes!), isNotNull);
    });
  });
}
