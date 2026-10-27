import 'package:flutter/material.dart';
import '../palette.dart';
import '../tokens.dart';
import 'buttons.dart';

/// 手机悬浮胶囊底栏预留安全高度（窄屏列表底部避免被胶囊栏遮挡）。
const double kZFloatingNavClearance = 88.0;

/// Zync 2.0 统一页面容器骨架。
class ZPageScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomBar;
  final double? maxContentWidth;
  final bool reserveFloatingNavPadding;

  const ZPageScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    required this.body,
    this.floatingActionButton,
    this.bottomBar,
    this.maxContentWidth,
    this.reserveFloatingNavPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    Widget content = body;
    if (maxContentWidth != null) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth!),
          child: content,
        ),
      );
    }

    if (reserveFloatingNavPadding && context.zb.isCompact) {
      content = Padding(
        padding: const EdgeInsets.only(bottom: kZFloatingNavClearance),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: zc.bg,
      appBar: (title != null ||
              titleWidget != null ||
              actions != null ||
              leading != null)
          ? AppBar(
              backgroundColor: zc.bg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: leading,
              title: titleWidget ??
                  (title != null ? Text(title!, style: zt.headline) : null),
              actions: actions,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: zc.outlineVariant),
              ),
            )
          : null,
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomBar,
    );
  }
}

/// Zync 2.0 通用卡片容器（中性暗房层级表面 + 细描边）。
class ZCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool elevated;
  final bool selected;
  final BorderRadius? borderRadius;

  const ZCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZSpace.lg),
    this.margin,
    this.onTap,
    this.elevated = false,
    this.selected = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final radius = borderRadius ?? ZRadius.brLg;
    final bg = selected
        ? zc.accentContainer
        : (elevated ? zc.surfaceHigh : zc.surface);
    final borderColor = selected ? zc.accent : zc.outline;

    Widget card = AnimatedContainer(
      duration: ZMotion.of(context, ZMotion.short),
      curve: ZMotion.emphasized,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(
          color: borderColor,
          width: selected ? 1.4 : 0.8,
        ),
        boxShadow: zc.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      card = ZPressable(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      );
    }

    return card;
  }
}

/// Zync 2.0 分组卡片容器（替代 VantCellGroup）。
class ZSection extends StatelessWidget {
  final String? title;
  final String? footer;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  const ZSection({
    super.key,
    this.title,
    this.footer,
    this.trailing,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: ZSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: const EdgeInsets.only(
                left: ZSpace.xs,
                right: ZSpace.xs,
                top: ZSpace.md,
                bottom: ZSpace.xs + 2,
              ),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        style: zt.caption.copyWith(
                          color: zc.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: ZRadius.brLg,
              border: Border.all(color: zc.outline, width: 0.8),
              boxShadow: zc.cardShadow,
            ),
            child: ClipRRect(
              borderRadius: ZRadius.brLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Divider(
                        height: 1,
                        thickness: 0.7,
                        indent: ZSpace.lg,
                        color: zc.outlineVariant,
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(
                left: ZSpace.xs,
                right: ZSpace.xs,
                top: ZSpace.xs,
              ),
              child: Text(footer!, style: zt.caption),
            ),
        ],
      ),
    );
  }
}

/// Zync 2.0 列表行组件（替代 VantCell）。
class ZTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final IconData? icon;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final Widget? leading;
  final bool isLink;
  final bool isDanger;
  final VoidCallback? onTap;
  final bool showDivider;

  const ZTile({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.icon,
    this.leadingIcon,
    this.leadingColor,
    this.leading,
    this.isLink = false,
    this.isDanger = false,
    this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final effectiveIcon = icon ?? leadingIcon;
    final titleColor = isDanger ? zc.danger : zc.textPrimary;
    final iconColor = leadingColor ?? (isDanger ? zc.danger : zc.accent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.lg,
            vertical: 10,
          ),
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: zc.outlineVariant, width: 0.7),
                  ),
                )
              : null,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: ZSpace.md),
              ] else if (effectiveIcon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDanger
                        ? zc.danger.withAlpha(28)
                        : zc.surfaceHigh,
                    borderRadius: ZRadius.brSm,
                  ),
                  child: Icon(effectiveIcon, size: 17, color: iconColor),
                ),
                const SizedBox(width: ZSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: zt.body.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: zt.caption.copyWith(color: zc.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: ZSpace.sm),
                trailing!,
              ] else if (value != null) ...[
                const SizedBox(width: ZSpace.sm),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: zt.bodySmall,
                    ),
                  ),
                ),
              ],
              if (isLink) ...[
                const SizedBox(width: ZSpace.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: zc.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
