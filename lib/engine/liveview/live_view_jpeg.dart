import 'dart:typed_data';

/// 尼康实时取景帧的 JPEG 提取。
///
/// `0x9203` 返回的负载是「厂商头部 + 完整 JPEG + 可能的尾部填充」，
/// 头部长度随机型与固件变化，因此不能按固定偏移裁剪，
/// 只能按 JPEG 的 SOI (`FF D8`) / EOI (`FF D9`) 边界扫描。
class LiveViewJpeg {
  LiveViewJpeg._();

  static const int _soi0 = 0xFF;
  static const int _soi1 = 0xD8;
  static const int _eoi1 = 0xD9;

  /// 从取景负载中切出第一个完整 JPEG。
  ///
  /// 找不到 SOI 或找不到位于其后的 EOI 时返回 `null`：
  /// 半帧数据交给解码器只会得到异常，直接丢弃更安全。
  static Uint8List? extract(Uint8List payload) {
    final start = _findSoi(payload);
    if (start < 0) return null;

    final end = _findEoi(payload, start);
    if (end < 0) return null;

    return Uint8List.sublistView(payload, start, end);
  }

  static int _findSoi(Uint8List bytes) {
    for (var i = 0; i + 1 < bytes.length; i++) {
      if (bytes[i] == _soi0 && bytes[i + 1] == _soi1) return i;
    }
    return -1;
  }

  /// 从尾部向前找 EOI，避开 JPEG 内部 `FF D9` 不可能出现在熵编码数据里的前提，
  /// 同时保证尾部填充不会让边界偏移。
  static int _findEoi(Uint8List bytes, int start) {
    for (var i = bytes.length - 2; i > start; i--) {
      if (bytes[i] == _soi0 && bytes[i + 1] == _eoi1) return i + 2;
    }
    return -1;
  }
}
