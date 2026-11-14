import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../protocol/camera_driver.dart';

/// 队列项状态。
///
/// 与 UI 层的 `DownloadTaskStatus` 分开：这里要能表达「等重连」这种
/// 只在重启后才有意义的中间态，且必须是 JSON 里的稳定字符串。
enum DownloadQueueStatus {
  queued,
  downloading,
  pausedWaitingReconnect,
  failed,
  completed,
  canceled,
}

DownloadQueueStatus downloadQueueStatusFromName(String? name) {
  for (final s in DownloadQueueStatus.values) {
    if (s.name == name) return s;
  }
  return DownloadQueueStatus.queued;
}

/// 可落盘的下载任务快照。
class DownloadQueueEntry {
  const DownloadQueueEntry({
    required this.id,
    required this.storageId,
    required this.handle,
    required this.fileName,
    required this.captureDate,
    required this.sizeBytes,
    required this.isRaw,
    required this.isVideo,
    required this.tempPartPath,
    required this.targetPath,
    required this.bytesTransferred,
    required this.status,
    this.batchGroupId,
    this.lastError,
  });

  final String id;
  final int storageId;
  final int handle;
  final String fileName;
  final String captureDate;
  final int sizeBytes;
  final bool isRaw;
  final bool isVideo;
  final String tempPartPath;
  final String targetPath;
  final int bytesTransferred;
  final DownloadQueueStatus status;

  /// 同一批包围曝光 / 录像回传的任务共享一个分组，UI 按组折叠。
  final String? batchGroupId;
  final String? lastError;

  DownloadQueueEntry copyWith({
    int? handle,
    int? bytesTransferred,
    DownloadQueueStatus? status,
    String? lastError,
    String? tempPartPath,
  }) {
    return DownloadQueueEntry(
      id: id,
      storageId: storageId,
      handle: handle ?? this.handle,
      fileName: fileName,
      captureDate: captureDate,
      sizeBytes: sizeBytes,
      isRaw: isRaw,
      isVideo: isVideo,
      tempPartPath: tempPartPath ?? this.tempPartPath,
      targetPath: targetPath,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      status: status ?? this.status,
      batchGroupId: batchGroupId,
      lastError: lastError,
    );
  }

