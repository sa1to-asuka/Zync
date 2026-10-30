part of '../gallery_screen.dart';

/// 全屏专业暗房大图预览器。
/// 支持双指手势缩放、双击 2.2x 缩放、单指下拉关闭、原图渐进升级、
/// 左右顺滑切图、单行 EXIF 速览 + 详细参数抽屉、以及快传 / 水印调色 / RAW 暗房一键直达。
class FullScreenPhotoViewer extends StatefulWidget {
  final List<CameraMediaGroup> groups;
  final int initialIndex;
  final LruImageCache thumbCache;
  final LruImageCache fullCache;
  final CameraDriver driver;

  /// 复用相册页的缩略图解析链（内存 > 磁盘 > 相机，同文件去重），
  /// 避免查看器在 build 里重复发起 USB 请求。
  final Future<Uint8List> Function(CameraFileItem file) resolveThumb;
  final Function(CameraMediaGroup group)? onExportSingle;
  final Function(
    CameraFileItem item,
    Uint8List? imageBytes, {
    bool openFilter,
    String? rawPath,
  })? onOpenWatermark;
  final Function(CameraMediaGroup group)? onOpenProfessionalRaw;

  const FullScreenPhotoViewer({
    super.key,
    required this.groups,
    required this.initialIndex,
    required this.thumbCache,
    required this.fullCache,
    required this.driver,
    required this.resolveThumb,
    this.onExportSingle,
    this.onOpenWatermark,
    this.onOpenProfessionalRaw,
  });

  @override
  State<FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<FullScreenPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final Set<String> _fullTried = {};
  final Map<String, PhotoMetadata> _parsedMetas = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    if (widget.initialIndex >= 0 &&
        widget.initialIndex < widget.groups.length) {
      CameraViewedTracker.instance
          .markViewed(widget.groups[widget.initialIndex].baseName);
    }
    _preloadMetaForCurrent();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _preloadMetaForCurrent() {
    if (widget.groups.isEmpty) return;
    final primary = widget
        .groups[_currentIndex.clamp(0, widget.groups.length - 1)]
        .primaryItem;
    final key = cameraCacheKey(primary.storageId, primary.handle);
    if (_parsedMetas.containsKey(key)) return;

    final cached = widget.fullCache[key] ?? widget.thumbCache[key];
    if (cached != null && cached.isNotEmpty) {
      ExifHelper.parseBytes(cached).then((meta) {
        if (mounted) setState(() => _parsedMetas[key] = meta);
      });
    }
  }

  /// 后台静默拉取原图，完成后 setState 升级画质 (缩略图 → 清晰原图)。
  void _scheduleFullLoad(CameraFileItem file, {required bool isCurrent}) {
    if (!isCurrent) return;
    final key = cameraCacheKey(file.storageId, file.handle);
    if (!_fullTried.add(key)) return;
    if (!widget.driver.isConnected) return;
    fetchFullPhotoBytesSilent(widget.driver, widget.fullCache, file).then((
      bytes,
    ) {
      if (mounted && bytes != null) {
        ExifHelper.parseBytes(bytes).then((meta) {
          if (mounted) setState(() => _parsedMetas[key] = meta);
        });
        setState(() {});
      }
    });
  }

