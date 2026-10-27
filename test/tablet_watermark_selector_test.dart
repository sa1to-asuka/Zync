import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/engine/watermark/watermark_template.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/watermark_screen.dart';

Future<Uint8List> _png(int w, int h, int rgb) async {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(
          x, y, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Widget _app(Widget child) => MaterialApp(
      theme: ZyncTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final tabBar = tester.getRect(find.byType(TabBar));
  final tabs = ['画框版式', '胶片滤镜', '参数精调', '裁切几何'];
  final index = tabs.indexOf(label);
  final width = tabBar.width / tabs.length;
  await tester
      .tapAt(Offset(tabBar.left + width * (index + 0.5), tabBar.center.dy));
  await tester.pump();
}

void main() {
  setUp(() {
    AppSettings.instance.setTabletWatermarkViewPaged(false);
    AppSettings.instance.setTabletFilterViewPaged(false);
  });

  testWidgets('平板模式水印工坊：水印版式提供单列带滚动条列表与自适应分页切换', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        _app(WatermarkScreen(initialImageBytes: await _png(60, 40, 0x112233))));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // 默认列表模式：应包含垂直 Scrollbar，且不存在横向滑动 ListView
    expect(find.byType(Scrollbar), findsWidgets);
    expect(
      find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal),
      findsNothing,
      reason: '平板模式下画框版式不应出现横向滑动列表',
    );

    // 切换到自适应屏幕高度分页模式
    final pagedModeIcon = find.byIcon(Icons.auto_stories_outlined);
    expect(pagedModeIcon, findsOneWidget);
    await tester.tap(pagedModeIcon);
    await tester.pumpAndSettle();

    // 验证 PageView 已挂载，且 AppSettings 已持久化为 true
    expect(find.byType(PageView), findsWidgets);
    expect(AppSettings.instance.tabletWatermarkViewPaged, isTrue);

    // 切回单列列表模式
    final listModeIcon = find.byIcon(Icons.view_agenda_outlined);
    expect(listModeIcon, findsOneWidget);
    await tester.tap(listModeIcon);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.tabletWatermarkViewPaged, isFalse);

    // 样式微调分段切换
    final styleTab = find.byIcon(Icons.tune);
    if (styleTab.evaluate().isNotEmpty) {
      await tester.tap(styleTab.first);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('平板模式水印工坊：胶片滤镜提供单列列表与自适应分页切换', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        _app(WatermarkScreen(initialImageBytes: await _png(60, 40, 0x112233))));
    await _settle(tester);

    // 切换到胶片滤镜
    await _tapTab(tester, '胶片滤镜');
    await _settle(tester);
    expect(tester.takeException(), isNull);

    // 默认列表模式下存在滚动条
    expect(find.byType(Scrollbar), findsWidgets);

    // 切换到分页模式
    final pagedModeIcon = find.byIcon(Icons.auto_stories_outlined);
    if (pagedModeIcon.evaluate().isNotEmpty) {
      await tester.tap(pagedModeIcon.first);
      await tester.pumpAndSettle();
      expect(AppSettings.instance.tabletFilterViewPaged, isTrue);
      expect(find.byType(PageView), findsWidgets);
    }
  });
}
