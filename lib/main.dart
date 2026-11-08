import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'core/constants/colors.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_scope.dart';
import 'core/utils/app_log_file_store.dart';
import 'core/utils/app_log_manager.dart';
import 'l10n/l10n.dart';
import 'ui/design/design.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/root_scaffold.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLogManager.instance.addError(
          details.exception,
          details.stack,
          source: 'FlutterError',
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogManager.instance
            .addError(error, stack, source: 'PlatformDispatcher');
        return true;
      };
      ErrorWidget.builder = (_) => const _ZyncErrorWidget();

      await AppLogFileStore.instance.init();

      // 启动前加载持久化设置（失败时静默使用默认值），保证语言/主题/IP等立即生效
      await AppSettings.instance.load();

      runApp(const ZyncApp());
    },
    (error, stack) {
      AppLogManager.instance.addError(error, stack, source: 'Zone');
    },
  );
}

/// 自定义绘制失败时的兜底界面。
///
/// 这里不能用 `context` 拿本地化（Widget 树可能正处于异常状态），
/// 统一走全局 `L10n.current`。
class _ZyncErrorWidget extends StatelessWidget {
  const _ZyncErrorWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.current;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: ZyncPalette.dark.bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(ZSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              color: ZyncPalette.dark.danger,
              size: 32,
            ),
            const SizedBox(height: ZSpace.md),
            Text(
              l10n.errorScreenTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZyncPalette.dark.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: ZSpace.sm),
            Text(
              l10n.errorScreenBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ZyncPalette.dark.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ZyncApp extends StatelessWidget {
  const ZyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      settings: AppSettings.instance,
      child: Builder(
        builder: (context) {
          final settings = SettingsScope.of(context);
          final resolvedLocale = resolveZyncLocale(
            settings.language,
            PlatformDispatcher.instance.locales,
          );
          L10n.syncWithLocale(resolvedLocale);

          return MaterialApp(
            onGenerateTitle: (ctx) => ctx.l10n.appTitle,
            debugShowCheckedModeBanner: false,
            theme: ZyncTheme.lightTheme,
            darkTheme: ZyncTheme.darkTheme,
            themeMode: settings.materialThemeMode,
            locale: resolvedLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) {
              final brightness = ZyncTheme.brightnessFor(
                settings.materialThemeMode,
                MediaQuery.platformBrightnessOf(context),
              );
              ZyncColors.use(brightness);
              ZyncTheme.applySystemBars(brightness);
              L10n.syncWithLocale(resolvedLocale);
              NativeLocaleBridge.sync(resolvedLocale);
              return child ?? const SizedBox.shrink();
            },
            home: PageTransitionSwitcher(
              duration: ZMotion.long,
              transitionBuilder: (child, primary, secondary) {
                return FadeThroughTransition(
                  animation: primary,
                  secondaryAnimation: secondary,
                  fillColor: ZSwatch.transparent,
                  child: child,
                );
              },
              child: settings.onboardingCompleted
                  ? const RootScaffold(key: ValueKey<String>('root_shell'))
                  : const OnboardingFlow(
                      key: ValueKey<String>('onboarding_flow'),
                    ),
            ),
          );
        },
      ),
    );
  }
}
