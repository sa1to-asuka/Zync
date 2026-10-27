import 'package:flutter/material.dart';
import '../design/tokens.dart';

export '../design/tokens.dart' show ZBreakpoint;

/// 宽屏（平板横/竖屏、大屏手机、分屏）判定断点，单位 dp。
/// 窗口宽度达到该值即启用左侧导航栏等大屏布局。
const double kAdaptiveRailBreakpoint = 600;

/// 双栏布局（平板横屏、展开态）判定断点，单位 dp。
const double kAdaptiveTwoPaneBreakpoint = 840;

/// 桌面级/大平板可展开侧边栏断点，单位 dp。
const double kAdaptiveLargeSidebarBreakpoint = 1200;

/// 当前窗口是否属于宽屏形态（>= 600dp）。
bool isAdaptiveWide(BuildContext context) =>
    ZBreakpoint.of(context).isWide;

/// 当前窗口是否属于双栏形态（>= 840dp）。
bool isAdaptiveTwoPane(BuildContext context) =>
    ZBreakpoint.of(context).isTwoPane;

/// 当前窗口是否属于大屏可展开侧栏形态（>= 1200dp）。
bool isAdaptiveLargeSidebar(BuildContext context) =>
    ZBreakpoint.of(context).isLargeSidebar;

/// 编辑类界面宽屏时的右侧操作侧栏宽度：随可用宽度缩放，并夹在舒适区间内。
double adaptiveSidePanelWidth(double availableWidth) =>
    (availableWidth * 0.34).clamp(300, 400);

/// 大屏内容居中限宽容器：把列表/表单内容限制在舒适阅读宽度内并水平居中，
/// 避免在平板上被拉满整屏。窄屏下 maxWidth 不生效，视觉零变化。
class AdaptiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AdaptiveContent({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
