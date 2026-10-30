import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/network_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/utils/exif_helper.dart';
import '../../core/utils/lru_image_cache.dart';
import '../../core/utils/raw_preview_extractor.dart';
import '../../engine/transfer/camera_viewed_tracker.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../engine/transfer/shoot_and_transfer.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/nikon_driver.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import 'collage_screen.dart';
import 'photo_editor_screen.dart';
import 'transfer_center_screen.dart';
import 'video_editor_screen.dart';

part 'gallery/camera_media_group.dart';
part 'gallery/exported_media_image.dart';
part 'gallery/full_screen_local_viewer.dart';
part 'gallery/full_screen_photo_viewer.dart';
part 'gallery/gallery_cards.dart';
part 'gallery/gallery_modals.dart';
part 'gallery/photo_fetch_helpers.dart';
part 'gallery/zoomable_photo.dart';

class GalleryScreen extends StatefulWidget {
  final CameraDriver driver;
  final DownloadManager downloadManager;
  final ShootAndTransferController shootAndTransferController;
  final Function(
    CameraFileItem item,
    Uint8List? imageBytes, {
    bool openFilter,
    String? rawPath,
  })? onOpenWatermark;

  const GalleryScreen({
    super.key,
    required this.driver,
    required this.downloadManager,
    required this.shootAndTransferController,
    this.onOpenWatermark,
  });

  @override
  State<GalleryScreen> createState() => GalleryScreenState();
}

class GalleryScreenState extends State<GalleryScreen> {
  /// 合并后的相机媒体组列表
  List<CameraMediaGroup> _groups = [];

  /// 已选中的媒体组 baseName 集合
  final Set<String> _selectedBaseNames = {};
  bool _isLoading = false;
  bool _isSelectionMode = false;

  /// 本地「已导出」相册多选状态
  final Set<String> _selectedLocalFileNames = {};
  bool _isLocalSelectionMode = false;

  /// 系统返回拦截使用：当前相册是否处于多选模式。
  bool get hasActiveSelection => _isSelectionMode || _isLocalSelectionMode;

  /// 退出多选并清空勾选（相机相册与本地已导出相册一并处理）。
  void clearSelection() {
    if (!hasActiveSelection) return;
    setState(() {
      _isSelectionMode = false;
      _selectedBaseNames.clear();
      _isLocalSelectionMode = false;
      _selectedLocalFileNames.clear();
    });
  }

  /// 长按滑动多选状态
  final GlobalKey _cameraGridKey = GlobalKey();
  final GlobalKey _historyGridKey = GlobalKey();
  final ScrollController _historyScrollController = ScrollController();
  int? _dragStartIndex;
  bool _dragMoved = false;
  Set<int> _dragSnapshot = {};

  /// 当前选中的存储卡槽 ID (null 表示全部存储自动合并)
  int? _selectedStorageId;

  /// 当前激活的快捷筛选标签
  late _GalleryFilter _activeFilter;

  /// 顶部子视图切换: 0 = 相机照片, 1 = 历史导出 (手机相册)
  int _activeTab = 0;

  /// 历史导出管理器
  final ExportHistoryManager _historyManager = ExportHistoryManager();

  /// 缩略图与原图 LRU 缓存（容量 500 / 12）
  final LruImageCache _thumbCache = LruImageCache(maxEntries: 500);
  final LruImageCache _fullCache = LruImageCache(maxEntries: 12);

  /// 同一文件的缩略图 Future 去重表
  final Map<String, Future<Uint8List>> _thumbFutures = {};

  /// 相机会话代数：断线时自增，防止在途请求把旧 handle 的数据写回缓存。
  int _cacheEpoch = 0;

  /// 列表滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 后台预取让路开关
  bool _backgroundPrefetchHold = false;

  StreamSubscription<CameraConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    final savedFilter = AppSettings.instance.galleryFilter;
    _activeFilter = _GalleryFilter.values.firstWhere(
      (f) => f.name == savedFilter,
      orElse: () => _GalleryFilter.unviewed,
    );
    unawaited(CameraViewedTracker.instance.ensureInitialized());
    CameraViewedTracker.instance.addListener(_onHistoryChanged);

    _historyManager.refresh();
    _historyManager.addListener(_onHistoryChanged);

    if (!widget.driver.isConnected) {
      _activeTab = 1;
    }

    _connSub = widget.driver.connectionStateStream.listen((state) {
      if (!mounted) return;
      if (state == CameraConnectionState.connected) {
        setState(() => _activeTab = 0);
        _loadCameraFiles();
      } else if (state == CameraConnectionState.disconnected) {
        _cacheEpoch++;
        _thumbCache.clear();
        _fullCache.clear();
        _thumbFutures.clear();
        setState(() => _activeTab = 1);
      }
    });

    if (widget.driver.isConnected) {
      _loadCameraFiles();
    }
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  void _refresh([VoidCallback? fn]) {
    if (mounted) setState(fn ?? () {});
  }

