import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/collage/collage_layout.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/collage/collage_renderer.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/ui/screens/collage_screen.dart';

/// 拼图版式纯逻辑自检：单元格铺满画布、边框内缩规则、比例映射、中央斜切几何。
void main() {
  group('版式单元格', () {
    test('每个张数只暴露匹配张数的模板', () {
      for (var n = 2; n <= 9; n++) {
        final templates = CollageTemplate.forCount(n);
        expect(templates, isNotEmpty, reason: '$n 张至少要有一种拼接方式');
        for (final t in templates) {
          expect(t.count, n);
          expect(t.cells.length, n, reason: '${t.id} 单元格数量应等于张数');
        }
      }
    });

    test('矩形模板的单元格恰好铺满画布且互不重叠', () {
      for (var n = 2; n <= 9; n++) {
        for (final t in CollageTemplate.forCount(n)) {
          if (t.isDiagonal) continue; // 多边形单独校验
          final cells = t.cells;
          var area = 0.0;
          for (final r in cells) {
            expect(r.left, greaterThanOrEqualTo(-1e-9), reason: t.id);
            expect(r.top, greaterThanOrEqualTo(-1e-9), reason: t.id);
            expect(r.right, lessThanOrEqualTo(1 + 1e-9), reason: t.id);
            expect(r.bottom, lessThanOrEqualTo(1 + 1e-9), reason: t.id);
            area += r.width * r.height;
          }
          expect(area, closeTo(1.0, 1e-9), reason: '${t.id} 面积之和应为 1');

          for (var i = 0; i < cells.length; i++) {
            for (var j = i + 1; j < cells.length; j++) {
              expect(_overlap(cells[i], cells[j]), closeTo(0, 1e-9),
                  reason: '${t.id} 单元格 $i 与 $j 不应重叠');
            }
          }
        }
      }
    });
  });

  group('边框与比例', () {
    test('比例映射：短边固定 2048', () {
      expect(CollageAspect.square.outputSize, const Size(2048, 2048));
      final portrait = CollageAspect.portrait34.outputSize;
      expect(portrait.width, closeTo(1536, 1e-6));
      expect(portrait.height, closeTo(2048, 1e-6));
    });

    test('边框内缩：外缘为 borderWidth，相邻间隙为 borderWidth', () {
      const layout = CollageLayout(
        template: CollageTemplate.leftRight,
        border: CollageBorder.l,
      );
      final b = layout.borderWidth;
      expect(b, greaterThan(0));

      final cells = layout.cellRects;
      final left = layout.insetRect(cells[0]);
      final right = layout.insetRect(cells[1]);

      // 外缘留出整段边框宽度
      expect(left.left, closeTo(b, 1e-6));
      expect(right.right, closeTo(layout.canvasSize.width - b, 1e-6));
      // 相邻格间隙 = 边框宽度
      expect(right.left - left.right, closeTo(b, 1e-6));

      // 叠加水印模板时去掉外框，但保留分界线
      final leftNoFrame =
          layout.insetRect(cells[0], drawOuterFrame: false);
      expect(leftNoFrame.left, closeTo(0, 1e-6));
      expect(right.left - leftNoFrame.right, closeTo(b, 1e-6));
    });

    test('无边框时不产生任何间隙', () {
      const layout = CollageLayout(
        template: CollageTemplate.leftRight,
        border: CollageBorder.none,
      );
      expect(layout.borderWidth, 0);
      final cells = layout.cellRects;
      expect(layout.insetRect(cells[0]), cells[0]);
      expect(layout.insetRect(cells[1]), cells[1]);
    });
  });

  group('中央斜切', () {
    test('分割线居中、非对角线，上下多边形铺满画布', () {
      const layout =
          CollageLayout(template: CollageTemplate.topBottomDiagonal);
      final size = layout.canvasSize;
      final line = layout.diagonalLine;

      expect(line[0].dx, closeTo(0, 1e-6));
      expect(line[1].dx, closeTo(size.width, 1e-6));

      final midX = (line[0].dx + line[1].dx) / 2;
      final midY = (line[0].dy + line[1].dy) / 2;
      expect(midX, closeTo(size.width / 2, 1e-6));
      expect(midY, closeTo(size.height / 2, 1e-6));

      // 不是对角线：端点不在角上
      expect(line[0].dy, greaterThan(0));
      expect(line[1].dy, lessThan(size.height));

      final polys = layout.diagonalPolys;
      final total = _polyArea(polys[0]) + _polyArea(polys[1]);
      expect(total, closeTo(size.width * size.height, 1.0));
    });
  });

  group('光栅化合成', () {
    test('按比例输出全尺寸拼图', () async {
      final a = await _solid(40, 30, const Color(0xFFFF0000));
      final b = await _solid(30, 40, const Color(0xFF00FF00));
      addTearDown(() {
        a.dispose();
        b.dispose();
      });

      final out = await CollageRenderer.compose(
        images: [a, b],
        layout: const CollageLayout(
          template: CollageTemplate.leftRight,
          aspect: CollageAspect.square,
          border: CollageBorder.m,
        ),
      );
      addTearDown(out.dispose);
      expect(out.width, 2048);
      expect(out.height, 2048);
    });

    test('预览尺寸受 maxDimension 限制', () async {
      final a = await _solid(40, 40, const Color(0xFFFF0000));
      final b = await _solid(40, 40, const Color(0xFF0000FF));
      addTearDown(() {
        a.dispose();
        b.dispose();
      });

      final out = await CollageRenderer.compose(
        images: [a, b],
        layout: const CollageLayout(
          template: CollageTemplate.topBottom,
          aspect: CollageAspect.portrait34,
        ),
        maxDimension: 1024,
      );
      addTearDown(out.dispose);
      expect(out.width, 768);
      expect(out.height, 1024);
    });

    test('外缘与分界线渲染为白色边框', () async {
      final a = await _solid(40, 40, const Color(0xFFFF0000));
      final b = await _solid(40, 40, const Color(0xFF0000FF));
      addTearDown(() {
        a.dispose();
        b.dispose();
      });

      final out = await CollageRenderer.compose(
        images: [a, b],
        layout: const CollageLayout(
          template: CollageTemplate.topBottom,
          aspect: CollageAspect.square,
          border: CollageBorder.m,
        ),
        maxDimension: 200,
      );
      addTearDown(out.dispose);
      final data = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      // 左上角属于外框
      expect(_isWhite(_pixel(data, out.width, 0, 0)), isTrue);
      // 中缝（y = 高度一半）属于分界线
      expect(_isWhite(_pixel(data, out.width, 100, 100)), isTrue);
      // 图片内部应保留原色，不是白
      expect(_isWhite(_pixel(data, out.width, 100, 40)), isFalse);
    });
  });

  group('单元格图片变换', () {
    const cell = Rect.fromLTWH(0, 0, 100, 100);
    const wide = Size(200, 100); // 2:1 横图

    test('scale=1/offset=0 时恰好 cover 铺满并居中', () {
      final dst =
          collageImageDstRect(wide, cell, CollageImageTransform.identity);
      expect(dst.width, closeTo(200, 1e-6));
      expect(dst.height, closeTo(100, 1e-6));
      expect(dst.center, cell.center);
    });

    test('缩放被夹取到 1–4 倍', () {
      final tooSmall = clampCollageTransform(
          wide, cell, const CollageImageTransform(scale: 0.2));
      expect(tooSmall.scale, 1.0);
      final tooBig = clampCollageTransform(
          wide, cell, const CollageImageTransform(scale: 99));
      expect(tooBig.scale, kCollageMaxImageScale);
    });

    test('任意缩放/位移都被夹取到始终盖满单元格（不露白）', () {
      for (final scale in [1.0, 1.7, 4.0]) {
        for (final dx in [-5.0, -0.3, 0.0, 0.3, 5.0]) {
          for (final dy in [-5.0, -0.3, 0.0, 0.3, 5.0]) {
            final dst = collageImageDstRect(
              wide,
              cell,
              CollageImageTransform(scale: scale, offset: Offset(dx, dy)),
            );
            expect(dst.left, lessThanOrEqualTo(cell.left + 1e-6));
            expect(dst.top, lessThanOrEqualTo(cell.top + 1e-6));
            expect(dst.right, greaterThanOrEqualTo(cell.right - 1e-6));
            expect(dst.bottom, greaterThanOrEqualTo(cell.bottom - 1e-6));
          }
        }
      }
    });

    test('向下移动图片可露出更靠上的部分（用户选上半部分）', () {
      const tall = Size(100, 300); // 竖图放进方格
      final base =
          collageImageDstRect(tall, cell, CollageImageTransform.identity);
      final down = collageImageDstRect(
          tall, cell, const CollageImageTransform(offset: Offset(0, 0.4)));
      // 可见起点（-top）更靠上，且底部仍盖满
      expect(-down.top, lessThan(-base.top));
      expect(down.bottom, greaterThanOrEqualTo(cell.bottom - 1e-6));
    });
  });
  group('拼图界面', () {
    testWidgets('加载本地素材、切换布局/水印标签且不出现布局异常', (tester) async {
      // 真实文件 I/O 必须走 runAsync（本仓库其它测试同一约定）。
      late Directory dir;
      late List<ExportedMediaItem> items;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('collage_ui');
        final f1 = File('${dir.path}/a.png');
        final f2 = File('${dir.path}/b.png');
        await f1.writeAsBytes(await _pngBytes(60, 40, const Color(0xFFCC3333)));
        await f2.writeAsBytes(await _pngBytes(40, 60, const Color(0xFF3366CC)));
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

      await tester.pumpWidget(MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: CollageScreen(items: items),
      ));

      // 加载态是无限动画，不能 pumpAndSettle；改为有界推进真实异步 + 帧。
      // 等图片真正解码完成（CollagePainter 出现在树上），而不是面板出现即算完。
      Finder canvasFinder() => find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CollagePainter);
      for (var i = 0; i < 150 && canvasFinder().evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }

      // 素材就绪、版式面板渲染，且没有 RenderFlex 溢出等异常。
      expect(tester.takeException(), isNull);
      expect(find.text('布局'), findsOneWidget);
      expect(find.text('水印'), findsOneWidget);
      expect(find.text('边框'), findsOneWidget);
      expect(find.text('比例'), findsOneWidget);

      await tester.tap(find.text('水印'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('纯调色 · 无水印'), findsOneWidget);

      // 回到布局页
      await tester.tap(find.text('布局'));
      await tester.pump();

      // 缩略图比例必须跟随导出比例（默认 1:1 方，切 3:4 变竖）。
      double thumbRatio(String id) {
        final size = tester.getSize(
            find.byKey(ValueKey<String>('collage_thumb_box_$id')));
        return size.width / size.height;
      }

      expect(thumbRatio('top_bottom'), closeTo(1.0, 0.02));
      await tester.tap(find.text('3:4'));
      await tester.pump();
      expect(thumbRatio('top_bottom'), closeTo(0.75, 0.02));
      await tester.tap(find.text('1:1'));
      await tester.pump();
      expect(thumbRatio('top_bottom'), closeTo(1.0, 0.02));

      // 直接手势：拖动 + 捏合都不应抛异常，且真的改动了单元格变换。
      expect(canvasFinder(), findsOneWidget);
      List<CollageImageTransform> transformsNow() =>
          (tester.widget<CustomPaint>(canvasFinder()).painter as CollagePainter)
              .transforms;
      final before = List<CollageImageTransform>.from(transformsNow());

      final center = tester.getCenter(canvasFinder());
      final drag = await tester.startGesture(center);
      // 第一次移动会被识别为手势起点，需再移动才会产生 update。
      for (var i = 0; i < 3; i++) {
        await drag.moveBy(const Offset(6, 20));
        await tester.pump();
      }
      await drag.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(transformsNow(), isNot(equals(before)));

      final pinched = List<CollageImageTransform>.from(transformsNow());
      final p1 = await tester.startGesture(center - const Offset(20, 0));
      final p2 = await tester.startGesture(center + const Offset(20, 0));
      for (var i = 0; i < 3; i++) {
        await p1.moveBy(const Offset(-14, 0));
        await p2.moveBy(const Offset(14, 0));
        await tester.pump();
      }
      await p1.up();
      await p2.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(transformsNow(), isNot(equals(pinched)));

      // 冲掉防抖预览定时器，避免测试结束时残留挂起定时器。
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}

double _overlap(Rect a, Rect b) {
  final w = math.max(0.0, math.min(a.right, b.right) - math.max(a.left, b.left));
  final h =
      math.max(0.0, math.min(a.bottom, b.bottom) - math.max(a.top, b.top));
  return w * h;
}

double _polyArea(List<Offset> p) {
  var sum = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[(i + 1) % p.length];
    sum += p[i].dx * q.dy - q.dx * p[i].dy;
  }
  return sum.abs() / 2;
}

Future<ui.Image> _solid(int w, int h, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(w, h);
  } finally {
    picture.dispose();
  }
}

Future<Uint8List> _pngBytes(int w, int h, Color color) async {
  final img = await _solid(w, h, color);
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    img.dispose();
  }
}

List<int> _pixel(ByteData data, int width, int x, int y) {
  final idx = (y * width + x) * 4;
  return [
    data.getUint8(idx),
    data.getUint8(idx + 1),
    data.getUint8(idx + 2),
    data.getUint8(idx + 3),
  ];
}

bool _isWhite(List<int> px) =>
    px[0] > 240 && px[1] > 240 && px[2] > 240 && px[3] > 240;