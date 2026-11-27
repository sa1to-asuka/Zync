import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/utils/exif_helper.dart';
import '../../../engine/ai/ai_color_grader.dart';
import '../../../engine/ai/ai_provider_config.dart';
import '../../../engine/ai/ai_recipe_catalog.dart';
import '../../../engine/ai/ai_vision_client.dart';
import '../../../engine/filter/photo_filter.dart';
import '../../../engine/spektrafilm/spektrafilm_models.dart';
import '../../../l10n/l10n.dart';
import '../../design/design.dart';
import '../../widgets/ai_api_key_guide.dart';
import '../../widgets/ai_error_card.dart';
import '../../widgets/ai_svg_icons.dart';

/// 应用到水彩/暗房画布的完整 AI 调色载荷（含命中的内置配方 + 强度缩放后的本图微调）。
class AiGradeApplyPayload {
  final AiGradeVariant variant;
  final PhotoEditAdjustments scaledAdjustments;
  final double effectiveRecipeIntensity;

  const AiGradeApplyPayload({
    required this.variant,
    required this.scaledAdjustments,
    required this.effectiveRecipeIntensity,
  });
}

/// 响应式打开 AI 智能识图调色面板（手机底部弹窗 / 平板居中受限弹窗）。
Future<String?> showAiGradeModal({
  required BuildContext context,
  required Uint8List imageBytes,
  required ImageColorStats stats,
  required ValueChanged<AiGradeApplyPayload> onPreviewPayload,
  required Future<void> Function(AiGradeApplyPayload payload, String name)
      onSavePreset,
  ValueChanged<bool>? onToggleCompareOriginal,
  PhotoMetadata? metadata,
  List<SpektraStockInfo>? spektraStocks,
  bool preResizedJpeg = false,
}) {
  final zc = context.zc;
  final isWide = context.zb.isTwoPane || MediaQuery.sizeOf(context).width >= 640;

  if (isWide) {
    return showDialog<String>(
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
            maxWidth: 600,
            maxHeight: MediaQuery.sizeOf(dlgCtx).height * 0.88,
          ),
          child: AiGradeSheet(
            imageBytes: imageBytes,
            stats: stats,
            metadata: metadata,
            spektraStocks: spektraStocks,
            preResizedJpeg: preResizedJpeg,
            onPreviewPayload: onPreviewPayload,
            onSavePreset: onSavePreset,
            onToggleCompareOriginal: onToggleCompareOriginal,
            isDialog: true,
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: zc.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
    ),
    builder: (_) => AiGradeSheet(
      imageBytes: imageBytes,
      stats: stats,
      metadata: metadata,
      spektraStocks: spektraStocks,
      preResizedJpeg: preResizedJpeg,
      onPreviewPayload: onPreviewPayload,
      onSavePreset: onSavePreset,
      onToggleCompareOriginal: onToggleCompareOriginal,
      isDialog: false,
    ),
  );
}

/// AI 智能识图调色面板 2.0：
/// 将照片 + 直方图统计 + Zync 全量内置配方库发给视觉大模型，严选最契合的 3 款配方与本图微调参数。
class AiGradeSheet extends StatefulWidget {
  final Uint8List imageBytes;
  final ImageColorStats stats;
  final PhotoMetadata? metadata;
  final List<SpektraStockInfo>? spektraStocks;
  final ValueChanged<AiGradeApplyPayload> onPreviewPayload;
  final Future<void> Function(AiGradeApplyPayload payload, String name)
      onSavePreset;
  final ValueChanged<bool>? onToggleCompareOriginal;
  final bool isDialog;
  final bool autoRunOnOpen;
  final bool preResizedJpeg;

  const AiGradeSheet({
    super.key,
    required this.imageBytes,
    required this.stats,
    required this.onPreviewPayload,
    required this.onSavePreset,
    this.metadata,
    this.spektraStocks,
    this.onToggleCompareOriginal,
    this.isDialog = false,
    this.autoRunOnOpen = false,
    this.preResizedJpeg = false,
  });

