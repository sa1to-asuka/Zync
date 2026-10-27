import 'dart:typed_data';
import '../core/utils/byte_buffer_ext.dart';

/// PTP/IP 协议数据包实体
class PtpPacket {
  final int length;
  final int type;
  final Uint8List payload;

  PtpPacket({
    required this.length,
    required this.type,
    required this.payload,
  });

  /// 读取负载内特定偏移处的 32 位小端整数
  int getUint32(int offset) {
    if (offset + 4 > payload.length) return 0;
    return ByteData.sublistView(payload, offset, offset + 4)
        .getUint32(0, Endian.little);
  }

  /// 读取负载内特定偏移处的 16 位小端整数
  int getUint16(int offset) {
    if (offset + 2 > payload.length) return 0;
    return ByteData.sublistView(payload, offset, offset + 2)
        .getUint16(0, Endian.little);
  }

  /// 构造完整的可发送 TCP 字节流: [Length: 4B] + [Type: 4B] + [Payload: NB]
  Uint8List toBytes() {
    final buffer = PtpByteBuffer();
    buffer.writeUint32(payload.length + 8);
    buffer.writeUint32(type);
    buffer.writeBytes(payload);
    return buffer.toBytes();
  }

  /// 快捷构造: InitCommandRequest (Type = 1)
  /// 格式: [16字节GUID] + [客户端名称 UTF-16LE 字符串] + [0x0000 结束符] + [4字节版本 0x00010000]
  static PtpPacket buildInitCommandRequest({
    String clientName = 'Android Device',
    Uint8List? guid,
  }) {
    final buffer = PtpByteBuffer();
    buffer.writeBytes(guid ?? Uint8List(16)); // 16 字节全 0 GUID
    buffer.writeUtf16LeNullTerminated(
        clientName); // UTF-16LE 字符串 + 0x0000 结尾 (无前置长度字节)
    buffer.writeUint32(0x00010000); // 协议版本 1.0 (65536)
    final payload = buffer.toBytes();
    return PtpPacket(length: payload.length + 8, type: 1, payload: payload);
  }

  /// 快捷构造: InitEventRequest (Type = 3)
  /// 负载为 Command 通道获得的 connectionNumber
  static PtpPacket buildInitEventRequest(int connectionNumber) {
    final buffer = PtpByteBuffer()..writeUint32(connectionNumber);
    final payload = buffer.toBytes();
    return PtpPacket(length: payload.length + 8, type: 3, payload: payload);
  }

  /// 快捷构造: OperationRequest (Type = 6)
  /// 格式: [DataPhase: 4B (1)] + [OpCode: 2B] + [TransactionID: 4B] + [Params: 4B * N]
  static PtpPacket buildOperationRequest({
    required int opCode,
    required int transactionId,
    List<int> params = const [],
    int dataPhase = 1,
  }) {
    final buffer = PtpByteBuffer();
    buffer.writeUint32(dataPhase);
    buffer.writeUint16(opCode);
    buffer.writeUint32(transactionId);
    for (final p in params) {
      buffer.writeUint32(p);
    }
    final payload = buffer.toBytes();
    return PtpPacket(length: payload.length + 8, type: 6, payload: payload);
  }

  /// 从字节缓冲区反序列化解析单个数据包
  static PtpPacket? parse(Uint8List bytes) {
    if (bytes.length < 8) return null;
    final bd = ByteData.sublistView(bytes, 0, 8);
    final totalLen = bd.getUint32(0, Endian.little);
    final type = bd.getUint32(4, Endian.little);

    if (totalLen < 8) return null;
    if (bytes.length < totalLen) return null; // 粘包未完整到达
    final payload = bytes.sublist(8, totalLen);
    return PtpPacket(length: totalLen, type: type, payload: payload);
  }

  @override
  String toString() =>
      'PtpPacket(len: $length, type: $type, payloadLen: ${payload.length})';
}

/// InitCommandAck 解析结果：连接号、相机 GUID、相机展示名。
class PtpIpInitAck {
  final int connectionNumber;
  final String cameraGuid;
  final String cameraName;

  const PtpIpInitAck({
    required this.connectionNumber,
    required this.cameraGuid,
    required this.cameraName,
  });

  static PtpIpInitAck parse(PtpPacket packet) {
    if (packet.payload.length < 4) {
      throw const FormatException('InitCommandAck 载荷长度不足 4 字节');
    }
    final connectionNumber = packet.getUint32(0);
    var cameraGuid = '';
    if (packet.payload.length >= 20) {
      final guid = packet.payload.sublist(4, 20);
      cameraGuid = guid.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
    var cameraName = '';
    if (packet.payload.length > 20) {
      final chars = <int>[];
      for (var i = 20; i + 1 < packet.payload.length; i += 2) {
        final code = packet.payload[i] | (packet.payload[i + 1] << 8);
        if (code == 0) break;
        chars.add(code);
      }
      cameraName = String.fromCharCodes(chars).trim();
    }
    return PtpIpInitAck(
      connectionNumber: connectionNumber,
      cameraGuid: cameraGuid,
      cameraName: cameraName,
    );
  }
}
