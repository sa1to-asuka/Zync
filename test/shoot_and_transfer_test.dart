import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/shoot_and_transfer.dart';
import 'package:zync/protocol/camera_driver.dart';

import 'helpers/fake_capture_driver.dart';

CameraFileItem _jpeg([int handle = 201]) => CameraFileItem(
      handle: handle,
      storageId: 0x00010001,
      format: 0x3801,
      size: 4096,
      fileName: 'DSC_$handle.JPG',
      captureDate: '20261108T120000',
    );

CameraFileItem _nef([int handle = 202]) => CameraFileItem(
      handle: handle,
      storageId: 0x00010001,
      format: 0xB101,
      size: 24000000,
      fileName: 'DSC_$handle.NEF',
      captureDate: '20261108T120000',
    );

void main() {
  late FakeCaptureDriver driver;
  late DownloadManager downloads;
  late ShootAndTransferController controller;

  setUp(() {
    AppSettings.instance.resetForTest();
    driver = FakeCaptureDriver();
    downloads = DownloadManager(driver: driver);
    controller = ShootAndTransferController(
      driver: driver,
      downloadManager: downloads,
    );
  });

  tearDown(() {
    controller.dispose();
    driver.dispose();
  });

  test('默认关闭：应用内快门拍到的文件不会回传', () {
    expect(controller.isEnabled, isFalse);

    controller.handleCaptured(_jpeg());

    expect(downloads.tasks, isEmpty);
  });

  test('打开后：应用内快门拍到的文件会入队', () {
    controller.setEnabled(true);

    controller.handleCaptured(_jpeg());

    expect(downloads.tasks, hasLength(1));
    expect(downloads.tasks.single.fileItem.fileName, 'DSC_201.JPG');
  });

  test('未勾选 RAW 时跳过 NEF，勾选后放行', () {
    controller.setEnabled(true);

    controller.handleCaptured(_nef());
    expect(downloads.tasks, isEmpty);

    AppSettings.instance.setDownloadRaw(true);
    controller.handleCaptured(_nef());
    expect(downloads.tasks, hasLength(1));
  });

  test('设置页开关与控制器是同一个状态', () {
    expect(controller.isEnabled, isFalse);

    AppSettings.instance.setShootAndTransferEnabled(true);
    expect(controller.isEnabled, isTrue);

    AppSettings.instance.setShootAndTransferEnabled(false);
    expect(controller.isEnabled, isFalse);
  });

  test('开关状态会持久化到设置对象', () {
    controller.toggle();
    expect(AppSettings.instance.shootAndTransferEnabled, isTrue);

    controller.toggle();
    expect(AppSettings.instance.shootAndTransferEnabled, isFalse);
  });

  test('相机事件路径同样遵守开关', () async {
    controller.handleCaptured(_jpeg(1));
    expect(downloads.tasks, isEmpty);

    controller.setEnabled(true);
    driver.emitCaptured(_jpeg(2));
    await Future<void>.delayed(Duration.zero);

    expect(downloads.tasks, hasLength(1));
    expect(downloads.tasks.single.fileItem.handle, 2);
  });
}
