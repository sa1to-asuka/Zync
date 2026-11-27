import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'collage_layout.dart';

/// 把多张图片按 [CollageLayout] 光栅化合成单张拼图（可再交给水印引擎）。
class CollageRenderer {
  CollageRenderer._();

  /// 成品边框与分界线颜色（导出成品，固定纯白，不随 App 主题变化）。
  static const Color borderColor = Color(0xFFFFFFFF);

  /// 合成拼图。
  ///
  /// [transforms] 与 [images] 一一对应，描述每格图片的移动/缩放。
  /// [maxDimension] 为空时按 [CollageLayout.canvasSize] 全尺寸导出；传入数值
  /// （如 1024）用于生成预览缩略图，避免预览反复全尺寸光栅化。
  static Future<ui.Image> compose({
    required List<ui.Image> images,
    required CollageLayout layout,
    List<CollageImageTransform> transforms = const [],
    bool drawOuterFrame = true,
    double? maxDimension,
  }) async {
    final full = layout.canvasSize;
    final scale = maxDimension == null
        ? 1.0
        : math.min(1.0, maxDimension / full.longestSide);
    final outW = math.max(1, (full.width * scale).round());
    final outH = math.max(1, (full.height * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, full.width, full.height));
    if (scale != 1.0) canvas.scale(scale, scale);

    paintCollage(
      canvas,
      layout: layout,
      images: images,
      transforms: transforms,
      drawOuterFrame: drawOuterFrame,
    );

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(outW, outH);
    } finally {
      picture.dispose();
    }
  }

  /// 在 [layout.canvasSize] 坐标系里绘制整张拼图。
  ///
  /// 预览（[CollagePainter]）与导出（[compose]）共用，保证所见即所得。
  static void paintCollage(
    Canvas canvas, {
    required CollageLayout layout,
    required List<ui.Image> images,
    List<CollageImageTransform> transforms = const [],
    bool drawOuterFrame = true,
  }) {
    final full = layout.canvasSize;
    final border = layout.borderWidth;
    final outerBorder = layout.outerBorderWidth;
    final cornerRadius = layout.cornerRadiusPx;
    final borderCol = Color(layout.borderColorValue);
    final paint = Paint()..filterQuality = FilterQuality.high;
    final fullRect = Rect.fromLTWH(0, 0, full.width, full.height);

    // 先铺边框底色，边框与分界线由底色透出。
    canvas.drawRect(fullRect, Paint()..color = borderCol);

    if (layout.isDiagonal) {
      _paintDiagonal(
        canvas,
        full,
        images,
        layout,
        transforms,
        border,
        outerBorder,
        borderCol,
        drawOuterFrame,
        paint,
      );
      return;
    }

    final cells = layout.cellRects;
    for (var i = 0; i < cells.length && i < images.length; i++) {
      final dst = layout.insetRect(cells[i], drawOuterFrame: drawOuterFrame);
      if (dst.width <= 0 || dst.height <= 0) continue;
      _paintImageInCell(
        canvas,
        images[i],
        dst,
        _at(transforms, i),
        paint,
        cornerRadius: cornerRadius,
      );
    }
  }

  /// 将整张拼图矢量绘制进水印外框的 [targetRect] 区域（60fps 所见即所得预览用）。
  static void paintIntoRect(
    Canvas canvas,
    Rect targetRect, {
    required CollageLayout layout,
    required List<ui.Image> images,
    List<CollageImageTransform> transforms = const [],
    bool drawOuterFrame = false,
    int? activeIndex,
    int? swapSourceIndex,
    Color? highlightColor,
    bool drawDividerHandle = true,
  }) {
    if (targetRect.width <= 0 || targetRect.height <= 0) return;
    final full = layout.canvasSize;
    final sx = targetRect.width / full.width;
    final sy = targetRect.height / full.height;

    canvas.save();
    canvas.translate(targetRect.left, targetRect.top);
    canvas.scale(sx, sy);
    paintCollage(
      canvas,
      layout: layout,
      images: images,
      transforms: transforms,
      drawOuterFrame: drawOuterFrame,
    );
    paintInteractiveOverlays(
      canvas,
      layout: layout,
      imageCount: images.length,
      drawOuterFrame: drawOuterFrame,
      activeIndex: activeIndex,
      swapSourceIndex: swapSourceIndex,
      highlightColor: highlightColor,
      drawDividerHandle: drawDividerHandle,
    );
    canvas.restore();
  }

  /// 绘制选中格高亮框、互换源标记与主分隔线手柄。
  static void paintInteractiveOverlays(
    Canvas canvas, {
    required CollageLayout layout,
    required int imageCount,
    bool drawOuterFrame = true,
    int? activeIndex,
    int? swapSourceIndex,
    Color? highlightColor,
    bool drawDividerHandle = true,
  }) {
    final full = layout.canvasSize;
    final hl = highlightColor;
    if (hl != null) {
      final stroke = math.max(2.0, full.shortestSide * 0.005);
      final corner = layout.cornerRadiusPx;

      void drawCellBorder(int idx, Color color, double widthScale) {
        if (idx < 0 || idx >= imageCount) return;
        final p = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * widthScale;
        if (layout.isDiagonal) {
          final polys = layout.diagonalPolys;
          if (idx < polys.length) {
            canvas.drawPath(Path()..addPolygon(polys[idx], true), p);
          }
        } else {
          final cells = layout.imageCells(drawOuterFrame: drawOuterFrame);
          if (idx < cells.length) {
            final r = cells[idx].deflate(stroke * widthScale / 2);
            if (corner > 0) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(r, Radius.circular(corner)),
                p,
              );
            } else {
              canvas.drawRect(r, p);
            }
          }
        }
      }

      if (activeIndex != null) {
        drawCellBorder(activeIndex, hl, 1.0);
      }
      if (swapSourceIndex != null && swapSourceIndex != activeIndex) {
        drawCellBorder(swapSourceIndex, hl.withAlpha(180), 1.4);
      }

      if (drawDividerHandle) {
        final divider = layout.primaryDivider;
        if (divider != null) {
          final anchor = divider.handleAnchor;
          final w = divider.isVerticalDivider
              ? full.shortestSide * 0.014
              : full.shortestSide * 0.075;
          final h = divider.isVerticalDivider
              ? full.shortestSide * 0.075
              : full.shortestSide * 0.014;
          final pill = RRect.fromRectAndRadius(
            Rect.fromCenter(center: anchor, width: w, height: h),
            Radius.circular(math.min(w, h) / 2),
          );
          canvas.drawRRect(
            pill,
            Paint()..color = const Color(0xCC121418),
          );
          canvas.drawRRect(
            pill,
            Paint()
              ..color = hl
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, full.shortestSide * 0.002),
          );
        }
      }
    }
  }

  /// 中央斜切：上下各一个多边形区域，再叠加斜线分界线与外框。
  static void _paintDiagonal(
    Canvas canvas,
    Size size,
    List<ui.Image> images,
    CollageLayout layout,
    List<CollageImageTransform> transforms,
    double border,
    double outerBorder,
    Color borderCol,
    bool drawOuterFrame,
    Paint paint,
  ) {
    final line = layout.diagonalLine;
    final p1 = line[0];
    final p2 = line[1];
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final top = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p1.dx, p1.dy)
      ..close();
    final bottom = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    if (images.isNotEmpty) {
      canvas.save();
      canvas.clipPath(top);
      _paintImageInCell(canvas, images[0], _polyBounds(top), _at(transforms, 0), paint);
      canvas.restore();
    }
    if (images.length > 1) {
      canvas.save();
      canvas.clipPath(bottom);
      _paintImageInCell(canvas, images[1], _polyBounds(bottom), _at(transforms, 1), paint);
      canvas.restore();
    }
    // 未用到的格子仍保留底色即可（斜切模板固定 2 张）。
    assert(images.length <= 2);

    if (border > 0) {
      // 居中的斜线：两侧各占一半，与矩形模板的格间间隙宽度一致。
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = borderCol
          ..strokeWidth = border
          ..strokeCap = StrokeCap.butt,
      );
    }
    if (drawOuterFrame && outerBorder > 0) {
      canvas.drawRect(
        fullRect.deflate(outerBorder / 2),
        Paint()
          ..color = borderCol
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerBorder,
      );
    }
  }

  /// 在单元格里画一张图（含旋转/镜像/缩放/位移，超出部分裁掉，保证铺满不留白）。
  static void _paintImageInCell(
    Canvas canvas,
    ui.Image img,
    Rect cell,
    CollageImageTransform t,
    Paint paint, {
    double cornerRadius = 0.0,
  }) {
    if (cell.width <= 0 || cell.height <= 0) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = collageImageDstRect(
      Size(img.width.toDouble(), img.height.toDouble()),
      cell,
      t,
    );
    canvas.save();
    if (cornerRadius > 0) {
      final maxR = math.min(cell.width, cell.height) / 2;
      canvas.clipRRect(
        RRect.fromRectAndRadius(
          cell,
          Radius.circular(math.min(cornerRadius, maxR)),
        ),
      );
    } else {
      canvas.clipRect(cell);
    }

    final turns = ((t.quarterTurns % 4) + 4) % 4;
    if (turns == 0 && !t.flipX) {
      canvas.drawImageRect(img, src, dst, paint);
    } else {
      canvas.translate(dst.center.dx, dst.center.dy);
      if (t.flipX) canvas.scale(-1, 1);
      if (turns != 0) canvas.rotate(turns * math.pi / 2);
      final localDst = Rect.fromCenter(
        center: Offset.zero,
        width: turns.isOdd ? dst.height : dst.width,
        height: turns.isOdd ? dst.width : dst.height,
      );
      canvas.drawImageRect(img, src, localDst, paint);
    }
    canvas.restore();
  }

  static CollageImageTransform _at(List<CollageImageTransform> list, int i) =>
      i < list.length ? list[i] : CollageImageTransform.identity;

  static Rect _polyBounds(Path path) => path.getBounds();
}

