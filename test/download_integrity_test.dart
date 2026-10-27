import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/protocol/camera_driver.dart';

/// 可编程的假驱动：用于验证分块下载的续传与完整性契约。
class FakeDriver implements CameraDriver {
  FakeDriver({required this.payload, this.failFromOffset});

  final Uint8List payload;

  /// 当 offset >= 该值时返回空块（模拟相机丢包/断开）。
  int? failFromOffset;

  @override
  CameraConnectionState state = CameraConnectionState.connected;
  @override
  bool get isConnected => state == CameraConnectionState.connected;
  @override
  String get cameraModel => 'FAKE';
  @override
  int get batteryLevel => 100;
  @override
  bool get isSingleSlotCamera => false;
  @override
  List<int> get availableStorageIds => const [1];
  @override
  Stream<CameraConnectionState> get connectionStateStream =>
      const Stream.empty();
  @override
  Stream<CameraFileItem> get onPhotoCaptured => const Stream.empty();

  @override
  Future<void> connect(String host,
      {int port = 15740, void Function(String msg)? onLog}) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<List<int>> listStorageIds() async => const [1];
  @override
  Future<CameraExposureParams> fetchExposureParams() async =>
      const CameraExposureParams();
  @override
  Future<List<int>> listObjectHandles([int? storageId]) async => const [];
  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async => null;
  @override
  Future<Uint8List> getThumbnail(int handle) async => Uint8List(0);
  @override
  Future<bool> deleteObject(int handle) async => true;

  @override
  Future<Uint8List> downloadPartialObject(
      int handle, int offset, int maxBytes) async {
    if (failFromOffset != null && offset >= failFromOffset!)
      return Uint8List(0);
    final end = (offset + maxBytes).clamp(0, payload.length);
    return Uint8List.sublistView(payload, offset, end);
  }

  @override
  Future<Uint8List> downloadFullObject(
    int handle,
    int totalSize, {
    Function(int current, int total)? onProgress,
  }) async {
    final builder = BytesBuilder();
    var offset = 0;
    while (offset < totalSize) {
      final chunk =
          await downloadPartialObject(handle, offset, 4 * 1024 * 1024);
      if (chunk.isEmpty) {
        throw StateError('不完整：$offset / $totalSize');
      }
      builder.add(chunk);
      offset += chunk.length;
      onProgress?.call(offset, totalSize);
    }
    final bytes = builder.toBytes();
    if (bytes.length != totalSize) {
      throw StateError('不完整：${bytes.length} / $totalSize');
    }
    return bytes;
  }
}

void main() {
  test('分块下载在整段成功时返回完整字节', () async {
    final payload =
        Uint8List.fromList(List.generate(10 * 1024 * 1024, (i) => i & 0xFF));
    final driver = FakeDriver(payload: payload);
    final bytes = await driver.downloadFullObject(1, payload.length);
    expect(bytes.length, equals(payload.length));
  });

  test('中途空块必须抛错，绝不返回残缺数据', () async {
    final payload = Uint8List(8 * 1024 * 1024);
    final driver =
        FakeDriver(payload: payload, failFromOffset: 4 * 1024 * 1024);
    await expectLater(
      driver.downloadFullObject(1, payload.length),
      throwsA(isA<StateError>()),
    );
  });

  test('empty 数据块触发失败（续传契约）后可从偏移继续', () async {
    final payload = Uint8List.fromList(
        List.generate(6 * 1024 * 1024, (i) => (i * 31) & 0xFF));
    final driver =
        FakeDriver(payload: payload, failFromOffset: 4 * 1024 * 1024);
    await expectLater(
        driver.downloadFullObject(1, payload.length), throwsStateError);

    // 相机恢复后从 4MB 处继续，拼出的字节应与原始 payload 一致
    driver.failFromOffset = null;
    final tail =
        await driver.downloadPartialObject(1, 4 * 1024 * 1024, 4 * 1024 * 1024);
    final merged = Uint8List.fromList(
      Uint8List.sublistView(payload, 0, 4 * 1024 * 1024) + tail,
    );
    expect(merged.length, equals(payload.length));
    expect(merged, equals(payload));
  });

  test('导出诊断能识别 JPEG 是否带 EXIF 拍摄参数', () {
    // JPEG SOI + APP1 "Exif\0\0" 头部（相机原图）
    final withExif = <int>[
      0xFF,
      0xD8,
      0xFF,
      0xE1,
      0x00,
      0x10,
      0x45,
      0x78,
      0x69,
      0x66,
      0x00,
      0x00,
      0x4D,
      0x4D
    ];
    expect(bytesContainExifMarker(withExif), isTrue);

    // 纯 JFIF 缩略图 / 重新编码后丢元数据的 JPEG
    final withoutExif = <int>[
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01
    ];
    expect(bytesContainExifMarker(withoutExif), isFalse);

    expect(bytesContainExifMarker(const <int>[]), isFalse);
  });
}
