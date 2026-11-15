import '../../core/constants/ptp_opcodes.dart';
import '../../core/utils/app_log_manager.dart';
import 'ptp_device_prop_desc.dart';

/// 机内 HDR 所需的相机能力。
///
/// 抽成接口而不是直接吃 `CameraDriver`：这一块只用到整数属性的读写与描述符查询，
/// 单测里给一个内存实现就够。
abstract class HdrDriver {
  bool get isConnected;

  /// 读取设备属性描述（用于识别 Z 30 上 UINT8 / UINT16 宽度与真实枚举表）。
  Future<PtpDevicePropDesc?> readPropertyDesc(int propertyId) async => null;

  /// 读一个无符号整数设备属性（1/2/4 字节自适应）；读不到返回 null。
  Future<int?> readUintProperty(int propertyId);

  /// 写一个无符号整数设备属性（按属性描述符宽度编码）；相机拒绝时抛异常。
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
    var mode = await driver.readUintProperty(PtpOpCodes.nikonPropHdrMode);
    mode ??= (await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrMode))
        ?.currentValue;
    if (mode == null) {
      AppLogManager.instance
          .add('[hdr] 0xD130 read failed (property unavailable)');
      return null;
    }
    final highDynamic =
        await driver.readUintProperty(PtpOpCodes.nikonPropHdrHighDynamic) ??
            (await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrHighDynamic))
                ?.currentValue ??
            0;
    final smoothing =
        await driver.readUintProperty(PtpOpCodes.nikonPropHdrSmoothing) ??
            (await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrSmoothing))
                ?.currentValue ??
            1;
    final saveIndividuals =
        await driver.readUintProperty(PtpOpCodes.nikonPropHdrSaveIndividual) ??
            (await driver
                    .readPropertyDesc(PtpOpCodes.nikonPropHdrSaveIndividual))
                ?.currentValue ??
            0;
    return CameraHdrState(
      mode: mode,
      highDynamic: highDynamic,
      smoothing: smoothing,
      saveIndividuals: saveIndividuals,
    );
  }

  /// 将逻辑动态范围档位（0=自动, 1=1EV, 2=2EV, 3=3EV）映射为机身实际枚举值。
  ///
  /// Nikon Z 30 (`nikon-z30.txt`) 的 `0xD131` 枚举为 `[6, 12, 18, 255]`（1/3 EV 步进与 255 自动），
  /// 而老单反为 `[0, 1, 2, 3]`。
  static int resolveHighDynamic(int logicalEv, PtpDevicePropDesc? desc) {
    final enums = desc?.enumValues ?? const <int>[];
    if (enums.isEmpty) return logicalEv;
    const zSeriesMap = <int, int>{0: 255, 1: 6, 2: 12, 3: 18};
    final mapped = zSeriesMap[logicalEv];
    if (mapped != null && enums.contains(mapped)) return mapped;
    if (enums.contains(logicalEv)) return logicalEv;
    return enums.first;
  }

  /// 将逻辑平滑度档位映射为机身实际枚举值。
  ///
  /// Nikon Z 30 的 `0xD132` 为 `UINT16`，枚举为 `[2, 3, 4]`（弱/标准/强），不含 `1`。
  static int resolveSmoothing(int logicalSmoothing, PtpDevicePropDesc? desc) {
    final enums = desc?.enumValues ?? const <int>[];
    if (enums.isEmpty) return logicalSmoothing;
    if (enums.contains(logicalSmoothing)) return logicalSmoothing;
    if (logicalSmoothing == 1 && enums.contains(3)) return 3;
    return enums[enums.length ~/ 2];
  }

  /// 开启机内 HDR 并拍一张，结束后把配置还原。
  ///
  /// [highDynamic]：0=自动，1=±1EV，2=±2EV，3=±3EV（自动适配 Z 30 的 `255/6/12/18`）。
  /// [smoothing]：默认 1=标准（自动适配 Z 30 的 `UINT16 [2,3,4]`）。
  /// [saveIndividuals]：让相机同时把两张原片也留在卡上。
  Future<HdrResult> shoot({
    int highDynamic = 2,
    int smoothing = 1,
    bool saveIndividuals = true,
  }) async {
    if (!driver.isConnected) return HdrResult.unsupported;

    final previous = await readState();
    if (previous == null) return HdrResult.unsupported;

    // Nikon Z 30 在 RAW / RAW+JPEG (0x5004 >= 4) 下机身锁死机内 HDR（仅纯 JPEG 可用）。
    // 若检测到当前处于 RAW 画质，临时切到最佳纯 JPEG 档位，拍完在 finally 还原。
    int? previousCompression;
    var switchedCompression = false;
    try {
      final comp =
          await driver.readUintProperty(PtpOpCodes.devicePropCompressionSetting);
      if (comp != null && comp >= 4) {
        previousCompression = comp;
        final compDesc = await driver
            .readPropertyDesc(PtpOpCodes.devicePropCompressionSetting);
        final jpegOptions = (compDesc?.enumValues ?? const <int>[0, 1, 2])
            .where((v) => v >= 0 && v < 4)
            .toList();
        final targetJpeg = jpegOptions.isNotEmpty ? jpegOptions.last : 2;
        await driver.writeUintProperty(
            PtpOpCodes.devicePropCompressionSetting, targetJpeg);
        switchedCompression = true;
        AppLogManager.instance.add(
          '[hdr] temporarily switched 0x5004 compression $comp -> $targetJpeg for in-camera HDR',
        );
      }
    } catch (e) {
      AppLogManager.instance.add('[hdr] compression check/switch skipped: $e');
    }

    var enabled = false;
    try {
      // 先写附属参数，最后开 HDR，避免中途失败留下半开状态。
      try {
        await driver.writeUintProperty(
            PtpOpCodes.nikonPropHdrSaveIndividual, saveIndividuals ? 1 : 0);
      } catch (_) {
        // 部分固件不允许保存单张原片；主流程不受影响。
      }

      final hdDesc =
          await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrHighDynamic);
      final targetHd = resolveHighDynamic(highDynamic, hdDesc);
      try {
        await driver.writeUintProperty(
            PtpOpCodes.nikonPropHdrHighDynamic, targetHd);
      } catch (_) {
        // 未能读到描述符时回退尝试 Z 系列编码 (0->255, 1->6, 2->12, 3->18)
        const fallbackMap = <int, int>{0: 255, 1: 6, 2: 12, 3: 18};
        final alt = fallbackMap[highDynamic];
        if (alt != null && alt != targetHd) {
          await driver.writeUintProperty(
              PtpOpCodes.nikonPropHdrHighDynamic, alt);
        } else {
          rethrow;
        }
      }

      final smoothDesc =
          await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrSmoothing);
      final targetSmooth = resolveSmoothing(smoothing, smoothDesc);
      try {
        await driver.writeUintProperty(
            PtpOpCodes.nikonPropHdrSmoothing, targetSmooth);
      } catch (_) {
        if (targetSmooth != 3) {
          try {
            await driver.writeUintProperty(PtpOpCodes.nikonPropHdrSmoothing, 3);
          } catch (_) {}
        }
      }

      final modeDesc =
          await driver.readPropertyDesc(PtpOpCodes.nikonPropHdrMode);
      final modeChoices = modeDesc?.enumValues ?? const <int>[];
      final targetMode = modeChoices.isEmpty || modeChoices.contains(1)
          ? 1
          : modeChoices.firstWhere((v) => v != 0, orElse: () => 1);
      await driver.writeUintProperty(PtpOpCodes.nikonPropHdrMode, targetMode);

      final actual =
          await driver.readUintProperty(PtpOpCodes.nikonPropHdrMode);
      if (actual == null || actual == 0) {
        AppLogManager.instance
            .add('[hdr] 0xD130 readback stayed $actual after write');
        return HdrResult.unsupported;
      }
      enabled = true;

      await _capture();
      return HdrResult.merged;
    } catch (e) {
      AppLogManager.instance.add('[hdr] shoot failed (enabled=$enabled): $e');
      // 写属性阶段被拒 = 不支持；已经开起来之后的失败算快门失败。
      return enabled ? HdrResult.captureFailed : HdrResult.unsupported;
    } finally {
      // 即使中途失败也要还原：附属参数可能已经写进去了，
      // 不能把相机留在「HDR 关着但动态范围/降噪/画质被改过」的状态。
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
      if (switchedCompression && previousCompression != null) {
        await restore(
            PtpOpCodes.devicePropCompressionSetting, previousCompression);
      }
    }
  }
}
