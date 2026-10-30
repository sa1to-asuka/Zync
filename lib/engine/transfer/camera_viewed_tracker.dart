import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 相机存储卡已查看/已浏览照片轻量级持久化追踪器。
/// 记录用户已查看过的照片 baseName，供相册筛选「新照片 / 未查看」使用，
/// 避免用户每次连接相机都要重复查看翻找大量旧照片。
class CameraViewedTracker extends ChangeNotifier {
  static final CameraViewedTracker instance = CameraViewedTracker._();
  CameraViewedTracker._();

  final Set<String> _viewedBaseNames = <String>{};
  File? _file;
  bool _initialized = false;

  Set<String> get viewedBaseNames => Set.unmodifiable(_viewedBaseNames);

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/gallery_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return _file = File('${cacheDir.path}/viewed_items.json');
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    try {
      final f = await _getFile();
      if (await f.exists()) {
        final content = await f.readAsString();
        final List<dynamic> list = jsonDecode(content);
        _viewedBaseNames.addAll(list.map((e) => e.toString()));
      }
    } catch (_) {}
    _initialized = true;
  }

  bool isViewed(String baseName) {
    final clean = baseName.toUpperCase().trim();
    return _viewedBaseNames.contains(clean);
  }

  Future<void> markViewed(String baseName) async {
    await ensureInitialized();
    final clean = baseName.toUpperCase().trim();
    if (_viewedBaseNames.add(clean)) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> markAllViewed(Iterable<String> baseNames) async {
    await ensureInitialized();
    var changed = false;
    for (final b in baseNames) {
      final clean = b.toUpperCase().trim();
      if (_viewedBaseNames.add(clean)) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> clearViewed() async {
    await ensureInitialized();
    if (_viewedBaseNames.isNotEmpty) {
      _viewedBaseNames.clear();
      notifyListeners();
      await _save();
    }
  }

  Future<void> _save() async {
    try {
      final f = await _getFile();
      await f.writeAsString(jsonEncode(_viewedBaseNames.toList()), flush: false);
    } catch (_) {}
  }
}
