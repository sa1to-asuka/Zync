import 'package:flutter/material.dart';

import '../../../engine/capture/camera_property.dart';
import '../../../engine/capture/exposure_settings_controller.dart';
import '../../design/design.dart';

/// 单条曝光参数滑条。
///
/// 拖动过程只改本地下标（画面立刻跟手），松手才写相机——
/// 避免每移一格就发一次 `0x1016` 并回读。
class CaptureExposureSlider extends StatefulWidget {
  const CaptureExposureSlider({
    super.key,
    required this.parameter,
    required this.label,
    required this.binding,
    required this.onApply,
  });

  final CameraParameter parameter;
  final String label;
  final PropertyBinding? binding;
  final Future<void> Function(int rawValue) onApply;

  @override
  State<CaptureExposureSlider> createState() => _CaptureExposureSliderState();
}

class _CaptureExposureSliderState extends State<CaptureExposureSlider> {
  double? _dragIndex;

  /// 已经发给相机、但还没回读到结果的值。
  ///
  /// 写相机要经历「写 → 等 80ms → 回读」一个来回。这段时间里如果直接显示
  /// 相机上一次的值，滑条会先弹回旧位置、再跳回新位置，看起来就是抽搐。
  /// 所以松手后先把这个值「按住」，等控制器给出结果再放开。
  int? _pendingRaw;
  bool _applying = false;

  int _currentIndex(PropertyBinding binding) {
    final index = binding.options.indexOf(binding.currentValue);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(covariant CaptureExposureSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pendingRaw == null || _applying) return;
    // 写入已经结束：以相机回读到的值为准（可能被吸附到相邻档位，也可能保持不变）。
    _pendingRaw = null;
  }

  Future<void> _commit(List<int> options, int index) async {
    final raw = options[index];
    setState(() {
      _pendingRaw = raw;
      _dragIndex = null;
    });
    _applying = true;
    try {
      await widget.onApply(raw);
    } finally {
      _applying = false;
      if (mounted) {
        setState(() {
          // 相机没接受这个值（回读不一致）时，立刻显示它实际保持的值，
          // 而不是继续按用户拖到的位置显示。
          if (_pendingRaw != null &&
              widget.binding?.currentValue != _pendingRaw) {
            _pendingRaw = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final binding = widget.binding;
    // 以相机返回的 writable 为准：它会随档位变化（A 档快门只读、S 档光圈只读）。
    final editable = binding?.writable ?? false;

    if (binding == null || binding.options.isEmpty) {
      return _SliderShell(
        label: widget.label,
        valueText: '--',
        enabled: false,
        child: const SizedBox(height: 32),
      );
    }

    final options = binding.options;
    final currentIndex = _currentIndex(binding);
    final pendingIndex =
        _pendingRaw == null ? -1 : options.indexOf(_pendingRaw!);
    final baseIndex = pendingIndex >= 0 ? pendingIndex : currentIndex;
    final maxIndex = (options.length - 1).toDouble();
    final value = (_dragIndex ?? baseIndex.toDouble()).clamp(0.0, maxIndex);
    final displayIndex = value.round().clamp(0, options.length - 1);
    final valueText = binding.labelOf(options[displayIndex]);

    return _SliderShell(
      label: widget.label,
      valueText: valueText,
      enabled: editable,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: editable ? zc.accent : zc.outline,
          inactiveTrackColor: zc.outline,
          thumbColor: editable ? zc.accent : zc.textTertiary,
        ),
        child: Slider(
          value: value,
          min: 0,
          max: maxIndex <= 0 ? 1 : maxIndex,
          divisions: maxIndex <= 0 ? null : maxIndex.round(),
          label: valueText,
          onChanged:
              editable && maxIndex > 0 ? (v) => setState(() => _dragIndex = v) : null,
          onChangeEnd: editable && maxIndex > 0
              ? (v) => _commit(
                  options, v.round().clamp(0, options.length - 1))
              : null,
        ),
      ),
      trailing: editable
          ? null
          : Text(
              'LOCK',
              style: zt.overline.copyWith(color: zc.textTertiary),
            ),
    );
  }
}

class _SliderShell extends StatelessWidget {
  const _SliderShell({
    required this.label,
    required this.valueText,
    required this.enabled,
    required this.child,
    this.trailing,
  });

  final String label;
  final String valueText;
  final bool enabled;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final color = enabled ? zc.textPrimary : zc.textTertiary;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZSpace.xxs),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Text(
                label,
                style: zt.caption.copyWith(color: zc.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(child: child),
            SizedBox(
              width: 76,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  valueText,
                  style: zt.label.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: ZSpace.xs),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 大圆快门。
class CaptureShutterButton extends StatelessWidget {
  const CaptureShutterButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onTap,
    this.size = 72,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy ? zc.surfaceHigh : zc.accent,
            border: Border.all(color: zc.onAccent.withAlpha(60), width: 3),
          ),
          child: busy
              ? Padding(
                  padding: EdgeInsets.all(size * 0.28),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: zc.accent,
                  ),
                )
              : Icon(Icons.camera, color: zc.onAccent, size: size * 0.42),
        ),
      ),
    );
  }
}

/// 按住持续生效的按钮（手动对焦）。
class CaptureHoldButton extends StatefulWidget {
  const CaptureHoldButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
  });

  final IconData icon;
  final String semanticLabel;
  final bool enabled;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  State<CaptureHoldButton> createState() => _CaptureHoldButtonState();
}

