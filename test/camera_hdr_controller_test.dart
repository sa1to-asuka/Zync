import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/engine/capture/camera_hdr_controller.dart';
import 'package:zync/engine/capture/ptp_device_prop_desc.dart';

class _FakeHdrDriver implements HdrDriver {
  _FakeHdrDriver({
    Map<int, int>? initial,
    Map<int, PtpDevicePropDesc>? descriptors,
  })  : values = <int, int>{...?initial},
        descriptors = <int, PtpDevicePropDesc>{...?descriptors};

  final Map<int, int> values;
  final Map<int, PtpDevicePropDesc> descriptors;

  /// 拒绝写入的属性 id。
  final Set<int> rejected = <int>{};

  /// 写入后回读仍返回旧值的属性 id（模拟相机忽略写入）。
  final Set<int> ignored = <int>{};

  final List<(int, int)> writes = <(int, int)>[];

  @override
  bool get isConnected => true;

  @override
  Future<PtpDevicePropDesc?> readPropertyDesc(int propertyId) async =>
      descriptors[propertyId];

  @override
  Future<int?> readUintProperty(int propertyId) async => values[propertyId];

  @override
  Future<void> writeUintProperty(int propertyId, int value) async {
    if (rejected.contains(propertyId)) {
      throw StateError('相机拒绝写入 0x${propertyId.toRadixString(16)}');
    }
    writes.add((propertyId, value));
    if (!ignored.contains(propertyId)) values[propertyId] = value;
  }
}

Map<int, int> _defaults() => <int, int>{
      PtpOpCodes.nikonPropHdrMode: 0,
      PtpOpCodes.nikonPropHdrHighDynamic: 0,
      PtpOpCodes.nikonPropHdrSmoothing: 1,
      PtpOpCodes.nikonPropHdrSaveIndividual: 0,
    };

