import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/photo_edit_controller.dart';
import 'package:zync/ui/widgets/photo_edit_preview.dart';
import 'package:zync/ui/widgets/photo_edit_tools.dart';

/// 代码审查发现的问题：PhotoEditPreview 里 onLongPress（对比）与
/// onScale（自由变换缩放）注册在同一个 GestureDetector。
/// GestureDetector 内部手势竞技场里 scale 手势一旦有 pointer 移动就立即胜出，
/// 会顶掉 longPress，导致「自由变换」工具下长按对比不可用。
///
/// 本测试直接注入 ui.Image，绕过 controller.load()（后者会启动真实渲染循环，
/// 在 widget 测试里会挂起）。
Future<PhotoEditController> _pumpPreview(
  WidgetTester tester,
  PhotoEditTool tool,
) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = const Color(0xFF8899AA));
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 64);
  picture.dispose();

  final controller = PhotoEditController();
  controller.originalPreview = image;
  controller.previewImage = image.clone();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: PhotoEditPreview(
              controller: controller,
              activeTool: tool,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  testWidgets('自由变换工具下长按可触发对比', (tester) async {
    final controller = await _pumpPreview(tester, PhotoEditTool.free);
    expect(find.text('对比'), findsOneWidget);

    final center = tester.getCenter(find.byType(PhotoEditPreview));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    // 进入对比状态：按钮文案变为「原图」。
    expect(find.text('原图'), findsWidgets, reason: '自由变换工具下长按未触发对比');

    await gesture.up();
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('裁剪工具下拖拽不会误触发对比', (tester) async {
    final controller = await _pumpPreview(tester, PhotoEditTool.crop);

    final center = tester.getCenter(find.byType(PhotoEditPreview));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    // 移动超过长按阈值：手势竞技场应判为拖拽，而不是长按。
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    // 核心断言：拖拽过程中不进入对比状态。
    expect(find.text('原图'), findsNothing, reason: '拖拽裁剪框被误判为长按对比');

    await gesture.up();
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('扭曲工具下长按画面中部可触发对比', (tester) async {
    final controller = await _pumpPreview(tester, PhotoEditTool.distort);

    // 扭曲手柄只在四角，长按画面中部（空白区）应能触发对比。
    final previewRect = tester.getRect(find.byType(PhotoEditPreview));
    final center = previewRect.center;
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('原图'), findsWidgets, reason: '扭曲工具下长按画面中部未触发对比');

    await gesture.up();
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets('裁剪工具下长按可触发对比', (tester) async {
    final controller = await _pumpPreview(tester, PhotoEditTool.crop);

    final center = tester.getCenter(find.byType(PhotoEditPreview));
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('原图'), findsWidgets, reason: '裁剪工具下长按未触发对比');

    await gesture.up();
    await tester.pumpAndSettle();
    controller.dispose();
  });
}
