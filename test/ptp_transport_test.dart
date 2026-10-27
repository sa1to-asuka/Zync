import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/nikon_driver.dart';
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
  });}
