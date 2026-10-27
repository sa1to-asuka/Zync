import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/collage/collage_layout.dart';
import '../../engine/collage/collage_renderer.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../engine/watermark/watermark_painter.dart';
import '../../engine/watermark/watermark_renderer.dart';
import '../../engine/watermark/watermark_template.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/watermark_style_controls.dart';
import '../widgets/watermark_template_card.dart';

/// 全屏拼图工作台：多张本地照片按版式拼接，可叠加现有水印模板后导出。
///
/// 复用下载/水印/主题管线，不重复实现：素材来自 [ExportHistoryManager]
/// 的本地文件，成品由 [CollageRenderer] + [WatermarkRenderer] 合成。
class CollageScreen extends StatefulWidget {
  /// 按用户选择顺序排列的本地素材。
  final List<ExportedMediaItem> items;

  /// EXIF 缺失时用于回退的拍摄参数（如相机机型）。
  final PhotoMetadata? fallbackMetadata;

  const CollageScreen({
    super.key,
    required this.items,
    this.fallbackMetadata,
  });

  @override
  State<CollageScreen> createState() => _CollageScreenState();
}

class _CollageScreenState extends State<CollageScreen> {
  final List<ui.Image> _images = [];
  bool _loading = true;
  bool _isExporting = false;

  CollageTemplate _template = CollageTemplate.topBottom;
  CollageAspect _aspect = CollageAspect.square;
  CollageBorder _border = CollageBorder.none;

  WatermarkTemplate _wmTemplate = WatermarkTemplate.none;
  bool _cardDark = false;
  bool _textDark = true;

  PhotoMetadata _metadata = const PhotoMetadata();

  ui.Image? _preview;
  Timer? _previewTimer;
  int _previewGen = 0;
  int _tab = 0;

  /// 每格图片的移动/缩放（与 _images 一一对应）。
  final List<CollageImageTransform> _transforms = [];

  /// 当前选中的单元格（手势高亮）。
  int? _activeIndex;
  int? _gestureIndex;
  double _gestureStartScale = 1.0;
  Offset _gestureStartOffset = Offset.zero;
  Offset? _gestureStartFocal;
  Offset? _doubleTapPos;

