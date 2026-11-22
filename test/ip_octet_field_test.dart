import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/connect/ip_octet_field.dart';

void main() {
  testWidgets('保留补零输入，满 3 位自动跳到下一段', (tester) async {
    final values = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: IpOctetField(
            initialIp: '010.151.169.075',
            onChanged: values.add,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final fields =
        tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields, hasLength(4));
    expect(fields[0].controller.text, '010');
    expect(fields[1].controller.text, '151');
    expect(fields[2].controller.text, '169');
    expect(fields[3].controller.text, '075');

    await tester.enterText(find.byType(EditableText).first, '192');
    await tester.pumpAndSettle();

    expect(fields[0].controller.text, '192');
    expect(fields[1].focusNode.hasFocus, isTrue);
    expect(values.last.startsWith('192.'), isTrue);
  });
}