  @override
  State<AiGradeSheet> createState() => _AiGradeSheetState();
}

class _AiGradeSheetState extends State<AiGradeSheet> {
  final TextEditingController _styleController = TextEditingController();
  final TextEditingController _refineController = TextEditingController();

  bool _loading = false;
  bool _refining = false;
  bool _unconfigured = false;
  Object? _lastError;
  String? _errorDetail;
  AiColorGradeBundle? _bundle;
  int _selectedIndex = 0;
  double _intensity = 1.0;

  @override
  void initState() {
    super.initState();
    AiSettingsStore.instance.addListener(_onAiStoreChanged);
    _initStoreAndCheck();
  }

  void _onAiStoreChanged() {
    if (!mounted) return;
    final missing = AiSettingsStore.instance.isTargetMissingApiKey(
      AiSettingsStore.instance.resolveGradeTarget(),
    );
    if (missing != _unconfigured) {
      setState(() => _unconfigured = missing);
    }
  }

  Future<void> _initStoreAndCheck() async {
    await AiSettingsStore.instance.ensureInitialized();
    if (!mounted) return;
    final hasTarget = !AiSettingsStore.instance.isTargetMissingApiKey(
      AiSettingsStore.instance.resolveGradeTarget(),
    );
    setState(() => _unconfigured = !hasTarget);
    if (widget.autoRunOnOpen && hasTarget) {
      await _runGrade();
    }
  }

  @override
  void dispose() {
    AiSettingsStore.instance.removeListener(_onAiStoreChanged);
    widget.onToggleCompareOriginal?.call(false);
    _styleController.dispose();
    _refineController.dispose();
    super.dispose();
  }

  AiGradeVariant? get _currentVariant {
    final list = _bundle?.variants ?? const [];
    if (list.isEmpty) return null;
    final idx = _selectedIndex.clamp(0, list.length - 1);
    return list[idx];
  }

  AiGradeApplyPayload? get _currentPayload {
    final v = _currentVariant;
    if (v == null) return null;
    return AiGradeApplyPayload(
      variant: v,
      scaledAdjustments: AiColorGrader.scaleAdjustments(
        v.adjustments,
        _intensity,
      ),
      effectiveRecipeIntensity:
          (v.recipeIntensity * _intensity).clamp(0.0, 1.0).toDouble(),
    );
  }

