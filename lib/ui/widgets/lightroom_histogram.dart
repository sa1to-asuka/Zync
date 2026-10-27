import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/filter/photo_filter.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 直方图五大核心曝光区间定义 (对标 Adobe Lightroom 5-Zone Exposure)
enum HistogramZone {
  blacks('黑色色阶', 'Blacks'),
  shadows('阴影', 'Shadows'),
  exposure('曝光度', 'Exposure'),
  highlights('高光', 'Highlights'),
  whites('白色色阶', 'Whites');

  final String label;
  final String code;

  const HistogramZone(this.label, this.code);

  String trLabel(BuildContext context) => switch (this) {
        HistogramZone.blacks => context.l10n.toneBlacks,
        HistogramZone.shadows => context.l10n.toneShadows,
        HistogramZone.exposure => context.l10n.toneExposure,
        HistogramZone.highlights => context.l10n.toneHighlights,
        HistogramZone.whites => context.l10n.toneWhites,
      };
}

/// 直方图通道频数统计模型
class HistogramData {
  final List<double> redBins; // 64 bins, 0.0 ~ 1.0
  final List<double> greenBins; // 64 bins, 0.0 ~ 1.0
  final List<double> blueBins; // 64 bins, 0.0 ~ 1.0
  final List<double> lumBins; // 64 bins, 0.0 ~ 1.0

  const HistogramData({
    required this.redBins,
    required this.greenBins,
    required this.blueBins,
    required this.lumBins,
  });

  /// 依据调色参数与采样像素实时计算直方图频数分布
  factory HistogramData.compute({
    required PhotoEditAdjustments adjustments,
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    List<int>? sampledR,
    List<int>? sampledG,
    List<int>? sampledB,
  }) {
    const binCount = 64;

    // 若具备实际图像采样像素，进行高保真实时变换运算
    if (sampledR != null &&
        sampledG != null &&
        sampledB != null &&
        sampledR.isNotEmpty) {
      final matrix = PhotoFilterEngine.createCompositeMatrix(
        filterType: filterType,
        filterIntensity: filterIntensity,
        adjustments: adjustments,
      );

      final rCounts = List<int>.filled(binCount, 0);
      final gCounts = List<int>.filled(binCount, 0);
      final bCounts = List<int>.filled(binCount, 0);
      final lumCounts = List<int>.filled(binCount, 0);

      final n = sampledR.length;
      for (int i = 0; i < n; i++) {
        final transformed = PhotoFilterEngine.applyMatrixToRgb(
          sampledR[i],
          sampledG[i],
          sampledB[i],
          matrix,
        );
        final r = transformed[0];
        final g = transformed[1];
        final b = transformed[2];
        final lum =
            (0.2126 * r + 0.7152 * g + 0.0722 * b).round().clamp(0, 255);

        rCounts[(r * (binCount - 1) ~/ 255).clamp(0, binCount - 1)]++;
        gCounts[(g * (binCount - 1) ~/ 255).clamp(0, binCount - 1)]++;
        bCounts[(b * (binCount - 1) ~/ 255).clamp(0, binCount - 1)]++;
        lumCounts[(lum * (binCount - 1) ~/ 255).clamp(0, binCount - 1)]++;
      }

      int maxR = 1, maxG = 1, maxB = 1, maxLum = 1;
      for (int i = 0; i < binCount; i++) {
        if (rCounts[i] > maxR) maxR = rCounts[i];
        if (gCounts[i] > maxG) maxG = gCounts[i];
        if (bCounts[i] > maxB) maxB = bCounts[i];
        if (lumCounts[i] > maxLum) maxLum = lumCounts[i];
      }

      return HistogramData(
        redBins:
            List.generate(binCount, (i) => (rCounts[i] / maxR).clamp(0.0, 1.0)),
        greenBins:
            List.generate(binCount, (i) => (gCounts[i] / maxG).clamp(0.0, 1.0)),
        blueBins:
            List.generate(binCount, (i) => (bCounts[i] / maxB).clamp(0.0, 1.0)),
        lumBins: List.generate(
          binCount,
          (i) => (lumCounts[i] / maxLum).clamp(0.0, 1.0),
        ),
      );
    }

    // 无图像采样时的自然摄影平滑基准分布 (依据曝光与色温动态偏移)
    final shiftExp = (adjustments.exposure / 100.0) * 12.0;
    final shiftTemp = (adjustments.temperature / 100.0) * 8.0;
    final contrastScale = 1.0 + (adjustments.contrast / 100.0) * 0.5;

    final rBins = List<double>.filled(binCount, 0.0);
    final gBins = List<double>.filled(binCount, 0.0);
    final bBins = List<double>.filled(binCount, 0.0);
    final lBins = List<double>.filled(binCount, 0.0);

    for (int i = 0; i < binCount; i++) {
      final xNorm = (i - (32.0 + shiftExp)) / (11.0 / contrastScale);
      final baseVal = math.exp(-0.5 * xNorm * xNorm);

      final rX = (i - (32.0 + shiftExp + shiftTemp)) / (11.0 / contrastScale);
      final bX = (i - (32.0 + shiftExp - shiftTemp)) / (11.0 / contrastScale);

      rBins[i] = (math.exp(-0.5 * rX * rX) * (0.85 + 0.15 * math.sin(i * 0.2)))
          .clamp(0.0, 1.0);
      gBins[i] = (baseVal * (0.80 + 0.15 * math.cos(i * 0.25))).clamp(0.0, 1.0);
      bBins[i] = (math.exp(-0.5 * bX * bX) * (0.88 + 0.12 * math.sin(i * 0.3)))
          .clamp(0.0, 1.0);
      lBins[i] = (baseVal * 0.92).clamp(0.0, 1.0);
    }

    return HistogramData(
      redBins: rBins,
      greenBins: gBins,
      blueBins: bBins,
      lumBins: lBins,
    );
  }
}

