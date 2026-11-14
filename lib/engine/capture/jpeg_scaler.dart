import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// 把 JPEG 解码成一张缩小后的 `img.Image`。
///
/// 必须走 Flutter 引擎的 `instantiateCodec(targetWidth:)`：`package:image`
/// 只能整幅解码，24MP × 9 张会直接吃掉几百 MB 内存。
/// 返回 null 表示这张图无法解码（损坏或不是 JPEG）。
Future<img.Image?> decodeScaledJpeg(
  Uint8List bytes, {
  int maxEdge = 1280,
}) async {
  if (bytes.isEmpty) return null;
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final srcWidth = descriptor.width;
    final srcHeight = descriptor.height;
    if (srcWidth <= 0 || srcHeight <= 0) return null;

    final longest = srcWidth > srcHeight ? srcWidth : srcHeight;
    final scale = longest <= maxEdge ? 1.0 : maxEdge / longest;
    final targetWidth = (srcWidth * scale).round().clamp(1, 8192);
    final targetHeight = (srcHeight * scale).round().clamp(1, 8192);

    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;

    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    return img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: data.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
