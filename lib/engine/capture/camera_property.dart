/// 拍摄台可调的相机参数，以及每个参数的属性 ID 与显示格式。
///
/// 属性 ID 与解码规则与 `NikonDriver.fetchExposureParams` 保持一致，
/// 避免「读数」和「选项列表」两套口径对不上。
enum CameraParameter { mode, aperture, shutter, iso, exposureCompensation }

extension CameraParameterInfo on CameraParameter {
  /// 首选属性 ID。
  int get propertyId => switch (this) {
        CameraParameter.mode => 0x500E,
        CameraParameter.aperture => 0x5007,
        CameraParameter.shutter => 0xD100, // Nikon 扩展：分子/分母打包
        CameraParameter.iso => 0xD0B4, // Nikon 扩展
        CameraParameter.exposureCompensation => 0x5010,
      };

  /// 首选属性读失败时依次尝试的备用 ID。
  ///
  /// 机型的 Nikon 扩展属性不齐全时回落到标准 PTP 属性；
  /// 注意 0x500D 的单位是 100 µs，与 0xD100 的分子/分母完全不同，
  /// 所以格式化函数也必须跟着切换。
  List<int> get fallbackPropertyIds => switch (this) {
        CameraParameter.shutter => const <int>[0x500D],
        CameraParameter.iso => const <int>[0x500F],
        _ => const <int>[],
      };

  /// 把属性的原始值格式化成界面文案。传入 [usedPropertyId] 是为了在
  /// 走备用属性时切换解码方式。
  String format(int rawValue, {int? usedPropertyId}) => switch (this) {
        CameraParameter.mode => CameraValueLabels.mode(rawValue),
        CameraParameter.aperture => CameraValueLabels.aperture(rawValue),
        CameraParameter.shutter => usedPropertyId == 0x500D
            ? CameraValueLabels.shutterStandard(rawValue)
            : CameraValueLabels.shutterNikon(rawValue),
        CameraParameter.iso => CameraValueLabels.iso(rawValue),
        CameraParameter.exposureCompensation =>
          CameraValueLabels.exposureCompensation(rawValue),
      };
}

/// 相机属性值的显示格式。
///
/// 全部为纯函数，便于在没有相机的情况下做单元测试。
class CameraValueLabels {
  CameraValueLabels._();

  static const String unknown = '—';

  /// 0x5007 F-number：无符号，实际值 = raw / 100。
  static String aperture(int raw) {
    if (raw <= 0 || raw >= 65000) return unknown;
    return 'f/${(raw / 100.0).toStringAsFixed(1)}';
  }

  /// 0xD100 Nikon 快门速度：32 位，高 16 位分子、低 16 位分母。
  static String shutterNikon(int raw) {
    if (raw == 0xFFFFFFFF) return 'BULB';
    final value = raw & 0xFFFFFFFF;
    final numerator = (value >> 16) & 0xFFFF;
    final denominator = value & 0xFFFF;
    if (numerator == 65535 && denominator == 65535) return 'BULB';
    if (numerator == 65535 && denominator == 65533) return 'TIME';
    if (numerator == 65535 && denominator == 65534) return 'FLASH';
    if (denominator == 0) return unknown;
    if (denominator == 1) return '${numerator}s';
    if (numerator == 1) return '1/${denominator}s';
    if (numerator > 0 && denominator % numerator == 0) {
      return '1/${denominator ~/ numerator}s';
    }
    return '$numerator/$denominator s';
  }

  /// 0x500D 标准 PTP ExposureTime：单位 100 µs，0xFFFFFFFF 表示 Bulb。
  static String shutterStandard(int raw) {
    if (raw == 0xFFFFFFFF) return 'BULB';
    if (raw <= 0) return unknown;
    final seconds = raw / 10000.0;
    if (seconds < 1) {
      final denominator = (1 / seconds).round();
      return '1/${denominator}s';
    }
    if (seconds == seconds.roundToDouble()) return '${seconds.round()}s';
    return '${seconds.toStringAsFixed(1)}s';
  }

  /// 0x500F / 0xD0B4 ISO：raw 即 ISO 值。
  static String iso(int raw) {
    if (raw <= 0) return unknown;
    return 'ISO $raw';
  }

  /// 0x5010 曝光补偿：有符号 16 位，单位 1/1000 EV。
  static String exposureCompensation(int raw) {
    final signed = (raw & 0xFFFF) >= 0x8000 ? (raw & 0xFFFF) - 0x10000 : raw;
    final ev = signed / 1000.0;
    if (ev == 0) return '±0.0 EV';
    final sign = ev > 0 ? '+' : '';
    return '$sign${ev.toStringAsFixed(1)} EV';
  }

  /// 0x500E 曝光模式。
  static String mode(int raw) => switch (raw) {
        1 => 'M',
        2 => 'P',
        3 => 'A',
        4 => 'S',
        0x8010 => 'AUTO',
        0x8011 => 'AUTO',
        _ => unknown,
      };

  /// 0xD10E 机身朝向 → 画面顺时针旋转角度。
  static int rotationDegrees(int raw) => switch (raw) {
        1 => 270,
        2 => 90,
        3 => 180,
        _ => 0,
      };
}
