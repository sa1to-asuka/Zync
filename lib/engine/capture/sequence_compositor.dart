import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 序列合成方式。
enum SequenceCompositeMode {
  /// 包围曝光：按「对比度 × 饱和度 × 曝光适中度」加权融合，
  /// 保住暗部细节的同时不把高光烧掉。
  exposureFusion,

  /// 焦点堆叠：逐像素挑局部最锐利的那一帧，得到全画面都实的照片。
  focusStack,
}

/// 合成失败的原因（给 UI 用）。
class SequenceCompositeResult {
  const SequenceCompositeResult({
    this.bytes,
    this.width = 0,
    this.height = 0,
  });

  final Uint8List? bytes;
  final int width;
  final int height;

  bool get isSuccess => bytes != null && bytes!.isNotEmpty;
}

/// 把一组已经缩放好的帧合成一张。
///
/// 解码必须由调用方用 Flutter 引擎的 `instantiateCodec(targetWidth:)` 完成：
/// 24MP 的 9 张图用 `package:image` 全尺寸解码会吃掉几百 MB，手机上直接 OOM。
/// 这里只负责像素运算，所以能在单测里用合成图直接验证。
abstract final class SequenceCompositor {
  /// 合成用的工作长边。再大收益有限，内存却线性上涨。
  static const int defaultMaxEdge = 1280;

  /// 融合所需的曝光适中度曲线宽度。
  static const double _wellExposedSigma = 0.2;

  static SequenceCompositeResult composeFrames(
    List<img.Image> frames, {
    required SequenceCompositeMode mode,
  }) {
    if (frames.length < 2) {
      return const SequenceCompositeResult();
    }

    // 尺寸必须一致才能逐像素融合；不一致的直接丢弃而不是拉伸对齐。
    final width = frames.first.width;
    final height = frames.first.height;
    final usable = frames
        .where((f) => f.width == width && f.height == height)
        .toList(growable: false);
    if (usable.length < 2) {
      return const SequenceCompositeResult();
    }

    final merged = switch (mode) {
      SequenceCompositeMode.exposureFusion => fuseExposures(usable),
      SequenceCompositeMode.focusStack => fuseFocusStack(usable),
    };

    final bytes = img.encodeJpg(merged, quality: 92);
    return SequenceCompositeResult(
      bytes: bytes,
      width: merged.width,
      height: merged.height,
    );
  }

