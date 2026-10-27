import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../protocol/camera_native_bridge.dart';

/// 已导出到本地相册的文件模型
class ExportedMediaItem {
  final File file;
  final String fileName;
  final String baseName;
  final int size;
  final DateTime modifiedTime;

  /// MediaStore 内容 URI（Android 10+）或旧系统绝对路径；扫描得到的项可能为 null。
  final String? mediaUri;

  /// 是否由编辑器“覆盖原图”写回（用于已导出分类角标）。
  final bool isOverwritten;

  ExportedMediaItem({
    required this.file,
    required this.fileName,
    required this.baseName,
    required this.size,
    required this.modifiedTime,
    this.mediaUri,
    this.isOverwritten = false,
  });

  /// 是否由编辑器“另存为新文件”产生（文件名带 _edit 后缀）。
  bool get isSavedAsCopy =>
      RegExp(r'_EDIT(_\d+)?$').hasMatch(baseName.toUpperCase());

  bool get isJpeg {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
  }

  bool get isRaw {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.nef') || lower.endsWith('.nrw');
  }

  bool get isVideo {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mov') || lower.endsWith('.mp4');
  }

  bool get isPng => fileName.toLowerCase().endsWith('.png');

  String get formatBadge {
    if (isRaw) return 'RAW';
    if (isVideo) return 'VIDEO';
    if (isPng) return 'PNG';
    return 'JPG';
  }

  String get sizeFormatted {
    if (size >= 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }
  }

  String get dateFormatted {
    return '${modifiedTime.year}.${_twoDigits(modifiedTime.month)}.${_twoDigits(modifiedTime.day)} '
        '${_twoDigits(modifiedTime.hour)}:${_twoDigits(modifiedTime.minute)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
}

/// 手机本地已导出照片历史记录管理器
class ExportHistoryManager extends ChangeNotifier {
  static final ExportHistoryManager _instance = ExportHistoryManager._internal();
  factory ExportHistoryManager() => _instance;
  ExportHistoryManager._internal();

  List<ExportedMediaItem> _exportedItems = [];
  final Set<String> _exportedBaseNames = {};
  bool _isLoading = false;

  /// 被编辑器“覆盖原图”写回的文件名集合（持久化，保证重启后角标仍在）。
  final Set<String> _overwrittenNames = {};
  bool _editedIndexLoaded = false;
  final Map<String, Future<File>> _localReads = {};
  final Map<String, String> _sources = {};

  static String sourceKey(int storageId, String name, int size, String captured) =>
      '$storageId|${name.toUpperCase()}|$size|$captured';

  Future<void> recordSource(String key, String uri) async {
    _sources[key] = uri;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/downloaded_media.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(_sources), flush: true);
    await temp.rename(file.path);
  }

  Future<File> ensureLocalFile(ExportedMediaItem item) {
    final key = item.mediaUri ?? item.file.path;
    return _localReads.putIfAbsent(key, () async {
      try {
        if (item.mediaUri?.startsWith('content://') == true) {
          final path = await CameraNativeBridge.materializeMedia(item.mediaUri!);
          if (path == null) throw FileSystemException('本地照片已删除或无法读取', item.fileName);
          final file = File(path);
          if (!await file.exists() || await file.length() == 0) {
            throw FileSystemException('本地照片为空', path);
          }
          return file;
        }
        final file = item.mediaUri != null ? File(item.mediaUri!) : item.file;
        if (!await file.exists() || await file.length() == 0) {
          throw FileSystemException('本地照片已删除或无法读取', file.path);
        }
        return file;
      } finally { _localReads.remove(key); }
    });
  }

  List<ExportedMediaItem> get items => List.unmodifiable(_exportedItems);
  Set<String> get exportedBaseNames => Set.unmodifiable(_exportedBaseNames);
  bool get isLoading => _isLoading;
  int get count => _exportedItems.length;

  /// 判断指定照片（或其基础名）是否已导出到本地
  bool isExported(String baseName) {
    final clean = _cleanBaseName(baseName);
    return _exportedBaseNames.contains(clean);
  }

  ExportedMediaItem? findExportedItemByExactName(String fileName) => findExportedItem(fileName);

