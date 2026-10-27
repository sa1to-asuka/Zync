part of '../gallery_screen.dart';

/// 全屏查看器的可缩放大图：双击缩放 + 下拉关闭。
///
/// 相机查看器与本地查看器共用这一份实现，避免两处手势与阈值漂移。
/// 下拉用原始指针监听（不参与手势竞技场），因此翻页与捏合缩放不受影响。
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.child});

  final Widget child;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  static const double _zoomScale = 2.2;
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 800;

  final TransformationController _controller = TransformationController();
  Offset? _doubleTapPosition;
  Offset? _pointerStart;
  Duration? _pointerStartTime;
  double _dragOffset = 0;

  // 下拉关闭只允许「单指」触发：捏合时第二根手指的按下会覆盖起始点，
  // 两指之间的相对位移会被误判成向下拖动，导致一放大就返回上一级。
  int _activePointers = 0;
  int? _dragPointer;
  bool _multiTouch = false;

  bool get _isZoomed => _controller.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 双击：以触点为中心在 2.2× 与 1× 之间切换（瞬时，不加动画）。
  void _toggleZoom() {
    if (_isZoomed) {
      _controller.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapPosition;
    if (position == null) return;
    // viewport = point * scale + offset，令触点保持原位 ⇒ offset = point * (1 - scale)
    final factor = 1 - _zoomScale;
    _controller.value = Matrix4.identity()
      ..setEntry(0, 0, _zoomScale)
      ..setEntry(1, 1, _zoomScale)
      ..setEntry(0, 3, position.dx * factor)
      ..setEntry(1, 3, position.dy * factor);
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    if (_activePointers > 1) {
      // 出现第二根手指 → 判定为缩放/双指平移，本次手势不再允许下拉关闭
      _multiTouch = true;
      _dragPointer = null;
      _pointerStart = null;
      _pointerStartTime = null;
      if (_dragOffset != 0) setState(() => _dragOffset = 0);
      return;
    }
    if (_isZoomed) return; // 放大状态下纵向拖动是平移图片
    _dragPointer = event.pointer;
    _pointerStart = event.position;
    _pointerStartTime = event.timeStamp;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_multiTouch || event.pointer != _dragPointer) return;
    final start = _pointerStart;
    if (start == null) return;
    final delta = event.position - start;
    if (_dragOffset == 0 &&
        (delta.dy <= 16 || delta.dy <= delta.dx.abs() * 1.2)) {
      return; // 还没构成「明显向下拖」
    }
    if (delta.dy <= 0) return;
    setState(() => _dragOffset = delta.dy);
  }

  void _onPointerEnd(PointerEvent event, {required bool canceled}) {
    _activePointers = _activePointers > 0 ? _activePointers - 1 : 0;
    if (_activePointers == 0) _multiTouch = false;
    if (event.pointer != _dragPointer) return;
    _dragPointer = null;
    _endPointerDrag(event.timeStamp, canceled: canceled);
  }

  void _endPointerDrag(Duration timeStamp, {required bool canceled}) {
    final startedAt = _pointerStartTime;
    _pointerStart = null;
    _pointerStartTime = null;
    final dragged = _dragOffset;
    if (dragged <= 0) return;
    setState(() => _dragOffset = 0); // 回弹

    if (canceled) return;
    // 用指针事件时间戳算速度（而不是墙上时钟），既准确又便于测试
    final elapsedMs = startedAt == null
        ? 1
        : (timeStamp - startedAt).inMilliseconds.clamp(1, 100000);
    final velocity = dragged * 1000 / elapsedMs;
    if (dragged > _dismissDistance || velocity > _dismissVelocity) {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (event) => _onPointerEnd(event, canceled: false),
      onPointerCancel: (event) => _onPointerEnd(event, canceled: true),
      child: AnimatedContainer(
        // 拖动跟手（零时长）；松手回弹（ZMotion.fast）
        duration: _dragOffset == 0
            ? ZMotion.resolve(context, ZMotion.fast)
            : Duration.zero,
        curve: ZMotion.emphasizedDecelerate,
        transform: Matrix4.translationValues(0, _dragOffset, 0),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: _toggleZoom,
          child: InteractiveViewer(
            transformationController: _controller,
            minScale: 1.0,
            maxScale: 4.5,
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}
