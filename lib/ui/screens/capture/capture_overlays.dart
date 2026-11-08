import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../engine/liveview/live_view_analyzer.dart';
import '../../../engine/liveview/live_view_frame_pipeline.dart';
import '../../design/design.dart';

/// 把内容按等比缩放放进盒子并居中（letterbox）。
Rect fitContentRect(Size content, Size box) {
  if (content.width <= 0 || content.height <= 0) return Rect.zero;
  final scale =
      math.min(box.width / content.width, box.height / content.height);
  final width = content.width * scale;
  final height = content.height * scale;
  return Rect.fromLTWH(
    (box.width - width) / 2,
    (box.height - height) / 2,
    width,
    height,
  );
}

/// 构图网格 + 参考线。
class LiveViewGridPainter extends CustomPainter {
  /// 帧尺寸来源：网格必须画在画面区域内，而不是整个黑边上。
  final ValueListenable<LiveViewFrame?> frames;

  /// 0 = 关，1 = 三分，2 = 九宫格。
  final int mode;

  /// 机身朝向换算出的顺时针角度（0/90/180/270）。
  final int quarterTurns;

  /// 是否画构图参考线（依据机身朝向的水平/垂直基准）。
  final bool guides;

  LiveViewGridPainter({
    required this.frames,
    required this.mode,
    required this.quarterTurns,
    required this.guides,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frames.value;
    final rect = frame == null
        ? Rect.fromLTWH(0, 0, size.width, size.height)
        : fitContentRect(
            Size(frame.width.toDouble(), frame.height.toDouble()), size);
    if (mode > 0) _paintGrid(canvas, rect, nine: mode == 2);
    if (guides) _paintGuides(canvas, rect);
  }

  void _paintGrid(Canvas canvas, Rect rect, {required bool nine}) {
    final paint = Paint()
      ..color = ZSwatch.white54
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final divisions = nine ? 3 : 2;
    for (var i = 1; i <= divisions; i++) {
      final x = rect.left + rect.width * i / (divisions + 1);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
      final y = rect.top + rect.height * i / (divisions + 1);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    canvas.drawRect(rect, paint);
  }

  /// 只画一条与机身朝向一致的基准线。
  ///
  /// PTP 没有暴露俯仰/横滚角，这里给的是「相机横持时基准线应水平、
  /// 竖持时应垂直」的构图参考，不是真正的水准泡。
  void _paintGuides(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = ZSwatch.nikonGold.withAlpha(180)
      ..strokeWidth = 1.2;
    final center = rect.center;
    final vertical = quarterTurns == 90 || quarterTurns == 270;
    const halfLength = 0.36;

    if (vertical) {
      final dx = center.dx;
      canvas.drawLine(
        Offset(dx, center.dy - rect.height * halfLength),
        Offset(dx, center.dy + rect.height * halfLength),
        paint,
      );
    } else {
      final dy = center.dy;
      canvas.drawLine(
        Offset(center.dx - rect.width * halfLength, dy),
        Offset(center.dx + rect.width * halfLength, dy),
        paint,
      );
    }

    // 中心刻度
    final tick = Paint()
      ..color = ZSwatch.nikonGold.withAlpha(150)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - 10, center.dy),
      Offset(center.dx + 10, center.dy),
      tick,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 10),
      Offset(center.dx, center.dy - 3),
      tick,
    );
  }

  @override
  bool shouldRepaint(covariant LiveViewGridPainter oldDelegate) =>
      oldDelegate.frames != frames ||
      oldDelegate.mode != mode ||
      oldDelegate.quarterTurns != quarterTurns ||
      oldDelegate.guides != guides;
}

/// 峰值 / 斑马纹叠加图。
class LiveViewAnalysisPainter extends CustomPainter {
  LiveViewAnalysisPainter({required this.frames, required this.overlay})
      : super(repaint: overlay);

  final ValueListenable<LiveViewFrame?> frames;
  final ValueListenable<LiveViewAnalysisOverlay?> overlay;

  @override
  void paint(Canvas canvas, Size size) {
    final current = overlay.value;
    if (current == null) return;

    final frame = frames.value;
    final frameSize = frame == null
        ? Size(current.width.toDouble(), current.height.toDouble())
        : Size(frame.width.toDouble(), frame.height.toDouble());

    final src = Rect.fromLTWH(
        0, 0, current.width.toDouble(), current.height.toDouble());
    canvas.drawImageRect(
      current.image,
      src,
      fitContentRect(frameSize, size),
      Paint()
        ..filterQuality = FilterQuality.low
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(covariant LiveViewAnalysisPainter oldDelegate) =>
      oldDelegate.frames != frames || oldDelegate.overlay != overlay;
}

/// 角落直方图。
class LiveViewHistogramPainter extends CustomPainter {
  LiveViewHistogramPainter({
    required this.histogram,
    required this.zebraThreshold,
  }) : super(repaint: histogram);

  final ValueListenable<HistogramSnapshot?> histogram;
  final int zebraThreshold;

  @override
  void paint(Canvas canvas, Size size) {
    final snapshot = histogram.value;
    final background = Paint()..color = ZSwatch.black54;
    final rect = Offset.zero & size;
    final rounded = RRect.fromRectAndRadius(
        rect, Radius.circular(ZRadius.xs));
    canvas.drawRRect(rounded, background);

    if (snapshot == null || snapshot.peakCount == 0) return;

    final barPaint = Paint()..color = ZSwatch.pureWhite.withAlpha(200);
    final barWidth = size.width / 256;
    for (var i = 0; i < 256; i++) {
      final ratio = snapshot.ratioOf(i);
      if (ratio <= 0) continue;
      final h = size.height * ratio.clamp(0.0, 1.0);
      canvas.drawRect(
        Rect.fromLTWH(i * barWidth, size.height - h, barWidth, h),
        barPaint,
      );
    }

    // 过曝阈值参考线
    final thresholdPaint = Paint()
      ..color = ZSwatch.nikonGold.withAlpha(160)
      ..strokeWidth = 1;
    final x = size.width * zebraThreshold / 255;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), thresholdPaint);
  }

  @override
  bool shouldRepaint(covariant LiveViewHistogramPainter oldDelegate) =>
      oldDelegate.histogram != histogram ||
      oldDelegate.zebraThreshold != zebraThreshold;
}
