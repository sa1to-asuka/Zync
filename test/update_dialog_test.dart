import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/colors.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/update/app_update_manager.dart';
import 'package:zync/ui/widgets/markdown_text.dart';

void main() {
  const markdownChangelog = '## v1.4.0 更新内容\n'
      '\n'
      '- 新增 **拼图** 功能\n'
      '- 修复 `EXIF` 方向\n';

  Future<void> pumpDialog(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: AppUpdateDialog(
          releaseInfo: AppReleaseInfo(
            tagName: 'v1.4.0',
            versionName: '1.4.0',
            title: 'Zync v1.4.0',
            changelog: markdownChangelog,
            downloadUrl: '',
            releasePageUrl: '',
            sourceName: 'GitHub',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Color? headingColor(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .firstWhere((t) => (t.textSpan?.toPlainText() ?? '').contains('v1.4.0'))
      .style
      ?.color;

  testWidgets('更新弹窗把 Markdown 更新日志渲染成标题+列表', (tester) async {
    await pumpDialog(tester, ZyncTheme.lightTheme);

    // 走 MarkdownText 而不是直接塞纯文本
    expect(find.byType(MarkdownText), findsOneWidget);
    expect(find.textContaining('v1.4.0 更新内容'), findsOneWidget);
    expect(find.textContaining('新增'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('更新弹窗更新日志随浅色/深色主题变色', (tester) async {
    await pumpDialog(tester, ZyncTheme.lightTheme);
    expect(headingColor(tester), ZyncPalette.light.textPrimary);

    await pumpDialog(tester, ZyncTheme.darkTheme);
    expect(headingColor(tester), ZyncPalette.dark.textPrimary);
    expect(tester.takeException(), isNull);
  });
}
