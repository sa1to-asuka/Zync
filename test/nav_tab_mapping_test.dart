import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/root_scaffold.dart';

void main() {
  testWidgets('手机底栏 5 项，点击相册落到第 3 个页面（含拍摄台）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    final bottomBar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bottomBar.items.length, 5);
    expect(
      bottomBar.items.map((e) => e.label).toList(),
      ['连接', '相机相册', '色彩优化', '水印工坊', '设置'],
    );

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));

    // 底栏第 2 个位置 → screens 索引 2（拍摄台占了索引 1）。
    await tester.tap(find.text('相机相册'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(stack().index, 2);
  });

  testWidgets('平板侧栏保留 6 项，包含拍摄台', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations.length, 6);

    final labels =
        rail.destinations.map((d) => (d.label as Text).data).toList();
    expect(labels,
        ['连接', '拍摄台', '相机相册', '色彩优化', '水印工坊', '设置']);
  });

  testWidgets('从主页磁贴进入拍摄页时手机底栏隐藏', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: RootScaffold()));
    await tester.pump(const Duration(milliseconds: 100));

    // 底栏不出现拍摄台入口
    expect(find.text('拍摄台'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // 主页磁贴是手机端唯一的取景入口
    await tester.tap(find.text('实时取景'));
    await tester.pump(const Duration(milliseconds: 200));

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack().index, 1);
    expect(find.byType(BottomNavigationBar), findsNothing,
        reason: '拍摄页应占满全屏');
  });
}
