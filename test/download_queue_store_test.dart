import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/download_queue_store.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/nikon_driver.dart';

DownloadQueueEntry _entry({
  String fileName = 'DSC_0001.JPG',
  int storageId = 0x00010001,
  int handle = 42,
  int size = 4096,
  int transferred = 0,
  String captureDate = '20261108T120000',
  DownloadQueueStatus status = DownloadQueueStatus.queued,
}) =>
    DownloadQueueEntry(
      id: DownloadQueueEntry.buildId(
        storageId: storageId,
        fileName: fileName,
        captureDate: captureDate,
      ),
      storageId: storageId,
      handle: handle,
      fileName: fileName,
      captureDate: captureDate,
      sizeBytes: size,
      isRaw: false,
      isVideo: false,
      tempPartPath: '',
      targetPath: '',
      bytesTransferred: transferred,
      status: status,
    );

CameraFileItem _item({
  int handle = 42,
  int storageId = 0x00010001,
  int size = 4096,
  String fileName = 'DSC_0001.JPG',
  String captureDate = '20261108T120000',
}) =>
    CameraFileItem(
      handle: handle,
      storageId: storageId,
      format: 0x3801,
      size: size,
      fileName: fileName,
      captureDate: captureDate,
    );

void main() {
  group('落盘与读取', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('zync_queue_');
    });
    tearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('写入后能原样读回', () async {
      final store = DownloadQueueStore(directory: dir);
      final entries = [
        _entry(transferred: 2048),
        _entry(fileName: 'DSC_0002.NEF', handle: 43, size: 24000000),
      ];

      await store.save(entries);
      final loaded = await DownloadQueueStore(directory: dir).load();

      expect(loaded, hasLength(2));
      expect(loaded[0].fileName, 'DSC_0001.JPG');
      expect(loaded[0].bytesTransferred, 2048);
      expect(loaded[1].fileName, 'DSC_0002.NEF');
      expect(await store.file.exists(), isTrue);
      expect(await File('${store.file.path}.tmp').exists(), isFalse,
          reason: '临时文件必须 rename 掉，不能留在磁盘上');
    });

    test('文件不存在或损坏时返回空列表而不是抛异常', () async {
      final store = DownloadQueueStore(directory: dir);
      expect(await store.load(), isEmpty);

      await store.file.writeAsString('{ 这不是 JSON');
      expect(await store.load(), isEmpty);
    });

    test('防抖写入：连续调度只落一次盘', () async {
      final store = DownloadQueueStore(
        directory: dir,
        debounce: const Duration(milliseconds: 10),
      );
      store.scheduleSave([_entry(transferred: 1)]);
      store.scheduleSave([_entry(transferred: 2)]);
      store.scheduleSave([_entry(transferred: 3)]);
      await store.flush();

      final loaded = await store.load();
      expect(loaded.single.bytesTransferred, 3);
    });
  });

  group('冷启动按 .part 校正进度', () {
    test('文件不存在时归零', () {
      final result = reconcilePartWithDisk(
        _entry(transferred: 999),
        null,
        isConnected: false,
      );
      expect(result.bytesTransferred, 0);
      expect(result.status, DownloadQueueStatus.pausedWaitingReconnect);
    });

    test('磁盘长度是唯一可信进度', () {
      final result = reconcilePartWithDisk(
        _entry(transferred: 999999, size: 4096),
        2048,
        isConnected: true,
      );
      expect(result.bytesTransferred, 2048);
      expect(result.status, DownloadQueueStatus.queued);
    });

    test('超出总大小的 .part 判定损坏并清零', () {
      final result = reconcilePartWithDisk(
        _entry(size: 4096),
        9000,
        isConnected: true,
      );
      expect(result.bytesTransferred, 0);
      expect(result.status, DownloadQueueStatus.queued);
      expect(result.lastError, isNotNull);
    });

    test('已完成的任务不参与校正', () {
      final entry = _entry(status: DownloadQueueStatus.completed);
      expect(
        reconcilePartWithDisk(entry, 10, isConnected: false).status,
        DownloadQueueStatus.completed,
      );
    });
  });

  group('重连后句柄重映射', () {
    test('按文件名 + 大小 + 存储卷精确匹配到新 handle', () {
      final handle = matchHandleFor(
        _entry(handle: 1),
        [
          _item(handle: 77),
          _item(handle: 88, fileName: 'DSC_9999.JPG'),
        ],
      );
      expect(handle, 77);
    });

    test('同名但大小完全不符时不匹配', () {
      final handle = matchHandleFor(
        _entry(size: 4096),
        [_item(handle: 5, size: 8 * 1024 * 1024)],
      );
      expect(handle, isNull);
    });

    test('存在两张同样匹配时宁可不匹配', () {
      final handle = matchHandleFor(
        _entry(),
        [_item(handle: 5), _item(handle: 6)],
      );
      expect(handle, isNull, reason: '猜一个 handle 会下载到完全无关的照片');
    });

    test('找不到同名文件时返回 null', () {
      expect(matchHandleFor(_entry(), const []), isNull);
    });
  });

  group('≥4GiB 分块边界', () {
    test('4GiB 以内仍用 32 位指令', () {
      expect(requiresPartialObject64(0, 512 * 1024), isFalse);
      expect(requiresPartialObject64(0xFFFFFFFF - 100, 100), isFalse);
    });

    test('跨过 4GiB 边界改用 0x9431', () {
      expect(requiresPartialObject64(0xFFFFFFFF - 10, 512 * 1024), isTrue);
      expect(requiresPartialObject64(0x100000000, 512 * 1024), isTrue);
      expect(requiresPartialObject64(8 * 1024 * 1024 * 1024, 1024), isTrue);
    });
  });
}
