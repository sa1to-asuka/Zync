import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../engine/ai/ai_camera_coach.dart';
import '../../../engine/ai/ai_provider_config.dart';
import '../../../engine/ai/ai_vision_client.dart';
import '../../../engine/capture/camera_property.dart';
import '../../../engine/capture/exposure_settings_controller.dart';
import '../../../engine/liveview/live_view_controller.dart';
import '../../../engine/picture_control/picture_control_store.dart';
import '../../../l10n/l10n.dart';
import '../../../protocol/camera_driver.dart';
import '../../../protocol/nikon_driver.dart';
import '../../design/design.dart';
import '../../widgets/ai_api_key_guide.dart';
import '../../widgets/ai_error_card.dart';
import '../../widgets/ai_svg_icons.dart';
import 'capture_overlays.dart';

/// 管理 AI 实时取景指导的结果、叠加可见性与当前分析帧。
class AiCoachController extends ChangeNotifier {
  AiCameraCoachResult? _result;
  Size? _frameSize;
  Uint8List? _analyzedFrameJpeg;
  bool _showOverlay = true;

  AiCameraCoachResult? get result => _result;
  Size? get frameSize => _frameSize;
  Uint8List? get analyzedFrameJpeg => _analyzedFrameJpeg;
  bool get showOverlay => _showOverlay && _result != null;

  void updateResult(
    AiCameraCoachResult value, {
    Size? frameSize,
    Uint8List? frameJpeg,
  }) {
    _result = value;
    if (frameSize != null) _frameSize = frameSize;
    if (frameJpeg != null) _analyzedFrameJpeg = frameJpeg;
    _showOverlay = true;
    notifyListeners();
  }

  void toggleOverlay(bool visible) {
    if (_showOverlay == visible) return;
    _showOverlay = visible;
    notifyListeners();
  }

  void clear() {
    if (_result == null && _frameSize == null && _analyzedFrameJpeg == null) {
      return;
    }
    _result = null;
    _frameSize = null;
    _analyzedFrameJpeg = null;
    _showOverlay = false;
    notifyListeners();
  }
}

/// 叠加在实时取景器之上的无交互 AR 构图引导层（暗化四周杂乱区域 + 高亮推荐裁切框 + 比例角标）。
class AiCompositionOverlay extends StatelessWidget {
  final AiCoachController controller;
  final int quarterTurns;

  const AiCompositionOverlay({
    super.key,
    required this.controller,
    this.quarterTurns = 0,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final result = controller.result;
        if (!controller.showOverlay || result == null) {
          return const SizedBox.shrink();
        }
        return CustomPaint(
          painter: _AiCompositionPainter(
            result: result,
            imageSize: controller.frameSize,
            quarterTurns: quarterTurns,
            zc: zc,
            overlayLabel: _buildOverlayBadgeLabel(l10n, result),
          ),
        );
      },
    );
  }

  static String _buildOverlayBadgeLabel(
    AppLocalizations l10n,
    AiCameraCoachResult res,
  ) {
    final rec = res.cropRecommendation;
    if (rec == null) return l10n.aiCoachOverlayPillLabel;
    final orientLabel = switch (rec.orientation) {
      'portrait' => l10n.aiCoachOrientationPortrait,
      'square' => l10n.aiCoachOrientationSquare,
      _ => l10n.aiCoachOrientationLandscape,
    };
    final ratioText = '$orientLabel ${rec.aspectRatio}';
    if (rec.subjectTitle.isNotEmpty) {
      return '$ratioText · ${rec.subjectTitle}';
    }
    return ratioText;
  }
}

class _AiCompositionPainter extends CustomPainter {
  final AiCameraCoachResult result;
  final Size? imageSize;
  final int quarterTurns;
  final ZyncPalette zc;
  final String overlayLabel;

  _AiCompositionPainter({
    required this.result,
    required this.imageSize,
    required this.quarterTurns,
    required this.zc,
    required this.overlayLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect contentRect;
    if (imageSize != null && imageSize!.width > 0 && imageSize!.height > 0) {
      final oriented = quarterTurns.isOdd
          ? Size(imageSize!.height, imageSize!.width)
          : imageSize!;
      contentRect = fitContentRect(oriented, size);
    } else {
      contentRect = Offset.zero & size;
    }

    final cropNorm =
        result.effectiveCropRect ?? const Rect.fromLTWH(0.16, 0.16, 0.68, 0.68);
    final cropRect = Rect.fromLTWH(
      contentRect.left + cropNorm.left * contentRect.width,
      contentRect.top + cropNorm.top * contentRect.height,
      cropNorm.width * contentRect.width,
      cropNorm.height * contentRect.height,
    );

    // 1. 暗化裁切框外围的杂乱区域，聚焦显示推荐构图窗口
    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(contentRect)
      ..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(6)));
    canvas.drawPath(
      maskPath,
      Paint()..color = zc.overlayScrim.withAlpha(135),
    );

