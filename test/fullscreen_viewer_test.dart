import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

void main() {
  testWidgets('全屏图片查看器的缩放视口铺满黑色背景', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = Directory.systemTemp.createTempSync('zync_viewer_');
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    final image = img.Image(width: 40, height: 60);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(x, y, 180, 90, 40);
      }
    }
    final file = File('${dir.path}/portrait.png')
      ..writeAsBytesSync(Uint8List.fromList(img.encodePng(image)));
    final item = ExportedMediaItem(
      file: file,
      fileName: 'portrait.png',
      baseName: 'PORTRAIT',
      size: file.lengthSync(),
      modifiedTime: DateTime(2026, 10, 14),
    );

    await tester.pumpWidget(MaterialApp(
      home: FullScreenLocalImageViewer(items: [item], initialIndex: 0),
    ));

    // 等文件 Future 与图片解码完成，确保断言的是加载后的图片布局。
    for (var i = 0; i < 80 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final viewer = find.byType(InteractiveViewer).first;
    final viewport = tester.getRect(viewer);
    expect(viewport.size, const Size(400, 800));
    expect(
      find.ancestor(of: find.byType(Image), matching: find.byType(InteractiveViewer)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
