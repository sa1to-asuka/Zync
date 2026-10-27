import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/pro_photo_models.dart';
import 'package:zync/engine/filter/photo_filter.dart';

void main() {
  test('PhotoEditRecipe JSON 往返保留专业字段', () {
    const recipe = PhotoEditRecipe(
      sourceMode: PhotoSourceMode.professionalRaw,
      filterTypeName: 'classicChrome',
      filterIntensity: 0.8,
      grade: ColorGrade(
        sharpening: 22,
        noiseReduction: 18,
        lensDistortion: -3,
        lensVignette: 12,
        chromaticAberration: 4,
      ),
    );

    final restored = PhotoEditRecipe.fromJsonString(recipe.toJsonString());
    expect(restored.sourceMode, PhotoSourceMode.professionalRaw);
    expect(restored.filterTypeName, 'classicChrome');
    expect(restored.filterIntensity, 0.8);
    expect(restored.grade.sharpening, 22);
    expect(restored.grade.noiseReduction, 18);
    expect(restored.grade.lensDistortion, -3);
    expect(restored.grade.lensVignette, 12);
    expect(restored.grade.chromaticAberration, 4);
  });

  test('旧 PhotoEditAdjustments 可迁移到新 recipe', () {
    const legacy =
        PhotoEditAdjustments(exposure: 12, contrast: 8, temperature: -5);
    final recipe = PhotoEditRecipe.fromLegacy(
      filterType: PhotoFilterType.classicChrome,
      filterIntensity: 0.6,
      adjustments: legacy,
      sourceMode: PhotoSourceMode.professionalRaw,
    );
    expect(recipe.grade.base.exposure, 12);
    expect(recipe.grade.base.contrast, 8);
    expect(recipe.grade.base.temperature, -5);
    expect(recipe.sourceMode, PhotoSourceMode.professionalRaw);
  });

  test('色调曲线端点与插值稳定', () {
    const curve = ToneCurve(points: [
      ToneCurvePoint(0, 0.1),
      ToneCurvePoint(0.5, 0.4),
      ToneCurvePoint(1, 0.9),
    ]);
    expect(curve.evaluate(0), closeTo(0.1, 1e-9));
    expect(curve.evaluate(0.5), closeTo(0.4, 1e-9));
    expect(curve.evaluate(1), closeTo(0.9, 1e-9));
    expect(curve.evaluate(0.25), closeTo(0.25, 1e-9));
  });

  test('HSL 与色轮默认状态可识别', () {
    expect(const HslAdjustments().isDefault, isTrue);
    expect(const ColorGradingWheels().isDefault, isTrue);
    expect(const ColorGrade().isDefault, isTrue);
  });
}
