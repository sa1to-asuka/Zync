import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 取景分析的开关与阈值。
///
/// 值相等性很重要：`ValueNotifier` 用它判断是否需要重新下发分析请求。
class LiveViewAnalysisSettings {
  final bool focusPeaking;
  final int peakThreshold; // Sobel 梯度幅值阈值（0..1020）
  final int peakColor; // 0xAARRGGBB
  final bool zebra;
  final int zebraThreshold; // 亮度阈值 0..255
  final bool histogram;
  final int analysisWidth; // 分析分辨率宽度

  const LiveViewAnalysisSettings({
    this.focusPeaking = false,
    this.peakThreshold = 400,
    this.peakColor = 0xFFFF1744,
    this.zebra = false,
    this.zebraThreshold = 235,
    this.histogram = false,
    this.analysisWidth = 320,
  });

  static const LiveViewAnalysisSettings disabled = LiveViewAnalysisSettings();

  static const int zebraPeriod = 8;
  static const int zebraStripeWidth = 3;

  bool get hasOverlay => focusPeaking || zebra;
  bool get anyEnabled => hasOverlay || histogram;

  LiveViewAnalysisSettings copyWith({
    bool? focusPeaking,
    int? peakThreshold,
    int? peakColor,
    bool? zebra,
    int? zebraThreshold,
    bool? histogram,
    int? analysisWidth,
  }) {
    return LiveViewAnalysisSettings(
      focusPeaking: focusPeaking ?? this.focusPeaking,
      peakThreshold: peakThreshold ?? this.peakThreshold,
      peakColor: peakColor ?? this.peakColor,
      zebra: zebra ?? this.zebra,
      zebraThreshold: zebraThreshold ?? this.zebraThreshold,
      histogram: histogram ?? this.histogram,
      analysisWidth: analysisWidth ?? this.analysisWidth,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiveViewAnalysisSettings &&
      other.focusPeaking == focusPeaking &&
      other.peakThreshold == peakThreshold &&
      other.peakColor == peakColor &&
      other.zebra == zebra &&
      other.zebraThreshold == zebraThreshold &&
      other.histogram == histogram &&
      other.analysisWidth == analysisWidth;

  @override
  int get hashCode => Object.hash(focusPeaking, peakThreshold, peakColor,
      zebra, zebraThreshold, histogram, analysisWidth);
}

/// 一次分析的结果。
class RawAnalysisResult {
  /// 与输入同尺寸的预乘 RGBA 叠加图；不启用峰值/斑马纹时为 `null`。
  final Uint8List? overlayRgba;
  final Uint32List histogram; // 256 桶
  final int overexposedPixels;
  final int width;
  final int height;

  const RawAnalysisResult({
    required this.overlayRgba,
    required this.histogram,
    required this.overexposedPixels,
    required this.width,
    required this.height,
  });
}

/// 计算亮度。系数之和正好是 256，因此纯灰 128 会精确落到第 128 桶。
Uint8List computeLuma(Uint8List rgba, int width, int height) {
  final count = width * height;
  final luma = Uint8List(count);
  var offset = 0;
  for (var i = 0; i < count; i++) {
    final r = rgba[offset];
    final g = rgba[offset + 1];
    final b = rgba[offset + 2];
    luma[i] = (54 * r + 183 * g + 19 * b) >> 8;
    offset += 4;
  }
  return luma;
}

/// 直接把亮度累加进 256 桶直方图。
void accumulateHistogram(Uint8List luma, Uint32List bins) {
  for (var i = 0; i < luma.length; i++) {
    bins[luma[i]]++;
  }
}

/// 3×3 Sobel，返回每个像素的梯度幅值 `|Gx| + |Gy|`（0..1020）。
///
/// 边缘一圈留 0：没有相邻像素可比较，强行计算会在画面四周制造假边缘。
Uint16List computeSobelMagnitude(Uint8List luma, int width, int height) {
  final out = Uint16List(width * height);
  if (width < 3 || height < 3) return out;

  for (var y = 1; y < height - 1; y++) {
    final rowAbove = (y - 1) * width;
    final row = y * width;
    final rowBelow = (y + 1) * width;
    for (var x = 1; x < width - 1; x++) {
      final a = luma[rowAbove + x - 1];
      final b = luma[rowAbove + x];
      final c = luma[rowAbove + x + 1];
      final d = luma[row + x - 1];
      final f = luma[row + x + 1];
      final g = luma[rowBelow + x - 1];
      final h = luma[rowBelow + x];
      final i = luma[rowBelow + x + 1];

      final gx = (c + 2 * f + i) - (a + 2 * d + g);
      final gy = (g + 2 * h + i) - (a + 2 * b + c);
      out[row + x] = gx.abs() + gy.abs();
    }
  }
  return out;
}

/// 峰值掩码：超过阈值的像素为 1，其余为 0。
Uint8List computeFocusPeakMask(
  Uint8List luma,
  int width,
  int height,
  int threshold, {
  Uint16List? magnitudeCache,
}) {
  final magnitude =
      magnitudeCache ?? computeSobelMagnitude(luma, width, height);
  final mask = Uint8List(width * height);
  for (var i = 0; i < magnitude.length; i++) {
    if (magnitude[i] >= threshold) mask[i] = 1;
  }
  return mask;
}

/// 一次遍历产出直方图 + 叠加图。这是 isolate 里真正跑的入口。
RawAnalysisResult analyzeRgbaPixels(
  Uint8List rgba,
  int width,
  int height,
  LiveViewAnalysisSettings settings,
) {
  final luma = computeLuma(rgba, width, height);
  final bins = Uint32List(256);
  accumulateHistogram(luma, bins);

  final wantPeak = settings.focusPeaking;
  final wantZebra = settings.zebra;

  if (!wantPeak && !wantZebra) {
    return RawAnalysisResult(
      overlayRgba: null,
      histogram: bins,
      overexposedPixels: 0,
      width: width,
      height: height,
    );
  }

  final overlay = Uint8List(width * height * 4);
  final peakColor = settings.peakColor;
  final peakR = (peakColor >> 16) & 0xFF;
  final peakG = (peakColor >> 8) & 0xFF;
  final peakB = peakColor & 0xFF;
  final peakA = (peakColor >> 24) & 0xFF;
  final peakMask = wantPeak
      ? computeFocusPeakMask(luma, width, height, settings.peakThreshold)
      : null;

  var overexposed = 0;
  for (var y = 0; y < height; y++) {
    final row = y * width;
    for (var x = 0; x < width; x++) {
      final index = row + x;
      final isOver = luma[index] >= settings.zebraThreshold;
      if (isOver) overexposed++;

      final byteOffset = index * 4;
      if (wantZebra &&
          isOver &&
          (x + y) % LiveViewAnalysisSettings.zebraPeriod <
              LiveViewAnalysisSettings.zebraStripeWidth) {
        // 斑马纹优先于峰值：过曝区域整体打斜纹。
        overlay[byteOffset] = 0xFF;
        overlay[byteOffset + 1] = 0xFF;
        overlay[byteOffset + 2] = 0xFF;
        overlay[byteOffset + 3] = 0xFF;
      } else if (wantPeak && peakMask![index] == 1) {
        // decodeImageFromPixels 按预乘 alpha 解释 rgba8888。
        overlay[byteOffset] = (peakR * peakA) ~/ 255;
        overlay[byteOffset + 1] = (peakG * peakA) ~/ 255;
        overlay[byteOffset + 2] = (peakB * peakA) ~/ 255;
        overlay[byteOffset + 3] = peakA;
      }
    }
  }

  return RawAnalysisResult(
    overlayRgba: overlay,
    histogram: bins,
    overexposedPixels: overexposed,
    width: width,
    height: height,
  );
}

/// 解码 + 缩放 + 分析。损坏或超大的输入返回 `null`，让调用方直接丢帧。
///
/// 这是整个分析链路里最贵的一步（Dart JPEG 解码），所以分析频率独立于取景帧率。
RawAnalysisResult? analyzeJpegBytes(
  Uint8List jpeg,
  LiveViewAnalysisSettings settings,
) {
  if (jpeg.length > 8 * 1024 * 1024) return null;

  img.Image? decoded;
  try {
    decoded = img.decodeJpg(jpeg);
  } catch (_) {
    return null;
  }
  if (decoded == null) return null;
  if (decoded.width * decoded.height > 8000000) return null;

  // 不要 bakeOrientation：取景帧就是按相机原始方向画的，转了反而对不上。
  final targetWidth = settings.analysisWidth.clamp(160, 640);
  final resized = decoded.width > targetWidth
      ? img.copyResize(
          decoded,
          width: targetWidth,
          interpolation: img.Interpolation.average,
        )
      : decoded;

  final rgba = resized.getBytes(order: img.ChannelOrder.rgba);
  return analyzeRgbaPixels(rgba, resized.width, resized.height, settings);
}
