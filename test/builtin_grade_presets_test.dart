import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/builtin_grade_presets.dart';

void main() {
  test('内置预设非空且 id 唯一', () {
    expect(kBuiltinGradePresets, isNotEmpty);
    final ids = kBuiltinGradePresets.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('所有内置预设都归入已声明的分类', () {
    for (final preset in kBuiltinGradePresets) {
      expect(kBuiltinGradeCategories, contains(preset.category),
          reason: '预设 ${preset.name} 的分类未声明');
    }
  });

  test('每个分类至少有一个预设', () {
    for (final category in kBuiltinGradeCategories) {
      expect(builtinPresetsIn(category), isNotEmpty,
          reason: '分类 $category 没有预设');
    }
  });

  test('预设名称与描述都非空', () {
    for (final preset in kBuiltinGradePresets) {
      expect(preset.name.trim(), isNotEmpty);
      expect(preset.description.trim(), isNotEmpty);
    }
  });

  test('参数都在合法范围内', () {
    for (final preset in kBuiltinGradePresets) {
      final base = preset.grade.base;
      void bounded(String label, double value, double limit) {
        expect(value.abs(), lessThanOrEqualTo(limit + 0.001),
            reason: '${preset.name} 的 $label 超出范围: $value');
      }

      bounded('色温', base.temperature, 100);
      bounded('色调', base.tint, 100);
      bounded('曝光', base.exposure, 100);
      bounded('对比度', base.contrast, 100);
      bounded('高光', base.highlights, 100);
      bounded('阴影', base.shadows, 100);
      bounded('白色色阶', base.whites, 100);
      bounded('黑色色阶', base.blacks, 100);
      bounded('纹理', base.texture, 100);
      bounded('清晰度', base.clarity, 100);
      bounded('去朦胧', base.dehaze, 100);
      bounded('鲜艳度', base.vibrance, 100);
      bounded('饱和度', base.saturation, 100);
      bounded('暗角', base.vignette, 100);
      bounded('颗粒', base.grain, 100);
      bounded('锐化', preset.grade.sharpening, 100);
      bounded('降噪', preset.grade.noiseReduction, 100);
      expect(base.highlightHue, inInclusiveRange(0, 360));
      expect(base.shadowHue, inInclusiveRange(0, 360));
      bounded('高光饱和度', base.highlightSat, 100);
      bounded('阴影饱和度', base.shadowSat, 100);
    }
  });

  test('黑白类预设确实完全去饱和', () {
    for (final id in ['mono_classic', 'mono_high', 'mono_soft']) {
      final preset = kBuiltinGradePresets.firstWhere((e) => e.id == id);
      expect(preset.grade.base.saturation, -100, reason: '$id 应为纯黑白');
    }
  });

  test('预设不是空调整，除标准外都应有实际效果', () {
    for (final preset in kBuiltinGradePresets) {
      expect(preset.grade.isDefault, isFalse,
          reason: '${preset.name} 不应是完全默认的调色');
    }
  });

  test('builtin_ 前缀用于区分内置与用户预设', () {
    expect(isBuiltinPresetId('builtin_neutral'), isTrue);
    expect(isBuiltinPresetId('preset_123'), isFalse);
    final converted = kBuiltinGradePresets.first.toPreset(isGlobal: true);
    expect(converted.id, startsWith('builtin_'));
    expect(converted.isGlobal, isTrue);
  });

  test('按分类筛选结果都归属于该分类', () {
    for (final category in kBuiltinGradeCategories) {
      for (final preset in builtinPresetsIn(category)) {
        expect(preset.category, category);
      }
    }
  });
}
