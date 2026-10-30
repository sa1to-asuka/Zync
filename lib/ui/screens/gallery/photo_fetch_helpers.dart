part of '../gallery_screen.dart';

// ================= 相机相册持久缓存 (列表 + 缩略图) =================

Future<Directory> _galleryCacheDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/gallery_cache');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// 文件列表缓存路径 (按卡槽分文件)
Future<File> _cameraListCacheFile(int? storageId) async {
  final dir = await _galleryCacheDir();
  final key = storageId == null ? 'all' : storageId.toRadixString(16);
  return File('${dir.path}/camera_list_$key.json');
}

/// 读取上次的文件列表 (增量加载的基础)
Future<List<CameraFileItem>> _readCameraListCache(int? storageId) async {
  try {
    final f = await _cameraListCacheFile(storageId);
    if (!await f.exists()) return [];
    final List<dynamic> arr = jsonDecode(await f.readAsString());
    return arr
        .map(
            (e) => CameraFileItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
}

/// 持久化文件列表
Future<void> _writeCameraListCache(
    int? storageId, List<CameraFileItem> items) async {
  try {
    final f = await _cameraListCacheFile(storageId);
    await f.writeAsString(
      jsonEncode(items.map((e) => e.toJson()).toList()),
      flush: false,
    );
  } catch (_) {}
}

/// 缩略图磁盘缓存文件名：
/// v3: 按 storageId_size_fileName 唯一化，彻底解耦相机动态 handle。
/// 只要相机卡内该照片物理存在，跨连接、跨重启永久命中本地缓存，绝不向相机发起重复网络请求。
String _thumbCacheNameV3(
  int storageId, {
  int fileSize = 0,
  String fileName = '',
}) {
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return 'v3_${storageId}_${fileSize}_$safeName.jpg';
}

/// 兼容旧版 v2 格式文件名（用于平滑迁移老版本历史缓存）
String _thumbCacheNameV2(
  int storageId,
  int handle, {
  int fileSize = 0,
  String fileName = '',
}) {
  final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (safeName.isEmpty && fileSize == 0) {
    return 'v2_${storageId}_$handle.jpg';
  }
  return 'v2_${storageId}_${handle}_${fileSize}_$safeName.jpg';
}

Future<File> _thumbCacheFile(
  int storageId,
  int handle, {
  int fileSize = 0,
  String fileName = '',
}) async {
  final dir = Directory('${(await _galleryCacheDir()).path}/thumb');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  // 1. 优先使用跨会话永久稳定的 v3 缓存路径
  final v3File = File(
    '${dir.path}/${_thumbCacheNameV3(storageId, fileSize: fileSize, fileName: fileName)}',
  );
  if (await v3File.exists()) {
    return v3File;
  }

  // 2. 若命中旧版 v2 缓存，平滑迁移为 v3 规范文件
  final v2File = File(
    '${dir.path}/${_thumbCacheNameV2(storageId, handle, fileSize: fileSize, fileName: fileName)}',
  );
  if (await v2File.exists()) {
    try {
      await v2File.rename(v3File.path);
      return v3File;
    } catch (_) {
      return v2File;
    }
  }

  return v3File;
}

final _cameraOriginalLoads = Expando<Map<String, Future<Uint8List>>>();

Future<Uint8List> _readCameraOriginal(
  CameraDriver driver,
  CameraFileItem item, {
  void Function(int, int)? onProgress,
}) {
  final requests = _cameraOriginalLoads[driver] ??= {};
  final key = cameraCacheKey(item.storageId, item.handle);
  return requests.putIfAbsent(key, () async {
    try {
      return await driver.downloadFullObject(
        item.handle,
        item.size,
        onProgress: onProgress,
      );
    } finally {
      requests.remove(key);
    }
  });
}

Future<Uint8List?> _readLocalOriginal(CameraFileItem item) async {
  final history = ExportHistoryManager();
  final local = history.findExportedItem(
    item.fileName,
    sourceKey: ExportHistoryManager.sourceKey(
      item.storageId,
      item.fileName,
      item.size,
      item.captureDate,
    ),
  );
  if (local == null) return null;
  final file = await history.ensureLocalFile(local);
  final fileBytes = await file.readAsBytes();
  if (local.isRaw) {
    return RawPreviewExtractor.extractEmbeddedJpeg(fileBytes);
  }
  return fileBytes;
}

/// 静默获取相机原图（手机本地已导出 → 内存缓存 → 相机无线传输，不弹窗，用于后台预加载）
/// 注意：若该文件仅是 RAW (NEF)，则自动回退拉取其高清缩略图预览，防止 Flutter Image 无法直接解码原始拜耳阵列数据
Future<Uint8List?> fetchFullPhotoBytesSilent(
  CameraDriver driver,
  LruImageCache fullCache,
  CameraFileItem item,
) async {
  final key = cameraCacheKey(item.storageId, item.handle);

  // 1. 本地原图优先（优先于旧内存缓存，保证编辑覆盖后读取最新文件）
  try {
    final local = await _readLocalOriginal(item);
    if (local != null && local.isNotEmpty) {
      fullCache[key] = local;
      return local;
    }
  } catch (_) {}

  // 2. 命中内存原图缓存
  final cached = fullCache[key];
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  if (!driver.isConnected || item.size <= 0) return null;

  try {
    // 3. 若为纯 RAW (NEF/NRW)，先完整下载再用 RawPreviewExtractor 提取内嵌全尺寸预览 JPEG
    if (item.isRaw) {
      if (item.size > 0) {
        final rawBytes = await _readCameraOriginal(driver, item);
        final preview = await RawPreviewExtractor.extractEmbeddedJpeg(rawBytes);
        if (preview != null && preview.isNotEmpty) {
          fullCache[key] = preview;
          return preview;
        }
      }
      final thumbBytes = await driver.getThumbnail(item.handle);
      if (thumbBytes.isNotEmpty) {
        fullCache[key] = thumbBytes;
        return thumbBytes;
      }
      return null;
    }

    // 4. 标准 JPEG：从相机流式下载完整原图（并发请求去重）
    final bytes = await _readCameraOriginal(driver, item);
    if (bytes.isNotEmpty) {
      fullCache[key] = bytes;
      return bytes;
    }
  } catch (_) {}
  return null;
}

/// 顶层共用方法：带进度弹窗获取相机高清原图（供相册详情页、全屏预览器与一键调色共同调用）
///
/// [rawOriginal] 为 true 时返回相机里的原始 NEF 字节（不做内嵌 JPEG 提取、不写
/// `fullCache`），供 RAW 调色写入临时文件后交给原生 LibRaw。
Future<Uint8List?> fetchFullPhotoBytesWithDialog(
  BuildContext context,
  CameraDriver driver,
  LruImageCache fullCache,
  CameraFileItem item, {
  bool rawOriginal = false,
}) async {
  final key = cameraCacheKey(item.storageId, item.handle);

  // 1. 优先命中本地已导出原图
  if (!rawOriginal) {
    try {
      final local = await _readLocalOriginal(item);
      if (local != null && local.isNotEmpty) {
        fullCache[key] = local;
        return local;
      }
    } catch (_) {
      if (context.mounted) {
        showZToast(
          context,
          context.l10n.galleryLocalMissingFallbackToast,
          tone: ZStatusTone.warning,
        );
      }
    }

    // 2. 命中内存缓存
    final cached = fullCache[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
  }

  if (!context.mounted) return null;
  if (!driver.isConnected || item.size <= 0) return null;

  final progressNotifier = ValueNotifier<double>(0.0);
  bool isCanceled = false;

  if (!context.mounted) return null;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      final zc = dialogCtx.zc;
      final zt = dialogCtx.zt;
      final l10n = dialogCtx.l10n;
      return PopScope(
        canPop: false,
        child: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            return AlertDialog(
              backgroundColor: zc.surfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZRadius.lg),
                side: BorderSide(color: zc.outline, width: 0.8),
              ),
              title: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(zc.accent),
                    ),
                  ),
                  const SizedBox(width: ZSpace.md),
                  Expanded(
                    child: Text(
                      l10n.galleryLoadingHighResTitle,
                      style: zt.titleMedium,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.galleryLoadingHighResBody(item.sizeFormatted),
                    style: zt.bodySmall.copyWith(color: zc.textSecondary),
                  ),
                  const SizedBox(height: ZSpace.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.fileName,
                          style: zt.labelLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: zt.mono.copyWith(color: zc.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZSpace.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ZRadius.xs),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: zc.outline,
                      valueColor: AlwaysStoppedAnimation(zc.accent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    isCanceled = true;
                    Navigator.pop(dialogCtx);
                  },
                  child: Text(
                    l10n.commonCancel,
                    style: zt.labelLarge.copyWith(color: zc.danger),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );

  try {
    final downloaded = await _readCameraOriginal(
      driver,
      item,
      onProgress: (cur, total) {
        if (!isCanceled && total > 0) {
          progressNotifier.value = (cur / total).clamp(0.0, 1.0);
        }
      },
    );
    Uint8List? bytes = downloaded;
    if (!rawOriginal && item.isRaw) {
      bytes = await RawPreviewExtractor.extractEmbeddedJpeg(downloaded);
      if (bytes == null || bytes.isEmpty) {
        final thumb = await driver.getThumbnail(item.handle);
        if (thumb.isNotEmpty) bytes = thumb;
      }
    }
    if (context.mounted && !isCanceled && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    if (isCanceled || bytes == null || bytes.isEmpty) return null;
    if (!rawOriginal) fullCache[key] = bytes;
    return bytes;
  } catch (_) {
    if (context.mounted && !isCanceled && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    return null;
  }
}
