import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/root_scaffold.dart';
import 'package:zync/ui/screens/settings_screen.dart';
import 'helpers/pump_app.dart';

void main() {
  setUp(() {
    AppSettings.instance.resetForTest();
  });

  testWidgets('360dp 窄屏使用底部悬浮胶囊导航栏', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpZyncApp(
      tester,
      const RootScaffold(),
      locale: const Locale('en'),
    );

    expect(
      find.byKey(const ValueKey<String>('zync_floating_pill_nav')),
      findsOneWidget,
    );
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Camera Roll'), findsOneWidget);
  });

  testWidgets('700dp 与 1000dp 平板使用紧凑型左侧 NavigationRail', (tester) async {
    for (final width in <double>[700, 1000]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpZyncApp(
        tester,
        const RootScaffold(),
        locale: const Locale('ja'),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse, reason: '${width}dp 下默认应为紧凑型 Rail');
      expect(
        find.byKey(const ValueKey<String>('zync_sidebar_camera_card')),
        findsNothing,
      );
      expect(find.text('カメラロール'), findsOneWidget);
    }
  });

  testWidgets('1280dp 大屏自动展开侧边栏并展示相机状态卡，支持手动折叠', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpZyncApp(
      tester,
      const RootScaffold(),
      locale: const Locale('zh'),
    );

    NavigationRail rail() =>
        tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail().extended, isTrue);
    expect(
      find.byKey(const ValueKey<String>('zync_sidebar_camera_card')),
      findsOneWidget,
    );

    // 点击折叠按钮 -> 收起侧边栏
    await tester.tap(
      find.byKey(const ValueKey<String>('zync_sidebar_toggle_button')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(rail().extended, isFalse);
    expect(
      find.byKey(const ValueKey<String>('zync_sidebar_camera_card')),
      findsNothing,
    );
  });

  testWidgets('设置页在宽屏(>=840dp)采用左右双栏并支持切换三语', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: AppSettings.instance,
        builder: (context, _) {
          final locale = resolveZyncLocale(
            AppSettings.instance.language,
            const [Locale('zh', 'CN')],
          );
          L10n.syncWithLocale(locale);
          return MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ZyncTheme.darkTheme,
            home: const SettingsScreen(),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    // 点击左侧语言设置项
    await tester.tap(
      find.byKey(const ValueKey<String>('settings_tile_language')),
    );
    await tester.pumpAndSettle();

    // 选择 English
    await tester.tap(
      find.byKey(const ValueKey<String>('settings_lang_en')),
    );
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, AppLanguage.en);
    expect(find.text('Appearance & Display'), findsOneWidget);

    // 选择 日本語
    await tester.tap(
      find.byKey(const ValueKey<String>('settings_lang_ja')),
    );
    await tester.pumpAndSettle();
    expect(AppSettings.instance.language, AppLanguage.ja);
    expect(find.text('外観と表示'), findsOneWidget);
  });
}
