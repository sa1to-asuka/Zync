import 'package:flutter/material.dart';

import '../../../engine/capture/exposure_bracketing_controller.dart';
import '../../../engine/capture/focus_stacking_controller.dart';
import '../../../l10n/engine_l10n.dart';
import '../../../l10n/l10n.dart';
import '../../../protocol/camera_driver.dart' show MfDirection;
import '../../design/design.dart';

/// 包围曝光参数面板。返回 `null` 表示取消。
Future<ExposureBracketConfig?> showBracketConfigSheet(
  BuildContext context, {
  BracketAxis defaultAxis = BracketAxis.exposureCompensation,
}) {
  return showModalBottomSheet<ExposureBracketConfig>(
    context: context,
    backgroundColor: ZSwatch.transparent,
    isScrollControlled: true,
    builder: (_) => _BracketSheet(defaultAxis: defaultAxis),
  );
}

/// 焦点堆叠参数面板。返回 `null` 表示取消。
Future<FocusStackConfig?> showFocusStackConfigSheet(BuildContext context) {
  return showModalBottomSheet<FocusStackConfig>(
    context: context,
    backgroundColor: ZSwatch.transparent,
    isScrollControlled: true,
    builder: (_) => const _FocusStackSheet(),
  );
}

class _BracketSheet extends StatefulWidget {
  const _BracketSheet({required this.defaultAxis});

  final BracketAxis defaultAxis;

  @override
  State<_BracketSheet> createState() => _BracketSheetState();
}

class _BracketSheetState extends State<_BracketSheet> {
  late BracketAxis _axis = widget.defaultAxis;
  double _shots = 5;
  double _step = 1;
  BracketOrder _order = BracketOrder.normalFirst;
  double _settleMs = 300;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final lang = L10n.current.localeName;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(ZSpace.md),
        padding: const EdgeInsets.all(ZSpace.lg),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: ZRadius.brLg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(EngineL10n.bracketTitle(lang),
                  style: zt.title.copyWith(color: zc.textPrimary)),
              const SizedBox(height: ZSpace.md),
              Wrap(
                spacing: ZSpace.sm,
                runSpacing: ZSpace.xs,
                children: <Widget>[
                  for (final axis in BracketAxis.values)
                    GestureDetector(
                      onTap: () => setState(() => _axis = axis),
                      child: ZTag(
                        text: _axisLabel(lang, axis),
                        color: _axis == axis ? zc.accent : zc.textSecondary,
                        isOutline: _axis != axis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: ZSpace.md),
              _slider(
                context,
                label: EngineL10n.seqShotCount(lang, _shots.round()),
                value: _shots,
                min: 3,
                max: 9,
                divisions: 3,
                onChanged: (v) => setState(() => _shots = v),
              ),
              _slider(
                context,
                label: EngineL10n.seqStepCount(lang, _step.round()),
                value: _step,
                min: 1,
                max: 7,
                divisions: 6,
                onChanged: (v) => setState(() => _step = v),
              ),
              _slider(
                context,
                label: EngineL10n.seqSettleMs(lang, _settleMs.round()),
                value: _settleMs,
                min: 100,
                max: 1000,
                divisions: 9,
                onChanged: (v) => setState(() => _settleMs = v),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _order == BracketOrder.normalFirst
                          ? EngineL10n.seqOrderNormalFirst(lang)
                          : EngineL10n.seqOrderDarkToLight(lang),
                      style: zt.body.copyWith(color: zc.textPrimary),
                    ),
                  ),
                  Switch(
                    value: _order == BracketOrder.darkToLight,
                    onChanged: (v) => setState(() => _order = v
                        ? BracketOrder.darkToLight
                        : BracketOrder.normalFirst),
                  ),
                ],
              ),
              const SizedBox(height: ZSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ZButton(
                      label: context.l10n.commonCancel,
                      variant: ZButtonVariant.outlined,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: ZButton(
                      label: context.l10n.captureIntervalStart,
                      icon: Icons.play_arrow_rounded,
                      onTap: () => Navigator.of(context).pop(
                        ExposureBracketConfig(
                          axis: _axis,
                          shotCount: _shots.round(),
                          step: _step.round(),
                          order: _order,
                          settle: Duration(milliseconds: _settleMs.round()),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _axisLabel(String lang, BracketAxis axis) =>
      EngineL10n.axisLabel(lang, axis.name);

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: zt.label.copyWith(color: zc.textSecondary)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FocusStackSheet extends StatefulWidget {
  const _FocusStackSheet();

  @override
  State<_FocusStackSheet> createState() => _FocusStackSheetState();
}

class _FocusStackSheetState extends State<_FocusStackSheet> {
  double _shots = 10;
  double _step = 32;
  bool _farToNear = true;
  double _settleMs = 300;
  bool _returnToStart = false;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final lang = L10n.current.localeName;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(ZSpace.md),
        padding: const EdgeInsets.all(ZSpace.lg),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: ZRadius.brLg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(EngineL10n.focusStackTitle(lang),
                  style: zt.title.copyWith(color: zc.textPrimary)),
              const SizedBox(height: ZSpace.md),
              _slider(
                context,
                label: EngineL10n.seqShotCount(lang, _shots.round()),
                value: _shots,
                min: 2,
                max: 50,
                divisions: 48,
                onChanged: (v) => setState(() => _shots = v),
              ),
              _slider(
                context,
                label: EngineL10n.focusStepPerShot(lang, _step.round()),
                value: _step,
                min: 4,
                max: 160,
                divisions: 39,
                onChanged: (v) => setState(() => _step = v),
              ),
              _slider(
                context,
                label: EngineL10n.seqSettleMs(lang, _settleMs.round()),
                value: _settleMs,
                min: 100,
                max: 1000,
                divisions: 9,
                onChanged: (v) => setState(() => _settleMs = v),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _farToNear
                          ? EngineL10n.focusFarToNear(lang)
                          : EngineL10n.focusNearToFar(lang),
                        style: zt.body.copyWith(color: zc.textPrimary)),
                  ),
                  Switch(
                    value: _farToNear,
                    onChanged: (v) => setState(() => _farToNear = v),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(EngineL10n.focusReturnToStart(lang),
                        style: zt.body.copyWith(color: zc.textPrimary)),
                  ),
                  Switch(
                    value: _returnToStart,
                    onChanged: (v) => setState(() => _returnToStart = v),
                  ),
                ],
              ),
              const SizedBox(height: ZSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ZButton(
                      label: context.l10n.commonCancel,
                      variant: ZButtonVariant.outlined,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: ZButton(
                      label: context.l10n.captureIntervalStart,
                      icon: Icons.play_arrow_rounded,
                      onTap: () => Navigator.of(context).pop(
                        FocusStackConfig(
                          shotCount: _shots.round(),
                          step: _step.round(),
                          direction:
                              _farToNear ? MfDirection.far : MfDirection.near,
                          settle: Duration(milliseconds: _settleMs.round()),
                          returnToStart: _returnToStart,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: zt.label.copyWith(color: zc.textSecondary)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