    // 2. 框内柔和构图参考线 + 细框线 + L 型亮角标 + 比例标签（绝不绘制方向箭头或圆点）
    _drawGuideLines(canvas, cropRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(6)),
      Paint()
        ..color = zc.accent.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    _drawCornerBrackets(canvas, cropRect, zc.accent);
    _drawCropPill(canvas, cropRect, overlayLabel);
  }

  void _drawCropPill(Canvas canvas, Rect cropRect, String label) {
    if (label.isEmpty || cropRect.width < 60) return;
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: zc.onAccent,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      maxLines: 1,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(48.0, cropRect.width - 12));

    final pillW = tp.width + 12;
    final pillH = tp.height + 6;
    final pillTop = cropRect.top - pillH - 6 >= 4
        ? cropRect.top - pillH - 6
        : cropRect.top + 6;
    final double pillLeft = cropRect.left
        .clamp(4.0, math.max(4.0, cropRect.right - pillW))
        .toDouble();
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, pillTop, pillW, pillH),
      const Radius.circular(6),
    );
    canvas.drawRRect(pillRect, Paint()..color = zc.accent);
    tp.paint(canvas, Offset(pillLeft + 6, pillTop + 3));
  }

  void _drawGuideLines(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = zc.accent.withAlpha(110)
      ..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

    switch (result.guideType) {
      case CompositionGuideType.ruleOfThirds:
        for (final t in const [1 / 3, 2 / 3]) {
          canvas.drawLine(
            Offset(rect.left + rect.width * t, rect.top),
            Offset(rect.left + rect.width * t, rect.bottom),
            paint,
          );
          canvas.drawLine(
            Offset(rect.left, rect.top + rect.height * t),
            Offset(rect.right, rect.top + rect.height * t),
            paint,
          );
        }
      case CompositionGuideType.goldenSpiral:
        for (final phi in const [0.382, 0.618]) {
          canvas.drawLine(
            Offset(rect.left + rect.width * phi, rect.top),
            Offset(rect.left + rect.width * phi, rect.bottom),
            paint,
          );
          canvas.drawLine(
            Offset(rect.left, rect.top + rect.height * phi),
            Offset(rect.right, rect.top + rect.height * phi),
            paint,
          );
        }
      case CompositionGuideType.diagonal:
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
        canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
      case CompositionGuideType.symmetry:
        canvas.drawLine(
          Offset(rect.center.dx, rect.top),
          Offset(rect.center.dx, rect.bottom),
          paint,
        );
        canvas.drawLine(
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          paint,
        );
      case CompositionGuideType.leadingLines:
        final focus = Offset(rect.center.dx, rect.top + rect.height * 0.4);
        canvas.drawLine(rect.bottomLeft, focus, paint);
        canvas.drawLine(rect.bottomRight, focus, paint);
      case CompositionGuideType.center:
        final inner = Rect.fromCenter(
          center: rect.center,
          width: rect.width * 0.36,
          height: rect.height * 0.36,
        );
        canvas.drawRect(inner, paint);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final len = math.min(rect.width, rect.height).clamp(24.0, 120.0) * 0.22;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(len, 0), p);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, len), p);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-len, 0), p);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, len), p);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(len, 0), p);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -len), p);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-len, 0), p);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -len), p);
  }

  @override
  bool shouldRepaint(covariant _AiCompositionPainter old) =>
      old.result != result ||
      old.imageSize != imageSize ||
      old.quarterTurns != quarterTurns ||
      old.overlayLabel != overlayLabel;
}

/// 打开 AI 实时取景指导面板（手机底部弹窗 / 平板居中受限弹窗）。
Future<void> showAiCoachSheet({
  required BuildContext context,
  required AiCoachController controller,
  required LiveViewController liveViewController,
  required ExposureSettingsController exposureController,
  required CameraDriver driver,
  Future<void> Function(Offset normalizedPoint)? onFocusAtNormalized,
}) {
  final zc = context.zc;
  final isWide = context.zb.isTwoPane || MediaQuery.sizeOf(context).width >= 640;

  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (dlgCtx) => Dialog(
        backgroundColor: zc.surfaceElevated,
        insetPadding: const EdgeInsets.all(ZSpace.xl),
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brLg,
          side: BorderSide(color: zc.outline, width: 0.8),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(dlgCtx).height * 0.88,
          ),
          child: _AiCoachSheet(
            controller: controller,
            liveViewController: liveViewController,
            exposureController: exposureController,
            driver: driver,
            onFocusAtNormalized: onFocusAtNormalized,
            isDialog: true,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: zc.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
    ),
    builder: (_) => _AiCoachSheet(
      controller: controller,
      liveViewController: liveViewController,
      exposureController: exposureController,
      driver: driver,
      onFocusAtNormalized: onFocusAtNormalized,
      isDialog: false,
    ),
  );
}

