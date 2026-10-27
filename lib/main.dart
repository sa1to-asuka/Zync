import 'dart:ui' show PlatformDispatcher;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'core/constants/colors.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_scope.dart';
import 'l10n/l10n.dart';
import 'ui/design/design.dart';
import 'ui/onboarding/onboarding_flow.dart';
import 'ui/root_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动前加载持久化设置（失败时静默使用默认值），保证语言/主题/IP等立即生效
  await AppSettings.instance.load();

  runApp(const ZyncApp());
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
                  fillColor: Colors.transparent,
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
