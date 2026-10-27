import 'package:flutter/material.dart';
import 'tokens.dart';

/// Zync 2.0 专业暗房风（Pro Darkroom）语义调色板。
///
/// 采用中性石墨灰层级底色 + 低饱和品牌青绿（Muted Teal）单一强调色，
/// 实现 [ThemeExtension] 并支持 [lerp]，使明暗主题切换时全界面色彩平滑插值过渡。
@immutable
class ZyncPalette extends ThemeExtension<ZyncPalette> {
  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color outline;
  final Color outlineVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentStrong;
  final Color accentContainer;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color canvas;

  // 专业摄影内容通道色（直方图、示波器、对比标尺等）
  final Color channelRed;
  final Color channelGreen;
  final Color channelBlue;
  final Color channelLuma;
  final Color overlayScrim;

  const ZyncPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.outlineVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentStrong,
    required this.accentContainer,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.canvas,
    this.channelRed = const Color(0xFFE86A6A),
    this.channelGreen = const Color(0xFF5FCB8A),
    this.channelBlue = const Color(0xFF5CA8E6),
    this.channelLuma = const Color(0xFFD5DAE0),
    this.overlayScrim = const Color(0xA608090B),
  });

  bool get isDark => brightness == Brightness.dark;

  // 兼容与语义别名字段，确保全界面平滑调用
  Color get background => bg;
  Color get surfaceLow => surface;
  Color get surfaceMid => surface;
  Color get card => surface;
  Color get cardElevated => surfaceHigh;
  Color get surfaceElevated => surfaceHigh;
  Color get accentMuted => accentContainer;
  Color get border => outline;
  Color get borderLight => outlineVariant;
  Color get outlineStrong => outline;
  Color get scrim => overlayScrim;
  Color get primary => accent;
  Color get primaryDark => accentStrong;
  Color get textInverse => onAccent;

  /// 深色主题：中性石墨暗房底 + 低饱和青绿强调色。
  static const ZyncPalette dark = ZyncPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF0E0F11),
    surface: Color(0xFF16181B),
    surfaceHigh: Color(0xFF1E2125),
    surfaceHighest: Color(0xFF272A2F),
    outline: Color(0xFF2E3237),
    outlineVariant: Color(0xFF23262A),
    textPrimary: Color(0xFFEDEFF2),
    textSecondary: Color(0xFFA3A9B1),
    textTertiary: Color(0xFF7B828C),
    accent: Color(0xFF5BBFB0),
    accentStrong: Color(0xFF3E9E90),
    accentContainer: Color(0xFF1A3632),
    onAccent: Color(0xFF06201C),
    success: Color(0xFF5FCB8A),
    warning: Color(0xFFE6B35A),
    danger: Color(0xFFE86A6A),
    info: Color(0xFF5CA8E6),
    canvas: Color(0xFF18191C),
    channelRed: Color(0xFFE86A6A),
    channelGreen: Color(0xFF5FCB8A),
    channelBlue: Color(0xFF5CA8E6),
    channelLuma: Color(0xFFD5DAE0),
    overlayScrim: Color(0xB307080A),
  );

  /// 浅色主题：中性柔灰纸感底 + 深青绿强调色。
  static const ZyncPalette light = ZyncPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5F6F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEFF1F3),
    surfaceHighest: Color(0xFFE5E8EB),
    outline: Color(0xFFDADEE2),
    outlineVariant: Color(0xFFE8EBED),
    textPrimary: Color(0xFF15181B),
    textSecondary: Color(0xFF4F565E),
    textTertiary: Color(0xFF687078),
    accent: Color(0xFF237A6E),
    accentStrong: Color(0xFF195E55),
    accentContainer: Color(0xFFD6ECE8),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF1D7A46),
    warning: Color(0xFF9E5F08),
    danger: Color(0xFFB83232),
    info: Color(0xFF1E6BB8),
    canvas: Color(0xFFE8EAED),
    channelRed: Color(0xFFD14343),
    channelGreen: Color(0xFF238A52),
    channelBlue: Color(0xFF2472C8),
    channelLuma: Color(0xFF4F565E),
    overlayScrim: Color(0x800E1013),
  );

  /// 浅色模式极淡层次阴影；深色模式不投射阴影，靠明度层级与细描边区分。
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ];

  /// 悬浮胶囊导航栏 / 浮动工具栏阴影。
  List<BoxShadow> get floatingShadow => isDark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ];

  ZType get typography => ZType.fromColors(
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textTertiary: textTertiary,
      );

  @override
  ZyncPalette copyWith({
    Brightness? brightness,
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? outline,
    Color? outlineVariant,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentStrong,
    Color? accentContainer,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? canvas,
    Color? channelRed,
    Color? channelGreen,
    Color? channelBlue,
    Color? channelLuma,
    Color? overlayScrim,
  }) {
    return ZyncPalette(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      outline: outline ?? this.outline,
      outlineVariant: outlineVariant ?? this.outlineVariant,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentStrong: accentStrong ?? this.accentStrong,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      canvas: canvas ?? this.canvas,
      channelRed: channelRed ?? this.channelRed,
      channelGreen: channelGreen ?? this.channelGreen,
      channelBlue: channelBlue ?? this.channelBlue,
      channelLuma: channelLuma ?? this.channelLuma,
      overlayScrim: overlayScrim ?? this.overlayScrim,
    );
  }

  @override
  ZyncPalette lerp(covariant ThemeExtension<ZyncPalette>? other, double t) {
    if (other is! ZyncPalette) return this;
    return ZyncPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineVariant: Color.lerp(outlineVariant, other.outlineVariant, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentStrong: Color.lerp(accentStrong, other.accentStrong, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      channelRed: Color.lerp(channelRed, other.channelRed, t)!,
      channelGreen: Color.lerp(channelGreen, other.channelGreen, t)!,
      channelBlue: Color.lerp(channelBlue, other.channelBlue, t)!,
      channelLuma: Color.lerp(channelLuma, other.channelLuma, t)!,
      overlayScrim: Color.lerp(overlayScrim, other.overlayScrim, t)!,
    );
  }
}

