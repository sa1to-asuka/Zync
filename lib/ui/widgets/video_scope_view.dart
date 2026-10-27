import 'package:flutter/material.dart';

import '../../engine/video/video_scopes.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 视频示波器面板：波形图 / 矢量示波器 / RGB Parade + 亮度直方图 + 削波统计。
class VideoScopeView extends StatefulWidget {
  final VideoScopeData? data;
  final bool loading;
  final VoidCallback onRefresh;

  const VideoScopeView({
    super.key,
    required this.data,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<VideoScopeView> createState() => _VideoScopeViewState();
}

class _VideoScopeViewState extends State<VideoScopeView> {
  VideoScopeType _type = VideoScopeType.waveform;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    const dark = ZyncPalette.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.scopeTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: zc.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.scopeCaptureFrameTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: widget.loading ? null : widget.onRefresh,
              icon: widget.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(l10n.scopeWaveform, VideoScopeType.waveform),
                _chip(l10n.scopeVectorscope, VideoScopeType.vectorscope),
                _chip('RGB Parade', VideoScopeType.rgbParade),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.data == null)
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                widget.loading ? l10n.scopeAnalyzing : l10n.scopeEmptyHint,
                style: TextStyle(fontSize: 12, color: zc.textSecondary),
              ),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: dark.bg,
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    border: Border.all(
                      color: dark.outline,
                      width: ZStroke.hairline,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _ScopePainter(
                      data: widget.data!,
                      type: _type,
                      gridColor: dark.textSecondary,
                      palette: dark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildHistogram(zc, l10n),
              const SizedBox(height: 6),
              _buildReadings(zc, l10n),
              const SizedBox(height: 6),
              _buildClipInfo(zc, l10n),
            ],
          ),
      ],
    );
  }

  Widget _chip(String label, VideoScopeType type) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: _type == type,
        onSelected: (_) => setState(() => _type = type),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildHistogram(ZyncPalette zc, AppLocalizations l10n) {
    final data = widget.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.scopeLumaHistogram,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: zc.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 52,
          child: CustomPaint(
            size: Size.infinite,
            painter: _HistogramPainter(
              data.lumaHistogram,
              zc.textSecondary,
              zc.outline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadings(ZyncPalette zc, AppLocalizations l10n) {
    final readings = widget.data!.readings;
    if (readings.length < 3) return const SizedBox.shrink();
    final labels = [
      l10n.scopePeak,
      l10n.scopeAverage,
      l10n.scopeBlackLevel,
    ];
    return Row(
      children: [
        for (var i = 0; i < readings.length; i++)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels[i],
                  style: TextStyle(fontSize: 10, color: zc.textSecondary),
                ),
                Text(
                  readings[i].ire.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: zc.textPrimary,
                  ),
                ),
                Text(
                  'IRE',
                  style: TextStyle(fontSize: 9, color: zc.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildClipInfo(ZyncPalette zc, AppLocalizations l10n) {
    final data = widget.data!;
    final hi = data.clippedHighlights;
    final lo = data.clippedShadows;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _clipChip(zc, l10n.scopeHighlightClip, hi, zc.warning),
        _clipChip(zc, l10n.scopeShadowClip, lo, zc.info),
      ],
    );
  }

  Widget _clipChip(
    ZyncPalette zc,
    String label,
    double value,
    Color color,
  ) {
    final percent = (value * 100).toStringAsFixed(2);
    final hasClip = value > 0.001;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasClip ? Icons.warning_amber : Icons.check_circle_outline,
          size: 14,
          color: hasClip ? color : zc.success,
        ),
        const SizedBox(width: 4),
        Text(
          '$label $percent%',
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: hasClip ? color : zc.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ScopePainter extends CustomPainter {
  final VideoScopeData data;
  final VideoScopeType type;
  final Color gridColor;
  final ZyncPalette palette;

  _ScopePainter({
    required this.data,
    required this.type,
    required this.gridColor,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    switch (type) {
      case VideoScopeType.waveform:
        _drawIntensity(
          canvas,
          size,
          data.waveform,
          (v) => palette.channelLuma.withAlpha((v * 235).round().clamp(0, 255)),
        );
      case VideoScopeType.vectorscope:
        _drawIntensity(
          canvas,
          size,
          data.vectorscope,
          (v) => palette.channelGreen.withAlpha((v * 235).round().clamp(0, 255)),
        );
      case VideoScopeType.rgbParade:
        _drawParade(canvas, size);
    }
    // 0/100 IRE 参考线。
    final linePaint = Paint()
      ..color = palette.outlineStrong
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), linePaint);
    if (type == VideoScopeType.waveform) {
      void drawIreLine(double value, Color color, {bool dashed = false}) {
        final y = size.height * (1.0 - value.clamp(0.0, 1.0));
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1;
        if (dashed) {
          const dash = 6.0;
          for (var x = 0.0; x < size.width; x += dash * 2) {
            canvas.drawLine(Offset(x, y),
                Offset((x + dash).clamp(0.0, size.width), y), paint);
          }
        } else {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      }

      drawIreLine(0.75, palette.outline, dashed: true);
      drawIreLine(0.5, palette.outline, dashed: true);
      drawIreLine(0.25, palette.outline, dashed: true);
      if (data.readings.length >= 3) {
        drawIreLine(data.readings[1].value, palette.info, dashed: true);
        drawIreLine(data.readings[0].value, palette.warning);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.outline
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawIntensity(
    Canvas canvas,
    Size size,
    List<double> cells,
    Color Function(double) colorOf,
  ) {
    final cellW = size.width / kVideoScopeColumns;
    final cellH = size.height / kVideoScopeRows;
    final paint = Paint();
    for (var row = 0; row < kVideoScopeRows; row++) {
      for (var col = 0; col < kVideoScopeColumns; col++) {
        final v = cells[row * kVideoScopeColumns + col];
        if (v <= 0.004) continue;
        paint.color = colorOf(v);
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW + 0.6, cellH + 0.6),
          paint,
        );
      }
    }
  }

  void _drawParade(Canvas canvas, Size size) {
    final laneW = size.width / 3;
    final cellW = laneW / kVideoScopeColumns;
    final cellH = size.height / kVideoScopeRows;
    final paint = Paint();
    final lanes = [
      (data.paradeR, palette.channelRed),
      (data.paradeG, palette.channelGreen),
      (data.paradeB, palette.channelBlue),
    ];
    for (var lane = 0; lane < 3; lane++) {
      final cells = lanes[lane].$1;
      final base = lanes[lane].$2;
      final offsetX = lane * laneW;
      for (var row = 0; row < kVideoScopeRows; row++) {
        for (var col = 0; col < kVideoScopeColumns; col++) {
          final v = cells[row * kVideoScopeColumns + col];
          if (v <= 0.004) continue;
          paint.color = base.withAlpha((v * 235).round().clamp(0, 255));
          canvas.drawRect(
            Rect.fromLTWH(
                offsetX + col * cellW, row * cellH, cellW + 0.6, cellH + 0.6),
            paint,
          );
        }
      }
    }
    // 通道分隔线。
    final sep = Paint()
      ..color = palette.outlineStrong
      ..strokeWidth = 1;
    canvas.drawLine(Offset(laneW, 0), Offset(laneW, size.height), sep);
    canvas.drawLine(Offset(laneW * 2, 0), Offset(laneW * 2, size.height), sep);
  }

  @override
  bool shouldRepaint(covariant _ScopePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.type != type ||
      oldDelegate.gridColor != gridColor;
}

class _HistogramPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color lineColor;

  _HistogramPainter(this.values, this.color, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    var maxV = 0.0;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (maxV <= 0) return;
    final barW = size.width / values.length;
    final paint = Paint()..color = color.withAlpha(160);
    for (var i = 0; i < values.length; i++) {
      final h = size.height * (values[i] / maxV);
      canvas.drawRect(
        Rect.fromLTWH(i * barW, size.height - h, barW - 0.6, h),
        paint,
      );
    }
    // 中灰 50 IRE 参考线。
    final mid = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.25),
        Offset(size.width, size.height * 0.25), mid);
    canvas.drawLine(Offset(0, size.height * 0.5),
        Offset(size.width, size.height * 0.5), mid);
    canvas.drawLine(Offset(0, size.height * 0.75),
        Offset(size.width, size.height * 0.75), mid);
  }

  @override
  bool shouldRepaint(covariant _HistogramPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
