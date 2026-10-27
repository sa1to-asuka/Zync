import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../engine/watermark/watermark_template.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

class WatermarkColorPreset {
  final String id;
  final int? value;

  const WatermarkColorPreset(this.id, this.value);

  String trLabel(AppLocalizations l10n) => switch (id) {
        'auto' => l10n.wmStyleFollowTemplate,
        'white' => l10n.wmStylePureWhite,
        'black' => l10n.wmStyleDeepBlack,
        'cream' => l10n.wmStyleCream,
        'gold' => l10n.wmStyleNikonGold,
        'cyan' => l10n.wmStyleCyan,
        'magenta' => l10n.wmStyleMagenta,
        'grey' => l10n.wmStyleDarkGrey,
        _ => id,
      };
}

const List<WatermarkColorPreset> watermarkColorPresets = [
  WatermarkColorPreset('auto', null),
  WatermarkColorPreset('white', 0xFFFFFFFF),
  WatermarkColorPreset('black', 0xFF101216),
  WatermarkColorPreset('cream', 0xFFF5F1E8),
  WatermarkColorPreset('gold', 0xFFFFD100),
  WatermarkColorPreset('cyan', 0xFF37C6FF),
  WatermarkColorPreset('magenta', 0xFFFF5FA2),
  WatermarkColorPreset('grey', 0xFF4A4A4A),
];

int watermarkColorValue(Color color) => color.toARGB32();

Color watermarkColor(int value) => ZSwatch.fromArgb32(value);

Future<int?> showWatermarkColorPicker(
    BuildContext context, int? initialValue) async {
  var r = initialValue == null ? 255 : (initialValue >> 16) & 0xFF;
  var g = initialValue == null ? 255 : (initialValue >> 8) & 0xFF;
  var b = initialValue == null ? 255 : initialValue & 0xFF;

  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) {
        final zc = ctx.zc;
        final l10n = ctx.l10n;
        final preview = ZSwatch.fromRgb(r, g, b);
        Widget channel(String label, int value, ValueChanged<int> onChanged) {
          return Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  label,
                  style: TextStyle(color: zc.textSecondary, fontSize: 12),
                ),
              ),
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  activeColor: preview,
                  label: '$value',
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$value',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: zc.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: zc.surfaceHigh,
          title: Text(
            l10n.wmStyleCustomColorTitle,
            style: TextStyle(
              color: zc.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: preview,
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    border: Border.all(color: zc.outline),
                  ),
                ),
                const SizedBox(height: 8),
                channel('R', r, (v) => setDialog(() => r = v)),
                channel('G', g, (v) => setDialog(() => g = v)),
                channel('B', b, (v) => setDialog(() => b = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, preview.toARGB32()),
              child: Text(l10n.commonApply),
            ),
          ],
        );
      },
    ),
  );
}

class WatermarkColorPickerRow extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool showAuto;

  const WatermarkColorPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.showAuto = true,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final presetValues = watermarkColorPresets
        .where((e) => e.value != null)
        .map((e) => e.value)
        .toSet();
    final isCustom = value != null && !presetValues.contains(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: zc.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in watermarkColorPresets)
              if (showAuto || preset.value != null)
                ChoiceChip(
                  label: Text(preset.trLabel(l10n)),
                  avatar: CircleAvatar(
                    radius: 7,
                    backgroundColor: preset.value == null
                        ? ZSwatch.transparent
                        : ZSwatch.fromArgb32(preset.value!),
                    child: preset.value == null
                        ? Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: zc.textSecondary,
                          )
                        : null,
                  ),
                  selected: value == preset.value,
                  onSelected: (_) => onChanged(preset.value),
                ),
            ChoiceChip(
              label: Text(l10n.commonCustom),
              avatar: CircleAvatar(
                radius: 7,
                backgroundColor: isCustom
                    ? ZSwatch.fromArgb32(value!)
                    : ZSwatch.transparent,
                child: isCustom
                    ? null
                    : Icon(Icons.colorize, size: 11, color: zc.textSecondary),
              ),
              selected: isCustom,
              onSelected: (_) async {
                final picked = await showWatermarkColorPicker(context, value);
                if (picked != null) onChanged(picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
    );
  }
}

enum WatermarkStyleSection {
  all,
  palette,
  toggles,
  typography,
}

class WatermarkStyleControls extends StatefulWidget {
  final VoidCallback? onChanged;
  final WatermarkStyleSection section;

  const WatermarkStyleControls({
    super.key,
    this.onChanged,
    this.section = WatermarkStyleSection.all,
  });

  @override
  State<WatermarkStyleControls> createState() => _WatermarkStyleControlsState();
}

class _WatermarkStyleControlsState extends State<WatermarkStyleControls> {
  final AppSettings _settings = AppSettings.instance;
  late final TextEditingController _line1;
  late final TextEditingController _line2;

