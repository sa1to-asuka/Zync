import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/video/video_scopes.dart';

Uint8List _solidJpeg(int width, int height,
    {required int r, required int g, required int b}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return img.encodeJpg(image, quality: 95);
}

void main() {
  test('纯灰帧的波形图集中在中间亮度且不削波', () async {
    final bytes = _solidJpeg(64, 64, r: 128, g: 128, b: 128);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    expect(data!.clippedHighlights, lessThan(0.001));
    expect(data.clippedShadows, lessThan(0.001));

    var energy = 0.0;
    var peakRow = -1;
    var peakValue = -1.0;
    for (var row = 0; row < kVideoScopeRows; row++) {
      var rowEnergy = 0.0;
      for (var col = 0; col < kVideoScopeColumns; col++) {
        rowEnergy += data.waveform[row * kVideoScopeColumns + col];
      }
      energy += rowEnergy;
      if (rowEnergy > peakValue) {
        peakValue = rowEnergy;
        peakRow = row;
      }
    }
    expect(energy, greaterThan(0));
    expect(peakRow, greaterThan(kVideoScopeRows ~/ 2 - 3));
    expect(peakRow, lessThan(kVideoScopeRows ~/ 2 + 3));
  });

  test('纯白帧被识别为高光削波', () async {
    final bytes = _solidJpeg(48, 48, r: 255, g: 255, b: 255);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    expect(data!.clippedHighlights, greaterThan(0.9));
    expect(data.clippedShadows, lessThan(0.001));
  });

  test('纯黑帧被识别为暗部削波', () async {
    final bytes = _solidJpeg(48, 48, r: 0, g: 0, b: 0);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    expect(data!.clippedShadows, greaterThan(0.9));
    expect(data.clippedHighlights, lessThan(0.001));
  });

  test('饱和红色在矢量示波器与 RGB Parade 上分离', () async {
    final bytes = _solidJpeg(64, 64, r: 255, g: 0, b: 0);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    final scope = data!;

    var redTotal = 0.0;
    var greenTotal = 0.0;
    var blueTotal = 0.0;
    for (var i = 0; i < scope.paradeR.length; i++) {
      redTotal += scope.paradeR[i];
      greenTotal += scope.paradeG[i];
      blueTotal += scope.paradeB[i];
    }
    expect(redTotal, greaterThan(greenTotal));
    expect(redTotal, greaterThan(blueTotal));

    var vectorTotal = 0.0;
    for (final v in scope.vectorscope) {
      vectorTotal += v;
    }
    expect(vectorTotal, greaterThan(0));
  });

  test('IRE 读数：纯白帧接近 100 IRE', () async {
    final bytes = _solidJpeg(32, 32, r: 255, g: 255, b: 255);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    final readings = data!.readings;
    expect(readings.length, 3);
    for (final reading in readings) {
      expect(reading.ire, greaterThan(98));
    }
    expect(readings[0].label.contains('IRE'), isTrue);
  });

  test('IRE 读数：纯黑帧接近 0 IRE', () async {
    final bytes = _solidJpeg(32, 32, r: 0, g: 0, b: 0);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    for (final reading in data!.readings) {
      expect(reading.ire, lessThan(2));
    }
  });

  test('IRE 读数顺序为峰值 >= 平均 >= 黑位', () async {
    final gradient = img.Image(width: 16, height: 32, numChannels: 3);
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 16; x++) {
        final v = (255 * y / 31).round();
        gradient.setPixel(x, y, img.ColorRgb8(v, v, v));
      }
    }
    final bytes = img.encodeJpg(gradient, quality: 95);
    final data = await VideoScopeAnalyzer.analyze(bytes);
    expect(data, isNotNull);
    final readings = data!.readings;
    expect(readings[0].ire, greaterThanOrEqualTo(readings[1].ire));
    expect(readings[1].ire, greaterThanOrEqualTo(readings[2].ire));
    expect(readings[0].ire, greaterThan(85));
    expect(readings[2].ire, lessThan(15));
  });

  test('非法输入返回 null 而不抛异常', () async {
    expect(await VideoScopeAnalyzer.analyze(Uint8List(0)), isNull);
    expect(await VideoScopeAnalyzer.analyze(Uint8List.fromList([1, 2, 3])),
        isNull);
  });
}
