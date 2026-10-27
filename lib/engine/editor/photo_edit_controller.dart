import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

import 'photo_edit_engine.dart';

/// 编辑历史栈：提供撤销 / 重做，限制最大步数避免内存膨胀。
class PhotoEditController extends ChangeNotifier {
  PhotoEditController({PhotoEditTransform initial = const PhotoEditTransform()})
      : _current = initial {
    _history.add(initial);
  }

  static const int maxHistory = 30;
  PhotoEditWorker? _worker;
  ui.Image? previewImage;
  ui.Image? originalPreview;
  int sourceWidth = 0, sourceHeight = 0;
  int _paintedRevision = -1;
  bool get previewPending => _paintedRevision != _revision;
  String? renderError;
  bool loading = false,
      _disposed = false,
      _rendering = false,
      _omitCrop = false;
  int _revision = 0;
  Timer? _timer;

  void setCropOverlay(bool omit) {
    if (_omitCrop == omit) return;
    _omitCrop = omit;
    _schedulePreview();
  }

  Future<void> load(Uint8List bytes) async {
    final old = _worker;
    final worker = PhotoEditWorker();
    _worker = worker;
    old?.dispose();
    _revision++;
    loading = true;
    renderError = null;
    notifyListeners();
    try {
      final info = await worker.open(bytes);
      if (_disposed || _worker != worker) return;
      sourceWidth = info['width'] as int;
      sourceHeight = info['height'] as int;
      final codec =
          await ui.instantiateImageCodec(info['previewBytes'] as Uint8List);
      final ui.Image original;
      try {
        original = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (_disposed || _worker != worker) {
        original.dispose();
        return;
      }
      originalPreview?.dispose();
      originalPreview = original;
      loading = false;
      if (value.isIdentity) {
        final old = previewImage;
        previewImage = original.clone();
        _paintedRevision = _revision;
        notifyListeners();
        old?.dispose();
        return;
      }
      await _renderPreview();
    } catch (e) {
      if (!_disposed && _worker == worker) {
        loading = false;
        renderError = e.toString();
        notifyListeners();
      }
    }
  }

  void _schedulePreview() {
    if (_worker == null || loading || _disposed) return;
    _revision++;

    if (_timer?.isActive != true)
      _timer = Timer(const Duration(milliseconds: 50), _renderPreview);
  }

  Future<void> _renderPreview() async {
    if (_rendering || _disposed || loading || _worker == null) return;
    _rendering = true;
    final revision = _revision, worker = _worker;

    try {
      final result = await worker!.render(_current, omitCrop: _omitCrop);

      if (_disposed || revision != _revision || worker != _worker) return;
      final codec =
          await ui.instantiateImageCodec(result['bytes'] as Uint8List);
      try {
        final frame = await codec.getNextFrame();
        if (_disposed || revision != _revision || worker != _worker) {
          frame.image.dispose();
          return;
        }
        final previous = previewImage;
        previewImage = frame.image;
        renderError = null;
        _paintedRevision = revision;
        notifyListeners();
        previous?.dispose();
      } finally {
        codec.dispose();
      }
    } catch (e) {
      if (!_disposed && revision == _revision && worker == _worker) {
        renderError = e.toString();
        notifyListeners();
      }
    } finally {
      _rendering = false;
      if (!_disposed && (revision != _revision || worker != _worker)) {
        _timer?.cancel();
        _renderPreview();
      }
    }
  }

  Future<Uint8List> renderFull({String format = 'png'}) async {
    if (_worker == null || loading) throw StateError('工作图尚未加载');
    final result =
        await _worker!.render(_current, preview: false, format: format);
    return result['bytes'] as Uint8List;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _worker?.dispose();
    previewImage?.dispose();
    originalPreview?.dispose();
    super.dispose();
  }

  final List<PhotoEditTransform> _history = [];
  int _cursor = 0;
  PhotoEditTransform _current;

  PhotoEditTransform get value => _current;
  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _history.length - 1;
  bool get isDirty => !_current.isIdentity;

  void rotateBy(double degrees) {
    var angle = (_current.rotationDegrees + degrees) % 360;
    if (angle > 180) angle -= 360;
    update(_current.copyWith(rotationDegrees: angle));
  }

  PhotoEditTransform? _gestureStart;
  bool get inGesture => _gestureStart != null;
  void beginGesture() {
    _gestureStart ??= _current;
  }

  void endGesture() {
    final start = _gestureStart;
    _gestureStart = null;
    if (start == null || start == _current) return;
    final next = _current;
    _current = start;
    update(next);
  }

  /// 提交一次变换；与当前值相同时忽略，避免污染历史。
  void update(PhotoEditTransform next) {
    if (next == _current) return;
    _current = next;
    if (_gestureStart != null) {
      _schedulePreview();
      notifyListeners();
      return;
    }
    if (_cursor < _history.length - 1) {
      _history.removeRange(_cursor + 1, _history.length);
    }
    _history.add(next);
    if (_history.length > maxHistory) {
      _history.removeAt(0);
    } else {
      _cursor++;
    }
    _cursor = _history.length - 1;
    _schedulePreview();
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _cursor--;
    _current = _history[_cursor];

    _schedulePreview();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _cursor++;
    _current = _history[_cursor];

    _schedulePreview();
    notifyListeners();
  }

  void reset() {
    _gestureStart = null;
    _history
      ..clear()
      ..add(const PhotoEditTransform());
    _cursor = 0;
    _current = _history.first;
    _schedulePreview();
    notifyListeners();
  }
}