  static bool _sameMedia(String? first,String? second) {
    if(first==second) return true;
    final a=Uri.tryParse(first ?? ''),b=Uri.tryParse(second ?? '');
    if(a==null || b==null || a.scheme!='content' || b.scheme!='content' ||
        a.authority!='media' || b.authority!='media' || a.pathSegments.length<3 || b.pathSegments.length<3) return false;
    // Images/Video/Files 同一卷的同一个 _ID 是同一条媒体记录。
    return a.pathSegments.first==b.pathSegments.first && a.pathSegments.last==b.pathSegments.last;
  }

  /// 有扩展名时只匹配同类型文件；不以 RAW 副本替代 JPG。
  ExportedMediaItem? findExportedItem(String fileName, {String? sourceKey}) {
    final upper = fileName.toUpperCase().trim();
    final candidates = _exportedItems.where((e) => fileName.contains('.')
        ? e.fileName.toUpperCase() == upper : e.baseName == _cleanBaseName(fileName)).toList();
    final uri = sourceKey == null ? null : _sources[sourceKey];
    if (uri != null) {
      for (final item in candidates) { if (_sameMedia(item.mediaUri,uri)) return item; }
      return null;
    }
    return candidates.length == 1 ? candidates.single : null;
  }

  /// 归一化提取文件名主干 (如 DSC_0001.JPG -> DSC_0001)
  static String _cleanBaseName(String name) {
    var s = name;
    final dotIdx = s.lastIndexOf('.');
    if (dotIdx > 0) {
      s = s.substring(0, dotIdx);
    }
    return s.toUpperCase().trim();
  }

