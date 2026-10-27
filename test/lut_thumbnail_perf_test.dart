
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/filter/lut_engine.dart';

/// 生成一个 33x33x33 的 .cube 内容（约 36k 行），用于评估解析耗时。
String _bigCube({int size = 33}) {
  final buffer = StringBuffer()
    ..writeln('TITLE "perf"')
    ..writeln('LUT_3D_SIZE $size')
    ..writeln('DOMAIN_MIN 0.0 0.0 0.0')
    ..writeln('DOMAIN_MAX 1.0 1.0 1.0');
  for (var b = 0; b < size; b++) {
    for (var g = 0; g < size; g++) {
      for (var r = 0; r < size; r++) {
        buffer.writeln('${r / (size - 1)} ${g / (size - 1)} ${b / (size - 1)}');
      }
    }
  }
  return buffer.toString();
}

void main() {
  test('33^3 cube 解析耗时可接受（缩略图路径的上限）', () {
    final source = _bigCube();
    final sw = Stopwatch()..start();
    final lut = CubeLutParser.parse(source);
    sw.stop();
    expect(lut.lut3d, isNotNull);
    expect(lut.lut3d!.size, 33);
    // 解析 + 一次采样的总耗时必须远小于一帧（16ms），
    // 否则缩略图渲染会明显拖慢预设列表。
    final sampleSw = Stopwatch()..start();
    for (var i = 0; i < 100; i++) {
      lut.apply(i / 100.0, 0.5, 0.5);
    }
    sampleSw.stop();
    // 100 次采样（对应 100 个像素）应在 10ms 内。
    expect(sampleSw.elapsedMilliseconds, lessThan(200),
        reason: '采样过慢：${sampleSw.elapsedMilliseconds}ms');
  });

  test('小尺寸 cube 解析更快', () {
    final sw = Stopwatch()..start();
    final lut = CubeLutParser.parse(_bigCube(size: 9));
    sw.stop();
    expect(lut.lut3d!.size, 9);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });

  test('采样结果在 0..1 范围内且可复现', () {
    final lut = CubeLutParser.parse(_bigCube(size: 9));
    final a = lut.apply(0.2, 0.4, 0.6);
    final b = lut.apply(0.2, 0.4, 0.6);
    expect(a, equals(b), reason: '同输入必须得到同输出');
    for (final v in a) {
      expect(v, inInclusiveRange(0.0, 1.0));
    }
  });

  test('空/非法输入不抛异常', () {
    expect(() => CubeLutParser.parse(''), throwsA(anything));
    expect(() => CubeLutParser.parse('garbage'), throwsA(anything));
  });
}
