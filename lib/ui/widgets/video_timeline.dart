import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/video/video_project.dart';
import 'video_frame_strip.dart';

class VideoTimeline extends StatelessWidget {
  final VideoProject project;
  final int currentTimeUs;
  final int selectedClipIndex;
  final int? visibleDurationUs;
  final double height;

  /// 帧序列缩略图条：按时间顺序提供已解码的帧，用于在片段上叠加真实画面。
  final VideoFrameStrip? frameStrip;

  final ValueChanged<int> onSeek;

  const VideoTimeline({
    super.key,
    required this.project,
    required this.currentTimeUs,
    required this.selectedClipIndex,
    this.visibleDurationUs,
    this.height = 132,
    this.frameStrip,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final durationUs = visibleDurationUs ?? project.durationUs;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        void seekFrom(double dx) {
          if (durationUs <= 0 || width <= 0) return;
          final ratio = (dx / width).clamp(0.0, 1.0);
          onSeek((durationUs * ratio).round());
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seekFrom(details.localPosition.dx),
          onHorizontalDragStart: (details) =>
              seekFrom(details.localPosition.dx),
          onHorizontalDragUpdate: (details) =>
              seekFrom(details.localPosition.dx),
          child: CustomPaint(
            size: Size(width, height),
            painter: _TimelinePainter(
              project: project,
              currentTimeUs: currentTimeUs,
              selectedClipIndex: selectedClipIndex,
              visibleDurationUs: visibleDurationUs,
              background: Theme.of(context).colorScheme.surfaceContainerHighest,
              clipColor: Theme.of(context).colorScheme.primary.withAlpha(60),
              clipSelectedColor:
                  Theme.of(context).colorScheme.primary.withAlpha(110),
              markerColor: Theme.of(context).colorScheme.tertiary,
              keyframeColor: Theme.of(context).colorScheme.secondary,
              playheadColor: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
              frameStrip: frameStrip,
            ),
          ),
        );
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final VideoProject project;
  final int currentTimeUs;
  final int selectedClipIndex;
  final int? visibleDurationUs;
  final Color background;
  final Color clipColor;
  final Color clipSelectedColor;
  final Color markerColor;
  final Color keyframeColor;
  final Color playheadColor;
  final Color textColor;
  final VideoFrameStrip? frameStrip;

  _TimelinePainter({
    required this.project,
    required this.currentTimeUs,
    required this.selectedClipIndex,
    required this.visibleDurationUs,
    required this.background,
    required this.clipColor,
    required this.clipSelectedColor,
    required this.markerColor,
    required this.keyframeColor,
    required this.playheadColor,
    required this.textColor,
    this.frameStrip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final durationUs = visibleDurationUs ?? project.durationUs;
    final trackTop = 26.0;
    final trackHeight = math.max(48.0, size.height - 72.0);
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, trackTop, size.width, trackHeight),
      const Radius.circular(8),
    );
    canvas.drawRRect(trackRect, Paint()..color = background);

    if (durationUs <= 0 || project.clips.isEmpty) return;

    double xForUs(int timeUs) => (timeUs / durationUs) * size.width;

    for (var i = 0; i < project.clips.length; i++) {
      final clip = project.clips[i];
      final left = xForUs(clip.timelineStartUs).clamp(0.0, size.width);
      final right = xForUs(clip.timelineEndUs).clamp(0.0, size.width);
      if (right <= 0 || left >= size.width || right <= left) continue;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(left + 1, trackTop + 2, math.max(left + 2, right - 1),
            trackTop + trackHeight - 2),
        const Radius.circular(6),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..color = i == selectedClipIndex ? clipSelectedColor : clipColor);
      // 帧序列缩略图：覆盖在片段底色之上，保留选中高亮边框。
      frameStrip?.draw(
        canvas,
        clip: Rect.fromLTRB(
            left + 1, trackTop + 2, right - 1, trackTop + trackHeight - 2),
        clipTimelineStartUs: clip.timelineStartUs,
        clipDurationUs: clip.durationUs,
      );
      if (right - left > 54) {
        final painter = TextPainter(
          text: TextSpan(
            text: '${(clip.durationUs / 1000000).toStringAsFixed(1)}s',
            style: TextStyle(
                color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: right - left - 8);
        painter.paint(canvas, Offset(left + 6, trackTop + 6));
      }
    }

    final totalSeconds = durationUs / 1000000.0;
    final tickStep = totalSeconds <= 15
        ? 1.0
        : totalSeconds <= 60
            ? 5.0
            : 15.0;
    final tickPaint = Paint()
      ..color = textColor.withAlpha(90)
      ..strokeWidth = 1;
    for (var t = 0.0; t <= totalSeconds + 0.01; t += tickStep) {
      final x = xForUs((t * 1000000).round());
      canvas.drawLine(Offset(x, trackTop + trackHeight),
          Offset(x, trackTop + trackHeight + 5), tickPaint);
      if (t % (tickStep * 2) == 0) {
        final label = _formatSeconds(t.round());
        final tp = TextPainter(
          text: TextSpan(
              text: label, style: TextStyle(color: textColor, fontSize: 9)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset((x - tp.width / 2).clamp(0, size.width - tp.width),
                trackTop + trackHeight + 6));
      }
    }

    final markerPaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2;
    for (final chapter in project.chapters) {
      if (chapter.timeUs > durationUs) continue;
      final x = xForUs(chapter.timeUs);
      canvas.drawLine(Offset(x, trackTop - 4),
          Offset(x, trackTop + trackHeight), markerPaint);
      final flag = Path()
        ..moveTo(x, trackTop - 4)
        ..lineTo(x + 8, trackTop)
        ..lineTo(x, trackTop + 4)
        ..close();
      canvas.drawPath(flag, Paint()..color = markerColor);
    }

    final clip =
        project.clips[selectedClipIndex.clamp(0, project.clips.length - 1)];
    final keyPaint = Paint()..color = keyframeColor;
    for (final track in clip.keyframes) {
      for (final key in track.keys) {
        final absoluteUs = clip.timelineStartUs + key.timeUs;
        if (absoluteUs > durationUs) continue;
        final x = xForUs(absoluteUs);
        final y = trackTop + trackHeight / 2;
        final diamond = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(diamond, keyPaint);
      }
    }

    final playheadX = xForUs(currentTimeUs.clamp(0, durationUs));
    final playheadPaint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(playheadX, trackTop - 8),
        Offset(playheadX, trackTop + trackHeight + 4), playheadPaint);
    canvas.drawCircle(
        Offset(playheadX, trackTop - 8), 4, Paint()..color = playheadColor);
  }

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${s}s';
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) =>
      oldDelegate.project != project ||
      oldDelegate.currentTimeUs != currentTimeUs ||
      oldDelegate.selectedClipIndex != selectedClipIndex ||
      oldDelegate.visibleDurationUs != visibleDurationUs ||
      oldDelegate.frameStrip != frameStrip;
}
