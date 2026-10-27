import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/widgets/compare_button.dart';

void main() {
  testWidgets('默认显示"对比"，点击后变为"原图"', (tester) async {
    var comparing = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompareButton(
            comparing: comparing,
            onPressed: () => comparing = !comparing,
            onLongPressStart: () => comparing = true,
            onLongPressEnd: () => comparing = false,
            onLongPressCancel: () => comparing = false,
          ),
        ),
      ),
    );

    expect(find.text('对比'), findsOneWidget);
    expect(find.text('原图'), findsNothing);
    expect(find.byIcon(Icons.compare), findsOneWidget);

    await tester.tap(find.byType(CompareButton));
    expect(comparing, isTrue);
  });

  testWidgets('处于对比状态时显示原图与 visibility 图标', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompareButton(
            comparing: true,
            onPressed: () {},
            onLongPressStart: () {},
            onLongPressEnd: () {},
            onLongPressCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text('原图'), findsOneWidget);
    expect(find.text('对比'), findsNothing);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  testWidgets('长按触发 onLongPressStart，松开触发 onLongPressEnd', (tester) async {
    var started = 0;
    var ended = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompareButton(
            comparing: false,
            onPressed: () {},
            onLongPressStart: () => started++,
            onLongPressEnd: () => ended++,
            onLongPressCancel: () {},
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(CompareButton)));
    await tester.pump(const Duration(milliseconds: 700));
    expect(started, 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(ended, 1);
  });
}
