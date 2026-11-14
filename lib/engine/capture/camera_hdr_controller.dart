import '../../core/constants/ptp_opcodes.dart';
import '../../core/utils/app_log_manager.dart';

/// 机内 HDR 所需的相机能力。
///
/// 抽成接口而不是直接吃 `CameraDriver`：这一块只用到 UINT8 属性的读写，
/// 单测里给一个内存实现就够。
abstract class HdrDriver {
  bool get isConnected;

  /// 读一个 UINT8 设备属性；读不到返回 null。
  Future<int?> readUintProperty(int propertyId);

  /// 写一个 UINT8 设备属性；相机拒绝时抛异常。
  Future<void> writeUintProperty(int propertyId, int value);
}

/// 相机当前的 HDR 配置。
class CameraHdrState {
  const CameraHdrState({
    required this.mode,
    required this.highDynamic,
    required this.smoothing,
    required this.saveIndividuals,
  });

  final int mode;
  final int highDynamic;
  final int smoothing;
  final int saveIndividuals;

  bool get isEnabled => mode != 0;

  CameraHdrState copyWith({
    int? mode,
    int? highDynamic,
    int? smoothing,
    int? saveIndividuals,
  }) =>
      CameraHdrState(
        mode: mode ?? this.mode,
        highDynamic: highDynamic ?? this.highDynamic,
        smoothing: smoothing ?? this.smoothing,
        saveIndividuals: saveIndividuals ?? this.saveIndividuals,
      );
}

/// 机内 HDR 的拍摄结果。
enum HdrResult {
  /// 相机已开启 HDR 并完成一次拍摄（相机自己合成）。
  merged,

  /// 这台机身没有 HDR 属性，或拒绝写入。
  unsupported,

  /// 属性写进去了，但快门失败。
  captureFailed,
}

/// 机内 HDR 控制。
///
/// Z 30 的 `0xD130`–`0xD133` 由相机自己拍两张并合成一张 JPEG，
/// 比 App 端融合的质量高得多，也省掉一次大图解码。
/// 写入顺序刻意把 `HDRMode` 放最后：中途失败时相机不会被留在半配置状态。
class CameraHdrController {
  CameraHdrController({
    required this.driver,
    required Future<void> Function() capture,
  }) : _capture = capture;

  final HdrDriver driver;
  final Future<void> Function() _capture;

  /// 读取当前 HDR 配置；读不到返回 null。
  Future<CameraHdrState?> readState() async {
    if (!driver.isConnected) return null;
    final mode = await driver.readUintProperty(PtpOpCodes.nikonPropHdrMode);
    if (mode == null) {
      // 记下来：Z 30 上如果这条读不到，说明机身没有通过 PTP 暴露
      // 「高动态范围」开关，只能让用户在机身菜单里自己打开。
      AppLogManager.instance.add('[hdr] 0xD130 read failed (property hidden)');
      return null;
    }
    return CameraHdrState(
      mode: mode,
      highDynamic:
          await driver.readUintProperty(PtpOpCodes.nikonPropHdrHighDynamic) ??
              0,
      smoothing:
          await driver.readUintProperty(PtpOpCodes.nikonPropHdrSmoothing) ?? 1,
      saveIndividuals:
          await driver.readUintProperty(PtpOpCodes.nikonPropHdrSaveIndividual) ??
              0,
    );
  }

  /// 开启机内 HDR 并拍一张，结束后把配置还原。
  ///
  /// [highDynamic]：0=自动，1=±1EV，2=±2EV，3=±3EV。
  /// [smoothing]：0=强，1=标准，2=弱，3=自动，4=超强。
  /// [saveIndividuals]：让相机同时把两张原片也留在卡上。
  Future<HdrResult> shoot({
    int highDynamic = 2,
    int smoothing = 1,
    bool saveIndividuals = true,
  }) async {
    if (!driver.isConnected) return HdrResult.unsupported;

    final previous = await readState();
    if (previous == null) return HdrResult.unsupported;

    var enabled = false;
    try {
      // 先写附属参数，最后开 HDR，避免中途失败留下半开状态。
      try {
        await driver.writeUintProperty(
            PtpOpCodes.nikonPropHdrSaveIndividual, saveIndividuals ? 1 : 0);
      } catch (_) {
        // 部分固件不允许保存单张原片；主流程不受影响。
      }
      await driver.writeUintProperty(
          PtpOpCodes.nikonPropHdrHighDynamic, highDynamic);
      await driver.writeUintProperty(
          PtpOpCodes.nikonPropHdrSmoothing, smoothing);
      await driver.writeUintProperty(PtpOpCodes.nikonPropHdrMode, 1);

      final actual =
          await driver.readUintProperty(PtpOpCodes.nikonPropHdrMode);
      if (actual != 1) return HdrResult.unsupported;
      enabled = true;

      await _capture();
      return HdrResult.merged;
    } catch (_) {
      // 写属性阶段被拒 = 不支持；已经开起来之后的失败算快门失败。
      return enabled ? HdrResult.captureFailed : HdrResult.unsupported;
    } finally {
      // 即使中途失败也要还原：附属参数可能已经写进去了，
      // 不能把相机留在「HDR 关着但动态范围/降噪被改过」的状态。
      // 逐项还原，某一项被拒不影响其余几项。
      Future<void> restore(int propertyId, int value) async {
        try {
          await driver.writeUintProperty(propertyId, value);
        } catch (_) {}
      }

      await restore(PtpOpCodes.nikonPropHdrMode, previous.mode);
      await restore(
          PtpOpCodes.nikonPropHdrHighDynamic, previous.highDynamic);
      await restore(PtpOpCodes.nikonPropHdrSmoothing, previous.smoothing);
      await restore(
          PtpOpCodes.nikonPropHdrSaveIndividual, previous.saveIndividuals);
    }
  }
}
