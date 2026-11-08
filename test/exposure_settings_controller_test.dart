import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/camera_property.dart';
import 'package:zync/engine/capture/exposure_settings_controller.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/protocol/camera_driver.dart';

import 'helpers/fake_capture_driver.dart';

Future<void> _frameSleep(Duration _) =>
    Future<void>.delayed(const Duration(milliseconds: 1));

/// 构造 0x1014 数据集（UINT16 枚举型）。
Uint8List _u16EnumDesc({
  required int property,
  required int current,
  required List<int> values,
  bool writable = true,
}) {
  final b = BytesBuilder();
  final view = ByteData(4);

  void u16(int v) {
    view.setUint16(0, v, Endian.little);
    b.add(view.buffer.asUint8List(0, 2));
  }

  u16(property);
  u16(0x0004); // UINT16
  b.add(<int>[writable ? 1 : 0]);
  u16(values.isNotEmpty ? values.first : current); // factory default
  u16(current);
  b.add(<int>[2]); // 枚举型
  u16(values.length);
  for (final v in values) {
    u16(v);
  }
  return b.toBytes();
}

/// 构造 0x1014 数据集（UINT16 范围型）。
Uint8List _u16RangeDesc({
  required int property,
  required int current,
  required int min,
  required int max,
  required int step,
  bool writable = true,
}) {
  final b = BytesBuilder();
  final view = ByteData(4);

  void u16(int v) {
    view.setUint16(0, v, Endian.little);
    b.add(view.buffer.asUint8List(0, 2));
  }

  u16(property);
  u16(0x0004); // UINT16
  b.add(<int>[writable ? 1 : 0]);
  u16(current); // factory default
  u16(current);
  b.add(<int>[1]); // 范围型
  u16(min);
  u16(max);
  u16(step);
  return b.toBytes();
}

ExposureSettingsController _controller(
  FakeCaptureDriver driver,
  LiveViewController liveView,
) {
  return ExposureSettingsController(
    driver: driver,
    liveView: liveView,
    sleep: (_) async {},
  );
}

