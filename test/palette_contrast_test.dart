import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/design.dart';

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('ZyncPalette WCAG AA 对比度与插值验证', () {
    test('深色暗房调色板文字与强调色满足 WCAG AA (>= 4.5:1)', () {
      const p = ZyncPalette.dark;
      expect(_contrastRatio(p.textPrimary, p.bg), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(p.textPrimary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textSecondary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textSecondary, p.surfaceHigh),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textTertiary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.accent, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.onAccent, p.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('浅色调色板文字与强调色满足 WCAG AA (>= 4.5:1)', () {
      const p = ZyncPalette.light;
      expect(_contrastRatio(p.textPrimary, p.bg), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(p.textPrimary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textSecondary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textSecondary, p.surfaceHigh),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.textTertiary, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.accent, p.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(p.onAccent, p.accent),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('ThemeExtension lerp 平滑插值', () {
      final mid = ZyncPalette.dark.lerp(ZyncPalette.light, 0.5);
      expect(mid.bg, isNot(equals(ZyncPalette.dark.bg)));
      expect(mid.bg, isNot(equals(ZyncPalette.light.bg)));
      expect(ZyncPalette.dark.lerp(ZyncPalette.light, 0.0).bg,
          equals(ZyncPalette.dark.bg));
      expect(ZyncPalette.dark.lerp(ZyncPalette.light, 1.0).bg,
          equals(ZyncPalette.light.bg));
    });
  });

  group('ZBreakpoint 与 ZMotion Token 验证', () {
    test('四档断点按宽度正确划分', () {
      expect(ZBreakpoint.ofWidth(390), ZBreakpoint.compact);
      expect(ZBreakpoint.ofWidth(599), ZBreakpoint.compact);
      expect(ZBreakpoint.ofWidth(600), ZBreakpoint.medium);
      expect(ZBreakpoint.ofWidth(839), ZBreakpoint.medium);
      expect(ZBreakpoint.ofWidth(840), ZBreakpoint.expanded);
      expect(ZBreakpoint.ofWidth(1199), ZBreakpoint.expanded);
      expect(ZBreakpoint.ofWidth(1200), ZBreakpoint.large);
    });

    testWidgets('系统开启减少动画时 ZMotion.of 返回 Duration.zero', (tester) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = ZMotion.of(context, ZMotion.long);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved, Duration.zero);
    });

    testWidgets('ZSlider 双击标题自动归零', (tester) async {
      double current = 42;
      await tester.pumpWidget(
        MaterialApp(
          theme: ZyncTheme.darkTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ZSlider(
                  label: 'Exposure',
                  value: current,
                  defaultValue: 0,
                  onChanged: (v) => setState(() => current = v),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('+42'), findsOneWidget);
      await tester.tap(find.text('Exposure'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Exposure'));
      await tester.pumpAndSettle();
      expect(current, 0);
      expect(find.text('0'), findsOneWidget);
    });
  });
}
