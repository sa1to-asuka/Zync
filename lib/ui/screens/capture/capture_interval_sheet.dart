import 'package:flutter/material.dart';

import '../../../engine/capture/interval_shooting_controller.dart';
import '../../../l10n/l10n.dart';
import '../../design/design.dart';

/// 间隔拍摄参数面板。返回 `null` 表示取消。
Future<IntervalShootingConfig?> showIntervalConfigSheet(
  BuildContext context, {
  required int defaultSeconds,
  required int defaultCount,
}) {
  return showModalBottomSheet<IntervalShootingConfig>(
    context: context,
    backgroundColor: ZSwatch.transparent,
    isScrollControlled: true,
    builder: (_) => _IntervalSheet(
      defaultSeconds: defaultSeconds,
      defaultCount: defaultCount,
    ),
  );
}

class _IntervalSheet extends StatefulWidget {
  const _IntervalSheet({
    required this.defaultSeconds,
    required this.defaultCount,
  });

  final int defaultSeconds;
  final int defaultCount;

  @override
  State<_IntervalSheet> createState() => _IntervalSheetState();
}

class _IntervalSheetState extends State<_IntervalSheet> {
  late double _seconds;
  late double _count;
  double _delay = 0;
  bool _unlimited = false;
  bool _keepLiveView = false;

  @override
  void initState() {
    super.initState();
    _seconds = widget.defaultSeconds.clamp(2, 300).toDouble();
    _count = widget.defaultCount.clamp(1, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(ZSpace.md),
        padding: const EdgeInsets.all(ZSpace.lg),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: ZRadius.brLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l10n.captureIntervalTitle,
                style: zt.title.copyWith(color: zc.textPrimary)),
            const SizedBox(height: ZSpace.md),
            _row(
              context,
              label: l10n.captureIntervalSeconds(_seconds.round()),
              value: _seconds,
              min: 2,
              max: 300,
              divisions: 298,
              onChanged: (v) => setState(() => _seconds = v),
            ),
            _row(
              context,
              label: _unlimited
                  ? l10n.captureIntervalUnlimitedShots
                  : l10n.captureIntervalCount(_count.round()),
              value: _count,
              min: 1,
              max: 100,
              divisions: 99,
              enabled: !_unlimited,
              onChanged: (v) => setState(() => _count = v),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.captureIntervalUnlimitedShots,
                      style: zt.body.copyWith(color: zc.textPrimary)),
                ),
                Switch(
                  value: _unlimited,
                  onChanged: (v) => setState(() => _unlimited = v),
                ),
              ],
            ),
            _row(
              context,
              label: l10n.captureIntervalDelay(_delay.round()),
              value: _delay,
              min: 0,
              max: 30,
              divisions: 30,
              onChanged: (v) => setState(() => _delay = v),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.captureIntervalKeepLiveView,
                      style: zt.body.copyWith(color: zc.textPrimary)),
                ),
                Switch(
                  value: _keepLiveView,
                  onChanged: (v) => setState(() => _keepLiveView = v),
                ),
              ],
            ),
            const SizedBox(height: ZSpace.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: ZButton(
                    label: l10n.commonCancel,
                    variant: ZButtonVariant.outlined,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: ZSpace.sm),
                Expanded(
                  child: ZButton(
                    label: l10n.captureIntervalStart,
                    icon: Icons.play_arrow_rounded,
                    onTap: () => Navigator.of(context).pop(
                      IntervalShootingConfig(
                        interval: Duration(seconds: _seconds.round()),
                        shotCount: _unlimited ? 0 : _count.round(),
                        startDelay: Duration(seconds: _delay.round()),
                        keepLiveView: _keepLiveView,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: zt.label.copyWith(color: zc.textSecondary)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