class _AiCoachSheet extends StatefulWidget {
  final AiCoachController controller;
  final LiveViewController liveViewController;
  final ExposureSettingsController exposureController;
  final CameraDriver driver;
  final Future<void> Function(Offset normalizedPoint)? onFocusAtNormalized;
  final bool isDialog;

  const _AiCoachSheet({
    required this.controller,
    required this.liveViewController,
    required this.exposureController,
    required this.driver,
    this.onFocusAtNormalized,
    this.isDialog = false,
  });

  @override
  State<_AiCoachSheet> createState() => _AiCoachSheetState();
}

class _AiCoachSheetState extends State<_AiCoachSheet> {
  final TextEditingController _intentController = TextEditingController();
  String _selectedPresetKey = 'auto';
  bool _analyzing = false;
  bool _applyingExposure = false;
  bool _focusingSubject = false;
  bool _unconfigured = false;
  bool _showFullFrameBox = false;
  Object? _lastError;
  String? _errorDetail;
  String? _statusMessage;

  ui.Image? _decodedFrameImage;
  Uint8List? _decodedForBytes;

  @override
  void initState() {
    super.initState();
    AiSettingsStore.instance.addListener(_onAiStoreChanged);
    _initStateAsync();
  }

  void _onAiStoreChanged() {
    if (!mounted) return;
    final missing = AiSettingsStore.instance.isTargetMissingApiKey(
      AiSettingsStore.instance.resolveCoachTarget(),
    );
    if (missing != _unconfigured) {
      setState(() => _unconfigured = missing);
    }
  }

  Future<void> _initStateAsync() async {
    await AiSettingsStore.instance.ensureInitialized();
    final existingJpeg = widget.controller.analyzedFrameJpeg;
    if (existingJpeg != null && existingJpeg.isNotEmpty) {
      await _decodePreviewUiImage(existingJpeg);
    }
    if (!mounted) return;
    setState(() {
      _unconfigured = AiSettingsStore.instance.isTargetMissingApiKey(
        AiSettingsStore.instance.resolveCoachTarget(),
      );
    });
  }

  @override
  void dispose() {
    AiSettingsStore.instance.removeListener(_onAiStoreChanged);
    _decodedFrameImage?.dispose();
    _intentController.dispose();
    super.dispose();
  }

  String _effectiveSceneIntent(AppLocalizations l10n) {
    final typed = _intentController.text.trim();
    if (typed.isNotEmpty) return typed;
    return switch (_selectedPresetKey) {
      'portrait' => l10n.aiCoachScenePortrait,
      'landscape' => l10n.aiCoachSceneLandscape,
      'street' => l10n.aiCoachSceneStreet,
      'night' => l10n.aiCoachSceneNight,
      'food' => l10n.aiCoachSceneFood,
      _ => '',
    };
  }

  Map<String, String> _collectTelemetry() {
    final exp = widget.exposureController;
    final out = <String, String>{};
    for (final param in const [
      CameraParameter.aperture,
      CameraParameter.shutter,
      CameraParameter.iso,
      CameraParameter.exposureCompensation,
    ]) {
      final b = exp.bindingOf(param);
      if (b != null) {
        out[param.name] = b.labelOf(b.currentValue);
      }
    }
    return out;
  }

