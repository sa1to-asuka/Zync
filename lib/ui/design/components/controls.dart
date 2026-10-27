import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../palette.dart';
import '../tokens.dart';

/// 分段控件单项定义。
class ZSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const ZSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

/// Zync 2.0 滑动胶囊分段选择器（支持图标+文字、平滑滑动选中指示器）。
class ZSegmented<T> extends StatelessWidget {
  final List<ZSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool isExpanded;

  const ZSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final selectedIndex = segments
        .indexWhere((s) => s.value == selected)
        .clamp(0, segments.length - 1);
    final duration = ZMotion.of(context, ZMotion.medium);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: zc.surfaceHighest,
        borderRadius: ZRadius.brMd,
        border: Border.all(color: zc.outlineVariant, width: 0.8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          final hasBoundedWidth =
              isExpanded && constraints.maxWidth.isFinite && count > 0;
          final itemWidth = hasBoundedWidth ? constraints.maxWidth / count : null;

          return Stack(
            children: [
              if (hasBoundedWidth && itemWidth != null)
                AnimatedPositioned(
                  duration: duration,
                  curve: ZMotion.emphasized,
                  left: selectedIndex * itemWidth,
                  top: 0,
                  bottom: 0,
                  width: itemWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: zc.surface,
                      borderRadius: ZRadius.brSm,
                      border: Border.all(color: zc.outline, width: 0.8),
                      boxShadow: zc.cardShadow,
                    ),
                  ),
                ),
              Row(
                mainAxisSize:
                    isExpanded ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      flex: isExpanded ? 1 : 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (segments[i].value != selected) {
                            HapticFeedback.selectionClick();
                            onChanged(segments[i].value);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZSpace.md,
                            vertical: ZSpace.sm,
                          ),
                          decoration: !hasBoundedWidth && i == selectedIndex
                              ? BoxDecoration(
                                  color: zc.surface,
                                  borderRadius: ZRadius.brSm,
                                  border: Border.all(
                                    color: zc.outline,
                                    width: 0.8,
                                  ),
                                )
                              : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (segments[i].icon != null) ...[
                                Icon(
                                  segments[i].icon,
                                  size: 15,
                                  color: i == selectedIndex
                                      ? zc.accent
                                      : zc.textSecondary,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  segments[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: zt.caption.copyWith(
                                    fontSize: 12,
                                    fontWeight: i == selectedIndex
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: i == selectedIndex
                                        ? zc.textPrimary
                                        : zc.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 专业暗房参数滑块（双击归零、等宽数字读数、拖动过程零额外动画确保帧率）。
class ZSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final int? divisions;
  final String? valueText;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final bool dense;

  const ZSlider({
    super.key,
    required this.label,
    required this.value,
    this.min = -100,
    this.max = 100,
    this.defaultValue = 0,
    this.divisions,
    this.valueText,
    this.onChanged,
    this.onChangeEnd,
    this.dense = false,
  });

  bool get _isModified => (value - defaultValue).abs() > 0.001;

  void _resetToDefault() {
    if (onChanged == null || !_isModified) return;
    HapticFeedback.lightImpact();
    onChanged!(defaultValue);
    onChangeEnd?.call(defaultValue);
  }

  String _formatDefault(double v) {
    if (max - min <= 2.0) {
      return v.toStringAsFixed(2);
    }
    final rounded = v.round();
    if (min < 0 && rounded > 0) return '+$rounded';
    return '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final clamped = value.clamp(min, max);
    final displayValue = valueText ?? _formatDefault(clamped);

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? ZSpace.xxs : ZSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: _resetToDefault,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpace.xs),
              child: Row(
                children: [
                  if (_isModified)
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: zc.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: zt.caption.copyWith(
                        fontSize: 12,
                        color: _isModified ? zc.textPrimary : zc.textSecondary,
                        fontWeight:
                            _isModified ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    displayValue,
                    style: zt.numericSmall.copyWith(
                      color: _isModified ? zc.accent : zc.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: dense ? 2.5 : 3.0,
              activeTrackColor: _isModified ? zc.accent : zc.textSecondary,
              inactiveTrackColor: zc.surfaceHighest,
              thumbColor: _isModified ? zc.accent : zc.textPrimary,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: dense ? 6.0 : 7.0,
              ),
            ),
            child: SizedBox(
              height: dense ? 26 : 30,
              child: Slider(
                value: clamped,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ZStatusTone { accent, success, warning, danger, neutral }

/// Zync 2.0 状态/格式小标签（替代 VantTag，如 RAW / JPG / 已导出）。
class ZTag extends StatelessWidget {
  final String text;
  final Color? color;
  final bool isOutline;
  final bool compact;
  final IconData? icon;

  const ZTag({
    super.key,
    required this.text,
    this.color,
    this.isOutline = false,
    this.compact = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final tone = color ?? zc.accent;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 6,
        vertical: compact ? 1.5 : 2,
      ),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : tone.withAlpha(32),
        borderRadius: ZRadius.brXs,
        border: Border.all(
          color: isOutline ? tone : tone.withAlpha(90),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: tone),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: zt.caption.copyWith(
              color: tone,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// 连接状态胶囊指示器（支持连接中呼吸动效，遵守“减少动画”设置）。
class ZStatusPill extends StatefulWidget {
  final String? label;
  final String? text;
  final Color? dotColor;
  final ZStatusTone? tone;
  final bool pulsing;
  final VoidCallback? onTap;

  const ZStatusPill({
    super.key,
    this.label,
    this.text,
    this.dotColor,
    this.tone,
    this.pulsing = false,
    this.onTap,
  });

  @override
  State<ZStatusPill> createState() => _ZStatusPillState();
}

class _ZStatusPillState extends State<ZStatusPill>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ZStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.pulsing) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      )..repeat(reverse: true);
    } else {
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final resolvedToneColor = switch (widget.tone) {
      ZStatusTone.accent => zc.accent,
      ZStatusTone.success => zc.success,
      ZStatusTone.warning => zc.warning,
      ZStatusTone.danger => zc.danger,
      ZStatusTone.neutral => zc.textTertiary,
      null => zc.accent,
    };
    final dot = widget.dotColor ?? resolvedToneColor;
    final displayText = widget.label ?? widget.text ?? '';
    final animate = widget.pulsing && !ZMotion.isDisabled(context);

    Widget dotWidget = Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    );

    if (animate && _controller != null) {
      dotWidget = FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_controller!),
        child: dotWidget,
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: zc.surfaceHigh,
          borderRadius: ZRadius.brPill,
          border: Border.all(color: zc.outline, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dotWidget,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: zt.caption.copyWith(
                  color: zc.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
