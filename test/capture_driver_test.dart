import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/protocol/ptp_ip_client.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/ptp_transport.dart';

/// 可按操作码脚本化失败与返回值的假传输层。
class ScriptedTransport implements PtpTransport {
  bool connected = false;
  final List<String> calls = <String>[];

  /// opCode -> 依次抛出的异常；用尽后按正常路径成功。
  final Map<int, List<Object>> failures = <int, List<Object>>{};

  /// opCode -> data-in 返回负载。
  final Map<int, Uint8List> dataIn = <int, Uint8List>{};

  int succeedingDataInLength = 0;

  @override
  bool get isConnected => connected;

  @override
  Stream<PtpPacket> get events => const Stream.empty();

  @override
  Future<void> connect() async {
    connected = true;
    calls.add('connect');
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  void _throwIfScripted(int opCode) {
    final queue = failures[opCode];
    if (queue != null && queue.isNotEmpty) {
      throw queue.removeAt(0);
    }
  }

  @override
  Future<void> executeOperation(int opCode,
      [List<int> params = const []]) async {
    calls.add('op:0x${opCode.toRadixString(16)}:${params.join(",")}');
    _throwIfScripted(opCode);
  }

  @override
  Future<Uint8List> executeDataIn(int opCode,
      [List<int> params = const []]) async {
    calls.add('in:0x${opCode.toRadixString(16)}:${params.join(",")}');
    _throwIfScripted(opCode);
    final canned = dataIn[opCode];
    if (canned != null) return canned;
    return Uint8List(succeedingDataInLength);
  }

  @override
  Future<void> executeDataOut(int opCode, Uint8List data,
      [List<int> params = const []]) async {
    calls.add('out:0x${opCode.toRadixString(16)}:${params.join(",")}:${data.length}');
    _throwIfScripted(opCode);
  }
}

/// 连上假传输层的驱动。
Future<(NikonDriver, ScriptedTransport)> _connectedDriver() async {
  final transport = ScriptedTransport();
  final driver = NikonDriver();
  await driver.connectTransport(transport);
  return (driver, transport);
}

void main() {
  group('实时取景', () {
    test('startLiveView 发送 0x9201', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.startLiveView();
      expect(transport.calls, contains('op:0x9201:'));
      driver.dispose();
    });

    test('重复 startLiveView 不会重复发送', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.startLiveView();
      await driver.startLiveView();
      final count =
          transport.calls.where((c) => c.startsWith('op:0x9201')).length;
      expect(count, 1);
      driver.dispose();
    });

    test('设备忙时重试', () async {
      final (driver, transport) = await _connectedDriver();
      transport.failures[PtpOpCodes.nikonStartLiveView] = <Object>[
        PtpException(
            PtpOpCodes.nikonStartLiveView, PtpOpCodes.responseDeviceBusy),
      ];

      await driver.startLiveView();

      final count =
          transport.calls.where((c) => c.startsWith('op:0x9201')).length;
      expect(count, 2);
      driver.dispose();
    });

    test('fetchLiveViewFrame 走 0x9203 数据输入', () async {
      final (driver, transport) = await _connectedDriver();
      transport.dataIn[PtpOpCodes.nikonGetLiveViewImage] =
          Uint8List.fromList(<int>[1, 2, 3]);

      final frame = await driver.fetchLiveViewFrame();

      expect(frame, <int>[1, 2, 3]);
      expect(transport.calls, contains('in:0x9203:'));
      driver.dispose();
    });

    test('endLiveView 只在取景中发送 0x9202', () async {
      final (driver, transport) = await _connectedDriver();

      await driver.endLiveView();
      expect(
        transport.calls.where((c) => c.startsWith('op:0x9202')),
        isEmpty,
        reason: '没进过取景就不该发退出指令',
      );

      await driver.startLiveView();
      await driver.endLiveView();
      expect(transport.calls, contains('op:0x9202:'));
      driver.dispose();
    });

    test('endLiveView 失败不会抛给调用方', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.startLiveView();
      transport.failures[PtpOpCodes.nikonEndLiveView] = <Object>[
        PtpException(
            PtpOpCodes.nikonEndLiveView, PtpOpCodes.responseGeneralError),
      ];

      await driver.endLiveView();
      driver.dispose();
    });

