part of '../gallery_screen.dart';

/// 本地历史导出照片全屏大图预览器。
class FullScreenLocalImageViewer extends StatefulWidget {
  final List<ExportedMediaItem> items;
  final int initialIndex;
  final Function(
    ExportedMediaItem item,
    Uint8List imageBytes, {
    String? rawPath,
  })? onOpenWatermark;
  final Future<bool> Function(ExportedMediaItem item)? onDelete;

  const FullScreenLocalImageViewer({
    super.key,
    required this.items,
    required this.initialIndex,
    this.onOpenWatermark,
    this.onDelete,
  });

  @override
  State<FullScreenLocalImageViewer> createState() =>
      _FullScreenLocalImageViewerState();
}

class _FullScreenLocalImageViewerState
    extends State<FullScreenLocalImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  /// 可删除的可变副本（widget.items 是只读快照）。
  late final List<ExportedMediaItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List<ExportedMediaItem>.from(widget.items);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  /// 删除当前这张（仅本地相册，不影响相机存储卡）。
  Future<void> _handleDeleteCurrent() async {
    if (_items.isEmpty) return;
    final index = _currentIndex.clamp(0, _items.length - 1);
    final item = _items[index];
    final l10n = context.l10n;

    if (AppSettings.instance.confirmDelete) {
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
            title: Text(l10n.galleryDeleteSingleTitle, style: zt.titleMedium),
            content: Text(
              l10n.galleryDeleteSingleBody(item.fileName),
              style: zt.bodySmall.copyWith(color: zc.textSecondary),
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
                  l10n.commonDelete,
                  style: zt.labelLarge.copyWith(color: zc.danger),
                ),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) return;
    }

    final ok = await (widget.onDelete?.call(item) ??
        ExportHistoryManager().deleteItem(item));
    if (!mounted) return;
    if (!ok) {
      showZToast(
        context,
        l10n.galleryDeleteFailedToast,
        tone: ZStatusTone.danger,
      );
      return;
    }

    setState(() {
      _items.removeAt(index);
      _currentIndex = _items.isEmpty ? 0 : index.clamp(0, _items.length - 1);
    });
    if (_items.isEmpty) {
      Navigator.pop(context);
      return;
    }
    if (_pageController.hasClients) _pageController.jumpToPage(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// 编辑：进入全屏图片编辑器（裁切/旋转/透视/扭曲/自由变换）。
  Future<void> _handleOpenEditor(ExportedMediaItem item) async {
    if (!item.isJpeg && !item.isPng) return;
    final l10n = context.l10n;
    try {
      final localFile = await ExportHistoryManager().ensureLocalFile(item);
      final bytes = await localFile.readAsBytes();
      if (!mounted) return;
      final result = await Navigator.push<PhotoEditResult>(
        context,
        MaterialPageRoute(
          builder: (ctx) => PhotoEditorScreen(item: item, bytes: bytes),
        ),
      );
      if (result == null || !mounted) return;
      await ExportHistoryManager().refresh();
      if (!mounted) return;
      setState(() {});
      final label = result.overwriteFallback
          ? l10n.editorOverwriteFallbackToast
          : result.mode == PhotoEditSaveMode.overwrite
              ? l10n.editorOverwrittenToast
              : l10n.editorSavedAsNewToast;
      showZToast(context, label, tone: ZStatusTone.success);
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          l10n.galleryOpenEditorFailedToast('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  /// 去调色：读取本地原图并进入水印工坊调色（RAW 用内嵌 JPEG 预览）
  Future<void> _handleOpenFilter(ExportedMediaItem item) async {
    final l10n = context.l10n;
    try {
      final localFile = await ExportHistoryManager().ensureLocalFile(item);
      var bytes = await localFile.readAsBytes();
      if (item.isRaw) {
        final preview = await RawPreviewExtractor.extractEmbeddedJpeg(bytes);
        if (preview == null) {
          if (mounted) {
            showZToast(
              context,
              l10n.galleryRawNoEmbeddedPreviewToast,
              tone: ZStatusTone.warning,
            );
          }
          return;
        }
        bytes = preview;
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onOpenWatermark?.call(item, bytes);
      }
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          l10n.galleryLocalUnreadableToast('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = ZyncPalette.dark;
    final l10n = context.l10n;
    if (_items.isEmpty) {
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

    final curItem = _items[_currentIndex.clamp(0, _items.length - 1)];
    final totalCount = _items.length;

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
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final old = _items[index];
                final item = ExportHistoryManager().items.where((e) {
                      return e.mediaUri == old.mediaUri &&
                          e.fileName == old.fileName;
                    }).firstOrNull ??
                    old;
                return _ZoomablePhoto(
                  child: ExportedMediaImage(
                    item: item,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.broken_image,
                      color: dark.textTertiary,
                      size: 64,
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. 顶部编号/总编号
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: dark.scrim,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dark.outline, width: 0.8),
                ),
                child: Text(
                  '${_currentIndex + 1} / $totalCount',
                  style: TextStyle(
                    color: dark.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // 3. 操作栏：宽屏（平板 / 横屏）竖排在右侧，窄屏保持底部横条
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
                final bar = _buildControlBar(curItem, vertical: wide);
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

  /// 查看器操作栏：宽屏竖排在右侧，窄屏保持底部横条。
  Widget _buildControlBar(
    ExportedMediaItem curItem, {
    required bool vertical,
  }) {
    final dark = ZyncPalette.dark;
    final l10n = context.l10n;

    final close = GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dark.surfaceElevated.withAlpha(220),
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: dark.outline, width: 0.8),
        ),
        child: Icon(Icons.close, color: dark.textPrimary, size: 20),
      ),
    );

    final delete = GestureDetector(
      onTap: _handleDeleteCurrent,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: dark.surfaceElevated.withAlpha(220),
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: dark.outline, width: 0.8),
        ),
        child: Icon(Icons.delete_outline, color: dark.danger, size: 20),
      ),
    );

    final edit = GestureDetector(
      onTap: () => _handleOpenEditor(curItem),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark.surfaceElevated.withAlpha(220),
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: dark.outlineStrong, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune, color: dark.textPrimary, size: 16),
            const SizedBox(width: 6),
            Text(
              l10n.commonEdit,
              style: TextStyle(
                color: dark.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    final palette = GestureDetector(
      onTap: () => _handleOpenFilter(curItem),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark.accent,
          borderRadius: BorderRadius.circular(ZRadius.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.palette_outlined, color: dark.onAccent, size: 16),
            const SizedBox(width: 6),
            Text(
              l10n.galleryActionGradeShort,
              style: TextStyle(
                color: dark.onAccent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );

    final canEdit = curItem.isJpeg || curItem.isPng;
    if (vertical) {
      return Column(
        key: const ValueKey('adaptiveGalleryToolbar'),
        mainAxisSize: MainAxisSize.min,
        children: [
          close,
          const SizedBox(height: 10),
          delete,
          if (canEdit) ...[
            const SizedBox(height: 10),
            edit,
          ],
          const SizedBox(height: 10),
          palette,
        ],
      );
    }
    return Row(
      children: [
        close,
        const SizedBox(width: 10),
        delete,
        const Spacer(),
        if (canEdit) ...[
          edit,
          const SizedBox(width: 10),
        ],
        palette,
      ],
    );
  }
}

/// 本地历史导出视频全屏播放器
class FullScreenExportedVideoViewer extends StatefulWidget {
  final ExportedMediaItem item;
  final Future<bool> Function(ExportedMediaItem item)? onDelete;

  const FullScreenExportedVideoViewer({
    super.key,
    required this.item,
    this.onDelete,
  });

  @override
  State<FullScreenExportedVideoViewer> createState() =>
      _FullScreenExportedVideoViewerState();
}

class _FullScreenExportedVideoViewerState
    extends State<FullScreenExportedVideoViewer> {
  VideoPlayerController? _controller;
  File? _localFile;
  bool _isLoading = true;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final file = await ExportHistoryManager().ensureLocalFile(widget.item);
      if (!mounted) return;
      _localFile = file;
      final ctrl = VideoPlayerController.file(file);
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      ctrl.addListener(_onControllerUpdate);
      _controller = ctrl;
      _isLoading = false;
      _controller?.play();
      _startHideTimer();
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_controller?.value.isPlaying ?? false) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _hideTimer?.cancel();
      setState(() => _showControls = true);
    } else {
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
      setState(() => _showControls = true);
      _startHideTimer();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.zc;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: dark.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 视频画面
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            child: Center(
              child: _isLoading
                  ? CircularProgressIndicator(color: dark.accent)
                  : (_controller != null && _controller!.value.isInitialized)
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        )
                      : Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: dark.textTertiary,
                        ),
            ),
          ),

          // 居中播放/暂停大按扭 (仅控件可见时)
          if (_showControls &&
              _controller != null &&
              _controller!.value.isInitialized)
            Center(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: dark.scrim.withAlpha(160),
                    shape: BoxShape.circle,
                    border: Border.all(color: dark.outline, width: 0.8),
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: dark.onAccent,
                    size: 34,
                  ),
                ),
              ),
            ),

          // 顶部标题栏
          AnimatedPositioned(
            duration: ZMotion.fast,
            top: _showControls ? 0 : -90,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [dark.scrim.withAlpha(200), ZSwatch.transparent],
                ),
              ),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.item.fileName,
                      style: TextStyle(
                        color: dark.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_localFile != null)
                    ZButton(
                      label: l10n.videoEnterEditor,
                      icon: Icons.movie_creation_outlined,
                      size: ZButtonSize.sm,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoEditorScreen(
                              path: _localFile!.path,
                              fileName: widget.item.fileName,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 底部控制条
          AnimatedPositioned(
            duration: ZMotion.fast,
            bottom: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [dark.scrim.withAlpha(220), ZSwatch.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller != null &&
                      _controller!.value.isInitialized) ...[
                    Row(
                      children: [
                        Text(
                          _formatDuration(_controller!.value.position),
                          style: TextStyle(
                            color: dark.textPrimary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              activeTrackColor: dark.accent,
                              inactiveTrackColor: dark.outline,
                              thumbColor: dark.accent,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: SliderComponentShape.noOverlay,
                            ),
                            child: Slider(
                              value: _controller!.value.position.inMilliseconds
                                  .toDouble()
                                  .clamp(
                                    0.0,
                                    _controller!.value.duration.inMilliseconds
                                        .toDouble(),
                                  ),
                              max: _controller!.value.duration.inMilliseconds
                                  .toDouble(),
                              onChanged: (val) {
                                _controller?.seekTo(
                                  Duration(milliseconds: val.round()),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_controller!.value.duration),
                          style: TextStyle(
                            color: dark.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ZIconButton(
                        icon: (_controller?.value.isPlaying ?? false)
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        tooltip: (_controller?.value.isPlaying ?? false)
                            ? l10n.videoPause
                            : l10n.videoPlay,
                        onTap: _togglePlayPause,
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_localFile != null)
                            ZIconButton(
                              icon: Icons.ios_share_rounded,
                              tooltip: l10n.pcShareAction,
                              onTap: () {
                                CameraNativeBridge.shareFile(
                                  _localFile!.path,
                                  title: widget.item.fileName,
                                );
                              },
                            ),
                          const SizedBox(width: 8),
                          ZIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: l10n.commonDelete,
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: dark.surfaceElevated,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(ZRadius.lg),
                                    side: BorderSide(
                                        color: dark.outline, width: 0.8),
                                  ),
                                  title: Text(l10n.galleryDeleteSingleTitle),
                                  content: Text(
                                    l10n.galleryDeleteSingleBody(
                                        widget.item.fileName),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(l10n.commonCancel),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: Text(
                                        l10n.commonDelete,
                                        style: TextStyle(color: dark.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && mounted) {
                                await widget.onDelete?.call(widget.item);
                                if (mounted) Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
