import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/core/utils/byte_buffer_ext.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/protocol/nikon_sta_pairing.dart';
import 'package:zync/protocol/ptp_ip_client.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/ptp_transport.dart';

Uint8List _buildDeviceInfoBytes({
  required String model,
  required List<int> ops,
  String firmware = 'V1.20',
  String serial = '1234567',
}) {
  final buf = PtpByteBuffer();
  buf.writeUint16(100); // standardVersion
  buf.writeUint32(0x0000000A); // vendorExtensionId (Nikon)
  buf.writeUint16(100); // vendorExtensionVersion
  _writePtpString(buf, 'Nikon PTP Extensions');
  buf.writeUint16(0); // functionalMode
  _writeUint16Array(buf, ops);
  _writeUint16Array(buf, const []); // events
  _writeUint16Array(buf, const []); // props
  _writeUint16Array(buf, const []); // captureFormats
  _writeUint16Array(buf, const []); // playbackFormats
  _writePtpString(buf, 'Nikon Corporation');
  _writePtpString(buf, model);
  _writePtpString(buf, firmware);
  _writePtpString(buf, serial);
  return buf.toBytes();
}

void _writeUint16Array(PtpByteBuffer buf, List<int> values) {
  buf.writeUint32(values.length);
  for (final v in values) {
    buf.writeUint16(v);
  }
}

void _writePtpString(PtpByteBuffer buf, String text) {
  if (text.isEmpty) {
    buf.writeUint8(0);
    return;
  }
  buf.writeUint8(text.length + 1);
  for (final unit in text.codeUnits) {
    buf.writeUint16(unit);
  }
  buf.writeUint16(0);
}

class _ScriptedTransport implements PtpTransport {
  bool _connected = false;
  final List<String> calls = <String>[];
  final Future<Uint8List> Function(int opCode, List<int> params)? onDataIn;

  _ScriptedTransport({this.onDataIn});

  @override
  bool get isConnected => _connected;

  @override
  Stream<PtpPacket> get events => const Stream<PtpPacket>.empty();

  @override
  set onUnexpectedDisconnect(void Function()? callback) {}

  @override
  Future<void> connect() async {
    _connected = true;
    calls.add('connect');
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    calls.add('disconnect');
  }

  @override
  Future<void> executeOperation(int opCode,
      [List<int> params = const []]) async {
    calls.add('op:0x${opCode.toRadixString(16)}:${params.join(",")}');
  }

  @override
  Future<Uint8List> executeDataIn(int opCode,
      [List<int> params = const []]) async {
    calls.add('in:0x${opCode.toRadixString(16)}');
    if (onDataIn != null) {
      return await onDataIn!(opCode, params);
    }
    return Uint8List(0);
  }

  @override
  Future<void> executeDataOut(int opCode, Uint8List data,
      [List<int> params = const []]) async {
    calls.add('out:0x${opCode.toRadixString(16)}:${data.length}');
  }
}

