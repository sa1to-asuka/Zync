import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/protocol/camera_driver.dart';

class MockCameraDriver implements CameraDriver {
  @override
  CameraConnectionState state = CameraConnectionState.connected;

  @override
  bool isConnected = true;

  @override
  String cameraModel = 'NIKON Z 8';

  @override
  int batteryLevel = 80;

  @override
  bool isSingleSlotCamera = false;

  @override
  List<int> availableStorageIds = const [0x00010001, 0x00020001];

  @override
  Stream<CameraConnectionState> get connectionStateStream =>
      Stream.value(state);

  @override
  Future<List<int>> listStorageIds() async => availableStorageIds;

  final _photoStreamController = StreamController<CameraFileItem>.broadcast();

  @override
  Future<void> connect(String host,
      {int port = 15740, void Function(String msg)? onLog}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<CameraExposureParams> fetchExposureParams() async =>
      const CameraExposureParams(
        aperture: 'f/2.8',
        shutterSpeed: '1/250s',
        iso: 'ISO 400',
        exposureComp: '±0.0 EV',
        programMode: 'M',
        focalLength: '50mm',
        lensInfo: '24-70mm',
        batteryLevel: 80,
      );

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async =>
      [0x10001, 0x10002];

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async => CameraFileItem(
        handle: handle,
        storageId: 0x00010001,
        format: 0x3801,
        size: 5000000,
        fileName: 'DSC_0001.JPG',
        captureDate: '20261006T110000',
      );

  @override
  Future<Uint8List> getThumbnail(int handle) async => Uint8List(100);

  @override
  Future<bool> deleteObject(int handle) async => true;

  @override
  Future<Uint8List> downloadPartialObject(
          int handle, int offset, int maxBytes) async =>
      Uint8List(maxBytes);

  @override
  Future<Uint8List> downloadFullObject(int handle, int totalSize,
      {Function(int current, int total)? onProgress}) async {
    onProgress?.call(totalSize, totalSize);
    return Uint8List(totalSize);
  }

  @override
  Stream<CameraFileItem> get onPhotoCaptured => _photoStreamController.stream;
}

void main() {
  group('低电量保护状态机与传输队列', () {
    test('手动暂停与省电暂停独立性测试', () {
      final mock = MockCameraDriver();
      final dm = DownloadManager(driver: mock);

      expect(dm.isManualPaused, isFalse);
      expect(dm.isPowerPaused, isFalse);
      expect(dm.isPaused, isFalse);

      dm.setManualPaused(true);
      expect(dm.isManualPaused, isTrue);
      expect(dm.isPaused, isTrue);

      dm.setManualPaused(false);
      expect(dm.isManualPaused, isFalse);
      expect(dm.isPaused, isFalse);
    });

    test('任务入队与队列计数统计', () {
      final mock = MockCameraDriver();
      final dm = DownloadManager(driver: mock);

      final file1 = CameraFileItem(
        handle: 101,
        storageId: 1,
        format: 0x3801,
        size: 1000,
        fileName: 'DSC_0001.JPG',
        captureDate: '',
      );
      final file2 = CameraFileItem(
        handle: 102,
        storageId: 1,
        format: 0x3801,
        size: 2000,
        fileName: 'DSC_0002.JPG',
        captureDate: '',
      );

      dm.enqueue(file1);
      dm.enqueue(file2);

      expect(dm.totalCount, equals(2));
    });
  });
}
