import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// 从 RAW（NEF / NRW）里提取内嵌 JPEG 预览。
///
/// NEF 是 TIFF 容器，内部按规范嵌了一张或多张 JPEG 预览；这里不做完整
/// TIFF/IFD 解析，而是按 JPEG 段结构扫描出所有完整候选，取最大且可解码的那个。
/// 这样即使厂商把预览放在私有 IFD 里也能命中，代价是一次线性扫描。
class RawPreviewExtractor {
  RawPreviewExtractor._();

  /// 小于该体积的候选基本是缩略图，直接忽略。
  static const int _minCandidateBytes = 64 * 1024;

  /// 最多尝试解码几个候选（从大到小），避免异常文件拖慢加载。
  static const int _maxDecodeAttempts = 4;

  /// 返回内嵌 JPEG 字节；没有可用预览时返回 null（调用方保持占位提示）。
  static Future<Uint8List?> extractEmbeddedJpeg(Uint8List raw) async {
    final candidates = scanCandidates(raw);
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.length.compareTo(a.length));
    for (final candidate in candidates.take(_maxDecodeAttempts)) {
      if (await _isDecodable(candidate)) {
        // 复制一份，避免返回的视图把整个 RAW 缓冲一直留在内存里。
        return Uint8List.fromList(candidate);
      }
    }
    return null;
  }

  /// 扫描所有「完整且够大」的 JPEG 候选（返回的是 raw 的视图，不复制）。
  @visibleForTesting
  static List<Uint8List> scanCandidates(Uint8List raw) {
    final out = <Uint8List>[];
    var i = 0;
    final limit = raw.length - 3;
    while (i < limit) {
      if (raw[i] == 0xFF && raw[i + 1] == 0xD8 && raw[i + 2] == 0xFF) {
        final end = _findEnd(raw, i + 2);
        if (end > 0) {
          if (end - i >= _minCandidateBytes) {
            out.add(Uint8List.sublistView(raw, i, end));
          }
          i = end;
          continue;
        }
      }
      i++;
    }
    return out;
  }

  /// 从 SOI 之后开始按段长度跳过，遇到 EOI 返回结束下标（不含）。
  static int _findEnd(Uint8List b, int start) {
    var p = start;
    while (p + 1 < b.length) {
      if (b[p] != 0xFF) {
        p++;
        continue;
      }
      final marker = b[p + 1];
      if (marker == 0xD9) return p + 2; // EOI
      if (marker == 0x00 || marker == 0xFF) {
        p += 2; // 熵编码转义或填充
        continue;
      }
      if (marker == 0xDA) {
        // SOS：之后是熵编码数据，只能逐字节找 EOI。
        // 熵编码里 0xFF 只可能是转义(0x00)或重启标记(0xD0-0xD7)，
        // 因此一旦遇到新的 SOI(0xD8) 就说明当前候选被截断，必须放弃，
        // 否则会把后面那张完整 JPEG 的 EOI 误当成自己的结尾。
        p += 2;
        while (p + 1 < b.length) {
          if (b[p] == 0xFF) {
            final next = b[p + 1];
            if (next == 0xD9) return p + 2;
            if (next == 0xD8) return -1;
            if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
              p += 2;
              continue;
            }
          }
          p++;
        }
        return -1;
      }
      if (p + 3 >= b.length) return -1;
      final len = (b[p + 2] << 8) | b[p + 3];
      if (len < 2) return -1;
      p += 2 + len;
    }
    return -1;
  }

  static Future<bool> _isDecodable(Uint8List jpeg) async {
    try {
      final codec = await ui.instantiateImageCodec(jpeg);
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }
}
