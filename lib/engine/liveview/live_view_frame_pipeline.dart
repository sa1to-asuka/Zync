import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 一帧已解码的取景画面。
///
/// [image] 是原生显存对象，必须由持有方负责 `dispose()`。
class LiveViewFrame {
  final ui.Image image;
  final int width;
  final int height;
  final int sequence;

  const LiveViewFrame({
    required this.image,
    required this.width,
    required this.height,
    required this.sequence,
  });
}

/// 取景帧的解码与合流。
///
/// 相机的出帧速度可能快于 JPEG 解码速度，这里只保留「最新一帧待解码」：
/// 解码忙时新帧覆盖旧帧并计入丢弃数，管线里最多同时存在两帧，
/// 因此无论相机多快，内存与延迟都有上界。
class LiveViewFramePipeline {
  LiveViewFramePipeline();

  final ValueNotifier<LiveViewFrame?> _frame =
      ValueNotifier<LiveViewFrame?>(null);

  Uint8List? _pending;
  Uint8List? _latestJpeg;
  bool _decoding = false;
  bool _disposed = false;
  int _sequence = 0;
  int _decoded = 0;
  int _dropped = 0;

  ValueListenable<LiveViewFrame?> get frame => _frame;

  /// 最近收到的原始取景 JPEG（供 AI 取景构图与影调分析复用，不额外拷贝内存）。
  Uint8List? get latestJpeg => _latestJpeg;

  int get decodedFrames => _decoded;
  int get droppedFrames => _dropped;

  /// 提交一帧 JPEG。传入 `null` 或已释放时是空操作。
  void offerJpeg(Uint8List? jpeg) {
    if (_disposed || jpeg == null || jpeg.isEmpty) return;
    _latestJpeg = jpeg;
    if (_decoding) {
      _pending = jpeg;
      _dropped++;
      return;
    }
    _decodeLoop(jpeg);
  }

  Future<void> _decodeLoop(Uint8List first) async {
    _decoding = true;
    var jpeg = first;
    try {
      while (true) {
        final image = await _decode(jpeg);
        if (_disposed) {
          image?.dispose();
          return;
        }
        if (image != null) _swap(image);

        final next = _pending;
        _pending = null;
        if (next == null) break;
        jpeg = next;
      }
    } finally {
      _decoding = false;
    }
  }

  Future<ui.Image?> _decode(Uint8List jpeg) async {
    try {
      final codec = await ui.instantiateImageCodec(jpeg);
      final info = await codec.getNextFrame();
      codec.dispose();
      return info.image;
    } catch (_) {
      // 半帧或损坏的帧直接丢掉，等下一帧。
      return null;
    }
  }

  void _swap(ui.Image image) {
    final previous = _frame.value;
    _sequence++;
    _decoded++;
    _frame.value = LiveViewFrame(
      image: image,
      width: image.width,
      height: image.height,
      sequence: _sequence,
    );
    if (previous != null) {
      // 必须等这一帧画完再释放，否则会在绘制途中回收显存。
      SchedulerBinding.instance.addPostFrameCallback((_) {
        previous.image.dispose();
      });
    }
  }

  /// 清空当前帧（例如退出取景）。
  void clear() {
    _pending = null;
    _latestJpeg = null;
    final current = _frame.value;
    _frame.value = null;
    if (current != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        current.image.dispose();
      });
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pending = null;
    _latestJpeg = null;
    final current = _frame.value;
    _frame.value = null;
    current?.image.dispose();
    _frame.dispose();
  }
}
