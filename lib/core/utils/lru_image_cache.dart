import 'dart:typed_data';

/// 原图字节 LRU 缓存：默认最多 2 张且总量不超过 128MB，
/// 避免查看大图/水印时无限缓存原图导致内存膨胀。
class LruImageCache {
  LruImageCache({this.maxEntries = 2, this.maxBytes = 128 * 1024 * 1024});

  final int maxEntries;
  final int maxBytes;

  // Dart 的 Map 保持插入顺序，队尾即最近使用。
  final Map<String, Uint8List> _map = {};

  Uint8List? operator [](String key) {
    final v = _map.remove(key);
    if (v != null) _map[key] = v; // 命中后移动到队尾
    return v;
  }

  bool containsKey(String key) => _map.containsKey(key);

  void operator []=(String key, Uint8List value) {
    _map.remove(key);
    _map[key] = value;
    _evict();
  }

  Uint8List? remove(String key) => _map.remove(key);

  void clear() => _map.clear();

  void _evict() {
    while (_map.isNotEmpty && (_map.length > maxEntries || _totalBytes() > maxBytes)) {
      _map.remove(_map.keys.first);
    }
  }

  int _totalBytes() {
    var total = 0;
    for (final v in _map.values) {
      total += v.length;
    }
    return total;
  }
}

/// 跨卡槽唯一缓存键：storageId 与 handle 组合，避免不同卡槽同名文件互相串图。
String cameraCacheKey(int storageId, int handle) => '${storageId}_$handle';
