import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/widgets/markdown_text.dart';

const _base = TextStyle(fontSize: 13, color: Color(0xFF888888));
const _code = TextStyle(fontFamily: 'monospace');
const _link = TextStyle(color: Color(0xFFFFC800), decoration: TextDecoration.underline);

List<TextSpan> _flatten(InlineSpan span) {
  final out = <TextSpan>[];
  void walk(InlineSpan s) {
    if (s is TextSpan) {
      if ((s.text ?? '').isNotEmpty) out.add(s);
      for (final child in s.children ?? const <InlineSpan>[]) {
        walk(child);
      }
    }
  }

  walk(span);
  return out;
}

void main() {
  group('Markdown 块级解析', () {
    test('标题按 # 数量分级，正文按段落合并', () {
      final blocks = parseMarkdownBlocks('# 一级\n## 二级\n\n普通第一行\n普通第二行');
      expect(blocks.length, 3);
      expect(blocks[0].kind, MarkdownBlockKind.heading);
      expect(blocks[0].level, 1);
      expect(blocks[0].text, '一级');
      expect(blocks[1].kind, MarkdownBlockKind.heading);
      expect(blocks[1].level, 2);
      expect(blocks[2].kind, MarkdownBlockKind.paragraph);
      expect(blocks[2].text, '普通第一行 普通第二行');
    });

    test('无序/有序列表、引用、分割线', () {
      final blocks =
          parseMarkdownBlocks('- 甲\n* 乙\n1. 丙\n2) 丁\n> 引用\n---');
      expect(blocks.map((b) => b.kind).toList(), [
        MarkdownBlockKind.bullet,
        MarkdownBlockKind.bullet,
        MarkdownBlockKind.ordered,
        MarkdownBlockKind.ordered,
        MarkdownBlockKind.quote,
        MarkdownBlockKind.divider,
      ]);
      expect(blocks[0].text, '甲');
      expect(blocks[2].text, '丙');
      expect(blocks[4].text, '引用');
    });

    test('围栏代码块整块保留（含空行与缩进）', () {
      final blocks = parseMarkdownBlocks('前文\n```dart\nvoid main() {}\n\n  indented\n```\n后文');
      expect(blocks.map((b) => b.kind).toList(), [
        MarkdownBlockKind.paragraph,
        MarkdownBlockKind.code,
        MarkdownBlockKind.paragraph,
      ]);
      expect(blocks[1].text, 'void main() {}\n\n  indented');
    });

    test('CRLF 换行与表格等未支持语法按纯文本处理', () {
      final blocks = parseMarkdownBlocks('| a | b |\r\n| - | - |\r\n');
      expect(blocks.length, 1);
      expect(blocks.first.kind, MarkdownBlockKind.paragraph);
      expect(blocks.first.text, '| a | b | | - | - |');
    });
  });

  group('Markdown 行内解析', () {
    test('粗体 / 斜体 / 行内代码 / 链接各自套用样式', () {
      final spans = buildMarkdownSpans(
        '**加粗** 与 *斜体* 与 `代码` 与 [官网](https://example.com)',
        style: _base,
        code: _code,
        link: _link,
      );
      final parts = _flatten(TextSpan(children: spans));
      expect(parts.firstWhere((s) => s.text == '加粗').style?.fontWeight,
          FontWeight.bold);
      expect(parts.firstWhere((s) => s.text == '斜体').style?.fontStyle,
          FontStyle.italic);
      expect(parts.firstWhere((s) => s.text == '代码').style?.fontFamily,
          'monospace');
      // 链接只显示文字，并套用链接样式（不显示 URL）
      expect(parts.firstWhere((s) => s.text == '官网').style?.color,
          _link.color);
      expect(parts.any((s) => (s.text ?? '').contains('example.com')), isFalse);
    });

    test('无标记文本原样保留', () {
      final spans = buildMarkdownSpans('普通文字',
          style: _base, code: _code, link: _link);
      expect(_flatten(TextSpan(children: spans)).single.text, '普通文字');
    });
  });

  group('MarkdownText 渲染', () {
    const changelog = '## v1.4.0 更新\n'
        '\n'
        '- 新增 **拼图** 功能\n'
        '- 修复 `EXIF` 方向\n'
        '\n'
        '> 重要提示\n'
        '\n'
        '1. 先备份\n'
        '\n'
        '---\n';

    Future<void> pump(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: SingleChildScrollView(child: MarkdownText(data: changelog)),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('渲染标题/列表/引用/分割线且不抛异常', (tester) async {
      await pump(tester, ZyncTheme.lightTheme);

      expect(find.textContaining('v1.4.0 更新'), findsOneWidget);
      expect(find.textContaining('新增'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(2));
      expect(find.textContaining('重要提示'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('浅色与深色下标题颜色分别跟随主题', (tester) async {
      Color? headingColor() => tester
          .widgetList<Text>(find.byType(Text))
          .firstWhere((t) => (t.textSpan?.toPlainText() ?? '').contains('v1.4.0'))
          .style
          ?.color;

      await pump(tester, ZyncTheme.lightTheme);
      final light = headingColor();
      expect(light, isNotNull);

      await pump(tester, ZyncTheme.darkTheme);
      final dark = headingColor();
      expect(dark, isNotNull);
      expect(dark, isNot(light));
      expect(tester.takeException(), isNull);
    });
  });
}