import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/color_grade_preset.dart';
import 'package:zync/engine/editor/pro_photo_models.dart';
import 'package:zync/engine/filter/photo_filter.dart';

ColorGrade _sampleGrade() {
  return ColorGrade(
    base:
        const PhotoEditAdjustments(exposure: 25, contrast: -10, saturation: 15),
    sharpening: 40,
  );
}

void main() {
  test('预设 JSON 往返保留调色参数', () {
    final preset = ColorGradePreset(
      id: 'preset_1',
      name: '电影青橙',
      isGlobal: true,
      grade: _sampleGrade(),
      createdAtMs: 111,
      updatedAtMs: 222,
    );
    final restored = ColorGradePreset.fromJsonString(preset.toJsonString());
    expect(restored.id, 'preset_1');
    expect(restored.name, '电影青橙');
    expect(restored.isGlobal, isTrue);
    expect(restored.grade.base.exposure, 25);
    expect(restored.grade.base.contrast, -10);
    expect(restored.grade.sharpening, 40);
    expect(restored.createdAtMs, 111);
  });

  test('摘要列出非零参数', () {
    final preset = ColorGradePreset(id: 'p', name: 'n', grade: _sampleGrade());
    final summary = preset.summary;
    expect(summary.contains('曝光'), isTrue);
    expect(summary.contains('对比度'), isTrue);
    expect(summary.contains('饱和度'), isTrue);
    expect(summary.contains('锐化'), isTrue);
  });

  test('默认调色摘要为未做调整', () {
    final preset = ColorGradePreset(id: 'p', name: 'n');
    expect(preset.summary, '未做调整');
  });

  test('导出后可完整导入并按 id 去重覆盖', () {
    final a = ColorGradePreset(
      id: 'shared',
      name: '旧名称',
      grade: _sampleGrade(),
      updatedAtMs: 1,
    );
    final b = ColorGradePreset(
      id: 'other',
      name: '另一个',
      grade: const ColorGrade(),
      updatedAtMs: 2,
    );
    final exported = ColorGradePresetStore.exportJson([a, b]);

    final updatedA = ColorGradePreset(
      id: 'shared',
      name: '新名称',
      grade: const ColorGrade(),
      updatedAtMs: 5,
    );
    final imported =
        ColorGradePresetStore.importJson(exported, existing: [updatedA]);

    expect(imported.length, 2);
    final shared = imported.firstWhere((e) => e.id == 'shared');
    expect(shared.name, '新名称');
    expect(imported.any((e) => e.id == 'other'), isTrue);
  });

  test('导入支持裸数组格式并跳过损坏条目', () {
    final valid = ColorGradePreset(id: 'ok', name: '正常').toJson();
    final source = jsonEncode([valid, 'not-a-map', 42]);
    final imported = ColorGradePresetStore.importJson(source);
    expect(imported.length, 1);
    expect(imported.single.id, 'ok');
  });

  test('导入非法 JSON 时不抛异常', () {
    expect(() => ColorGradePresetStore.importJson('not json at all'),
        returnsNormally);
  });

  test('copyWith 只覆盖指定字段', () {
    final preset = ColorGradePreset(
      id: 'p',
      name: '原名',
      isGlobal: true,
      grade: _sampleGrade(),
    );
    final renamed = preset.copyWith(name: '新名');
    expect(renamed.name, '新名');
    expect(renamed.id, 'p');
    expect(renamed.isGlobal, isTrue);
    expect(renamed.grade.base.exposure, 25);
  });

  test('预设携带 isGlobal 以区分整体与单片段调色', () {
    final global = ColorGradePreset(id: 'g', name: '整体', isGlobal: true);
    final clip = ColorGradePreset(id: 'c', name: '片段');
    expect(global.isGlobal, isTrue);
    expect(clip.isGlobal, isFalse);
  });
}
