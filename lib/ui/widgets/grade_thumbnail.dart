import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../engine/editor/pro_photo_models.dart';
import '../../engine/filter/lut_engine.dart';
import '../../engine/filter/photo_filter.dart';
import '../design/design.dart';

/// 预设缩略图渲染器。
///
/// 复用照片加载时已采集的 48x48 采样像素与现有调色矩阵，
/// 在后台为每个候选预设渲染一张小图，避免"套用后才发现不合适"。
/// 结果按 (采样指纹, 预设指纹) 缓存，重复打开面板不会重算。
///
/// 渲染顺序（与视频 GradeLutFactory / RAW 原生管线保持一致）：
/// 1. 线性调色矩阵（[PhotoFilterEngine.createCompositeMatrix]）——曝光、对比度、
///    高光、阴影、白色与黑色色阶、色温色调、鲜艳度饱和度、纹理清晰度去朦胧
/// 2. 色调曲线（[ColorGrade.toneCurve]）
/// 3. HSL 与三段色轮（[ColorGrade.hsl] / [ColorGrade.colorGrading]）
/// 4. 暗角
///
/// 5. 3D LUT（[ColorGrade.lut]），强度由 [loadLut] 解析后按 [CubeLut.apply] 采样
///
/// LUT 只在配方确实带 LUT 时才解析，且解析放在后台 isolate；
/// 解析失败会静默跳过 LUT 步骤，不影响其它调色参数的缩略图。
/// 内置预设不使用 LUT（见 test/grade_thumbnail_accuracy_test.dart 的约束测试）。
class GradeThumbnailCache {
  GradeThumbnailCache._();

  static final Map<String, ui.Image> _cache = <String, ui.Image>{};

  /// 已解析的 .cube 缓存。key = 路径|大小|修改时间|强度，最多保留 8 份。
  static final Map<String, CubeLut> _lutCache = <String, CubeLut>{};

