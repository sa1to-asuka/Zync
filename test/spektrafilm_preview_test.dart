import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_models.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_native.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_renderer.dart';

Future<ui.Image> _image(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    pixels[i * 4] = 40;
    pixels[i * 4 + 1] = 80;
    pixels[i * 4 + 2] = 120;
    pixels[i * 4 + 3] = 255;
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('预览控制器能拿到原生渲染结果', (tester) async {
    final channel = MethodChannel('com.zync.app/spektrafilm');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      if (call.method == 'render') {
        final arguments = Map<dynamic, dynamic>.from(call.arguments as Map);
        final width = arguments['width'] as int;
        final height = arguments['height'] as int;
        final input = arguments['bytes'] as Uint8List;
        expect(input.length, width * height * 4);
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
    });
    SpektrafilmNative.debugDataDirectory = '/tmp/spektrafilm-test';

    await tester.runAsync(() async {
      final source = await _image(64, 48);
      final controller = SpektrafilmPreviewController(
        debounce: const Duration(milliseconds: 1),
      );
      const settings = SpektrafilmSettings(
        stockId: 'kodak_portra_400',
        paperId: 'kodak_portra_endura',
      );
      controller.update(source, settings);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (controller.image == null && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(controller.image, isNotNull);
      expect(controller.isProcessing, isFalse);
      expect(controller.image!.width, source.width);
      expect(controller.image!.height, source.height);

      final data =
          await controller.image!.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(data, isNotNull);
      expect(data!.getUint8(0), 200);
      expect(data.getUint8(1), 150);

      controller.dispose();
      source.dispose();
    });

    SpektrafilmNative.debugDataDirectory = null;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });
}
