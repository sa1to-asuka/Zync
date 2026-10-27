import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/editor/photo_edit_controller.dart';
import 'package:zync/engine/editor/photo_edit_engine.dart';
import 'package:zync/ui/widgets/photo_edit_tools.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/filter/photo_filter.dart';
import 'package:zync/ui/widgets/lightroom_histogram.dart';

void main() {
  testWidgets('工具栏固定在参数区上方，切换工具不改变面板高度', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PhotoEditController();
    var active = PhotoEditTool.rotate;
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Scaffold(
            body: Column(children: [
          const Expanded(child: SizedBox()),
          StatefulBuilder(
              builder: (context, setState) => PhotoEditToolsPanel(
                  controller: controller,
                  activeTool: active,
                  onToolChanged: (tool) => setState(() => active = tool),
                  cropAspect: 0,
                  onCropAspectSelected: (_) {})),
        ]))));
    final bounds = tester.getRect(find.byType(PhotoEditToolsPanel));
    expect(bounds.height, 220);
    expect(
        tester.getRect(find.byKey(const ValueKey('edit-tool-rotate'))).bottom,
        lessThan(tester.getRect(find.byType(Slider)).top));
    for (final tool in PhotoEditTool.values) {
      await tester.tap(find.byKey(ValueKey('edit-tool-${tool.name}')));
      await tester.pump();
      expect(tester.getRect(find.byType(PhotoEditToolsPanel)), bounds);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('窄屏裁切比例选项等宽且全部可见', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PhotoEditController();
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Scaffold(
            body: Column(children: [
          const Expanded(child: SizedBox()),
          PhotoEditToolsPanel(
              controller: controller,
              activeTool: PhotoEditTool.crop,
              onToolChanged: (_) {},
              cropAspect: 0,
              onCropAspectSelected: (_) {})
        ]))));
    const rows = [
      ['原图', '1:1', '4:3', '3:2', '16:9'],
      ['3:4', '2:3', '9:16', '自定义'],
    ];
    for (final names in rows) {
      final buttons = names
          .map((s) => find.byKey(ValueKey('crop-ratio-$s')))
          .toList();
      final width = tester.getSize(buttons.first).width;
      for (final button in buttons) {
        expect(tester.getSize(button).width, closeTo(width, .001));
        expect(tester.getRect(button).right, lessThanOrEqualTo(320));
        expect(button.hitTestable(), findsOneWidget);
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('比例按钮回传预设值，自定义回传 -1', (tester) async {
    final controller = PhotoEditController();
    double? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PhotoEditToolsPanel(
                controller: controller,
                activeTool: PhotoEditTool.crop,
                onToolChanged: (_) {},
                cropAspect: 0,
                onCropAspectSelected: (v) => selected = v))));
    await tester.tap(find.byKey(const ValueKey('crop-ratio-3:4')));
    expect(selected, 3 / 4);
    await tester.tap(find.byKey(const ValueKey('crop-ratio-自定义')));
    expect(selected, -1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('直方图无顶部标题和重置按钮，下方保留横轴与曝光区间', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: Scaffold(
            body: LightroomHistogramWidget(
                data: HistogramData.compute(
                    adjustments: const PhotoEditAdjustments())))));
    expect(find.text('HISTOGRAM 直方图'), findsNothing);
    expect(find.text('重置参数'), findsNothing);
    expect(find.text('直方图'), findsOneWidget);
    for (final text in ['0', '64', '128', '192', '255', '阴影', '高光']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('编辑工具条渲染全部六个工具', (tester) async {
    final controller = PhotoEditController();
    PhotoEditTool active = PhotoEditTool.rotate;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PhotoEditToolsPanel(
            controller: controller,
            activeTool: active,
            onToolChanged: (t) => setState(() => active = t),
            cropAspect: 0,
            onCropAspectSelected: (_) {},
          ),
        ),
      ),
    ));
    expect(find.text('旋转'), findsOneWidget);
    expect(find.text('翻转'), findsOneWidget);
    expect(find.text('透视'), findsOneWidget);
    expect(find.text('扭曲'), findsOneWidget);
    expect(find.text('自由变换'), findsOneWidget);
    expect(find.text('裁切'), findsOneWidget);
  });

  testWidgets('切换到裁切显示比例预设', (tester) async {
    final controller = PhotoEditController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PhotoEditToolsPanel(
          controller: controller,
          activeTool: PhotoEditTool.crop,
          onToolChanged: (_) {},
          cropAspect: 0,
          onCropAspectSelected: (_) {},
        ),
      ),
    ));
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
  });

  testWidgets('点击工具条切换激活工具', (tester) async {
    final controller = PhotoEditController();
    PhotoEditTool active = PhotoEditTool.rotate;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => PhotoEditToolsPanel(
            controller: controller,
            activeTool: active,
            onToolChanged: (t) => setState(() => active = t),
            cropAspect: 0,
            onCropAspectSelected: (_) {},
          ),
        ),
      ),
    ));
    await tester.tap(find.text('透视'));
    await tester.pumpAndSettle();
    expect(find.textContaining('水平校正'), findsOneWidget);
    expect(find.textContaining('垂直校正'), findsOneWidget);
  });

  testWidgets('变换描述序列化往返一致', (tester) async {
    const t = PhotoEditTransform(
      rotationDegrees: 45,
      flipHorizontal: true,
      scale: 1.2,
      crop: CropRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
    );
    final restored = PhotoEditTransform.fromJson(t.toJson());
    expect(restored, equals(t));
  });
}
