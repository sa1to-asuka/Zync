/// Spektrafilm 与 `ui.Image` 的桥接：调用原生光谱引擎，并做预览防抖。
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'spektrafilm_models.dart';
import 'spektrafilm_native.dart';

/// 把胶片模拟应用到 `ui.Image`（导出与预览共用）。
abstract final class SpektrafilmRenderer {
  /// 未启用时直接返回原图，调用方无需判断。
  static Future<ui.Image> applyToUiImage(
    ui.Image source,
    SpektrafilmSettings settings,
  ) async {
    if (!settings.isActive) return source;
    final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return source;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final processed = await SpektrafilmNative.render(
      rgba: bytes,
      width: source.width,
      height: source.height,
      settings: settings,
    );
    if (processed == null) return source;
    return _decode(processed, source.width, source.height);
  }

  static Future<ui.Image> _decode(
    Uint8List bytes,
    int width,
    int height,
  ) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }
}

/// 水印工坊预览用的胶片模拟控制器。
///
/// - 防抖，避免拖动滑块时堆积请求；
/// - 请求代次校验，过期结果直接丢弃；
/// - 始终只持有一张处理后的位图，替换时立即释放旧图。
class SpektrafilmPreviewController extends ChangeNotifier {
  SpektrafilmPreviewController({
    this.debounce = const Duration(milliseconds: 120),
  });

  final Duration debounce;

  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool _processing = false;
  ui.Image? _image;
  ui.Image? _retired;
  Timer? _retireTimer;
  String? _lastError;
  String? _lastKey;
  (ui.Image, SpektrafilmSettings)? _pending;

  ui.Image? get image => _image;

  bool get isProcessing => _processing;

  /// 最近一次预览渲染的错误（成功后清空）。
  String? get lastError => _lastError;

  /// 提交最新的源图与参数；未启用时清空处理结果。
  void update(ui.Image? source, SpektrafilmSettings settings) {
    if (_disposed) return;
    if (source == null || !settings.isActive) {
      _timer?.cancel();
      _timer = null;
      _generation++;
      _lastKey = null;
      _pending = null;
      if (_processing) {
        _processing = false;
        notifyListeners();
      }
      final current = _image;
      if (current != null) {
        _retire(current);
        _image = null;
        notifyListeners();
      }
      return;
    }

    final key = '${identityHashCode(source)}|${settings.requestKey}';
    if (key == _lastKey) return;
    _lastKey = key;
    _pending = (source, settings);
    _timer?.cancel();
    _timer = Timer(debounce, _run);
  }

  Future<void> _run() async {
    final request = _pending;
    if (request == null || _disposed) return;
    final source = request.$1;
    final settings = request.$2;
    final generation = ++_generation;
    _processing = true;
    notifyListeners();

    try {
      final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        if (!_disposed && generation == _generation) {
          _processing = false;
          _lastError = 'image-unavailable';
          _lastKey = null;
          notifyListeners();
        }
        return;
      }
      if (_disposed || generation != _generation) return;
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final processed = await SpektrafilmNative.render(
        rgba: bytes,
        width: source.width,
        height: source.height,
        settings: settings,
      );
      if (_disposed || generation != _generation) return;
      if (processed == null) {
        _processing = false;
        _lastError = 'render-failed';
        _lastKey = null; // allow a later update to retry
        notifyListeners();
        return;
      }
      final image = await SpektrafilmRenderer._decode(
        processed,
        source.width,
        source.height,
      );
      if (_disposed || generation != _generation) {
        image.dispose();
        return;
      }
      final old = _image;
      _image = image;
      _processing = false;
      _lastError = null;
      if (old != null) _retire(old);
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      _processing = false;
      _lastError = 'render-failed';
      _lastKey = null; // allow a later update to retry
      notifyListeners();
    }
  }

  // 旧图可能仍被上一帧绘制引用，延后释放避免画到已销毁的图。
  void _retire(ui.Image image) {
    _retireTimer?.cancel();
    final previous = _retired;
    _retired = image;
    if (previous != null) previous.dispose();
    _retireTimer = Timer(const Duration(milliseconds: 500), () {
      _retired?.dispose();
      _retired = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _retireTimer?.cancel();
    _retired?.dispose();
    _image?.dispose();
    _image = null;
    _retired = null;
    super.dispose();
  }
}
