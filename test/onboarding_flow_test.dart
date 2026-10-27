import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/settings/settings_scope.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/onboarding/onboarding_flow.dart';

Widget _buildTestOnboarding() {
  return SettingsScope(
    settings: AppSettings.instance,
    child: Builder(
      builder: (context) {
        final settings = SettingsScope.of(context);
        final locale = resolveZyncLocale(
          settings.language,
          const [Locale('zh', 'CN')],
        );
        L10n.syncWithLocale(locale);
        return MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ZyncTheme.lightTheme,
          darkTheme: ZyncTheme.darkTheme,
          themeMode: settings.materialThemeMode,
          home: const OnboardingFlow(),
        );
      },
    ),
  );
}

void main() {
  setUp(() {
    AppSettings.instance.resetForTest();
  });

  testWidgets('首次启动展示第 1 步语言选择，点击语言卡片即时切换引导页文案', (tester) async {
    await tester.pumpWidget(_buildTestOnboarding());
    await tester.pumpAndSettle();

    // 默认跟随系统 (zh_CN) -> 展示中文标题
    expect(find.text('选择应用语言'), findsOneWidget);

    // 点击日本語 -> 立即切换为日文
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_lang_ja')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, AppLanguage.ja);
    expect(find.text('表示言語を選択'), findsOneWidget);

    // 点击 English -> 立即切换为英文
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_lang_en')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, AppLanguage.en);
    expect(find.text('Choose Your Language'), findsOneWidget);
  });

  testWidgets('完整走完 3 步欢迎引导（语言 -> 外观 -> 工作流）并持久化完成状态', (tester) async {
    await tester.pumpWidget(_buildTestOnboarding());
    await tester.pumpAndSettle();

    // Step 1 -> Step 2
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_next_btn')));
    await tester.pumpAndSettle();
    expect(find.text('选择暗房外观'), findsOneWidget);

    // 切换浅色模式
    final lightFinder =
        find.byKey(const ValueKey<String>('onboarding_theme_light'));
    await tester.ensureVisible(lightFinder);
    await tester.tap(lightFinder);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.themeMode, AppThemeMode.light);

    // Step 2 -> Step 3
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_next_btn')));
    await tester.pumpAndSettle();
    expect(find.text('直连尼康相机工作流'), findsOneWidget);

    // 点击开始使用 -> onboardingCompleted = true
    expect(AppSettings.instance.onboardingCompleted, isFalse);
    await tester.tap(find.byKey(const ValueKey<String>('onboarding_next_btn')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.onboardingCompleted, isTrue);
  });

  testWidgets('点击跳过直接标记完成引导', (tester) async {
    await tester.pumpWidget(_buildTestOnboarding());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('onboarding_skip_btn')));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.onboardingCompleted, isTrue);
  });
}
