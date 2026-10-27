import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/watermark_screen.dart';

Uint8List _pngBytes() {
  final image = img.Image(width: 48, height: 64);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(x, y, 120, 160, 200);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  testWidgets('水印导出成功后是轻提示而不是阻断式弹窗', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('zync_export_fb_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    const paths = MethodChannel('plugins.flutter.io/path_provider');
    const native = MethodChannel('com.zync.app/native_camera');
    String? savedFileName;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(paths, (call) async => dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(native, (call) async {
      switch (call.method) {
        case 'saveMediaToGallery':
          savedFileName =
              Map<String, dynamic>.from(call.arguments as Map)['fileName'] as String?;
          return 'content://media/external/images/media/42';
        case 'listSavedMedia':
          return <Map<String, dynamic>>[];
        default:
          return null;
      }
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(paths, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(native, null);
    });

    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: WatermarkScreen(initialImageBytes: _pngBytes()),
    ));

    // 等图片解码完成（真实异步）
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }

    await tester.tap(find.byTooltip('保存高清成片至相册'));

    // 导出包含真实光栅化 + PNG 编码，给足时间并持续 pump
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      if (find.textContaining('已保存到系统相册').evaluate().isNotEmpty) break;
    }

    expect(find.textContaining('已保存到系统相册'), findsOneWidget,
        reason: '导出成功应给出轻提示');
    expect(find.byType(AlertDialog), findsNothing,
        reason: '不应再用模态弹窗阻断连续导出');
    expect(find.text('在相册查看'), findsOneWidget,
        reason: '轻提示应提供直接查看的入口');
    expect(savedFileName, isNotNull);
    expect(savedFileName, endsWith('.jpg'),
        reason: '写入系统相册的成品应是 JPEG（image/jpeg 入库）');
    expect(tester.takeException(), isNull);
  });
}
