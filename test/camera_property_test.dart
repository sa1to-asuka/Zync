import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/camera_property.dart';

void main() {
  group('CameraValueLabels.aperture', () {
    test('raw / 100 保留一位小数', () {
      expect(CameraValueLabels.aperture(280), 'f/2.8');
      expect(CameraValueLabels.aperture(560), 'f/5.6');
      expect(CameraValueLabels.aperture(1800), 'f/18.0');
    });

    test('0 与越界值显示为占位符', () {
      expect(CameraValueLabels.aperture(0), CameraValueLabels.unknown);
      expect(CameraValueLabels.aperture(65000), CameraValueLabels.unknown);
    });
  });

  group('CameraValueLabels.shutterNikon', () {
    int packed(int numerator, int denominator) =>
        ((numerator & 0xFFFF) << 16) | (denominator & 0xFFFF);

    test('常规快门速度', () {
      expect(CameraValueLabels.shutterNikon(packed(1, 250)), '1/250s');
      expect(CameraValueLabels.shutterNikon(packed(1, 60)), '1/60s');
    });

    test('整数秒', () {
      expect(CameraValueLabels.shutterNikon(packed(1, 1)), '1s');
      expect(CameraValueLabels.shutterNikon(packed(2, 1)), '2s');
      expect(CameraValueLabels.shutterNikon(packed(30, 1)), '30s');
    });

    test('可约分的分子分母', () {
      expect(CameraValueLabels.shutterNikon(packed(3, 300)), '1/100s');
    });

    test('BULB / TIME / FLASH 三个哨兵值', () {
      expect(CameraValueLabels.shutterNikon(0xFFFFFFFF), 'BULB');
      expect(CameraValueLabels.shutterNikon(packed(65535, 65535)), 'BULB');
      expect(CameraValueLabels.shutterNikon(packed(65535, 65533)), 'TIME');
      expect(CameraValueLabels.shutterNikon(packed(65535, 65534)), 'FLASH');
    });

    test('分母为 0 时不崩，显示占位符', () {
      expect(CameraValueLabels.shutterNikon(packed(1, 0)),
          CameraValueLabels.unknown);
    });
  });

  group('CameraValueLabels.shutterStandard', () {
    test('单位是 100 µs', () {
      expect(CameraValueLabels.shutterStandard(400), '1/25s');
      expect(CameraValueLabels.shutterStandard(10000), '1s');
    });

    test('超过 1 秒保留一位小数', () {
      expect(CameraValueLabels.shutterStandard(25000), '2.5s');
    });

    test('0xFFFFFFFF 表示 Bulb', () {
      expect(CameraValueLabels.shutterStandard(0xFFFFFFFF), 'BULB');
    });

    test('0 显示占位符', () {
      expect(CameraValueLabels.shutterStandard(0), CameraValueLabels.unknown);
    });
  });

  group('CameraValueLabels.iso', () {
    test('直接以 ISO 值显示', () {
      expect(CameraValueLabels.iso(400), 'ISO 400');
      expect(CameraValueLabels.iso(12800), 'ISO 12800');
    });

    test('0 显示占位符', () {
      expect(CameraValueLabels.iso(0), CameraValueLabels.unknown);
    });
  });

  group('CameraValueLabels.exposureCompensation', () {
    test('0 显示为正负零', () {
      expect(CameraValueLabels.exposureCompensation(0), '±0.0 EV');
    });

    test('正补偿带加号', () {
      expect(CameraValueLabels.exposureCompensation(333), '+0.3 EV');
      expect(CameraValueLabels.exposureCompensation(1000), '+1.0 EV');
    });

    test('负补偿按有符号 16 位解释', () {
      expect(CameraValueLabels.exposureCompensation(-333), '-0.3 EV');
      expect(CameraValueLabels.exposureCompensation(0xFEB3), '-0.3 EV');
    });
  });

  group('CameraValueLabels.mode', () {
    test('标准模式码', () {
      expect(CameraValueLabels.mode(1), 'M');
      expect(CameraValueLabels.mode(2), 'P');
      expect(CameraValueLabels.mode(3), 'A');
      expect(CameraValueLabels.mode(4), 'S');
    });

    test('自动模式两个码', () {
      expect(CameraValueLabels.mode(0x8010), 'AUTO');
      expect(CameraValueLabels.mode(0x8011), 'AUTO');
    });

    test('未知码显示占位符', () {
      expect(CameraValueLabels.mode(99), CameraValueLabels.unknown);
    });
  });

  group('CameraValueLabels.rotationDegrees', () {
    test('朝向码映射到顺时针旋转角度', () {
      expect(CameraValueLabels.rotationDegrees(0), 0);
      expect(CameraValueLabels.rotationDegrees(1), 270);
      expect(CameraValueLabels.rotationDegrees(2), 90);
      expect(CameraValueLabels.rotationDegrees(3), 180);
    });

    test('未知码按水平处理', () {
      expect(CameraValueLabels.rotationDegrees(42), 0);
    });
  });

  group('CameraParameter', () {
    test('每个参数都有首选属性 ID', () {
      expect(CameraParameter.mode.propertyId, 0x500E);
      expect(CameraParameter.aperture.propertyId, 0x5007);
      expect(CameraParameter.shutter.propertyId, 0xD100);
      expect(CameraParameter.iso.propertyId, 0xD0B4);
      expect(CameraParameter.exposureCompensation.propertyId, 0x5010);
    });

    test('快门与 ISO 有标准 PTP 备用属性', () {
      expect(CameraParameter.shutter.fallbackPropertyIds, contains(0x500D));
      expect(CameraParameter.iso.fallbackPropertyIds, contains(0x500F));
    });

    test('走备用快门属性时切换解码方式', () {
      const raw = 400;
      expect(
        CameraParameter.shutter.format(raw, usedPropertyId: 0x500D),
        '1/25s',
      );
      expect(
        CameraParameter.shutter.format(raw, usedPropertyId: 0xD100),
        CameraValueLabels.shutterNikon(raw),
      );
    });
  });
}