  /// 扫描手机系统相册与下载目录，刷新已导出列表
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await _ensureEditedIndexLoaded();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/downloaded_media.json');
      if (await f.exists()) _sources.addAll(Map<String, String>.from(jsonDecode(await f.readAsString()) as Map));
    } catch (_) {}

    final foundItems = <ExportedMediaItem>[];
    final foundBaseNames = <String>{};

    try {
      final targetDirs = <Directory>[
        Directory('/storage/emulated/0/DCIM/Zync'),
        Directory('/storage/emulated/0/Pictures/Zync'),
        Directory('/storage/emulated/0/Movies/Zync'),
        Directory('/storage/emulated/0/Download/Zync'),
      ];

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) targetDirs.add(extDir);
      } catch (_) {}

      try {
        final docDir = await getApplicationDocumentsDirectory();
        targetDirs.add(Directory('${docDir.path}/DCIM/Zync'));
        targetDirs.add(Directory('${docDir.path}/Pictures/Zync'));
        targetDirs.add(docDir);
      } catch (_) {}

      final seenPaths = <String>{};
      final candidateNames = <String>[];

      for (final dir in targetDirs) {
        if (!await dir.exists()) continue;

        try {
          final entries = dir.listSync(followLinks: false);
          for (final entry in entries) {
            if (entry is File) {
              final path = entry.path;
              if (seenPaths.contains(path)) continue;

              final name = entry.uri.pathSegments.last;
              final lower = name.toLowerCase();

              // 支持照片、视频与水印导出图
              if (lower.endsWith('.jpg') ||
                  lower.endsWith('.jpeg') ||
                  lower.endsWith('.png') ||
                  lower.endsWith('.nef') ||
                  lower.endsWith('.nrw') ||
                  lower.endsWith('.mov') ||
                  lower.endsWith('.mp4')) {
                seenPaths.add(path);
                candidateNames.add(name);
                final stat = await entry.stat();
                final base = _cleanBaseName(name);

                foundItems.add(ExportedMediaItem(
                  file: entry,
                  fileName: name,
                  baseName: base,
                  size: stat.size,
                  modifiedTime: stat.modified,
                  isOverwritten: _overwrittenNames.contains(name.toUpperCase()),
                ));
                foundBaseNames.add(base);
              }
            }
          }
        } catch (_) {}
      }

      // MediaStore 是主索引，不依赖 Android 是否允许直接枚举公共路径。
      try {
        final rows = await CameraNativeBridge.listSavedMedia();
        final names = rows.map((e) => (e['name'] as String).toUpperCase()).toSet();
        foundItems.removeWhere((e) => names.contains(e.fileName.toUpperCase()) &&
            e.file.path.startsWith('/storage/'));
        for (final row in rows) {
          final name = row['name'] as String;
          final uri = row['uri'] as String;
          final path = row['path'] as String?;
          foundItems.add(ExportedMediaItem(
            file: File(path?.isNotEmpty == true ? path! : uri),
            fileName: name, baseName: _cleanBaseName(name), size: (row['size'] as num).toInt(),
            modifiedTime: DateTime.fromMillisecondsSinceEpoch((row['modified'] as num).toInt()),
            mediaUri: uri, isOverwritten: _overwrittenNames.contains(name.toUpperCase()),
          ));
        }
      } catch (_) { /* 旧系统/权限受限时保留路径扫描结果。 */ }
      foundBaseNames.clear();
      foundBaseNames.addAll(foundItems.map((e) => e.baseName));

      // 按修改时间降序 (最新的在最前)
      foundItems.sort((a, b) => b.modifiedTime.compareTo(a.modifiedTime));
    } catch (_) {}

    _exportedItems = foundItems;
    _exportedBaseNames.clear();
    _exportedBaseNames.addAll(foundBaseNames);
    _isLoading = false;
    notifyListeners();
  }

  /// 当下载或导出单张新照片时快速注册。mediaUri 为 MediaStore 返回的 Uri/路径。
  void registerExported(String fileName, [File? file, String? mediaUri]) {
    final base = _cleanBaseName(fileName);
    _exportedBaseNames.add(base);
    if (file != null && file.existsSync()) {
      final stat = file.statSync();
      _exportedItems.insert(
        0,
        ExportedMediaItem(
          file: mediaUri != null ? File(mediaUri) : file,
          fileName: fileName,
          baseName: base,
          size: stat.size,
          modifiedTime: stat.modified,
          mediaUri: mediaUri,
          isOverwritten: _overwrittenNames.contains(fileName.toUpperCase()),
        ),
      );
    }
    notifyListeners();
  }

  /// 编辑“覆盖原图”成功后调用：记录角标并刷新对应条目。
  Future<void> markOverwritten(String fileName, File file, String? mediaUri) async {
    final key = fileName.toUpperCase();
    _overwrittenNames.add(key);
    await _saveEditedIndex();
    final index = _exportedItems.indexWhere((e) => e.fileName.toUpperCase() == key &&
        (mediaUri == null || e.mediaUri == mediaUri));
    if (index >= 0) {
      final old = _exportedItems[index];
      final stat = file.existsSync() ? file.statSync() : null;
      _exportedItems[index] = ExportedMediaItem(
        file: File(mediaUri ?? old.mediaUri ?? old.file.path),
        fileName: old.fileName,
        baseName: old.baseName,
        size: stat?.size ?? old.size,
        modifiedTime: stat?.modified ?? DateTime.now(),
        mediaUri: mediaUri ?? old.mediaUri,
        isOverwritten: true,
      );
    }
    notifyListeners();
  }

  /// 编辑“另存为新文件”成功后调用：注册新条目（_edit 后缀即另存）。
  void registerSavedCopy(String fileName, File file, String? mediaUri) {
    registerExported(fileName, file, mediaUri);
  }

  Future<void> _ensureEditedIndexLoaded() async {
    if (_editedIndexLoaded) return;
    _editedIndexLoaded = true;
    try {
      final f = await _editedIndexFile();
      if (!await f.exists()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is List) {
        _overwrittenNames
          ..clear()
          ..addAll(raw.map((e) => e.toString().toUpperCase()));
      }
    } catch (_) {}
  }

  Future<File> _editedIndexFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(dir.path + '/edited_media.json');
  }

  Future<void> _saveEditedIndex() async {
    try {
      final f = await _editedIndexFile();
      await f.writeAsString(jsonEncode(_overwrittenNames.toList()));
    } catch (_) {}
  }

  /// 删除某张已导出照片
  /// 按基础名查找本地已导出的全部文件（RAW+JPG/视频整组删除）。
  List<ExportedMediaItem> findExportedItemsByBaseName(String baseName) {
    final clean = _cleanBaseName(baseName);
    return _exportedItems.where((e) => e.baseName == clean).toList();
  }

  Future<bool> deleteItem(ExportedMediaItem item) async {
    try {
      if (item.mediaUri != null) {
        if (!await CameraNativeBridge.deleteMedia(item.mediaUri!)) return false;
      } else if (await item.file.exists()) { await item.file.delete(); }
      _sources.removeWhere((_, uri) => uri == item.mediaUri);
      _exportedItems.remove(item);
      // 重新评估 baseName 是否还有同组其他文件
      final hasSameBase = _exportedItems.any((e) => e.baseName == item.baseName);
      if (!hasSameBase) {
        _exportedBaseNames.remove(item.baseName);
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
