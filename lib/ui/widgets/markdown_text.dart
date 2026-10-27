import 'package:flutter/material.dart';

import '../design/design.dart';

/// 轻量 Markdown 文本渲染（用于更新日志等短文本）。
///
/// 只覆盖发布说明常用的子集，避免为此引入额外依赖：
/// - 块级：ATX 标题 `#`~`######`、无序列表 `- * +`、有序列表 `1.`、
///   围栏代码块 ```、引用 `>`、分割线 `---`、普通段落；
/// - 行内：`**粗体**`、`*斜体*`、`` `行内代码` ``、`[文字](链接)`（只显示文字）。
/// 其余语法（表格、图片等）按纯文本原样显示，不会渲染出错。
class MarkdownText extends StatelessWidget {
  final String data;
  final double fontSize;
  final double height;

  const MarkdownText({
    super.key,
    required this.data,
    this.fontSize = 13,
    this.height = 1.55,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final base =
        TextStyle(color: c.textSecondary, fontSize: fontSize, height: height);
    final heading =
        base.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold);
    final code = base.copyWith(
      fontFamily: 'monospace',
      color: c.textPrimary,
      backgroundColor: c.outline.withAlpha(70),
    );
    final link = base.copyWith(
        color: c.accent, decoration: TextDecoration.underline);

    List<InlineSpan> spans(String text, TextStyle style) =>
        buildMarkdownSpans(text, style: style, code: code, link: link);

    final blocks = parseMarkdownBlocks(data);
    final children = <Widget>[];
    var orderedIndex = 0;

    for (final block in blocks) {
      if (block.kind != MarkdownBlockKind.ordered) orderedIndex = 0;
      switch (block.kind) {
        case MarkdownBlockKind.heading:
          final level = block.level.clamp(1, 6);
          final style = heading.copyWith(
            fontSize: fontSize + (level == 1 ? 3.0 : level == 2 ? 2.0 : 1.0),
          );
          children.add(Padding(
            padding: EdgeInsets.only(top: children.isEmpty ? 0 : 10, bottom: 4),
            child: Text.rich(TextSpan(children: spans(block.text, style)),
                style: style),
          ));
        case MarkdownBlockKind.bullet:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: base.copyWith(color: c.accent)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                      TextSpan(children: spans(block.text, base)),
                      style: base),
                ),
              ],
            ),
          ));
        case MarkdownBlockKind.ordered:
          orderedIndex++;
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$orderedIndex.',
                    style: base.copyWith(
                        color: c.accent, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                      TextSpan(children: spans(block.text, base)),
                      style: base),
                ),
              ],
            ),
          ));
        case MarkdownBlockKind.code:
          children.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.outline),
            ),
            child: Text(
              block.text,
              style: code.copyWith(backgroundColor: null, height: 1.4),
            ),
          ));
        case MarkdownBlockKind.quote:
          children.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: BoxDecoration(
              color: c.surfaceMid,
              border: Border(left: BorderSide(color: c.accent, width: 3)),
            ),
            child: Text.rich(
                TextSpan(
                    children: spans(
                        block.text, base.copyWith(color: c.textTertiary))),
                style: base),
          ));
        case MarkdownBlockKind.divider:
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, thickness: 1, color: c.outline),
          ));
        case MarkdownBlockKind.paragraph:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
                TextSpan(children: spans(block.text, base)),
                style: base),
          ));
      }
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// 块级元素类型。
enum MarkdownBlockKind {
  heading,
  bullet,
  ordered,
  code,
  quote,
  divider,
  paragraph,
}

/// 一个块级元素（标题/列表项/代码块/引用/分割线/段落）。
class MarkdownBlock {
  final MarkdownBlockKind kind;
  final String text;
  final int level;

  const MarkdownBlock(this.kind, this.text, {this.level = 0});
}

/// 把 Markdown 源码切成块级元素（纯函数，便于单测）。
List<MarkdownBlock> parseMarkdownBlocks(String source) {
  final blocks = <MarkdownBlock>[];
  final lines =
      source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final paragraph = StringBuffer();
  final code = StringBuffer();
  var inCode = false;

  void flushParagraph() {
    final text = paragraph.toString().trim();
    if (text.isNotEmpty) {
      blocks.add(MarkdownBlock(MarkdownBlockKind.paragraph, text));
    }
    paragraph.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    final isFence = trimmed.startsWith('```');

    if (inCode) {
      if (isFence) {
        blocks.add(
            MarkdownBlock(MarkdownBlockKind.code, code.toString().trimRight()));
        code.clear();
        inCode = false;
      } else {
        code.writeln(line);
      }
      continue;
    }
    if (isFence) {
      flushParagraph();
      inCode = true;
      continue;
    }
    if (trimmed.isEmpty) {
      flushParagraph();
      continue;
    }
    if (RegExp(r'^([-*_])\1{2,}$').hasMatch(trimmed.replaceAll(' ', ''))) {
      flushParagraph();
      blocks.add(const MarkdownBlock(MarkdownBlockKind.divider, ''));
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(MarkdownBlockKind.heading, heading.group(2)!,
          level: heading.group(1)!.length));
      continue;
    }
    if (trimmed.startsWith('>')) {
      flushParagraph();
      blocks.add(MarkdownBlock(
          MarkdownBlockKind.quote, trimmed.replaceFirst(RegExp(r'^>\s?'), '')));
      continue;
    }
    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(MarkdownBlockKind.bullet, bullet.group(1)!));
      continue;
    }
    final ordered = RegExp(r'^\d+[.)]\s+(.*)$').firstMatch(trimmed);
    if (ordered != null) {
      flushParagraph();
      blocks.add(MarkdownBlock(MarkdownBlockKind.ordered, ordered.group(1)!));
      continue;
    }
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
  }

  if (inCode && code.isNotEmpty) {
    blocks.add(
        MarkdownBlock(MarkdownBlockKind.code, code.toString().trimRight()));
  }
  flushParagraph();
  return blocks;
}

/// 行内 Markdown → TextSpan 列表（纯函数，便于单测）。
List<InlineSpan> buildMarkdownSpans(
  String text, {
  required TextStyle style,
  required TextStyle code,
  required TextStyle link,
}) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(
      r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)|\*(.+?)\*');
  var index = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(
          TextSpan(text: text.substring(index, match.start), style: style));
    }
    if (match.group(1) != null) {
      spans.add(TextSpan(
          text: match.group(1),
          style: style.copyWith(fontWeight: FontWeight.bold)));
    } else if (match.group(2) != null) {
      spans.add(TextSpan(text: match.group(2), style: code));
    } else if (match.group(3) != null) {
      spans.add(TextSpan(text: match.group(3), style: link));
    } else if (match.group(5) != null) {
      spans.add(TextSpan(
          text: match.group(5),
          style: style.copyWith(fontStyle: FontStyle.italic)));
    }
    index = match.end;
  }
  if (index < text.length) {
    spans.add(TextSpan(text: text.substring(index), style: style));
  }
  return spans;
}
