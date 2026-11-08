import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/af_area_mapper.dart';

void main() {
  group('AfAreaMapper.fromNormalized', () {
    test('画面中心映射到坐标系中心', () {
      final point = AfAreaMapper.fromNormalized(0.5, 0.5);
      expect(point.x, 2880);
      expect(point.y, 1920);
    });

    test('左上角映射到原点', () {
      final point = AfAreaMapper.fromNormalized(0.0, 0.0);
      expect(point.x, 0);
      expect(point.y, 0);
    });

    test('右下角映射到坐标上限', () {
      final point = AfAreaMapper.fromNormalized(1.0, 1.0);
      expect(point.x, AfAreaMapper.defaultWidth);
      expect(point.y, AfAreaMapper.defaultHeight);
    });

    test('越界输入被夹紧而不是溢出画面', () {
      final point = AfAreaMapper.fromNormalized(-3.0, 2.5);
      expect(point.x, 0);
      expect(point.y, AfAreaMapper.defaultHeight);
    });

    test('可覆盖坐标系尺寸', () {
      final point =
          AfAreaMapper.fromNormalized(0.5, 0.5, width: 1000, height: 800);
      expect(point.x, 500);
      expect(point.y, 400);
    });
  });

  group('AfAreaMapper.toNormalized', () {
    test('中心坐标反算回 0.5', () {
      final point = AfAreaMapper.toNormalized(2880, 1920);
      expect(point.x, closeTo(0.5, 1e-9));
      expect(point.y, closeTo(0.5, 1e-9));
    });

    test('越界坐标被夹紧到 0..1', () {
      final point = AfAreaMapper.toNormalized(99999, -5);
      expect(point.x, 1.0);
      expect(point.y, 0.0);
    });
  });
}