  Future<void> _runGrade() async {
    final localeCode = context.l10n.localeName;
    setState(() {
      _loading = true;
      _lastError = null;
      _errorDetail = null;
      _unconfigured = false;
    });

    try {
      await AiSettingsStore.instance.ensureInitialized();
      final target = AiSettingsStore.instance.resolveGradeTarget();
      if (AiSettingsStore.instance.isTargetMissingApiKey(target)) {
        if (!mounted) return;
        setState(() {
          _unconfigured = true;
          _loading = false;
        });
        return;
      }

      final result = await AiColorGrader().gradePhoto(
        profile: target!.profile,
        modelId: target.modelId,
        apiKey: target.apiKey,
        imageBytes: widget.imageBytes,
        stats: widget.stats,
        metadata: widget.metadata,
        styleHint: _styleController.text,
        includeExifTelemetry: AiSettingsStore.instance.includeExifTelemetry,
        localeCode: localeCode,
        spektraStocks: widget.spektraStocks,
        skipResize: widget.preResizedJpeg,
      );
      if (!mounted) return;
      setState(() {
        _bundle = result;
        _selectedIndex = 0;
        _intensity = 1.0;
        _loading = false;
      });
      final payload = _currentPayload;
      if (payload != null) widget.onPreviewPayload(payload);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e;
        _errorDetail = AiVisionClient.sanitizeForLog('$e');
        _loading = false;
      });
    }
  }

  void _runOfflineBaseline() {
    final localeCode = context.l10n.localeName;
    final fallback = AiColorGrader.analyzeOfflineFallback(
      stats: widget.stats,
      styleHint: _styleController.text,
      localeCode: localeCode,
      spektraStocks: widget.spektraStocks,
    );
    setState(() {
      _bundle = fallback;
      _selectedIndex = 0;
      _intensity = 1.0;
      _lastError = null;
      _errorDetail = null;
      _unconfigured = false;
      _loading = false;
    });
    final payload = _currentPayload;
    if (payload != null) widget.onPreviewPayload(payload);
  }

  Future<void> _runRefine() async {
    final current = _currentVariant;
    final instruction = _refineController.text.trim();
    if (current == null || instruction.isEmpty || _refining) return;

    final localeCode = context.l10n.localeName;
    setState(() {
      _refining = true;
      _lastError = null;
      _errorDetail = null;
    });

    try {
      await AiSettingsStore.instance.ensureInitialized();
      final target = AiSettingsStore.instance.resolveGradeTarget();
      if (AiSettingsStore.instance.isTargetMissingApiKey(target)) {
        if (!mounted) return;
        setState(() {
          _refining = false;
          _unconfigured = true;
        });
        return;
      }

      final updated = await AiColorGrader().refineVariant(
        profile: target!.profile,
        modelId: target.modelId,
        apiKey: target.apiKey,
        imageBytes: widget.imageBytes,
        currentVariant: current,
        instruction: instruction,
        stats: widget.stats,
        localeCode: localeCode,
        spektraStocks: widget.spektraStocks,
        skipResize: widget.preResizedJpeg,
      );
      if (!mounted) return;

      final bundle = _bundle;
      if (bundle != null) {
        final next = List<AiGradeVariant>.from(bundle.variants);
        next[_selectedIndex.clamp(0, next.length - 1)] = updated;
        setState(() {
          _bundle = AiColorGradeBundle(
            diagnosis: bundle.diagnosis,
            variants: next,
            isOfflineFallback: bundle.isOfflineFallback,
          );
          _intensity = 1.0;
          _refining = false;
        });
        _refineController.clear();
        final payload = _currentPayload;
        if (payload != null) widget.onPreviewPayload(payload);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e;
        _errorDetail = AiVisionClient.sanitizeForLog('$e');
        _refining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final current = _currentVariant;
    final payload = _currentPayload;

    final inspirationChips = <String>[
      l10n.aiGradeStyleChipShinkai,
      l10n.aiGradeStyleChipWong,
      l10n.aiGradeStyleChipHamada,
      l10n.aiGradeStyleChipKodak,
      l10n.aiGradeStyleChipTealOrange,
      l10n.aiGradeStyleChipForest,
      l10n.aiGradeStyleChipBw,
    ];

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                l10n.aiGradeSheetTitle,
                style: zt.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_bundle?.isOfflineFallback == true)
              ZTag(
                text: l10n.aiGradeOfflineTag,
                compact: true,
                color: zc.warning,
                isOutline: true,
              ),
            if (widget.onToggleCompareOriginal != null && _bundle != null) ...[
              const SizedBox(width: ZSpace.xs),
              GestureDetector(
                onTapDown: (_) => widget.onToggleCompareOriginal?.call(true),
                onTapUp: (_) => widget.onToggleCompareOriginal?.call(false),
                onTapCancel: () => widget.onToggleCompareOriginal?.call(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZSpace.sm,
                    vertical: ZSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: zc.surfaceHigh,
                    borderRadius: ZRadius.brPill,
                    border: Border.all(color: zc.outline, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AiSvgIcon(
                        AiSvgIconKind.compareOriginal,
                        size: 14,
                        color: zc.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.aiGradeCompareHold,
                        style: zt.caption.copyWith(color: zc.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (widget.isDialog) ...[
              const SizedBox(width: ZSpace.xs),
              IconButton(
                icon: Icon(Icons.close_rounded, color: zc.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
        const SizedBox(height: ZSpace.md),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.aiGradeInspirationLabel,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
                const SizedBox(height: ZSpace.xs),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final chipText in inspirationChips) ...[
                        ActionChip(
                          label: Text(
                            chipText,
                            style: zt.caption.copyWith(color: zc.textPrimary),
                          ),
                          backgroundColor: zc.surfaceHigh,
                          side: BorderSide(color: zc.outline, width: 0.8),
                          onPressed: () {
                            setState(() {
                              _styleController.text = chipText;
                            });
                          },
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
                        controller: _styleController,
                        style: zt.bodySmall.copyWith(color: zc.textPrimary),
                        onSubmitted: (_) {
                          if (!_loading) _runGrade();
                        },
                        decoration: InputDecoration(
                          hintText: l10n.aiGradeStyleHint,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    ZButton(
                      label: _bundle == null
                          ? l10n.aiGradeGenerateBtn
                          : l10n.aiGradeRegenerateBtn,
                      variant: ZButtonVariant.filled,
                      size: ZButtonSize.sm,
                      isLoading: _loading,
                      onTap: _loading ? null : _runGrade,
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                if (_loading)
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
                          l10n.aiGradeAnalyzingHint,
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
                    onRetry: _runGrade,
                    onShowGuide: () => showAiApiKeyTutorialModal(context),
                    onUseOffline: _runOfflineBaseline,
                  )
                else if (_unconfigured && _bundle == null)
                  AiDiagnosticCard(
                    isError: false,
                    title: l10n.aiUnconfiguredTitle,
                    hint: l10n.aiCoachSetupAiFirst,
                    onShowGuide: () => showAiApiKeyTutorialModal(context),
                    onUseOffline: _runOfflineBaseline,
                  )
                else if (_bundle == null)
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
                          AiSvgIconKind.masterFilter,
                          size: 20,
                          color: zc.accent,
                        ),
                        const SizedBox(width: ZSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.aiGradeEmptyPromptCardTitle,
                                style: zt.titleSmall,
                              ),
                              const SizedBox(height: ZSpace.xxs),
                              Text(
                                l10n.aiGradeEmptyPromptCardSub,
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
                  if (_bundle!.diagnosis.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(ZSpace.sm),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.outlineVariant),
                      ),
                      child: Text(
                        _bundle!.diagnosis,
                        style: zt.caption.copyWith(
                          color: zc.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  const SizedBox(height: ZSpace.md),
                  LayoutBuilder(
                    builder: (context, cons) {
                      final stacked = cons.maxWidth < 340;
                      if (stacked) {
                        return Column(
                          children: [
                            for (var i = 0; i < _bundle!.variants.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: ZSpace.xs),
                                child: _VariantCard(
                                  variant: _bundle!.variants[i],
                                  selected: i == _selectedIndex,
                                  onTap: () => _selectVariant(i),
                                ),
                              ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < _bundle!.variants.length; i++) ...[
                            if (i > 0) const SizedBox(width: ZSpace.sm),
                            Expanded(
                              child: _VariantCard(
                                variant: _bundle!.variants[i],
                                selected: i == _selectedIndex,
                                onTap: () => _selectVariant(i),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  if (current != null && current.rationale.isNotEmpty) ...[
                    const SizedBox(height: ZSpace.sm),
                    Text(
                      current.rationale,
                      style: zt.caption.copyWith(
                        color: zc.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: ZSpace.sm),
                  Row(
                    children: [
                      Text(
                        l10n.aiGradeIntensity((_intensity * 100).round()),
                        style: zt.caption.copyWith(
                          color: zc.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _intensity,
                          min: 0.0,
                          max: 1.5,
                          divisions: 30,
                          onChanged: (v) {
                            setState(() => _intensity = v);
                            final p = _currentPayload;
                            if (p != null) widget.onPreviewPayload(p);
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _refineController,
                          style: zt.bodySmall.copyWith(color: zc.textPrimary),
                          onSubmitted: (_) => _runRefine(),
                          decoration: InputDecoration(
                            hintText: l10n.aiGradeRefineHint,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZSpace.sm),
                      ZButton(
                        label: l10n.aiGradeRefineSend,
                        variant: ZButtonVariant.outlined,
                        size: ZButtonSize.sm,
                        isLoading: _refining,
                        onTap: _refining ? null : _runRefine,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (payload != null && current != null) ...[
          const SizedBox(height: ZSpace.md),
          Row(
            children: [
              Expanded(
                child: ZButton(
                  label: l10n.aiGradeSavePreset,
                  icon: Icons.bookmark_add_outlined,
                  variant: ZButtonVariant.outlined,
                  onTap: () => widget.onSavePreset(payload, current.name),
                ),
              ),
              const SizedBox(width: ZSpace.sm),
              Expanded(
                child: ZButton(
                  label: l10n.aiGradeApplyToCanvas,
                  icon: Icons.check_rounded,
                  variant: ZButtonVariant.filled,
                  onTap: () {
                    widget.onPreviewPayload(payload);
                    Navigator.of(context).pop(current.name);
                  },
                ),
              ),
            ],
          ),
        ],
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

  void _selectVariant(int index) {
    setState(() {
      _selectedIndex = index;
      _intensity = 1.0;
    });
    final p = _currentPayload;
    if (p != null) widget.onPreviewPayload(p);
  }
}

class _VariantCard extends StatelessWidget {
  final AiGradeVariant variant;
  final bool selected;
  final VoidCallback onTap;

  const _VariantCard({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  AiSvgIconKind _iconForKind(AiGradeRecipeKind kind) => switch (kind) {
        AiGradeRecipeKind.filter => AiSvgIconKind.masterFilter,
        AiGradeRecipeKind.spektraFilm => AiSvgIconKind.filmRoll,
        AiGradeRecipeKind.builtinPreset => AiSvgIconKind.presetSliders,
        AiGradeRecipeKind.customAdjustments => AiSvgIconKind.sparkleAperture,
      };

  String _kindLabel(AppLocalizations l10n, AiGradeRecipeKind kind) =>
      switch (kind) {
        AiGradeRecipeKind.filter => l10n.aiGradeRecipeBadgeFilter,
        AiGradeRecipeKind.spektraFilm => l10n.aiGradeRecipeBadgeSpektra,
        AiGradeRecipeKind.builtinPreset => l10n.aiGradeRecipeBadgePreset,
        AiGradeRecipeKind.customAdjustments => l10n.aiGradeRecipeBadgeCustom,
      };

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final hasRecipe = variant.recipeDisplayName.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: ZRadius.brSm,
      child: Container(
        padding: const EdgeInsets.all(ZSpace.sm),
        decoration: BoxDecoration(
          color: selected ? zc.accentContainer : zc.surfaceHigh,
          borderRadius: ZRadius.brSm,
          border: Border.all(
            color: selected ? zc.accent : zc.outline,
            width: selected ? ZStroke.emphasis : ZStroke.hairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AiSvgIcon(
                  _iconForKind(variant.kind),
                  size: 13,
                  color: selected ? zc.accent : zc.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _kindLabel(l10n, variant.kind),
                    style: zt.caption.copyWith(
                      color: selected ? zc.accent : zc.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              variant.name,
              style: zt.bodySmall.copyWith(
                color: zc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasRecipe) ...[
              const SizedBox(height: 2),
              Text(
                '${variant.recipeDisplayName} · ${(variant.recipeIntensity * 100).round()}%',
                style: zt.caption.copyWith(
                  color: selected ? zc.accent : zc.textSecondary,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
