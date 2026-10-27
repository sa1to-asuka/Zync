import 'package:flutter/material.dart';

/// Zync 2.0 专业暗房风（Pro Darkroom）全局间距 Token。
abstract final class ZSpace {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
}

/// Zync 2.0 全局圆角 Token。
abstract final class ZRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 999.0;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

/// Zync 2.0 全局描边宽度 Token。
abstract final class ZStroke {
  static const double hairline = 0.8;
  static const double regular = 1.0;
  static const double emphasis = 1.5;
}

/// Zync 2.0 动画时长与曲线 Token（遵守系统“减少动画”无障碍设置）。
abstract final class ZMotion {
  /// 150ms：按压、开关、颜色变化等微交互。
  static const Duration short = Duration(milliseconds: 150);
  static const Duration fast = short;

  /// 250ms：Tab 切换、分段控件、BottomSheet 等中尺度过渡。
  static const Duration medium = Duration(milliseconds: 250);

  /// 350ms：页面转场、Hero 过渡等大尺度动效。
  static const Duration long = Duration(milliseconds: 350);

  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard = Curves.easeOutCubic;

  /// 当系统开启“减少动画”时返回 [Duration.zero]，保证零动画干扰。
  static Duration of(BuildContext context, [Duration duration = medium]) {
    final media = MediaQuery.maybeOf(context);
    if (media != null && media.disableAnimations) {
      return Duration.zero;
    }
    return duration;
  }

  static Duration resolve(BuildContext context, [Duration duration = medium]) =>
      of(context, duration);

  /// 是否在当前上下文禁用动画。
  static bool isDisabled(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations ?? false;
  }
}

/// 四档自适应布局断点。
enum ZBreakpoint {
  /// 手机竖屏 (< 600dp)：底部悬浮胶囊导航栏。
  compact,

  /// 小平板 / 大折叠屏展开 / 手机横屏 (600–839dp)：左侧 NavigationRail。
  medium,

  /// 平板竖屏 / 中等横屏 (840–1199dp)：左侧 NavigationRail + 双栏内容。
  expanded,

  /// 平板横屏 / 桌面级大屏 (>= 1200dp)：可展开侧边栏（图标+文字+连接状态卡）。
  large;

  static ZBreakpoint ofWidth(double width) {
    if (width >= 1200) return ZBreakpoint.large;
    if (width >= 840) return ZBreakpoint.expanded;
    if (width >= 600) return ZBreakpoint.medium;
    return ZBreakpoint.compact;
  }

  static ZBreakpoint of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == ZBreakpoint.compact;
  bool get isWide => this != ZBreakpoint.compact;
  bool get isTwoPane =>
      this == ZBreakpoint.expanded || this == ZBreakpoint.large;
  bool get isLargeSidebar => this == ZBreakpoint.large;
  bool get hasExpandableSidebar => isLargeSidebar;
}

/// Zync 2.0 排版阶梯 Token（支持等宽数字 `tabularFigures`）。
class ZType {
  final TextStyle display;
  final TextStyle title;
  final TextStyle headline;
  final TextStyle body;
  final TextStyle bodySmall;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle numeric;
  final TextStyle numericSmall;

  TextStyle get overline => caption.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  TextStyle get titleMedium => headline;
  TextStyle get titleSmall => label.copyWith(fontSize: 14);
  TextStyle get labelLarge => label;
  TextStyle get mono => numeric;

  const ZType({
    required this.display,
    required this.title,
    required this.headline,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.caption,
    required this.numeric,
    required this.numericSmall,
  });

  factory ZType.fromColors({
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    const tabular = [FontFeature.tabularFigures()];
    return ZType(
      display: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.22,
        letterSpacing: -0.3,
      ),
      title: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.28,
        letterSpacing: -0.1,
      ),
      headline: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.32,
      ),
      body: TextStyle(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.42,
      ),
      label: TextStyle(
        color: textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: 0.2,
      ),
      caption: TextStyle(
        color: textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
      ),
      numeric: TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
        fontFeatures: tabular,
      ),
      numericSmall: TextStyle(
        color: textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.25,
        fontFeatures: tabular,
      ),
    );
  }
}
