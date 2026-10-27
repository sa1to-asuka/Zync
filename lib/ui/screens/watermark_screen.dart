import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/editor/builtin_grade_presets.dart';
import '../../engine/editor/color_grade_preset.dart';
import '../../engine/editor/photo_edit_controller.dart';
import '../../engine/editor/pro_photo_models.dart';
import '../../engine/editor/raw_processor_bridge.dart';
import '../../engine/filter/photo_filter.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../engine/watermark/watermark_painter.dart';
import '../../engine/watermark/watermark_renderer.dart';
import '../../engine/watermark/watermark_template.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/nikon_ble_lss.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/grade_thumbnail.dart';
import '../widgets/lightroom_histogram.dart';
import '../widgets/photo_edit_preview.dart';
import '../widgets/photo_edit_tools.dart';
import '../widgets/watermark_style_controls.dart';
import '../widgets/watermark_template_card.dart';

part 'watermark/watermark_grade_panel.dart';
part 'watermark/watermark_sheets.dart';

/// 摄影画廊级水印工坊与胶片调色工作室
class WatermarkScreen extends StatefulWidget {
  final Uint8List? initialImageBytes;
  final PhotoMetadata? initialMetadata;

  const WatermarkScreen({
    super.key,
    this.initialImageBytes,
    this.initialMetadata,
  });

  @override
  State<WatermarkScreen> createState() => WatermarkScreenState();
}

