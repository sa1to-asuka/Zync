import 'package:flutter/material.dart';
import '../../ui/design/palette.dart';

export '../../ui/design/palette.dart' show ZyncPalette, ZyncDesignContext;

/// Zync 2.0 颜色兼容转发层。
///
/// 新代码请统一使用 `context.zc`（即 [ZyncPalette] `ThemeExtension`）；
/// 此处保留 `ZyncColors.of(context)` 与静态 getter 以保证各阶段平滑迁移。
class ZyncColors {
  ZyncColors._();

  static ZyncPalette _current = ZyncPalette.dark;

  static ZyncPalette of(BuildContext context) => context.zc;

  static void use(Brightness brightness) {
    _current =
        brightness == Brightness.dark ? ZyncPalette.dark : ZyncPalette.light;
  }

  static Color get background => _current.bg;
  static Color get surface => _current.surface;
  static Color get card => _current.surface;
  static Color get cardElevated => _current.surfaceHigh;
  static Color get border => _current.outline;
  static Color get borderLight => _current.outlineVariant;
  static Color get primary => _current.accent;
  static Color get primaryDark => _current.accentStrong;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textTertiary => _current.textTertiary;
  static Color get textInverse => _current.onAccent;
  static Color get success => _current.success;
  static Color get warning => _current.warning;
  static Color get danger => _current.danger;

  // 品牌色（低饱和青绿）
  static const Color zyncCyan = Color(0xFF5BBFB0);
  static const Color zyncTeal = Color(0xFF237A6E);
  static const Color zyncDeep = Color(0xFF0E0F11);
  static const Color info = Color(0xFF5CA8E6);

  // 导出卡片浅色常量（用于水印画布固定浅色模式）
  static const Color vantLightBg = Color(0xFFF5F6F7);
  static const Color vantLightCard = Color(0xFFFFFFFF);
  static const Color vantLightBorder = Color(0xFFDADEE2);
  static const Color vantLightText = Color(0xFF15181B);
  static const Color vantLightSubText = Color(0xFF687078);
}
