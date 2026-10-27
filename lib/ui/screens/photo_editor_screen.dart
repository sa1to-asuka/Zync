import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../engine/editor/photo_edit_controller.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/photo_edit_preview.dart';
import '../widgets/photo_edit_tools.dart';

/// 编辑结果保存方式
enum PhotoEditSaveMode { overwrite, saveAsCopy }

/// 编辑结果
class PhotoEditResult {
  final PhotoEditSaveMode mode;
  final String fileName;
  final String? mediaUri;
  final File file;
  final bool overwriteFallback;

  const PhotoEditResult({
    required this.mode,
    required this.fileName,
    required this.mediaUri,
    required this.file,
    this.overwriteFallback = false,
  });
}

/// 图片编辑器：旋转 / 翻转 / 透视 / 扭曲 / 自由变换 / 裁切。
///
/// 全屏查看器与水印工坊共用本页，不重复实现。
class PhotoEditorScreen extends StatefulWidget {
  final ExportedMediaItem item;
  final Uint8List bytes;

  const PhotoEditorScreen({
    super.key,
    required this.item,
    required this.bytes,
  });

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  late final PhotoEditController _controller;
  final GlobalKey _previewKey = GlobalKey();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  PhotoEditTool _activeTool = PhotoEditTool.rotate;
  double get _cropAspect => _controller.value.cropAspect;