  /// 去调色：等待原图传输完成后退出预览并进入水印工坊调色
  Future<void> _handleOpenFilter(CameraFileItem primary) async {
    final bytes = await fetchFullPhotoBytesWithDialog(
      context,
      widget.driver,
      widget.fullCache,
      primary,
    );
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) return;
    Navigator.pop(context);
    widget.onOpenWatermark?.call(primary, bytes, openFilter: true);
  }

  /// 照片渲染：本地导出 > 原图 > 缩略图(带原图加载进度角标)
  Widget _buildPhotoWidget(
    CameraFileItem file, {
    BoxFit fit = BoxFit.contain,
    bool isCurrent = false,
  }) {
    final localItem = ExportHistoryManager().findExportedItem(
      file.fileName,
      sourceKey: ExportHistoryManager.sourceKey(
        file.storageId,
        file.fileName,
        file.size,
        file.captureDate,
      ),
    );
    if (localItem != null) {
      return ExportedMediaImage(
        item: localItem,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            _buildCameraPreview(file, fit, isCurrent: isCurrent),
      );
    }
    return _buildCameraPreview(file, fit, isCurrent: isCurrent);
  }

  Widget _buildCameraPreview(
    CameraFileItem file,
    BoxFit fit, {
    required bool isCurrent,
  }) {
    final dark = ZyncPalette.dark;
    final fullKey = cameraCacheKey(file.storageId, file.handle);
    final full = widget.fullCache[fullKey];
    if (full != null && full.isNotEmpty) {
      return Image.memory(
        full,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.broken_image, color: dark.textTertiary, size: 64),
      );
    }

    final cachedThumb = widget.thumbCache[fullKey];
    if (cachedThumb != null && cachedThumb.isNotEmpty) {
      _scheduleFullLoad(file, isCurrent: isCurrent);
      return _buildThumbStage(cachedThumb, fit, isCurrent: isCurrent);
    }

    return FutureBuilder<Uint8List>(
      future: widget.resolveThumb(file),
      builder: (ctx, snap) {
        if (snap.hasData && snap.data!.isNotEmpty) {
          widget.thumbCache[fullKey] = snap.data!;
          _scheduleFullLoad(file, isCurrent: isCurrent);
          return _buildThumbStage(snap.data!, fit, isCurrent: isCurrent);
        }
        return Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(dark.accent),
            ),
          ),
        );
      },
    );
  }

  /// 缩略图 + 「原图加载中」角标（只有当前页显示角标，避免预建页误导）。
  Widget _buildThumbStage(
    Uint8List thumbBytes,
    BoxFit fit, {
    required bool isCurrent,
  }) {
    final dark = ZyncPalette.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          thumbBytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.broken_image, color: dark.textTertiary, size: 64),
        ),
        if (isCurrent)
          Positioned(
            top: 10,
            right: 10,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: dark.accent,
              ),
            ),
          ),
      ],
    );
  }

  void _showExifDetailSheet(
    BuildContext context,
    CameraMediaGroup group,
    PhotoMetadata meta,
  ) {
    final dark = ZyncPalette.dark;
    final l10n = context.l10n;
    final primary = group.primaryItem;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: dark.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.galleryExifDetailSheetTitle,
                      style: TextStyle(
                        color: dark.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: dark.textTertiary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: dark.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: dark.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildExifParamItem(
                              l10n.galleryExifShutter,
                              meta.shutterSpeed.isNotEmpty
                                  ? meta.shutterSpeed
                                  : '—',
                            ),
                          ),
                          Expanded(
                            child: _buildExifParamItem(
                              l10n.galleryExifAperture,
                              meta.aperture.isNotEmpty ? meta.aperture : '—',
                            ),
                          ),
                          Expanded(
                            child: _buildExifParamItem(
                              'ISO',
                              meta.iso.isNotEmpty
                                  ? meta.iso.replaceAll('ISO ', '')
                                  : '—',
                            ),
                          ),
                          Expanded(
                            child: _buildExifParamItem(
                              l10n.galleryExifFocal,
                              meta.focalLength.isNotEmpty
                                  ? meta.focalLength
                                  : '—',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20, thickness: 0.8),
                      _buildExifMetaRow(
                        l10n.galleryExifCamera,
                        meta.cameraModel.isNotEmpty
                            ? meta.cameraModel
                            : widget.driver.cameraModel,
                      ),
                      const SizedBox(height: 6),
                      _buildExifMetaRow(
                        l10n.galleryExifLens,
                        meta.lensModel.isNotEmpty ? meta.lensModel : '—',
                      ),
                      const SizedBox(height: 6),
                      _buildExifMetaRow(
                        l10n.collageFileSize,
                        '${primary.fileName} (${primary.sizeFormatted})',
                      ),
                      if (primary.captureDate.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildExifMetaRow(
                          l10n.wmStyleShowDate,
                          primary.captureDate,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExifParamItem(String label, String value) {
    final dark = ZyncPalette.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(color: dark.textTertiary, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: dark.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildExifMetaRow(String label, String value) {
    final dark = ZyncPalette.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(color: dark.textTertiary, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: dark.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = ZyncPalette.dark;
    final l10n = context.l10n;
    if (widget.groups.isEmpty) {
      return Scaffold(
        backgroundColor: dark.bg,
        appBar: AppBar(backgroundColor: dark.bg),
        body: Center(
          child: Text(
            l10n.galleryNoPhotos,
            style: TextStyle(color: dark.textSecondary),
          ),
        ),
      );
    }

    final currentGroup =
        widget.groups[_currentIndex.clamp(0, widget.groups.length - 1)];
    final primary = currentGroup.primaryItem;
    final totalCount = widget.groups.length;
    final key = cameraCacheKey(primary.storageId, primary.handle);
    final meta = _parsedMetas[key] ?? const PhotoMetadata();

    return Scaffold(
      backgroundColor: dark.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 暗房画布全屏滑动预览
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: totalCount,
              onPageChanged: (idx) {
                setState(() => _currentIndex = idx);
                _preloadMetaForCurrent();
                if (idx >= 0 && idx < widget.groups.length) {
                  CameraViewedTracker.instance
                      .markViewed(widget.groups[idx].baseName);
                }
              },
              itemBuilder: (context, index) {
                final file = widget.groups[index].primaryItem;
                return _ZoomablePhoto(
                  child: _buildPhotoWidget(
                    file,
                    fit: BoxFit.contain,
                    isCurrent: index == _currentIndex,
                  ),
                );
              },
            ),
          ),

          // 2. 顶部相机内编号/格式与关闭/参数按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: dark.surfaceElevated.withAlpha(210),
                      shape: BoxShape.circle,
                      border: Border.all(color: dark.outline, width: 0.8),
                    ),
                    child: Icon(Icons.arrow_back,
                        color: dark.textPrimary, size: 20),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: dark.scrim,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: dark.outline, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_currentIndex + 1} / $totalCount',
                        style: TextStyle(
                          color: dark.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: dark.surfaceHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          currentGroup.formatBadge,
                          style: TextStyle(
                            color: dark.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showExifDetailSheet(context, currentGroup, meta),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: dark.surfaceElevated.withAlpha(210),
                      shape: BoxShape.circle,
                      border: Border.all(color: dark.outline, width: 0.8),
                    ),
                    child: Icon(Icons.info_outline,
                        color: dark.textPrimary, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // 3. 底部悬浮暗房操作坞 (EXIF 速览 + 快捷动作)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
                final bar = _buildControlDock(currentGroup, primary, meta,
                    vertical: wide);
                return wide
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: bar,
                        ),
                      )
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            MediaQuery.of(context).padding.bottom + 12,
                          ),
                          child: bar,
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 查看器底部操作坞 (速览 EXIF + 加框调色 + RAW 暗房 + 下载)
  Widget _buildControlDock(
    CameraMediaGroup group,
    CameraFileItem primary,
    PhotoMetadata meta, {
    required bool vertical,
  }) {
    final dark = ZyncPalette.dark;
    final l10n = context.l10n;
    final hasRaw = group.rawItem != null || group.primaryItem.isRaw;

    final exifSummary = meta.exposureSummary.isNotEmpty
        ? meta.exposureSummary
        : (primary.captureDate.isNotEmpty
            ? primary.captureDate
            : primary.fileName);

    final close = Material(
      color: dark.surfaceElevated.withAlpha(220),
      borderRadius: BorderRadius.circular(ZRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(ZRadius.md),
        onTap: () => Navigator.pop(context),
        child: Icon(Icons.close, color: dark.textPrimary, size: 24),
      ),
    );

    if (vertical) {
      return Container(
        key: const ValueKey('adaptiveGalleryToolbar'),
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark.surfaceElevated.withAlpha(235),
          borderRadius: BorderRadius.circular(ZRadius.lg),
          border: Border.all(color: dark.outline, width: 0.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: close),
            const SizedBox(height: 10),
            Text(
              exifSummary,
              style: TextStyle(
                color: dark.textSecondary,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 16, thickness: 0.8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: dark.accent,
                foregroundColor: dark.onAccent,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _handleOpenFilter(primary),
              icon: const Icon(Icons.palette_outlined, size: 16),
              label: Text(l10n.galleryActionGradeShort,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            if (hasRaw) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: dark.accent,
                  side: BorderSide(color: dark.accent),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenProfessionalRaw?.call(group);
                },
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: Text(l10n.galleryActionProRawGrade,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
            if (widget.onExportSingle != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: dark.textPrimary,
                  side: BorderSide(color: dark.outline),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => widget.onExportSingle!(group),
                icon: const Icon(Icons.download_outlined, size: 16),
                label: Text(l10n.gallerySyncToPhoneButton,
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        close,
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: dark.surfaceElevated.withAlpha(235),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dark.outlineStrong, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: dark.scrim.withAlpha(90),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：单行 EXIF 速览
                Row(
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 13, color: dark.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${meta.cameraModel.isNotEmpty ? meta.cameraModel : widget.driver.cameraModel}  ·  $exifSummary',
                        style: TextStyle(
                          color: dark.textSecondary,
                          fontSize: 10.5,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 第二行：操作按钮（统一紧凑高度，防文字折行撑高）
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dark.accent,
                            foregroundColor: dark.onAccent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _handleOpenFilter(primary),
                          icon: const Icon(Icons.palette_outlined, size: 15),
                          label: Text(
                            l10n.galleryActionGradeShort,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (hasRaw) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: dark.accent,
                              side: BorderSide(
                                  color: dark.accent.withAlpha(160), width: 1.0),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onOpenProfessionalRaw?.call(group);
                            },
                            icon: const Icon(Icons.auto_awesome, size: 14),
                            label: Text(
                              l10n.galleryActionProRawGrade,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (widget.onExportSingle != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: dark.surfaceHigh,
                              foregroundColor: dark.textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: dark.outline, width: 0.8),
                              ),
                            ),
                            onPressed: () => widget.onExportSingle!(group),
                            icon: const Icon(Icons.download_outlined, size: 15),
                            label: Text(
                              l10n.gallerySyncToPhoneButton,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