void main() {
  group('STA 受限配对态判定 (isRestrictedStaPairingProfile)', () {
    test('仅含 0x952B + 0x935A 且无取景指令时判定为受限配对态', () {
      expect(
        isRestrictedStaPairingProfile([
          PtpOpCodes.getDeviceInfo,
          PtpOpCodes.openSession,
          PtpOpCodes.closeSession,
          PtpOpCodes.nikonGetPairingInfo,
          PtpOpCodes.nikonConfirmPairing,
        ]),
        isTrue,
      );
    });

    test('完整能力集（含取景指令 0x9201/0x9203 或 0x9428）不判定为受限态', () {
      expect(
        isRestrictedStaPairingProfile([
          PtpOpCodes.getDeviceInfo,
          PtpOpCodes.nikonGetPairingInfo,
          PtpOpCodes.nikonConfirmPairing,
          PtpOpCodes.nikonStartLiveView,
          PtpOpCodes.nikonGetLiveViewImage,
        ]),
        isFalse,
      );
      expect(
        isRestrictedStaPairingProfile([
          PtpOpCodes.nikonGetPairingInfo,
          PtpOpCodes.nikonConfirmPairing,
          PtpOpCodes.nikonGetLiveViewImageEx,
        ]),
        isFalse,
      );
    });

    test('空操作码集或缺少任一配对指令时不判定为受限态', () {
      expect(isRestrictedStaPairingProfile(const []), isFalse);
      expect(
        isRestrictedStaPairingProfile([PtpOpCodes.nikonGetPairingInfo]),
        isFalse,
      );
    });
  });

  group('4 位配对验证码多格式容错解析 (NikonPairingChallenge)', () {
    test('末尾 4 字节直接存 0..9 数字（Z f / Z 30 实机格式）', () {
      final raw = Uint8List.fromList([0x04, 0x00, 0x00, 0x00, 4, 8, 2, 9]);
      final challenge = NikonPairingChallenge.parse(raw, cameraName: 'NIKON Z f');
      expect(challenge.hasPin, isTrue);
      expect(challenge.pin, equals('4829'));
      expect(challenge.cameraName, equals('NIKON Z f'));
    });

    test('纯 4 字节数字载荷', () {
      final raw = Uint8List.fromList([0, 1, 9, 5]);
      final challenge = NikonPairingChallenge.parse(raw);
      expect(challenge.pin, equals('0195'));
    });

    test('ASCII 4 位数字', () {
      final raw = Uint8List.fromList('PIN=7391\x00'.codeUnits);
      expect(NikonPairingChallenge.parse(raw).pin, equals('7391'));
    });

    test('UTF-16LE 4 位数字', () {
      final buf = PtpByteBuffer()..writeUtf16LeNullTerminated('6042');
      expect(NikonPairingChallenge.parse(buf.toBytes()).pin, equals('6042'));
    });

    test('独立 uint16 整数 (1000..9999)', () {
      final raw = Uint8List(2);
      ByteData.sublistView(raw).setUint16(0, 5280, Endian.little);
      expect(NikonPairingChallenge.parse(raw).pin, equals('5280'));
    });

    test('2 字节 BCD 编码', () {
      final raw = Uint8List.fromList([0x93, 0x47]);
      expect(NikonPairingChallenge.parse(raw).pin, equals('9347'));
    });

    test('无法识别格式时保留 rawHex 兜底', () {
      final raw = Uint8List.fromList([0xAB, 0xCD, 0xEF]);
      final challenge = NikonPairingChallenge.parse(raw);
      expect(challenge.hasPin, isFalse);
      expect(challenge.pin, isNull);
      expect(challenge.rawHex, equals('ab cd ef'));
    });
  });

  group('STA 扫描未命中类型化诊断 (diagnoseStaScanMiss)', () {
    test('在路由器子模式下仍连着 NIKON 相机热点', () {
      expect(
        diagnoseStaScanMiss(
          staSubMode: 'router',
          wifiConnected: true,
          wifiSsid: 'NIKON_Z30_1234',
          wifiGateway: '192.168.1.1',
          scannedSubnets: const ['192.168.1.0/24'],
          hasHotspotInterface: false,
          respondingPeerCount: 1,
        ),
        equals(StaScanMissReason.onCameraAccessPoint),
      );
    });

    test('未连接 Wi-Fi 且无扫描网段', () {
      expect(
        diagnoseStaScanMiss(
          staSubMode: 'router',
          wifiConnected: false,
          wifiSsid: '',
          wifiGateway: '',
          scannedSubnets: const [],
          hasHotspotInterface: false,
          respondingPeerCount: 0,
        ),
        equals(StaScanMissReason.noLocalNetwork),
      );
    });

    test('同网段有其他设备响应但无 15740 端口', () {
      expect(
        diagnoseStaScanMiss(
          staSubMode: 'router',
          wifiConnected: true,
          wifiSsid: 'Home_5G',
          wifiGateway: '192.168.31.1',
          scannedSubnets: const ['192.168.31.0/24'],
          hasHotspotInterface: false,
          respondingPeerCount: 5,
        ),
        equals(StaScanMissReason.hostsVisibleNoPtp),
      );
    });

    test('路由器网段完全静默无任何对端响应（AP 隔离 / 6GHz）', () {
      expect(
        diagnoseStaScanMiss(
          staSubMode: 'router',
          wifiConnected: true,
          wifiSsid: 'Hotel_Guest',
          wifiGateway: '192.168.10.1',
          scannedSubnets: const ['192.168.10.0/24'],
          hasHotspotInterface: false,
          respondingPeerCount: 0,
        ),
        equals(StaScanMissReason.silentOrIsolatedNetwork),
      );
    });

    test('手机热点子模式下有网段但未发现相机回退常规未命中', () {
      expect(
        diagnoseStaScanMiss(
          staSubMode: 'hotspot',
          wifiConnected: false,
          wifiSsid: '',
          wifiGateway: '',
          scannedSubnets: const ['192.168.43.0/24'],
          hasHotspotInterface: true,
          respondingPeerCount: 0,
        ),
        equals(StaScanMissReason.cameraNotFound),
      );
    });
  });

  group('NikonDriver STA 配对流程与 0x9428 取景回退', () {
    test('受限配对态跳过卡槽与电量查询，支持 0x952B 忙重试与 0x935A 确认', () async {
      var pairingPolls = 0;
      final transport = _ScriptedTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfoBytes(
              model: 'NIKON Z f',
              ops: [
                PtpOpCodes.getDeviceInfo,
                PtpOpCodes.openSession,
                PtpOpCodes.closeSession,
                PtpOpCodes.nikonGetPairingInfo,
                PtpOpCodes.nikonConfirmPairing,
              ],
            );
          }
          if (op == PtpOpCodes.nikonGetPairingInfo) {
            pairingPolls++;
            if (pairingPolls == 1) {
              throw PtpException(
                PtpOpCodes.nikonGetPairingInfo,
                PtpOpCodes.responseDeviceBusy,
                'busy',
              );
            }
            return Uint8List.fromList([0x04, 0x00, 0x00, 0x00, 1, 2, 3, 4]);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport);

      expect(driver.isConnected, isTrue);
      expect(driver.isRestrictedPairingSession, isTrue);
      expect(driver.supportsLiveView, isFalse);
      expect(driver.cameraModel, equals('NIKON Z f'));
      // 受限配对态不应下发 GetStorageIDs (0x1004) 或 BatteryLevel (0x1015)
      expect(transport.calls, isNot(contains('in:0x1004')));
      expect(transport.calls, isNot(contains('in:0x1015')));

      final challenge = await driver.requestStaPairingChallenge(
        maxAttempts: 3,
        pollInterval: Duration.zero,
      );
      expect(pairingPolls, equals(2));
      expect(challenge.pin, equals('1234'));

      await driver.confirmStaPairing();
      expect(
        transport.calls,
        contains('op:0x935a:${PtpOpCodes.responseOk}'),
      );

      await driver.disconnect();
      expect(driver.isRestrictedPairingSession, isFalse);
    });

    test('0x9203 返回 0xA00B 且设备支持 0x9428 时自动切换扩展取景帧', () async {
      final expectedFrame = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
      final transport = _ScriptedTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfoBytes(
              model: 'NIKON Z50_2',
              ops: [
                PtpOpCodes.getDeviceInfo,
                PtpOpCodes.nikonStartLiveView,
                PtpOpCodes.nikonEndLiveView,
                PtpOpCodes.nikonGetLiveViewImage,
                PtpOpCodes.nikonGetLiveViewImageEx,
              ],
            );
          }
          if (op == PtpOpCodes.nikonGetLiveViewImage) {
            throw PtpException(
              PtpOpCodes.nikonGetLiveViewImage,
              PtpOpCodes.responseNotLiveView,
              'Z50II requires 0x9428',
            );
          }
          if (op == PtpOpCodes.nikonGetLiveViewImageEx) {
            return expectedFrame;
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport);

      expect(driver.cameraModel, equals('NIKON Z50II'));
      expect(driver.supportsLiveView, isTrue);

      final frame1 = await driver.fetchLiveViewFrame();
      expect(frame1, equals(expectedFrame));
      // 再次拉帧应直接走 0x9428，不再重复请求失败的 0x9203
      final beforeCount =
          transport.calls.where((c) => c == 'in:0x9203').length;
      final frame2 = await driver.fetchLiveViewFrame();
      expect(frame2, equals(expectedFrame));
      final afterCount =
          transport.calls.where((c) => c == 'in:0x9203').length;
      expect(afterCount, equals(beforeCount));

      await driver.disconnect();
    });
  });
}
