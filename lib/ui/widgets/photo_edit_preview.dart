import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../engine/editor/photo_edit_controller.dart';
import '../../engine/editor/photo_edit_engine.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';
import 'compare_button.dart';
import 'photo_edit_tools.dart';

Rect fittedPhotoRect(Size viewport, Size image) {
  if (image.isEmpty || viewport.isEmpty) return Rect.zero;
  final size = applyBoxFit(BoxFit.contain, image, viewport).destination;
  return Alignment.center.inscribe(size, Offset.zero & viewport);
}

/// 照片编辑器预览。
///
/// 支持前后对比：长按画面（或按住右下角对比按钮）临时显示未调色画面，
/// 松开立刻恢复，方便判断调色前后差异。
class PhotoEditPreview extends StatefulWidget {
  final PhotoEditController controller;
  final ui.Image? previewImage;
  final PhotoEditTool activeTool;
  final double cropAspect;

  const PhotoEditPreview({
    super.key,
    required this.controller,
    this.previewImage,
    required this.activeTool,
    this.cropAspect = 0,
  });

  @override
  State<PhotoEditPreview> createState() => _PhotoEditPreviewState();
}

class _PhotoEditPreviewState extends State<PhotoEditPreview> {
  PhotoEditTransform? _start;
  Offset _focal = Offset.zero;

  /// 对比中：显示未调色画面。
  bool _compare = false;

  PhotoEditController get controller => widget.controller;

  /// 用于对比的原图：优先未调色预览，其次解码后的源图。
  ui.Image? get _compareImage =>
      controller.originalPreview ?? controller.previewImage;

