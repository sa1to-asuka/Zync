import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'np3_codec.dart';

/// 尼康优化校准配方近似预览渲染引擎。
///
/// 结合配方中的 257 点 15-bit 自定义曲线 LUT、基底风格特性（标准/自然/鲜艳/人像/风景/单色）、
/// 对比度、亮度、饱和度、色相及单色滤镜/调色参数，在内置样片或用户自选照片上生成实时近似预览。
class PictureControlPreviewRenderer {
  PictureControlPreviewRenderer._();

  /// 构建 256 级 (0..255 -> 0..255) 阶调查找表。
  static Uint8List buildToneLut256(PictureControlRecipe recipe) {
    final lut = Uint8List(256);

    // 基底默认反差系数
    final baseContrast = switch (recipe.base) {
      PictureControlBase.neutral => -0.08,
      PictureControlBase.flat => -0.14,
      PictureControlBase.vivid => 0.12,
      PictureControlBase.landscape => 0.10,
      PictureControlBase.portrait => -0.04,
      PictureControlBase.monochrome => 0.06,
      _ => 0.0,
    };

    if (recipe.hasCustomCurve && recipe.curveLut257.length == 257) {
      for (var i = 0; i < 256; i++) {
        // 257 点 LUT 覆盖 0..256，映射 0..32767 -> 0..255
        final v15 = recipe.curveLut257[i].clamp(0, 32767);
        var norm = v15 / 32767.0;
        if (baseContrast != 0.0) {
          norm = _applySContrast(norm, baseContrast * 0.5);
        }
        lut[i] = (norm.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
      }
      return lut;
    }

    // 无自定义曲线时，根据对比度 (-3..+3)、亮度 (-1.5..+1.5) 以及 Flexible Color 色阶参数构造平滑曲线
    final cStep = (recipe.contrastQuarters ?? 0) / 4.0;
    final bStep = (recipe.brightnessQuarters ?? 0) / 4.0;
    final totalContrast = (baseContrast + cStep * 0.11).clamp(-0.45, 0.55);
    final gamma = math.pow(2.0, -bStep * 0.22).toDouble();

    final fcHi = (recipe.fcHighlights ?? 0) / 100.0;
    final fcSh = (recipe.fcShadows ?? 0) / 100.0;
    final fcWh = (recipe.fcWhites ?? 0) / 100.0;
    final fcBk = (recipe.fcBlacks ?? 0) / 100.0;

    for (var i = 0; i < 256; i++) {
      var x = i / 255.0;
      if (gamma != 1.0) {
        x = math.pow(x, gamma).toDouble();
      }
      x = _applySContrast(x, totalContrast);
      if (fcHi != 0.0 || fcSh != 0.0 || fcWh != 0.0 || fcBk != 0.0) {
        final shadowWeight = (1.0 - x) * (1.0 - x);
        final highWeight = x * x;
        x += fcSh * 0.18 * shadowWeight +
            fcHi * 0.18 * highWeight +
            fcBk * 0.10 * (1.0 - x) +
            fcWh * 0.10 * x;
      }
      lut[i] = (x.clamp(0.0, 1.0) * 255.0).round().clamp(0, 255);
    }
    return lut;
  }

  static double _applySContrast(double x, double amount) {
    final centered = x - 0.5;
    final adjusted = centered * (1.0 + amount * 1.35) -
        amount * 1.8 * centered * centered * centered;
    return (adjusted + 0.5).clamp(0.0, 1.0);
  }

  /// 对 `img.Image` 应用完整的 256 级曲线 LUT + 饱和度/色相/单色滤镜与调色，返回编码后的 JPEG 字节。
  static Uint8List renderPreviewJpg(
    img.Image source,
    PictureControlRecipe recipe, {
    int quality = 85,
  }) {
    final copy = source.clone();
    final lut = buildToneLut256(recipe);

    final baseSat = switch (recipe.base) {
      PictureControlBase.neutral => 0.88,
      PictureControlBase.flat => 0.82,
      PictureControlBase.vivid => 1.24,
      PictureControlBase.landscape => 1.18,
      PictureControlBase.portrait => 0.96,
      _ => 1.0,
    };
    final satStep = (recipe.saturationQuarters ?? 0) / 4.0;
    final satFactor = (baseSat * (1.0 + satStep * 0.14)).clamp(0.0, 2.2);

    final hueStep = (recipe.hueQuarters ?? 0) / 4.0;
    // 尼康色相步进约每档 3.5 度
    final hueRad = hueStep * 3.5 * math.pi / 180.0;
    final cosH = math.cos(hueRad);
    final sinH = math.sin(hueRad);

    final isMono = recipe.isMonochrome;
    // 单色滤镜权重 (0: Off, 1: Yellow, 2: Orange, 3: Red, 4: Green)
    final (double wR, double wG, double wB) = switch (recipe.monoFilter) {
      1 => (0.38, 0.54, 0.08), // Yellow
      2 => (0.48, 0.46, 0.06), // Orange
      3 => (0.64, 0.32, 0.04), // Red
      4 => (0.20, 0.70, 0.10), // Green
      _ => (0.299, 0.587, 0.114),
    };

    // 单色调色偏色向量 (1: Sepia, 2: Cyanotype, 3: Red, 4: Yellow, 5: Green, 6: Blue-Green, 7: Blue, 8: Purple-Blue, 9: Red-Purple)
    final (double tR, double tG, double tB) = switch (recipe.monoToning) {
      1 => (28.0, 8.0, -24.0), // Sepia
      2 => (-22.0, 4.0, 28.0), // Cyanotype
      3 => (26.0, -10.0, -14.0), // Red
      4 => (20.0, 16.0, -24.0), // Yellow
      5 => (-14.0, 20.0, -10.0), // Green
      6 => (-18.0, 14.0, 16.0), // Blue-Green
      7 => (-18.0, -6.0, 28.0), // Blue
      8 => (4.0, -12.0, 26.0), // Purple-Blue
      9 => (22.0, -12.0, 16.0), // Red-Purple
      _ => (0.0, 0.0, 0.0),
    };
    final toningStrength =
        recipe.monoToning == 0 ? 0.0 : ((recipe.monoToningSaturation + 1) / 8.0);

    for (final pixel in copy) {
      final rIn = pixel.r.toInt().clamp(0, 255);
      final gIn = pixel.g.toInt().clamp(0, 255);
      final bIn = pixel.b.toInt().clamp(0, 255);

      var r = lut[rIn].toDouble();
      var g = lut[gIn].toDouble();
      var b = lut[bIn].toDouble();

      if (isMono) {
        final luma = (r * wR + g * wG + b * wB).clamp(0.0, 255.0);
        // 越靠近中间调，调色染色越明显
        final midWeight = 1.0 - ((luma / 127.5) - 1.0).abs() * 0.55;
        final k = toningStrength * midWeight;
        pixel
          ..r = (luma + tR * k).round().clamp(0, 255)
          ..g = (luma + tG * k).round().clamp(0, 255)
          ..b = (luma + tB * k).round().clamp(0, 255);
        continue;
      }

      // 饱和度与色相调整
      final luma = 0.299 * r + 0.587 * g + 0.114 * b;
      r = luma + (r - luma) * satFactor;
      g = luma + (g - luma) * satFactor;
      b = luma + (b - luma) * satFactor;

      if (hueStep != 0.0) {
        final iCh = 0.596 * r - 0.274 * g - 0.322 * b;
        final qCh = 0.211 * r - 0.523 * g + 0.312 * b;
        final iRot = iCh * cosH - qCh * sinH;
        final qRot = iCh * sinH + qCh * cosH;
        r = luma + 0.956 * iRot + 0.621 * qRot;
        g = luma - 0.272 * iRot - 0.647 * qRot;
        b = luma - 1.106 * iRot + 1.703 * qRot;
      }

      pixel
        ..r = r.round().clamp(0, 255)
        ..g = g.round().clamp(0, 255)
        ..b = b.round().clamp(0, 255);
    }

    return Uint8List.fromList(img.encodeJpg(copy, quality: quality));
  }

  /// 构建用于列表小卡片 60fps 实时渲染的 4x5 ColorFilter 矩阵近似值。
  static List<double> buildQuickColorMatrix(PictureControlRecipe recipe) {
    final lut = buildToneLut256(recipe);
    // 用曲线黑位 (lut[16]) 与高光 (lut[240]) 拟合斜率与截距
    final shadowOut = lut[24] / 255.0;
    final midOut = lut[128] / 255.0;
    final highOut = lut[232] / 255.0;
    final slope = ((highOut - shadowOut) / (208.0 / 255.0)).clamp(0.55, 1.55);
    final bias =
        ((midOut - 0.5 * slope) * 255.0).clamp(-42.0, 42.0);

    if (recipe.isMonochrome) {
      final (double wR, double wG, double wB) = switch (recipe.monoFilter) {
        1 => (0.38, 0.54, 0.08),
        2 => (0.48, 0.46, 0.06),
        3 => (0.64, 0.32, 0.04),
        4 => (0.20, 0.70, 0.10),
        _ => (0.299, 0.587, 0.114),
      };
      final rM = wR * slope;
      final gM = wG * slope;
      final bM = wB * slope;
      final sepiaBoost = recipe.monoToning == 1 ? 10.0 : 0.0;
      return <double>[
        rM, gM, bM, 0, bias + sepiaBoost,
        rM, gM, bM, 0, bias + sepiaBoost * 0.25,
        rM, gM, bM, 0, bias - sepiaBoost * 0.7,
        0, 0, 0, 1, 0,
      ];
    }

    final baseSat = switch (recipe.base) {
      PictureControlBase.neutral => 0.88,
      PictureControlBase.flat => 0.82,
      PictureControlBase.vivid => 1.24,
      PictureControlBase.landscape => 1.18,
      PictureControlBase.portrait => 0.96,
      _ => 1.0,
    };
    final satStep = (recipe.saturationQuarters ?? 0) / 4.0;
    final s = (baseSat * (1.0 + satStep * 0.14)).clamp(0.0, 2.2);

    const lumR = 0.299;
    const lumG = 0.587;
    const lumB = 0.114;

    final sr = (1.0 - s) * lumR;
    final sg = (1.0 - s) * lumG;
    final sb = (1.0 - s) * lumB;

    return <double>[
      (sr + s) * slope, sg * slope, sb * slope, 0, bias,
      sr * slope, (sg + s) * slope, sb * slope, 0, bias,
      sr * slope, sg * slope, (sb + s) * slope, 0, bias,
      0, 0, 0, 1, 0,
    ];
  }
}