  @override
  void dispose() {
    CameraViewedTracker.instance.removeListener(_onHistoryChanged);
    _historyManager.removeListener(_onHistoryChanged);
    _historyScrollController.dispose();
    _connSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// 供外部 (如 RootScaffold) 主动调用的刷新接口
  void reloadFiles() {
    if (mounted) _loadCameraFiles();
  }

  /// 标签页切换时空状态自动补漏刷新
  void reloadFilesIfEmpty() {
    if (_groups.isEmpty && widget.driver.isConnected && !_isLoading) {
      _loadCameraFiles();
    }
  }

  /// 切换至手机已导出相册
  void switchToExportedTab() {
    if (mounted) setState(() => _activeTab = 1);
  }

  /// 切换至相机存储卡相册
  void switchToCameraTab() {
    if (mounted) {
      setState(() => _activeTab = 0);
      reloadFilesIfEmpty();
    }
  }

  /// 进入拼图选片多选模式
  void enterCollageSelectionMode() {
    if (mounted) {
      setState(() {
        if (widget.driver.isConnected && _groups.isNotEmpty) {
          _activeTab = 0;
          _isSelectionMode = true;
        } else {
          _activeTab = 1;
          _isLocalSelectionMode = true;
        }
      });
    }
  }

  /// 系统返回：优先退出长按多选模式（清空已选），返回 true 表示已消费本次返回。
  bool handleSystemBack() {
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedBaseNames.clear();
      });
      return true;
    }
    if (_isLocalSelectionMode) {
      setState(() {
        _isLocalSelectionMode = false;
        _selectedLocalFileNames.clear();
      });
      return true;
    }
    return false;
  }

  /// 缩略图解析：内存 > 磁盘缓存(带完整 JPEG 校验) > 相机请求(原子写回磁盘)，同文件 in-flight 去重
  Future<Uint8List> _resolveThumb(CameraFileItem file) {
    final cacheKey = cameraCacheKey(file.storageId, file.handle);
    final cached = _thumbCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return Future.value(cached);
    }
    final inflight = _thumbFutures[cacheKey];
    if (inflight != null) return inflight;

    final future = () async {
      final epoch = _cacheEpoch;
      try {
        final disk = await _thumbCacheFile(
          file.storageId,
          file.handle,
          fileSize: file.size,
          fileName: file.fileName,
        );
        if (await disk.exists()) {
          final rawBytes = await disk.readAsBytes();
          if (epoch != _cacheEpoch) return Uint8List(0);
          final validDisk = NikonDriver.extractValidJpegSlice(rawBytes);
          if (validDisk != null && validDisk.isNotEmpty) {
            _thumbCache[cacheKey] = validDisk;
            return validDisk;
          } else {
            // 发现旧缓存或截断文件，立即清理重拉
            try {
              await disk.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final fetched = await widget.driver.getThumbnail(file.handle);
      if (epoch != _cacheEpoch) return Uint8List(0);
      final validBytes = NikonDriver.extractValidJpegSlice(fetched) ?? fetched;
      if (validBytes.isNotEmpty &&
          NikonDriver.extractValidJpegSlice(validBytes) != null) {
        _thumbCache[cacheKey] = validBytes;
        try {
          final disk = await _thumbCacheFile(
            file.storageId,
            file.handle,
            fileSize: file.size,
            fileName: file.fileName,
          );
          final tmp = File('${disk.path}.tmp');
          await tmp.writeAsBytes(validBytes, flush: true);
          await tmp.rename(disk.path);
        } catch (_) {}
        return validBytes;
      }
      return Uint8List(0);
    }();

    _thumbFutures[cacheKey] = future;
    future.whenComplete(() {
      if (identical(_thumbFutures[cacheKey], future)) {
        _thumbFutures.remove(cacheKey);
      }
    });
    return future;
  }

  /// 当缩略图解码异常时，立即淘汰内存与磁盘坏缓存以便自动重拉修复
  void _evictCorruptedThumb(CameraFileItem file) {
    final cacheKey = cameraCacheKey(file.storageId, file.handle);
    _thumbCache.remove(cacheKey);
    _thumbFutures.remove(cacheKey);
    unawaited(() async {
      try {
        final disk = await _thumbCacheFile(
          file.storageId,
          file.handle,
          fileSize: file.size,
          fileName: file.fileName,
        );
        if (await disk.exists()) {
          await disk.delete();
        }
      } catch (_) {}
    }());
  }

  /// 后台低速预取缩略图：先磁盘后相机，让滚动到哪都秒显。
  Future<void> _prefetchThumbnails(List<CameraFileItem> items) async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (final item in items) {
      if (!mounted || !widget.driver.isConnected) return;
      while (_backgroundPrefetchHold && mounted && widget.driver.isConnected) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      if (!mounted || !widget.driver.isConnected) return;
      if (item.isFolder ||
          _thumbCache
              .containsKey(cameraCacheKey(item.storageId, item.handle))) {
        continue;
      }
      try {
        await _resolveThumb(item);
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 40));
    }
  }

  void _updateMediaGroups(List<CameraFileItem> items) {
    final groupMap = <String, CameraMediaGroup>{};
    final orderList = <String>[];

    for (final item in items) {
      final dotIdx = item.fileName.lastIndexOf('.');
      final baseName =
          dotIdx != -1 ? item.fileName.substring(0, dotIdx) : item.fileName;
      final ext =
          dotIdx != -1 ? item.fileName.substring(dotIdx + 1).toUpperCase() : '';
      final isVid = item.isVideo || ext == 'MOV' || ext == 'MP4';

      final key = isVid ? '$baseName#video' : baseName;

      if (!groupMap.containsKey(key)) {
        groupMap[key] = CameraMediaGroup(baseName: baseName);
        orderList.add(key);
      }

      final g = groupMap[key]!;
      if (isVid) {
        g.videoItem = item;
      } else if (item.isRaw || ext == 'NEF' || ext == 'NRW') {
        g.rawItem = item;
      } else {
        g.jpegItem = item;
      }
    }

    _groups = orderList.map((k) => groupMap[k]!).toList();
  }

  /// 根据当前快捷筛选胶囊过滤媒体组
  List<CameraMediaGroup> get _filteredGroups {
    return _groups.where((g) {
      final isSynced = _historyManager.isExported(g.baseName);
      return switch (_activeFilter) {
        _GalleryFilter.all => true,
        _GalleryFilter.unviewed =>
          !isSynced && !CameraViewedTracker.instance.isViewed(g.baseName),
        _GalleryFilter.unsynced => !isSynced,
        _GalleryFilter.synced => isSynced,
        _GalleryFilter.jpg => g.isJpegOnly,
        _GalleryFilter.raw => g.isRawOnly,
        _GalleryFilter.jpgRaw => g.isRawAndJpeg,
        _GalleryFilter.mp4 => g.isVideo,
      };
    }).toList();
  }

  /// 计算已选媒体组的总大小文本
  String _getSelectedTotalSize() {
    if (_selectedBaseNames.isEmpty) return '0 KB';
    int totalBytes = 0;
    for (final g in _groups) {
      if (_selectedBaseNames.contains(g.baseName)) {
        totalBytes += g.totalBytes;
      }
    }
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (totalBytes >= 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
  }

  /// 超快渐进式文件列表加载算法
  Future<void> _loadCameraFiles() async {
    if (_isLoading || !widget.driver.isConnected) return;
    setState(() => _isLoading = true);

    try {
      final handles = await widget.driver.listObjectHandles(_selectedStorageId);
      final reversedHandles = handles.reversed.toList();

      if (reversedHandles.isEmpty) {
        if (mounted) {
          setState(() {
            _groups = [];
            _selectedBaseNames.clear();
          });
        }
        return;
      }

      final cachedItems = await _readCameraListCache(_selectedStorageId);
      final cachedByHandle = {for (final i in cachedItems) i.handle: i};
      final knownItems = <CameraFileItem>[];
      final missingHandles = <int>[];
      for (final h in reversedHandles) {
        final c = cachedByHandle[h];
        if (c != null) {
          knownItems.add(c);
        } else {
          missingHandles.add(h);
        }
      }

      final firstItems = <CameraFileItem>[];
      if (knownItems.isNotEmpty) {
        firstItems.addAll(knownItems);
      } else {
        for (final h in missingHandles.take(12)) {
          try {
            final info = await widget.driver.getObjectInfo(h);
            if (info != null && !info.isFolder) {
              firstItems.add(info);
            }
          } catch (_) {}
        }
      }

      _updateMediaGroups(firstItems);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedBaseNames.clear();
        });
      }

      final remaining = knownItems.isNotEmpty
          ? missingHandles
          : missingHandles.skip(12).toList();
      if (remaining.isNotEmpty) {
        _streamLoadRemaining(remaining, firstItems);
      } else {
        if (firstItems.isNotEmpty) {
          await _writeCameraListCache(_selectedStorageId, firstItems);
          unawaited(_prefetchThumbnails(firstItems));
        }
      }
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          context.l10n.galleryLoadFailedToast('$e'),
          tone: ZStatusTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 后台平滑分批流式追加加载，完成后持久化列表并预取缩略图
  void _streamLoadRemaining(
    List<int> handles,
    List<CameraFileItem> accumulator,
  ) async {
    const chunkSize = 12;
    for (var i = 0; i < handles.length; i += chunkSize) {
      if (!mounted || !widget.driver.isConnected) break;
      final chunk = handles.skip(i).take(chunkSize).toList();
      var hasNew = false;
      for (final h in chunk) {
        try {
          final info = await widget.driver.getObjectInfo(h);
          if (info != null && !info.isFolder) {
            accumulator.add(info);
            hasNew = true;
          }
        } catch (_) {}
      }
      if (hasNew && mounted) {
        _updateMediaGroups(accumulator);
        setState(() {});
      }
      await Future.delayed(const Duration(milliseconds: 30));
    }

    if (mounted) {
      await _writeCameraListCache(_selectedStorageId, accumulator);
      unawaited(_prefetchThumbnails(accumulator));
    }
  }

  void _toggleSelectGroup(String baseName) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedBaseNames.contains(baseName)) {
        _selectedBaseNames.remove(baseName);
        if (_selectedBaseNames.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBaseNames.add(baseName);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedBaseNames.length == _groups.length) {
        _selectedBaseNames.clear();
        _isSelectionMode = false;
      } else {
        _selectedBaseNames.addAll(_groups.map((g) => g.baseName));
        _isSelectionMode = _groups.isNotEmpty;
      }
    });
  }

  void _selectAllLocal() {
    setState(() {
      final items = _historyManager.items;
      if (_selectedLocalFileNames.length == items.length) {
        _selectedLocalFileNames.clear();
        _isLocalSelectionMode = false;
      } else {
        _selectedLocalFileNames.addAll(items.map((i) => i.fileName));
        _isLocalSelectionMode = items.isNotEmpty;
      }
    });
  }

  // ==========================================
  // 长按滑动多选（相机相册与历史导出共用）
  // ==========================================

  static const double _gridSpacing = 8;
  static const EdgeInsets _cameraGridPadding = EdgeInsets.fromLTRB(
    14,
    4,
    14,
    100,
  );
  static const EdgeInsets _historyGridPadding = EdgeInsets.fromLTRB(
    10,
    4,
    10,
    80,
  );
  static const double _cameraCardAspect = 1.0;
  static const double _historyCardAspect = 0.85;

  int _gridCrossAxisCountFor(double availableWidth) =>
      (availableWidth / 130).floor().clamp(3, 8);

  List<String> _displayKeys() => _activeTab == 0
      ? _filteredGroups.map((g) => g.baseName).toList()
      : _historyManager.items.map((e) => e.fileName).toList();

  Set<String> _currentSelection() =>
      _activeTab == 0 ? _selectedBaseNames : _selectedLocalFileNames;

  _GridGeometry? _activeGridGeometry() {
    if (_activeTab == 0 && _cameraGridKey.currentContext != null) {
      return _GridGeometry(
        key: _cameraGridKey,
        controller: _scrollController,
        padding: _cameraGridPadding,
        aspect: _cameraCardAspect,
      );
    }
    if (_historyGridKey.currentContext != null) {
      return _GridGeometry(
        key: _historyGridKey,
        controller: _historyScrollController,
        padding: _historyGridPadding,
        aspect: _historyCardAspect,
      );
    }
    return null;
  }

  int? _gridIndexAt(Offset global, int itemCount) {
    final geo = _activeGridGeometry();
    if (geo == null) return null;
    final ctx = geo.key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;

    final crossAxisCount = _gridCrossAxisCountFor(box.size.width);
    final local = box.globalToLocal(global);
    final gridW = box.size.width - geo.padding.horizontal;
    if (gridW <= 0 || crossAxisCount <= 0) return null;
    final itemW =
        (gridW - _gridSpacing * (crossAxisCount - 1)) / crossAxisCount;
    if (itemW <= 0) return null;
    final itemH = itemW / geo.aspect;
    final scroll = geo.controller.hasClients ? geo.controller.offset : 0.0;

    var col = ((local.dx - geo.padding.left) / (itemW + _gridSpacing)).floor();
    final row = ((local.dy - geo.padding.top + scroll) / (itemH + _gridSpacing))
        .floor();
    if (col < 0) col = 0;
    if (col >= crossAxisCount) col = crossAxisCount - 1;
    if (row < 0) return null;
    final index = row * crossAxisCount + col;
    return (index >= 0 && index < itemCount) ? index : null;
  }

  void _beginDragSelect(int index) {
    final keys = _displayKeys();
    if (index < 0 || index >= keys.length) return;
    final enteringSelection = _currentSelection().isEmpty;
    setState(() {
      _dragSnapshot = <int>{
        for (var i = 0; i < keys.length; i++)
          if (_currentSelection().contains(keys[i])) i,
      };
      _dragStartIndex = index;
      _dragMoved = false;
      _currentSelection().add(keys[index]);
      if (_activeTab == 0) {
        _isSelectionMode = true;
      } else {
        _isLocalSelectionMode = true;
      }
    });
    if (enteringSelection) HapticFeedback.mediumImpact();
  }

  void _updateDragSelect(Offset global) {
    final start = _dragStartIndex;
    if (start == null) return;
    final keys = _displayKeys();
    final index = _gridIndexAt(global, keys.length);
    if (index == null) return;
    setState(() {
      _dragMoved = true;
      final toggled = applyDragRangeToggle(_dragSnapshot, start, index);
      _currentSelection()
        ..clear()
        ..addAll(toggled.map((i) => keys[i]));
    });
  }

  void _endDragSelect() {
    final start = _dragStartIndex;
    if (start == null) return;
    final keys = _displayKeys();
    setState(() {
      if (!_dragMoved && start < keys.length) {
        _currentSelection().add(keys[start]);
      }
      if (_currentSelection().isEmpty) {
        if (_activeTab == 0) {
          _isSelectionMode = false;
        } else {
          _isLocalSelectionMode = false;
        }
      }
      _dragStartIndex = null;
      _dragMoved = false;
      _dragSnapshot = {};
    });
  }

  Future<void> _openFullScreenPreview(
    List<CameraMediaGroup> groups,
    int index,
  ) async {
    if (index < 0 || index >= groups.length) return;
    final item = groups[index].primaryItem;
    final cachedThumb =
        _thumbCache[cameraCacheKey(item.storageId, item.handle)];
    if (cachedThumb != null && cachedThumb.isNotEmpty) {
      unawaited(precacheImage(MemoryImage(cachedThumb), context));
    }
    _backgroundPrefetchHold = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenPhotoViewer(
          groups: groups,
          initialIndex: index,
          thumbCache: _thumbCache,
          fullCache: _fullCache,
          driver: widget.driver,
          resolveThumb: _resolveThumb,
          onExportSingle: _handleExportSingle,
          onOpenWatermark: widget.onOpenWatermark,
          onOpenProfessionalRaw: _handleOpenProfessionalRaw,
        ),
      ),
    );
    _backgroundPrefetchHold = false;
  }

  /// RAW 调色：把相机 NEF 落到临时文件，再交给水印/调色工作室走原生全质量渲染。
  Future<void> _handleOpenProfessionalRaw(CameraMediaGroup group) async {
    final raw =
        group.rawItem ?? (group.primaryItem.isRaw ? group.primaryItem : null);
    if (raw == null) return;
    final l10n = context.l10n;

    final nefBytes = await fetchFullPhotoBytesWithDialog(
      context,
      widget.driver,
      _fullCache,
      raw,
      rawOriginal: true,
    );
    if (!mounted || nefBytes == null || nefBytes.isEmpty) return;

    final rawPath = await _writeRawTempFile(raw, nefBytes);
    if (rawPath == null) {
      if (mounted) {
        showZToast(context, l10n.galleryRawDecodeFailedToast, isError: true);
      }
      return;
    }

    var preview = await RawPreviewExtractor.extractEmbeddedJpeg(nefBytes);
    if (preview == null || preview.isEmpty) {
      final thumb = await widget.driver.getThumbnail(raw.handle);
      preview = thumb.isNotEmpty ? thumb : null;
    }
    if (!mounted) return;
    if (preview == null || preview.isEmpty) {
      showZToast(context, l10n.galleryRawDecodeFailedToast, isError: true);
      return;
    }

    widget.onOpenWatermark?.call(
      raw,
      preview,
      openFilter: true,
      rawPath: rawPath,
    );
  }

  Future<String?> _writeRawTempFile(
    CameraFileItem raw,
    Uint8List bytes,
  ) async {
    try {
      final dir = await getTemporaryDirectory();
      final name =
          raw.fileName.isNotEmpty ? raw.fileName : 'raw_${raw.handle}.nef';
      final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file =
          File('${dir.path}/zync_raw_${raw.storageId}_${raw.size}_$safe');
      if (await file.exists() && await file.length() == bytes.length) {
        return file.path;
      }
      await file.writeAsBytes(bytes, flush: true);
      _pruneRawTempFiles(dir);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  void _pruneRawTempFiles(Directory dir) {
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('zync_raw_'))
          .toList()
        ..sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );
      for (final stale in files.skip(8)) {
        try {
          stale.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _openFullScreenLocalPreview(int initialIndex) {
    final items = _historyManager.items;
    if (initialIndex >= 0 && initialIndex < items.length) {
      final target = items[initialIndex];
      if (target.isVideo) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenExportedVideoViewer(
              item: target,
              onDelete: (it) => _historyManager.deleteItem(it),
            ),
          ),
        );
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenLocalImageViewer(
          items: _historyManager.items,
          initialIndex: initialIndex,
          onOpenWatermark: (item, bytes, {String? rawPath}) {
            final fakeCameraItem = CameraFileItem(
              handle: 0,
              storageId: 0,
              format: 0x3801,
              size: item.size,
              fileName: item.fileName,
              captureDate: item.dateFormatted,
            );
            widget.onOpenWatermark?.call(
              fakeCameraItem,
              bytes,
              openFilter: true,
              rawPath: rawPath,
            );
          },
          onDelete: (item) => _historyManager.deleteItem(item),
        ),
      ),
    );
  }

  Future<void> _handleExportSingle(CameraMediaGroup group) async {
    List<CameraFileItem> filesToDownload = [];
    if (group.isRawAndJpeg) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: context.zc.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _buildExportFormatSheet(ctx, 1),
      );
      if (choice == null) return;
      if (choice == 'both') {
        if (group.rawItem != null) filesToDownload.add(group.rawItem!);
        if (group.jpegItem != null) filesToDownload.add(group.jpegItem!);
      } else {
        if (group.jpegItem != null) filesToDownload.add(group.jpegItem!);
      }
    } else {
      if (group.rawItem != null) filesToDownload.add(group.rawItem!);
      if (group.jpegItem != null) filesToDownload.add(group.jpegItem!);
      if (group.videoItem != null) filesToDownload.add(group.videoItem!);
    }

    if (filesToDownload.isNotEmpty) {
      _showBlockingTransferDialog(filesToDownload);
    }
  }

  Future<void> _handleExport() async {
    final selected =
        _groups.where((g) => _selectedBaseNames.contains(g.baseName)).toList();
    if (selected.isEmpty) return;

    final hasRawAndJpeg = selected.any((g) => g.isRawAndJpeg);
    List<CameraFileItem> filesToDownload = [];

    if (hasRawAndJpeg) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: context.zc.surfaceElevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => _buildExportFormatSheet(ctx, selected.length),
      );

      if (choice == null) return;

      for (final g in selected) {
        if (g.isRawAndJpeg) {
          if (choice == 'both') {
            if (g.rawItem != null) filesToDownload.add(g.rawItem!);
            if (g.jpegItem != null) filesToDownload.add(g.jpegItem!);
          } else {
            if (g.jpegItem != null) filesToDownload.add(g.jpegItem!);
          }
        } else {
          if (g.rawItem != null) filesToDownload.add(g.rawItem!);
          if (g.jpegItem != null) filesToDownload.add(g.jpegItem!);
          if (g.videoItem != null) filesToDownload.add(g.videoItem!);
        }
      }
    } else {
      for (final g in selected) {
        if (g.rawItem != null) filesToDownload.add(g.rawItem!);
        if (g.jpegItem != null) filesToDownload.add(g.jpegItem!);
        if (g.videoItem != null) filesToDownload.add(g.videoItem!);
      }
    }

    if (filesToDownload.isEmpty) return;

    setState(() {
      _selectedBaseNames.clear();
      _isSelectionMode = false;
    });

    widget.downloadManager.enqueueAll(filesToDownload);
    if (mounted) {
      _showTransferMessage(
        context.l10n.galleryEnqueuedToast(filesToDownload.length),
      );
    }
  }

  Future<void> _openTransferCenter() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TransferCenterScreen(manager: widget.downloadManager),
      ),
    );
    if (mounted) setState(() {});
  }

  void _showTransferMessage(String message) {
    showZToast(
      context,
      message,
      action: SnackBarAction(
        label: context.l10n.commonView,
        textColor: context.zc.accent,
        onPressed: _openTransferCenter,
      ),
    );
  }

  // ==========================================
  // 拼图（Collage）入口
  // ==========================================

  List<CameraMediaGroup> _orderedSelectedGroups() {
    final byName = {for (final g in _groups) g.baseName: g};
    return _selectedBaseNames
        .map((n) => byName[n])
        .whereType<CameraMediaGroup>()
        .toList();
  }

  List<ExportedMediaItem> _orderedSelectedLocalItems() {
    final byName = {for (final e in _historyManager.items) e.fileName: e};
    return _selectedLocalFileNames
        .map((n) => byName[n])
        .whereType<ExportedMediaItem>()
        .toList();
  }

  void _collageHint(String message) {
    showZToast(context, message, tone: ZStatusTone.warning);
  }

  Future<void> _handleCollageFromCamera() async {
    final l10n = context.l10n;
    final selected = _orderedSelectedGroups();
    if (selected.length < 2) {
      _collageHint(l10n.galleryCollageNeed2To9);
      return;
    }
    if (selected.length > 9) {
      _collageHint(l10n.galleryCollageMax9);
      return;
    }

    final usable = selected.where((g) => g.jpegItem != null).toList();
    if (usable.length < 2) {
      _collageHint(l10n.galleryCollageNeedJpeg);
      return;
    }
    final skipped = selected.length - usable.length;

    final localByName = {
      for (final e in _historyManager.items) e.fileName.toUpperCase(): e,
    };
    bool isLocal(CameraMediaGroup g) =>
        localByName.containsKey(g.jpegItem!.fileName.toUpperCase());
    final missing = usable.where((g) => !isLocal(g)).toList();

    if (missing.isEmpty) {
      final items = <ExportedMediaItem>[];
      for (final g in usable) {
        final item = localByName[g.jpegItem!.fileName.toUpperCase()];
        if (item != null) items.add(item);
      }
      if (items.length < 2) {
        _collageHint(l10n.galleryCollageInsufficientCancelled);
        return;
      }
      setState(() {
        _selectedBaseNames.clear();
        _isSelectionMode = false;
      });
      await _openCollage(items);
      return;
    }

    final reusable = usable.length - missing.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final zc = ctx.zc;
        final zt = ctx.zt;
        return AlertDialog(
          backgroundColor: zc.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadius.lg),
            side: BorderSide(color: zc.outline, width: 0.8),
          ),
          title: Text(l10n.galleryCollageEnterTitle, style: zt.titleMedium),
          content: Text(
            l10n.galleryCollageDownloadPrompt(
              missing.length,
              reusable > 0 ? l10n.galleryCollageReusablePart(reusable) : '',
              skipped > 0 ? l10n.galleryCollageSkippedPart(skipped) : '',
            ),
            style: zt.bodySmall.copyWith(color: zc.textSecondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                l10n.commonCancel,
                style: zt.labelLarge.copyWith(color: zc.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                l10n.galleryConfirmDownload,
                style: zt.labelLarge.copyWith(color: zc.accent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final files = missing.map((g) => g.jpegItem!).toList();
    _showBlockingTransferDialog(
      files,
      onCompleted: (_) {
        _afterCameraDownloadForCollage(usable);
      },
    );
  }

  Future<void> _afterCameraDownloadForCollage(
    List<CameraMediaGroup> usable,
  ) async {
    final localByName = {
      for (final e in _historyManager.items) e.fileName.toUpperCase(): e,
    };
    final items = <ExportedMediaItem>[];
    for (final g in usable) {
      final item = localByName[g.jpegItem!.fileName.toUpperCase()];
      if (item != null) items.add(item);
    }
    if (!mounted) return;
    if (items.length < 2) {
      _collageHint(context.l10n.galleryCollageInsufficientCancelled);
      return;
    }
    setState(() {
      _selectedBaseNames.clear();
      _isSelectionMode = false;
    });
    await _openCollage(items);
  }

  Future<void> _handleCollageFromLocal() async {
    final l10n = context.l10n;
    final selected =
        _orderedSelectedLocalItems().where((e) => e.isJpeg || e.isPng).toList();
    if (selected.length < 2) {
      _collageHint(l10n.galleryCollageNeed2To9);
      return;
    }
    if (selected.length > 9) {
      _collageHint(l10n.galleryCollageMax9);
      return;
    }
    setState(() {
      _selectedLocalFileNames.clear();
      _isLocalSelectionMode = false;
    });
    await _openCollage(selected);
  }

  Future<void> _openCollage(List<ExportedMediaItem> items) async {
    final fallback = PhotoMetadata(
      cameraModel: widget.driver.cameraModel.isNotEmpty
          ? widget.driver.cameraModel
          : 'Nikon',
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollageScreen(items: items, fallbackMetadata: fallback),
      ),
    );
    if (mounted) {
      _historyManager.refresh();
      setState(() {});
    }
  }

  /// 多选删除：先选择删除范围，再按“相机先、本地后”逐组删除。
  Future<void> _handleDeleteSelected() async {
    final selected =
        _groups.where((g) => _selectedBaseNames.contains(g.baseName)).toList();
    if (selected.isEmpty) return;

    final scope = await showModalBottomSheet<_DeleteScope>(
      context: context,
      backgroundColor: context.zc.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildDeleteScopeSheet(ctx, selected.length),
    );
    if (scope == null || !mounted) return;

    if (AppSettings.instance.confirmDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            _buildDeleteConfirmDialog(ctx, selected.length, scope),
      );
      if (confirmed != true || !mounted) return;
    }

    await _executeDelete(selected, scope);
  }

  Future<void> _executeDelete(
    List<CameraMediaGroup> selected,
    _DeleteScope scope,
  ) async {
    final removedFromCamera = <String>{};
    final handled = <String>{};
    var failed = 0;
    var localFailedAfterCameraDelete = 0;
    for (final group in selected) {
      final files = <CameraFileItem>[
        if (group.jpegItem != null) group.jpegItem!,
        if (group.rawItem != null) group.rawItem!,
        if (group.videoItem != null) group.videoItem!,
      ];

      var cameraDeleted = scope == _DeleteScope.localOnly;
      if (scope == _DeleteScope.localAndCamera) {
        cameraDeleted = true;
        for (final file in files) {
          final ok = await widget.driver.deleteObject(file.handle);
          if (!ok) {
            cameraDeleted = false;
            break;
          }
        }
      }

      var localDeleted = true;
      if (cameraDeleted) {
        for (final file in files) {
          final candidates = ExportHistoryManager().findExportedItemsByBaseName(
            file.fileName,
          );
          ExportedMediaItem? local;
          for (final candidate in candidates) {
            if (candidate.fileName.toUpperCase() ==
                file.fileName.toUpperCase()) {
              local = candidate;
              break;
            }
          }
          if (local == null) continue;
          if (!await ExportHistoryManager().deleteItem(local)) {
            localDeleted = false;
            break;
          }
        }
      } else {
        localDeleted = false;
      }

      if (scope == _DeleteScope.localAndCamera && cameraDeleted) {
        removedFromCamera.add(group.baseName);
        for (final file in files) {
          final key = cameraCacheKey(file.storageId, file.handle);
          _thumbCache.remove(key);
          _fullCache.remove(key);
          _thumbFutures.remove(key);
        }
      }
      if (cameraDeleted && localDeleted) {
        handled.add(group.baseName);
      } else {
        if (scope == _DeleteScope.localAndCamera && cameraDeleted) {
          handled.add(group.baseName);
          localFailedAfterCameraDelete++;
        }
        failed++;
      }
    }

    if (!mounted) return;
    setState(() {
      if (removedFromCamera.isNotEmpty) {
        _groups = _groups
            .where((g) => !removedFromCamera.contains(g.baseName))
            .toList();
      }
      _selectedBaseNames.removeAll(handled);
      _isSelectionMode = true;
    });
    if (removedFromCamera.isNotEmpty) {
      unawaited(
        _writeCameraListCache(
          _selectedStorageId,
          _groups
              .expand(
                (g) => [
                  if (g.jpegItem != null) g.jpegItem!,
                  if (g.rawItem != null) g.rawItem!,
                  if (g.videoItem != null) g.videoItem!,
                ],
              )
              .toList(),
        ),
      );
    }

    final l10n = context.l10n;
    final message = failed == 0
        ? l10n.galleryDeletedGroupsToast(handled.length)
        : localFailedAfterCameraDelete > 0
            ? l10n.galleryDeletedGroupsPartialLocalFailToast(
                handled.length,
                failed,
                localFailedAfterCameraDelete,
              )
            : l10n.galleryDeletedGroupsFailToast(handled.length, failed);
    showZToast(context, message);
  }

  /// 本地多选删除：只删本地副本，不影响相机存储卡。
  Future<void> _handleLocalDeleteSelected() async {
    final selected = _orderedSelectedLocalItems();
    if (selected.isEmpty) return;

    if (AppSettings.instance.confirmDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _buildDeleteConfirmDialog(
          ctx,
          selected.length,
          _DeleteScope.localOnly,
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    var ok = 0;
    var failed = 0;
    for (final item in selected) {
      if (await _historyManager.deleteItem(item)) {
        ok++;
      } else {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() {
      _selectedLocalFileNames.removeAll(selected.map((e) => e.fileName));
      if (_selectedLocalFileNames.isEmpty) _isLocalSelectionMode = false;
    });
    final l10n = context.l10n;
    showZToast(
      context,
      failed == 0
          ? l10n.galleryDeletedLocalToast(ok)
          : l10n.galleryDeletedLocalPartialToast(ok, failed),
    );
  }

  Future<void> _openVideoEditor(CameraMediaGroup group) async {
    final video = group.videoItem;
    if (video == null) return;
    final progress = ValueNotifier<double>(0);
    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => AlertDialog(
            backgroundColor: context.zc.surfaceElevated,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.galleryStreamingVideoToast),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value == 0 ? null : value),
              ],
            ),
          ),
        ),
      );
    }
    final file = await widget.downloadManager.downloadToTemp(
      video,
      onProgress: (p) => progress.value = p,
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    progress.dispose();
    if (!mounted || file == null) {
      if (mounted) {
        showZToast(
          context,
          context.l10n.galleryVideoDownloadFailedToast,
          tone: ZStatusTone.danger,
        );
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoEditorScreen(path: file.path, fileName: video.fileName),
      ),
    );
  }

  Widget _buildSegmentedTabCapsule() {
    final zc = context.zc;
    final l10n = context.l10n;
    final isConnected = widget.driver.isConnected;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: zc.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 相机卡
          InkWell(
            onTap: () {
              if (_activeTab != 0) {
                if (!isConnected) {
                  showZToast(context, l10n.statusCameraDisconnected);
                  return;
                }
                setState(() => _activeTab = 0);
                reloadFilesIfEmpty();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: ZMotion.fast,
              curve: ZMotion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _activeTab == 0 ? zc.surface : ZSwatch.transparent,
                borderRadius: BorderRadius.circular(16),
                border: _activeTab == 0
                    ? Border.all(color: zc.outlineStrong, width: 0.8)
                    : null,
                boxShadow: _activeTab == 0
                    ? [
                        BoxShadow(
                          color: zc.scrim,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isConnected) ...[
                    Icon(Icons.circle, size: 6, color: zc.success),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _groups.isNotEmpty
                        ? '${l10n.galleryTabCameraCard} (${_groups.length})'
                        : l10n.galleryTabCameraCard,
                    style: TextStyle(
                      color:
                          _activeTab == 0 ? zc.textPrimary : zc.textSecondary,
                      fontSize: 12,
                      fontWeight:
                          _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 2),
          // 2. 手机已导出
          InkWell(
            onTap: () {
              if (_activeTab != 1) {
                setState(() => _activeTab = 1);
                _historyManager.refresh();
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: ZMotion.fast,
              curve: ZMotion.standard,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _activeTab == 1 ? zc.surface : ZSwatch.transparent,
                borderRadius: BorderRadius.circular(16),
                border: _activeTab == 1
                    ? Border.all(color: zc.outlineStrong, width: 0.8)
                    : null,
                boxShadow: _activeTab == 1
                    ? [
                        BoxShadow(
                          color: zc.scrim,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _historyManager.count > 0
                    ? '${l10n.galleryTabExportedPhoneShort} (${_historyManager.count})'
                    : l10n.galleryTabExportedPhoneShort,
                style: TextStyle(
                  color: _activeTab == 1 ? zc.textPrimary : zc.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isConnected = widget.driver.isConnected;
    final displayGroups = _filteredGroups;

    return Scaffold(
      appBar: AppBar(
        title: _buildSegmentedTabCapsule(),
        actions: [
          _buildTransferEntry(),
          if (isConnected && _activeTab == 0) ...[
            if (!widget.driver.isSingleSlotCamera &&
                widget.driver.availableStorageIds.length > 1)
              PopupMenuButton<int?>(
                icon: const Icon(Icons.sd_card),
                tooltip: l10n.gallerySlotSelectTitle,
                onSelected: (val) {
                  setState(() => _selectedStorageId = val);
                  _loadCameraFiles();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: null,
                    child: Text(l10n.gallerySlotAllMerged),
                  ),
                  PopupMenuItem(
                    value: 0x00010001,
                    child: Text(l10n.gallerySlot1),
                  ),
                  PopupMenuItem(
                    value: 0x00020001,
                    child: Text(l10n.gallerySlot2),
                  ),
                ],
              ),
            IconButton(
              icon: Icon(
                _isSelectionMode ? Icons.check_circle : Icons.checklist_rounded,
                color: _isSelectionMode ? zc.accent : zc.textSecondary,
              ),
              tooltip: l10n.galleryActionSelectAll,
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedBaseNames.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.galleryRefreshCardTooltip,
              onPressed: _loadCameraFiles,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _isLocalSelectionMode
                    ? Icons.check_circle
                    : Icons.checklist_rounded,
                color: _isLocalSelectionMode ? zc.accent : zc.textSecondary,
              ),
              tooltip: l10n.galleryActionSelectAll,
              onPressed: () {
                setState(() {
                  _isLocalSelectionMode = !_isLocalSelectionMode;
                  if (!_isLocalSelectionMode) _selectedLocalFileNames.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.galleryRefreshExportedTooltip,
              onPressed: () {
                _historyManager.refresh();
              },
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (isConnected && _activeTab == 0) _buildCameraInfoBar(),
              if (isConnected && _activeTab == 0) _buildFilterBar(),
              if (isConnected &&
                  _activeTab == 0 &&
                  widget.shootAndTransferController.isEnabled)
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: zc.accentMuted,
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    border: Border.all(
                      color: zc.success.withAlpha(100),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sync_alt, color: zc.success, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.galleryShootAndTransferBanner,
                          style: TextStyle(
                            color: zc.textPrimary,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      Switch(
                        value: true,
                        activeThumbColor: zc.success,
                        onChanged: (val) {
                          setState(() {
                            widget.shootAndTransferController.setEnabled(val);
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: (!isConnected || _activeTab == 1)
                    ? _buildHistoryExportView()
                    : _isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(zc.accent),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.galleryEnumeratingStorage,
                                  style: TextStyle(
                                    color: zc.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : displayGroups.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.photo_library_outlined,
                                        size: 48,
                                        color: zc.textSecondary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _groups.isEmpty
                                            ? l10n.galleryEmptyCameraPhotos
                                            : (_activeFilter ==
                                                    _GalleryFilter.unviewed
                                                ? l10n.galleryAllViewedTip
                                                : l10n.galleryEmptyFilterPhotos(
                                                    _filterLabel(
                                                      context,
                                                      _activeFilter,
                                                    ),
                                                  )),
                                        style: TextStyle(
                                          color: zc.textSecondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (_groups.isNotEmpty &&
                                          _activeFilter ==
                                              _GalleryFilter.unviewed) ...[
                                        const SizedBox(height: 14),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _activeFilter =
                                                  _GalleryFilter.all;
                                              AppSettings.instance
                                                  .setGalleryFilter(
                                                      _GalleryFilter.all.name);
                                            });
                                          },
                                          icon: Icon(
                                            Icons.photo_library_outlined,
                                            size: 16,
                                            color: zc.accent,
                                          ),
                                          label: Text(
                                            l10n.galleryViewAllPhotos,
                                            style: TextStyle(
                                              color: zc.accent,
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(
                                              color: zc.outline,
                                              width: 0.8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      ZRadius.pill),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, gridConstraints) => Listener(
                                  key: _cameraGridKey,
                                  onPointerMove: (e) =>
                                      _updateDragSelect(e.position),
                                  onPointerUp: (_) => _endDragSelect(),
                                  onPointerCancel: (_) => _endDragSelect(),
                                  child: GridView.builder(
                                    key: const PageStorageKey<String>(
                                      'camera_gallery_grid',
                                    ),
                                    controller: _scrollController,
                                    padding: _cameraGridPadding,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _gridCrossAxisCountFor(
                                        gridConstraints.maxWidth,
                                      ),
                                      crossAxisSpacing: _gridSpacing,
                                      mainAxisSpacing: _gridSpacing,
                                      childAspectRatio: _cameraCardAspect,
                                    ),
                                    itemCount: displayGroups.length,
                                    itemBuilder: (context, index) {
                                      final group = displayGroups[index];
                                      final isSelected = _selectedBaseNames
                                          .contains(group.baseName);
                                      return _buildMediaGroupCard(
                                        group,
                                        isSelected,
                                        index,
                                        displayGroups,
                                      );
                                    },
                                  ),
                                ),
                              ),
              ),
            ],
          ),

          // 5. 底部悬浮操作岛 Floating Action Dock
          if (isConnected && _activeTab == 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFloatingActionDock(),
            ),

          // 6. 本地「已导出」多选操作岛 (删除 + 拼图)
          if (_activeTab == 1 && _isLocalSelectionMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildLocalActionDock(),
            ),
        ],
      ),
    );
  }
}
