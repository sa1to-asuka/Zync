import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 渐进式 JPEG 预览工具。
///
/// 相机端 PTP `GetPartialObject` 可以只取文件前 N 字节，而 `image` 包
/// 对截断的 JPEG 具备容错解码能力（Scan 未写完时仍能解出前半幅画面）。
/// 这样无需等待整张原图传输完成，即可先呈现一张可辨认的预览。
///
/// 性能约定（USB 大图预览不卡顿的关键）：
///  1. `image` 包的 JPEG 解码是纯 Dart 实现，放在 UI isolate 上会直接卡住界面；
///     这里统一丢到后台 isolate（[compute]）里解码。
///  2. 解码结果按预览尺寸缩放后再回传，避免把整张原图的 RGBA 像素（动辄上百 MB）
///     在主 isolate 上分配、拷贝与上传，造成 GC 抖动。
class ProgressiveJpeg {
  ProgressiveJpeg._();

  /// 先取前 [defaultFraction] 比例字节做低清预览的默认比例。
  static const double defaultFraction = 0.35;

  /// 片段预览最多取多少字节：限制单次 USB 传输量，避免为了预览拉走大半张原图。
  static const int maxPreviewBytes = 2 * 1024 * 1024;

  /// 预览解码长边上限：预览框最大只占屏高 46%，无需全分辨率位图。
  static const int defaultMaxEdge = 2048;

  /// 用 [bytes]（允许是截断的 JPEG 片段）尽力解码为 Flutter 位图。
  ///
  /// 解码失败或不是 JPEG 时返回 null，调用方应回退到缩略图或完整原图。
  static Future<ui.Image?> decodeLenient(Uint8List bytes, {int maxEdge = defaultMaxEdge}) async {
    if (bytes.length < 4) return null;
    // 仅处理 JPEG（SOI 0xFFD8），RAW/PNG 走原有完整下载路径
    if (bytes[0] != 0xFF || bytes[1] != 0xD8) return null;

    // 纯 Dart 解码放到后台 isolate，UI 线程只做一次像素上传。
    final frame = await compute(_decodeJpegFrame, _ProgressiveDecodeRequest(bytes, maxEdge));
    if (frame == null) return null;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      frame.pixels,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// 后台 isolate 入参（[compute] 只接受单个参数）。
class _ProgressiveDecodeRequest {
  const _ProgressiveDecodeRequest(this.bytes, this.maxEdge);

  final Uint8List bytes;
  final int maxEdge;
}

/// 后台 isolate 产物：已按 EXIF 摆正、并缩放到预览尺寸的 RGBA 像素。
class _ProgressiveFrame {
  const _ProgressiveFrame(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

_ProgressiveFrame? _decodeJpegFrame(_ProgressiveDecodeRequest request) {
  try {
    var decoded = img.decodeJpg(request.bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) return null;

    // 烘焙 EXIF 方向：RawImage 不会像 Image.memory 那样自动应用方向，
    // 必须先按 EXIF Orientation 旋转像素，竖拍片段才不会是躺倒的。
    decoded = img.bakeOrientation(decoded);

    final maxEdge = request.maxEdge;
    if (maxEdge > 0 && (decoded.width > maxEdge || decoded.height > maxEdge)) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxEdge, interpolation: img.Interpolation.average)
          : img.copyResize(decoded, height: maxEdge, interpolation: img.Interpolation.average);
    }

    final rgba = decoded.convert(numChannels: 4);
    return _ProgressiveFrame(rgba.getBytes(order: img.ChannelOrder.rgba), rgba.width, rgba.height);
  } catch (_) {
    return null;
  }
}
