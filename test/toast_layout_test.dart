import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/design.dart';

Future<void> _pumpToast(WidgetTester tester, Size size, String message) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  showZToast(context, message);
  await tester.pump();
}

void main() {
  testWidgets('宽屏提示条限宽 560 并水平居中', (tester) async {
    await _pumpToast(tester, const Size(1000, 800), '宽屏提示');

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final margin = snackBar.margin!.resolve(TextDirection.ltr);
    expect(margin.left, 220); // (1000 - 560) / 2
    expect(margin.right, 220);
    expect(margin.bottom, ZSpace.md);
  });

  testWidgets('窄屏提示条保持左右 16 并贴近底部', (tester) async {
    await _pumpToast(tester, const Size(400, 800), '窄屏提示');

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    final margin = snackBar.margin!.resolve(TextDirection.ltr);
    expect(margin.left, ZSpace.lg);
    expect(margin.right, ZSpace.lg);
    expect(margin.bottom, ZSpace.md);
  });
}
