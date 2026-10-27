import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/collage/collage_renderer.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/ui/screens/collage_screen.dart';
import 'package:zync/ui/screens/photo_editor_screen.dart';
import 'package:zync/ui/screens/watermark_screen.dart';
import 'package:zync/ui/widgets/photo_edit_tools.dart';

const _sidePanel = ValueKey('adaptiveSidePanel');

Future<Uint8List> _png(int w, int h, int rgb) async {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Widget _app(Widget child) => MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: child,
    );

/// 有界推进真实异步（图片解码）+ 帧，替代会卡死的 pumpAndSettle。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// 按标签文字点击 TabBar 上的对应页签（Tab 内文字与选中态文字会重复，故按坐标点击）。
Future<void> _tapTab(WidgetTester tester, String label) async {
  final tabBar = tester.getRect(find.byType(TabBar));
  final tabs = ['画框版式', '胶片滤镜', '参数精调', '裁切几何'];
  final index = tabs.indexOf(label);
  final width = tabBar.width / tabs.length;
  await tester.tapAt(Offset(tabBar.left + width * (index + 0.5), tabBar.center.dy));
  await tester.pump();
}

void main() {
  testWidgets('水印工坊：宽屏走右侧侧栏，窄屏走底部面板', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
        _app(WatermarkScreen(initialImageBytes: await _png(40, 60, 0xCC3333))));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_sidePanel), findsOneWidget);
    final panel = tester.getRect(find.byKey(_sidePanel));
    expect(panel.width, inInclusiveRange(300, 400));
    expect(panel.right, closeTo(tester.view.physicalSize.width, 1.0));
    // TabBar 在侧栏内继续可用。
    await _tapTab(tester, '胶片滤镜');
    await _settle(tester);

    await _tapTab(tester, '裁切几何');
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('edit-tool-crop')), findsOneWidget,
        reason: '编辑 Tab 下六个工具应在侧栏中渲染');
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });


  testWidgets('图像编辑器：宽屏走右侧侧栏，窄屏保留 220 底部面板', (tester) async {
    final item = ExportedMediaItem(
      file: File('missing'),
      fileName: 'photo.png',
      baseName: 'PHOTO',
      size: 100,
      modifiedTime: DateTime(2026, 10, 13),
    );

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(PhotoEditorScreen(
      item: item,
      bytes: await _png(40, 60, 0x3366CC),
    )));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_sidePanel), findsOneWidget);
    final panel = tester.getRect(find.byKey(_sidePanel));
    expect(panel.width, inInclusiveRange(300, 400));

    // 六个工具按钮都在侧栏内（宽屏为 3x2 网格）。
    for (final name in ['rotate', 'flip', 'perspective', 'distort', 'free', 'crop']) {
      final rect = tester.getRect(find.byKey(ValueKey('edit-tool-' + name)));
      expect(panel.left, lessThanOrEqualTo(rect.left + 0.5), reason: name);
      expect(rect.right, lessThanOrEqualTo(panel.right + 0.5), reason: name);
    }

    await tester.tap(find.byKey(const ValueKey('edit-tool-crop')));
    await tester.pump();
    expect(find.text('1:1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());

    // 窄屏：面板回到屏幕底部，高度保持 220。
    tester.view.physicalSize = const Size(430, 900);
    await tester.pumpWidget(_app(PhotoEditorScreen(
      item: item,
      bytes: await _png(40, 60, 0x3366CC),
    )));
    await _settle(tester);
    expect(find.byKey(_sidePanel), findsNothing);
    final toolRect = tester.getRect(find.byType(PhotoEditToolsPanel));
    expect(toolRect.height, 220);
    expect(toolRect.bottom, closeTo(tester.view.physicalSize.height, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('拼图：宽屏走右侧侧栏，布局/水印 Tab 可用', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Directory dir;
    late List<ExportedMediaItem> items;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('collage_adaptive');
      final f1 = File('${dir.path}' + '/a.png');
      final f2 = File('${dir.path}' + '/b.png');
      await f1.writeAsBytes(await _png(60, 40, 0xCC3333));
      await f2.writeAsBytes(await _png(40, 60, 0x3366CC));
      items = [
        ExportedMediaItem(
          file: f1,
          fileName: 'a.png',
          baseName: 'a',
          size: await f1.length(),
          modifiedTime: DateTime.now(),
        ),
        ExportedMediaItem(
          file: f2,
          fileName: 'b.png',
          baseName: 'b',
          size: await f2.length(),
          modifiedTime: DateTime.now(),
        ),
      ];
    });
    addTearDown(() => dir.deleteSync(recursive: true));

    await tester.pumpWidget(_app(CollageScreen(items: items)));
    Finder canvas() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CollagePainter);
    for (var i = 0; i < 150 && canvas().evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    expect(tester.takeException(), isNull);
    expect(find.byKey(_sidePanel), findsOneWidget);
    final panel = tester.getRect(find.byKey(_sidePanel));
    expect(panel.width, inInclusiveRange(300, 400));
    expect(panel.right, closeTo(tester.view.physicalSize.width, 1.0));
    expect(find.byKey(const ValueKey('collage_thumb_box_top_bottom')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('collage_thumb_box_top_bottom_diagonal')),
        findsOneWidget);

    // 布局 / 水印两个 Tab 与「边框」「比例」仍在侧栏内可操作。
    for (final label in ['布局', '水印', '边框', '比例']) {
      final rect = tester.getRect(find.text(label));
      expect(panel.left, lessThanOrEqualTo(rect.left + 0.5), reason: label);
      expect(rect.right, lessThanOrEqualTo(panel.right + 0.5), reason: label);
    }
    await tester.tap(find.text('水印'));
    await tester.pump();
    expect(find.text('布局'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_sidePanel),
        matching: find.byWidgetPredicate(
            (w) => w is ListView && w.scrollDirection == Axis.horizontal),
      ),
      findsNothing,
      reason: '拼图水印模板在宽屏侧栏也不应横向滑动',
    );
    expect(tester.takeException(), isNull);
  });
}