void main() {
  test('开启 HDR、拍摄、再还原全部属性', () async {
    final driver = _FakeHdrDriver(initial: _defaults());
    var captures = 0;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async => captures++,
    );

    final result = await controller.shoot(highDynamic: 2, smoothing: 1);

    expect(result, HdrResult.merged);
    expect(captures, 1);
    expect(driver.writes.first, (PtpOpCodes.nikonPropHdrSaveIndividual, 1));
    expect(driver.writes, contains((PtpOpCodes.nikonPropHdrMode, 1)));
    // 结束后回到拍摄前的状态。
    expect(driver.values[PtpOpCodes.nikonPropHdrMode], 0);
    expect(driver.values[PtpOpCodes.nikonPropHdrHighDynamic], 0);
    expect(driver.writes.last, (PtpOpCodes.nikonPropHdrSaveIndividual, 0));
  });

  test('读不到 0xD130 时判定为不支持，且不按快门', () async {
    final driver = _FakeHdrDriver(initial: <int, int>{});
    var captures = 0;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async => captures++,
    );

    final result = await controller.shoot();

    expect(result, HdrResult.unsupported);
    expect(captures, 0);
  });

  test('写入被拒时返回不支持', () async {
    final driver = _FakeHdrDriver(initial: _defaults());
    driver.rejected.add(PtpOpCodes.nikonPropHdrMode);
    var captures = 0;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async => captures++,
    );

    final result = await controller.shoot();

    expect(result, HdrResult.unsupported);
    expect(captures, 0);
  });

  test('相机忽略写入（回读仍为 0）时不按快门', () async {
    final driver = _FakeHdrDriver(initial: _defaults());
    driver.ignored.add(PtpOpCodes.nikonPropHdrMode);
    var captures = 0;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async => captures++,
    );

    final result = await controller.shoot();

    expect(result, HdrResult.unsupported);
    expect(captures, 0);
  });

  test('快门失败返回 captureFailed，且仍会还原配置', () async {
    final driver = _FakeHdrDriver(initial: _defaults());
    final controller = CameraHdrController(
      driver: driver,
      capture: () async => throw StateError('快门失败'),
    );

    final result = await controller.shoot();

    expect(result, HdrResult.captureFailed);
    expect(driver.values[PtpOpCodes.nikonPropHdrMode], 0,
        reason: '失败也要把相机还原，不能留在 HDR 模式');
  });

  test('原本已开启 HDR 时保留用户设置', () async {
    final driver = _FakeHdrDriver(initial: <int, int>{
      PtpOpCodes.nikonPropHdrMode: 1,
      PtpOpCodes.nikonPropHdrHighDynamic: 3,
      PtpOpCodes.nikonPropHdrSmoothing: 4,
      PtpOpCodes.nikonPropHdrSaveIndividual: 1,
    });
    final controller = CameraHdrController(
      driver: driver,
      capture: () async {},
    );

    await controller.shoot(highDynamic: 1, smoothing: 0);

    expect(driver.values[PtpOpCodes.nikonPropHdrMode], 1);
    expect(driver.values[PtpOpCodes.nikonPropHdrHighDynamic], 3);
    expect(driver.values[PtpOpCodes.nikonPropHdrSmoothing], 4);
  });

  test('Nikon Z 30 枚举映射：0xD131 [6,12,18,255] 与 0xD132 [2,3,4]', () async {
    final driver = _FakeHdrDriver(
      initial: <int, int>{
        PtpOpCodes.nikonPropHdrMode: 0,
        PtpOpCodes.nikonPropHdrHighDynamic: 255,
        PtpOpCodes.nikonPropHdrSmoothing: 3,
        PtpOpCodes.nikonPropHdrSaveIndividual: 0,
      },
      descriptors: <int, PtpDevicePropDesc>{
        PtpOpCodes.nikonPropHdrHighDynamic: const PtpDevicePropDesc(
          property: PtpOpCodes.nikonPropHdrHighDynamic,
          dataType: 0x0002,
          writable: true,
          factoryDefault: 255,
          currentValue: 255,
          form: PtpPropForm.enumeration,
          enumValues: <int>[6, 12, 18, 255],
        ),
        PtpOpCodes.nikonPropHdrSmoothing: const PtpDevicePropDesc(
          property: PtpOpCodes.nikonPropHdrSmoothing,
          dataType: 0x0004,
          writable: true,
          factoryDefault: 3,
          currentValue: 3,
          form: PtpPropForm.enumeration,
          enumValues: <int>[2, 3, 4],
        ),
      },
    );

    int? highDynDuringShot;
    int? smoothingDuringShot;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async {
        highDynDuringShot = driver.values[PtpOpCodes.nikonPropHdrHighDynamic];
        smoothingDuringShot = driver.values[PtpOpCodes.nikonPropHdrSmoothing];
      },
    );

    // 传入逻辑档位 2 (2EV) 与普通平滑 1，应自动映射到 Z 30 的 12 与 3
    final result = await controller.shoot(highDynamic: 2, smoothing: 1);

    expect(result, HdrResult.merged);
    expect(highDynDuringShot, 12);
    expect(smoothingDuringShot, 3);
  });

  test('RAW 模式下自动临时切换为 JPEG 并在拍摄后还原 0x5004', () async {
    final driver = _FakeHdrDriver(
      initial: <int, int>{
        ..._defaults(),
        PtpOpCodes.devicePropCompressionSetting: 4, // RAW (NEF)
      },
      descriptors: <int, PtpDevicePropDesc>{
        PtpOpCodes.devicePropCompressionSetting: const PtpDevicePropDesc(
          property: PtpOpCodes.devicePropCompressionSetting,
          dataType: 0x0002,
          writable: true,
          factoryDefault: 4,
          currentValue: 4,
          form: PtpPropForm.enumeration,
          enumValues: <int>[0, 1, 2, 4, 5, 6, 7],
        ),
      },
    );

    int? compressionDuringShot;
    final controller = CameraHdrController(
      driver: driver,
      capture: () async {
        compressionDuringShot =
            driver.values[PtpOpCodes.devicePropCompressionSetting];
      },
    );

    final result = await controller.shoot();

    expect(result, HdrResult.merged);
    expect(compressionDuringShot, 2, reason: '拍摄期间应临时切到 JPEG Fine (2)');
    expect(driver.values[PtpOpCodes.devicePropCompressionSetting], 4,
        reason: '拍摄结束后必须还原回 RAW (4)');
  });
}
