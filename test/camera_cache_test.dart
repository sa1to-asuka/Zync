import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/camera_viewed_tracker.dart';
import 'package:zync/protocol/camera_driver.dart';

void main() {
  test('CameraFileItem JSON 往返 (相册列表持久缓存与增量加载基础)', () {
    final item = CameraFileItem(
      handle: 0x12345678,
      storageId: 0x00010001,
      format: 0x3000,
      size: 5 * 1024 * 1024,
      fileName: 'DSC_0100.MP4',
      captureDate: '2026:10:07 15:41:00',
    );

    final restored = CameraFileItem.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(item.toJson())) as Map),
    );

    expect(restored.handle, equals(item.handle));
    expect(restored.storageId, equals(item.storageId));
    expect(restored.format, equals(item.format));
    expect(restored.size, equals(item.size));
    expect(restored.fileName, equals(item.fileName));
    expect(restored.captureDate, equals(item.captureDate));
    expect(restored.isVideo, isTrue, reason: 'MP4 必须被识别为视频');
    expect(restored.sizeFormatted, equals('5.0 MB'));
  });

  test('竖拍照片宽高判定与 JSON 往返 (相册竖屏识别基础)', () {
    // Z 系列竖拍：6000x4000 传感器，EXIF 旋转后为 4000x6000
    final portrait = CameraFileItem(
      handle: 1,
      storageId: 1,
      format: 0x3801,
      size: 8 * 1024 * 1024,
      fileName: 'DSC_0001.JPG',
      captureDate: '2026:10:09 10:00:00',
      pixelWidth: 4000,
      pixelHeight: 6000,
    );
    expect(portrait.isPortrait, isTrue, reason: '高 > 宽必须判定为竖拍');

    final landscape = CameraFileItem(
      handle: 2,
      storageId: 1,
      format: 0x3801,
      size: 8 * 1024 * 1024,
      fileName: 'DSC_0002.JPG',
      captureDate: '2026:10:09 10:01:00',
      pixelWidth: 6000,
      pixelHeight: 4000,
    );
    expect(landscape.isPortrait, isFalse, reason: '宽 > 高必须判定为横拍');

    // 宽高未知 (0) 时不得误判为竖拍
    final unknown = CameraFileItem(
      handle: 3,
      storageId: 1,
      format: 0x3801,
      size: 8 * 1024 * 1024,
      fileName: 'DSC_0003.JPG',
      captureDate: '',
    );
    expect(unknown.isPortrait, isFalse, reason: '宽高未知时保守判定为横拍');

    final restored = CameraFileItem.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(portrait.toJson())) as Map),
    );
    expect(restored.pixelWidth, equals(4000));
    expect(restored.pixelHeight, equals(6000));
    expect(restored.isPortrait, isTrue, reason: '宽高必须随列表缓存一起持久化');
  });

  test('CameraViewedTracker 标记与防重复查看判定', () async {
    final tracker = CameraViewedTracker.instance;
    await tracker.clearViewed();

    expect(tracker.isViewed('DSC_0001'), isFalse);
    expect(tracker.isViewed('dsc_0001'), isFalse);

    await tracker.markViewed('DSC_0001');
    expect(tracker.isViewed('DSC_0001'), isTrue);
    expect(tracker.isViewed('dsc_0001'), isTrue, reason: '大小写不敏感');
    expect(tracker.isViewed('DSC_0002'), isFalse);

    await tracker.markAllViewed(['DSC_0002', 'DSC_0003']);
    expect(tracker.isViewed('DSC_0002'), isTrue);
    expect(tracker.isViewed('DSC_0003'), isTrue);
    expect(tracker.viewedBaseNames.length, equals(3));

    await tracker.clearViewed();
    expect(tracker.isViewed('DSC_0001'), isFalse);
    expect(tracker.viewedBaseNames.isEmpty, isTrue);
  });
}
