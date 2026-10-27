import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/builtin_grade_presets.dart';
import 'package:zync/engine/editor/pro_photo_models.dart';
import 'package:zync/ui/widgets/grade_thumbnail.dart';

List<int> graySample(int side) => List<int>.filled(side * side, 128);

void main() {
  tearDown(GradeThumbnailCache.clear);

  test('无采样像素时返回 null 而不抛异常', () async {
    expect(
      await GradeThumbnailCache.render(null, null, null, const ColorGrade()),
      isNull,
    );
  });

  test('空采样列表返回 null', () async {
    expect(
      await GradeThumbnailCache.render(
          const <int>[], const <int>[], const <int>[], const ColorGrade()),
      isNull,
    );
  });

  test('三通道长度不一致时返回 null', () async {
    final r = List<int>.filled(64, 100);
    expect(
      await GradeThumbnailCache.render(r, List<int>.filled(16, 100),
          List<int>.filled(64, 100), const ColorGrade()),
      isNull,
    );
  });

  test('采样数量不是完全平方数时返回 null', () async {
    final r = List<int>.filled(50, 100);
    expect(
      await GradeThumbnailCache.render(r, r, r, const ColorGrade()),
      isNull,
    );
  });

  test('合法方形采样可渲染，且同一预设命中缓存', () async {
    final r = graySample(8);
    final first = await GradeThumbnailCache.render(r, r, r, const ColorGrade());
    expect(first, isNotNull);

    final second =
        await GradeThumbnailCache.render(r, r, r, const ColorGrade());
    expect(second, isNotNull);
    // 相同输入应复用同一张缓存图，避免重复渲染。
    expect(identical(first, second), isTrue);
  });

  test('不同预设产生不同的缓存条目', () async {
    final r = graySample(8);
    final a = await GradeThumbnailCache.render(r, r, r, const ColorGrade());
    final b = await GradeThumbnailCache.render(
        r, r, r, kBuiltinGradePresets.first.grade);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(identical(a, b), isFalse);
  });

  test('clear 不会抛出异常且可重复调用', () {
    GradeThumbnailCache.clear();
    GradeThumbnailCache.clear();
  });

  test('所有内置预设都可作为缩略图输入', () {
    expect(kBuiltinGradePresets, isNotEmpty);
    for (final preset in kBuiltinGradePresets) {
      expect(preset.grade, isNotNull);
      expect(preset.name, isNotEmpty);
    }
  });
}
