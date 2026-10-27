import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/protocol/ptp_packet.dart';

void main() {
  group('PtpPacket 编解码与小端字节序验证测试', () {
    test('InitCommandRequest 封包格式与头部校验', () {
      final packet = PtpPacket.buildInitCommandRequest(
        clientName: 'Zync',
        guid: Uint8List(16),
      );

      expect(packet.type, equals(PtpOpCodes.ptpIpInitCommandRequest));
      expect(packet.length, greaterThan(8));

      // 序列化为二进制流
      final bytes = packet.toBytes();
      expect(bytes.length, equals(packet.length));

      // 解析拆包
      final parsed = PtpPacket.parse(bytes);
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(1));
      expect(parsed.length, equals(packet.length));
    });

    test('InitEventRequest 封包格式校验', () {
      const connNum = 0x12345678;
      final packet = PtpPacket.buildInitEventRequest(connNum);

      expect(packet.type, equals(PtpOpCodes.ptpIpInitEventRequest));
      expect(packet.payload.length, equals(4));
      expect(packet.getUint32(0), equals(connNum));
    });

    test('OperationRequest 封包参数校验', () {
      final packet = PtpPacket.buildOperationRequest(
        opCode: PtpOpCodes.getDevicePropValue,
        transactionId: 42,
        params: [1, 2, 3],
      );

      expect(packet.type, equals(PtpOpCodes.ptpIpOperationRequest));
      final bytes = packet.toBytes();
      final parsed = PtpPacket.parse(bytes);
      expect(parsed, isNotNull);
      expect(parsed!.type, equals(6));
    });
  });
  group('PTP/IP InitCommandAck 解析', () {
    test('InitCommandAck 解析连接号、相机 GUID 与 UTF-16LE 名称', () {
      const name = 'NIKON Z 30';
      final payload = BytesBuilder();
      final header = ByteData(4)..setUint32(0, 0x12345678, Endian.little);
      payload.add(header.buffer.asUint8List());
      payload.add(List<int>.generate(16, (i) => i));
      for (final code in name.codeUnits) {
        payload.addByte(code & 0xff);
        payload.addByte((code >> 8) & 0xff);
      }
      payload.addByte(0);
      payload.addByte(0);

      final ack = PtpIpInitAck.parse(PtpPacket(
        length: payload.length + 8,
        type: PtpOpCodes.ptpIpInitCommandAck,
        payload: payload.toBytes(),
      ));

      expect(ack.connectionNumber, equals(0x12345678));
      expect(ack.cameraGuid, equals('000102030405060708090a0b0c0d0e0f'));
      expect(ack.cameraName, equals('NIKON Z 30'));
    });
  });
}
