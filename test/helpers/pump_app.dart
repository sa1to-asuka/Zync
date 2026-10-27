import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/colors.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/settings/settings_scope.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/ui/design/design.dart';

/// 统一 Widget 测试挂载辅助函数：注入 [SettingsScope]、[ZyncTheme] 与 [AppLocalizations]。
Future<void> pumpZyncApp(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('zh'),
  Brightness brightness = Brightness.dark,
  Size? surfaceSize,
  AppSettings? settings,
}) async {
  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final activeSettings = settings ?? AppSettings.instance;
  L10n.syncWithLocale(locale);
  ZyncColors.use(brightness);

  await tester.pumpWidget(
    SettingsScope(
      settings: activeSettings,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ZyncTheme.lightTheme,
        darkTheme: ZyncTheme.darkTheme,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        home: home,
      ),
    ),
  );
}