  void _setCompare(bool value) {
    if (_compare == value) return;
    setState(() => _compare = value);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final zc = context.zc;
          final l10n = context.l10n;
          final image = widget.previewImage ?? controller.previewImage;
          if (image == null) {
            return Center(
              child: Text(
                controller.renderError ??
                    (controller.loading || controller.sourceWidth > 0
                        ? l10n.editorPreparingPreview
                        : l10n.editorNoPhotoSelected),
                style: TextStyle(color: zc.textSecondary),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, c) {
              final immediate = controller.previewPending &&
                  controller.originalPreview != null;
              final sourceWidth =
                  controller.originalPreview?.width ?? image.width;
              final sourceHeight =
                  controller.originalPreview?.height ?? image.height;
              final omitCrop = widget.activeTool == PhotoEditTool.crop ||
                  widget.activeTool == PhotoEditTool.distort;
              final frameTransform = omitCrop
                  ? controller.value
                      .copyWith(crop: const CropRect(), cropAspect: 0)
                  : controller.value;
              final frame = PhotoEditEngine.frameDimensions(
                sourceWidth,
                sourceHeight,
                frameTransform,
                includeCrop: !omitCrop,
              );
              final displaySize =
                  Size(frame.width.toDouble(), frame.height.toDouble());
              final rect = fittedPhotoRect(c.biggest, displaySize);
              final usePainter = controller.originalPreview != null &&
                  (immediate ||
                      (widget.activeTool == PhotoEditTool.perspective &&
                          controller.value.hasPerspective));

              // 对比中：几何按当前视图走，但画面内容换回未调色原图。
              final compareImage = _compare ? _compareImage : null;
              final showCompare = _compare && compareImage != null;

              final Widget photo;
              if (showCompare) {
                photo = RawImage(
                  image: compareImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                );
              } else if (usePainter) {
                photo = CustomPaint(
                  painter: _ImmediateEditPainter(
                    controller.originalPreview!,
                    controller.value,
                    omitCrop,
                  ),
                );
              } else {
                photo = RawImage(image: image, fit: BoxFit.fill);
              }

              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: GestureDetector(
                      // 长按对比：按住显示原图，松开（含手势被系统打断）恢复。
                      onLongPressStart: (_) => _setCompare(true),
                      onLongPressEnd: (_) => _setCompare(false),
                      onLongPressCancel: () => _setCompare(false),
                      onScaleStart: widget.activeTool == PhotoEditTool.free
                          ? (d) {
                              _start = controller.value;
                              _focal = d.focalPoint;
                              controller.beginGesture();
                            }
                          : null,
                      onScaleUpdate: widget.activeTool == PhotoEditTool.free
                          ? (d) {
                              final t = _start!;
                              final delta = d.focalPoint - _focal;
                              controller.update(
                                t.copyWith(
                                  scale: (t.scale * d.scale).clamp(.5, 2),
                                  offsetX: (t.offsetX + delta.dx / rect.width)
                                      .clamp(-.5, .5),
                                  offsetY: (t.offsetY + delta.dy / rect.height)
                                      .clamp(-.5, .5),
                                ),
                              );
                            }
                          : null,
                      onScaleEnd: widget.activeTool == PhotoEditTool.free
                          ? (_) {
                              controller.endGesture();
                              _start = null;
                            }
                          : null,
                      child: photo,
                    ),
                  ),
                  Positioned.fromRect(
                    rect: rect,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: zc.accent.withAlpha(180),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.activeTool == PhotoEditTool.crop)
                    Positioned.fromRect(
                      rect: rect,
                      child: _CropOverlay(
                        controller: controller,
                        aspect: widget.cropAspect,
                        imageAspect: sourceWidth / sourceHeight,
                        onCompareStart: () => _setCompare(true),
                        onCompareEnd: () => _setCompare(false),
                      ),
                    ),
                  if (widget.activeTool == PhotoEditTool.perspective)
                    Positioned.fromRect(
                      rect: rect,
                      child: IgnorePointer(
                        child: CustomPaint(painter: _CorrectionGridPainter()),
                      ),
                    ),
                  if (widget.activeTool == PhotoEditTool.distort)
                    Positioned.fromRect(
                      rect: rect,
                      child: _DistortOverlay(controller: controller),
                    ),
                  if (const [
                    PhotoEditTool.rotate,
                    PhotoEditTool.flip,
                    PhotoEditTool.distort,
                  ].contains(widget.activeTool))
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (rect.top + 8)
                          .clamp(0.0, math.max(0.0, c.maxHeight - 48)),
                      child: Center(child: _shortcutBar(context)),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: CompareButton(
                      comparing: _compare,
                      onPressed: () => _setCompare(!_compare),
                      onLongPressStart: () => _setCompare(true),
                      onLongPressEnd: () => _setCompare(false),
                      onLongPressCancel: () => _setCompare(false),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 6,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _compare ? 1 : 0,
                        duration: ZMotion.of(context, ZMotion.short),
                        child: Text(
                          l10n.editorComparingHoldHint,
                          style: TextStyle(
                            fontSize: 10,
                            color: ZyncPalette.dark.textPrimary,
                            shadows: [
                              Shadow(
                                color: ZyncPalette.dark.scrim,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

  Widget _shortcutBar(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final t = controller.value;
    Widget button(
      String label,
      IconData icon,
      VoidCallback command, {
      bool selected = false,
    }) =>
        IconButton(
          tooltip: label,
          onPressed: command,
          icon: Icon(icon, size: 21),
          style: IconButton.styleFrom(
            foregroundColor: selected ? zc.accent : zc.textPrimary,
            backgroundColor:
                selected ? zc.accent.withAlpha(25) : ZSwatch.transparent,
          ),
        );
    final buttons = switch (widget.activeTool) {
      PhotoEditTool.rotate => [
          button(
            l10n.editorRotateLeft90,
            Icons.rotate_left,
            () => controller.rotateBy(-90),
          ),
          button(
            l10n.editorRotateRight90,
            Icons.rotate_right,
            () => controller.rotateBy(90),
          ),
          button(
            l10n.editorResetAngle,
            Icons.restart_alt,
            () => controller.update(t.copyWith(rotationDegrees: 0)),
          ),
        ],
      PhotoEditTool.flip => [
          button(
            l10n.editorFlipHorizontal,
            Icons.swap_horiz,
            () => controller
                .update(t.copyWith(flipHorizontal: !t.flipHorizontal)),
            selected: t.flipHorizontal,
          ),
          button(
            l10n.editorFlipVertical,
            Icons.swap_vert,
            () => controller.update(t.copyWith(flipVertical: !t.flipVertical)),
            selected: t.flipVertical,
          ),
        ],
      _ => [
          button(
            l10n.editorResetDistortion,
            Icons.restart_alt,
            () => controller.update(
              t.copyWith(
                distortTopLeftX: 0,
                distortTopLeftY: 0,
                distortTopRightX: 0,
                distortTopRightY: 0,
                distortBottomLeftX: 0,
                distortBottomLeftY: 0,
                distortBottomRightX: 0,
                distortBottomRightY: 0,
              ),
            ),
          ),
        ],
    };
    return Material(
      key: const ValueKey('photo-transform-shortcuts'),
      color: zc.surface.withAlpha(235),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZRadius.sm),
        side: BorderSide(color: zc.outline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }
}

/// GPU 预览仅在后台重算期间使用，投影矩阵与导出引擎共用。
class _ImmediateEditPainter extends CustomPainter {
  final ui.Image image;
  final PhotoEditTransform transform;
  final bool omitCrop;
  _ImmediateEditPainter(this.image, this.transform, this.omitCrop);
  @override
  void paint(Canvas canvas, Size size) {
    final t = transform,
        w = image.width.toDouble(),
        h = image.height.toDouble();
    final dimensions = PhotoEditEngine.frameDimensions(
      image.width,
      image.height,
      t,
      includeCrop: false,
    );
    final cw = dimensions.width.toDouble(), ch = dimensions.height.toDouble();
    final crop = PhotoEditEngine.cropBounds(
      dimensions.width,
      dimensions.height,
      t.crop,
      t.cropAspect,
    );
    final spill =
        t.hasPerspective && t.crop.isFull && t.cropAspect == 0 && !omitCrop;
    canvas.save();
    // 底层黑幕布：缩放/扭曲露出的区域是纯黑底，与导出一致，不再垫一张原图。
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = ZyncPalette.dark.bg.withRed(0).withGreen(0).withBlue(0),
    );
    if (!spill) canvas.clipRect(Offset.zero & size);
    canvas.scale(
      size.width / (omitCrop ? cw : crop.width),
      size.height / (omitCrop ? ch : crop.height),
    );
    if (!omitCrop) {
      canvas.translate(-crop.left.toDouble(), -crop.top.toDouble());
    }
    if (!spill) canvas.clipRect(Rect.fromLTWH(0, 0, cw, ch));
    canvas.translate(cw / 2 + t.offsetX * cw, ch / 2 + t.offsetY * ch);
    canvas.scale(t.scale, t.scale);
    canvas.scale(t.flipHorizontal ? -1 : 1, t.flipVertical ? -1 : 1);
    final angle = t.rotationDegrees * math.pi / 180;
    final ca = math.cos(angle).abs(), sa = math.sin(angle).abs();
    final cover = math.max((cw * ca + ch * sa) / w, (cw * sa + ch * ca) / h);
    canvas.scale(cover, cover);
    canvas.rotate(angle);
    canvas.translate(-w / 2, -h / 2);
    if (!spill) canvas.clipRect(Rect.fromLTWH(0, 0, w, h));
    if (t.hasPerspective || t.hasDistortion) {
      final m = PhotoEditEngine.homography(t, width: w, height: h);
      final matrix = Matrix4.identity()
        ..setEntry(0, 0, m[0])
        ..setEntry(0, 1, m[1] * w / h)
        ..setEntry(0, 3, m[2] * w)
        ..setEntry(1, 0, m[3] * h / w)
        ..setEntry(1, 1, m[4])
        ..setEntry(1, 3, m[5] * h)
        ..setEntry(3, 0, m[6] / w)
        ..setEntry(3, 1, m[7] / h);
      canvas.transform(matrix.storage);
    }
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ImmediateEditPainter old) =>
      old.image != image ||
      old.transform != transform ||
      old.omitCrop != omitCrop;
}

class _CorrectionGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 1; i < 3; i++) {
      path
        ..moveTo(size.width * i / 3, 0)
        ..lineTo(size.width * i / 3, size.height)
        ..moveTo(0, size.height * i / 3)
        ..lineTo(size.width, size.height * i / 3);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ZyncPalette.dark.scrim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = ZyncPalette.dark.textPrimary.withAlpha(180)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CorrectionGridPainter old) => false;
}

class _CropOverlay extends StatelessWidget {
  final PhotoEditController controller;
  final double aspect, imageAspect;
  final VoidCallback onCompareStart;
  final VoidCallback onCompareEnd;

  const _CropOverlay({
    required this.controller,
    required this.aspect,
    required this.imageAspect,
    required this.onCompareStart,
    required this.onCompareEnd,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final zc = context.zc;
          final crop = controller.value.crop;
          final rect = Rect.fromLTRB(
            crop.left * c.maxWidth,
            crop.top * c.maxHeight,
            crop.right * c.maxWidth,
            crop.bottom * c.maxHeight,
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _CropMaskPainter(rect)),
                ),
              ),
              Positioned.fromRect(
                rect: rect,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: (_) => onCompareStart(),
                  onLongPressEnd: (_) => onCompareEnd(),
                  onLongPressCancel: onCompareEnd,
                  onPanStart: (_) => controller.beginGesture(),
                  onPanUpdate: (d) {
                    final r = controller.value.crop;
                    final dx =
                        (d.delta.dx / c.maxWidth).clamp(-r.left, 1 - r.right);
                    final dy =
                        (d.delta.dy / c.maxHeight).clamp(-r.top, 1 - r.bottom);
                    controller.update(
                      controller.value.copyWith(
                        crop: CropRect(
                          left: r.left + dx,
                          top: r.top + dy,
                          right: r.right + dx,
                          bottom: r.bottom + dy,
                        ),
                      ),
                    );
                  },
                  onPanEnd: (_) => controller.endGesture(),
                  onPanCancel: controller.endGesture,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: zc.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < 4; i++)
                _handle(
                  context,
                  i,
                  [
                    rect.topLeft,
                    rect.topRight,
                    rect.bottomLeft,
                    rect.bottomRight,
                  ][i],
                  c,
                ),
            ],
          );
        },
      );

  Widget _handle(BuildContext context, int i, Offset p, BoxConstraints c) {
    final zc = context.zc;
    return Positioned(
      left: p.dx.clamp(
            math.min(14, c.maxWidth / 2),
            math.max(c.maxWidth - 14, c.maxWidth / 2),
          ) -
          14,
      top: p.dy.clamp(
            math.min(14, c.maxHeight / 2),
            math.max(c.maxHeight - 14, c.maxHeight / 2),
          ) -
          14,
      child: GestureDetector(
        key: ValueKey('crop-handle-$i'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => controller.beginGesture(),
        onPanEnd: (_) => controller.endGesture(),
        onPanCancel: controller.endGesture,
        onPanUpdate: (d) {
          final t = controller.value, r = t.crop;
          final left = i == 0 || i == 2, top = i < 2;
          var l = r.left, rt = r.right, tp = r.top, b = r.bottom;
          if (left) {
            l = (l + d.delta.dx / c.maxWidth).clamp(0, rt - .04);
          } else {
            rt = (rt + d.delta.dx / c.maxWidth).clamp(l + .04, 1);
          }
          if (top) {
            tp = (tp + d.delta.dy / c.maxHeight).clamp(0, b - .04);
          } else {
            b = (b + d.delta.dy / c.maxHeight).clamp(tp + .04, 1);
          }
          if (aspect > 0) {
            final ratio = aspect / imageAspect;
            final maxW = left ? r.right : 1 - r.left,
                maxH = top ? r.bottom : 1 - r.top;
            final fromX = rt - l, fromY = (b - tp) * ratio;
            final width = (d.delta.dx.abs() >= d.delta.dy.abs() ? fromX : fromY)
                .clamp(
                  math.min(.04, math.min(maxW, maxH * ratio)),
                  math.min(maxW, maxH * ratio),
                );
            final height = width / ratio;
            l = left ? r.right - width : r.left;
            rt = left ? r.right : r.left + width;
            tp = top ? r.bottom - height : r.top;
            b = top ? r.bottom : r.top + height;
          }
          controller.update(
            t.copyWith(crop: CropRect(left: l, top: tp, right: rt, bottom: b)),
          );
        },
        child: SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: zc.accent,
                border: Border.all(color: ZyncPalette.dark.bg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistortOverlay extends StatelessWidget {
  final PhotoEditController controller;
  const _DistortOverlay({required this.controller});

  Offset _map(Offset p, PhotoEditTransform t, {bool inverse = false}) {
    final a = t.rotationDegrees * math.pi / 180,
        co = math.cos(a),
        si = math.sin(a);
    final w = controller.sourceWidth.toDouble(),
        h = controller.sourceHeight.toDouble();
    final rw = w * co.abs() + h * si.abs(), rh = w * si.abs() + h * co.abs();
    if (inverse) {
      var x = p.dx / t.scale, y = p.dy / t.scale;
      if (t.flipHorizontal) x = -x;
      if (t.flipVertical) y = -y;
      return Offset(
        (x * rw * co + y * rh * si) / w,
        (-x * rw * si + y * rh * co) / h,
      );
    }
    var x = ((p.dx - .5) * w * co - (p.dy - .5) * h * si) / rw + .5;
    var y = ((p.dx - .5) * w * si + (p.dy - .5) * h * co) / rh + .5;
    if (t.flipHorizontal) x = 1 - x;
    if (t.flipVertical) y = 1 - y;
    return Offset(
      .5 + (x - .5) * t.scale + t.offsetX,
      .5 + (y - .5) * t.scale + t.offsetY,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final zc = context.zc;
          final t = controller.value;
          final corners = PhotoEditEngine.corners(
            t,
            width: controller.sourceWidth.toDouble(),
            height: controller.sourceHeight.toDouble(),
          ).map((p) => _map(Offset(p.x, p.y), t)).toList();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: (corners[i].dx * c.maxWidth).clamp(
                        math.min(16, c.maxWidth / 2),
                        math.max(c.maxWidth - 16, c.maxWidth / 2),
                      ) -
                      16,
                  top: (corners[i].dy * c.maxHeight).clamp(
                        math.min(16, c.maxHeight / 2),
                        math.max(c.maxHeight - 16, c.maxHeight / 2),
                      ) -
                      16,
                  child: GestureDetector(
                    key: ValueKey('distort-handle-$i'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => controller.beginGesture(),
                    onPanEnd: (_) => controller.endGesture(),
                    onPanCancel: controller.endGesture,
                    onPanUpdate: (d) {
                      final t = controller.value;
                      final delta = _map(
                        Offset(
                          d.delta.dx / c.maxWidth,
                          d.delta.dy / c.maxHeight,
                        ),
                        t,
                        inverse: true,
                      );
                      final next = switch (i) {
                        0 => t.copyWith(
                            distortTopLeftX:
                                (t.distortTopLeftX + delta.dx).clamp(-.45, .45),
                            distortTopLeftY:
                                (t.distortTopLeftY + delta.dy).clamp(-.45, .45),
                          ),
                        1 => t.copyWith(
                            distortTopRightX: (t.distortTopRightX + delta.dx)
                                .clamp(-.45, .45),
                            distortTopRightY: (t.distortTopRightY + delta.dy)
                                .clamp(-.45, .45),
                          ),
                        2 => t.copyWith(
                            distortBottomRightX:
                                (t.distortBottomRightX + delta.dx)
                                    .clamp(-.45, .45),
                            distortBottomRightY:
                                (t.distortBottomRightY + delta.dy)
                                    .clamp(-.45, .45),
                          ),
                        _ => t.copyWith(
                            distortBottomLeftX:
                                (t.distortBottomLeftX + delta.dx)
                                    .clamp(-.45, .45),
                            distortBottomLeftY:
                                (t.distortBottomLeftY + delta.dy)
                                    .clamp(-.45, .45),
                          ),
                      };
                      if (PhotoEditEngine.validQuad(
                        next,
                        width: controller.sourceWidth.toDouble(),
                        height: controller.sourceHeight.toDouble(),
                      )) {
                        controller.update(next);
                      }
                    },
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: zc.info,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: ZyncPalette.dark.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class _CropMaskPainter extends CustomPainter {
  final Rect rect;
  _CropMaskPainter(this.rect);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, Paint()..color = ZyncPalette.dark.bg.withAlpha(110));
  }

  @override
  bool shouldRepaint(_CropMaskPainter old) => old.rect != rect;
}
