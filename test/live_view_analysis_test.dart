import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/liveview/live_view_analysis.dart';

Uint8List _rgbaFromLuma(int width, int height, int Function(int x, int y) luma) {
  final bytes = Uint8List(width * height * 4);
  var offset = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final v = luma(x, y).clamp(0, 255);
      bytes[offset] = v;
      bytes[offset + 1] = v;
      bytes[offset + 2] = v;
      bytes[offset + 3] = 255;
      offset += 4;
    }
  }
  return bytes;
}

void main() {
  group('computeLuma', () {
    test('纯灰 128 精确落在第 128 桶（系数和为 256）', () {
      final rgba = _rgbaFromLuma(4, 4, (_, __) => 128);
      final luma = computeLuma(rgba, 4, 4);
      expect(luma.every((v) => v == 128), isTrue);
    });

    test('亮度按 54/183/19 加权', () {
      final rgba = Uint8List.fromList(<int>[255, 0, 0, 255]);
      final luma = computeLuma(rgba, 1, 1);
      expect(luma[0], 53); // 255*54>>8 = 53
    });
  });

  group('computeSobelMagnitude', () {
    test('平坦画面没有边缘', () {
      final luma = Uint8List(16 * 8)..fillRange(0, 16 * 8, 120);
      final magnitude = computeSobelMagnitude(luma, 16, 8);
      expect(magnitude.every((v) => v == 0), isTrue);
    });

    test('竖直明暗边界产生梯度，边缘一圈留 0', () {
      const w = 16;
      const h = 8;
      final luma = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          luma[y * w + x] = x < 8 ? 0 : 255;
        }
      }
      final magnitude = computeSobelMagnitude(luma, w, h);

      // 边界两侧的像素应有明显梯度。
      expect(magnitude[4 * w + 7], greaterThan(100));
      expect(magnitude[4 * w + 8], greaterThan(100));
      // 远离边界与最外圈应为 0。
      expect(magnitude[4 * w + 2], 0);
      expect(magnitude[0], 0);
      expect(magnitude[(h - 1) * w + (w - 1)], 0);
    });

    test('尺寸小于 3 时不越界', () {
      final magnitude = computeSobelMagnitude(Uint8List(4), 2, 2);
      expect(magnitude.length, 4);
      expect(magnitude.every((v) => v == 0), isTrue);
    });
  });

  group('computeFocusPeakMask', () {
    test('阈值越高命中越少', () {
      const w = 16;
      const h = 8;
      final luma = Uint8List(w * h);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          luma[y * w + x] = x < 8 ? 0 : 255;
        }
      }
      final sensitive = computeFocusPeakMask(luma, w, h, 100);
      final strict = computeFocusPeakMask(luma, w, h, 100000);

      expect(sensitive.any((v) => v == 1), isTrue);
      expect(strict.any((v) => v == 1), isFalse);
    });
  });

  group('analyzeRgbaPixels', () {
    test('直方图与像素总数一致', () {
      final rgba = _rgbaFromLuma(8, 4, (x, _) => x * 8);
      final result = analyzeRgbaPixels(
          rgba, 8, 4, const LiveViewAnalysisSettings());
      final total = result.histogram.fold<int>(0, (a, b) => a + b);
      expect(total, 32);
      expect(result.overlayRgba, isNull);
    });

    test('纯灰画面的直方图集中在一个桶', () {
      final rgba = _rgbaFromLuma(4, 4, (_, __) => 128);
      final result = analyzeRgbaPixels(
          rgba, 4, 4, const LiveViewAnalysisSettings());
      expect(result.histogram[128], 16);
      expect(result.histogram[0], 0);
    });

    test('斑马纹只标记过曝且落在条纹上的像素', () {
      const w = 16;
      const h = 8;
      final rgba = _rgbaFromLuma(w, h, (x, _) => x < 8 ? 100 : 240);
      final result = analyzeRgbaPixels(
        rgba,
        w,
        h,
        const LiveViewAnalysisSettings(zebra: true, zebraThreshold: 235),
      );

      expect(result.overexposedPixels, 8 * 8);
      final overlay = result.overlayRgba!;
      var marked = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final alpha = overlay[(y * w + x) * 4 + 3];
          if (alpha == 0) continue;
          marked++;
          expect(x, greaterThanOrEqualTo(8), reason: '暗部不应被标记');
          expect(
            (x + y) % LiveViewAnalysisSettings.zebraPeriod,
            lessThan(LiveViewAnalysisSettings.zebraStripeWidth),
          );
        }
      }
      expect(marked, greaterThan(0));
    });

    test('峰值命中边缘且输出为预乘 RGBA', () {
      const w = 16;
      const h = 8;
      final rgba = _rgbaFromLuma(w, h, (x, _) => x < 8 ? 0 : 255);
      final result = analyzeRgbaPixels(
        rgba,
        w,
        h,
        const LiveViewAnalysisSettings(
          focusPeaking: true,
          peakThreshold: 100,
          peakColor: 0x80FF0000,
        ),
      );

      final overlay = result.overlayRgba!;
      // 边界第 7 列应被标记
      final index = (4 * w + 7) * 4;
      expect(overlay[index + 3], 0x80);
      // 预乘：R = 255 * 0x80 / 255 = 128
      expect(overlay[index], 128);
      expect(overlay[index + 1], 0);
      expect(overlay[index + 2], 0);
    });

    test('峰值与斑马纹都关闭时不生成叠加图', () {
      final rgba = _rgbaFromLuma(4, 4, (_, __) => 200);
      final result = analyzeRgbaPixels(
        rgba,
        4,
        4,
        const LiveViewAnalysisSettings(histogram: true),
      );
      expect(result.overlayRgba, isNull);
    });
  });

  group('LiveViewAnalysisSettings', () {
    test('值相等性可用于 ValueNotifier', () {
      const a = LiveViewAnalysisSettings(focusPeaking: true);
      const b = LiveViewAnalysisSettings(focusPeaking: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('anyEnabled 反映开关组合', () {
      expect(const LiveViewAnalysisSettings().anyEnabled, isFalse);
      expect(const LiveViewAnalysisSettings(histogram: true).anyEnabled, isTrue);
      expect(const LiveViewAnalysisSettings(zebra: true).hasOverlay, isTrue);
    });
  });
}
