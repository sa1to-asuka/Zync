import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/utils/app_log_manager.dart';
import '../../core/utils/camera_error_mapper.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/camera_native_bridge.dart';
import 'download_queue_store.dart';
import 'export_history_manager.dart';
import 'keep_alive_arbiter.dart';

/// 单个下载任务状态
enum DownloadTaskStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled,

  /// 相机断线，等重连后自动续传。
  pausedWaitingReconnect,
}

/// 媒体下载任务项
class DownloadTask {
  CameraFileItem fileItem;
  DownloadTaskStatus status;
  int downloadedBytes;
  int totalBytes;
  double progress; // 0.0 ~ 1.0
  String? localPath;
  String? error;
  int retryCount;

  /// 临时 `.part` 文件的绝对路径（重连 / 重启后续传要靠它定位已下载字节）。
  String? partPath;

  /// 同一次包围曝光 / 录像回传的任务共享，UI 按批次分组。
  String? batchGroupId;

  DownloadTask({
    required this.fileItem,
    this.status = DownloadTaskStatus.queued,
    this.downloadedBytes = 0,
    required this.totalBytes,
    this.progress = 0.0,
    this.localPath,
    this.error,
    this.retryCount = 0,
    this.partPath,
    this.batchGroupId,
  });

  /// 跨会话稳定的身份：handle 会随重连变化，文件名 + 拍摄时间不会。
  String get id => DownloadQueueEntry.buildId(
        storageId: fileItem.storageId,
        fileName: fileItem.fileName,
        captureDate: fileItem.captureDate,
      );

  bool get isPending =>
      status == DownloadTaskStatus.queued ||
      status == DownloadTaskStatus.downloading ||
      status == DownloadTaskStatus.pausedWaitingReconnect;
}

/// 传输保活状态：决定是否显示 / 如何显示前台服务通知。
enum TransferKeepAliveState { none, active, paused }