  CollageLayout get _layout => CollageLayout(
        template: _template,
        aspect: _aspect,
        border: _border,
      );

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _preview?.dispose();
    for (final img in _images) {
      img.dispose();
    }
    super.dispose();
  }

  Future<void> _loadImages() async {
    final images = <ui.Image>[];
    final skipped = <String>[];
    Uint8List? firstBytes;
    for (final item in widget.items) {
      try {
        final file = await ExportHistoryManager().ensureLocalFile(item);
        final bytes = await file.readAsBytes();
        firstBytes ??= bytes;
        images.add(await WatermarkRenderer.decodeImageFromBytes(bytes));
      } catch (_) {
        skipped.add(item.fileName);
      }
    }

    if (!mounted) {
      for (final img in images) {
        img.dispose();
      }
      return;
    }

    if (images.length < 2) {
      for (final img in images) {
        img.dispose();
      }
      if (mounted) {
        final l10n = context.l10n;
        final zc = context.zc;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.collageInsufficientPhotos),
            backgroundColor: zc.danger,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // 拼图最多 9 张；超出的素材直接丢弃，避免无可用版式。
    if (images.length > 9) {
      for (final img in images.sublist(9)) {
        img.dispose();
      }
      images.removeRange(9, images.length);
    }

    PhotoMetadata meta = widget.fallbackMetadata ?? const PhotoMetadata();
    if (firstBytes != null) {
      try {
        meta = _mergeMeta(
            await ExifHelper.parseBytes(firstBytes), widget.fallbackMetadata);
      } catch (_) {}
    }

    _images
      ..clear()
      ..addAll(images);
    _transforms
      ..clear()
      ..addAll(List<CollageImageTransform>.filled(
          images.length, CollageImageTransform.identity));
    setState(() {
      _metadata = meta;
      _template = CollageTemplate.forCount(images.length).first;
      _loading = false;
    });

    if (skipped.isNotEmpty && mounted) {
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.collageSkippedUnreadableToast(skipped.length)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _rebuildPreview();
  }

  /// 优先采用真实 EXIF 解析结果，缺失字段用外部回退值补齐。
  PhotoMetadata _mergeMeta(PhotoMetadata parsed, PhotoMetadata? fallback) {
    if (fallback == null) return parsed;
    String pick(String a, String b) => a.isNotEmpty ? a : b;
    return PhotoMetadata(
      cameraMake: pick(parsed.cameraMake, fallback.cameraMake),
      cameraModel: pick(parsed.cameraModel, fallback.cameraModel),
      lensModel: pick(parsed.lensModel, fallback.lensModel),
      shutterSpeed: pick(parsed.shutterSpeed, fallback.shutterSpeed),
      aperture: pick(parsed.aperture, fallback.aperture),
      iso: pick(parsed.iso, fallback.iso),
      focalLength: pick(parsed.focalLength, fallback.focalLength),
      capturedDate: pick(parsed.capturedDate, fallback.capturedDate),
    );
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 120), _rebuildPreview);
  }

  /// 合成带水印的预览位图。仅在选了水印模板时需要（布局页直接绘制拼图，无需位图）。
  Future<void> _rebuildPreview() async {
    if (_images.isEmpty || _wmTemplate == WatermarkTemplate.none) return;
    final gen = ++_previewGen;
    try {
      final img = await CollageRenderer.compose(
        images: _images,
        layout: _layout,
        transforms: _transforms,
        drawOuterFrame: false,
        maxDimension: 1024,
      );
      if (!mounted || gen != _previewGen) {
        img.dispose();
        return;
      }
      final old = _preview;
      setState(() => _preview = img);
      old?.dispose();
    } catch (_) {
      // 预览失败不阻塞编辑，保存时会重新合成并提示。
    }
  }

  /// 布局变化后按新的单元格重新夹取各格变换，避免越界露白。
  void _reclampTransforms() {
    final cells = _layout.imageCells(
        drawOuterFrame: _wmTemplate == WatermarkTemplate.none);
    for (var i = 0;
        i < _transforms.length && i < cells.length && i < _images.length;
        i++) {
      final img = _images[i];
      _transforms[i] = clampCollageTransform(
        Size(img.width.toDouble(), img.height.toDouble()),
        cells[i],
        _transforms[i],
      );
    }
  }

  void _resetTransforms() {
    setState(() {
      for (var i = 0; i < _transforms.length; i++) {
        _transforms[i] = CollageImageTransform.identity;
      }
      _activeIndex = null;
    });
    _schedulePreview();
  }

  // ------------------------------------------------------------------
  // 保存：全尺寸合成 → 水印渲染 → 写入系统相册
  // ------------------------------------------------------------------
  Future<void> _save() async {
    if (_isExporting || _images.length < 2) return;
    setState(() => _isExporting = true);
    ui.Image? full;
    try {
      full = await CollageRenderer.compose(
        images: _images,
        layout: _layout,
        transforms: _transforms,
        drawOuterFrame: _wmTemplate == WatermarkTemplate.none,
      );
      final ws = AppSettings.instance;
      final result = await WatermarkRenderer.exportWatermarkedPhoto(
        sourceImage: full,
        metadata: _metadata,
        template: _wmTemplate,
        spacingScale: ws.watermarkSpacingScale,
        showDetails: ws.watermarkShowDetails,
        cardDark: _cardDark,
        textDark: _textDark,
        cardColorOverride: ws.watermarkCardColorValue == null
            ? null
            : ZSwatch.fromArgb32(ws.watermarkCardColorValue!),
        textColorOverride: ws.watermarkTextColorValue == null
            ? null
            : ZSwatch.fromArgb32(ws.watermarkTextColorValue!),
        titleTextScale: ws.watermarkTitleTextScale,
        metaTextScale: ws.watermarkMetaTextScale,
        letterSpacingScale: ws.watermarkLetterSpacingScale,
        lineSpacingScale: ws.watermarkLineSpacingScale,
        fontWeight: WatermarkFontWeight.values[ws.watermarkFontWeightIndex],
        borderThicknessScale: ws.watermarkBorderThicknessScale,
        accentColor: ZSwatch.fromArgb32(ws.watermarkAccentColorValue),
        cornerRadiusFactor: ws.watermarkCornerRadiusFactor,
        showModel: ws.watermarkShowModel,
        showLens: ws.watermarkShowLens,
        showExposure: ws.watermarkShowExposure,
        showDate: ws.watermarkShowDate,
        watermarkOpacity: ws.watermarkOpacity,
      );
      final outWidth = result.width;
      final outHeight = result.height;
      final outBytes = result.byteLength;

      try {
        final name = result.file.uri.pathSegments.last;
        final uri =
            await CameraNativeBridge.saveMediaToGallery(result.file.path, name);
        if (uri == null || uri.isEmpty) {
          throw StateError(
            mounted ? context.l10n.wmSaveAlbumFailed : 'Save failed',
          );
        }
        ExportHistoryManager().registerExported(name, result.file, uri);
      } finally {
        if (await result.file.exists()) await result.file.delete();
      }

      if (!mounted) return;
      await _showSavedDialog(outWidth, outHeight, outBytes);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final zc = context.zc;
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.wmExportFailedToast(e.toString())),
            backgroundColor: zc.danger,
          ),
        );
      }
    } finally {
      full?.dispose();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// 保存成功提示（与水印工坊导出提示同款）。点「完成」返回相册。
  Future<void> _showSavedDialog(int width, int height, int byteLength) {
    final zc = context.zc;
    final l10n = context.l10n;
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('$label: $value',
              style: TextStyle(color: zc.textSecondary, fontSize: 13)),
        );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: zc.surfaceHigh,
        shape: const RoundedRectangleBorder(borderRadius: ZRadius.brLg),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: zc.success, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l10n.collageSaveSuccessTitle,
                  style: TextStyle(
                      color: zc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line(l10n.collageMethodLabel, _template.trLabel),
            line(l10n.collageAspectLabel, _aspect.label),
            line(l10n.collageBorderLabel, _border.trLabel),
            line(
              l10n.collageTabWatermark,
              _wmTemplate == WatermarkTemplate.none
                  ? l10n.collageNoWatermark
                  : _wmTemplate.trLabel,
            ),
            line(l10n.collageOutputResolution, '$width × $height'),
            line(l10n.collageFileSize,
                '${(byteLength / 1024 / 1024).toStringAsFixed(2)} MB'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: zc.surfaceMid,
                borderRadius: ZRadius.brSm,
                border: Border.all(color: zc.outline),
              ),
              child: Text(
                l10n.collageSaveSuccessBody,
                style: TextStyle(color: zc.accent, fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonDone,
                style:
                    TextStyle(color: zc.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        title: Text(l10n.collageTitle),
        leadingWidth: 72,
        leading: TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: Text(l10n.commonCancel,
              style: TextStyle(color: zc.textSecondary, fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: _isExporting || _loading ? null : _save,
            child: _isExporting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: zc.accent),
                  )
                : Text(l10n.commonSave,
                    style: TextStyle(
                        color: zc.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
        final panel = _tab == 0
            ? _buildLayoutPanel(wide: wide)
            : _buildWatermarkPanel(wide: wide);
        // 宽屏：预览在左，操作面板收进右侧固定宽度侧栏。
        if (constraints.maxWidth >= kAdaptiveRailBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildPreview()),
              const VerticalDivider(width: 1),
              SizedBox(
                key: const ValueKey('adaptiveSidePanel'),
                width: adaptiveSidePanelWidth(constraints.maxWidth),
                child: Column(
                    children: [Expanded(child: panel), _buildBottomTabs()]),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: _buildPreview()),
            SizedBox(
              height: math.min(
                  216, math.max(150, MediaQuery.sizeOf(context).height * 0.42)),
              child: panel,
            ),
            _buildBottomTabs(),
          ],
        );
      }),
    );
  }

  Widget _buildPreview() {
    final zc = context.zc;
    final l10n = context.l10n;
    if (_loading) {
      return Container(
        color: zc.canvas,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(zc.accent),
              ),
              const SizedBox(height: 12),
              Text(l10n.collagePreparingMaterials,
                  style: TextStyle(color: zc.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
    }
    return Container(
      color: zc.canvas,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 选了水印模板时展示合成位图（所见即所得）；否则直接绘制拼图（可手势编辑）。
          final raster = _preview;
          final showRaster =
              raster != null && _wmTemplate != WatermarkTemplate.none;
          final double aspect;
          if (showRaster) {
            final l = WatermarkCanvasPainter.computeLayout(
              raster.width.toDouble(),
              raster.height.toDouble(),
              _wmTemplate,
              1.0,
            );
            aspect = l.totalWidth / l.totalHeight;
          } else {
            final full = _layout.canvasSize;
            aspect = full.width / full.height;
          }
          var w = constraints.maxWidth;
          var h = w / aspect;
          if (h > constraints.maxHeight) {
            h = constraints.maxHeight;
            w = h * aspect;
          }
          final size = Size(w, h);
          final Widget child = showRaster
              ? CustomPaint(
                  size: size,
                  painter: WatermarkCanvasPainter(
                    image: raster,
                    metadata: _metadata,
                    template: _wmTemplate,
                    spacingScale: AppSettings.instance.watermarkSpacingScale,
                    showDetails: AppSettings.instance.watermarkShowDetails,
                    cardDark: _cardDark,
                    textDark: _textDark,
                    cardColorOverride:
                        AppSettings.instance.watermarkCardColorValue == null
                            ? null
                            : ZSwatch.fromArgb32(AppSettings
                                .instance.watermarkCardColorValue!),
                    textColorOverride:
                        AppSettings.instance.watermarkTextColorValue == null
                            ? null
                            : ZSwatch.fromArgb32(AppSettings
                                .instance.watermarkTextColorValue!),
                    titleTextScale:
                        AppSettings.instance.watermarkTitleTextScale,
                    metaTextScale: AppSettings.instance.watermarkMetaTextScale,
                    letterSpacingScale:
                        AppSettings.instance.watermarkLetterSpacingScale,
                    lineSpacingScale:
                        AppSettings.instance.watermarkLineSpacingScale,
                    fontWeight: WatermarkFontWeight.values[
                        AppSettings.instance.watermarkFontWeightIndex],
                    borderThicknessScale:
                        AppSettings.instance.watermarkBorderThicknessScale,
                    accentColor: ZSwatch.fromArgb32(
                        AppSettings.instance.watermarkAccentColorValue),
                    cornerRadiusFactor:
                        AppSettings.instance.watermarkCornerRadiusFactor,
                    showModel: AppSettings.instance.watermarkShowModel,
                    showLens: AppSettings.instance.watermarkShowLens,
                    showExposure: AppSettings.instance.watermarkShowExposure,
                    showDate: AppSettings.instance.watermarkShowDate,
                    watermarkOpacity: AppSettings.instance.watermarkOpacity,
                  ),
                )
              : _buildInteractiveCanvas(size, interactive: _tab == 0);
          return Center(
            child: SizedBox(width: w, height: h, child: child),
          );
        },
      ),
    );
  }

  /// 拼图画布。布局页可交互（单指拖动移动、双指捏合缩放、双击重置该格）；
  /// 水印页只做效果预览，不接手势。
  Widget _buildInteractiveCanvas(Size previewSize, {bool interactive = true}) {
    final zc = context.zc;
    final canvas = CustomPaint(
      size: previewSize,
      painter: CollagePainter(
        images: _images,
        layout: _layout,
        transforms: _transforms,
        drawOuterFrame: _wmTemplate == WatermarkTemplate.none,
        activeIndex: _activeIndex,
        highlightColor: zc.accent,
      ),
    );
    if (!interactive) return canvas;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) => _onGestureStart(d.localFocalPoint, previewSize),
      onScaleUpdate: (d) => _onGestureUpdate(d, previewSize),
      onScaleEnd: (_) => _onGestureEnd(),
      onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
      onDoubleTap: () => _onDoubleTap(previewSize),
      child: canvas,
    );
  }

  /// 预览坐标 → 拼图画布坐标。
  Offset _toCanvas(Offset local, Size previewSize) {
    if (previewSize.width <= 0) return local;
    final k = _layout.canvasSize.width / previewSize.width;
    return Offset(local.dx * k, local.dy * k);
  }

  /// 命中测试：返回触点所在的单元格下标。
  int? _cellIndexAt(Offset local, Size previewSize) {
    final p = _toCanvas(local, previewSize);
    if (_layout.isDiagonal) {
      final polys = _layout.diagonalPolys;
      for (var i = 0; i < polys.length && i < _images.length; i++) {
        if ((Path()..addPolygon(polys[i], true)).contains(p)) return i;
      }
      return null;
    }
    final cells = _layout.cellRects;
    for (var i = 0; i < cells.length && i < _images.length; i++) {
      if (cells[i].contains(p)) return i;
    }
    return null;
  }

  void _onGestureStart(Offset local, Size previewSize) {
    final idx = _cellIndexAt(local, previewSize);
    _gestureIndex = idx;
    _gestureStartFocal = local;
    if (idx != null && idx < _transforms.length) {
      _gestureStartScale = _transforms[idx].scale;
      _gestureStartOffset = _transforms[idx].offset;
      setState(() => _activeIndex = idx);
    }
  }

  void _onGestureUpdate(ScaleUpdateDetails d, Size previewSize) {
    final idx = _gestureIndex;
    if (idx == null || idx >= _transforms.length || idx >= _images.length) {
      return;
    }
    final cells = _layout.imageCells(
        drawOuterFrame: _wmTemplate == WatermarkTemplate.none);
    if (idx >= cells.length) return;
    final cell = cells[idx];
    if (cell.width <= 0 || cell.height <= 0) return;

    final startFocal = _gestureStartFocal ?? d.localFocalPoint;
    final k = previewSize.width <= 0
        ? 1.0
        : _layout.canvasSize.width / previewSize.width;
    final delta = (d.localFocalPoint - startFocal) * k;
    final img = _images[idx];
    final next = clampCollageTransform(
      Size(img.width.toDouble(), img.height.toDouble()),
      cell,
      CollageImageTransform(
        scale: _gestureStartScale * d.scale,
        offset: _gestureStartOffset +
            Offset(delta.dx / cell.width, delta.dy / cell.height),
      ),
    );
    setState(() => _transforms[idx] = next);
  }

  void _onGestureEnd() {
    _gestureIndex = null;
    _gestureStartFocal = null;
  }

  void _onDoubleTap(Size previewSize) {
    final pos = _doubleTapPos;
    if (pos == null) return;
    final idx = _cellIndexAt(pos, previewSize);
    if (idx == null || idx >= _transforms.length) return;
    setState(() {
      _transforms[idx] = CollageImageTransform.identity;
      _activeIndex = idx;
    });
  }

  Widget _buildLayoutPanel({bool wide = false}) {
    final zc = context.zc;
    final l10n = context.l10n;
    final templates = CollageTemplate.forCount(_images.length);
    final hasWatermark = _wmTemplate != WatermarkTemplate.none;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasWatermark)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                l10n.collageWatermarkDragHint,
                style: TextStyle(color: zc.textTertiary, fontSize: 11),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, hasWatermark ? 6 : 10, 16, 6),
            child: Row(
              children: [
                _panelLabel(l10n.collageBorderLabel),
                const SizedBox(width: 10),
                Expanded(
                  child: SegmentedButton<CollageBorder>(
                    segments: CollageBorder.values
                        .map((b) =>
                            ButtonSegment(value: b, label: Text(b.trLabel)))
                        .toList(),
                    selected: {_border},
                    onSelectionChanged: (s) => setState(() {
                      _border = s.first;
                      _reclampTransforms();
                      _schedulePreview();
                    }),
                    style: _segStyle(),
                    showSelectedIcon: false,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _panelLabel(l10n.collageAspectLabel),
                SegmentedButton<CollageAspect>(
                  segments: CollageAspect.values
                      .map((a) => ButtonSegment(value: a, label: Text(a.label)))
                      .toList(),
                  selected: {_aspect},
                  onSelectionChanged: (s) => setState(() {
                    _aspect = s.first;
                    _reclampTransforms();
                    _schedulePreview();
                  }),
                  style: _segStyle(),
                  showSelectedIcon: false,
                ),
                TextButton.icon(
                  onPressed: _resetTransforms,
                  icon:
                      Icon(Icons.restart_alt, size: 15, color: zc.textSecondary),
                  label: Text(l10n.commonReset,
                      style:
                          TextStyle(color: zc.textSecondary, fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (wide)
            // 宽屏侧栏高度充足：布局方式自适应换行展示，不再左右滑动。
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [for (final t in templates) _layoutThumb(t)],
              ),
            )
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _layoutThumb(templates[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _layoutThumb(CollageTemplate t) {
    final zc = context.zc;
    final selected = t == _template;
    final accent = selected ? zc.accent : zc.textTertiary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _template = t;
        _reclampTransforms();
        _schedulePreview();
      }),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 缩略图比例严格跟随导出比例（1:1 方 / 3:4 竖）。
            SizedBox(
              height: 54,
              child: AspectRatio(
                key: ValueKey<String>('collage_thumb_box_${t.id}'),
                aspectRatio: _aspect.w / _aspect.h,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: zc.surfaceMid,
                    borderRadius: ZRadius.brSm,
                    border: Border.all(
                      color: selected ? zc.accent : zc.outline,
                      width: selected ? ZStroke.emphasis : ZStroke.hairline,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _CollageThumbPainter(template: t, color: accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.trLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? zc.accent : zc.textSecondary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectWatermarkTemplate(WatermarkTemplate t) {
    final ws = AppSettings.instance;
    setState(() {
      _wmTemplate = t;
      if (ws.watermarkCardColorValue == null) {
        _cardDark = t.defaultCardDark;
      }
      if (ws.watermarkTextColorValue == null) {
        _textDark = t.defaultTextDark;
      }
    });
    _schedulePreview();
  }

  Future<void> _showWatermarkStyleSheet() async {
    final zc = context.zc;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: zc.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (ctx) {
        final sheetZc = ctx.zc;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                18, 16, 18, 18 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.wmSettingsSheetTitle,
                      style: TextStyle(
                          color: sheetZc.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(l10n.collageSharedWatermarkSub,
                      style: TextStyle(
                          color: sheetZc.textSecondary, fontSize: 11)),
                  const SizedBox(height: 14),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: WatermarkStyleControls(
                        onChanged: () {
                          if (mounted) setState(() {});
                          _schedulePreview();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonDone),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWatermarkPanel({bool wide = false}) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wide)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in WatermarkTemplate.values)
                    SizedBox(
                      width: 168,
                      height: 58,
                      child: WatermarkTemplateCard(
                        template: t,
                        isSelected: t == _wmTemplate,
                        onTap: () => _selectWatermarkTemplate(t),
                      ),
                    ),
                ],
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: WatermarkTemplate.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = WatermarkTemplate.values[i];
                  return SizedBox(
                    width: 200,
                    child: WatermarkTemplateCard(
                      template: t,
                      isSelected: t == _wmTemplate,
                      onTap: () => _selectWatermarkTemplate(t),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: WatermarkColorPickerRow(
              label: l10n.wmBorderColorShort,
              value: AppSettings.instance.watermarkCardColorValue,
              onChanged: (v) {
                AppSettings.instance.updateWatermarkStyle(cardColorValue: v);
                setState(() {
                  if (v == null) _cardDark = _wmTemplate.defaultCardDark;
                });
                _schedulePreview();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: WatermarkColorPickerRow(
              label: l10n.wmTextColorShort,
              value: AppSettings.instance.watermarkTextColorValue,
              onChanged: (v) {
                AppSettings.instance.updateWatermarkStyle(textColorValue: v);
                setState(() {
                  if (v == null) _textDark = _wmTemplate.defaultTextDark;
                });
                _schedulePreview();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _showWatermarkStyleSheet,
                icon: const Icon(Icons.tune, size: 16),
                label: Text(l10n.wmDetailSettingsShort),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabs() {
    final zc = context.zc;
    final l10n = context.l10n;
    Widget tab(int index, String label) {
      final active = _tab == index;
      return Expanded(
        child: InkWell(
          onTap: () {
            // 切到水印页需要合成位图；切回布局页则清掉高亮。
            setState(() {
              _tab = index;
              if (index == 0) _activeIndex = null;
            });
            if (index == 1) _schedulePreview();
          },
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? zc.accent : zc.textSecondary,
                fontSize: 14,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: zc.surfaceLow,
        border: Border(
          top: BorderSide(color: zc.outline, width: ZStroke.hairline),
        ),
      ),
      child: Row(children: [
        tab(0, l10n.collageTabLayout),
        tab(1, l10n.collageTabWatermark),
      ]),
    );
  }

  Widget _panelLabel(String text) => Text(
        text,
        style: TextStyle(color: context.zc.textSecondary, fontSize: 12),
      );

  /// 分段选择器样式。
  ButtonStyle _segStyle() {
    final zc = context.zc;
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? zc.accent
            : zc.surfaceMid,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? zc.onAccent
            : zc.textSecondary,
      ),
      side: WidgetStateProperty.all(
        BorderSide(color: zc.outline, width: ZStroke.hairline),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// 拼接方式缩略示意图：把归一化单元格直接画进小方块。
class _CollageThumbPainter extends CustomPainter {
  final CollageTemplate template;
  final Color color;

  _CollageThumbPainter({required this.template, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (template.isDiagonal) {
      final y1 = (0.5 - kCollageDiagonalSlant) * size.height;
      final y2 = (0.5 + kCollageDiagonalSlant) * size.height;
      final top = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, y2)
        ..lineTo(0, y1)
        ..close();
      final bottom = Path()
        ..moveTo(0, y1)
        ..lineTo(size.width, y2)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(top, Paint()..color = color.withAlpha(150));
      canvas.drawPath(bottom, Paint()..color = color.withAlpha(70));
      return;
    }
    final paint = Paint()..color = color;
    const gap = 1.5;
    for (final r in template.cells) {
      final rect = Rect.fromLTRB(r.left * size.width, r.top * size.height,
              r.right * size.width, r.bottom * size.height)
          .deflate(gap / 2);
      if (rect.width > 0 && rect.height > 0) canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CollageThumbPainter old) =>
      old.template != template || old.color != color;
}
