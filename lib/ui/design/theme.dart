import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'palette.dart';
import 'tokens.dart';

/// Zync 2.0 专业暗房风主题构建器。
abstract final class ZyncTheme {
  static ThemeData get darkTheme => build(ZyncPalette.dark);

  static ThemeData get lightTheme => build(ZyncPalette.light);

  /// 将外观模式解析为实际亮度。
  static Brightness brightnessFor(
    ThemeMode mode,
    Brightness platformBrightness,
  ) =>
      switch (mode) {
        ThemeMode.dark => Brightness.dark,
        ThemeMode.light => Brightness.light,
        ThemeMode.system => platformBrightness,
      };

  /// 同步更新系统状态栏与底部手势导航栏样式。
  static void applySystemBars(Brightness brightness) {
    final palette =
        brightness == Brightness.dark ? ZyncPalette.dark : ZyncPalette.light;
    final iconBrightness =
        brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: brightness,
        systemNavigationBarColor: palette.bg,
        systemNavigationBarIconBrightness: iconBrightness,
      ),
    );
  }

  static ThemeData build(ZyncPalette palette) {
    final isDark = palette.isDark;
    final typo = palette.typography;

    final scheme = ColorScheme(
      brightness: palette.brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentContainer,
      onPrimaryContainer: palette.textPrimary,
      secondary: palette.accentStrong,
      onSecondary: palette.onAccent,
      secondaryContainer: palette.surfaceHigh,
      onSecondaryContainer: palette.textPrimary,
      error: palette.danger,
      onError: const Color(0xFFFFFFFF),
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.outline,
      outlineVariant: palette.outlineVariant,
    );

    final textTheme = TextTheme(
      displaySmall: typo.display,
      headlineMedium: typo.title,
      titleLarge: typo.title,
      titleMedium: typo.headline,
      titleSmall: typo.label,
      bodyLarge: typo.body,
      bodyMedium: typo.bodySmall,
      bodySmall: typo.caption,
      labelLarge: typo.label,
      labelMedium: typo.bodySmall,
      labelSmall: typo.caption,
    );

    const transitionsBuilder = ZyncSharedAxisPageTransitionsBuilder();

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.surface,
      cardColor: palette.surface,
      dividerColor: palette.outlineVariant,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: transitionsBuilder,
          TargetPlatform.iOS: transitionsBuilder,
          TargetPlatform.windows: transitionsBuilder,
          TargetPlatform.macOS: transitionsBuilder,
          TargetPlatform.linux: transitionsBuilder,
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: typo.headline,
        iconTheme: IconThemeData(color: palette.textPrimary, size: 20),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.accent,
        unselectedItemColor: palette.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: typo.caption.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: typo.caption,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accentContainer,
        selectedIconTheme: IconThemeData(color: palette.accent, size: 22),
        unselectedIconTheme:
            IconThemeData(color: palette.textTertiary, size: 22),
        selectedLabelTextStyle: typo.caption.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: typo.caption,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brLg,
          side: BorderSide(color: palette.outline, width: 0.8),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: ZSpace.lg,
          vertical: ZSpace.xs,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        inactiveTrackColor: palette.surfaceHighest,
        thumbColor: palette.accent,
        overlayColor: palette.accent.withAlpha(36),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          disabledBackgroundColor: palette.surfaceHighest,
          disabledForegroundColor: palette.textTertiary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.lg,
            vertical: ZSpace.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: ZRadius.brMd),
          textStyle: typo.label,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.outline, width: 1),
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.lg,
            vertical: ZSpace.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: ZRadius.brMd),
          textStyle: typo.label,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          shape: const RoundedRectangleBorder(borderRadius: ZRadius.brSm),
          textStyle: typo.label,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.md,
        ),
        labelStyle: typo.bodySmall,
        hintStyle: typo.bodySmall.copyWith(color: palette.textTertiary),
        border: OutlineInputBorder(
          borderRadius: ZRadius.brMd,
          borderSide: BorderSide(color: palette.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: ZRadius.brMd,
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: ZRadius.brMd,
          borderSide: BorderSide(color: palette.accent, width: 1.4),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brXl,
          side: BorderSide(color: palette.outline, width: 0.8),
        ),
        titleTextStyle: typo.headline,
        contentTextStyle: typo.bodySmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        modalBackgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ZRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brMd,
          side: BorderSide(color: palette.outline, width: 0.8),
        ),
        textStyle: typo.body,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceHigh,
        contentTextStyle: typo.body.copyWith(color: palette.textPrimary),
        actionTextColor: palette.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brMd,
          side: BorderSide(color: palette.outline, width: 0.8),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.onAccent
              : palette.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : palette.surfaceHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : palette.outline,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(palette.onAccent),
        side: BorderSide(color: palette.outline, width: 1.4),
        shape: const RoundedRectangleBorder(borderRadius: ZRadius.brXs),
      ),
      dividerTheme: DividerThemeData(
        color: palette.outlineVariant,
        thickness: isDark ? 0.7 : 0.8,
        space: 1,
      ),
    );
  }
}

/// 统一水平 SharedAxis 页面转场（遵守系统“减少动画”设置）。
class ZyncSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const ZyncSharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (ZMotion.isDisabled(context)) {
      return child;
    }

    final primaryCurved = CurvedAnimation(
      parent: animation,
      curve: ZMotion.emphasizedDecelerate,
      reverseCurve: ZMotion.emphasizedAccelerate,
    );
    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: ZMotion.emphasizedDecelerate,
      reverseCurve: ZMotion.emphasizedAccelerate,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.06, 0),
      ).animate(secondaryCurved),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.92).animate(secondaryCurved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(primaryCurved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
