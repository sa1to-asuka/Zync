import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../palette.dart';
import '../tokens.dart';

/// 通用按压缩放 + 轻触觉反馈包装器（遵守系统“减少动画”设置）。
class ZPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enableHaptic;
  final BorderRadius? borderRadius;
  final HitTestBehavior behavior;

  const ZPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
    this.enableHaptic = true,
    this.borderRadius,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<ZPressable> createState() => _ZPressableState();
}

class _ZPressableState extends State<ZPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_enabled || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final duration = ZMotion.of(context, ZMotion.short);
    final scale = (_pressed && _enabled && duration > Duration.zero)
        ? widget.pressedScale
        : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTap: _enabled ? _handleTap : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: scale,
        duration: duration,
        curve: ZMotion.emphasized,
        child: widget.child,
      ),
    );
  }
}

enum ZButtonVariant { filled, primary, tonal, secondary, outlined, ghost, danger }

enum ZButtonSize { sm, md, lg }

/// Zync 2.0 统一按钮组件（替代 VantButton 与零散 ElevatedButton）。
class ZButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final ZButtonVariant variant;
  final ZButtonSize size;
  final bool isBlock;
  final bool expanded;
  final bool isRound;
  final bool isLoading;
  final bool loading;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;

  const ZButton({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.variant = ZButtonVariant.filled,
    this.size = ZButtonSize.md,
    this.isBlock = false,
    this.expanded = false,
    this.isRound = false,
    this.isLoading = false,
    this.loading = false,
    this.onTap,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final effectiveLoading = isLoading || loading;
    final effectiveBlock = isBlock || expanded;
    final effectiveOnTap = onTap ?? onPressed;
    final enabled = effectiveOnTap != null && !effectiveLoading;

    final (Color bg, Color fg, Color? borderColor) = switch (variant) {
      ZButtonVariant.filled ||
      ZButtonVariant.primary =>
        (zc.accent, zc.onAccent, null),
      ZButtonVariant.tonal ||
      ZButtonVariant.secondary =>
        (zc.accentContainer, zc.accent, null),
      ZButtonVariant.outlined => (
          zc.surface,
          zc.textPrimary,
          zc.outline,
        ),
      ZButtonVariant.ghost => (Colors.transparent, zc.textSecondary, null),
      ZButtonVariant.danger => (zc.danger, const Color(0xFFFFFFFF), null),
    };

    final (EdgeInsets padding, double iconSize, TextStyle textStyle) =
        switch (size) {
      ZButtonSize.sm => (
          const EdgeInsets.symmetric(horizontal: ZSpace.md, vertical: ZSpace.sm),
          15.0,
          zt.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ZButtonSize.md => (
          const EdgeInsets.symmetric(
            horizontal: ZSpace.lg,
            vertical: ZSpace.md,
          ),
          17.0,
          zt.label,
        ),
      ZButtonSize.lg => (
          const EdgeInsets.symmetric(
            horizontal: ZSpace.xl,
            vertical: 14.0,
          ),
          19.0,
          zt.headline.copyWith(fontSize: 15),
        ),
    };

    final radius = isRound
        ? ZRadius.brPill
        : (size == ZButtonSize.sm ? ZRadius.brSm : ZRadius.brMd);

    final effectiveBg = enabled
        ? bg
        : (variant == ZButtonVariant.ghost
            ? Colors.transparent
            : zc.surfaceHighest);
    final effectiveFg = enabled ? fg : zc.textTertiary;

    final content = Row(
      mainAxisSize: effectiveBlock ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (effectiveLoading) ...[
          SizedBox(
            width: iconSize - 2,
            height: iconSize - 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          ),
          const SizedBox(width: ZSpace.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize, color: effectiveFg),
          const SizedBox(width: ZSpace.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle.copyWith(color: effectiveFg),
          ),
        ),
        if (trailingIcon != null && !effectiveLoading) ...[
          const SizedBox(width: ZSpace.xs),
          Icon(trailingIcon, size: iconSize - 1, color: effectiveFg),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ZPressable(
        onTap: enabled ? effectiveOnTap : null,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: ZMotion.of(context, ZMotion.short),
          curve: ZMotion.emphasized,
          width: effectiveBlock ? double.infinity : null,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: radius,
            border: borderColor != null
                ? Border.all(
                    color: enabled ? borderColor : zc.outlineVariant,
                    width: 1,
                  )
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// 统一图标按钮（40dp / 48dp 标准触控区）。
class ZIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool isSelected;
  final bool isTonal;
  final Color? color;
  final Widget? badge;

  const ZIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.isSelected = false,
    this.isTonal = false,
    this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final enabled = onTap != null;
    final bg = isSelected
        ? zc.accentContainer
        : (isTonal ? zc.surfaceHigh : Colors.transparent);
    final fg = !enabled
        ? zc.textTertiary
        : (color ?? (isSelected ? zc.accent : zc.textPrimary));

    Widget button = ZPressable(
      onTap: onTap,
      borderRadius: ZRadius.brMd,
      child: AnimatedContainer(
        duration: ZMotion.of(context, ZMotion.short),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: ZRadius.brMd,
          border: isSelected
              ? Border.all(color: zc.accent.withAlpha(110), width: 1)
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: iconSize, color: fg),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: badge!,
              ),
          ],
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
