import 'dart:typed_data';

import 'live_view_jpeg.dart';

/// Nikon `0x9203` 取景负载的头部解析。
///
/// 负载结构是「厂商头部 + JPEG + 填充」，头部长度随机型/固件变化，
/// 所以不能按固定偏移切 JPEG。但头部里的遥测字段位置在 Z 系列上稳定，
/// 前提是 SOI 偏移足够大（`>= 840`）——短包的老机型直接降级为纯 JPEG。
class NikonLiveViewPacket {
  /// 头部可按固定偏移解析所需的最小 SOI 偏移。
  static const int headerMinSoiOffset = 840;

  static const int _offsetRecording = 828;
  static const int _offsetPeakLeft = 824;
  static const int _offsetPeakRight = 825;
  static const int _offsetCurrentLeft = 826;
  static const int _offsetCurrentRight = 827;
  static const int _offsetOrientation = 839;

  /// 从负载里切出的 JPEG；解析失败时为 null。
  final Uint8List? jpeg;

  /// 头部是否足够长、可以信任下面的遥测字段。
  final bool hasTelemetry;

  /// 机身是否正在录像。即使是在机身按红色录像键，这里也会立刻反映。
  final bool isRecording;

  /// 双声道电平，值域 0..14 段。
  final int peakLeft;
  final int peakRight;
  final int currentLeft;
  final int currentRight;

  /// 机身朝向：0=正常，1=逆时针 90°，2=顺时针 90°，3=倒置。
  final int orientation;

  const NikonLiveViewPacket({
    required this.jpeg,
    required this.hasTelemetry,
    required this.isRecording,
    required this.peakLeft,
    required this.peakRight,
    required this.currentLeft,
    required this.currentRight,
    required this.orientation,
  });

  /// 只有 JPEG、没有可解析头部时的结果。
  static NikonLiveViewPacket jpegOnly(Uint8List? jpeg) => NikonLiveViewPacket(
        jpeg: jpeg,
        hasTelemetry: false,
        isRecording: false,
        peakLeft: 0,
        peakRight: 0,
        currentLeft: 0,
        currentRight: 0,
        orientation: 0,
      );

  static NikonLiveViewPacket parse(Uint8List payload) {
    final jpeg = LiveViewJpeg.extract(payload);
    if (jpeg == null) return jpegOnly(null);

    final soi = LiveViewJpeg.findSoi(payload);
    if (soi < headerMinSoiOffset) return jpegOnly(jpeg);

    // 每帧都会跑，不做闭包与越界检查函数；SOI 已在 840 之后，偏移必然可读。
    return NikonLiveViewPacket(
      jpeg: jpeg,
      hasTelemetry: true,
      isRecording: payload[_offsetRecording] != 0,
      peakLeft: payload[_offsetPeakLeft],
      peakRight: payload[_offsetPeakRight],
      currentLeft: payload[_offsetCurrentLeft],
      currentRight: payload[_offsetCurrentRight],
      orientation: payload[_offsetOrientation],
    );
  }
}
