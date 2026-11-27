import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/watermark/watermark_overlay_layer.dart';

void main() {
  group('WatermarkTextLayer & EXIF Token Substitution', () {
    test('WatermarkTextLayer JSON 序列化往返保持字段完整且钳制合法边界', () {
      const layer = WatermarkTextLayer(
        id: 't1',
        text: '光影纪实 {model}',
        nx: 0.35,
        ny: 0.72,
        scale: 1.6,
        rotation: 0.25,
        fontId: 'ma_shan_zheng',
        colorValue: 0xFFAA1D17,
        opacity: 0.9,
        letterSpacing: 3.0,
        lineHeight: 1.4,
        weightIndex: 2,
        italic: true,
        vertical: true,
        strokeColorValue: 0xFFFFFFFF,
        strokeWidth: 2.0,
        shadowBlur: 4.0,
        bgStyle: OverlayBgStyle.vermilionSealYang,
        bgColorValue: 0xFFFAF6EC,
        locked: true,
      );

      final decoded = WatermarkTextLayer.fromJson(layer.toJson());
      expect(decoded.id, 't1');
      expect(decoded.text, '光影纪实 {model}');
      expect(decoded.nx, closeTo(0.35, 1e-6));
      expect(decoded.ny, closeTo(0.72, 1e-6));
      expect(decoded.vertical, isTrue);
      expect(decoded.bgStyle, OverlayBgStyle.vermilionSealYang);
      expect(decoded.locked, isTrue);

      final clamped = layer.copyWith(nx: -2, ny: 99, scale: 99);
      expect(clamped.nx, inInclusiveRange(0.02, 0.98));
      expect(clamped.ny, inInclusiveRange(0.02, 0.98));
      expect(clamped.scale, lessThanOrEqualTo(4.0));
    });

    test('resolveWatermarkExifTokens 正确替换令牌并清理缺失字段遗留的分隔符', () {
      const fullMeta = PhotoMetadata(
        cameraMake: 'NIKON',
        cameraModel: 'Z 6 III',
        lensModel: 'NIKKOR Z 35mm f/1.8 S',
        shutterSpeed: '1/500s',
        aperture: 'f/2.0',
        iso: 'ISO 100',
        focalLength: '35mm',
        capturedDate: '2026.11.26',
      );
      final resolved = resolveWatermarkExifTokens(
        '{model} · {focal} · {aperture} · {shutter} · {iso} · {gps}',
        fullMeta,
      );
      expect(resolved, contains('35mm'));
      expect(resolved, contains('f/2.0'));
      expect(resolved, isNot(contains('{')));
      expect(resolved, isNot(endsWith('·')));
    });

    test('WatermarkStampLayer JSON 往返与安全范围钳制', () {
      const stamp = WatermarkStampLayer(
        id: 's1',
        nx: 0.88,
        ny: 0.14,
        scale: 0.22,
        rotation: -0.1,
        opacity: 0.85,
      );
      final parsed = WatermarkStampLayer.fromJson(stamp.toJson());
      expect(parsed.id, 's1');
      expect(parsed.scale, closeTo(0.22, 1e-6));
      expect(stamp.copyWith(scale: 5.0).scale, lessThanOrEqualTo(0.6));
    });
  });
}