  @override
  void initState() {
    super.initState();
    _line1 = TextEditingController(text: _settings.watermarkCustomLine1);
    _line2 = TextEditingController(text: _settings.watermarkCustomLine2);
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    super.dispose();
  }

  void _update({
    Object? cardColorValue = AppSettings.watermarkUnset,
    Object? textColorValue = AppSettings.watermarkUnset,
    Object? accentColorValue = AppSettings.watermarkUnset,
    Object? titleTextScale = AppSettings.watermarkUnset,
    Object? metaTextScale = AppSettings.watermarkUnset,
    Object? customTextScale = AppSettings.watermarkUnset,
    Object? letterSpacingScale = AppSettings.watermarkUnset,
    Object? lineSpacingScale = AppSettings.watermarkUnset,
    Object? fontWeightIndex = AppSettings.watermarkUnset,
    Object? borderThicknessScale = AppSettings.watermarkUnset,
    Object? spacingScale = AppSettings.watermarkUnset,
    Object? cornerRadiusFactor = AppSettings.watermarkUnset,
    Object? opacity = AppSettings.watermarkUnset,
    Object? fontChoice = AppSettings.watermarkUnset,
    Object? showModel = AppSettings.watermarkUnset,
    Object? showLens = AppSettings.watermarkUnset,
    Object? showExposure = AppSettings.watermarkUnset,
    Object? showDate = AppSettings.watermarkUnset,
    Object? showDetails = AppSettings.watermarkUnset,
    Object? showBrandLogo = AppSettings.watermarkUnset,
    Object? showGps = AppSettings.watermarkUnset,
    Object? customLine1 = AppSettings.watermarkUnset,
    Object? customLine2 = AppSettings.watermarkUnset,
    Object? logoScale = AppSettings.watermarkUnset,
    Object? logoOpacity = AppSettings.watermarkUnset,
    Object? logoCorner = AppSettings.watermarkUnset,
    Object? textAlign = AppSettings.watermarkUnset,
  }) {
    _settings.updateWatermarkStyle(
      cardColorValue: cardColorValue,
      textColorValue: textColorValue,
      accentColorValue: accentColorValue,
      titleTextScale: titleTextScale,
      metaTextScale: metaTextScale,
      customTextScale: customTextScale,
      letterSpacingScale: letterSpacingScale,
      lineSpacingScale: lineSpacingScale,
      fontWeightIndex: fontWeightIndex,
      borderThicknessScale: borderThicknessScale,
      spacingScale: spacingScale,
      cornerRadiusFactor: cornerRadiusFactor,
      opacity: opacity,
      fontChoice: fontChoice,
      showModel: showModel,
      showLens: showLens,
      showExposure: showExposure,
      showDate: showDate,
      showDetails: showDetails,
      showBrandLogo: showBrandLogo,
      showGps: showGps,
      customLine1: customLine1,
      customLine2: customLine2,
      logoScale: logoScale,
      logoOpacity: logoOpacity,
      logoCorner: logoCorner,
      textAlign: textAlign,
    );
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.zc.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _sliderRow(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    final zc = context.zc;
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: TextStyle(color: zc.textSecondary, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: zc.accent,
            inactiveColor: zc.outline,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: zc.accent,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  ButtonStyle _segStyle(BuildContext context) {
    final zc = context.zc;
    return ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? zc.accent
            : zc.surface,
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

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final s = _settings;

    final showPalette = widget.section == WatermarkStyleSection.all ||
        widget.section == WatermarkStyleSection.palette;
    final showTypography = widget.section == WatermarkStyleSection.all ||
        widget.section == WatermarkStyleSection.typography;
    final showToggles = widget.section == WatermarkStyleSection.all ||
        widget.section == WatermarkStyleSection.toggles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPalette) ...[
          _sectionTitle(context, l10n.wmStyleColorsSection),
          WatermarkColorPickerRow(
            label: l10n.wmStyleFrameBgLabel,
            value: s.watermarkCardColorValue,
            onChanged: (v) => _update(cardColorValue: v),
          ),
          WatermarkColorPickerRow(
            label: l10n.wmStyleTextColorLabel,
            value: s.watermarkTextColorValue,
            onChanged: (v) => _update(textColorValue: v),
          ),
          WatermarkColorPickerRow(
            label: l10n.wmStyleAccentColorLabel,
            value: s.watermarkAccentColorValue,
            showAuto: false,
            onChanged: (v) => _update(
                accentColorValue:
                    v ?? AppSettings.defaultWatermarkAccentColorValue),
          ),
          _sliderRow(
              context,
              l10n.wmStyleLineThickness,
              s.watermarkBorderThicknessScale,
              0.5,
              2.0,
              15,
              (v) => _update(borderThicknessScale: v)),
          _sliderRow(context, l10n.wmStyleMarginScale, s.watermarkSpacingScale,
              0.8, 1.4, 6, (v) => _update(spacingScale: v)),
          _sliderRow(
              context,
              l10n.wmStyleCornerRadius,
              s.watermarkCornerRadiusFactor,
              0.0,
              2.0,
              8,
              (v) => _update(cornerRadiusFactor: v)),
          _sliderRow(context, l10n.wmStyleOpacity, s.watermarkOpacity, 0.5, 1.0,
              10, (v) => _update(opacity: v)),
          const SizedBox(height: 12),
        ],
        if (showTypography) ...[
          _sectionTitle(context, l10n.wmStyleTypographySection),
          _sliderRow(context, l10n.wmStyleTitleScale, s.watermarkTitleTextScale,
              0.7, 1.5, 16, (v) => _update(titleTextScale: v)),
          _sliderRow(context, l10n.wmStyleMetaScale, s.watermarkMetaTextScale,
              0.7, 1.5, 16, (v) => _update(metaTextScale: v)),
          _sliderRow(
              context,
              l10n.wmStyleCustomTextScale,
              s.watermarkCustomTextScale,
              0.7,
              1.5,
              16,
              (v) => _update(customTextScale: v)),
          _sliderRow(
              context,
              l10n.wmStyleLetterSpacing,
              s.watermarkLetterSpacingScale,
              0.5,
              1.5,
              20,
              (v) => _update(letterSpacingScale: v)),
          _sliderRow(context, l10n.wmStyleLineSpacing,
              s.watermarkLineSpacingScale, 0.8, 1.4, 12,
              (v) => _update(lineSpacingScale: v)),
          const SizedBox(height: 8),
          Text(
            l10n.wmStyleFontFamily,
            style: TextStyle(color: zc.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'default',
                label: Text(l10n.wmStyleFontDefault),
              ),
              ButtonSegment(
                value: 'serif',
                label: Text(l10n.wmStyleFontSerif),
              ),
              ButtonSegment(
                value: 'mono',
                label: Text(l10n.wmStyleFontMono),
              ),
              ButtonSegment(
                value: 'condensed',
                label: Text(l10n.wmStyleFontCondensed),
              ),
            ],
            selected: {s.watermarkFontChoice},
            onSelectionChanged: (v) => _update(fontChoice: v.first),
            style: _segStyle(context),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.wmStyleFontWeight,
            style: TextStyle(color: zc.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < WatermarkFontWeight.values.length; i++)
                ChoiceChip(
                  label: Text(WatermarkFontWeight.values[i].trLabel),
                  selected: s.watermarkFontWeightIndex == i,
                  onSelected: (_) => _update(fontWeightIndex: i),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (showToggles) ...[
          _sectionTitle(context, l10n.wmStyleContentSection),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(l10n.wmStyleShowModel),
                selected: s.watermarkShowModel,
                onSelected: (v) => _update(showModel: v),
              ),
              FilterChip(
                label: Text(l10n.wmStyleShowLens),
                selected: s.watermarkShowLens,
                onSelected: (v) => _update(showLens: v),
              ),
              FilterChip(
                label: Text(l10n.wmStyleShowExposure),
                selected: s.watermarkShowExposure,
                onSelected: (v) => _update(showExposure: v),
              ),
              FilterChip(
                label: Text(l10n.wmStyleShowDate),
                selected: s.watermarkShowDate,
                onSelected: (v) => _update(showDate: v),
              ),
              FilterChip(
                label: Text(EngineL10n.wmShowBrandLogo(l10n.localeName)),
                selected: s.watermarkShowBrandLogo,
                onSelected: (v) => _update(showBrandLogo: v),
              ),
              FilterChip(
                label: Text(EngineL10n.wmShowGps(l10n.localeName)),
                selected: s.watermarkShowGps,
                onSelected: (v) => _update(showGps: v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.wmStyleShowDetails,
              style: TextStyle(color: zc.textSecondary, fontSize: 12),
            ),
            value: s.watermarkShowDetails,
            activeThumbColor: zc.accent,
            activeTrackColor: zc.accent.withAlpha(120),
            onChanged: (v) => _update(showDetails: v),
          ),
          _sectionTitle(context, l10n.wmStyleCustomTextSection),
          TextField(
            controller: _line1,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: l10n.wmStyleCustomLine1Label,
              hintText: l10n.wmStyleCustomLine1Hint,
            ),
            onChanged: (v) => _update(customLine1: v),
          ),
          TextField(
            controller: _line2,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: l10n.wmStyleCustomLine2Label,
              hintText: l10n.wmStyleCustomLine2Hint,
            ),
            onChanged: (v) => _update(customLine2: v),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.wmStyleTextAlign,
            style: TextStyle(color: zc.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final a in WatermarkTextAlign.values)
                ChoiceChip(
                  label: Text(a.trLabel),
                  selected: s.watermarkTextAlign == a.name,
                  onSelected: (_) => _update(textAlign: a.name),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
