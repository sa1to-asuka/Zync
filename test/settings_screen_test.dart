import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/colors.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/settings/settings_scope.dart';
import 'package:zync/engine/ai/ai_provider_config.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/screens/settings/ai_settings_section.dart';
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

    await tester.ensureVisible(find.text('关于 Zync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于 Zync'));
    await tester.pumpAndSettle();

    expect(find.text('项目地址'), findsOneWidget);
    expect(find.text('github.com/sa1to-asuka/Zync'), findsOneWidget);
  });

  testWidgets('开源致谢页展示重点项目和真实地址', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('关于 Zync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于 Zync'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('开源致谢'));
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

  group('AI 设置页风格一致、自适应与无识图限制', () {
    testWidgets('使用 ZTile + Switch 且放行 DeepSeek 模型，无不支持识图限制', (tester) async {
      final tmp = await tester.runAsync(
          () => Directory.systemTemp.createTemp('zync_ai_settings_test_'));
      addTearDown(() async {
        try {
          if (tmp != null && tmp.existsSync()) tmp.deleteSync(recursive: true);
        } catch (_) {}
      });

      await tester.runAsync(() async {
        final store = AiSettingsStore.instance;
        await store.ensureInitialized(overrideDirectory: tmp);
        await store.upsertProfile(
          const AiProviderProfile(
            id: 'p_deepseek',
            name: 'DeepSeek 官方',
            protocol: AiApiProtocol.openAiCompatible,
            baseUrl: 'https://api.deepseek.com/v1',
            importedModels: [
              AiImportedModel(
                id: 'deepseek-chat',
                displayName: 'deepseek-chat',
                visionHint: false,
                visionVerified: false,
              ),
            ],
          ),
          apiKey: 'sk-deepseek-test',
        );
        await store.setActiveCoach('p_deepseek', 'deepseek-chat');
        await store.setActiveGrade('p_deepseek', 'deepseek-chat');
      });

      for (final cfg in const [
        (locale: Locale('zh'), size: Size(390, 844)),
        (locale: Locale('en'), size: Size(1024, 768)),
        (locale: Locale('ja'), size: Size(1024, 768)),
      ]) {
        tester.view.physicalSize = cfg.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: cfg.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ZyncTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: AiSettingsDetailContent()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.byType(ZTile), findsWidgets);
        expect(find.byType(Switch), findsNWidgets(2));
        expect(find.text('不支持识图'), findsNothing);
        expect(find.text('deepseek-chat'), findsOneWidget);
      }
    });

    testWidgets('协议选择卡片选中态视觉对比清晰（浅色/深色主题）', (tester) async {
      final tmp = await tester.runAsync(
          () => Directory.systemTemp.createTemp('zync_ai_proto_test_'));
      addTearDown(() async {
        try {
          if (tmp != null && tmp.existsSync()) tmp.deleteSync(recursive: true);
        } catch (_) {}
      });
      await tester.runAsync(
          () => AiSettingsStore.instance.ensureInitialized(overrideDirectory: tmp));

      for (final theme in [ZyncTheme.lightTheme, ZyncTheme.darkTheme]) {
        final palette = theme.extension<ZyncPalette>()!;
        tester.view.physicalSize = const Size(400, 840);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: const Scaffold(
              body: SingleChildScrollView(child: AiSettingsDetailContent()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('添加接口档案'));
        await tester.tap(find.text('添加接口档案'));
        await tester.pumpAndSettle();

        // 默认选中 OpenAI 兼容：应显示高亮容器底色与勾选图标
        final openAiText = tester.widget<Text>(find.text('OpenAI 兼容').first);
        expect(openAiText.style!.color, palette.accent);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        // 切换到 Anthropic 兼容：选中高亮与勾选图标跟随切换
        await tester.tap(find.text('Anthropic 兼容').first);
        await tester.pumpAndSettle();
        final anthropicText =
            tester.widget<Text>(find.text('Anthropic 兼容').first);
        expect(anthropicText.style!.color, palette.accent);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      }
    });
  });
}
