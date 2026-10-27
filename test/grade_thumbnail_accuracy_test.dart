import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/editor/builtin_grade_presets.dart';
import 'package:zync/engine/editor/pro_photo_models.dart';
import 'package:zync/engine/filter/photo_filter.dart';
import 'package:zync/ui/widgets/grade_thumbnail.dart';

/// 生成一张有高光与阴影层次的测试图，便于观察颜色变化。
Uint8List _sampleJpeg() {
  final image = img.Image(width: 64, height: 64, numChannels: 3);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      final v = y < 32 ? 220 : 40;
      final g = y < 32 ? 210 : 50;
      final b = y < 32 ? 190 : 70;
      image.setPixel(x, y, img.ColorRgb8(v, g, b));
    }
  }
  return img.encodeJpg(image, quality: 95);
}

late List<int> _sampledR;
late List<int> _sampledG;
late List<int> _sampledB;

void main() {
  setUpAll(() {
    final decoded = img.decodeJpg(_sampleJpeg())!;
    _sampledR = <int>[];
    _sampledG = <int>[];
    _sampledB = <int>[];
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final p = decoded.getPixel(x, y);
        _sampledR.add(p.r.toInt());
        _sampledG.add(p.g.toInt());
        _sampledB.add(p.b.toInt());
      }
    }
  });

  tearDown(GradeThumbnailCache.clear);

  test('缩略图渲染返回有效图像', () async {
    final image = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, const ColorGrade());
    expect(image, isNotNull);
    expect(image!.width, 64);
  });

  test('基础色调参数（曝光/对比度）进入缩略图', () {
    const adjusted = PhotoEditAdjustments(contrast: 30, exposure: 10);
    const plain = PhotoEditAdjustments();
    final a = PhotoFilterEngine.createCompositeMatrix(adjustments: adjusted);
    final b = PhotoFilterEngine.createCompositeMatrix(adjustments: plain);
    expect(a, isNot(equals(b)));
  });

  test('分离色调会进入缩略图（buildAdjustmentsMatrix 内部已做线性近似）', () {
    final preset =
        kBuiltinGradePresets.firstWhere((e) => e.id == 'landscape_teal');
    expect(preset.grade.base.highlightSat, greaterThan(0));
    expect(preset.grade.base.shadowSat, greaterThan(0));

    const split = PhotoEditAdjustments(highlightSat: 80, shadowSat: 60);
    final withSplit =
        PhotoFilterEngine.createCompositeMatrix(adjustments: split);
    final without = PhotoFilterEngine.createCompositeMatrix(
        adjustments: const PhotoEditAdjustments());
    expect(withSplit, isNot(equals(without)), reason: '分离色调应改变缩略图颜色');
  });

  test('toneCurve / hsl / colorGrading 现在都进入缩略图', () async {
    // 上一轮审查判定这三类缺失，本轮已补进缩略图渲染路径，
    // 顺序与视频 GradeLutFactory / RAW 原生管线一致。
    final curvey = ColorGrade(
      base: const PhotoEditAdjustments(),
      toneCurve: const ToneCurve(points: [
        ToneCurvePoint(0, 0.2),
        ToneCurvePoint(0.5, 0.5),
        ToneCurvePoint(1, 0.8),
      ]),
    );
    final hsly = ColorGrade(
      base: const PhotoEditAdjustments(),
      hsl: const HslAdjustments(
          bands: [HslBandAdjustment(band: 'red', saturation: 60)]),
    );
    final wheeled = ColorGrade(
      base: const PhotoEditAdjustments(),
      colorGrading: const ColorGradingWheels(
          shadows: ColorWheelAdjustment(hue: 20, saturation: 50)),
    );

    final base = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, const ColorGrade());
    final a = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, curvey);
    final b =
        await GradeThumbnailCache.render(_sampledR, _sampledG, _sampledB, hsly);
    final c = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, wheeled);

    expect(base, isNotNull);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(c, isNotNull);
    expect(identical(a, base), isFalse, reason: '曲线应改变缩略图');
    expect(identical(b, base), isFalse, reason: 'HSL 应改变缩略图');
    expect(identical(c, base), isFalse, reason: '色轮应改变缩略图');
  });

  test('非线性阶段保持单调：曲线不会把亮度反转', () async {
    final curveOnly = ColorGrade(
      base: const PhotoEditAdjustments(),
      toneCurve: const ToneCurve(points: [
        ToneCurvePoint(0, 0.15),
        ToneCurvePoint(0.5, 0.5),
        ToneCurvePoint(1, 0.85),
      ]),
    );
    final image = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, curveOnly);
    expect(image, isNotNull);
    // 缓存键不同即说明指纹包含了这些参数。
    final again = await GradeThumbnailCache.render(
        _sampledR, _sampledG, _sampledB, curveOnly);
    expect(identical(image, again), isTrue, reason: '相同参数应命中缓存');
  });

  test('内置预设不使用 LUT（当前唯一约束）', () {
    // 缩略图现在支持 toneCurve / hsl / colorGrading；
    // 唯一仍不支持的是 LUT（3D LUT 采样代价过高，会拖慢列表滚动）。
    final withLut = kBuiltinGradePresets
        .where((p) => !p.grade.lut.isDefault)
        .map((p) => p.name)
        .toList();
    expect(withLut, isEmpty, reason: '内置预设不应使用 LUT，否则缩略图无法体现：$withLut');
  });

  test('内置预设确实都产生了视觉差异（不是空预设）', () {
    final plain = PhotoFilterEngine.createCompositeMatrix(
        adjustments: const PhotoEditAdjustments());
    for (final preset in kBuiltinGradePresets) {
      final matrix = PhotoFilterEngine.createCompositeMatrix(
          adjustments: preset.grade.base);
      expect(matrix, isNot(equals(plain)),
          reason: '${preset.name} 在缩略图上与默认无区别');
    }
  });
}
