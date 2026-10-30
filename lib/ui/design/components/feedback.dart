import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../palette.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'controls.dart';

/// 提示条在大屏上的最大宽度（与底部 Sheet 的 560 保持一致）。
const double _kZToastMaxWidth = 560;

/// 全应用统一的底部浮层入口（自动带顶部拖拽条、大屏宽度限制与暗房风描边）。
Future<T?> showZSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  Widget? trailing,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  double maxWidth = 560,
}) {
  final zc = context.zc;
  final zt = context.zt;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: zc.surface,
    barrierColor: zc.overlayScrim,
    constraints: BoxConstraints(maxWidth: maxWidth),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(ZRadius.xl),
      ),
      side: BorderSide(color: zc.outline, width: 0.8),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: ZSpace.sm),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: zc.outline,
                  borderRadius: ZRadius.brPill,
                ),
              ),
            ),
            if (title != null || trailing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZSpace.lg,
                  ZSpace.md,
                  ZSpace.lg,
                  ZSpace.sm,
                ),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Text(title, style: zt.headline),
                      )
                    else
                      const Spacer(),
                    if (trailing != null) trailing,
                  ],
                ),
              )
            else
              const SizedBox(height: ZSpace.sm),
            Flexible(child: builder(sheetCtx)),
          ],
        ),
      );
    },
  );
}

/// 全应用统一的模态对话框入口。
Future<T?> showZDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final zc = context.zc;
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: zc.overlayScrim,
    builder: builder,
  );
}

/// 标准暗房风对话框组件。
class ZDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final String? cancelLabel;
  final String? confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final bool isDanger;

  const ZDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions,
    this.cancelLabel,
    this.confirmLabel,
    this.onCancel,
    this.onConfirm,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Dialog(
      backgroundColor: zc.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: ZSpace.xl,
        vertical: ZSpace.xl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: ZRadius.brXl,
        side: BorderSide(color: zc.outline, width: 0.8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(ZSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: zt.headline),
              if (message != null) ...[
                const SizedBox(height: ZSpace.sm),
                Text(message!, style: zt.bodySmall),
              ],
              if (content != null) ...[
                const SizedBox(height: ZSpace.md),
                Flexible(child: content!),
              ],
              const SizedBox(height: ZSpace.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions ??
                    [
                      if (cancelLabel != null) ...[
                        ZButton(
                          label: cancelLabel!,
                          variant: ZButtonVariant.ghost,
                          size: ZButtonSize.sm,
                          onTap: onCancel ??
                              () => Navigator.of(context).pop(false),
                        ),
                        const SizedBox(width: ZSpace.sm),
                      ],
                      if (confirmLabel != null)
                        ZButton(
                          label: confirmLabel!,
                          variant: isDanger
                              ? ZButtonVariant.danger
                              : ZButtonVariant.filled,
                          size: ZButtonSize.sm,
                          onTap: onConfirm ??
                              () => Navigator.of(context).pop(true),
                        ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 全应用统一的浮动轻提示入口（带微型关闭按钮、点击即隐，并限制大屏宽度）。
void showZToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 2200),
  bool isError = false,
  ZStatusTone? tone,
  SnackBarAction? action,
  double? bottomMargin,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final zc = context.zc;
  final zt = context.zt;
  final effectiveError = isError || tone == ZStatusTone.danger;
  final borderColor = switch (tone) {
    ZStatusTone.danger => zc.danger,
    ZStatusTone.warning => zc.warning,
    ZStatusTone.success => zc.success,
    ZStatusTone.accent => zc.accent,
    _ => effectiveError ? zc.danger : zc.outline,
  };

  // SnackBar 的 width 与 margin 互斥，用对称水平 margin 实现「限宽 + 居中」：
  // 手机保持左右 16，大屏按 560 上限自动加大左右留白。
  final horizontal = math.max(
    ZSpace.lg,
    (MediaQuery.sizeOf(context).width - _kZToastMaxWidth) / 2,
  );
  final bottomGap = bottomMargin ?? ZSpace.md;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: zc.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: horizontal,
          right: horizontal,
          bottom: bottomGap,
        ),
        dismissDirection: DismissDirection.horizontal,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brMd,
          side: BorderSide(
            color: borderColor.withAlpha(180),
            width: 0.9,
          ),
        ),
        content: InkWell(
          onTap: () => messenger.hideCurrentSnackBar(),
          child: Row(
            children: [
              if (effectiveError) ...[
                Icon(Icons.error_outline_rounded, size: 18, color: zc.danger),
                const SizedBox(width: ZSpace.sm),
              ] else if (tone == ZStatusTone.success) ...[
                Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: zc.success),
                const SizedBox(width: ZSpace.sm),
              ],
              Expanded(
                child: Text(
                  message,
                  style: zt.bodySmall.copyWith(
                    color: zc.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: ZSpace.xs),
              // 小小的关闭按钮，点按立即消失
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => messenger.hideCurrentSnackBar(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: zc.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: action,
      ),
    );
}

/// 统一空状态 / 未连接提示组件。
class ZEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const ZEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: ZRadius.brXl,
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                child: Icon(icon, size: 28, color: zc.textSecondary),
              ),
              const SizedBox(height: ZSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: zt.headline,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: ZSpace.sm),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: zt.bodySmall,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: ZSpace.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 暗房风加载骨架屏（遵守系统“减少动画”设置）。
class ZSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const ZSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = ZRadius.brSm,
  });

  @override
  State<ZSkeleton> createState() => _ZSkeletonState();
}

class _ZSkeletonState extends State<ZSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    if (ZMotion.isDisabled(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: zc.surfaceHigh,
          borderRadius: widget.borderRadius,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color = Color.lerp(
          zc.surfaceHigh,
          zc.surfaceHighest,
          _controller.value,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}