  /// 读取并解析 LUT。解析 33^3 cube 要读 3.6 万行，必须放后台 isolate。
  /// 失败返回 null，缩略图静默跳过 LUT 部分。
  static Future<CubeLut?> loadLut(String path, double strength) async {
    if (path.isEmpty || strength <= 0.01) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      final fingerprint =
          '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}|$strength';
      final hit = _lutCache[fingerprint];
      if (hit != null) return hit;
      final source = await file.readAsString();
      final lut = await compute(_parseLutIsolate, source);
      if (lut == null) return null;
      _lutCache[fingerprint] = lut;
      if (_lutCache.length > 8) {
        _lutCache.remove(_lutCache.keys.first);
      }
      return lut;
    } catch (_) {
      return null;
    }
  }

  /// 后台 isolate 入口：解析 .cube。
  static CubeLut? _parseLutIsolate(String source) {
    try {
      return CubeLutParser.parse(source);
    } catch (_) {
      return null;
    }
  }

  /// 缓存条目上限，超出后按插入顺序淘汰最旧的。
  static const int _maxEntries = 96;

  static String _fingerprint(
    List<int> sampledR,
    ColorGrade grade,
  ) {
    final base = grade.base;
    final parts = <String>[
      '${sampledR.length}',
      if (sampledR.isNotEmpty) '${sampledR.first}',
      if (sampledR.isNotEmpty) '${sampledR.last}',
      base.exposure.toStringAsFixed(1),
      base.contrast.toStringAsFixed(1),
      base.highlights.toStringAsFixed(1),
      base.shadows.toStringAsFixed(1),
      base.whites.toStringAsFixed(1),
      base.blacks.toStringAsFixed(1),
      base.texture.toStringAsFixed(1),
      base.clarity.toStringAsFixed(1),
      base.dehaze.toStringAsFixed(1),
      base.vibrance.toStringAsFixed(1),
      base.saturation.toStringAsFixed(1),
      base.temperature.toStringAsFixed(1),
      base.tint.toStringAsFixed(1),
      base.vignette.toStringAsFixed(1),
      base.grain.toStringAsFixed(1),
      base.highlightHue.toStringAsFixed(0),
      base.highlightSat.toStringAsFixed(1),
      base.shadowHue.toStringAsFixed(0),
      base.shadowSat.toStringAsFixed(1),
      grade.sharpening.toStringAsFixed(1),
      grade.noiseReduction.toStringAsFixed(1),
      // 非线性阶段必须参与指纹，否则不同预设会命中同一条缓存。
      grade.toneCurve.points
          .map((p) => '${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)}')
          .join(';'),
      grade.hsl.bands
          .map((b) => '${b.band}:${b.hue.toStringAsFixed(1)},'
              '${b.saturation.toStringAsFixed(1)},'
              '${b.luminance.toStringAsFixed(1)}')
          .join(';'),
      _wheelFingerprint(grade.colorGrading.shadows),
      _wheelFingerprint(grade.colorGrading.midtones),
      _wheelFingerprint(grade.colorGrading.highlights),
      grade.lut.path,
      grade.lut.strength.toStringAsFixed(3),
      grade.lut.id,
    ];
    return parts.join('|');
  }

  static String _wheelFingerprint(ColorWheelAdjustment wheel) =>
      '${wheel.hue.toStringAsFixed(1)},'
      '${wheel.saturation.toStringAsFixed(1)},'
      '${wheel.luminance.toStringAsFixed(1)}';

  /// 渲染该预设对应的缩略图；无可用采样或渲染失败时返回 null。
  static Future<ui.Image?> render(
    List<int>? sampledR,
    List<int>? sampledG,
    List<int>? sampledB,
    ColorGrade grade, {
    CubeLut? preloadedLut,
  }) async {
    if (sampledR == null ||
        sampledG == null ||
        sampledB == null ||
        sampledR.isEmpty) {
      return null;
    }
    if (sampledR.length != sampledG.length ||
        sampledR.length != sampledB.length) {
      return null;
    }
    final side = _inferSide(sampledR.length);
    if (side == null) return null;

    final key = _fingerprint(sampledR, grade);
    final cached = _cache[key];
    if (cached != null) return cached;

    final lut =
        preloadedLut ?? await loadLut(grade.lut.path, grade.lut.strength);
    final pixels =
        _renderPixels(sampledR, sampledG, sampledB, grade, side, lut);
    if (pixels == null) return null;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      side,
      side,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final image = await completer.future;
    if (_cache.length >= _maxEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest)?.dispose();
    }
    _cache[key] = image;
    return image;
  }

  /// 采样按行列步进取，用采样点数推断近似方形边长。
  static int? _inferSide(int total) {
    for (var side = 4; side <= 64; side++) {
      if (side * side == total) return side;
    }
    return null;
  }

  static Uint8List? _renderPixels(
    List<int> r,
    List<int> g,
    List<int> b,
    ColorGrade grade,
    int side,
    CubeLut? lut,
  ) {
    try {
      final matrix = PhotoFilterEngine.createCompositeMatrix(
        adjustments: grade.base,
      );
      final out = Uint8List(side * side * 4);
      final vignette = grade.base.vignette / 100.0;

      final curvePoints = grade.toneCurve.points.toList()
        ..sort((a, b) => a.x.compareTo(b.x));
      final bands = grade.hsl.bands
          .map((b) => [b.hue, b.saturation, b.luminance])
          .toList();
      final wheels = [
        grade.colorGrading.shadows,
        grade.colorGrading.midtones,
        grade.colorGrading.highlights,
      ].map((w) => [w.hue, w.saturation, w.luminance]).toList();
      final hasHslOrWheels = bands.isNotEmpty ||
          wheels.any((w) => w[0].abs() + w[1].abs() + w[2].abs() > 1e-6);
      for (var i = 0; i < r.length; i++) {
        final transformed =
            PhotoFilterEngine.applyMatrixToRgb(r[i], g[i], b[i], matrix);
        var rr = transformed[0].toDouble();
        var gg = transformed[1].toDouble();
        var bb = transformed[2].toDouble();

        // 与视频 GradeLutFactory / RAW 原生管线保持一致的语义顺序：
        // 线性调色矩阵 -> 色调曲线 -> HSL / 色轮 -> 暗角。
        if (curvePoints.length >= 2) {
          rr = _evaluateCurve(curvePoints, rr / 255.0) * 255.0;
          gg = _evaluateCurve(curvePoints, gg / 255.0) * 255.0;
          bb = _evaluateCurve(curvePoints, bb / 255.0) * 255.0;
        }
        if (hasHslOrWheels) {
          final hsl = _rgbToHsl(rr, gg, bb);
          var hue = hsl[0];
          var sat = hsl[1];
          var lum = hsl[2];
          var hueShift = 0.0;
          var satShift = 0.0;
          var lumShift = 0.0;

          for (var bi = 0; bi < bands.length; bi++) {
            final distance = _hueDistance(hue, bandCenters[bi]);
            final weight = (1.0 - distance / 45.0).clamp(0.0, 1.0);
            hueShift += bands[bi][0] * weight;
            satShift += bands[bi][1] * weight;
            lumShift += bands[bi][2] * weight;
          }

          final shadowWeight = 1.0 - _smoothStep(0.0, 0.5, lum);
          final highlightWeight = _smoothStep(0.5, 1.0, lum);
          final midWeight = math.max(0.0, 1.0 - (lum - 0.5).abs() * 2.0);
          final wheelWeights = [shadowWeight, midWeight, highlightWeight];
          for (var wi = 0; wi < wheels.length; wi++) {
            hueShift += wheels[wi][0] * wheelWeights[wi];
            satShift += wheels[wi][1] * wheelWeights[wi];
            lumShift += wheels[wi][2] * wheelWeights[wi];
          }

          hue += hueShift;
          sat = (sat * (1.0 + satShift / 100.0)).clamp(0.0, 1.0);
          lum = (lum + lumShift / 100.0 * 0.18).clamp(0.0, 1.0);
          final rgb = _hslToRgb(hue, sat, lum);
          rr = rgb[0] * 255.0;
          gg = rgb[1] * 255.0;
          bb = rgb[2] * 255.0;
        }

        if (lut != null) {
          final mapped = lut.apply(
            (rr / 255.0).clamp(0.0, 1.0),
            (gg / 255.0).clamp(0.0, 1.0),
            (bb / 255.0).clamp(0.0, 1.0),
            strength: grade.lut.strength,
          );
          rr = mapped[0] * 255.0;
          gg = mapped[1] * 255.0;
          bb = mapped[2] * 255.0;
        }

        if (vignette.abs() > 0.001) {
          final x = i % side;
          final y = i ~/ side;
          final nx = (x / (side - 1) - 0.5) * 2;
          final ny = (y / (side - 1) - 0.5) * 2;
          final radius2 = nx * nx + ny * ny;
          final factor = 1.0 + vignette * 0.55 * radius2;
          rr = (rr * factor).clamp(0.0, 255.0);
          gg = (gg * factor).clamp(0.0, 255.0);
          bb = (bb * factor).clamp(0.0, 255.0);
        }

        final idx = i * 4;
        out[idx] = rr.round().clamp(0, 255);
        out[idx + 1] = gg.round().clamp(0, 255);
        out[idx + 2] = bb.round().clamp(0, 255);
        out[idx + 3] = 255;
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  /// 色相环上的最短距离（0..180）。
  static double _hueDistance(double a, double b) {
    final d = (a - b).abs() % 360.0;
    return d > 180.0 ? 360.0 - d : d;
  }

  /// HSL 调整使用的 8 个色相带中心（与视频端一致）。
  static const List<double> bandCenters = <double>[
    0.0,
    30.0,
    60.0,
    120.0,
    180.0,
    240.0,
    280.0,
    320.0,
  ];

  static double _smoothStep(double edge0, double edge1, double x) {
    final t = ((x - edge0) / math.max(1e-6, edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  /// 0..1 的单调色调曲线（线性插值，与 Dart 侧 ToneCurve.evaluate 一致）。
  static double _evaluateCurve(List<ToneCurvePoint> points, double value) {
    if (points.length < 2) return value;
    final t = value.clamp(0.0, 1.0);
    if (t <= points.first.x) return points.first.y.clamp(0.0, 1.0);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (t <= b.x) {
        final span = b.x - a.x;
        if (span.abs() < 1e-9) return b.y.clamp(0.0, 1.0);
        return (a.y + (b.y - a.y) * ((t - a.x) / span)).clamp(0.0, 1.0);
      }
    }
    return points.last.y.clamp(0.0, 1.0);
  }

  /// RGB(0..255) -> HSL(h 0..360, s/l 0..1)。
  static List<double> _rgbToHsl(double r255, double g255, double b255) {
    final r = r255 / 255.0;
    final g = g255 / 255.0;
    final b = b255 / 255.0;
    final maxV = math.max(r, math.max(g, b));
    final minV = math.min(r, math.min(g, b));
    final l = (maxV + minV) * 0.5;
    final delta = maxV - minV;
    if (delta < 1e-6) return <double>[0.0, 0.0, l];
    final s = l > 0.5
        ? delta / math.max(1e-6, 2.0 - maxV - minV)
        : delta / math.max(1e-6, maxV + minV);
    double h;
    if (maxV == r) {
      h = (g - b) / delta + (g < b ? 6.0 : 0.0);
    } else if (maxV == g) {
      h = (b - r) / delta + 2.0;
    } else {
      h = (r - g) / delta + 4.0;
    }
    return <double>[h * 60.0, s, l];
  }

  static double _hueToRgb(double p, double q, double t) {
    var v = t;
    if (v < 0.0) v += 1.0;
    if (v > 1.0) v -= 1.0;
    if (v < 1.0 / 6.0) return p + (q - p) * 6.0 * v;
    if (v < 1.0 / 2.0) return q;
    if (v < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - v) * 6.0;
    return p;
  }

  /// HSL(h 0..360, s/l 0..1) -> RGB(0..255)。
  static List<double> _hslToRgb(double h360, double s, double l) {
    var hue = h360 % 360.0;
    if (hue < 0.0) hue += 360.0;
    hue /= 360.0;
    if (s < 1e-6) return <double>[l * 255.0, l * 255.0, l * 255.0];
    final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
    final p = 2.0 * l - q;
    return <double>[
      _hueToRgb(p, q, hue + 1.0 / 3.0) * 255.0,
      _hueToRgb(p, q, hue) * 255.0,
      _hueToRgb(p, q, hue - 1.0 / 3.0) * 255.0,
    ];
  }

  /// 清空缓存。切换图片时调用，避免旧缩略图占用显存。
  static void clear() {
    _lutCache.clear();
    for (final image in _cache.values) {
      try {
        image.dispose();
      } catch (_) {
        // 无 GPU 的测试环境下 dispose 会断言失败，安全跳过即可。
      }
    }
    _cache.clear();
  }
}

/// 显示一张预设缩略图，渲染中显示占位块。
class GradeThumbnail extends StatefulWidget {
  final ColorGrade grade;
  final List<int>? sampledR;
  final List<int>? sampledG;
  final List<int>? sampledB;
  final double size;

  const GradeThumbnail({
    super.key,
    required this.grade,
    this.sampledR,
    this.sampledG,
    this.sampledB,
    this.size = 44,
  });

  @override
  State<GradeThumbnail> createState() => _GradeThumbnailState();
}

class _GradeThumbnailState extends State<GradeThumbnail> {
  ui.Image? _image;
  int _renderToken = 0;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void didUpdateWidget(covariant GradeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grade != widget.grade ||
        oldWidget.sampledR != widget.sampledR) {
      _render();
    }
  }

  Future<void> _render() async {
    final token = ++_renderToken;
    final image = await GradeThumbnailCache.render(
      widget.sampledR,
      widget.sampledG,
      widget.sampledB,
      widget.grade,
    );
    if (!mounted || token != _renderToken) return;
    setState(() => _image = image);
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    return Container(
      width: widget.size,
      height: widget.size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: zc.surfaceHighest,
      ),
      child: _image == null
          ? const Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            )
          : RawImage(
              image: _image!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
            ),
    );
  }
}
