import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/capture_date.dart';
import 'package:zync/core/utils/exif_helper.dart';
import 'package:zync/protocol/camera_driver.dart';

Uint8List _pngWithoutExif() {
  final image = img.Image(width: 8, height: 8);
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('formatCaptureDate 兼容 PTP / EXIF / ISO / 纯日期', () {
    expect(formatCaptureDate('20261011T100000'), '2026.10.11 10:00');
    expect(formatCaptureDate('2026:10:11 10:00:00'), '2026.10.11 10:00');
    expect(formatCaptureDate('2026.10.11 10:00'), '2026.10.11 10:00');
    expect(formatCaptureDate('2026-10-11T10:00:00'), '2026.10.11 10:00');
    expect(formatCaptureDate('2026-10-11'), '2026.10.11 00:00');
    expect(formatCaptureDate('00000000T000000'), '');
    expect(formatCaptureDate(''), '');
    expect(formatCaptureDate('not a date'), 'not a date');
  });

  test('无 EXIF 的图片不再回退到示例拍摄时间', () async {
    final meta = await ExifHelper.parseBytes(_pngWithoutExif());
    expect(meta.capturedDate, '');
    expect(meta.cameraModel, '');
    expect(meta.cameraMake, '');
    expect(meta.shutterSpeed, '');
    expect(meta.aperture, '');
    expect(meta.iso, '');
  });

  test('CameraFileItem 保留原始 captureDate，展示值归一化', () {
    final item = CameraFileItem(
      handle: 1,
      storageId: 1,
      format: 0x3801,
      size: 1,
      fileName: 'DSC_0001.JPG',
      captureDate: '20261011T100000',
    );
    expect(item.captureDate, '20261011T100000');
    expect(item.captureDateDisplay, '2026.10.11 10:00');
  });
}