class _CaptureHoldButtonState extends State<CaptureHoldButton> {
  bool _pressed = false;

  void _end() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Listener(
        onPointerDown: widget.enabled
            ? (_) {
                setState(() => _pressed = true);
                widget.onPress();
              }
            : null,
        onPointerUp: (_) => _end(),
        onPointerCancel: (_) => _end(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _pressed ? zc.accentContainer : zc.surfaceHigh,
            borderRadius: ZRadius.brSm,
            border: Border.all(
              color: _pressed ? zc.accent : zc.outline,
              width: 0.8,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 20,
            color: widget.enabled ? zc.textPrimary : zc.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// 间隔拍摄的状态条（运行时替换掉常用按钮行）。
class CaptureIntervalBar extends StatelessWidget {
  const CaptureIntervalBar({
    super.key,
    required this.progressText,
    required this.nextText,
    required this.paused,
    required this.onPauseResume,
    required this.onStop,
    required this.pauseLabel,
    required this.resumeLabel,
    required this.stopLabel,
  });

  final String progressText;
  final String? nextText;
  final bool paused;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final String pauseLabel;
  final String resumeLabel;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.accentContainer,
        borderRadius: ZRadius.brSm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 18, color: zc.accent),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(progressText, style: zt.label),
                if (nextText != null)
                  Text(
                    nextText!,
                    style: zt.caption.copyWith(color: zc.textSecondary),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPauseResume,
            child: Text(paused ? resumeLabel : pauseLabel),
          ),
          TextButton(
            onPressed: onStop,
            child: Text(stopLabel),
          ),
        ],
      ),
    );
  }
}

/// 拍照 / 录像模式切换胶囊。
///
/// 只负责展示与回调：真正的 `0xD1A6` 写入由 [MovieRecordingController] 处理，
/// 失败时（Z 30 拨杆在拍照档）由上层提示用户拨动实体拨杆。
class CaptureModePill extends StatelessWidget {
  const CaptureModePill({
    super.key,
    required this.videoMode,
    required this.enabled,
    required this.photoLabel,
    required this.videoLabel,
    required this.onChanged,
    this.width = 176,
  });

  final bool videoMode;
  final bool enabled;
  final String photoLabel;
  final String videoLabel;
  final ValueChanged<bool> onChanged;

  /// 胶囊总宽：两段等分，外层可能是无界宽度的 Row，所以这里必须给死。
  final double width;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    Widget segment(String label, IconData icon, bool selected, bool isVideo) {
      final color = selected
          ? (isVideo ? zc.danger : zc.accent)
          : zc.textSecondary;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged(isVideo) : null,
          child: AnimatedContainer(
            duration: ZMotion.short,
            curve: ZMotion.standard,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color.withAlpha(30) : ZSwatch.transparent,
              borderRadius: ZRadius.brSm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: zt.caption.copyWith(
                    color: color,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          segment(photoLabel, Icons.photo_camera_outlined, !videoMode, false),
          const SizedBox(width: 2),
          segment(videoLabel, Icons.videocam_outlined, videoMode, true),
        ],
      ),
    );
  }
}

/// 录像启停键：待机是红色圆点，录制中是红色方块。
class CaptureRecordButton extends StatelessWidget {
  const CaptureRecordButton({
    super.key,
    required this.label,
    required this.recording,
    required this.busy,
    required this.onTap,
    this.size = 72,
  });

  final String label;
  final bool recording;
  final bool busy;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final color = zc.danger;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: recording ? color.withAlpha(38) : color.withAlpha(24),
            border: Border.all(color: color, width: 2.5),
          ),
          child: Center(
            child: AnimatedContainer(
              duration: ZMotion.short,
              curve: ZMotion.standard,
              width: recording ? size * 0.30 : size * 0.46,
              height: recording ? size * 0.30 : size * 0.46,
              decoration: BoxDecoration(
                color: color,
                borderRadius:
                    BorderRadius.circular(recording ? 4 : size * 0.23),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 取景器上的 REC 角标 + 计时 + 双声道音频电平。
class CaptureRecordingBadge extends StatelessWidget {
  const CaptureRecordingBadge({
    super.key,
    required this.label,
    required this.elapsed,
    required this.leftLevel,
    required this.rightLevel,
    this.finalizingLabel,
    this.maxLevel = 14,
  });

  final String label;
  final String elapsed;

  /// 0..[maxLevel]
  final int leftLevel;
  final int rightLevel;
  final String? finalizingLabel;
  final int maxLevel;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    Widget meter(int level) {
      final ratio = (level / maxLevel).clamp(0.0, 1.0);
      return SizedBox(
        width: 42,
        height: 3,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ZSwatch.white54,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ratio > 0.85 ? zc.danger : zc.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ZSwatch.black54,
        borderRadius: ZRadius.brSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: zc.danger,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: zt.caption.copyWith(
              color: ZSwatch.pureWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            elapsed,
            style: zt.numericSmall.copyWith(color: ZSwatch.pureWhite),
          ),
          if (finalizingLabel != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              finalizingLabel!,
              style: zt.caption.copyWith(color: ZSwatch.white70),
            ),
          ],
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              meter(leftLevel),
              const SizedBox(height: 2),
              meter(rightLevel),
            ],
          ),
        ],
      ),
    );
  }
}
