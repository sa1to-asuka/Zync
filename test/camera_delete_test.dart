import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/ptp_transport.dart';

class _FakeTransport implements PtpTransport {
  final List<(int, List<int>)> operations = [];

  @override
  bool get isConnected => true;
  @override
  Stream<PtpPacket> get events => const Stream.empty();
  @override
  Future<void> connect() async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> executeOperation(int opCode, [List<int> params = const []]) async {
    operations.add((opCode, params));
  }
  @override
  Future<Uint8List> executeDataIn(int opCode, [List<int> params = const []]) async => Uint8List(0);
  @override
  Future<void> executeDataOut(int opCode, Uint8List data, [List<int> params = const []]) async {}
}

void main() {
  test('deleteObject 使用标准 PTP 0x100B 与参数 [handle, 0]', () async {
    final transport = _FakeTransport();
    final driver = NikonDriver();
    await driver.connectTransport(transport);

    expect(await driver.deleteObject(0x1234), isTrue);
    expect(transport.operations.length, equals(1));
    expect(transport.operations.single.$1, equals(PtpOpCodes.deleteObject));
    expect(transport.operations.single.$2, equals([0x1234, 0]));

    await driver.disconnect();
  });
}