/// 拼图预览绘制器：与 [CollageRenderer.compose] 共用同一份绘制逻辑，
/// 直接在预览画布上绘制（不经过位图合成），因此拖动/缩放可零延迟实时反馈。
class CollagePainter extends CustomPainter {
  final List<ui.Image> images;
  final CollageLayout layout;
  final List<CollageImageTransform> transforms;
  final bool drawOuterFrame;

  /// 当前正在调整的单元格下标（预览高亮用；导出传 null）。
  final int? activeIndex;
  final int? swapSourceIndex;
  final Color? highlightColor;
  final bool drawDividerHandle;

  const CollagePainter({
    required this.images,
    required this.layout,
    this.transforms = const [],
    this.drawOuterFrame = true,
    this.activeIndex,
    this.swapSourceIndex,
    this.highlightColor,
    this.drawDividerHandle = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final full = layout.canvasSize;
    final s = size.width / full.width;

    canvas.save();
    canvas.scale(s, s);
    CollageRenderer.paintCollage(
      canvas,
      layout: layout,
      images: images,
      transforms: transforms,
      drawOuterFrame: drawOuterFrame,
    );
    CollageRenderer.paintInteractiveOverlays(
      canvas,
      layout: layout,
      imageCount: images.length,
      drawOuterFrame: drawOuterFrame,
      activeIndex: activeIndex,
      swapSourceIndex: swapSourceIndex,
      highlightColor: highlightColor,
      drawDividerHandle: drawDividerHandle,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CollagePainter old) =>
      old.images != images ||
      old.layout.template != layout.template ||
      old.layout.aspect != layout.aspect ||
      old.layout.border != layout.border ||
      old.layout.innerGapRatio != layout.innerGapRatio ||
      old.layout.outerMarginRatio != layout.outerMarginRatio ||
      old.layout.cornerRadiusRatio != layout.cornerRadiusRatio ||
      old.layout.borderColorValue != layout.borderColorValue ||
      old.layout.splitRatio != layout.splitRatio ||
      old.transforms != transforms ||
      old.drawOuterFrame != drawOuterFrame ||
      old.activeIndex != activeIndex ||
      old.swapSourceIndex != swapSourceIndex ||
      old.drawDividerHandle != drawDividerHandle;
}