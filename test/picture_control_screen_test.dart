import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/engine/picture_control/builtin_np3_recipes.dart';
import 'package:zync/engine/picture_control/picture_control_store.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/root_scaffold.dart';
import 'package:zync/ui/screens/picture_control_screen.dart';
import 'package:zync/ui/screens/settings_screen.dart';
import 'package:zync/ui/screens/watermark_screen.dart';

Widget _app(Widget child) => MaterialApp(
      theme: ZyncTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zync_pc_test_');
    await PictureControlStore.instance.ensureInitialized(
      overrideDirectory: tempDir,
    );
    AppSettings.instance.setTabletFilterViewPaged(false);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('水印工坊顶部标题「水印工坊」与设置页「设置」左上角水平位置严格一致', (tester) async {
    tester.view.physicalSize = const Size(400, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const SettingsScreen()));
    await tester.pumpAndSettle();
    final settingsTitleTopLeft = tester.getTopLeft(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('系统设置'),
      ),
    );

    await tester.pumpWidget(_app(const WatermarkScreen()));
    await _settle(tester);
    final watermarkTitleTopLeft = tester.getTopLeft(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('水印工坊'),
      ),
    );

    expect(
      watermarkTitleTopLeft,
      equals(settingsTitleTopLeft),
      reason: '水印工坊左上角标题坐标应与设置页完全一致',
    );
  });

  testWidgets('RootScaffold 底部与平板侧栏包含 5 个导航项：连接 / 相机相册 / 色彩优化 / 水印工坊 / 设置',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const RootScaffold()));
    await _settle(tester);

    final bottomBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomBar.items.length, 5);
    expect(
      bottomBar.items.map((e) => e.label).toList(),
      ['连接', '相机相册', '色彩优化', '水印工坊', '设置'],
    );
  });

  testWidgets('平板模式色彩优化页：支持单列滚动条列表与自适应高度分页切换，且包含内置与 Timor88 社区配方',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final driver = NikonDriver();
    addTearDown(driver.dispose);

    await tester.pumpWidget(_app(PictureControlScreen(driver: driver)));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // 验证已加载内置经典配方与 Timor88 配方
    expect(PictureControlStore.instance.items.length, greaterThanOrEqualTo(8));

    // 默认列表模式下存在垂直 Scrollbar
    expect(find.byType(Scrollbar), findsWidgets);

    // 切换到自适应高度分页模式
    final pagedIcon = find.byIcon(Icons.auto_stories_outlined);
    expect(pagedIcon, findsOneWidget);
    await tester.tap(pagedIcon);
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsWidgets);
    expect(AppSettings.instance.tabletFilterViewPaged, isTrue);

    // 切回相机槽位 C1–C9 页签验证未连接空状态
    final slotsTab = find.byKey(const ValueKey<String>('pc_tab_camera_slots'));
    await tester.tap(slotsTab);
    await tester.pumpAndSettle();
    expect(find.text('尚未连接尼康相机'), findsOneWidget);
  });

  test('内置配方库分类与 PicUI 云端样片完整性校验', () {
    // 验证样片场景均具备 PicUI CDN 远程图床直链
    expect(BuiltinNp3Catalog.sampleScenes.length, 8);
    for (final scene in BuiltinNp3Catalog.sampleScenes) {
      expect(scene.remoteUrl, isNotNull);
      expect(scene.remoteUrl, startsWith('https://free.picui.cn/'));
    }

    // 验证官方创作者与调色预设
    expect(BuiltinNp3Catalog.creatorSeeds.length, 47);
    for (final cs in BuiltinNp3Catalog.creatorSeeds) {
      expect(cs.noteNameZh, isNotEmpty);
      expect(cs.category, isNot(PictureControlCategory.all));
    }

    // 验证 Timor88 配方分类非空
    for (final ts in BuiltinNp3Catalog.timor88Seeds) {
      expect(ts.category, isNot(PictureControlCategory.all));
    }
  });

  testWidgets('色彩优化主界面：自由选择对比样片且挑选预设时不自动切换场景，支持左右拖拽对比手柄', (tester) async {
    tester.view.physicalSize = const Size(400, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final driver = NikonDriver();
    addTearDown(driver.dispose);

    await tester.pumpWidget(_app(PictureControlScreen(driver: driver)));
    await _settle(tester);

    // 验证存在原图与效果徽章
    expect(find.text('原图'), findsOneWidget);
    expect(find.textContaining('效果'), findsOneWidget);

    // 验证分割线手柄存在
    expect(find.byIcon(Icons.compare_arrows_rounded), findsOneWidget);

    // 切换到「风景」场景对比
    final landscapeScene = find.text('风景');
    expect(landscapeScene, findsOneWidget);
    await tester.tap(landscapeScene);
    await tester.pumpAndSettle();

    final state =
        tester.state<PictureControlScreenState>(find.byType(PictureControlScreen));
    expect(state.selectedSceneIdForTesting, 'landscape');

    // 挑选列表中的其他预设，验证场景依然锁定为用户选择的「风景」，绝不被强制跳走
    final cards = find.byType(InkWell);
    if (cards.evaluate().length > 3) {
      await tester.tap(cards.at(2));
      await tester.pumpAndSettle();
      expect(state.selectedSceneIdForTesting, 'landscape');
    }
  });
}
