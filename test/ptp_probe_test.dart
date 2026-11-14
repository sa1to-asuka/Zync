import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/protocol/ptp_packet.dart';

void main() {
  test('ProbeResponse 原样回送探活负载', () {
    final payload = Uint8List.fromList([0x00, 0x00, 0x01, 0x00]);
    final response = PtpPacket.buildProbeResponse(payload);

    expect(response.type, PtpOpCodes.ptpIpProbeResponse);
    expect(response.payload, payload);
    expect(response.length, payload.length + 8);
  });

  test('空负载探活兜底为协议版本 1.0', () {
    final response = PtpPacket.buildProbeResponse(Uint8List(0));
    expect(response.payload, hasLength(4));
    expect(response.getUint32(0), 0x00010000);
  });

  test('ProbeRequest (0x000D) 能被拆包识别', () {
    // 长度 12: [len 4B][type 4B][协议版本 4B]
    final bytes = Uint8List.fromList(<int>[
      12, 0, 0, 0, //
      13, 0, 0, 0, //
      0x00, 0x00, 0x01, 0x00,
    ]);
    final packet = PtpPacket.parse(bytes);
    expect(packet, isNotNull);
    expect(packet!.type, PtpOpCodes.ptpIpProbeRequest);
    expect(packet.getUint32(0), 0x00010000);
  });
}
