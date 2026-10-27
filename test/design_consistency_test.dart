import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/design.dart';

void main() {
  group('Zync 2.0 Pro Darkroom 设计一致性门禁', () {
    final uiDir = Directory('lib/ui');

    List<File> collectUiFiles() {
      return uiDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) {
            final norm = f.path.replaceAll('\\', '/');
            return norm.endsWith('.dart') && !norm.contains('lib/ui/design/');
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    }

    test('旧 Vant 组件与主题文件已彻底移除', () {
      expect(File('lib/ui/widgets/vant_widgets.dart').existsSync(), isFalse);
      expect(File('lib/core/theme/vant_theme.dart').existsSync(), isFalse);
    });

    test('lib/ui/**（除 design/ 外）零裸 Color(0x...) / Colors.xxx / Vant* / ZyncColors',
        () {
      final violations = <String>[];
      final rawColorPattern = RegExp(r'\bColor\s*\(\s*0x|\bColors\.[a-zA-Z]+');
      final legacySymbolPattern = RegExp(r'\bVant[A-Z]\w*|\bZyncColors\b');

      for (final file in collectUiFiles()) {
        final norm = file.path.replaceAll('\\', '/');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].replaceFirst(RegExp(r'//.*$'), '');
          if (rawColorPattern.hasMatch(code)) {
            violations.add('$norm:${i + 1}: 裸颜色引用 -> ${lines[i].trim()}');
          }
          if (legacySymbolPattern.hasMatch(code)) {
            violations.add('$norm:${i + 1}: 旧主题/组件符号 -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '发现违反 Pro Darkroom 设计令牌约束的代码：\n${violations.join('\n')}',
      );
    });

    test('lib/ui/**（除白名单调试日志与内部枚举键外）零硬编码中文 UI 字符串', () {
      final violations = <String>[];
      final cjkLiteralPattern =
          RegExp(r'''(['"])(?:(?!\1).)*[\u4e00-\u9fff](?:(?!\1).)*\1''');

      bool isWhitelisted(String normPath, String codeLine) {
        // 1. 语言选择卡展示各语言母语自称（简体中文 / 日本語）
        if (normPath.endsWith('onboarding_flow.dart') &&
            (codeLine.contains('AppLanguage.zh') ||
                codeLine.contains('AppLanguage.ja'))) {
          return true;
        }
        // 2. 底层连接诊断日志（AppLogManager 保持中文）与原生占位回退
        if (normPath.endsWith('connect_screen.dart') &&
            (codeLine.contains('_addLog(') ||
                codeLine.contains('PTP/IP') ||
                codeLine.contains('<检测中...>'))) {
          return true;
        }
        // 3. 诊断日志着色关键字匹配
        if (normPath.endsWith('settings_screen.dart') &&
            codeLine.contains('line.contains(')) {
          return true;
        }
        // 4. 直方图曝光分区与裁切比例枚举内部稳定键（UI 渲染均走 trLabel / l10n）
        if (normPath.endsWith('lightroom_histogram.dart') &&
            RegExp(r'^\s*(blacks|shadows|exposure|highlights|whites)\(')
                .hasMatch(codeLine)) {
          return true;
        }
        if (normPath.endsWith('photo_edit_tools.dart') &&
            (codeLine.contains('原图') || codeLine.contains('自定义'))) {
          return true;
        }
        return false;
      }

      for (final file in collectUiFiles()) {
        final norm = file.path.replaceAll('\\', '/');
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].replaceFirst(RegExp(r'//.*$'), '');
          if (code.trim().isEmpty) continue;
          if (cjkLiteralPattern.hasMatch(code) && !isWhitelisted(norm, code)) {
            violations.add('$norm:${i + 1}: 未国际化中文字符串 -> ${lines[i].trim()}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: '发现未接入 ARB 国际化的 UI 中文字符串：\n${violations.join('\n')}',
      );
    });

    testWidgets('ZMotion 严格遵守系统 disableAnimations 无障碍设置', (tester) async {
      late Duration normalDuration;
      late Duration reducedDuration;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: Builder(
            builder: (context) {
              normalDuration = ZMotion.of(context, ZMotion.medium);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(normalDuration, ZMotion.medium);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reducedDuration = ZMotion.of(context, ZMotion.medium);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(reducedDuration, Duration.zero);
    });
  });
}
