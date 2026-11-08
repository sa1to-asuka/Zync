import 'camera_property.dart';

/// 参数为什么不可写。用枚举而不是文案，交给界面做本地化。
enum ExposureLockReason {
  /// 可写。
  none,

  /// 曝光模式本身只用于显示，本版本不主动改机身档位。
  modeIsDisplayOnly,

  /// 当前档位由相机决定这个参数（A 档的快门、S 档的光圈、P 档的光圈快门）。
  bodyModeExcludes,

  /// 全自动或场景模式，几乎全部参数都由机身接管。
  autoMode,

  /// 读不到当前模式，无法判断——此时只提示、不锁死。
  unknownMode,
}

/// 相机曝光模式码（0x500E）。
abstract final class CameraExposureMode {
  static const int manual = 1;
  static const int program = 2;
  static const int aperturePriority = 3;
  static const int shutterPriority = 4;
  static const int auto = 0x8010;
  static const int autoAlt = 0x8011;

  static bool isAuto(int mode) => mode == auto || mode == autoAlt;
}

/// 按机身档位推断某个参数能否修改，**只作为兜底与文案依据**。
///
/// 界面以相机 `0x1014` 返回的 `writable` 为准：实测 Z 30 会随档位自己改这个
/// 标志（A 档快门只读、S 档光圈只读），本地再判一次只会制造矛盾。
ExposureLockReason lockReasonFor(CameraParameter parameter, int? mode) {
  // 模式本身是只读的：改档位会动到用户的机身设置，本版本不做。
  if (parameter == CameraParameter.mode) {
    return ExposureLockReason.modeIsDisplayOnly;
  }

  if (mode == null) return ExposureLockReason.unknownMode;
  if (CameraExposureMode.isAuto(mode)) return ExposureLockReason.autoMode;

  switch (mode) {
    case CameraExposureMode.manual:
      return ExposureLockReason.none;
    case CameraExposureMode.aperturePriority:
      // A 档：光圈与 ISO 由用户决定，快门由机身测光决定。
      return switch (parameter) {
        CameraParameter.shutter => ExposureLockReason.bodyModeExcludes,
        _ => ExposureLockReason.none,
      };
    case CameraExposureMode.shutterPriority:
      // S 档：快门与 ISO 由用户决定，光圈由机身决定。
      return switch (parameter) {
        CameraParameter.aperture => ExposureLockReason.bodyModeExcludes,
        _ => ExposureLockReason.none,
      };
    case CameraExposureMode.program:
      // P 档：机身决定光圈与快门，ISO 与曝光补偿仍可调。
      return switch (parameter) {
        CameraParameter.aperture ||
        CameraParameter.shutter =>
          ExposureLockReason.bodyModeExcludes,
        _ => ExposureLockReason.none,
      };
    default:
      return ExposureLockReason.unknownMode;
  }
}

/// 按档位推断是否可编辑（兜底用，界面实际读 `writable`）。
///
/// `unknownMode` 下**允许尝试**：读不到模式不应该把参数全锁死，
/// 真写不动时还有回读比对兜底。
bool isEditable(CameraParameter parameter, int? mode) {
  final reason = lockReasonFor(parameter, mode);
  return reason == ExposureLockReason.none ||
      reason == ExposureLockReason.unknownMode;
}

/// 当前档位下被机身接管的参数列表，用于界面一次性展示提示。
List<CameraParameter> lockedParameters(int? mode) {
  return CameraParameter.values
      .where((p) => !isEditable(p, mode) &&
          p != CameraParameter.mode)
      .toList(growable: false);
}

/// 模式码 → 简短标签（与 `CameraValueLabels.mode` 保持一致）。
String modeLabel(int? mode) {
  if (mode == null) return CameraValueLabels.unknown;
  return CameraValueLabels.mode(mode);
}
