import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/exif_helper.dart';
import '../../engine/watermark/watermark_overlay_layer.dart';
import '../../engine/watermark/watermark_painter.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 自由拖拽/旋转/缩放艺术字图层的透明交互手势叠加层。
///
/// 精确对齐 [WatermarkCanvasPainter] 的逻辑总画布尺寸，支持：
/// - 点击命中测试（逆序命中顶层，带缩放与旋转逆变换）
/// - 单指自由拖移（画布 50% 中轴与 1/3、2/3 线磁吸并震动提示）
/// - 双指捏合缩放 & 扭转旋转
/// - 右下角单手缩放旋转手柄 + 顶部快捷删除/编辑/复制按钮
class WatermarkLayerEditorOverlay extends StatefulWidget {
  final Size previewSize;
  final Size logicalCanvasSize;
  final PhotoMetadata metadata;
  final List<WatermarkTextLayer> layers;
  final String? selectedLayerId;
  final String? globalFontFamily;
  final ValueChanged<String?> onSelectLayer;
  final ValueChanged<WatermarkTextLayer> onUpdateLayer;
  final ValueChanged<String> onDeleteLayer;
  final ValueChanged<WatermarkTextLayer> onEditLayerText;
  final ValueChanged<WatermarkTextLayer>? onDuplicateLayer;

  const WatermarkLayerEditorOverlay({
    super.key,
    required this.previewSize,
    required this.logicalCanvasSize,
    required this.metadata,
    required this.layers,
    required this.selectedLayerId,
    required this.globalFontFamily,
    required this.onSelectLayer,
    required this.onUpdateLayer,
    required this.onDeleteLayer,
    required this.onEditLayerText,
    this.onDuplicateLayer,
  });

  @override
  State<WatermarkLayerEditorOverlay> createState() =>
      _WatermarkLayerEditorOverlayState();
}

