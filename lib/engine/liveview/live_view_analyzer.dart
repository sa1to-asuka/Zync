import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'live_view_analysis.dart';

/// 一张叠加图。持有 `ui.Image`，由 [LiveViewAnalyzer] 负责释放。
class LiveViewAnalysisOverlay {
  final ui.Image image;
  final int width;
  final int height;
  final int sourceSequence;

  const LiveViewAnalysisOverlay({
    required this.image,
    required this.width,
    required this.height,
    required this.sourceSequence,
  });
}

/// 直方图快照（已做指数平滑，避免每帧跳动）。
class HistogramSnapshot {
  final Uint32List bins;
  final int peakCount;
  final int overexposedPixels;

  const HistogramSnapshot({
    required this.bins,
    required this.peakCount,
    required this.overexposedPixels,
  });

  double ratioOf(int bin) => peakCount == 0 ? 0 : bins[bin] / peakCount;
}

typedef AnalyzeFunction = Future<RawAnalysisResult?> Function(
    Uint8List jpeg, LiveViewAnalysisSettings settings);

/// 取景分析的调度器：节流、合流、把结果变成 `ui.Image`。
///
/// 真正的解码与像素运算在后台 isolate 里跑（[analyzeJpegBytes]）；
/// 这里只在 UI isolate 上做「要不要现在算」和「结果怎么给 painter」。
class LiveViewAnalyzer {
  LiveViewAnalyzer({
    AnalyzeFunction? analyze,
    LiveViewAnalysisSettings settings = LiveViewAnalysisSettings.disabled,
    this.minInterval = const Duration(milliseconds: 200),
  })  : _analyze = analyze ?? _defaultAnalyze,
        _settings = ValueNotifier<LiveViewAnalysisSettings>(settings);

  final AnalyzeFunction _analyze;
  final Duration minInterval;

  static Future<RawAnalysisResult?> _defaultAnalyze(
    Uint8List jpeg,
    LiveViewAnalysisSettings settings,
  ) {
    // 同一个 isolate group，闭包与设置对象都可以直接传。
    return Isolate.run(() => analyzeJpegBytes(jpeg, settings));
  }

  final ValueNotifier<LiveViewAnalysisSettings> _settings;
  final ValueNotifier<LiveViewAnalysisOverlay?> _overlay =
      ValueNotifier<LiveViewAnalysisOverlay?>(null);
  final ValueNotifier<HistogramSnapshot?> _histogram =
      ValueNotifier<HistogramSnapshot?>(null);

  ValueListenable<LiveViewAnalysisSettings> get settings => _settings;
  ValueListenable<LiveViewAnalysisOverlay?> get overlay => _overlay;
  ValueListenable<HistogramSnapshot?> get histogram => _histogram;

  Uint8List? _pending;
  bool _busy = false;
  bool _disposed = false;
  int _epoch = 0;
  int _sequence = 0;
  Timer? _flushTimer;
  DateTime _lastStart = DateTime.fromMillisecondsSinceEpoch(0);
  double _histogramAlpha = 0.35;

  int offeredFrames = 0;
  int analyzedFrames = 0;
  int droppedFrames = 0;
  int failedFrames = 0;

  bool get isBusy => _busy;

  LiveViewAnalysisSettings get currentSettings => _settings.value;

  void updateSettings(LiveViewAnalysisSettings next) {
    if (_settings.value == next) return;
    _epoch++;
    _settings.value = next;
    if (!next.anyEnabled) {
      _pending = null;
      _flushTimer?.cancel();
      _flushTimer = null;
      _clearOutputs();
    }
  }

  /// 由 [LiveViewController] 每帧调用。同步、O(1)、绝不 await。
  void offerJpeg(Uint8List jpeg) {
    if (_disposed) return;
    final settings = _settings.value;
    if (!settings.anyEnabled) {
      _pending = null;
      _clearOutputs();
      return;
    }

    offeredFrames++;
    // 取景负载是原缓冲区的视图，必须复制后再交给另一个 isolate。
    final copy = Uint8List.fromList(jpeg);

    if (_busy) {
      _pending = copy;
      droppedFrames++;
      return;
    }

    final sinceStart = DateTime.now().difference(_lastStart);
    if (sinceStart < minInterval) {
      _pending = copy;
      droppedFrames++;
      _scheduleFlush(minInterval - sinceStart);
      return;
    }

    _start(copy, settings);
  }

  void _scheduleFlush(Duration delay) {
    if (_flushTimer != null) return;
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      if (_disposed || _busy) return;
      final next = _pending;
      _pending = null;
      final settings = _settings.value;
      if (next != null && settings.anyEnabled) _start(next, settings);
    });
  }

  Future<void> _start(Uint8List jpeg, LiveViewAnalysisSettings settings) async {
    _busy = true;
    _lastStart = DateTime.now();
    final epoch = _epoch;

    try {
      final raw = await _analyze(jpeg, settings);
      if (_disposed || epoch != _epoch) return;
      if (raw == null) {
        failedFrames++;
        return;
      }
      analyzedFrames++;
      _publishHistogram(raw);
      if (raw.overlayRgba == null) {
        _clearOverlay();
      } else {
        await _publishOverlay(raw, epoch);
      }
    } catch (_) {
      failedFrames++;
    } finally {
      _busy = false;
      final next = _pending;
      _pending = null;
      if (next != null && !_disposed && _settings.value.anyEnabled) {
        _start(next, _settings.value);
      }
    }
  }

  void _publishHistogram(RawAnalysisResult raw) {
    final previous = _histogram.value;
    final bins = Uint32List(256);
    var peak = 0;
    for (var i = 0; i < 256; i++) {
      final value = previous == null
          ? raw.histogram[i]
          : (_histogramAlpha * raw.histogram[i] +
                  (1 - _histogramAlpha) * previous.bins[i])
              .round();
      bins[i] = value;
      if (value > peak) peak = value;
    }
    _histogram.value = HistogramSnapshot(
      bins: bins,
      peakCount: peak,
      overexposedPixels: raw.overexposedPixels,
    );
  }

  Future<void> _publishOverlay(RawAnalysisResult raw, int epoch) async {
    final rgba = raw.overlayRgba;
    if (rgba == null) return;
    ui.Image image;
    try {
      image = await _rgbaToImage(rgba, raw.width, raw.height);
    } catch (_) {
      failedFrames++;
      return;
    }
    if (_disposed || epoch != _epoch) {
      image.dispose();
      return;
    }
    final previous = _overlay.value;
    _sequence++;
    _overlay.value = LiveViewAnalysisOverlay(
      image: image,
      width: raw.width,
      height: raw.height,
      sourceSequence: _sequence,
    );
    _disposePostFrame(previous?.image);
  }

  Future<ui.Image> _rgbaToImage(Uint8List rgba, int width, int height) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    return frame.image;
  }

  void _clearOverlay() {
    final current = _overlay.value;
    if (current == null) return;
    _overlay.value = null;
    _disposePostFrame(current.image);
  }

  void _clearOutputs() {
    _clearOverlay();
    _histogram.value = null;
  }

  void _disposePostFrame(ui.Image? image) {
    if (image == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
  }

  /// 取景停止或断开时调用；不销毁 isolate，因为用户可能马上重连。
  void clear() {
    _epoch++;
    _pending = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _clearOutputs();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    _pending = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    final current = _overlay.value;
    _overlay.value = null;
    current?.image.dispose();
    _overlay.dispose();
    _histogram.dispose();
    _settings.dispose();
  }
}