/// 便捷上下文扩展：`context.zc` 获取当前调色板，`context.zt` 获取当前字阶。
extension ZyncDesignContext on BuildContext {
  ZyncPalette get zc {
    final theme = Theme.of(this);
    return theme.extension<ZyncPalette>() ??
        (theme.brightness == Brightness.dark
            ? ZyncPalette.dark
            : ZyncPalette.light);
  }

  ZType get zt => zc.typography;

  ZBreakpoint get zb => ZBreakpoint.of(this);
}

/// 暗房与水印/调色工坊固定色板（不随明暗主题反转的物理纸卡色、色温轨与透明色）。
abstract final class ZSwatch {
  static const Color transparent = Color(0x00000000);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color pureBlack = Color(0xFF000000);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color black87 = Color(0xDD000000);
  static const Color black54 = Color(0x8A000000);

  // 水印相纸与经典点缀色
  static const Color nikonGold = Color(0xFFFFD100);
  static const Color paperCream = Color(0xFFF5F1E8);
  static const Color paperPolaroid = Color(0xFFFAF9F6);
  static const Color paperMagazine = Color(0xFFF6F3EC);
  static const Color inkBlack = Color(0xFF101216);
  static const Color cyan = Color(0xFF37C6FF);
  static const Color magenta = Color(0xFFFF5FA2);
  static const Color darkGrey = Color(0xFF4A4A4A);

  // 线框缩略示意固定深色底
  static const Color wireframeBg = Color(0xFF222228);
  static const Color wireframePhoto = Color(0xFF282D3C);
  static const Color wireframePhotoAlt = Color(0xFF2C303E);
  static const Color wireframeOverlay = Color(0xFF232733);
  static const Color wireframeGlass = Color(0xFF1B1E28);
  static const Color wireframeGlassInner = Color(0xFF12141C);
  static const Color wireframeGlassBar = Color(0xDE13151B);
  static const Color wireframeGradBottom = Color(0xFF14161C);

  // 调色滑块色轨渐变
  static const LinearGradient wbTemperatureGradient = LinearGradient(
    colors: [Color(0xFF29B6F6), Color(0xFFFFB300)],
  );

  static const LinearGradient wbTintGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFFEC407A)],
  );

  static const LinearGradient hueRainbowGradient = LinearGradient(
    colors: [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ],
  );

  static Color fromArgb32(int value) => Color(value);

  static Color fromRgb(int r, int g, int b) => Color.fromARGB(255, r, g, b);
}
