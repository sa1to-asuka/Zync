import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../palette.dart';
import '../tokens.dart';

/// 编辑器工具栏单项定义。
class ZToolItem<T> {
  final T id;
  final IconData icon;
  final String label;
  final bool hasIndicator;

  const ZToolItem({
    required this.id,
    required this.icon,
    required this.label,
    this.hasIndicator = false,
  });
}

/// 编辑器工具切换条（横向胶囊条或紧凑条）。
class ZToolRail<T> extends StatelessWidget {
  final List<ZToolItem<T>> items;
  final T selected;
  final ValueChanged<T> onSelect;

  const ZToolRail({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(
          top: BorderSide(color: zc.outlineVariant, width: 0.8),
          bottom: BorderSide(color: zc.outlineVariant, width: 0.8),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.xs,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: ZSpace.xs),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = item.id == selected;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!active) {
                HapticFeedback.selectionClick();
                onSelect(item.id);
              }
            },
            child: AnimatedContainer(
              duration: ZMotion.of(context, ZMotion.short),
              curve: ZMotion.emphasized,
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpace.md,
                vertical: ZSpace.xs,
              ),
              decoration: BoxDecoration(
                color: active ? zc.accentContainer : Colors.transparent,
                borderRadius: ZRadius.brMd,
                border: active
                    ? Border.all(color: zc.accent.withAlpha(100), width: 0.8)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 17,
                    color: active ? zc.accent : zc.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: zt.caption.copyWith(
                      fontSize: 12,
                      color: active ? zc.accent : zc.textSecondary,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (item.hasIndicator) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: zc.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 编辑器控制面板容器（修图/视频/水印/拼图共用）。
class ZPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ZPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZSpace.lg),
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    return Container(
      color: zc.surface,
      padding: padding,
      child: child,
    );
  }
}

/// 修图 / 视频 / 水印 / 拼图四个编辑器共用的响应式暗房布局骨架。
///
/// - 画布区域始终采用中性暗房灰 [ZyncPalette.canvas]（Q9），保证色彩判断准确。
/// - 窄屏（手机竖屏）：上方画布 + 下方控制区。
/// - 宽屏（平板/横屏）：左侧画布 + 右侧固定宽控制侧栏。
class ZEditorScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget canvas;
  final Widget controls;
  final double? sidePanelWidth;
  final bool extendBodyBehindAppBar;

  const ZEditorScaffold({
    super.key,
    this.appBar,
    required this.canvas,
    required this.controls,
    this.sidePanelWidth,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final isWide = context.zb.isWide;

    return Scaffold(
      backgroundColor: zc.bg,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final panelWidth = sidePanelWidth ??
              (constraints.maxWidth * 0.34).clamp(300.0, 400.0);

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: zc.canvas,
                    child: canvas,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.8,
                  color: zc.outlineVariant,
                ),
                SizedBox(
                  width: panelWidth,
                  child: ColoredBox(
                    color: zc.surface,
                    child: controls,
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: zc.canvas,
                  child: canvas,
                ),
              ),
              Divider(
                height: 1,
                thickness: 0.8,
                color: zc.outlineVariant,
              ),
              ColoredBox(
                color: zc.surface,
                child: controls,
              ),
            ],
          );
        },
      ),
    );
  }
}