class _WatermarkLayerEditorOverlayState
    extends State<WatermarkLayerEditorOverlay> {
  String? _gestureLayerId;
  WatermarkTextLayer? _startLayer;
  Offset? _startFocal;
  bool _snapX = false;
  bool _snapY = false;
  bool _wasSnappedX = false;
  bool _wasSnappedY = false;

  // 右下角单手控制手柄拖动基准
  bool _cornerDragging = false;
  double _cornerStartDist = 1.0;
  double _cornerStartAngle = 0.0;

  double get _scaleToPreview => widget.logicalCanvasSize.width <= 0
      ? 1.0
      : widget.previewSize.width / widget.logicalCanvasSize.width;

  Size _layerPreviewBox(WatermarkTextLayer layer) {
    final s = WatermarkCanvasPainter.measureTextLayer(
      layer,
      widget.metadata,
      widget.logicalCanvasSize,
      overrideGlobalFamily: widget.globalFontFamily,
    );
    final k = _scaleToPreview;
    return Size(math.max(36, s.width * k), math.max(28, s.height * k));
  }

  Offset _layerCenterPreview(WatermarkTextLayer layer) => Offset(
        layer.nx * widget.previewSize.width,
        layer.ny * widget.previewSize.height,
      );

  WatermarkTextLayer? _hitTestLayer(Offset local) {
    for (var i = widget.layers.length - 1; i >= 0; i--) {
      final layer = widget.layers[i];
      if (layer.locked) continue;
      final center = _layerCenterPreview(layer);
      final box = _layerPreviewBox(layer);
      final dx = local.dx - center.dx;
      final dy = local.dy - center.dy;
      final cosR = math.cos(-layer.rotation);
      final sinR = math.sin(-layer.rotation);
      final rx = dx * cosR - dy * sinR;
      final ry = dx * sinR + dy * cosR;
      if (rx.abs() <= box.width / 2 + 12 &&
          ry.abs() <= box.height / 2 + 12) {
        return layer;
      }
    }
    return null;
  }

  void _onTapDown(TapDownDetails details) {
    final hit = _hitTestLayer(details.localPosition);
    widget.onSelectLayer(hit?.id);
  }

  void _onDoubleTap(Offset pos) {
    final hit = _hitTestLayer(pos);
    if (hit != null) {
      widget.onSelectLayer(hit.id);
      widget.onEditLayerText(hit);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_cornerDragging) return;
    final hit = _hitTestLayer(details.localFocalPoint);
    if (hit == null) {
      // 若手势开始时已有选中且双指手势较大，则直接操作当前选中层
      final selected = widget.layers
          .where((e) => e.id == widget.selectedLayerId && !e.locked)
          .firstOrNull;
      if (selected != null && details.pointerCount >= 2) {
        _gestureLayerId = selected.id;
        _startLayer = selected;
        _startFocal = details.localFocalPoint;
      } else {
        _gestureLayerId = null;
        _startLayer = null;
      }
      return;
    }
    widget.onSelectLayer(hit.id);
    _gestureLayerId = hit.id;
    _startLayer = hit;
    _startFocal = details.localFocalPoint;
    _wasSnappedX = false;
    _wasSnappedY = false;
  }

  double _snapValue(double v, List<double> targets, {double tol = 0.014}) {
    for (final t in targets) {
      if ((v - t).abs() <= tol) return t;
    }
    return v;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_cornerDragging) return;
    final start = _startLayer;
    final focal0 = _startFocal;
    if (_gestureLayerId == null || start == null || focal0 == null) return;
    final delta = details.localFocalPoint - focal0;
    final w = widget.previewSize.width;
    final h = widget.previewSize.height;
    if (w <= 0 || h <= 0) return;

    var nx = (start.nx + delta.dx / w).clamp(0.03, 0.97);
    var ny = (start.ny + delta.dy / h).clamp(0.03, 0.97);

    const anchors = <double>[0.3333, 0.5, 0.6667];
    final snappedX = _snapValue(nx, anchors);
    final snappedY = _snapValue(ny, anchors);
    final isSnapX = snappedX != nx;
    final isSnapY = snappedY != ny;
    if (isSnapX) nx = snappedX;
    if (isSnapY) ny = snappedY;

    if ((isSnapX && !_wasSnappedX) || (isSnapY && !_wasSnappedY)) {
      HapticFeedback.selectionClick();
    }
    _wasSnappedX = isSnapX;
    _wasSnappedY = isSnapY;

    setState(() {
      _snapX = isSnapX;
      _snapY = isSnapY;
    });

    final nextScale = (start.scale * details.scale).clamp(0.4, 4.0);
    final nextRot = start.rotation + details.rotation;
    widget.onUpdateLayer(start.copyWith(
      nx: nx,
      ny: ny,
      scale: nextScale,
      rotation: nextRot,
    ));
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _gestureLayerId = null;
    _startLayer = null;
    _startFocal = null;
    if (_snapX || _snapY) {
      setState(() {
        _snapX = false;
        _snapY = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final selected = widget.layers
        .where((e) => e.id == widget.selectedLayerId)
        .firstOrNull;
    final w = widget.previewSize.width;
    final h = widget.previewSize.height;

    Offset? tapDownPos;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) {
                tapDownPos = d.localPosition;
                _onTapDown(d);
              },
              onDoubleTap: () {
                if (tapDownPos != null) _onDoubleTap(tapDownPos!);
              },
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: CustomPaint(
                painter: _SnapGuidesPainter(
                  snapX: _snapX,
                  snapY: _snapY,
                  centerX: selected?.nx ?? 0.5,
                  centerY: selected?.ny ?? 0.5,
                  guideColor: ZSwatch.nikonGold,
                ),
              ),
            ),
          ),
          if (selected != null) _buildSelectionFrame(context, selected, zc),
        ],
      ),
    );
  }

  Widget _buildSelectionFrame(
    BuildContext context,
    WatermarkTextLayer layer,
    ZyncPalette zc,
  ) {
    final center = _layerCenterPreview(layer);
    final box = _layerPreviewBox(layer);
    const handlePad = 24.0;
    final l10n = context.l10n;

    return Positioned(
      left: center.dx - box.width / 2 - handlePad,
      top: center.dy - box.height / 2 - handlePad,
      width: box.width + handlePad * 2,
      height: box.height + handlePad * 2,
      child: Transform.rotate(
        angle: layer.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: handlePad,
              top: handlePad,
              width: box.width,
              height: box.height,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ZSwatch.nikonGold,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // 左上角：删除
            Positioned(
              left: handlePad - 12,
              top: handlePad - 12,
              child: _cornerActionIcon(
                icon: Icons.close,
                tooltip: l10n.commonDelete,
                bg: zc.danger,
                fg: ZSwatch.pureWhite,
                onTap: () => widget.onDeleteLayer(layer.id),
              ),
            ),
            // 右上角：编辑文案
            Positioned(
              right: handlePad - 12,
              top: handlePad - 12,
              child: _cornerActionIcon(
                icon: Icons.edit,
                tooltip: l10n.wmArtEditText,
                bg: zc.surfaceHigh,
                fg: zc.textPrimary,
                onTap: () => widget.onEditLayerText(layer),
              ),
            ),
            // 右下角：单手缩放/旋转手柄
            Positioned(
              right: handlePad - 12,
              bottom: handlePad - 12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) {
                  _cornerDragging = true;
                  _startLayer = layer;
                  final v = d.globalPosition;
                  final boxRender = context.findRenderObject() as RenderBox?;
                  final localCenter = boxRender?.localToGlobal(center) ?? center;
                  final diff = v - localCenter;
                  _cornerStartDist = math.max(12.0, diff.distance);
                  _cornerStartAngle = math.atan2(diff.dy, diff.dx);
                },
                onPanUpdate: (d) {
                  final start = _startLayer;
                  if (start == null) return;
                  final boxRender = context.findRenderObject() as RenderBox?;
                  final localCenter = boxRender?.localToGlobal(center) ?? center;
                  final diff = d.globalPosition - localCenter;
                  final dist = math.max(12.0, diff.distance);
                  final ang = math.atan2(diff.dy, diff.dx);
                  widget.onUpdateLayer(start.copyWith(
                    scale: (start.scale * (dist / _cornerStartDist))
                        .clamp(0.4, 4.0),
                    rotation: start.rotation + (ang - _cornerStartAngle),
                  ));
                },
                onPanEnd: (_) {
                  _cornerDragging = false;
                  _startLayer = null;
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: ZSwatch.nikonGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: ZSwatch.pureBlack, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 13,
                    color: ZSwatch.pureBlack,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cornerActionIcon({
    required IconData icon,
    required String tooltip,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: ZSwatch.pureWhite, width: 1.0),
          ),
          child: Icon(icon, size: 13, color: fg),
        ),
      ),
    );
  }
}

class _SnapGuidesPainter extends CustomPainter {
  final bool snapX;
  final bool snapY;
  final double centerX;
  final double centerY;
  final Color guideColor;

  _SnapGuidesPainter({
    required this.snapX,
    required this.snapY,
    required this.centerX,
    required this.centerY,
    required this.guideColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!snapX && !snapY) return;
    final p = Paint()
      ..color = guideColor.withAlpha(200)
      ..strokeWidth = 1.0;
    if (snapX) {
      final x = centerX * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    if (snapY) {
      final y = centerY * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _SnapGuidesPainter old) =>
      old.snapX != snapX ||
      old.snapY != snapY ||
      old.centerX != centerX ||
      old.centerY != centerY;
}
