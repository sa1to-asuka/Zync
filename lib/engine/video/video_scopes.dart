import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum VideoScopeType { waveform, vectorscope, rgbParade }

/// 示波器栅格尺寸（与专业监看习惯一致，避免过度采样拖慢 UI）。
const int kVideoScopeColumns = 64;
const int kVideoScopeRows = 64;

/// 波形图上单个可量测点的读数。
class VideoScopeReading {
  final double ire;
  final double value;

  const VideoScopeReading({required this.ire, required this.value});

  /// 显示用：IRE 数值。
  String get label => "${ire.toStringAsFixed(0)} IRE";
}

class VideoScopeData {
  /// 每种示波器的栅格强度，0..1，长度 = columns * rows。
  final List<double> waveform;
  final List<double> vectorscope;

  /// RGB Parade：R、G、B 三条通道各自的长度 columns * rows。
  final List<double> paradeR;
  final List<double> paradeG;
  final List<double> paradeB;

  /// 亮度直方图，长度 64。
  final List<double> lumaHistogram;

  /// 削波统计：0..1，超 0 / 低于 1 的像素占比。
  final double clippedHighlights;
  final double clippedShadows;

  /// IRE 读数：最亮 / 平均 / 最暗三点。
  final List<VideoScopeReading> readings;

  const VideoScopeData({
    required this.waveform,
    required this.vectorscope,
    required this.paradeR,
    required this.paradeG,
    required this.paradeB,
    required this.lumaHistogram,
    required this.clippedHighlights,
    required this.clippedShadows,
    required this.readings,
  });
}

/// 从一帧 JPEG 计算示波器数据。解码与统计都在后台 isolate 完成。
class VideoScopeAnalyzer {
  VideoScopeAnalyzer._();

  static Future<VideoScopeData?> analyze(Uint8List jpeg) async {
    if (jpeg.length < 4) return null;
    return compute(_analyzeIsolate, jpeg);
  }
}

VideoScopeData? _analyzeIsolate(Uint8List bytes) {
  try {
    var decoded = img.decodeJpg(bytes);
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0)
      return null;
    decoded = img.bakeOrientation(decoded);

    // 采样前先限长边，避免 4K 帧在 isolate 里做几十万次采样。
    const maxEdge = 480;
    if (decoded.width > maxEdge || decoded.height > maxEdge) {
      decoded = decoded.width >= decoded.height
          ? img.copyResize(decoded,
              width: maxEdge, interpolation: img.Interpolation.average)
          : img.copyResize(decoded,
              height: maxEdge, interpolation: img.Interpolation.average);
    }

    final width = decoded.width;
    final height = decoded.height;
    final cells = kVideoScopeColumns * kVideoScopeRows;
    final waveform = List<double>.filled(cells, 0);
    final vectorscope = List<double>.filled(cells, 0);
    final paradeR = List<double>.filled(cells, 0);
    final paradeG = List<double>.filled(cells, 0);
    final paradeB = List<double>.filled(cells, 0);
    final luma = List<double>.filled(64, 0);

    // IRE 读数：按列统计亮度极值。
    final maxPerColumn = List<double>.filled(kVideoScopeColumns, 0);
    final minPerColumn = List<double>.filled(kVideoScopeColumns, 1);
    final sumPerColumn = List<double>.filled(kVideoScopeColumns, 0);
    final countPerColumn = List<int>.filled(kVideoScopeColumns, 0);

    var highlights = 0;
    var shadows = 0;
    var sampled = 0;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = decoded.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;
        final lumaValue = _luma(r, g, b);

        // 波形图：横向分列，纵向按亮度落格。
        final column = (x / width * kVideoScopeColumns)
            .floor()
            .clamp(0, kVideoScopeColumns - 1);
        final yWave = ((1.0 - lumaValue) * (kVideoScopeRows - 1)).round();
        waveform[yWave * kVideoScopeColumns + column] += 1;

        // RGB Parade：三通道分别累计。
        paradeR[yWave * kVideoScopeColumns + column] += r;
        paradeG[yWave * kVideoScopeColumns + column] += g;
        paradeB[yWave * kVideoScopeColumns + column] += b;

        // 矢量示波器：以 U/V 平面定位色度。
        final u = _cb(b - lumaValue);
        final v = _cr(r - lumaValue);
        final vsx = (0.5 + u).clamp(0.0, 1.0);
        final vsy = (0.5 + v).clamp(0.0, 1.0);
        final vx = (vsx * (kVideoScopeColumns - 1)).round();
        final vy = (vsy * (kVideoScopeRows - 1)).round();
        vectorscope[vy * kVideoScopeColumns + vx] += 1;

        luma[(lumaValue * 63).round().clamp(0, 63)] += 1;

        if (r >= 0.996 || g >= 0.996 || b >= 0.996) highlights++;
        if (r <= 0.004 && g <= 0.004 && b <= 0.004) shadows++;
        sampled++;

        if (maxPerColumn[column] < lumaValue) maxPerColumn[column] = lumaValue;
        if (minPerColumn[column] > lumaValue) minPerColumn[column] = lumaValue;
        sumPerColumn[column] += lumaValue;
        countPerColumn[column] += 1;
      }
    }

    if (sampled == 0) return null;

    final inv = 1.0 / sampled;
    final cellsPerColumn = ((width / kVideoScopeColumns).ceil() *
            (height / kVideoScopeRows).ceil()) *
        1;
    final paradeScale = cellsPerColumn <= 0 ? 1.0 : 1.0 / cellsPerColumn;

    return VideoScopeData(
      waveform: _normalize(waveform),
      vectorscope: _normalize(vectorscope),
      paradeR: _normalizeChannel(paradeR, paradeScale),
      paradeG: _normalizeChannel(paradeG, paradeScale),
      paradeB: _normalizeChannel(paradeB, paradeScale),
      lumaHistogram: _normalize(luma),
      clippedHighlights: highlights * inv,
      clippedShadows: shadows * inv,
      readings: _buildReadings(
          maxPerColumn, minPerColumn, sumPerColumn, countPerColumn),
    );
  } catch (_) {
    return null;
  }
}

