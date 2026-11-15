import 'dart:typed_data';

import '../../core/constants/ptp_opcodes.dart';
import '../../core/utils/app_log_manager.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/ptp_ip_client.dart' show PtpException;
import 'capture_controller.dart';
import 'camera_property.dart';
import 'exposure_bracketing_controller.dart';
import 'exposure_settings_controller.dart';
import 'focus_stacking_controller.dart';

CameraParameter _parameterFor(BracketAxis axis) => switch (axis) {
      BracketAxis.exposureCompensation =>
        CameraParameter.exposureCompensation,
      BracketAxis.shutter => CameraParameter.shutter,
      BracketAxis.iso => CameraParameter.iso,
    };

/// 把 [ExposureSettingsController] 适配成包围曝光所需的端口。
///
/// 复用 `apply()` 的好处是它会写后回读校验——包围曝光最怕的就是
/// 「以为写进去了，其实相机没接受」，那样整组照片的曝光间隔都是错的。
class ExposureSettingsBracketPort implements BracketPort {
  ExposureSettingsBracketPort({
    required this.driver,
    required this.exposure,
    required this.captureController,
  });

  final CameraDriver driver;
  final ExposureSettingsController exposure;
  final CaptureController captureController;

  @override
  bool get isConnected => driver.isConnected;

  @override
  Future<int?> readBuiltInBracketing() async {
    try {
      final data = await driver
          .fetchDevicePropValue(PtpOpCodes.devicePropEnableAeBracketing);
      if (data.isEmpty) return null;
      return data[0];
    } catch (_) {
      // 老固件可能没有这个属性，不阻塞包围曝光。
      return null;
    }
  }

  Future<PropertyBinding?> _binding(BracketAxis axis) async {
    final parameter = _parameterFor(axis);
    final existing = exposure.bindingOf(parameter);
    if (existing != null) return existing;
    await exposure.refresh(force: true);
    return exposure.bindingOf(parameter);
  }

  @override
  Future<List<int>> optionsOf(BracketAxis axis) async {
    final binding = await _binding(axis);
    return binding?.options ?? const <int>[];
  }

  @override
  Future<int?> currentOf(BracketAxis axis) async {
    final binding = await _binding(axis);
    return binding?.currentValue;
  }

  @override
  Future<bool> write(BracketAxis axis, int raw) async {
    final outcome = await exposure.apply(_parameterFor(axis), raw);
    return outcome is SettingsApplied;
  }

  @override
  Future<CameraFileItem?> capture() async {
    final outcome = await captureController.capture();
    return outcome is CaptureConfirmed ? outcome.file : null;
  }

  @override
  Future<void> settle(Duration duration) => Future<void>.delayed(duration);
}

/// 把驱动的手动对焦适配成焦点堆叠所需的端口。
class DriverFocusStackPort implements FocusStackPort {
  DriverFocusStackPort({
    required this.driver,
    required this.captureController,
  });

  final CameraDriver driver;
  final CaptureController captureController;

  @override
  bool get isConnected => driver.isConnected;

  @override
  Future<bool> drive(MfDirection direction, int steps) async {
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        await driver.mfDrive(direction, steps);
        return true;
      } on PtpException catch (e) {
        // 0xA00C：已经到行程尽头，继续推进会得到一串完全相同的照片。
        if (e.responseCode == PtpOpCodes.responseNikonMfDriveStepEnd) {
          return false;
        }
        // 拍摄恢复取景后相机可能短暂处于 Busy (0x2019) 或取景尚未就绪 (0xA004)，稍等重试。
        if ((e.responseCode == PtpOpCodes.responseDeviceBusy ||
                e.responseCode == PtpOpCodes.responseNikonInvalidStatus) &&
            attempt < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 90));
          try {
            await driver.deviceReady();
          } catch (_) {}
          continue;
        }
        rethrow;
      }
    }
    return false;
  }

  @override
  Future<CameraFileItem?> capture() async {
    // 不要走 0x9207 preserveFocus：部分固件对它会回「成功」却不真正落盘，
    // 表现为焦点一直在动但相机没拍。镜头在 MF 档时普通快门同样不会重新对焦。
    final outcome = await captureController.capture();
    switch (outcome) {
      case CaptureConfirmed(:final file):
        return file;
      case CaptureRejected(:final responseCode):
        AppLogManager.instance.add(
            '[focus] capture rejected 0x${responseCode.toRadixString(16)}');
        return null;
      case CaptureUnconfirmed():
        AppLogManager.instance
            .add('[focus] capture unconfirmed (no new object in time)');
        return null;
    }
  }

  @override
  Future<void> settle(Duration duration) => Future<void>.delayed(duration);
}

/// 从 `0xD0C0` 的原始字节里读开关值（部分机型是 UINT8，部分 UINT32）。
int? builtInBracketingFromBytes(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  if (bytes.length >= 4) {
    return ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.little);
  }
  return bytes[0];
}