/// 检查前 128KB 是否含 JPEG 的 EXIF 标记（APP1 "Exif\0\0"），用于导出诊断日志。
bool bytesContainExifMarker(List<int> bytes) {
  const marker = <int>[0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
  final limit = bytes.length - marker.length;
  for (var i = 0; i <= limit; i++) {
    var matched = true;
    for (var j = 0; j < marker.length; j++) {
      if (bytes[i + j] != marker[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

/// 导出诊断：把原图是否带 EXIF 写进应用日志，便于定位「相册看不到拍摄参数」。
void logExportExifPresence(File file, String fileName) {
  try {
    final raf = file.openSync();
    try {
      final head = raf.readSync(128 * 1024);
      final hasExif = bytesContainExifMarker(head);
      AppLogManager.instance.add(
        '导出 $fileName：${file.lengthSync()} 字节，原图 EXIF=${hasExif ? "有" : "无"}',
      );
    } finally {
      raf.closeSync();
    }
  } catch (e) {
    AppLogManager.instance.add('导出 $fileName：EXIF 检查失败 $e');
  }
}

/// 由队列状态推导保活状态（纯函数，便于单测）：
/// 队列清空 → none；有未完成任务且暂停 → paused；否则 → active。
TransferKeepAliveState transferKeepAliveState({
  required int queued,
  required int downloading,
  required bool paused,
}) {
  if (queued == 0 && downloading == 0) return TransferKeepAliveState.none;
  return paused ? TransferKeepAliveState.paused : TransferKeepAliveState.active;
}

/// 4MB 分块流式媒体下载管理器
/// 低电量保护状态机 (Hysteresis +5%) 与指数退避重试策略
class DownloadManager extends ChangeNotifier {
  final CameraDriver driver;
  final List<DownloadTask> _tasks = [];
  bool _isProcessing = false;

  /// 队列持久化（可不接：单测与某些页面只需要内存队列）。
  DownloadQueueStore? _store;

  /// 当前正在执行的批次（包围曝光 / 焦点堆叠），用于给任务打组。
  String? _activeBatchId;

  // ----------------------------------------------------
  // 低电量保护状态机
  // ----------------------------------------------------
  // 低电量保护参数统一来自 AppSettings，避免设置页改了但传输不生效
  bool get _powerProtectionEnabled =>
      AppSettings.instance.powerProtectionEnabled;
  int get _lowPowerThreshold => AppSettings.instance.powerThreshold;
  bool _isPowerPaused = false;
  bool _isManualPaused = false;
  String _powerPauseReason = '';

  DownloadManager({required this.driver});

  // ----------------------------------------------------
  // 传输保活前台服务同步
  // ----------------------------------------------------
  // 进度回调非常频繁，通知最多每 500ms 刷新一次；状态切换（开始 / 暂停 / 结束）不节流。
  static const Duration _keepAliveThrottle = Duration(milliseconds: 500);
  static const String _keepAliveKey = 'transfer';
  DateTime _lastKeepAliveSync = DateTime.fromMillisecondsSinceEpoch(0);
  TransferKeepAliveState _keepAliveState = TransferKeepAliveState.none;

  /// 唯一同步点：所有队列变化都经由这里驱动保活仲裁，
  /// 因此「边拍边传」与手动批量下载都被自动覆盖，无需各自埋点。
  @override
  void notifyListeners() {
    _syncTransferKeepAlive();
    _store?.scheduleSave(_snapshotForStore());
    super.notifyListeners();
  }

  /// 只持久化「还会继续」的任务：已完成 / 已取消的重启后没有意义，
  /// 而且已经交给 MediaStore 的条目重新入队会生成重复副本。
  List<DownloadQueueEntry> _snapshotForStore() {
    return _tasks
        .where((t) =>
            t.status != DownloadTaskStatus.completed &&
            t.status != DownloadTaskStatus.canceled)
        .map(_toEntry)
        .toList(growable: false);
  }

  DownloadQueueEntry _toEntry(DownloadTask task) => DownloadQueueEntry(
        id: task.id,
        storageId: task.fileItem.storageId,
        handle: task.fileItem.handle,
        fileName: task.fileItem.fileName,
        captureDate: task.fileItem.captureDate,
        sizeBytes: task.totalBytes,
        isRaw: task.fileItem.isRaw,
        isVideo: task.fileItem.isVideo,
        tempPartPath: task.partPath ?? '',
        targetPath: task.localPath ?? '',
        bytesTransferred: task.downloadedBytes,
        status: _statusToQueue(task.status),
        batchGroupId: task.batchGroupId,
        lastError: task.error,
      );

  static DownloadQueueStatus _statusToQueue(DownloadTaskStatus s) {
    switch (s) {
      case DownloadTaskStatus.queued:
        return DownloadQueueStatus.queued;
      case DownloadTaskStatus.downloading:
        return DownloadQueueStatus.downloading;
      case DownloadTaskStatus.pausedWaitingReconnect:
        return DownloadQueueStatus.pausedWaitingReconnect;
      case DownloadTaskStatus.failed:
        return DownloadQueueStatus.failed;
      case DownloadTaskStatus.completed:
        return DownloadQueueStatus.completed;
      case DownloadTaskStatus.canceled:
        return DownloadQueueStatus.canceled;
    }
  }

  static DownloadTaskStatus _statusFromQueue(DownloadQueueStatus s) {
    switch (s) {
      case DownloadQueueStatus.queued:
        return DownloadTaskStatus.queued;
      case DownloadQueueStatus.downloading:
        return DownloadTaskStatus.queued;
      case DownloadQueueStatus.pausedWaitingReconnect:
        return DownloadTaskStatus.pausedWaitingReconnect;
      case DownloadQueueStatus.failed:
        return DownloadTaskStatus.failed;
      case DownloadQueueStatus.completed:
        return DownloadTaskStatus.completed;
      case DownloadQueueStatus.canceled:
        return DownloadTaskStatus.canceled;
    }
  }

  void _syncTransferKeepAlive() {
    final next = transferKeepAliveState(
      queued: queuedCount,
      downloading: activeCount,
      paused: isPaused,
    );
    final isTransition = next != _keepAliveState;
    if (!isTransition &&
        DateTime.now().difference(_lastKeepAliveSync) < _keepAliveThrottle) {
      return;
    }
    _lastKeepAliveSync = DateTime.now();
    final previous = _keepAliveState;
    _keepAliveState = next;

    final arbiter = KeepAliveArbiter.instance;
    if (next == TransferKeepAliveState.none) {
      if (previous != TransferKeepAliveState.none) {
        arbiter.release(_keepAliveKey);
      }
      return;
    }
    if (previous == TransferKeepAliveState.none) {
      final lang = L10n.current.localeName;
      arbiter.acquire(
        _keepAliveKey,
        title: EngineL10n.transferKeepAliveTitle(lang),
      );
    }
    arbiter.update(
      _keepAliveKey,
      completed: completedCount,
      total: _tasks.length,
      paused: next == TransferKeepAliveState.paused,
    );
  }

  /// 整体进度 0..1（传输入口的进度徽标用）。
  double get progress {
    if (_tasks.isEmpty) return 0;
    final done =
        _tasks.where((t) => t.status == DownloadTaskStatus.completed).length;
    return done / _tasks.length;
  }

  /// 未结束任务数（排队 + 下载中 + 等待重连 + 失败），用于入口徽标。
  int get pendingCount => _tasks
      .where((t) =>
          t.status == DownloadTaskStatus.queued ||
          t.status == DownloadTaskStatus.downloading ||
          t.status == DownloadTaskStatus.pausedWaitingReconnect ||
          t.status == DownloadTaskStatus.failed)
      .length;

  /// 等待重连续传的任务数。
  int get waitingReconnectCount => _tasks
      .where((t) => t.status == DownloadTaskStatus.pausedWaitingReconnect)
      .length;

  /// 设置了持久化后，启动时把上次没传完的队列接回来。
  ///
  /// `.part` 的真实长度是唯一可信的进度来源：App 被强杀时内存里的
  /// `downloadedBytes` 一定比磁盘上的字节多。
  Future<void> attachStore(DownloadQueueStore store) async {
    _store = store;
    final entries = await store.load();
    if (entries.isEmpty) return;

    final connected = driver.isConnected;
    for (final entry in entries) {
      if (_tasks.any((t) => t.id == entry.id)) continue;
      var actual = await _fileLength(entry.tempPartPath);
      final reconciled =
          reconcilePartWithDisk(entry, actual, isConnected: connected);
      if (actual != null &&
          entry.sizeBytes > 0 &&
          actual > entry.sizeBytes &&
          entry.tempPartPath.isNotEmpty) {
        // 长度超出预期的 .part 一定是坏的，留着会让续传写进一个错位的文件。
        try {
          await File(entry.tempPartPath).delete();
        } catch (_) {}
        actual = null;
      }

      final task = DownloadTask(
        fileItem: CameraFileItem(
          handle: entry.handle,
          storageId: entry.storageId,
          format: entry.isRaw ? 0xB101 : 0,
          size: entry.sizeBytes,
          fileName: entry.fileName,
          captureDate: entry.captureDate,
        ),
        totalBytes: entry.sizeBytes,
        downloadedBytes: reconciled.bytesTransferred,
        status: _statusFromQueue(reconciled.status),
        partPath: entry.tempPartPath.isEmpty ? null : entry.tempPartPath,
        batchGroupId: entry.batchGroupId,
        error: reconciled.lastError,
      );
      _tasks.add(task);
    }

    notifyListeners();
    if (connected && !isPaused) _processQueue();
  }

  /// 相机掉线：把还没传完的任务挂起，等重连后续传，而不是判失败。
  void pauseForReconnect() {
    var changed = false;
    for (final t in _tasks) {
      if (t.status == DownloadTaskStatus.queued ||
          t.status == DownloadTaskStatus.downloading) {
        t.status = DownloadTaskStatus.pausedWaitingReconnect;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// 重连成功：重新绑定 ObjectHandle，然后把队列跑起来。
  ///
  /// 重连会换掉整个 PTP 会话，旧 handle 可能指向别的文件，
  /// 因此必须先用 `listObjectHandles + getObjectInfo` 建索引再匹配。
  Future<void> resumeAfterReconnect() async {
    final waiting = _tasks
        .where((t) => t.status == DownloadTaskStatus.pausedWaitingReconnect)
        .toList(growable: false);
    if (waiting.isEmpty) {
      if (!isPaused) _processQueue();
      return;
    }
    if (!driver.isConnected) return;

    final byStorage = <int, List<CameraFileItem>>{};
    for (final storageId in waiting.map((t) => t.fileItem.storageId).toSet()) {
      byStorage[storageId] = await _indexStorage(storageId);
    }

    for (final task in waiting) {
      final entry = _toEntry(task);
      final candidates = byStorage[task.fileItem.storageId] ?? const [];
      final handle = matchHandleFor(entry, candidates);
      if (handle == null) {
        task.status = DownloadTaskStatus.failed;
        task.error = '重连后相机端已找不到该文件，可能已被删除或换卡';
        continue;
      }
      final renewed =
          candidates.firstWhere((c) => c.handle == handle);
      task.fileItem = renewed;
      task.totalBytes = renewed.size > 0 ? renewed.size : task.totalBytes;
      task.status = DownloadTaskStatus.queued;
      task.error = null;
      task.retryCount = 0;
    }

    notifyListeners();
    if (!isPaused) _processQueue();
  }

  /// 读取一个存储卷的对象索引。相机端对象可能上万，只取有需要的分组，
  /// 并限制上限避免重连后卡在一个巨大的列表上。
  Future<List<CameraFileItem>> _indexStorage(int storageId) async {
    const maxObjects = 4000;
    try {
      final handles = await driver.listObjectHandles(storageId);
      final result = <CameraFileItem>[];
      for (final h in handles.take(maxObjects)) {
        final info = await driver.getObjectInfo(h);
        if (info != null) result.add(info);
      }
      return result;
    } catch (_) {
      return const <CameraFileItem>[];
    }
  }

  Future<int?> _fileLength(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final f = File(path);
      if (!await f.exists()) return null;
      return await f.length();
    } catch (_) {
      return null;
    }
  }

  /// 给接下来入队的任务打批次标记（包围曝光 / 焦点堆叠 / 录像回传）。
  void beginBatch(String batchGroupId) {
    _activeBatchId = batchGroupId;
  }

  void endBatch() {
    _activeBatchId = null;
  }

  /// 单条取消：排队中或等待重连的任务（正在下载的会在当前分块结束后由队列自然处理）。
  bool cancelTask(DownloadTask task) {
    if (task.status != DownloadTaskStatus.queued &&
        task.status != DownloadTaskStatus.pausedWaitingReconnect) {
      return false;
    }
    task.status = DownloadTaskStatus.canceled;
    notifyListeners();
    return true;
  }

  /// 从列表移除终态任务（完成 / 失败 / 已取消）。
  bool removeTask(DownloadTask task) {
    if (task.status == DownloadTaskStatus.downloading ||
        task.status == DownloadTaskStatus.queued) {
      return false;
    }
    if (!_tasks.remove(task)) return false;
    notifyListeners();
    return true;
  }

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  DownloadTask? get currentTask => _tasks.cast<DownloadTask?>().firstWhere(
      (t) => t?.status == DownloadTaskStatus.downloading,
      orElse: () => null);
  int get activeCount =>
      _tasks.where((t) => t.status == DownloadTaskStatus.downloading).length;
  int get completedCount =>
      _tasks.where((t) => t.status == DownloadTaskStatus.completed).length;
  int get queuedCount =>
      _tasks.where((t) => t.status == DownloadTaskStatus.queued).length;
  int get failedCount =>
      _tasks.where((t) => t.status == DownloadTaskStatus.failed).length;
  int get totalCount => _tasks.length;

  bool get powerProtectionEnabled => _powerProtectionEnabled;
  int get lowPowerThreshold => _lowPowerThreshold;
  bool get isPowerPaused => _isPowerPaused;
  bool get isManualPaused => _isManualPaused;
  bool get isPaused => _isPowerPaused || _isManualPaused;
  String get powerPauseReason => _powerPauseReason;

  set powerProtectionEnabled(bool val) {
    AppSettings.instance.setPowerProtectionEnabled(val);
    checkPowerState();
    notifyListeners();
  }

  set lowPowerThreshold(int val) {
    AppSettings.instance.setPowerThreshold(val);
    checkPowerState();
    notifyListeners();
  }

  /// 手动暂停 / 继续传输 (与省电暂停独立维护，互不覆盖)
  void setManualPaused(bool paused) {
    if (_isManualPaused == paused) return;
    _isManualPaused = paused;
    notifyListeners();
    if (!isPaused) {
      _processQueue();
    }
  }

  void toggleManualPause() {
    setManualPaused(!_isManualPaused);
  }

  /// 评估相机与手机电源状态 (Hysteresis 迟滞逻辑)
  Future<void> checkPowerState() async {
    if (!driver.isConnected) {
      if (_isPowerPaused) {
        _isPowerPaused = false;
        _powerPauseReason = '';
        notifyListeners();
      }
      return;
    }

    if (!_powerProtectionEnabled) {
      if (_isPowerPaused) {
        _isPowerPaused = false;
        _powerPauseReason = '';
        notifyListeners();
        if (!_isManualPaused) _processQueue();
      }
      return;
    }

    try {
      final phonePower = await CameraNativeBridge.getDevicePowerInfo();
      final phoneLevel = (phonePower['level'] as num?)?.toInt() ?? 100;
      final isCharging = phonePower['isCharging'] as bool? ?? false;
      final isPowerSave = phonePower['isPowerSaveMode'] as bool? ?? false;
      final cameraLevel = driver.batteryLevel;
      final lang = L10n.current.localeName;

      String? pauseReason;
      if (isPowerSave) {
        pauseReason = EngineL10n.powerPausePowerSave(lang);
      } else if (!isCharging && phoneLevel <= _lowPowerThreshold) {
        pauseReason =
            EngineL10n.powerPausePhoneLow(lang, phoneLevel, _lowPowerThreshold);
      } else if (cameraLevel > 0 && cameraLevel <= _lowPowerThreshold) {
        pauseReason = EngineL10n.powerPauseCameraLow(
            lang, cameraLevel, _lowPowerThreshold);
      }

      if (pauseReason != null) {
        if (!_isPowerPaused || _powerPauseReason != pauseReason) {
          _isPowerPaused = true;
          _powerPauseReason = pauseReason;
          notifyListeners();
        }
      } else if (_isPowerPaused) {
        // 迟滞恢复判定: 必须达到 threshold + 5% (避免电量波动频繁启停)
        final resumeThreshold = _lowPowerThreshold + 5;
        final phoneOk = isCharging || phoneLevel > resumeThreshold;
        final cameraOk = cameraLevel <= 0 || cameraLevel > resumeThreshold;

        if (!isPowerSave && phoneOk && cameraOk) {
          _isPowerPaused = false;
          _powerPauseReason = '';
          notifyListeners();
          if (!_isManualPaused) {
            _processQueue();
          }
        }
      }
    } catch (_) {}
  }

  /// 添加下载任务并入队
  void enqueue(CameraFileItem file) {
    final id = DownloadQueueEntry.buildId(
      storageId: file.storageId,
      fileName: file.fileName,
      captureDate: file.captureDate,
    );
    if (_tasks.any((t) => t.id == id)) return; // 避免重复添加

    final task = DownloadTask(
      fileItem: file,
      totalBytes: file.size,
      batchGroupId: _activeBatchId,
    );
    _tasks.add(task);
    notifyListeners();
    checkPowerState();
    _processQueue();
  }

  /// 批量添加任务
  void enqueueAll(List<CameraFileItem> files) {
    for (final f in files) {
      final id = DownloadQueueEntry.buildId(
        storageId: f.storageId,
        fileName: f.fileName,
        captureDate: f.captureDate,
      );
      if (_tasks.any((t) => t.id == id)) continue;
      _tasks.add(DownloadTask(
        fileItem: f,
        totalBytes: f.size,
        batchGroupId: _activeBatchId,
      ));
    }
    notifyListeners();
    checkPowerState();
    _processQueue();
  }

  /// 失败重试单项任务（「等待重连」的任务也可以手动重试）。
  void retryTask(DownloadTask task) {
    if (task.status != DownloadTaskStatus.failed &&
        task.status != DownloadTaskStatus.pausedWaitingReconnect) {
      return;
    }
    task.status = DownloadTaskStatus.queued;
    task.error = null;
    task.retryCount = 0;
    task.progress = 0.0;
    notifyListeners();
    _processQueue();
  }

  /// 批量重试所有失败任务
  void retryAllFailed() {
    for (final t in _tasks) {
      if (t.status == DownloadTaskStatus.failed) {
        t.status = DownloadTaskStatus.queued;
        t.error = null;
        t.retryCount = 0;
        t.progress = 0.0;
      }
    }
    notifyListeners();
    _processQueue();
  }

  /// 取消所有等待中的任务
  void cancelAll() {
    for (final t in _tasks) {
      if (t.status == DownloadTaskStatus.queued) {
        t.status = DownloadTaskStatus.canceled;
      }
    }
    notifyListeners();
  }

  /// 应用私有临时下载目录（下载/续传都写这里，成功后再交给 MediaStore 保存到公共相册）
  Future<Directory> _getTempDir() async {
    Directory base;
    try {
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (_) {
      base = Directory.systemTemp;
    }
    final dir = Directory('${base.path}/zync_downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _partialFileFor(DownloadTask task) async {
    final dir = await _getTempDir();
    final safeName =
        task.fileItem.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${dir.path}/$safeName.part');
  }

  /// 分块流式下载到临时文件：失败/断开时保留已写部分，下次从 [downloadedBytes] 续传。
  /// 长度校验在 [_downloadToFile] 内完成，任何缺口都会抛错，绝不产出残缺文件。
  Future<void> _downloadToFile(
    DownloadTask task,
    File target, {
    required Function(int current, int total) onProgress,
  }) async {
    const chunkSize = 512 * 1024; // 512KB 分块（兼顾 Wi-Fi 高吞吐与进度条平滑实时流动）
    final sink = target.openWrite(mode: FileMode.append);
    var received = task.downloadedBytes;

    try {
      while (received < task.totalBytes) {
        if (!driver.isConnected || isPaused) {
          throw const CameraFailure(CameraFailureKind.transferInterrupted);
        }
        final requestBytes = (task.totalBytes - received > chunkSize)
            ? chunkSize
            : (task.totalBytes - received);

        // downloadPartialObject 内部已含 3 次重试，此处负责把缺失字节补上或抛错
        final chunk = await driver.downloadPartialObject(
            task.fileItem.handle, received, requestBytes);
        if (chunk.isEmpty) {
          throw CameraFailure(
            CameraFailureKind.emptyChunk,
            details: <String, Object?>{'offset': received},
          );
        }
        sink.add(chunk);
        received += chunk.length;
        task.downloadedBytes = received;
        task.progress = task.totalBytes > 0
            ? (received / task.totalBytes).clamp(0.0, 1.0)
            : 0.0;
        onProgress(received, task.totalBytes);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    final actual = await target.length();
    if (actual < task.totalBytes) {
      throw CameraFailure(
        CameraFailureKind.incomplete,
        details: <String, Object?>{
          'actual': actual,
          'total': task.totalBytes,
        },
      );
    }
  }

  /// 流式下载到应用私有临时目录，供视频编辑器等需要本地文件的场景使用。
  /// 不写入公共相册，不把大视频整段读进内存。
  ///
  /// [suffix] 用来区分「序列合成」这类旁路下载，避免和队列里同名的 `.part`
  /// 互相覆盖——队列会删掉已存在的临时文件再续传。
  Future<File?> downloadToTemp(
    CameraFileItem file, {
    void Function(double progress)? onProgress,
    String suffix = '',
  }) async {
    if (!driver.isConnected || file.size <= 0) return null;
    final task = DownloadTask(
      fileItem: file,
      totalBytes: file.size,
      status: DownloadTaskStatus.downloading,
    );
    final dir = await _getTempDir();
    final safeName =
        file.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final partial = File('${dir.path}/$safeName$suffix.part');
    try {
      if (await partial.exists()) await partial.delete();
      await _downloadToFile(
        task,
        partial,
        onProgress: (current, total) {
          if (total > 0) onProgress?.call((current / total).clamp(0.0, 1.0));
        },
      );
      final finalPath = partial.path.endsWith('.part')
          ? partial.path.substring(0, partial.path.length - 5)
          : '${partial.path}.media';
      final finalFile = File(finalPath);
      if (await finalFile.exists()) await finalFile.delete();
      await partial.rename(finalFile.path);
      return finalFile;
    } catch (_) {
      return null;
    }
  }

  /// 队列处理循环 (带有限退避重试、断点续传与低电量无缝暂停保护)
  Future<void> _processQueue() async {
    if (_isProcessing || !driver.isConnected) return;
    _isProcessing = true;

    // 退避延迟梯度 (秒): 2/5/10/30s
    const backoffDelays = [2, 5, 10, 30];

    while (true) {
      // 检查电源状态
      await checkPowerState();

      // 若处于手动暂停或低电量暂停，退出当前循环 (但绝不截断正在写入中的文件)
      if (isPaused || !driver.isConnected) {
        break;
      }

      final pendingTask = _tasks.firstWhere(
        (t) => t.status == DownloadTaskStatus.queued,
        orElse: () => DownloadTask(
          fileItem: CameraFileItem(
              handle: 0,
              storageId: 0,
              format: 0,
              size: 0,
              fileName: '',
              captureDate: ''),
          totalBytes: 0,
          status: DownloadTaskStatus.canceled,
        ),
      );

      if (pendingTask.status == DownloadTaskStatus.canceled ||
          !driver.isConnected) {
        break;
      }

      pendingTask.status = DownloadTaskStatus.downloading;
      notifyListeners();

      bool success = false;
      File? partial;
      while (pendingTask.retryCount <= 4 && !success) {
        try {
          partial ??= await _partialFileFor(pendingTask);
          pendingTask.partPath = partial.path;

          // 断点续传：沿用已写入的字节数，从缺口处继续
          final existing = await partial.exists() ? await partial.length() : 0;
          pendingTask.downloadedBytes = existing;
          pendingTask.progress = pendingTask.totalBytes > 0
              ? (existing / pendingTask.totalBytes).clamp(0.0, 1.0)
              : 0.0;

          await _downloadToFile(
            pendingTask,
            partial,
            onProgress: (current, total) {
              pendingTask.downloadedBytes = current;
              pendingTask.totalBytes = total;
              pendingTask.progress =
                  total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
              notifyListeners();
            },
          );

          // 导出前记录原图是否带 EXIF：手机相册的拍摄参数面板（焦距/ISO/快门/光圈）
          // 完全依赖文件里的 EXIF，日志里能直接看出是「文件没带」还是「相册没解析」。
          logExportExifPresence(partial, pendingTask.fileItem.fileName);

          // 交给 MediaStore 保存进系统公共相册；失败必须视为任务失败
          final saved = await CameraNativeBridge.saveMediaToGallery(
            partial.path,
            pendingTask.fileItem.fileName,
            subDir: AppSettings.instance.exportFolder,
          );
          if (saved == null || saved.isEmpty) {
            throw CameraFailure(
              CameraFailureKind.saveFailed,
              details: <String, Object?>{
                'fileName': pendingTask.fileItem.fileName,
              },
            );
          }

          final source = pendingTask.fileItem;
          try {
            await ExportHistoryManager().recordSource(
                ExportHistoryManager.sourceKey(source.storageId,
                    source.fileName, source.size, source.captureDate),
                saved);
          } catch (e) {
            // 公共相册已保存成功，索引失败不应重复下载或生成重复副本。
            AppLogManager.instance.add('已保存照片，但来源索引写入失败: $e');
          }
          ExportHistoryManager()
              .registerExported(source.fileName, partial, saved);

          pendingTask.localPath = saved;
          pendingTask.status = DownloadTaskStatus.completed;
          pendingTask.progress = 1.0;
          pendingTask.error = null;
          success = true;

          // 成功后清理临时分块文件
          try {
            if (await partial.exists()) await partial.delete();
          } catch (_) {}
        } catch (e) {
          if (pendingTask.retryCount < 4 && driver.isConnected && !isPaused) {
            final delaySec = backoffDelays[pendingTask.retryCount];
            pendingTask.retryCount++;
            pendingTask.error = EngineL10n.transferRetryNotice(
              L10n.current.localeName,
              delaySec,
              pendingTask.retryCount,
            );
            notifyListeners();
            await Future.delayed(Duration(seconds: delaySec));
          } else {
            if (!driver.isConnected) {
              // 掉线不是任务失败：保留 .part，重连后从这里继续。
              pendingTask.status = DownloadTaskStatus.pausedWaitingReconnect;
              pendingTask.error = '相机已断开，等待重连后续传';
            } else {
              pendingTask.status = DownloadTaskStatus.failed;
              pendingTask.error = CameraErrorMapper.describe(e, L10n.current);
            }
            break;
          }
        }
      }

      notifyListeners();
    }

    _isProcessing = false;
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == DownloadTaskStatus.completed);
    notifyListeners();
  }

  @override
  void dispose() {
    // 退出前把防抖中的队列快照落盘，否则刚入队的任务会丢。
    unawaited(_store?.flush());
    _store?.dispose();
    super.dispose();
  }
}
