import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/engine/editor/raw_processor_bridge.dart';

void main() {
  test('RAW probe 拍摄参数覆盖预览 EXIF 并保留 GPS', () {
    const base = PhotoMetadata(
      cameraModel: 'Camera',
      latitude: 31.2,
      longitude: 121.4,
      altitude: 12,
    );
    const probe = RawProbeResult(
      supported: true,
      cameraMake: 'NIKON CORPORATION',
      cameraModel: 'NIKON Z 30',
      lensModel: 'NIKKOR Z DX 16-50mm f/3.5-6.3 VR',
      iso: 400,
      aperture: 2.8,
      shutter: '0.004',
      focalLength: 40,
      capturedAt: '2026:11:02 10:30:00',
    );

    final meta = ExifHelper.applyRawProbe(base, probe);

    expect(meta.cameraModel, 'NIKON Z 30');
    expect(meta.titleText, 'NIKON Z 30');
    expect(meta.lensModel, 'NIKKOR Z DX 16-50mm f/3.5-6.3 VR');
    expect(meta.iso, 'ISO 400');
    expect(meta.aperture, 'f/2.8');
    expect(meta.shutterSpeed, '1/250s');
    expect(meta.focalLength, '40mm');
    expect(meta.capturedDate, '2026.11.02 10:30');
    expect(meta.latitude, 31.2);
    expect(meta.longitude, 121.4);
    expect(meta.altitude, 12);
  });

  test('RAW probe 缺失字段或不可用时保留原有元数据', () {
    const base = PhotoMetadata(
      cameraMake: 'Nikon',
      cameraModel: 'Z 30',
      shutterSpeed: '1/100s',
      aperture: 'f/4.0',
      iso: 'ISO 200',
      focalLength: '24mm',
    );
    const probe = RawProbeResult(
      supported: true,
      cameraMake: '',
      cameraModel: '',
      lensModel: '',
      iso: 0,
      aperture: 0,
      shutter: '',
      focalLength: 0,
      capturedAt: '',
    );

    final meta = ExifHelper.applyRawProbe(base, probe);
    expect(meta.cameraMake, 'Nikon');
    expect(meta.cameraModel, 'Z 30');
    expect(meta.shutterSpeed, '1/100s');
    expect(meta.aperture, 'f/4.0');
    expect(meta.iso, 'ISO 200');
    expect(meta.focalLength, '24mm');

    const unavailable = RawProbeResult(supported: false);
    expect(ExifHelper.applyRawProbe(base, unavailable), same(base));

    const invalidShutter = RawProbeResult(supported: true, shutter: 'nan');
    expect(
      ExifHelper.applyRawProbe(base, invalidShutter).shutterSpeed,
      '1/100s',
    );
  });
}
