import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/colors.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/settings/settings_scope.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/screens/settings_screen.dart';

void main() {
  setUp(() => AppSettings.instance.resetForTest());

  testWidgets('设置一级页只显示六个分类入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    for (final title in const [
      '外观与显示',
      '相机连接',
      '无线与传输',
      '电池与传输保护',
      '诊断与日志',
      '关于 Zync',
    ]) {
      expect(find.text(title), findsOneWidget, reason: '$title 应在一级页');
    }

    expect(find.byType(Switch), findsNothing, reason: '一级页不应直接展示开关');
    expect(find.text('默认相机 IP 地址'), findsNothing, reason: '一级页不应展示详情控件');
  });

  testWidgets('关于页展示新的 GitHub 项目地址', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于 Zync'));
    await tester.pumpAndSettle();

    expect(find.text('项目地址'), findsOneWidget);
    expect(find.text('github.com/sa1to-asuka/Zync'), findsOneWidget);
  });

  testWidgets('开源致谢页展示重点项目和真实地址', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('关于 Zync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开源致谢'));
    await tester.pumpAndSettle();

    for (final name in const [
      'ImageToolbox',
      'Recipe Lab',
      'SnapBridge-Enhanced',
      'nsg',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('https://github.com/T8RIN/ImageToolbox'), findsOneWidget);
    expect(find.text('https://github.com/hurui200320/nsg'), findsOneWidget);
  });

  testWidgets('外观详情可切换主题模式', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观与显示'));
    await tester.pumpAndSettle();

    expect(find.text('颜色预览'), findsOneWidget);
    await tester.tap(find.text('浅色').first);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.themeMode, equals(AppThemeMode.light));

    await tester.tap(find.text('深色').first);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.themeMode, equals(AppThemeMode.dark));
  });

  testWidgets('开始为深色，切到浅色后设置项立即用浅色', (tester) async {
    AppSettings.instance.setThemeMode(AppThemeMode.dark);
    ZyncColors.use(Brightness.dark);
    await tester.pumpWidget(SettingsScope(
      settings: AppSettings.instance,
      child: Builder(builder: (context) {
        final settings = SettingsScope.of(context);
        return MaterialApp(
          theme: ZyncTheme.lightTheme,
          darkTheme: ZyncTheme.darkTheme,
          themeMode: settings.materialThemeMode,
          builder: (context, child) {
            ZyncColors.use(ZyncTheme.brightnessFor(
              settings.materialThemeMode,
              MediaQuery.platformBrightnessOf(context),
            ));
            return child ?? const SizedBox.shrink();
          },
          home: const SettingsScreen(),
        );
      }),
    ));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('系统设置'))).brightness,
        Brightness.dark);
    expect(ZyncColors.textPrimary, ZyncPalette.dark.textPrimary);

    AppSettings.instance.setThemeMode(AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('系统设置'))).brightness,
        Brightness.light);
    expect(ZyncColors.card, ZyncPalette.light.card);
    expect(ZyncColors.textPrimary, ZyncPalette.light.textPrimary);
    final cellTitle = tester.widget<Text>(find.text('外观与显示'));
    expect(cellTitle.style!.color, ZyncPalette.light.textPrimary);

    // 一级设置页的选项卡片背景必须同步为白色，而不是残留深色。
    final groupContainer = tester.widget<Container>(
      find
          .descendant(
              of: find.byType(ZSection), matching: find.byType(Container))
          .first,
    );
    final groupDecoration = groupContainer.decoration! as BoxDecoration;
    expect(groupDecoration.color, ZyncPalette.light.card);
  });
}
