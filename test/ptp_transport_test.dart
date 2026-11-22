import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/utils/byte_buffer_ext.dart';
import 'package:zync/protocol/connection_recovery_controller.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/protocol/nikon_sta_pairing.dart';
import 'package:zync/protocol/ptp_ip_client.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/ptp_transport.dart';
import 'package:zync/protocol/usb_ptp_transport.dart';

/// 记录调用并可返回预设数据的假传输层。
class RecordingTransport implements PtpTransport {
  bool connected = false;
  final List<String> calls = [];
  final Map<int, Uint8List> dataInResponses;

  RecordingTransport({this.dataInResponses = const {}});

  @override
  bool get isConnected => connected;

  @override
  Stream<PtpPacket> get events => const Stream.empty();

  @override
  set onUnexpectedDisconnect(void Function()? callback) {}

  @override
  Future<void> connect() async {
    connected = true;
    calls.add('connect');
  }

  @override
  Future<void> disconnect() async {
    connected = false;
    calls.add('disconnect');
  }

  @override
  Future<void> executeOperation(int opCode, [List<int> params = const []]) async {
    calls.add('op:0x${opCode.toRadixString(16)}:${params.join(",")}');
  }

  @override
  Future<Uint8List> executeDataIn(int opCode, [List<int> params = const []]) async {
    calls.add('in:0x${opCode.toRadixString(16)}');
    return dataInResponses[opCode] ?? Uint8List(0);
  }

  @override
  Future<void> executeDataOut(int opCode, Uint8List data, [List<int> params = const []]) async {
    calls.add('out:0x${opCode.toRadixString(16)}:${data.length}');
  }
}

void main() {
  test('传输抽象可用同一接口驱动指令', () async {
    final t = RecordingTransport();
    await t.connect();
    expect(t.isConnected, isTrue);
    await t.executeOperation(0x1002, [1]);
    await t.executeDataIn(0x1004);
    await t.executeDataOut(0x1016, Uint8List(4), [0x5007]);
    await t.disconnect();

    expect(t.calls, contains('connect'));
    expect(t.calls, contains('op:0x1002:1'));
    expect(t.calls, contains('in:0x1004'));
    expect(t.calls, contains('out:0x1016:4'));
    expect(t.calls, contains('disconnect'));
    expect(t.isConnected, isFalse);
  });

  test('USB 传输可实例化（编译契约）', () {
    final usb = UsbPtpTransport(deviceName: 'usb:1:2:/dev/bus/usb/001/002');
    expect(usb.isConnected, isFalse);
    usb.dispose();
  });
  test('connectTransport 只调用一次 transport.connect', () async {
    final transport = RecordingTransport();
    final driver = NikonDriver();
    await driver.connectTransport(transport, onLog: (_) {});
    expect(transport.calls.where((call) => call == 'connect').length, equals(1));
    expect(driver.isConnected, isTrue);
    await driver.disconnect();
  });

  group('PtpIpClient 真实 loopback Socket 协议加固测试', () {
    setUp(() => AppSettings.instance.resetForTest());

    Uint8List buildInitCommandAck({
      int connNumber = 0x1234,
      String cameraName = 'NIKON Z f',
    }) {
      final payload = PtpByteBuffer()
        ..writeUint32(connNumber)
        ..writeBytes(Uint8List(16))
        ..writeUtf16LeNullTerminated(cameraName)
        ..writeUint32(0x00010000);
      return PtpPacket(
        length: payload.toBytes().length + 8,
        type: PtpOpCodes.ptpIpInitCommandAck,
        payload: payload.toBytes(),
      ).toBytes();
    }

    Uint8List buildInitFail(int reasonCode) {
      final payload = PtpByteBuffer()..writeUint32(reasonCode);
      return PtpPacket(
        length: 12,
        type: PtpOpCodes.ptpIpInitFail,
        payload: payload.toBytes(),
      ).toBytes();
    }

    Uint8List buildOpOk(int txId) {
      final payload = PtpByteBuffer()
        ..writeUint16(PtpOpCodes.responseOk)
        ..writeUint32(txId);
      return PtpPacket(
        length: 14,
        type: PtpOpCodes.ptpIpOperationResponse,
        payload: payload.toBytes(),
      ).toBytes();
    }

    test('InitFail(1) 抛出 rejectedInitiator，InitFail(2) 抛出 busy', () async {
      for (final entry in <(int, PtpInitFailReason)>[
        (1, PtpInitFailReason.rejectedInitiator),
        (2, PtpInitFailReason.busy),
      ]) {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(server.close);
        server.listen((socket) {
          socket.listen((_) {
            socket.add(buildInitFail(entry.$1));
          });
        });

        final client = PtpIpClient(
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          postConnectSettle: Duration.zero,
          connectRetryCount: 1,
        );
        await expectLater(
          client.connect(timeout: const Duration(seconds: 2)),
          throwsA(
            isA<PtpInitFailException>()
                .having((e) => e.reason, 'reason', entry.$2),
          ),
        );
        client.dispose();
      }
    });

    test('事件通道被拒时允许降级为纯命令通道模式继续建立会话', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        final buf = BytesBuilder(copy: false);
        socket.listen((chunk) {
          buf.add(chunk);
          final pkt = PtpPacket.parse(buf.toBytes());
          if (pkt == null) return;
          buf.clear();
          if (pkt.type == PtpOpCodes.ptpIpInitCommandRequest) {
            socket.add(buildInitCommandAck(cameraName: 'NIKON Z50II'));
          } else if (pkt.type == PtpOpCodes.ptpIpInitEventRequest) {
            socket.add(buildInitFail(3));
          } else if (pkt.type == PtpOpCodes.ptpIpOperationRequest) {
            final txId = pkt.getUint32(6);
            socket.add(buildOpOk(txId));
          }
        });
      });

      final client = PtpIpClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
        postConnectSettle: Duration.zero,
        allowEventChannelFallback: true,
        connectRetryCount: 1,
      );
      await client.connect(timeout: const Duration(seconds: 2));
      expect(client.isConnected, isTrue);
      expect(client.eventsAvailable, isFalse);
      expect(client.cameraName, equals('NIKON Z50II'));

      await client.disconnect();
      client.dispose();
    });

    test('probePtpCameraName 可通过单次 InitCommand 读取机身名并立即释放', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      server.listen((socket) {
        socket.listen((_) {
          socket.add(buildInitCommandAck(cameraName: 'NIKON Z 6III'));
        });
      });

      final name = await probePtpCameraName(
        InternetAddress.loopbackIPv4.address,
        port: server.port,
        timeout: const Duration(seconds: 2),
        postConnectSettle: Duration.zero,
      );
      expect(name, equals('NIKON Z 6III'));
    });

    test('ConnectionRecoveryController 遇到 PtpInitFailException 立即停止自动重试',
        () async {
      var attempts = 0;
      final controller = ConnectionRecoveryController(
        reconnect: () async {
          attempts++;
          throw PtpInitFailException(failCode: 1, channel: '命令通道');
        },
        restoreSession: () async {},
        backoffSeconds: const [0, 0, 0],
        sleep: (_) async {},
      );
      addTearDown(controller.dispose);

      controller.notifyUnexpectedDisconnect();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(attempts, equals(1));
      expect(controller.phase, equals(RecoveryPhase.exhausted));
      expect(controller.lastError, contains('Init_Fail'));
    });
  });
}