  static String buildId({
    required int storageId,
    required String fileName,
    required String captureDate,
  }) =>
      '$storageId|$fileName|$captureDate';

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'storageId': storageId,
        'handle': handle,
        'fileName': fileName,
        'captureDate': captureDate,
        'sizeBytes': sizeBytes,
        'isRaw': isRaw,
        'isVideo': isVideo,
        'tempPartPath': tempPartPath,
        'targetPath': targetPath,
        'bytesTransferred': bytesTransferred,
        'status': status.name,
        if (batchGroupId != null) 'batchGroupId': batchGroupId,
        if (lastError != null) 'lastError': lastError,
      };

  static DownloadQueueEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final fileName = raw['fileName']?.toString() ?? '';
    if (fileName.isEmpty) return null;
    return DownloadQueueEntry(
      id: raw['id']?.toString() ??
          buildId(
            storageId: _asInt(raw['storageId']),
            fileName: fileName,
            captureDate: raw['captureDate']?.toString() ?? '',
          ),
      storageId: _asInt(raw['storageId']),
      handle: _asInt(raw['handle']),
      fileName: fileName,
      captureDate: raw['captureDate']?.toString() ?? '',
      sizeBytes: _asInt(raw['sizeBytes']),
      isRaw: raw['isRaw'] == true,
      isVideo: raw['isVideo'] == true,
      tempPartPath: raw['tempPartPath']?.toString() ?? '',
      targetPath: raw['targetPath']?.toString() ?? '',
      bytesTransferred: _asInt(raw['bytesTransferred']),
      status: downloadQueueStatusFromName(raw['status']?.toString()),
      batchGroupId: raw['batchGroupId']?.toString(),
      lastError: raw['lastError']?.toString(),
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// 冷启动 / 重连后按磁盘上 `.part` 的真实长度校正已传字节数。
///
/// 规则（来自 airnef 的边界策略）：
/// - 文件不存在 → 归零，等待重下
/// - `0 <= 实际长度 <= 总大小` → 以实际长度为准，从缺口处续传
/// - `实际长度 > 总大小` → `.part` 已损坏，归零并删掉它
DownloadQueueEntry reconcilePartWithDisk(
  DownloadQueueEntry entry,
  int? actualLength, {
  required bool isConnected,
}) {
  final status = entry.status;
  if (status == DownloadQueueStatus.completed ||
      status == DownloadQueueStatus.canceled) {
    return entry;
  }

  if (actualLength == null || actualLength < 0) {
    return entry.copyWith(
      bytesTransferred: 0,
      status: isConnected
          ? DownloadQueueStatus.queued
          : DownloadQueueStatus.pausedWaitingReconnect,
    );
  }

  if (entry.sizeBytes > 0 && actualLength > entry.sizeBytes) {
    return entry.copyWith(
      bytesTransferred: 0,
      status: isConnected
          ? DownloadQueueStatus.queued
          : DownloadQueueStatus.pausedWaitingReconnect,
      lastError: '临时文件长度超出预期，已重置',
    );
  }

  final clamped = entry.sizeBytes > 0
      ? actualLength.clamp(0, entry.sizeBytes)
      : actualLength;
  return entry.copyWith(
    bytesTransferred: clamped,
    status: isConnected
        ? DownloadQueueStatus.queued
        : DownloadQueueStatus.pausedWaitingReconnect,
  );
}

/// 重连后把队列项重新绑到相机端的 ObjectHandle。
///
/// 重连会换掉整个 PTP 会话，同一张照片的 handle 可能变化，
/// 因此按 `storageId + fileName + size` 精确匹配，再用拍摄时间消歧。
/// 匹配不唯一或找不到时返回 `null` —— 让调用方标记为「相机端已移除」，
/// 绝不能猜一个 handle 去下载，那会写出一张完全无关的照片。
int? matchHandleFor(
  DownloadQueueEntry entry,
  Iterable<CameraFileItem> candidates,
) {
  int? best;
  var bestScore = -1;
  var ambiguous = false;

  for (final c in candidates) {
    if (c.fileName != entry.fileName) continue;

    // 大小已知但完全对不上，就不是同一个文件：.part 的字节偏移量会错位，
    // 强行续传只会拼出一个坏文件。
    if (entry.sizeBytes > 0 && c.size != entry.sizeBytes) continue;

    var score = 1;
    if (c.size == entry.sizeBytes) score += 4;
    if (c.storageId == entry.storageId) score += 2;
    if (entry.captureDate.isNotEmpty && c.captureDate == entry.captureDate) {
      score += 4;
    }

    if (score > bestScore) {
      bestScore = score;
      best = c.handle;
      ambiguous = false;
    } else if (score == bestScore) {
      ambiguous = true;
    }
  }

  if (ambiguous || bestScore < 3) return null;
  return best;
}

/// 队列持久化：先写 `.tmp` 再 `rename`，断电也不会留半个 JSON。
class DownloadQueueStore {
  DownloadQueueStore({
    required Directory directory,
    this.debounce = const Duration(milliseconds: 250),
  }) : _directory = directory;

  final Directory _directory;
  final Duration debounce;

  static const int schemaVersion = 1;
  static const String fileName = 'download_queue.v1.json';

  File get file => File('${_directory.path}/$fileName');
  File get _tempFile => File('${_directory.path}/$fileName.tmp');

  Timer? _debounceTimer;
  List<DownloadQueueEntry>? _pending;
  Future<void>? _inFlight;

  /// 读取历史队列。文件不存在或内容损坏时返回空列表，不抛异常。
  Future<List<DownloadQueueEntry>> load() async {
    try {
      if (!await file.exists()) return const <DownloadQueueEntry>[];
      final text = await file.readAsString();
      if (text.trim().isEmpty) return const <DownloadQueueEntry>[];
      final decoded = jsonDecode(text);
      if (decoded is! Map) return const <DownloadQueueEntry>[];
      final version = DownloadQueueEntry._asInt(decoded['version']);
      if (version > schemaVersion) return const <DownloadQueueEntry>[];
      final items = decoded['items'];
      if (items is! List) return const <DownloadQueueEntry>[];
      return items
          .map(DownloadQueueEntry.fromJson)
          .whereType<DownloadQueueEntry>()
          .toList(growable: false);
    } catch (_) {
      return const <DownloadQueueEntry>[];
    }
  }

  /// 立即写入（用于 App 退到后台 / 页面关闭）。
  Future<void> save(List<DownloadQueueEntry> entries) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    return _write(entries);
  }

  /// 防抖写入：队列状态变化很频繁，250ms 内的多次调用只落一次盘。
  void scheduleSave(List<DownloadQueueEntry> entries) {
    _pending = List<DownloadQueueEntry>.of(entries);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      _debounceTimer = null;
      final snapshot = _pending;
      _pending = null;
      if (snapshot != null) unawaited(_write(snapshot));
    });
  }

  /// 等待在途写入与防抖中的快照全部落盘。
  Future<void> flush() async {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
      _debounceTimer = null;
      final snapshot = _pending;
      _pending = null;
      if (snapshot != null) await _write(snapshot);
    }
    await _inFlight;
  }

  Future<void> _write(List<DownloadQueueEntry> entries) {
    final previous = _inFlight ?? Future<void>.value();
    final next = previous.then((_) async {
      try {
        if (!await _directory.exists()) {
          await _directory.create(recursive: true);
        }
        final payload = jsonEncode(<String, Object?>{
          'version': schemaVersion,
          'savedAt': DateTime.now().toIso8601String(),
          'items': entries.map((e) => e.toJson()).toList(),
        });
        await _tempFile.writeAsString(payload, flush: true);
        if (await file.exists()) await file.delete();
        await _tempFile.rename(file.path);
      } catch (_) {
        // 队列落盘失败不应影响正在进行的传输。
      }
    });
    _inFlight = next;
    return next;
  }

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