/// 生成 IRE 读数：最亮 / 平均 / 最暗三点。
List<VideoScopeReading> _buildReadings(
  List<double> maxPerColumn,
  List<double> minPerColumn,
  List<double> sumPerColumn,
  List<int> countPerColumn,
) {
  var maxValue = 0.0;
  var minValue = 1.0;
  var sum = 0.0;
  var count = 0;
  for (var i = 0; i < maxPerColumn.length; i++) {
    if (maxValue < maxPerColumn[i]) maxValue = maxPerColumn[i];
    if (minValue > minPerColumn[i]) minValue = minPerColumn[i];
    if (countPerColumn[i] > 0) {
      sum += sumPerColumn[i] / countPerColumn[i];
      count++;
    }
  }
  final avgValue = count > 0 ? sum / count : 0.0;
  double toIre(double v) => v.clamp(0.0, 1.0) * 100.0;
  return [
    VideoScopeReading(ire: toIre(maxValue), value: maxValue),
    VideoScopeReading(ire: toIre(avgValue), value: avgValue),
    VideoScopeReading(ire: toIre(minValue), value: minValue),
  ];
}

double _luma(double r, double g, double b) =>
    0.2126 * r + 0.7152 * g + 0.0722 * b;

double _cb(double c) => 0.5386 * c;

double _cr(double c) => 0.6350 * c;

/// 归一化到 0..1，并开方压缩动态范围，让低亮度细节也可见。
List<double> _normalize(List<double> values) {
  var maxV = 0.0;
  for (final v in values) {
    if (v > maxV) maxV = v;
  }
  if (maxV <= 0) return List<double>.filled(values.length, 0);
  return values
      .map((v) => v <= 0 ? 0.0 : _sqrt(v / maxV))
      .toList(growable: false);
}

List<double> _normalizeChannel(List<double> values, double scale) {
  var maxV = 0.0;
  for (final v in values) {
    final scaled = v * scale;
    if (scaled > maxV) maxV = scaled;
  }
  if (maxV <= 0) return List<double>.filled(values.length, 0);
  return values.map((v) {
    final scaled = v * scale;
    return scaled <= 0 ? 0.0 : _sqrt(scaled / maxV);
  }).toList(growable: false);
}

double _sqrt(double v) {
  if (v <= 0) return 0;
  var guess = v;
  for (var i = 0; i < 6; i++) {
    guess = 0.5 * (guess + v / guess);
  }
  return guess.clamp(0.0, 1.0);
}