class WatermarkScreenState extends State<WatermarkScreen>
    with SingleTickerProviderStateMixin {
  void _updateState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  double _panelHeight(BuildContext context) => math.min(
      MediaQuery.orientationOf(context) == Orientation.landscape
          ? (_tabController.index == 3 ? 204.0 : 210.0)
          : (_tabController.index == 3 ? 270.0 : 330.0),
      MediaQuery.sizeOf(context).height * .48);

  ui.Image? get _decodedImage => _editController.previewImage;

  final PhotoEditController _editController = PhotoEditController();
  PhotoEditTool _editTool = PhotoEditTool.rotate;
  double get _editCropAspect => _editController.value.cropAspect;

  bool _isLoadingImage = false;
  String? _rawSourcePath;

  WatermarkTemplate _selectedTemplate = WatermarkTemplate.none;
  PhotoFilterType _selectedFilter = PhotoFilterType.original;
  double _filterIntensity = 1.0;
  PhotoEditAdjustments _adjustments = const PhotoEditAdjustments();
  ColorGrade _proGrade = const ColorGrade();
  HistogramZone? _activeHistogramZone;
  bool _isComparingOriginal = false;
  List<int>? _sampledR;
  List<int>? _sampledG;
  List<int>? _sampledB;
  double _spacingScale = 1.0;
  bool _showDetails = true;

  bool _cardDark = false;
  bool _textDark = true;
  String _fontChoice = 'default';
  bool _isExporting = false;

  ui.Image? _logoImage;
  int _logoScaleIndex = 1;
  int _logoOpacityIndex = 0;

  static const List<double> _logoScales = [0.10, 0.16, 0.24];
  static const List<double> _logoOpacities = [1.0, 0.7, 0.4];

  Color _accentColor = ZSwatch.nikonGold;
  Color? _cardColorOverride;
  Color? _textColorOverride;
  double _cornerRadiusFactor = 1.0;
  bool _showModel = true;
  bool _showLens = true;
  bool _showExposure = true;
  bool _showDate = true;
  bool _showBrandLogo = true;
  bool _showGps = true;
  double _watermarkOpacity = 1.0;
  WatermarkTextAlign _customTextAlign = WatermarkTextAlign.left;
  WatermarkLogoCorner _logoCorner = WatermarkLogoCorner.bottomRight;

  int _templateSubTab = 0;
  bool _showHistogramHud = false;
  String _activeParamCode = 'Exposure';
  String _filterCategory = 'preset';

  List<String> get _customLines => [
        AppSettings.instance.watermarkCustomLine1.trim(),
        AppSettings.instance.watermarkCustomLine2.trim(),
      ].where((e) => e.isNotEmpty).toList();

  String? get _watermarkFontFamily {
    switch (_fontChoice) {
      case 'serif':
        return 'serif';
      case 'mono':
        return 'monospace';
      case 'condensed':
        return 'sans-serif-condensed';
      default:
        return null;
    }
  }

  PhotoMetadata _metadata = const PhotoMetadata(
    cameraMake: 'Nikon',
    cameraModel: 'Z 30',
    lensModel: 'NIKKOR Z 40mm f/2',
    shutterSpeed: '1/250s',
    aperture: 'f/2.0',
    iso: 'ISO 100',
    focalLength: '40mm',
    capturedDate: '2026.10.06 14:32',
  );

  late final TabController _tabController;
  final ScrollController _wmScrollController = ScrollController();
  final ScrollController _filterScrollController = ScrollController();
  final PageController _wmPageController = PageController();
  final PageController _filterPageController = PageController();
  int _wmCurrentPage = 0;
  int _filterCurrentPage = 0;
  int _tabletWatermarkSection = 0;

  @override
  void initState() {
    super.initState();
    _syncStyleFromSettings();
    _tabController = TabController(length: 4, vsync: this);
    _editController.addListener(_onEditChanged);
    _tabController.addListener(_onTabChanged);

    if (widget.initialImageBytes != null) {
      loadImageBytes(widget.initialImageBytes!, widget.initialMetadata);
    }
  }

  @override
  void dispose() {
    _editController.removeListener(_onEditChanged);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _editController.dispose();
    _wmScrollController.dispose();
    _filterScrollController.dispose();
    _wmPageController.dispose();
    _filterPageController.dispose();
    super.dispose();
  }

  void _onEditChanged() {
    if (mounted) setState(() {});
  }

  void _syncStyleFromSettings() {
    final s = AppSettings.instance;
    _spacingScale = s.watermarkSpacingScale;
    _showDetails = s.watermarkShowDetails;
    _fontChoice = s.watermarkFontChoice;
    _accentColor = ZSwatch.fromArgb32(s.watermarkAccentColorValue);
    _cardColorOverride = s.watermarkCardColorValue == null
        ? null
        : ZSwatch.fromArgb32(s.watermarkCardColorValue!);
    _textColorOverride = s.watermarkTextColorValue == null
        ? null
        : ZSwatch.fromArgb32(s.watermarkTextColorValue!);
    _cornerRadiusFactor = s.watermarkCornerRadiusFactor;
    _showModel = s.watermarkShowModel;
    _showLens = s.watermarkShowLens;
    _showExposure = s.watermarkShowExposure;
    _showDate = s.watermarkShowDate;
    _showBrandLogo = s.watermarkShowBrandLogo;
    _showGps = s.watermarkShowGps;
    _watermarkOpacity = s.watermarkOpacity;
    _logoScaleIndex = _nearestIndex(_logoScales, s.watermarkLogoScale);
    _logoOpacityIndex = _nearestIndex(_logoOpacities, s.watermarkLogoOpacity);
    _customTextAlign = WatermarkTextAlign.values.firstWhere(
      (e) => e.name == s.watermarkTextAlign,
      orElse: () => WatermarkTextAlign.left,
    );
    _logoCorner = WatermarkLogoCorner.values.firstWhere(
      (e) => e.name == s.watermarkLogoCorner,
      orElse: () => WatermarkLogoCorner.bottomRight,
    );
    if (mounted) setState(() {});
  }

  static int _nearestIndex(List<double> values, double target) {
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < values.length; i++) {
      final d = (values[i] - target).abs();
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  void _onTabChanged() {
    _editController.setCropOverlay(_tabController.index == 3 &&
        (_editTool == PhotoEditTool.crop ||
            _editTool == PhotoEditTool.distort));
    if (mounted) setState(() {});
  }

  Future<void> loadImageBytes(
    Uint8List bytes, [
    PhotoMetadata? metadata,
  ]) async {
    _editController.reset();
    setState(() => _isLoadingImage = true);
    GradeThumbnailCache.clear();
    try {
      await _editController.load(bytes);
      if (!mounted) return;
      final decoded = _decodedImage;
      if (decoded == null) {
        throw StateError(
          _editController.renderError ?? context.l10n.wmDecodeImageFailed,
        );
      }
      final parsed = await ExifHelper.parseBytes(bytes);
      final PhotoMetadata meta;
      if (metadata != null) {
        meta = PhotoMetadata(
          cameraMake: parsed.cameraMake.isNotEmpty
              ? parsed.cameraMake
              : (metadata.cameraMake.isNotEmpty
                  ? metadata.cameraMake
                  : 'Nikon'),
          cameraModel: parsed.cameraModel.isNotEmpty
              ? parsed.cameraModel
              : metadata.cameraModel,
          lensModel: parsed.lensModel.isNotEmpty
              ? parsed.lensModel
              : metadata.lensModel,
          shutterSpeed: parsed.shutterSpeed.isNotEmpty
              ? parsed.shutterSpeed
              : metadata.shutterSpeed,
          aperture:
              parsed.aperture.isNotEmpty ? parsed.aperture : metadata.aperture,
          iso: parsed.iso.isNotEmpty ? parsed.iso : metadata.iso,
          focalLength: parsed.focalLength.isNotEmpty
              ? parsed.focalLength
              : metadata.focalLength,
          capturedDate: parsed.capturedDate.isNotEmpty
              ? parsed.capturedDate
              : metadata.capturedDate,
          latitude: parsed.latitude ??
              metadata.latitude ??
              NikonBleLss.sessionLatitude,
          longitude: parsed.longitude ??
              metadata.longitude ??
              NikonBleLss.sessionLongitude,
          altitude: parsed.altitude ??
              metadata.altitude ??
              NikonBleLss.sessionAltitude,
        );
      } else {
        meta = parsed.hasGps
            ? parsed
            : parsed.copyWith(
                latitude: NikonBleLss.sessionLatitude,
                longitude: NikonBleLss.sessionLongitude,
                altitude: NikonBleLss.sessionAltitude,
              );
      }

      List<int>? rList;
      List<int>? gList;
      List<int>? bList;
      try {
        final byteData =
            await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          final w = decoded.width;
          final h = decoded.height;
          final stepX = math.max(1, w ~/ 48);
          final stepY = math.max(1, h ~/ 48);
          final rBuf = <int>[];
          final gBuf = <int>[];
          final bBuf = <int>[];
          final raw = byteData.buffer.asUint8List();
          for (int y = 0; y < h; y += stepY) {
            for (int x = 0; x < w; x += stepX) {
              final idx = (y * w + x) * 4;
              if (idx + 2 < raw.length) {
                rBuf.add(raw[idx]);
                gBuf.add(raw[idx + 1]);
                bBuf.add(raw[idx + 2]);
              }
            }
          }
          rList = rBuf;
          gList = gBuf;
          bList = bBuf;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _metadata = meta;
        _sampledR = rList;
        _sampledG = gList;
        _sampledB = bList;
        _isLoadingImage = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingImage = false);
      if (mounted) {
        showZToast(
          context,
          context.l10n.wmParseImageFailed('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  void setRawSourcePath(String? path) {
    _rawSourcePath = path;
  }

  void showFilterTab() {
    if (mounted) {
      setState(() {
        _selectedTemplate = WatermarkTemplate.none;
      });
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    final path = await CameraNativeBridge.pickImageFromGallery();
    if (path == null || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    await loadImageBytes(bytes);

    if (mounted) {
      showZToast(
        context,
        context.l10n.wmImportedExifToast(_metadata.titleText),
        tone: ZStatusTone.success,
      );
    }
  }

  Future<void> _exportPhoto() async {
    if (_decodedImage == null) {
      showZToast(
        context,
        context.l10n.wmSelectPhotoFirstHint,
        tone: ZStatusTone.warning,
      );
      return;
    }

    setState(() => _isExporting = true);
    ui.Image? fullImage;
    try {
      Uint8List bytes;
      if (_rawSourcePath != null && _rawSourcePath!.isNotEmpty) {
        final raw = await RawProcessorBridge.renderFull(
          path: _rawSourcePath!,
          filterType: _selectedFilter,
          filterIntensity: _filterIntensity,
          adjustments: _adjustments,
          grade: _proGrade.copyWith(base: _adjustments),
          jpegQuality: AppSettings.instance.exportQuality,
        );
        if (raw.bytes.isEmpty) {
          throw StateError(
            mounted ? context.l10n.wmRawFullDecodeFailed : 'RAW decode failed',
          );
        }
        bytes = raw.bytes;
      } else {
        bytes = await _editController.renderFull();
      }
      fullImage = await WatermarkRenderer.decodeImageFromBytes(bytes);
      final result = await WatermarkRenderer.exportWatermarkedPhoto(
        sourceImage: fullImage,
        metadata: _metadata,
        template: _selectedTemplate,
        filterType: _selectedFilter,
        filterIntensity: _filterIntensity,
        adjustments: _rawSourcePath != null
            ? const PhotoEditAdjustments()
            : _adjustments,
        spacingScale: _spacingScale,
        showDetails: _showDetails,
        cardDark: _cardDark,
        textDark: _textDark,
        cardColorOverride: _cardColorOverride,
        textColorOverride: _textColorOverride,
        titleTextScale: AppSettings.instance.watermarkTitleTextScale,
        metaTextScale: AppSettings.instance.watermarkMetaTextScale,
        letterSpacingScale: AppSettings.instance.watermarkLetterSpacingScale,
        lineSpacingScale: AppSettings.instance.watermarkLineSpacingScale,
        fontWeight: WatermarkFontWeight
            .values[AppSettings.instance.watermarkFontWeightIndex],
        borderThicknessScale:
            AppSettings.instance.watermarkBorderThicknessScale,
        fontFamily: _watermarkFontFamily,
        jpegQuality: AppSettings.instance.exportQuality,
        customLines: _customLines,
        customTextScale: AppSettings.instance.watermarkCustomTextScale,
        logoImage: _logoImage,
        logoScale: _logoScales[_logoScaleIndex],
        logoOpacity: _logoOpacities[_logoOpacityIndex],
        accentColor: _accentColor,
        cardTone: WatermarkCardTone.auto,
        cornerRadiusFactor: _cornerRadiusFactor,
        showModel: _showModel,
        showLens: _showLens,
        showExposure: _showExposure,
        showDate: _showDate,
        showBrandLogo: _showBrandLogo,
        showGps: _showGps,
        watermarkOpacity: _watermarkOpacity,
        customTextAlign: _customTextAlign,
        logoCorner: _logoCorner,
      );

      String? savedUri;
      try {
        final name = result.file.uri.pathSegments.last;
        savedUri =
            await CameraNativeBridge.saveMediaToGallery(result.file.path, name);
        if (savedUri == null || savedUri.isEmpty) {
          throw StateError(
            mounted ? context.l10n.wmSaveAlbumFailed : 'Save failed',
          );
        }
        ExportHistoryManager().registerExported(name, result.file, savedUri);
      } finally {
        if (await result.file.exists()) await result.file.delete();
      }

      if (mounted) {
        final l10n = context.l10n;
        final sizeMb = (result.byteLength / 1024 / 1024).toStringAsFixed(1);
        final qLabel = L10n.tr(
          AppSettings.exportQualityLabel(AppSettings.instance.exportQuality),
          l10n.localeName,
        );
        showZToast(
          context,
          '${l10n.wmSavedSuccessToast(result.width, result.height, sizeMb)} · $qLabel',
          tone: ZStatusTone.success,
          action: SnackBarAction(
            label: l10n.wmViewInAlbumAction,
            textColor: context.zc.accent,
            onPressed: () {
              final uri = savedUri;
              if (uri != null && uri.isNotEmpty) {
                CameraNativeBridge.openUrlInBrowser(uri);
              }
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          context.l10n.wmExportFailedToast('$e'),
          tone: ZStatusTone.danger,
        );
      }
    } finally {
      fullImage?.dispose();
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: _decodedImage == null
            ? Text(l10n.wmStudioTitle)
            : InkWell(
                onTap: _showMetadataEditSheet,
                borderRadius: BorderRadius.circular(ZRadius.pill),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: zc.surface,
                    borderRadius: BorderRadius.circular(ZRadius.pill),
                    border: Border.all(color: zc.outline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 14, color: zc.accent),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${_metadata.titleText} · ${_metadata.exposureSummary}',
                          style: TextStyle(
                            color: zc.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined,
                          size: 12, color: zc.textTertiary),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: l10n.wmPickFromAlbumTooltip,
            onPressed: _pickImageFromGallery,
          ),
          // 组合式导出胶囊主按钮 [导出 | 原画 ▾]
          Container(
            margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: zc.accent,
              borderRadius: BorderRadius.circular(ZRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: l10n.wmSaveHighResTooltip,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(ZRadius.pill),
                    ),
                    onTap: _isExporting ? null : _exportPhoto,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isExporting)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: zc.onAccent,
                              ),
                            )
                          else
                            Icon(Icons.download, size: 16, color: zc.onAccent),
                          const SizedBox(width: 4),
                          Text(
                            l10n.commonExport,
                            style: TextStyle(
                              color: zc.onAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 16,
                  color: zc.onAccent.withAlpha(80),
                ),
                PopupMenuButton<int>(
                  tooltip: l10n.wmExportQualityTitle,
                  initialValue: AppSettings.instance.exportQuality,
                  onSelected: (v) {
                    AppSettings.instance.setExportQuality(v);
                    setState(() {});
                  },
                  itemBuilder: (ctx) => [
                    for (final q in AppSettings.exportQualityOptions)
                      PopupMenuItem(
                        value: q,
                        child: Text(
                          l10n.wmExportQualityMenuLabel(
                            L10n.tr(
                              AppSettings.exportQualityLabel(q),
                              l10n.localeName,
                            ),
                            q,
                          ),
                        ),
                      ),
                  ],
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          L10n.tr(
                            AppSettings.exportQualityLabel(
                              AppSettings.instance.exportQuality,
                            ),
                            l10n.localeName,
                          ),
                          style: TextStyle(
                            color: zc.onAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            size: 16, color: zc.onAccent),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isExporting,
        child: LayoutBuilder(builder: (context, constraints) {
          final narrow = <Widget>[
            // 1. 顶部所见即所得 (WYSIWYG) 实时画布预览区
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: zc.canvas,
                  borderRadius: BorderRadius.circular(ZRadius.md),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ZRadius.md),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (_tabController.index == 3) {
                            return PhotoEditPreview(
                              controller: _editController,
                              activeTool: _editTool,
                              cropAspect: _editCropAspect,
                            );
                          }
                          var canvasSize =
                              Size(constraints.maxWidth, constraints.maxHeight);
                          if (_decodedImage != null) {
                            final srcW = _decodedImage!.width.toDouble();
                            final srcH = _decodedImage!.height.toDouble();
                            final layout = WatermarkCanvasPainter.computeLayout(
                              srcW,
                              srcH,
                              _selectedTemplate,
                              _spacingScale,
                            );
                            final aspect =
                                layout.totalWidth / layout.totalHeight;
                            var w = constraints.maxWidth;
                            var h = w / aspect;
                            if (h > constraints.maxHeight) {
                              h = constraints.maxHeight;
                              w = h * aspect;
                            }
                            canvasSize = Size(w, h);
                          }
                          return Center(
                            child: SizedBox(
                              width: canvasSize.width,
                              height: canvasSize.height,
                              child: CustomPaint(
                                size: canvasSize,
                                painter: WatermarkCanvasPainter(
                                  image: _decodedImage,
                                  metadata: _metadata,
                                  template: _selectedTemplate,
                                  filterType: _isComparingOriginal
                                      ? PhotoFilterType.original
                                      : _selectedFilter,
                                  filterIntensity: _isComparingOriginal
                                      ? 0.0
                                      : _filterIntensity,
                                  adjustments: _isComparingOriginal
                                      ? const PhotoEditAdjustments()
                                      : _adjustments,
                                  spacingScale: _spacingScale,
                                  showDetails: _showDetails,
                                  cardDark: _cardDark,
                                  textDark: _textDark,
                                  cardColorOverride: _cardColorOverride,
                                  textColorOverride: _textColorOverride,
                                  titleTextScale: AppSettings
                                      .instance.watermarkTitleTextScale,
                                  metaTextScale: AppSettings
                                      .instance.watermarkMetaTextScale,
                                  letterSpacingScale: AppSettings
                                      .instance.watermarkLetterSpacingScale,
                                  lineSpacingScale: AppSettings
                                      .instance.watermarkLineSpacingScale,
                                  fontWeight: WatermarkFontWeight.values[
                                      AppSettings
                                          .instance.watermarkFontWeightIndex],
                                  borderThicknessScale: AppSettings
                                      .instance.watermarkBorderThicknessScale,
                                  fontFamily: _watermarkFontFamily,
                                  customLines: _customLines,
                                  customTextScale: AppSettings
                                      .instance.watermarkCustomTextScale,
                                  logoImage: _logoImage,
                                  logoScale: _logoScales[_logoScaleIndex],
                                  logoOpacity:
                                      _logoOpacities[_logoOpacityIndex],
                                  accentColor: _accentColor,
                                  cardTone: WatermarkCardTone.auto,
                                  cornerRadiusFactor: _cornerRadiusFactor,
                                  showModel: _showModel,
                                  showLens: _showLens,
                                  showExposure: _showExposure,
                                  showDate: _showDate,
                                  showBrandLogo: _showBrandLogo,
                                  showGps: _showGps,
                                  watermarkOpacity: _watermarkOpacity,
                                  customTextAlign: _customTextAlign,
                                  logoCorner: _logoCorner,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // 左上角直方图 HUD 折叠胶囊与卡片
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => setState(() =>
                                  _showHistogramHud = !_showHistogramHud),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _showHistogramHud
                                      ? zc.accent
                                      : zc.surface.withAlpha(220),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _showHistogramHud
                                        ? ZSwatch.transparent
                                        : zc.outline,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bar_chart,
                                      size: 13,
                                      color: _showHistogramHud
                                          ? zc.onAccent
                                          : zc.textPrimary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n.wmHistogramHudTooltip,
                                      style: TextStyle(
                                        color: _showHistogramHud
                                            ? zc.onAccent
                                            : zc.textPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showHistogramHud) ...[
                              const SizedBox(height: 6),
                              Container(
                                width: 220,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: zc.surface.withAlpha(240),
                                  borderRadius:
                                      BorderRadius.circular(ZRadius.sm),
                                  border: Border.all(color: zc.outline),
                                ),
                                child: LightroomHistogramWidget(
                                  data: HistogramData.compute(
                                    adjustments: _rawSourcePath != null
                                        ? const PhotoEditAdjustments()
                                        : _adjustments,
                                    filterType: _selectedFilter,
                                    filterIntensity: _filterIntensity,
                                    sampledR: _sampledR,
                                    sampledG: _sampledG,
                                    sampledB: _sampledB,
                                  ),
                                  selectedZone: _activeHistogramZone,
                                  onSelectZone: (zone) {
                                    _updateState(() {
                                      _activeHistogramZone = zone;
                                      _tabController.animateTo(2);
                                    });
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 右上角按住对比原片胶囊
                      if (_decodedImage != null &&
                          (!_adjustments.isDefault ||
                              _selectedFilter != PhotoFilterType.original))
                        Positioned(
                          top: 10,
                          right: 10,
                          child: GestureDetector(
                            onTapDown: (_) =>
                                setState(() => _isComparingOriginal = true),
                            onTapUp: (_) =>
                                setState(() => _isComparingOriginal = false),
                            onTapCancel: () =>
                                setState(() => _isComparingOriginal = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _isComparingOriginal
                                    ? zc.accent
                                    : zc.surface.withAlpha(220),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isComparingOriginal
                                      ? ZSwatch.transparent
                                      : zc.textSecondary,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.compare,
                                    size: 13,
                                    color: _isComparingOriginal
                                        ? zc.onAccent
                                        : zc.textPrimary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isComparingOriginal
                                        ? l10n.wmShowingOriginalBadge
                                        : l10n.wmHoldToCompareHint,
                                    style: TextStyle(
                                      color: _isComparingOriginal
                                          ? zc.onAccent
                                          : zc.textPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (_isLoadingImage)
                        Center(
                          child: CircularProgressIndicator(color: zc.accent),
                        ),

                      if (_decodedImage == null && !_isLoadingImage)
                        Positioned(
                          bottom: 16,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: zc.textSecondary,
                              side: BorderSide(color: zc.textSecondary),
                              backgroundColor: zc.surface,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(ZRadius.pill),
                              ),
                            ),
                            icon: Icon(
                              Icons.add_photo_alternate,
                              size: 16,
                              color: zc.accent,
                            ),
                            label: Text(
                              l10n.wmPickPhotoEmptyPrompt,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: _pickImageFromGallery,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. 中间功能切换 4 栏 TabBar
            Container(
              color: zc.surface,
              child: TabBar(
                controller: _tabController,
                indicatorColor: zc.accent,
                indicatorWeight: 2.5,
                labelColor: zc.accent,
                unselectedLabelColor: zc.textTertiary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: l10n.wmDockTemplate),
                  Tab(text: l10n.wmDockFilter),
                  Tab(text: l10n.wmDockGrade),
                  Tab(text: l10n.wmDockGeometry),
                ],
              ),
            ),

            // 3. 底部面板内容（窄屏模式）
            SizedBox(
              height: _panelHeight(context),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTemplateSelectorPanel(wide: false),
                  _buildFilmFilterPanel(wide: false),
                  _buildParameterGradePanel(),
                  _buildEditPanel(),
                ],
              ),
            ),
          ];

          if (constraints.maxWidth >= kAdaptiveRailBreakpoint) {
            final preview = narrow[0];
            final tabBar = narrow[1];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const VerticalDivider(width: 1),
                SizedBox(
                  key: const ValueKey('adaptiveSidePanel'),
                  width: adaptiveSidePanelWidth(constraints.maxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      tabBar,
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTemplateSelectorPanel(wide: true),
                            _buildFilmFilterPanel(wide: true),
                            _buildParameterGradePanel(),
                            _buildEditPanel(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(children: narrow);
        }),
      ),
    );
  }

  Widget _buildEditPanel() {
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l10n.commonUndo,
              onPressed: _editController.canUndo ? _editController.undo : null,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: l10n.commonRedo,
              onPressed: _editController.canRedo ? _editController.redo : null,
              icon: const Icon(Icons.redo),
            ),
            TextButton(
              onPressed: _editController.isDirty ? _editController.reset : null,
              child: Text(l10n.commonReset),
            ),
          ],
        ),
        Expanded(
          child: PhotoEditToolsPanel(
            controller: _editController,
            activeTool: _editTool,
            onToolChanged: (tool) {
              setState(() => _editTool = tool);
              _onTabChanged();
            },
            cropAspect: _editCropAspect,
            onCropAspectSelected: (aspect) =>
                applyCropAspect(_editController, aspect),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateSelectorPanel({bool wide = false}) {
    if (wide) {
      return _buildTabletTemplatePanel();
    }

    final zc = context.zc;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: [
        // 1. 上半部：横向模板胶片条（加宽卡片使完整版式名称清晰可见）
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: WatermarkTemplate.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final t = WatermarkTemplate.values[index];
              return SizedBox(
                width: 172,
                child: WatermarkTemplateCard(
                  template: t,
                  isSelected: t == _selectedTemplate,
                  onTap: () => setState(() {
                    _selectedTemplate = t;
                    if (_cardColorOverride == null) {
                      _cardDark = t.defaultCardDark;
                    }
                    if (_textColorOverride == null) {
                      _textDark = t.defaultTextDark;
                    }
                  }),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 2. 中间：3 段内联子胶囊切换（已移除冗余 Logo 贴图栏，品牌标识自动根据 EXIF 匹配）
        if (_selectedTemplate == WatermarkTemplate.none)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: zc.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(ZRadius.sm),
              border: Border.all(color: zc.accent.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: zc.accent, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.wmPureGradeModeTitle,
                        style: TextStyle(
                          color: zc.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.wmPureGradeModeSub,
                        style: TextStyle(color: zc.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text(
                    l10n.wmGoToGradeButton,
                    style: TextStyle(
                      color: zc.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: BorderRadius.circular(ZRadius.pill),
              border: Border.all(color: zc.outline),
            ),
            child: Row(
              children: [
                _buildTemplateSubTabButton(
                    0, l10n.wmSubPalette, Icons.palette_outlined),
                _buildTemplateSubTabButton(
                    1, l10n.wmSubToggles, Icons.toggle_on_outlined),
                _buildTemplateSubTabButton(
                    2, l10n.wmSubTypography, Icons.text_fields_outlined),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 3. 下半部：内联样式控件，零弹窗
          if (_templateSubTab == 0)
            WatermarkStyleControls(
              key: const ValueKey('wm-sub-palette'),
              section: WatermarkStyleSection.palette,
              onChanged: _syncStyleFromSettings,
            )
          else if (_templateSubTab == 1)
            WatermarkStyleControls(
              key: const ValueKey('wm-sub-toggles'),
              section: WatermarkStyleSection.toggles,
              onChanged: _syncStyleFromSettings,
            )
          else
            WatermarkStyleControls(
              key: const ValueKey('wm-sub-typography'),
              section: WatermarkStyleSection.typography,
              onChanged: _syncStyleFromSettings,
            ),
        ],
      ],
    );
  }

  /// 平板模式水印面板：支持「单列一行一种（带滚动条）」与「自适应高度分页」
  Widget _buildTabletTemplatePanel() {
    final zc = context.zc;
    final l10n = context.l10n;
    final isPaged = AppSettings.instance.tabletWatermarkViewPaged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 顶部二级分段切换：[ 版式选择 (16) ] | [ 样式微调 ]
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.pill),
            border: Border.all(color: zc.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabletWatermarkSection = 0),
                  borderRadius: BorderRadius.circular(ZRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _tabletWatermarkSection == 0
                          ? zc.accent
                          : ZSwatch.transparent,
                      borderRadius: BorderRadius.circular(ZRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        '${l10n.wmTabletSectionTemplates} (${WatermarkTemplate.values.length})',
                        style: TextStyle(
                          color: _tabletWatermarkSection == 0
                              ? zc.onAccent
                              : zc.textSecondary,
                          fontSize: 11.5,
                          fontWeight: _tabletWatermarkSection == 0
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabletWatermarkSection = 1),
                  borderRadius: BorderRadius.circular(ZRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _tabletWatermarkSection == 1
                          ? zc.accent
                          : ZSwatch.transparent,
                      borderRadius: BorderRadius.circular(ZRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        l10n.wmTabletSectionStyle,
                        style: TextStyle(
                          color: _tabletWatermarkSection == 1
                              ? zc.onAccent
                              : zc.textSecondary,
                          fontSize: 11.5,
                          fontWeight: _tabletWatermarkSection == 1
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. 主体区
        Expanded(
          child: _tabletWatermarkSection == 0
              ? _buildTabletTemplatePickerArea(isPaged)
              : _buildTabletStyleControlsArea(),
        ),
      ],
    );
  }

  Widget _buildTabletTemplatePickerArea(bool isPaged) {
    final zc = context.zc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部视图模式切换工具栏：[ 一行一种列表 / 自适应屏幕高度分页 ]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _selectedTemplate.trLabel,
                  style: TextStyle(
                    color: zc.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildTabletViewModePill(
                isPaged: isPaged,
                onToggle: (val) {
                  setState(() {
                    AppSettings.instance.setTabletWatermarkViewPaged(val);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: isPaged
              ? _buildTabletWatermarkPagedView()
              : _buildTabletWatermarkVerticalList(),
        ),
      ],
    );
  }

  /// 平板模式水印版式单列列表（一行放一种，带可见滚动条）
  Widget _buildTabletWatermarkVerticalList() {
    const values = WatermarkTemplate.values;

    return Scrollbar(
      controller: _wmScrollController,
      thumbVisibility: true,
      interactive: true,
      child: ListView.separated(
        controller: _wmScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final t = values[index];
          final isSelected = t == _selectedTemplate;
          return _buildTabletWatermarkListRow(t, isSelected);
        },
      ),
    );
  }

  Widget _buildTabletWatermarkListRow(WatermarkTemplate t, bool isSelected) {
    final zc = context.zc;
    final l10n = context.l10n;

    return Material(
      color: ZSwatch.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _selectedTemplate = t;
          if (_cardColorOverride == null) {
            _cardDark = t.defaultCardDark;
          }
          if (_textColorOverride == null) {
            _textDark = t.defaultTextDark;
          }
        }),
        borderRadius: BorderRadius.circular(ZRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? zc.accent.withAlpha(28) : zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Row(
            children: [
              // 示意线框
              WatermarkTemplateCard.schematic(
                context,
                t,
                isSelected,
                width: 58,
                height: 44,
              ),
              const SizedBox(width: 10),
              // 中间标题与描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.trLabel,
                      style: TextStyle(
                        color: isSelected ? zc.accent : zc.textPrimary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.trDescription,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 9.5,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 右侧选中状态与微调快捷入口
              if (isSelected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t != WatermarkTemplate.none) ...[
                      InkWell(
                        onTap: () =>
                            setState(() => _tabletWatermarkSection = 1),
                        borderRadius: BorderRadius.circular(ZRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: zc.accent.withAlpha(35),
                            borderRadius: BorderRadius.circular(ZRadius.pill),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.wmTabletTuneAction,
                                style: TextStyle(
                                  color: zc.accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios,
                                  size: 8, color: zc.accent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(Icons.check_circle, size: 18, color: zc.accent),
                  ],
                )
              else
                Icon(Icons.radio_button_unchecked,
                    size: 18, color: zc.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// 平板模式水印版式自适应屏幕高度分页
  Widget _buildTabletWatermarkPagedView() {
    const values = WatermarkTemplate.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight - 44;
        const cardH = 74.0;
        const spacing = 8.0;
        final rows = math.max(2, (availH / (cardH + spacing)).floor());
        const cols = 2;
        final itemsPerPage = rows * cols;
        final totalItems = values.length;
        final totalPages = math.max(1, (totalItems / itemsPerPage).ceil());
        final currentPage = _wmCurrentPage.clamp(0, totalPages - 1);

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _wmPageController,
                onPageChanged: (p) => setState(() => _wmCurrentPage = p),
                itemCount: totalPages,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * itemsPerPage;
                  final end = math.min(start + itemsPerPage, totalItems);
                  final pageItems = values.sublist(start, end);

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio:
                            (constraints.maxWidth - 20 - spacing) /
                                cols /
                                cardH,
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, i) {
                        final t = pageItems[i];
                        return WatermarkTemplateCard(
                          template: t,
                          isSelected: t == _selectedTemplate,
                          onTap: () => setState(() {
                            _selectedTemplate = t;
                            if (_cardColorOverride == null) {
                              _cardDark = t.defaultCardDark;
                            }
                            if (_textColorOverride == null) {
                              _textDark = t.defaultTextDark;
                            }
                          }),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            _buildTabletPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              onPrev: currentPage > 0
                  ? () => _wmPageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
              onNext: currentPage < totalPages - 1
                  ? () => _wmPageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabletStyleControlsArea() {
    final zc = context.zc;
    final l10n = context.l10n;

    if (_selectedTemplate == WatermarkTemplate.none) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined, size: 40, color: zc.accent),
              const SizedBox(height: 12),
              Text(
                l10n.wmTabletPureGradeHint,
                style: TextStyle(
                  color: zc.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.wmPureGradeModeSub,
                style: TextStyle(color: zc.textSecondary, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => setState(() => _tabletWatermarkSection = 0),
                icon: const Icon(Icons.style_outlined, size: 16),
                label: Text(l10n.wmTabletPureGradeAction),
                style: FilledButton.styleFrom(
                  backgroundColor: zc.accent,
                  foregroundColor: zc.onAccent,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 3 段子胶囊切换
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.pill),
            border: Border.all(color: zc.outline),
          ),
          child: Row(
            children: [
              _buildTemplateSubTabButton(
                  0, l10n.wmSubPalette, Icons.palette_outlined),
              _buildTemplateSubTabButton(
                  1, l10n.wmSubToggles, Icons.toggle_on_outlined),
              _buildTemplateSubTabButton(
                  2, l10n.wmSubTypography, Icons.text_fields_outlined),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: _templateSubTab == 0
                ? WatermarkStyleControls(
                    key: const ValueKey('wm-sub-palette'),
                    section: WatermarkStyleSection.palette,
                    onChanged: _syncStyleFromSettings,
                  )
                : _templateSubTab == 1
                    ? WatermarkStyleControls(
                        key: const ValueKey('wm-sub-toggles'),
                        section: WatermarkStyleSection.toggles,
                        onChanged: _syncStyleFromSettings,
                      )
                    : WatermarkStyleControls(
                        key: const ValueKey('wm-sub-typography'),
                        section: WatermarkStyleSection.typography,
                        onChanged: _syncStyleFromSettings,
                      ),
          ),
        ),
      ],
    );
  }

  /// 平板模式共享视图切换器（单列列表 / 自适应高度分页）
  Widget _buildTabletViewModePill({
    required bool isPaged,
    required ValueChanged<bool> onToggle,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: BorderRadius.circular(ZRadius.pill),
        border: Border.all(color: zc.outline, width: ZStroke.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.wmViewModeListTooltip,
            child: InkWell(
              onTap: () => onToggle(false),
              borderRadius: BorderRadius.circular(ZRadius.pill),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: !isPaged ? zc.accent : ZSwatch.transparent,
                  borderRadius: BorderRadius.circular(ZRadius.pill),
                ),
                child: Icon(
                  Icons.view_agenda_outlined,
                  size: 13,
                  color: !isPaged ? zc.onAccent : zc.textSecondary,
                ),
              ),
            ),
          ),
          Tooltip(
            message: l10n.wmViewModePagedTooltip,
            child: InkWell(
              onTap: () => onToggle(true),
              borderRadius: BorderRadius.circular(ZRadius.pill),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaged ? zc.accent : ZSwatch.transparent,
                  borderRadius: BorderRadius.circular(ZRadius.pill),
                ),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 13,
                  color: isPaged ? zc.onAccent : zc.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 平板模式共享翻页控制条
  Widget _buildTabletPaginationBar({
    required int currentPage,
    required int totalPages,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(
            top: BorderSide(color: zc.outline, width: ZStroke.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: l10n.wmTabletPagePrev,
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
            visualDensity: VisualDensity.compact,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.wmTabletPageIndicator(
                    (currentPage + 1).toString(), totalPages.toString()),
                style: TextStyle(
                  color: zc.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (totalPages <= 8)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(totalPages, (i) {
                    final active = i == currentPage;
                    return Container(
                      width: active ? 10 : 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: active ? zc.accent : zc.outline,
                        borderRadius: BorderRadius.circular(ZRadius.pill),
                      ),
                    );
                  }),
                ),
            ],
          ),
          IconButton(
            tooltip: l10n.wmTabletPageNext,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSubTabButton(int index, String label, IconData icon) {
    final isSelected = _templateSubTab == index;
    final zc = context.zc;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _templateSubTab = index),
        borderRadius: BorderRadius.circular(ZRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? zc.accent : ZSwatch.transparent,
            borderRadius: BorderRadius.circular(ZRadius.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? zc.onAccent : zc.textSecondary,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? zc.onAccent : zc.textSecondary,
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