/// Lightroom 级 RGB 曲线与明暗直方图绘制器
class LightroomHistogramPainter extends CustomPainter {
  final HistogramData data;
  final HistogramZone? selectedZone;

  LightroomHistogramPainter({
    required this.data,
    this.selectedZone,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final dark = ZyncPalette.dark;

    final borderRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(8),
    );

    // 1. 底板深色网格背景
    canvas.drawRRect(borderRRect, Paint()..color = dark.bg);

    // 2. 纵向五分区基准参考虚线与当前高亮分区背景
    final zoneWidth = size.width / 5.0;
    if (selectedZone != null) {
      final zoneIndex = selectedZone!.index;
      final zoneRect =
          Rect.fromLTWH(zoneIndex * zoneWidth, 0, zoneWidth, size.height);
      canvas.drawRect(
        zoneRect,
        Paint()..color = dark.accent.withAlpha(25),
      );
    }

    final gridPaint = Paint()
      ..color = dark.textPrimary.withAlpha(20)
      ..strokeWidth = 1.0;
    for (int i = 1; i < 5; i++) {
      final x = i * zoneWidth;
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), gridPaint);
    }

    // 3. 底部亮蓝基准标线
    final baseLineY = size.height - 3;
    final basePaint = Paint()
      ..color = dark.info
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(4, baseLineY),
      Offset(size.width - 4, baseLineY),
      basePaint,
    );

    final count = data.lumBins.length;
    final stepX = (size.width - 16) / (count - 1);
    const startX = 8.0;

    // 4. 亮度 (Luminance) 半透明波峰填充
    final lumPath = Path()..moveTo(startX, baseLineY);
    for (int i = 0; i < count; i++) {
      final val = data.lumBins[i];
      final x = startX + i * stepX;
      final y = baseLineY - (val * (size.height - 12));
      lumPath.lineTo(x, y);
    }
    lumPath.lineTo(startX + (count - 1) * stepX, baseLineY);
    lumPath.close();

    final lumFill = Paint()
      ..color = dark.channelLuma.withAlpha(32)
      ..style = PaintingStyle.fill;
    canvas.drawPath(lumPath, lumFill);

    // 5. R (红) 曲线
    _drawSmoothCurve(
      canvas,
      data.redBins,
      startX,
      stepX,
      baseLineY,
      size.height - 10,
      dark.channelRed,
    );

    // 6. G (绿) 曲线
    _drawSmoothCurve(
      canvas,
      data.greenBins,
      startX,
      stepX,
      baseLineY,
      size.height - 10,
      dark.channelGreen,
    );

    // 7. B (蓝) 曲线
    _drawSmoothCurve(
      canvas,
      data.blueBins,
      startX,
      stepX,
      baseLineY,
      size.height - 10,
      dark.channelBlue,
    );

    // 8. 边缘微细内边框
    canvas.drawRRect(
      borderRRect,
      Paint()
        ..color = dark.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawSmoothCurve(
    Canvas canvas,
    List<double> bins,
    double startX,
    double stepX,
    double baseLineY,
    double maxHeight,
    Color color,
  ) {
    final count = bins.length;
    final path = Path();
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    for (int i = 0; i < count; i++) {
      final x = startX + i * stepX;
      final y = baseLineY - (bins[i] * maxHeight);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LightroomHistogramPainter old) {
    return old.data != data || old.selectedZone != selectedZone;
  }
}

/// Adobe Lightroom 风格多功能直方图交互组件
class LightroomHistogramWidget extends StatelessWidget {
  final HistogramData data;
  final HistogramZone? selectedZone;
  final ValueChanged<HistogramZone>? onSelectZone;

  const LightroomHistogramWidget({
    super.key,
    required this.data,
    this.selectedZone,
    this.onSelectZone,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: BorderRadius.circular(ZRadius.md),
        border: Border.all(color: zc.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 核心 RGB 波形与明度曲线画布
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: LightroomHistogramPainter(
                data: data,
                selectedZone: selectedZone,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [0, 64, 128, 192, 255]
                  .map(
                    (value) => Text(
                      '$value',
                      style: TextStyle(color: zc.textSecondary, fontSize: 10),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),

          // 底部五大曝光区间指引标 (点击可快速聚焦对应调色项)
          Row(
            children: HistogramZone.values.map((zone) {
              final isSelected = zone == selectedZone;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelectZone?.call(zone),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? zc.accent.withAlpha(35)
                          : ZSwatch.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? zc.accent : ZSwatch.transparent,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      zone.trLabel(context),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? zc.accent : zc.textTertiary,
                        fontSize: 9.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Text(
            l10n.histogramTitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: zc.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
