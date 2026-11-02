import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/spektrafilm/spektrafilm_native.dart';
import 'package:zync/engine/watermark/watermark_painter.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/screens/watermark_screen.dart';

Uint8List _png(int width, int height, {int red = 118, int green = 126, int blue = 132}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, green, blue));
  return Uint8List.fromList(img.encodeJpg(image));
}

Widget _app({Key? key, Uint8List? bytes}) => MaterialApp(
      theme: ZyncTheme.lightTheme,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WatermarkScreen(
        key: key,
        initialImageBytes: bytes ?? _png(64, 48),
      ),
    );

ui.Image? _canvasImage(WidgetTester tester) {
  for (final widget in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = widget.painter;
    if (painter is WatermarkCanvasPainter && painter.image != null) {
      return painter.image;
    }
  }
  return null;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('zync_film_preview');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.zync.app/spektrafilm'),
      (call) async {
        if (call.method == 'catalog') {
          return '{"stocks":[{"id":"kodak_portra_400","name":"Kodak Portra 400",'
              '"targetPrint":"kodak_portra_endura","use":"still"}],'
              '"papers":[{"id":"kodak_portra_endura","name":"Kodak Portra Endura"}]}';
        }
        if (call.method == 'render') {
          final arguments = Map<dynamic, dynamic>.from(call.arguments as Map);
          final width = arguments['width'] as int;
          final height = arguments['height'] as int;
          final output = Uint8List(width * height * 4);
          for (var i = 0; i < width * height; i++) {
            output[i * 4] = 200;
            output[i * 4 + 1] = 150;
            output[i * 4 + 2] = 100;
            output[i * 4 + 3] = 255;
          }
          return output;
        }
        return null;
      },
    );
    SpektrafilmNative.debugDataDirectory = '/tmp/spektrafilm-test';
  });

  tearDown(() {
    SpektrafilmNative.debugDataDirectory = null;
    SpektrafilmNative.debugStocks = null;
    SpektrafilmNative.debugPapers = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.zync.app/spektrafilm'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  testWidgets('激活底片后画布使用原生渲染结果', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(find.text('胶片模拟'));
    await _settle(tester);

    final stock = find.text('Kodak Portra 400');
    expect(stock, findsWidgets);
    await tester.tap(stock.first);
    await _settle(tester);

    ui.Image? canvasImage;
    for (final widget in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
      final painter = widget.painter;
      if (painter is WatermarkCanvasPainter && painter.image != null) {
        canvasImage = painter.image;
        break;
      }
    }
    expect(canvasImage, isNotNull, reason: '画布没有拿到胶片模拟后的位图');

    final bytes = await tester.runAsync(
      () => canvasImage!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(bytes, isNotNull);
    expect(bytes!.getUint8(0), 200);
    expect(bytes.getUint8(1), 150);
    expect(bytes.getUint8(2), 100);
  });

  testWidgets('载入新照片后关闭并清空胶片模拟', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey<WatermarkScreenState>();
    await tester.pumpWidget(_app(key: key));
    await _settle(tester);

    await tester.tap(find.text('胶片模拟'));
    await _settle(tester);
    await tester.tap(find.text('Kodak Portra 400').first);
    await _settle(tester);
    expect(find.text('关闭胶片模拟'), findsOneWidget);

    await tester.runAsync(
      () => key.currentState!.loadImageBytes(
        _png(64, 48, red: 230, green: 20, blue: 20),
      ),
    );
    await _settle(tester);

    expect(find.text('关闭胶片模拟'), findsNothing);
    final directScan = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '负片直扫'),
    );
    expect(directScan.selected, isFalse);
    final canvasImage = _canvasImage(tester);
    expect(canvasImage, isNotNull);
    final bytes = await tester.runAsync(
      () => canvasImage!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(bytes, isNotNull);
    expect(bytes!.getUint8(0), greaterThan(180));
    expect(bytes.getUint8(1), lessThan(60));
  });
}