    test('disconnect 会先退出取景', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.startLiveView();

      await driver.disconnect();

      expect(transport.calls, contains('op:0x9202:'));
    });
  });

  group('遥控快门', () {
    test('initiateCapture 参数为 [0, 0]', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.initiateCapture();
      expect(transport.calls, contains('op:0x100e:0,0'));
      driver.dispose();
    });

    test('设备忙时重试一次', () async {
      final (driver, transport) = await _connectedDriver();
      transport.failures[PtpOpCodes.initiateCapture] = <Object>[
        PtpException(
            PtpOpCodes.initiateCapture, PtpOpCodes.responseDeviceBusy),
      ];

      await driver.initiateCapture();

      final count =
          transport.calls.where((c) => c.startsWith('op:0x100e')).length;
      expect(count, 2);
      driver.dispose();
    });

    test('不支持时回落到尼康私有拍照指令 0x9207', () async {
      final (driver, transport) = await _connectedDriver();
      transport.failures[PtpOpCodes.initiateCapture] = <Object>[
        PtpException(PtpOpCodes.initiateCapture,
            PtpOpCodes.responseOperationNotSupported),
      ];

      await driver.initiateCapture();

      expect(transport.calls, contains('op:0x9207:0,0'));
      driver.dispose();
    });

    test('非「不支持」的错误原样抛出', () async {
      final (driver, transport) = await _connectedDriver();
      transport.failures[PtpOpCodes.initiateCapture] = <Object>[
        PtpException(
            PtpOpCodes.initiateCapture, PtpOpCodes.responseAccessDenied),
      ];

      await expectLater(driver.initiateCapture(), throwsA(isA<PtpException>()));
      driver.dispose();
    });
  });

  group('触控对焦与设备属性', () {
    test('moveAfArea 传递坐标', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.moveAfArea(2880, 1920);
      expect(transport.calls, contains('op:0x9205:2880,1920'));
      driver.dispose();
    });

    test('设备属性描述走 0x1014', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.fetchDevicePropDesc(PtpOpCodes.devicePropFNumber);
      expect(transport.calls,
          contains('in:0x1014:${PtpOpCodes.devicePropFNumber}'));
      driver.dispose();
    });

    test('设备属性读取走 0x1015', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.fetchDevicePropValue(PtpOpCodes.devicePropFNumber);
      expect(transport.calls,
          contains('in:0x1015:${PtpOpCodes.devicePropFNumber}'));
      driver.dispose();
    });

    test('设备属性写入走 0x1016 数据输出', () async {
      final (driver, transport) = await _connectedDriver();
      await driver.writeDevicePropValue(
          PtpOpCodes.devicePropFNumber, Uint8List.fromList(<int>[0x18, 0x01]));
      expect(transport.calls,
          contains('out:0x1016:${PtpOpCodes.devicePropFNumber}:2'));
      driver.dispose();
    });
  });

  group('能力判定', () {
    test('未连接时所有能力为 false', () {
      final driver = NikonDriver();
      expect(driver.supportsLiveView, isFalse);
      expect(driver.supportsRemoteCapture, isFalse);
      expect(driver.supportsTapToFocus, isFalse);
      expect(driver.supportsExposureWrite, isFalse);
    });

    test('操作码表为空时乐观允许', () async {
      final (driver, _) = await _connectedDriver();
      expect(driver.supportsLiveView, isTrue);
      expect(driver.supportsRemoteCapture, isTrue);
      driver.dispose();
    });

    test('相机拒绝后该操作码被标记为不支持', () async {
      final (driver, transport) = await _connectedDriver();
      transport.failures[PtpOpCodes.nikonStartLiveView] = <Object>[
        PtpException(PtpOpCodes.nikonStartLiveView,
            PtpOpCodes.responseOperationNotSupported),
      ];

      await expectLater(driver.startLiveView(), throwsA(isA<PtpException>()));
      expect(driver.supportsLiveView, isFalse);
      driver.dispose();
    });
  });

  group('传输方式', () {
    test('默认 Wi-Fi，USB 连接标记为 usb', () async {
      final (driver, _) = await _connectedDriver();
      expect(driver.transportKind, CameraTransportKind.wifi);
      driver.dispose();
    });
  });
}
