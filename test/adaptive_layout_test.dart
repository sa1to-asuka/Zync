import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/root_scaffold.dart';
import 'package:zync/ui/widgets/adaptive_layout.dart';

void main() {
  testWidgets('窄屏(手机竖屏)使用底部导航', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360dp 宽
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.items.length, equals(5));
    expect(find.text('监看取景'), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('宽屏(平板)使用左侧导航并能切换页面', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000); // 1600dp 宽
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack().index, 0);

    // 点击左侧导航「相机相册」切换到相册页
    await tester.tap(find.text('相机相册'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(stack().index, 1);
  });

  testWidgets('宽屏下内容居中限宽(≤720dp)', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    final content = find.byType(AdaptiveContent);
    expect(content, findsWidgets);

    final box = find
        .descendant(of: content.first, matching: find.byType(ConstrainedBox))
        .first;
    final boxRect = tester.getRect(box);
    expect(boxRect.width, lessThanOrEqualTo(720.5),
        reason: '大屏内容宽度应被限制在 720dp 以内');

    // 内容应在可用区域内水平居中（左右留白基本相等）
    final stackRect = tester.getRect(find.byType(IndexedStack));
    final leftGap = boxRect.left - stackRect.left;
    final rightGap = stackRect.right - boxRect.right;
    expect((leftGap - rightGap).abs(), lessThan(2.0),
        reason: '内容应水平居中，leftGap=$leftGap rightGap=$rightGap');
  });
}