  Future<Size?> _decodePreviewUiImage(Uint8List jpeg) async {
    if (identical(_decodedForBytes, jpeg) && _decodedFrameImage != null) {
      return Size(
        _decodedFrameImage!.width.toDouble(),
        _decodedFrameImage!.height.toDouble(),
      );
    }
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(jpeg, (decoded) {
        if (!completer.isCompleted) {
          completer.complete(decoded);
        } else {
          decoded.dispose();
        }
      });
      final nextImg = await completer.future;
      final size = Size(nextImg.width.toDouble(), nextImg.height.toDouble());
      if (!mounted) {
        nextImg.dispose();
        return size;
      }
      _decodedFrameImage?.dispose();
      _decodedFrameImage = nextImg;
      _decodedForBytes = jpeg;
      return size;
    } catch (_) {
      return null;
    }
  }

  Future<void> _analyzeNow() async {
    final frameJpeg = widget.liveViewController.latestJpeg;
    final l10n = context.l10n;
    if (frameJpeg == null || frameJpeg.isEmpty) {
      setState(() => _statusMessage = l10n.aiCoachNoFrame);
      return;
    }

    setState(() {
      _analyzing = true;
      _lastError = null;
      _errorDetail = null;
      _statusMessage = null;
      _unconfigured = false;
    });

    try {
      await AiSettingsStore.instance.ensureInitialized();
      await PictureControlStore.instance.ensureInitialized();
      final catalog = PictureControlStore.instance.items;
      final intent = _effectiveSceneIntent(l10n);
      final target = AiSettingsStore.instance.resolveCoachTarget();

      if (AiSettingsStore.instance.isTargetMissingApiKey(target)) {
        if (!mounted) return;
        setState(() {
          _unconfigured = true;
          _analyzing = false;
        });
        return;
      }

      final frameSize = await _decodePreviewUiImage(frameJpeg);
      if (!mounted) return;
      final localeCode = context.l10n.localeName;
      final preferCellular =
          AiSettingsStore.instance.allowCellularBypassInAp &&
              widget.driver.isConnected &&
              widget.driver.transportKind == CameraTransportKind.wifi;

      final res = await AiCameraCoach().analyzeLiveFrame(
        profile: target!.profile,
        modelId: target.modelId,
        apiKey: target.apiKey,
        frameJpeg: frameJpeg,
        sceneIntent: intent,
        exposureTelemetry: _collectTelemetry(),
        np3Catalog: catalog,
        includeExifTelemetry: AiSettingsStore.instance.includeExifTelemetry,
        localeCode: localeCode,
        frameWidth: frameSize?.width.round(),
        frameHeight: frameSize?.height.round(),
        preferCellular: preferCellular,
      );

      if (!mounted) return;
      widget.controller.updateResult(
        res,
        frameSize: frameSize,
        frameJpeg: frameJpeg,
      );
      setState(() {
        _analyzing = false;
        _showFullFrameBox = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        _lastError = e;
        _errorDetail = AiVisionClient.sanitizeForLog('$e');
      });
    }
  }

  Future<void> _runOfflineBaseline() async {
    final frameJpeg = widget.liveViewController.latestJpeg;
    final l10n = context.l10n;
    final localeCode = l10n.localeName;
    if (frameJpeg == null || frameJpeg.isEmpty) {
      setState(() => _statusMessage = l10n.aiCoachNoFrame);
      return;
    }
    await PictureControlStore.instance.ensureInitialized();
    final catalog = PictureControlStore.instance.items;
    final frameSize = await _decodePreviewUiImage(frameJpeg);
    final fallback = AiCameraCoach.analyzeOfflineFallback(
      frameJpeg,
      np3Catalog: catalog,
      sceneIntent: _effectiveSceneIntent(l10n),
      localeCode: localeCode,
    );
    if (!mounted) return;
    widget.controller.updateResult(
      fallback,
      frameSize: frameSize,
      frameJpeg: frameJpeg,
    );
    setState(() {
      _lastError = null;
      _errorDetail = null;
      _unconfigured = false;
      _analyzing = false;
      _statusMessage = null;
    });
  }

  Future<void> _focusCropSubject(AiCameraCoachResult res) async {
    final crop = res.effectiveCropRect;
    final handler = widget.onFocusAtNormalized;
    if (crop == null || handler == null || _focusingSubject) return;
    setState(() => _focusingSubject = true);
    try {
      await handler(crop.center);
    } finally {
      if (mounted) setState(() => _focusingSubject = false);
    }
  }

  Future<void> _applySuggestedExposure(List<MatchedCameraWrite> writes) async {
    final l10n = context.l10n;
    if (writes.isEmpty) {
      showZToast(
        context,
        l10n.aiCoachExposureNoneWritable,
        tone: ZStatusTone.warning,
      );
      return;
    }
    setState(() => _applyingExposure = true);
    var okCount = 0;
    try {
      for (final w in writes) {
        final outcome =
            await widget.exposureController.apply(w.parameter, w.targetRaw);
        if (outcome is SettingsApplied) okCount++;
      }
      if (!mounted) return;
      showZToast(
        context,
        l10n.aiCoachExposureApplied(okCount),
        tone: okCount > 0 ? ZStatusTone.success : ZStatusTone.warning,
      );
    } finally {
      if (mounted) setState(() => _applyingExposure = false);
    }
  }

  Future<void> _pickSlotAndWriteNp3(AiNp3Match match) async {
    final l10n = context.l10n;
    final zc = context.zc;
    final item = match.resolvedItem;
    if (item == null) return;
    if (widget.driver is! NikonDriver) {
      showZToast(
        context,
        l10n.aiCoachNp3RequiresNikon,
        tone: ZStatusTone.warning,
      );
      return;
    }

    final slot = await showDialog<int>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: zc.surface,
        title: Text(
          l10n.aiCoachNp3SelectSlotTitle,
          style: TextStyle(color: zc.textPrimary, fontSize: 15),
        ),
        content: Wrap(
          spacing: ZSpace.sm,
          runSpacing: ZSpace.sm,
          children: [
            for (var s = 1; s <= 9; s++)
              ActionChip(
                label: Text(l10n.aiCoachNp3SlotLabel(s)),
                onPressed: () => Navigator.of(dlgCtx).pop(s),
              ),
          ],
        ),
      ),
    );
    if (slot == null || !mounted) return;

    try {
      final driver = widget.driver as NikonDriver;
      await widget.liveViewController.runExclusive(
        () => driver.writePictureControlSlot(
          slotNumber: slot,
          recipe: item.recipe,
          setActive: true,
        ),
      );
      if (!mounted) return;
      final displayName =
          item.noteName.isNotEmpty ? item.noteName : item.fileName;
      showZToast(
        context,
        l10n.aiCoachNp3WriteSuccess(displayName, slot),
        tone: ZStatusTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      showZToast(
        context,
        l10n.aiCoachNp3WriteFailed('$e', slot),
        tone: ZStatusTone.danger,
      );
    }
  }

  AiSvgIconKind _iconForTipCategory(AiTipCategory cat) => switch (cat) {
        AiTipCategory.lighting => AiSvgIconKind.lightingSun,
        AiTipCategory.pose => AiSvgIconKind.portraitPose,
        AiTipCategory.timing => AiSvgIconKind.decisiveTiming,
        AiTipCategory.position => AiSvgIconKind.cameraPosition,
        AiTipCategory.lens => AiSvgIconKind.lensFocal,
      };

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final res = widget.controller.result;
    final matchedWrites = res == null
        ? const <MatchedCameraWrite>[]
        : CameraParamMatcher.match(
            res.exposureSuggestion,
            widget.exposureController,
          );

    final scenes = <(String key, String label)>[
      ('auto', l10n.aiCoachSceneAuto),
      ('portrait', l10n.aiCoachScenePortrait),
      ('landscape', l10n.aiCoachSceneLandscape),
      ('street', l10n.aiCoachSceneStreet),
      ('night', l10n.aiCoachSceneNight),
      ('food', l10n.aiCoachSceneFood),
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isDialog)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ZSpace.md),
              decoration: BoxDecoration(
                color: zc.outline,
                borderRadius: ZRadius.brPill,
              ),
            ),
          ),
        Row(
          children: [
            AiSvgIcon(
              AiSvgIconKind.sparkleAperture,
              size: 20,
              color: zc.accent,
            ),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Text(
                l10n.aiCoachSheetTitle,
                style: zt.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (res?.isOfflineFallback == true)
              ZTag(
                text: l10n.aiCoachOfflineTag,
                compact: true,
                color: zc.warning,
                isOutline: true,
              ),
            if (res != null) ...[
              const SizedBox(width: ZSpace.xs),
              TextButton(
                onPressed: () {
                  widget.controller.clear();
                  setState(() {});
                },
                child: Text(l10n.aiCoachClearOverlay),
              ),
            ],
            if (widget.isDialog)
              IconButton(
                icon: Icon(Icons.close_rounded, color: zc.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: ZSpace.sm),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final (key, label) in scenes) ...[
                        ChoiceChip(
                          label: Text(label),
                          selected: _selectedPresetKey == key,
                          onSelected: (_) =>
                              setState(() => _selectedPresetKey = key),
                          selectedColor: zc.accentContainer,
                          backgroundColor: zc.surfaceHigh,
                          side: BorderSide(
                            color: _selectedPresetKey == key
                                ? zc.accent
                                : zc.outline,
                            width: _selectedPresetKey == key ? 1.1 : 0.8,
                          ),
                          labelStyle: zt.caption.copyWith(
                            color: _selectedPresetKey == key
                                ? zc.accent
                                : zc.textSecondary,
                            fontWeight: _selectedPresetKey == key
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          showCheckmark: false,
                        ),
                        const SizedBox(width: ZSpace.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: ZSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _intentController,
                        style: zt.bodySmall.copyWith(color: zc.textPrimary),
                        onSubmitted: (_) {
                          if (!_analyzing) _analyzeNow();
                        },
                        decoration: InputDecoration(
                          hintText: l10n.aiCoachSceneIntentHint,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    ZButton(
                      label: l10n.aiCoachAnalyzeNow,
                      variant: ZButtonVariant.filled,
                      size: ZButtonSize.sm,
                      isLoading: _analyzing,
                      onTap: _analyzing ? null : _analyzeNow,
                    ),
                  ],
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: ZSpace.sm),
                  Text(
                    _statusMessage!,
                    style: zt.caption.copyWith(color: zc.warning),
                  ),
                ],
                const SizedBox(height: ZSpace.md),
                if (_analyzing)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: ZSpace.xl),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: zc.accent,
                        ),
                        const SizedBox(height: ZSpace.sm),
                        Text(
                          l10n.aiCoachAnalyzing,
                          style: zt.bodySmall.copyWith(color: zc.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (_lastError != null)
                  AiDiagnosticCard(
                    title: l10n.aiRequestFailedTitle,
                    hint: localizedAiErrorHint(l10n, _lastError!),
                    technicalDetail: _errorDetail,
                    onRetry: _analyzeNow,
                    onShowGuide: () => showAiApiKeyTutorialModal(context),
                    onUseOffline: _runOfflineBaseline,
                  )
                else if (_unconfigured && res == null)
                  AiDiagnosticCard(
                    isError: false,
                    title: l10n.aiUnconfiguredTitle,
                    hint: l10n.aiCoachSetupAiFirst,
                    onShowGuide: () => showAiApiKeyTutorialModal(context),
                    onUseOffline: _runOfflineBaseline,
                  )
                else if (res == null)
                  Container(
                    padding: const EdgeInsets.all(ZSpace.md),
                    decoration: BoxDecoration(
                      color: zc.surfaceHigh,
                      borderRadius: ZRadius.brMd,
                      border: Border.all(color: zc.outline, width: 0.8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AiSvgIcon(
                          AiSvgIconKind.cropFrame,
                          size: 20,
                          color: zc.accent,
                        ),
                        const SizedBox(width: ZSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.aiCoachReadyHintTitle,
                                style: zt.titleSmall,
                              ),
                              const SizedBox(height: ZSpace.xxs),
                              Text(
                                l10n.aiCoachReadyHintSub,
                                style: zt.caption.copyWith(
                                  color: zc.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Row(
                    children: [
                      ZTag(
                        text: l10n.aiCoachCompScore(res.compositionScore),
                        compact: true,
                        color: zc.accent,
                      ),
                      const SizedBox(width: ZSpace.sm),
                      ZTag(
                        text: l10n.aiCoachExpScore(res.exposureScore),
                        compact: true,
                        color: zc.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: ZSpace.sm),
                  if (res.sceneSummary.isNotEmpty)
                    Text(
                      res.sceneSummary,
                      style: zt.titleSmall,
                    ),
                  if (res.cropRecommendation != null) ...[
                    const SizedBox(height: ZSpace.md),
                    _buildCropPreviewSection(res, res.cropRecommendation!),
                  ],
                  if (res.shootingTips.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.md),
                    Text(
                      l10n.aiCoachShootingTipsSection,
                      style: zt.titleSmall,
                    ),
                    const SizedBox(height: ZSpace.xs),
                    for (final tip in res.shootingTips)
                      Container(
                        margin: const EdgeInsets.only(bottom: ZSpace.xs),
                        padding: const EdgeInsets.all(ZSpace.sm),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: ZRadius.brSm,
                          border: Border.all(color: zc.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: AiSvgIcon(
                                _iconForTipCategory(tip.category),
                                size: 17,
                                color: zc.accent,
                              ),
                            ),
                            const SizedBox(width: ZSpace.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tip.title,
                                    style: zt.bodySmall.copyWith(
                                      color: zc.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (tip.detail.isNotEmpty &&
                                      tip.detail != tip.title) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      tip.detail,
                                      style: zt.caption.copyWith(
                                        color: zc.textSecondary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (res.cameraMoveHint.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.sm),
                    _InfoBlock(
                      title: l10n.aiCoachCompositionSection,
                      body: [
                        res.cameraMoveHint,
                        ...res.compositionTips,
                      ].where((e) => e.trim().isNotEmpty).join('\n'),
                    ),
                  ],
                  if (res.toneDiagnosis.isNotEmpty ||
                      res.colorMoodAdvice.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.sm),
                    _InfoBlock(
                      title: l10n.aiCoachToneSection,
                      body: [
                        res.toneDiagnosis,
                        res.colorMoodAdvice,
                      ].where((e) => e.trim().isNotEmpty).join('\n'),
                    ),
                  ],
                  if (matchedWrites.isNotEmpty ||
                      (res.exposureSuggestion?.reason.isNotEmpty ?? false)) ...[
                    const SizedBox(height: ZSpace.sm),
                    Container(
                      padding: const EdgeInsets.all(ZSpace.md),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.aiCoachExposureSyncSection,
                            style: zt.titleSmall,
                          ),
                          if (res.exposureSuggestion?.reason.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 4),
                            Text(
                              res.exposureSuggestion!.reason,
                              style: zt.caption.copyWith(
                                color: zc.textSecondary,
                              ),
                            ),
                          ],
                          for (final w in matchedWrites) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${w.parameter.name.toUpperCase()}: ${w.currentLabel} -> ${w.targetLabel}',
                              style: zt.mono.copyWith(
                                color: zc.accent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: ZSpace.sm),
                          ZButton(
                            label: l10n.aiCoachApplyExposure,
                            icon: Icons.tune_rounded,
                            variant: ZButtonVariant.tonal,
                            isBlock: true,
                            isLoading: _applyingExposure,
                            onTap: _applyingExposure
                                ? null
                                : () => _applySuggestedExposure(matchedWrites),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (res.np3Matches.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.md),
                    Row(
                      children: [
                        AiSvgIcon(
                          AiSvgIconKind.np3Chip,
                          size: 16,
                          color: zc.accent,
                        ),
                        const SizedBox(width: ZSpace.xs),
                        Text(
                          l10n.aiCoachNp3Section,
                          style: zt.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: ZSpace.xs),
                    for (final m in res.np3Matches)
                      Container(
                        margin: const EdgeInsets.only(bottom: ZSpace.xs),
                        padding: const EdgeInsets.all(ZSpace.sm),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: ZRadius.brSm,
                          border: Border.all(color: zc.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${m.resolvedItem == null ? m.recipeId : (m.resolvedItem!.noteName.isNotEmpty ? m.resolvedItem!.noteName : m.resolvedItem!.fileName)} (${m.matchScore}%)',
                                    style: zt.bodySmall.copyWith(
                                      color: zc.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (m.reason.isNotEmpty)
                                    Text(
                                      m.reason,
                                      style: zt.caption.copyWith(
                                        color: zc.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (m.resolvedItem != null)
                              ZButton(
                                label: l10n.aiCoachNp3WriteSlot,
                                variant: ZButtonVariant.outlined,
                                size: ZButtonSize.sm,
                                onTap: () => _pickSlotAndWriteNp3(m),
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isDialog) {
      return Padding(
        padding: const EdgeInsets.all(ZSpace.lg),
        child: body,
      );
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: ZSpace.lg,
            right: ZSpace.lg,
            top: ZSpace.sm,
            bottom: MediaQuery.viewInsetsOf(context).bottom + ZSpace.md,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildCropPreviewSection(
    AiCameraCoachResult res,
    AiCropRecommendation rec,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final orientLabel = switch (rec.orientation) {
      'portrait' => l10n.aiCoachOrientationPortrait,
      'square' => l10n.aiCoachOrientationSquare,
      _ => l10n.aiCoachOrientationLandscape,
    };

    return Container(
      padding: const EdgeInsets.all(ZSpace.md),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brMd,
        border: Border.all(color: zc.accent.withAlpha(110), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AiSvgIcon(
                rec.isPortrait
                    ? AiSvgIconKind.portraitRatio
                    : AiSvgIconKind.landscapeRatio,
                size: 16,
                color: zc.accent,
              ),
              const SizedBox(width: ZSpace.xs),
              Expanded(
                child: Text(
                  l10n.aiCoachCropPreviewTitle,
                  style: zt.titleSmall,
                ),
              ),
              ZTag(
                text: '$orientLabel ${rec.aspectRatio}',
                compact: true,
                color: zc.accent,
              ),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          LayoutBuilder(
            builder: (context, cons) {
              final previewWidget = _decodedFrameImage != null
                  ? ClipRRect(
                      borderRadius: ZRadius.brSm,
                      child: SizedBox(
                        height: cons.maxWidth >= 420 ? 180 : 168,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: zc.canvas),
                          child: CustomPaint(
                            painter: _CroppedFramePreviewPainter(
                              image: _decodedFrameImage!,
                              cropNorm: rec.cropBox,
                              showFullFrameWithBox: _showFullFrameBox,
                              accentColor: zc.accent,
                              scrimColor: zc.overlayScrim,
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink();

              final infoCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rec.subjectTitle.isNotEmpty) ...[
                    Text(
                      rec.subjectTitle,
                      style: zt.titleSmall.copyWith(color: zc.accent),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (rec.framingReason.isNotEmpty)
                    Text(
                      rec.framingReason,
                      style: zt.caption.copyWith(
                        color: zc.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  if (res.cameraMoveHint.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.xs),
                    Text(
                      res.cameraMoveHint,
                      style: zt.caption.copyWith(
                        color: zc.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_decodedFrameImage != null) ...[
                    const SizedBox(height: ZSpace.xs),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZSpace.xs,
                          vertical: 2,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          setState(() => _showFullFrameBox = !_showFullFrameBox),
                      icon: AiSvgIcon(
                        AiSvgIconKind.cropFrame,
                        size: 14,
                        color: zc.accent,
                      ),
                      label: Text(
                        _showFullFrameBox
                            ? l10n.aiCoachViewCroppedResult
                            : l10n.aiCoachViewOriginalCrop,
                        style: zt.caption.copyWith(
                          color: zc.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              );

              if (cons.maxWidth >= 460 && _decodedFrameImage != null) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 210, child: previewWidget),
                    const SizedBox(width: ZSpace.md),
                    Expanded(child: infoCol),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_decodedFrameImage != null) ...[
                    previewWidget,
                    const SizedBox(height: ZSpace.sm),
                  ],
                  infoCol,
                ],
              );
            },
          ),
          const SizedBox(height: ZSpace.sm),
          Row(
            children: [
              Expanded(
                child: ZButton(
                  label: l10n.aiCoachShowOnViewfinder,
                  icon: Icons.visibility_outlined,
                  variant: ZButtonVariant.filled,
                  size: ZButtonSize.sm,
                  onTap: () {
                    widget.controller.toggleOverlay(true);
                    Navigator.of(context).pop();
                  },
                ),
              ),
              if (widget.onFocusAtNormalized != null &&
                  widget.driver.supportsTapToFocus) ...[
                const SizedBox(width: ZSpace.sm),
                Expanded(
                  child: ZButton(
                    label: l10n.aiCoachFocusCropSubject,
                    icon: Icons.center_focus_strong_outlined,
                    variant: ZButtonVariant.tonal,
                    size: ZButtonSize.sm,
                    isLoading: _focusingSubject,
                    onTap:
                        _focusingSubject ? null : () => _focusCropSubject(res),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CroppedFramePreviewPainter extends CustomPainter {
  final ui.Image image;
  final Rect cropNorm;
  final bool showFullFrameWithBox;
  final Color accentColor;
  final Color scrimColor;

  _CroppedFramePreviewPainter({
    required this.image,
    required this.cropNorm,
    required this.showFullFrameWithBox,
    required this.accentColor,
    required this.scrimColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    if (imgW <= 0 || imgH <= 0 || size.isEmpty) return;

    final srcCrop = Rect.fromLTWH(
      (cropNorm.left * imgW).clamp(0.0, imgW - 1),
      (cropNorm.top * imgH).clamp(0.0, imgH - 1),
      (cropNorm.width * imgW).clamp(1.0, imgW),
      (cropNorm.height * imgH).clamp(1.0, imgH),
    );

    if (showFullFrameWithBox) {
      final fullSrc = Rect.fromLTWH(0, 0, imgW, imgH);
      final dst = fitContentRect(Size(imgW, imgH), size);
      canvas.drawImageRect(
        image,
        fullSrc,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      final boxRect = Rect.fromLTWH(
        dst.left + cropNorm.left * dst.width,
        dst.top + cropNorm.top * dst.height,
        cropNorm.width * dst.width,
        cropNorm.height * dst.height,
      );
      final mask = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(dst)
        ..addRect(boxRect);
      canvas.drawPath(mask, Paint()..color = scrimColor.withAlpha(140));
      canvas.drawRect(
        boxRect,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      return;
    }

    final dst = fitContentRect(srcCrop.size, size);
    canvas.drawImageRect(
      image,
      srcCrop,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawRect(
      dst,
      Paint()
        ..color = accentColor.withAlpha(160)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _CroppedFramePreviewPainter old) =>
      old.image != image ||
      old.cropNorm != cropNorm ||
      old.showFullFrameWithBox != showFullFrameWithBox;
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final String body;

  const _InfoBlock({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Container(
      padding: const EdgeInsets.all(ZSpace.sm),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: zt.titleSmall),
          const SizedBox(height: 4),
          Text(
            body,
            style: zt.caption.copyWith(
              color: zc.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// 实时取景画面底部的单行紧凑 AI 构图技巧浮条（不遮挡中央取景画面，点击展开详情或一键对焦/关闭）。
class AiViewfinderTipBanner extends StatelessWidget {
  final AiCameraCoachResult result;
  final VoidCallback onOpenCoach;
  final VoidCallback? onFocusSubject;
  final VoidCallback onClose;

  const AiViewfinderTipBanner({
    super.key,
    required this.result,
    required this.onOpenCoach,
    required this.onClose,
    this.onFocusSubject,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final rec = result.cropRecommendation;
    final firstTip =
        result.shootingTips.isNotEmpty ? result.shootingTips.first : null;
    final headline = firstTip?.title.isNotEmpty == true
        ? firstTip!.title
        : (rec?.subjectTitle.isNotEmpty == true
            ? rec!.subjectTitle
            : result.cameraMoveHint);
    final ratioBadge = rec != null
        ? '${rec.isPortrait ? l10n.aiCoachOrientationPortrait : (rec.orientation == 'square' ? l10n.aiCoachOrientationSquare : l10n.aiCoachOrientationLandscape)} ${rec.aspectRatio}'
        : l10n.aiCoachOverlayPillLabel;

    return Material(
      color: zc.surface.withAlpha(228),
      borderRadius: ZRadius.brMd,
      child: InkWell(
        onTap: onOpenCoach,
        borderRadius: ZRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.sm,
            vertical: ZSpace.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: ZRadius.brMd,
            border: Border.all(color: zc.accent.withAlpha(140), width: 0.9),
          ),
          child: Row(
            children: [
              AiSvgIcon(
                AiSvgIconKind.cropFrame,
                size: 15,
                color: zc.accent,
              ),
              const SizedBox(width: ZSpace.xs),
              ZTag(text: ratioBadge, compact: true, color: zc.accent),
              const SizedBox(width: ZSpace.xs + 2),
              Expanded(
                child: Text(
                  headline.isNotEmpty ? headline : result.sceneSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zt.caption.copyWith(
                    color: zc.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onFocusSubject != null) ...[
                const SizedBox(width: ZSpace.xs),
                InkWell(
                  onTap: onFocusSubject,
                  borderRadius: ZRadius.brSm,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AiSvgIcon(
                      AiSvgIconKind.afTarget,
                      size: 16,
                      color: zc.accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: ZSpace.xxs),
              InkWell(
                onTap: onClose,
                borderRadius: ZRadius.brSm,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: zc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