void main() {
  group('ExposureSettingsController.refresh', () {
    test('读取到光圈属性描述与选项', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400, 560],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      await controller.refresh(force: true);

      final binding = controller.bindingOf(CameraParameter.aperture);
      expect(binding, isNotNull);
      expect(binding!.currentValue, 280);
      expect(binding.options, <int>[280, 400, 560]);
      expect(binding.labelOf(400), 'f/4.0');
    });

    test('相机不支持的参数不会留下陈旧绑定', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      await controller.refresh(force: true);

      expect(controller.bindingOf(CameraParameter.aperture), isNotNull);
      expect(controller.bindingOf(CameraParameter.iso), isNull);
    });

    test('未连接时清空绑定', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);
      expect(controller.hasData, isTrue);

      driver.state = CameraConnectionState.disconnected;
      await controller.refresh(force: true);

      expect(controller.hasData, isFalse);
    });
  });

  group('ExposureSettingsController.apply', () {
    test('写入并被回读确认时返回 Applied', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400, 560],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect(outcome, isA<SettingsApplied>());
      expect((outcome as SettingsApplied).effectiveValue, 400);
      expect(driver.lastWrittenProperty, 0x5007);
      expect(driver.lastWrittenPayload, <int>[0x90, 0x01]);
    });

    test('相机静默忽略写入时，回读不一致会被发现', () async {
      final driver = FakeCaptureDriver()..ignoreWrites = true;
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400, 560],
      );
      // 相机保持原值
      driver.propValues[0x5007] = Uint8List.fromList(<int>[0x18, 0x01]); // 280
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect(outcome, isA<SettingsRejected>());
      final rejected = outcome as SettingsRejected;
      expect(rejected.reason, SettingsRejectReason.readbackMismatch);
      expect(rejected.effectiveValue, 280);
    });

    test('0x200F 映射为「机身不在 M 档」', () async {
      final driver = FakeCaptureDriver()..writeRejectCode = 0x200F;
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect((outcome as SettingsRejected).reason,
          SettingsRejectReason.dialNotInManual);
    });

    test('0x2019 映射为忙', () async {
      final driver = FakeCaptureDriver()..writeRejectCode = 0x2019;
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect((outcome as SettingsRejected).reason, SettingsRejectReason.busy);
    });

    test('只读属性直接拒绝，不发写入指令', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400],
        writable: false,
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect((outcome as SettingsRejected).reason,
          SettingsRejectReason.notWritable);
      expect(driver.calls.any((c) => c.startsWith('write:')), isFalse);
    });

    test('USB 偶发 0x201c 会重试一次并成功', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400, 560],
      );
      driver.writeFailures.add(PlatformException(
        code: 'USB_DATA_OUT_FAILED',
        message: 'PTP USB 操作 0x1016 失败，响应码 0x201c（Unknown）',
      ));
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect(outcome, isA<SettingsApplied>());
      expect(
        driver.calls.where((c) => c == 'write:20487').length,
        2,
        reason: '第一次失败后应重试一次',
      );
    });

    test('持续 0x201c 映射为「相机正忙」', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16EnumDesc(
        property: 0x5007,
        current: 280,
        values: <int>[280, 400, 560],
      );
      driver.writeFailures.addAll(<Object>[
        PlatformException(code: 'USB_DATA_OUT_FAILED', message: '响应码 0x201c'),
        PlatformException(code: 'USB_DATA_OUT_FAILED', message: '响应码 0x201c'),
      ]);
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      final outcome = await controller.apply(CameraParameter.aperture, 400);

      expect((outcome as SettingsRejected).reason, SettingsRejectReason.busy);
    });

    test('没有属性描述时返回 unavailable', () async {
      final driver = FakeCaptureDriver();
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      final outcome =
          await controller.apply(CameraParameter.shutter, 0x000100FA);

      expect((outcome as SettingsRejected).reason,
          SettingsRejectReason.unavailable);
    });
  });

  group('范围型属性', () {
    test('范围描述会被展开成可选值列表，滑条才有刻度', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16RangeDesc(
        property: 0x5007,
        current: 400,
        min: 280,
        max: 560,
        step: 40,
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      await controller.refresh(force: true);

      final binding = controller.bindingOf(CameraParameter.aperture);
      expect(binding, isNotNull);
      expect(binding!.options, <int>[280, 320, 360, 400, 440, 480, 520, 560]);
      expect(binding.labelOf(binding.currentValue), 'f/4.0');
    });

    test('范围过大时放弃展开，避免生成上万个刻度', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x5007] = _u16RangeDesc(
        property: 0x5007,
        current: 280,
        min: 0,
        max: 65535,
        step: 1,
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      await controller.refresh(force: true);

      expect(controller.bindingOf(CameraParameter.aperture)!.options, isEmpty);
    });
  });

  group('模式轮询', () {
    test('机身档位变化后 refreshMode 返回 true', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x500E] = _u16EnumDesc(
        property: 0x500E,
        current: 3, // A
        values: <int>[1, 2, 3, 4],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);
      expect(controller.bindingOf(CameraParameter.mode)!.currentValue, 3);

      // 用户在机身上把拨盘从 A 转到 S
      driver.propDescs[0x500E] = _u16EnumDesc(
        property: 0x500E,
        current: 4,
        values: <int>[1, 2, 3, 4],
      );

      expect(await controller.refreshMode(), isTrue);
      expect(controller.bindingOf(CameraParameter.mode)!.currentValue, 4);
    });

    test('档位没变时 refreshMode 返回 false', () async {
      final driver = FakeCaptureDriver();
      driver.propDescs[0x500E] = _u16EnumDesc(
        property: 0x500E,
        current: 3,
        values: <int>[1, 2, 3, 4],
      );
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);
      await controller.refresh(force: true);

      expect(await controller.refreshMode(), isFalse);
    });

    test('未连接时不轮询', () async {
      final driver = FakeCaptureDriver()
        ..state = CameraConnectionState.disconnected;
      final liveView = LiveViewController(driver: driver, sleep: _frameSleep);
      final controller = _controller(driver, liveView);

      expect(await controller.refreshMode(), isFalse);
    });
  });
}