  @override
  void initState() {
    super.initState();
    _controller = PhotoEditController();
    _controller.addListener(_onTransformChanged);
    _loadImage();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadImage() async {
    await _controller.load(widget.bytes);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = _controller.renderError;
      });
    }
  }

  // ----------------------------------------------------------------
  // 保存：覆盖原图 / 另存为新文件
  // ----------------------------------------------------------------
  Future<void> _handleSave() async {
    if (_controller.loading || _isSaving) return;

    final mode = await showModalBottomSheet<PhotoEditSaveMode>(
      context: context,
      backgroundColor: context.zc.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (ctx) => _buildSaveSheet(ctx),
    );
    if (mode == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final result = await _renderAndSave(mode);
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showZToast(
          context,
          context.l10n.editorSaveFailedToast('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  Widget _buildSaveSheet(BuildContext ctx) {
    final zc = ctx.zc;
    final zt = ctx.zt;
    final l10n = ctx.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: zc.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.editorSaveSheetTitle, style: zt.headline),
            const SizedBox(height: 6),
            Text(
              l10n.editorSaveSheetSub,
              style: zt.bodySmall.copyWith(color: zc.textSecondary),
            ),
            const SizedBox(height: 16),
            _saveOption(
              ctx,
              mode: PhotoEditSaveMode.overwrite,
              icon: Icons.save_outlined,
              title: l10n.editorOverwriteTitle,
              subtitle: l10n.editorOverwriteSub,
            ),
            const SizedBox(height: 10),
            _saveOption(
              ctx,
              mode: PhotoEditSaveMode.saveAsCopy,
              icon: Icons.copy_all_outlined,
              title: l10n.editorSaveAsNewTitle,
              subtitle: l10n.editorSaveAsNewSub,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveOption(
    BuildContext ctx, {
    required PhotoEditSaveMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final zc = ctx.zc;
    final zt = ctx.zt;
    final accent =
        mode == PhotoEditSaveMode.overwrite ? zc.info : zc.warning;
    return InkWell(
      borderRadius: BorderRadius.circular(ZRadius.md),
      onTap: () => Navigator.pop(ctx, mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: BorderRadius.circular(ZRadius.md),
          border: Border.all(color: zc.outline),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: zt.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: zt.bodySmall.copyWith(color: zc.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: zc.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Future<PhotoEditResult> _renderAndSave(PhotoEditSaveMode mode) async {
    final isPng = widget.item.fileName.toLowerCase().endsWith('.png');
    final ext = isPng
        ? 'png'
        : widget.item.fileName.toLowerCase().endsWith('.jpeg')
            ? 'jpeg'
            : 'jpg';
    final encoded = await _controller.renderFull(format: isPng ? 'png' : 'jpg');

    final tempDir = await getTemporaryDirectory();
    final tempName =
        'zync_edit_${DateTime.now().millisecondsSinceEpoch}${isPng ? '.png' : '.jpg'}';
    final tempFile = File('${tempDir.path}/$tempName');
    await tempFile.writeAsBytes(encoded, flush: true);

    final history = ExportHistoryManager();
    try {
      if (mode == PhotoEditSaveMode.overwrite) {
        final uri = widget.item.mediaUri;
        var ok = false;
        if (uri != null && uri.isNotEmpty) {
          ok = await CameraNativeBridge.overwriteMedia(uri, tempFile.path);
        }
        if (ok) {
          await history.markOverwritten(
            widget.item.fileName,
            tempFile,
            uri,
          );
          return PhotoEditResult(
            mode: PhotoEditSaveMode.overwrite,
            fileName: widget.item.fileName,
            mediaUri: uri,
            file: await history.ensureLocalFile(
              history.findExportedItemByExactName(widget.item.fileName) ??
                  widget.item,
            ),
          );
        }
        // 覆盖失败：回退到另存，避免用户丢失编辑
        return await _saveAsCopy(encoded, ext, history, fallbackNote: true);
      }

      return await _saveAsCopy(encoded, ext, history);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  Future<PhotoEditResult> _saveAsCopy(
    Uint8List encoded,
    String ext,
    ExportHistoryManager history, {
    bool fallbackNote = false,
  }) async {
    final base = widget.item.fileName.contains('.')
        ? widget.item.fileName
            .substring(0, widget.item.fileName.lastIndexOf('.'))
        : widget.item.fileName;
    final newName =
        '${base}_edit_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$newName');
    await tempFile.writeAsBytes(encoded, flush: true);

    try {
      final saved = await CameraNativeBridge.saveMediaToGallery(
        tempFile.path,
        newName,
      );
      if (saved == null || saved.isEmpty) {
        final l10n = L10n.current;
        throw StateError(
          fallbackNote
              ? l10n.editorOverwriteAndSaveBothFailed
              : l10n.editorSaveAsFailed,
        );
      }
      history.registerSavedCopy(newName, tempFile, saved);
      return PhotoEditResult(
        mode: PhotoEditSaveMode.saveAsCopy,
        fileName: newName,
        mediaUri: saved,
        file: await history
            .ensureLocalFile(history.findExportedItemByExactName(newName)!),
        overwriteFallback: fallbackNote,
      );
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  // ----------------------------------------------------------------
  // UI 构建
  // ----------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    return Scaffold(
      backgroundColor: zc.bg,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSaving,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final preview = _error != null
                        ? _buildError()
                        : _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: zc.accent,
                                ),
                              )
                            : _buildPreviewArea();
                    // 宽屏：预览在左，操作面板收进右侧固定宽度侧栏。
                    if (constraints.maxWidth >= kAdaptiveRailBreakpoint) {
                      final panelWidth =
                          adaptiveSidePanelWidth(constraints.maxWidth);
                      return Row(
                        children: [
                          Expanded(child: preview),
                          VerticalDivider(width: 1, color: zc.outline),
                          if (_error == null && !_isLoading)
                            SizedBox(
                              key: const ValueKey('adaptiveSidePanel'),
                              width: panelWidth,
                              child: _buildToolsPanel(),
                            ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        Expanded(child: preview),
                        if (_error == null && !_isLoading) _buildToolsPanel(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PhotoEditToolsPanel _buildToolsPanel() => PhotoEditToolsPanel(
        controller: _controller,
        activeTool: _activeTool,
        docked: isAdaptiveWide(context),
        onToolChanged: (t) {
          setState(() => _activeTool = t);
          _controller.setCropOverlay(
            t == PhotoEditTool.crop || t == PhotoEditTool.distort,
          );
        },
        cropAspect: _cropAspect,
        onCropAspectSelected: (v) => applyCropAspect(_controller, v),
      );

  Widget _buildError() {
    final zc = context.zc;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, color: zc.textSecondary, size: 56),
            const SizedBox(height: 12),
            Text(
              _error ?? l10n.commonUnknownError,
              style: TextStyle(color: zc.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final zc = context.zc;
    final l10n = context.l10n;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(bottom: BorderSide(color: zc.outline, width: 0.8)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: zc.textPrimary),
            tooltip: l10n.commonExit,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              l10n.editorTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: zc.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.undo, color: zc.textPrimary),
            tooltip: l10n.commonUndo,
            onPressed: _controller.canUndo ? _controller.undo : null,
          ),
          IconButton(
            icon: Icon(Icons.redo, color: zc.textPrimary),
            tooltip: l10n.commonRedo,
            onPressed: _controller.canRedo ? _controller.redo : null,
          ),
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: zc.accent,
                    ),
                  )
                : Text(
                    l10n.commonSave,
                    style: TextStyle(
                      color: zc.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    final zc = context.zc;
    return Container(
      key: _previewKey,
      color: zc.canvas,
      child: PhotoEditPreview(
        controller: _controller,
        previewImage: _controller.previewImage,
        cropAspect: _cropAspect,
        activeTool: _activeTool,
      ),
    );
  }
}
