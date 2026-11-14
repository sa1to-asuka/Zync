import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/liveview/nikon_live_view_packet.dart';

/// 构造一个「头部 + JPEG」的取景负载。
Uint8List _frame({
  int headerLength = 900,
  bool recording = false,
  int peakLeft = 3,
  int peakRight = 4,
  int currentLeft = 5,
  int currentRight = 6,
  int orientation = 0,
}) {
  final bytes = Uint8List(headerLength + 16);
  if (headerLength > 840) {
    bytes[828] = recording ? 1 : 0;
    bytes[824] = peakLeft;
    bytes[825] = peakRight;
    bytes[826] = currentLeft;
    bytes[827] = currentRight;
    bytes[839] = orientation;
  }
  bytes[headerLength] = 0xFF;
  bytes[headerLength + 1] = 0xD8;
  bytes[headerLength + 2] = 0x01;
  bytes[headerLength + 3] = 0x02;
  bytes[headerLength + 4] = 0xFF;
  bytes[headerLength + 5] = 0xD9;
  return bytes;
}

void main() {
  test('长头部帧解析出录像状态与音频电平', () {
    final packet = NikonLiveViewPacket.parse(_frame(recording: true));

    expect(packet.hasTelemetry, isTrue);
    expect(packet.isRecording, isTrue);
    expect(packet.peakLeft, 3);
    expect(packet.peakRight, 4);
    expect(packet.currentLeft, 5);
    expect(packet.currentRight, 6);
    expect(packet.jpeg, isNotNull);
    expect(packet.jpeg!.first, 0xFF);
    expect(packet.jpeg!.last, 0xD9);
  });

  test('头部不足 840 字节时降级为纯 JPEG', () {
    final packet = NikonLiveViewPacket.parse(_frame(headerLength: 64));

    expect(packet.hasTelemetry, isFalse);
    expect(packet.isRecording, isFalse);
    expect(packet.jpeg, isNotNull, reason: '短包机型仍然要能取景');
  });

  test('没有 JPEG 时返回空帧', () {
    final bytes = Uint8List(900);
    final packet = NikonLiveViewPacket.parse(bytes);
    expect(packet.jpeg, isNull);
    expect(packet.hasTelemetry, isFalse);
  });

  test('录像状态随帧切换', () {
    expect(NikonLiveViewPacket.parse(_frame(recording: false)).isRecording,
        isFalse);
    expect(NikonLiveViewPacket.parse(_frame(recording: true)).isRecording,
        isTrue);
  });

  test('朝向字节原样透出', () {
    expect(NikonLiveViewPacket.parse(_frame(orientation: 2)).orientation, 2);
  });
}
