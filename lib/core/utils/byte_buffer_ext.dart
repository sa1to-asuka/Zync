import 'dart:typed_data';

/// 专为 PTP/IP 二进制协议打造的小端字节序缓冲工具类
class PtpByteBuffer {
  final BytesBuilder _builder = BytesBuilder();

  PtpByteBuffer();

  /// 写入 1 字节无符号数
  void writeUint8(int value) {
    _builder.addByte(value & 0xFF);
  }

  /// 写入 2 字节小端无符号短整数
  void writeUint16(int value) {
    final bd = ByteData(2)..setUint16(0, value, Endian.little);
    _builder.add(bd.buffer.asUint8List());
  }

  /// 写入 4 字节小端无符号整数
  void writeUint32(int value) {
    final bd = ByteData(4)..setUint32(0, value, Endian.little);
    _builder.add(bd.buffer.asUint8List());
  }

  /// 写入 8 字节小端无符号长整数
  void writeUint64(int value) {
    final bd = ByteData(8)..setUint64(0, value, Endian.little);
    _builder.add(bd.buffer.asUint8List());
  }

  /// 写入原始字节序列
  void writeBytes(List<int> bytes) {
    _builder.add(bytes);
  }

  /// 写入 UTF-16LE 字符串 (PTP 规范：前置1字节字符数+双字节字符+双字节结尾0)
  void writePtpString(String text) {
    if (text.isEmpty) {
      writeUint8(0);
      return;
    }
    final chars = text.codeUnits;
    writeUint8(chars.length + 1); // 包含结尾0在内的字符数量
    for (final c in chars) {
      writeUint16(c);
    }
    writeUint16(0); // NULL 结束符
  }

  /// 写入 PTP/IP InitCommandRequest 专用以 0x0000 结尾的 UTF-16LE 友好名 (无前置长度字节)
  void writeUtf16LeNullTerminated(String text) {
    for (final c in text.codeUnits) {
      writeUint16(c);
    }
    writeUint16(0); // 2 字节 NULL (0x0000)
  }

  /// 输出当前构建完成的连续二进制字节切片
  Uint8List toBytes() => _builder.toBytes();
}

/// 二进制数据读取辅助类
class PtpByteReader {
  final Uint8List _bytes;
  int _offset = 0;

  PtpByteReader(this._bytes);

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;
  bool get hasRemaining => _offset < _bytes.length;

  int readUint8() {
    if (_offset >= _bytes.length) return 0;
    return _bytes[_offset++];
  }

  int readUint16() {
    if (_offset + 2 > _bytes.length) return 0;
    final value = ByteData.sublistView(_bytes, _offset, _offset + 2).getUint16(0, Endian.little);
    _offset += 2;
    return value;
  }

  int readUint32() {
    if (_offset + 4 > _bytes.length) return 0;
    final value = ByteData.sublistView(_bytes, _offset, _offset + 4).getUint32(0, Endian.little);
    _offset += 4;
    return value;
  }

  Uint8List readBytes(int length) {
    final end = (_offset + length > _bytes.length) ? _bytes.length : _offset + length;
    final slice = _bytes.sublist(_offset, end);
    _offset = end;
    return slice;
  }

  /// 读取 PTP 格式的 UTF-16LE 字符串 (前置 1 字节字符数，含结尾 0x0000)
  String readPtpString() {
    final numChars = readUint8();
    if (numChars == 0) return '';
    if (numChars == 1) {
      if (_offset + 2 <= _bytes.length) {
        readUint16(); // 消费单字符结束符 0x0000，防止偏移指针偏离 2 字节
      }
      return '';
    }
    final codeUnits = <int>[];
    for (var i = 0; i < numChars - 1; i++) {
      if (_offset + 2 > _bytes.length) break;
      codeUnits.add(readUint16());
    }
    if (_offset + 2 <= _bytes.length) {
      readUint16(); // 跳过结尾的 0x0000
    }
    return String.fromCharCodes(codeUnits);
  }

  /// 读取 PTP 标准 UINT16 数组 (前置 4 字节元素个数)
  List<int> readUint16Array() {
    final count = readUint32();
    if (count <= 0 || count > 10000) return [];
    final list = <int>[];
    for (var i = 0; i < count; i++) {
      if (_offset + 2 > _bytes.length) break;
      list.add(readUint16());
    }
    return list;
  }

  /// 读取 PTP 标准 UINT32 数组 (前置 4 字节元素个数)
  List<int> readUint32Array() {
    final count = readUint32();
    if (count <= 0 || count > 100000) return [];
    final list = <int>[];
    for (var i = 0; i < count; i++) {
      if (_offset + 4 > _bytes.length) break;
      list.add(readUint32());
    }
    return list;
  }
}