  /// 曝光融合（单尺度近似版 Mertens）。
  ///
  /// 逐像素算三组权重：局部对比度、色彩饱和度、曝光适中度。
  /// 权重归一化后加权平均，比「直接平均」更能保住高光与暗部细节。
  static img.Image fuseExposures(List<img.Image> frames) {
    final width = frames.first.width;
    final height = frames.first.height;
    final out = img.Image(width: width, height: height, numChannels: 3);

    final lumas = frames.map(_lumaMap).toList(growable: false);
    final contrasts =
        lumas.map((l) => _laplacianMagnitude(l, width, height)).toList();

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        double sumW = 0;
        double r = 0;
        double g = 0;
        double b = 0;
        for (var i = 0; i < frames.length; i++) {
          final pixel = frames[i].getPixel(x, y);
          final luma = lumas[i][index];
          final contrast = contrasts[i][index];
          final saturation = _saturation(pixel.r, pixel.g, pixel.b);
          final wellExposed = _wellExposed(luma);
          final weight = (contrast + 0.02) * (saturation + 0.05) * wellExposed;
          sumW += weight;
          r += weight * pixel.r;
          g += weight * pixel.g;
          b += weight * pixel.b;
        }
        if (sumW <= 1e-6) {
          // 全部权重都接近 0（例如三张全黑）：退化为平均，避免输出纯黑。
          final pixel = frames.first.getPixel(x, y);
          out.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
          continue;
        }
        out.setPixelRgb(x, y, r / sumW, g / sumW, b / sumW);
      }
    }
    return out;
  }

  /// 焦点堆叠：按局部锐度做加权平均。
  ///
  /// 权重取锐度的 4 次方，让「略锐一点」的像素也能主导输出；
  /// 这样焦平面过渡处不会出现硬边。
  static img.Image fuseFocusStack(List<img.Image> frames) {
    final width = frames.first.width;
    final height = frames.first.height;
    final out = img.Image(width: width, height: height, numChannels: 3);

    final sharpness = frames
        .map((f) => _blur3x3(
            _laplacianMagnitude(_lumaMap(f), width, height), width, height))
        .toList(growable: false);

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final index = y * width + x;
        double sumW = 0;
        double r = 0;
        double g = 0;
        double b = 0;
        for (var i = 0; i < frames.length; i++) {
          final s = sharpness[i][index];
          final weight = s * s * s * s;
          sumW += weight;
          final pixel = frames[i].getPixel(x, y);
          r += weight * pixel.r;
          g += weight * pixel.g;
          b += weight * pixel.b;
        }
        if (sumW <= 1e-6) {
          // 整片都没有纹理（纯色背景）：取中间那一帧即可。
          final pixel = frames[frames.length ~/ 2].getPixel(x, y);
          out.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
          continue;
        }
        out.setPixelRgb(x, y, r / sumW, g / sumW, b / sumW);
      }
    }
    return out;
  }

  static Float64List _lumaMap(img.Image image) {
    final width = image.width;
    final height = image.height;
    final luma = Float64List(width * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final p = image.getPixel(x, y);
        luma[y * width + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      }
    }
    return luma;
  }

  /// 3×3 Sobel 梯度幅值，用作局部对比度。
  static Float64List _laplacianMagnitude(
      Float64List luma, int width, int height) {
    final out = Float64List(width * height);
    for (var y = 1; y < height - 1; y++) {
      final row = y * width;
      for (var x = 1; x < width - 1; x++) {
        final tl = luma[row - width + x - 1];
        final tc = luma[row - width + x];
        final tr = luma[row - width + x + 1];
        final ml = luma[row + x - 1];
        final mr = luma[row + x + 1];
        final bl = luma[row + width + x - 1];
        final bc = luma[row + width + x];
        final br = luma[row + width + x + 1];

        final gx = (tr + 2 * mr + br) - (tl + 2 * ml + bl);
        final gy = (bl + 2 * bc + br) - (tl + 2 * tc + tr);
        out[row + x] = (gx.abs() + gy.abs()) / 8.0;
      }
    }
    return out;
  }

  /// 3×3 盒式模糊：锐度图直接取最大会让噪点决定结果，先平滑一下。
  static Float64List _blur3x3(Float64List src, int width, int height) {
    final out = Float64List(width * height);
    for (var y = 1; y < height - 1; y++) {
      final row = y * width;
      for (var x = 1; x < width - 1; x++) {
        double sum = 0;
        for (var dy = -1; dy <= 1; dy++) {
          final r = row + dy * width + x;
          sum += src[r - 1] + src[r] + src[r + 1];
        }
        out[row + x] = sum / 9.0;
      }
    }
    return out;
  }

  static double _saturation(num r, num g, num b) {
    var maxC = r;
    var minC = r;
    if (g > maxC) maxC = g;
    if (g < minC) minC = g;
    if (b > maxC) maxC = b;
    if (b < minC) minC = b;
    return (maxC - minC) / 255.0;
  }

  /// 曝光适中度：亮度越接近中灰权重越高，过曝/欠曝的像素自动让位。
  static double _wellExposed(double luma) {
    final normalized = (luma / 255.0).clamp(0.0, 1.0);
    final d = normalized - 0.5;
    return _gaussian(d, _wellExposedSigma);
  }

  static double _gaussian(double x, double sigma) =>
      math.exp(-(x * x) / (2 * sigma * sigma));
}
