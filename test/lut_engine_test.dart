import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/filter/lut_engine.dart';

void main() {
  test('解析 1D .cube 并应用强度', () {
    const source = '''
TITLE "Test 1D"
LUT_1D_SIZE 2
0 0 0
1 0.5 0.25
''';
    final lut = CubeLutParser.parse(source);
    expect(lut.lut1d, isNotNull);
    expect(lut.is3D, isFalse);
    final out = lut.apply(1, 1, 1, strength: 1);
    expect(out[0], closeTo(1, 1e-6));
    expect(out[1], closeTo(0.5, 1e-6));
    expect(out[2], closeTo(0.25, 1e-6));
    final half = lut.apply(0, 0, 0, strength: 0.5);
    expect(half[0], closeTo(0, 1e-6));
  });

  test('解析 3D .cube 并用四面体插值采样恒等 LUT', () {
    const source = '''
LUT_3D_SIZE 2
0 0 0
0 0 1
0 1 0
0 1 1
1 0 0
1 0 1
1 1 0
1 1 1
''';
    final lut = CubeLutParser.parse(source);
    expect(lut.lut3d, isNotNull);
    expect(lut.size, 2);
    final out = lut.apply(0.25, 0.5, 0.75);
    expect(out[0], closeTo(0.25, 1e-6));
    expect(out[1], closeTo(0.5, 1e-6));
    expect(out[2], closeTo(0.75, 1e-6));
  });

  test('损坏或缺少尺寸声明时明确失败', () {
    expect(() => CubeLutParser.parse('0 0 0\n1 1 1'), throwsFormatException);
    expect(
      () => CubeLutParser.parse('LUT_3D_SIZE 3\n0 0 0\n1 1 1'),
      throwsFormatException,
    );
  });

  test('N-Log/HLG 技术转换输出保持 0..1 且单调', () {
    final nlog0 = VideoColorTransforms.nLogToRec709(0, 0, 0);
    final nlog1 = VideoColorTransforms.nLogToRec709(1, 1, 1);
    expect(nlog0.every((e) => e >= 0 && e <= 1), isTrue);
    expect(nlog1.every((e) => e >= 0 && e <= 1), isTrue);
    expect(nlog1[0], greaterThan(nlog0[0]));

    final hlg0 = VideoColorTransforms.hlgToRec709(0, 0, 0);
    final hlg1 = VideoColorTransforms.hlgToRec709(1, 1, 1);
    expect(hlg0.every((e) => e >= 0 && e <= 1), isTrue);
    expect(hlg1.every((e) => e >= 0 && e <= 1), isTrue);
    expect(hlg1[0], greaterThan(hlg0[0]));
  });
}
