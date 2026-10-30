import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'builtin_np3_recipes.dart';
import 'np3_codec.dart';

/// 本地配方库单条记录。
class PictureControlLibraryItem {
  final String id;
  final String fileName;
  final String cameraName;
  final String noteName;
  final String description;
  final String recommendedSceneId;
  final PictureControlCategory category;
  final String? customCoverPath;
  final bool isBuiltIn;
  final int importedAtMs;
  final PictureControlRecipe recipe;
  final Uint8List rawBytes;

  const PictureControlLibraryItem({
    required this.id,
    required this.fileName,
    required this.cameraName,
    required this.noteName,
    this.description = '',
    this.recommendedSceneId = 'street',
    this.category = PictureControlCategory.all,
    this.customCoverPath,
    this.isBuiltIn = false,
    required this.importedAtMs,
    required this.recipe,
    required this.rawBytes,
  });

  String get displayTitle => noteName.trim().isNotEmpty ? noteName : cameraName;
  bool get isFlexibleColor => recipe.isFlexibleColor;

  Map<String, dynamic> toIndexJson() => {
        'id': id,
        'fileName': fileName,
        'cameraName': cameraName,
        'noteName': noteName,
        'description': description,
        'recommendedSceneId': recommendedSceneId,
        'category': category.name,
        'customCoverPath': customCoverPath,
        'isBuiltIn': isBuiltIn,
        'importedAtMs': importedAtMs,
      };
}

/// 导入批次结果统计。
class PictureControlImportReport {
  final int importedCount;
  final int duplicateCount;
  final int invalidCount;
  final List<PictureControlLibraryItem> addedItems;

  const PictureControlImportReport({
    this.importedCount = 0,
    this.duplicateCount = 0,
    this.invalidCount = 0,
    this.addedItems = const [],
  });
}

/// 手机本地尼康优化校准配方库持久化中心。
class PictureControlStore extends ChangeNotifier {
  static final PictureControlStore instance = PictureControlStore._();

  PictureControlStore._();

  final List<PictureControlLibraryItem> _items = [];
  final Set<String> _deletedBuiltinIds = <String>{};
  static final Map<String, Uint8List> _sceneBytesCache = {};
  Directory? _storeDir;
  bool _initialized = false;

  List<PictureControlLibraryItem> get items => List.unmodifiable(_items);
  bool get isInitialized => _initialized;

  /// 初始化本地配方库目录并加载已保存配方与内置经典初始配方。
  Future<void> ensureInitialized({Directory? overrideDirectory}) async {
    if (_initialized && overrideDirectory == null) return;
    final baseDir = overrideDirectory ?? await getApplicationDocumentsDirectory();
    _storeDir = Directory('${baseDir.path}/picture_controls');
    if (!_storeDir!.existsSync()) {
      _storeDir!.createSync(recursive: true);
    }

    _items.clear();
    _deletedBuiltinIds.clear();

    final indexFile = File('${_storeDir!.path}/index.json');
    if (indexFile.existsSync()) {
      try {
        final decoded =
            jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
        final deleted = (decoded['deletedBuiltinIds'] as List<dynamic>?)
                ?.whereType<String>() ??
            const <String>[];
        _deletedBuiltinIds.addAll(deleted);

        final rawList = (decoded['items'] as List<dynamic>?) ?? const [];
        for (final entry in rawList.whereType<Map<String, dynamic>>()) {
          final fileName = (entry['fileName'] as String?) ?? '';
          if (fileName.isEmpty) continue;
          final binFile = File('${_storeDir!.path}/$fileName');
          if (!binFile.existsSync()) continue;
          try {
            final bytes = await binFile.readAsBytes();
            final recipe = Np3Codec.parse(bytes);
            final catStr = entry['category'] as String?;
            final category = PictureControlCategory.values.firstWhere(
              (c) => c.name == catStr,
              orElse: () => PictureControlCategory.all,
            );
            _items.add(PictureControlLibraryItem(
              id: (entry['id'] as String?) ?? _hashBytes(bytes),
              fileName: fileName,
              cameraName: recipe.cameraName,
              noteName: (entry['noteName'] as String?) ?? '',
              description: (entry['description'] as String?) ?? '',
              recommendedSceneId:
                  (entry['recommendedSceneId'] as String?) ?? 'street',
              category: category,
              customCoverPath: entry['customCoverPath'] as String?,
              isBuiltIn: (entry['isBuiltIn'] as bool?) ?? false,
              importedAtMs: (entry['importedAtMs'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
              recipe: recipe,
              rawBytes: bytes,
            ));
          } catch (_) {
            // 忽略损坏文件
          }
        }
      } catch (_) {}
    }

    // 注入尚未安装且未被用户手动删除的内置初始配方
    var modified = false;
    final existingIds = _items.map((e) => e.id).toSet();
    var seedTime = DateTime.now().millisecondsSinceEpoch;
    for (final seed in BuiltinNp3Catalog.seeds) {
      if (existingIds.contains(seed.id) ||
          _deletedBuiltinIds.contains(seed.id)) {
        continue;
      }
      final fileName = '${seed.id}.NP3';
      final binFile = File('${_storeDir!.path}/$fileName');
      await binFile.writeAsBytes(seed.np3Bytes, flush: true);
      _items.add(PictureControlLibraryItem(
        id: seed.id,
        fileName: fileName,
        cameraName: seed.cameraName,
        noteName: seed.noteNameZh,
        description: seed.descriptionZh,
        recommendedSceneId: seed.recommendedSceneId,
        category: seed.category,
        isBuiltIn: true,
        importedAtMs: seedTime++,
        recipe: seed.recipe,
        rawBytes: seed.np3Bytes,
      ));
      existingIds.add(seed.id);
      modified = true;
    }

    // 加载打包自 Timor88/NikonNP3 的 32 款社区云创 NP3 配方
    for (final tSeed in BuiltinNp3Catalog.timor88Seeds) {
      if (existingIds.contains(tSeed.id) ||
          _deletedBuiltinIds.contains(tSeed.id)) {
        continue;
      }
      try {
        final byteData = await rootBundle.load(tSeed.assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final parsed = Np3Codec.parse(bytes);
        final fileName = '${tSeed.id}.NP3';
        final binFile = File('${_storeDir!.path}/$fileName');
        await binFile.writeAsBytes(bytes, flush: true);
        _items.add(PictureControlLibraryItem(
          id: tSeed.id,
          fileName: fileName,
          cameraName: parsed.cameraName,
          noteName: tSeed.noteNameZh,
          description: tSeed.descriptionZh,
          recommendedSceneId: tSeed.recommendedSceneId,
          category: tSeed.category,
          isBuiltIn: true,
          importedAtMs: seedTime++,
          recipe: parsed,
          rawBytes: bytes,
        ));
        existingIds.add(tSeed.id);
        modified = true;
      } catch (_) {
        // 测试环境未挂载 asset bundle 时静默跳过
      }
    }

    // 加载打包自尼康官方创作者与 Color Grading 的 47 款精选 NP3 配方
    for (final cSeed in BuiltinNp3Catalog.creatorSeeds) {
      if (existingIds.contains(cSeed.id) ||
          _deletedBuiltinIds.contains(cSeed.id)) {
        continue;
      }
      try {
        final byteData = await rootBundle.load(cSeed.assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final parsed = Np3Codec.parse(bytes);
        final fileName = '${cSeed.id}.NP3';
        final binFile = File('${_storeDir!.path}/$fileName');
        await binFile.writeAsBytes(bytes, flush: true);
        _items.add(PictureControlLibraryItem(
          id: cSeed.id,
          fileName: fileName,
          cameraName: parsed.cameraName,
          noteName: cSeed.noteNameZh,
          description: cSeed.descriptionZh,
          recommendedSceneId: cSeed.recommendedSceneId,
          category: cSeed.category,
          isBuiltIn: true,
          importedAtMs: seedTime++,
          recipe: parsed,
          rawBytes: bytes,
        ));
        existingIds.add(cSeed.id);
        modified = true;
      } catch (_) {
        // 测试环境未挂载 asset bundle 时静默跳过
      }
    }

    if (modified) {
      await _saveIndex();
    }
    _initialized = true;
    notifyListeners();
    // 异步静默预载并永久留存 8 张高清对比样片至手机，下次秒开不请求网络
    unawaited(preloadAllSampleScenes());
  }

  /// 恢复所有被删除的内置经典初始配方。
  Future<void> restoreBuiltInSeeds() async {
    await ensureInitialized();
    _deletedBuiltinIds.clear();
    await _saveIndex();
    _initialized = false;
    await ensureInitialized(overrideDirectory: _storeDir?.parent);
  }

  /// 加载预览样片原始字节（内存缓存 > 手机本地沙盒持久化高精原图 > PicUI 远程下载并永久留存手机 > 内置 asset 兜底）。
  Future<Uint8List?> loadSampleSceneBytes(PictureControlSampleScene scene) async {
    final inMem = _sceneBytesCache[scene.id];
    if (inMem != null && inMem.isNotEmpty) return inMem;

    await ensureInitialized();
    final sampleDir = Directory('${_storeDir!.path}/samples');
    if (!sampleDir.existsSync()) {
      sampleDir.createSync(recursive: true);
    }
    final cachedFile = File('${sampleDir.path}/${scene.id}.jpg');
    if (cachedFile.existsSync()) {
      try {
        final length = cachedFile.lengthSync();
        // 需大于 50KB（避免旧版 600px 小图或截断脏缓存）
        if (length > 50 * 1024) {
          final bytes = await cachedFile.readAsBytes();
          if (bytes.isNotEmpty) {
            _sceneBytesCache[scene.id] = bytes;
            return bytes;
          }
        } else {
          try {
            cachedFile.deleteSync();
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (scene.remoteUrl != null && scene.remoteUrl!.isNotEmpty) {
      try {
        final uri = Uri.parse(scene.remoteUrl!);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final bytesBuilder = BytesBuilder();
          await for (final chunk in response) {
            bytesBuilder.add(chunk);
          }
          final bytes = bytesBuilder.toBytes();
          if (bytes.isNotEmpty && bytes.length > 50 * 1024) {
            await cachedFile.writeAsBytes(bytes, flush: true);
            _sceneBytesCache[scene.id] = bytes;
            return bytes;
          }
        }
      } catch (_) {}
    }

    // 离线或下载超时，回退至内置轻量级 Asset
    try {
      final bd = await rootBundle.load(scene.assetPath);
      final fallback = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
      if (fallback.isNotEmpty) {
        _sceneBytesCache[scene.id] = fallback;
      }
      return fallback;
    } catch (_) {
      return null;
    }
  }

  /// 后台异步静默预下载并永久留存全部 8 张高清样片在手机沙盒中。
  Future<void> preloadAllSampleScenes() async {
    for (final scene in BuiltinNp3Catalog.sampleScenes) {
      try {
        await loadSampleSceneBytes(scene);
      } catch (_) {}
    }
  }

  /// 从本地文件路径列表导入（支持 .NP3 / .NCP 以及包含配方的 .ZIP 压缩包）。
  Future<PictureControlImportReport> importFromPaths(
    List<String> paths,
  ) async {
    await ensureInitialized();
    var imported = 0;
    var duplicates = 0;
    var invalid = 0;
    final added = <PictureControlLibraryItem>[];

    for (final path in paths) {
      final f = File(path);
      if (!f.existsSync()) {
        invalid++;
        continue;
      }
      final lower = path.toLowerCase();
      try {
        final bytes = await f.readAsBytes();
        if (lower.endsWith('.zip') || _looksLikeZip(bytes)) {
          final zipReport = await importZipBytes(bytes);
          imported += zipReport.importedCount;
          duplicates += zipReport.duplicateCount;
          invalid += zipReport.invalidCount;
          added.addAll(zipReport.addedItems);
        } else {
          final baseName = _extractBaseTitle(path);
          final res = await _importSingleRawBytes(
            bytes,
            suggestedNoteName: baseName,
            extensionHint: lower.endsWith('.ncp') ? 'NCP' : 'NP3',
          );
          if (res.status == _SingleImportStatus.added && res.item != null) {
            imported++;
            added.add(res.item!);
          } else if (res.status == _SingleImportStatus.duplicate) {
            duplicates++;
          } else {
            invalid++;
          }
        }
      } catch (_) {
        invalid++;
      }
    }

    if (imported > 0) {
      await _saveIndex();
      notifyListeners();
    }
    return PictureControlImportReport(
      importedCount: imported,
      duplicateCount: duplicates,
      invalidCount: invalid,
      addedItems: added,
    );
  }

  /// 解析并导入 ZIP 压缩包字节流中的所有 .NP3 / .NCP 文件。
  Future<PictureControlImportReport> importZipBytes(Uint8List zipBytes) async {
    await ensureInitialized();
    var imported = 0;
    var duplicates = 0;
    var invalid = 0;
    final added = <PictureControlLibraryItem>[];

    try {
      final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = file.name;
        if (name.contains('__MACOSX') || name.startsWith('.')) continue;
        final lower = name.toLowerCase();
        if (!lower.endsWith('.np3') && !lower.endsWith('.ncp')) continue;
        final content = file.content as List<int>;
        if (content.isEmpty || content.length > Np3Codec.maxFileSizeBytes) {
          invalid++;
          continue;
        }
        final raw = Uint8List.fromList(content);
        final noteHint = _extractBaseTitle(name);
        final res = await _importSingleRawBytes(
          raw,
          suggestedNoteName: noteHint,
          extensionHint: lower.endsWith('.ncp') ? 'NCP' : 'NP3',
        );
        if (res.status == _SingleImportStatus.added && res.item != null) {
          imported++;
          added.add(res.item!);
        } else if (res.status == _SingleImportStatus.duplicate) {
          duplicates++;
        } else {
          invalid++;
        }
      }
    } catch (_) {
      invalid++;
    }

    if (imported > 0) {
      await _saveIndex();
      notifyListeners();
    }
    return PictureControlImportReport(
      importedCount: imported,
      duplicateCount: duplicates,
      invalidCount: invalid,
      addedItems: added,
    );
  }

  /// 直接导入单份二进制配方字节（例如从相机 C1–C9 读回备份）。
  Future<PictureControlLibraryItem?> importRawBytes(
    Uint8List bytes, {
    String noteName = '',
    String description = '',
  }) async {
    await ensureInitialized();
    final res = await _importSingleRawBytes(
      bytes,
      suggestedNoteName: noteName,
      description: description,
      extensionHint: 'NP3',
    );
    if (res.item != null) {
      await _saveIndex();
      notifyListeners();
      return res.item;
    }
    // 若已存在相同哈希项，直接返回已有项
    final id = _hashBytes(bytes);
    for (final existing in _items) {
      if (existing.id == id) return existing;
    }
    return null;
  }

  /// 双名称重命名：
  /// - [newCameraName] 写入 .NP3 / .NCP 文件内嵌 0x200 记录（ASCII 最多 19 字符，相机菜单显示）。
  /// - [newNoteName] 保存在本地索引（支持中文/日文/备注）。
  Future<PictureControlLibraryItem?> renameItem({
    required String id,
    required String newCameraName,
    required String newNoteName,
  }) async {
    await ensureInitialized();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return null;

    final old = _items[idx];
    final cleanCamera = Np3Codec.sanitizeCameraName(newCameraName);
    final updatedBytes = Np3Codec.rewriteCameraName(old.rawBytes, cleanCamera);
    final updatedRecipe = Np3Codec.parse(updatedBytes);

    final binFile = File('${_storeDir!.path}/${old.fileName}');
    await binFile.writeAsBytes(updatedBytes, flush: true);

    final updated = PictureControlLibraryItem(
      id: old.id,
      fileName: old.fileName,
      cameraName: updatedRecipe.cameraName,
      noteName: newNoteName.trim(),
      description: old.description,
      recommendedSceneId: old.recommendedSceneId,
      category: old.category,
      customCoverPath: old.customCoverPath,
      isBuiltIn: old.isBuiltIn,
      importedAtMs: old.importedAtMs,
      recipe: updatedRecipe,
      rawBytes: updatedBytes,
    );
    _items[idx] = updated;
    await _saveIndex();
    notifyListeners();
    return updated;
  }

  /// 为配方设置或清除自定义封面图。
  Future<void> setCustomCoverPath(String id, String? coverPath) async {
    await ensureInitialized();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final old = _items[idx];
    _items[idx] = PictureControlLibraryItem(
      id: old.id,
      fileName: old.fileName,
      cameraName: old.cameraName,
      noteName: old.noteName,
      description: old.description,
      recommendedSceneId: old.recommendedSceneId,
      category: old.category,
      customCoverPath: coverPath,
      isBuiltIn: old.isBuiltIn,
      importedAtMs: old.importedAtMs,
      recipe: old.recipe,
      rawBytes: old.rawBytes,
    );
    await _saveIndex();
    notifyListeners();
  }

  /// 删除本地库中的配方。
  Future<void> deleteItem(String id) async {
    await ensureInitialized();
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final removed = _items.removeAt(idx);
    if (removed.isBuiltIn) {
      _deletedBuiltinIds.add(removed.id);
    }
    final binFile = File('${_storeDir!.path}/${removed.fileName}');
    if (binFile.existsSync()) {
      try {
        await binFile.delete();
      } catch (_) {}
    }
    await _saveIndex();
    notifyListeners();
  }

  /// 将一条 Flexible Color (0310) 配方拟合转换为可写入 C1–C9 的标准 (0300) NP3 配方并加入本地库。
  Future<PictureControlLibraryItem?> convertFlexibleItemToStandard(
    PictureControlLibraryItem source,
  ) async {
    await ensureInitialized();
    final stdBytes = Np3Codec.convertFlexibleToStandardNp3Bytes(
      source.recipe,
      overrideCameraName: source.cameraName,
    );
    final note = source.noteName.isNotEmpty
        ? '${source.noteName} (标准适配)'
        : '${source.cameraName} (标准适配)';
    return importRawBytes(
      stdBytes,
      noteName: note,
      description: source.description,
    );
  }

  /// 将配方导出为带可读文件名的临时文件，供系统分享面板发送。
  Future<File> exportFileForSharing(PictureControlLibraryItem item) async {
    await ensureInitialized();
    final exportDir = Directory('${_storeDir!.path}/shared');
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }
    final ext = item.recipe.format == PictureControlFormat.ncpLegacy
        ? 'NCP'
        : 'NP3';
    final safeBase = item.cameraName
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final out = File('${exportDir.path}/${safeBase.isEmpty ? "RECIPE" : safeBase}.$ext');
    await out.writeAsBytes(item.rawBytes, flush: true);
    return out;
  }

  Future<_SingleImportResult> _importSingleRawBytes(
    Uint8List bytes, {
    String suggestedNoteName = '',
    String description = '',
    String extensionHint = 'NP3',
  }) async {
    try {
      final recipe = Np3Codec.parse(bytes);
      final id = _hashBytes(bytes);
      if (_items.any((e) => e.id == id)) {
        return const _SingleImportResult(_SingleImportStatus.duplicate);
      }
      final ext = recipe.format == PictureControlFormat.ncpLegacy
          ? 'NCP'
          : extensionHint;
      final fileName = '$id.$ext';
      final binFile = File('${_storeDir!.path}/$fileName');
      await binFile.writeAsBytes(bytes, flush: true);

      final cleanNote = suggestedNoteName.trim();
      final item = PictureControlLibraryItem(
        id: id,
        fileName: fileName,
        cameraName: recipe.cameraName,
        noteName: cleanNote.toUpperCase() == recipe.cameraName.toUpperCase()
            ? ''
            : cleanNote,
        description: description,
        recommendedSceneId: _guessRecommendedScene(recipe),
        category: _guessCategory(recipe),
        isBuiltIn: false,
        importedAtMs: DateTime.now().millisecondsSinceEpoch,
        recipe: recipe,
        rawBytes: bytes,
      );
      _items.insert(0, item);
      return _SingleImportResult(_SingleImportStatus.added, item: item);
    } catch (_) {
      return const _SingleImportResult(_SingleImportStatus.invalid);
    }
  }

  static PictureControlCategory _guessCategory(PictureControlRecipe recipe) {
    switch (recipe.base) {
      case PictureControlBase.portrait:
        return PictureControlCategory.portrait;
      case PictureControlBase.landscape:
        return PictureControlCategory.landscape;
      case PictureControlBase.vivid:
        return PictureControlCategory.night;
      case PictureControlBase.monochrome:
        return PictureControlCategory.mono;
      default:
        return PictureControlCategory.street;
    }
  }

  static String _guessRecommendedScene(PictureControlRecipe recipe) {
    switch (recipe.base) {
      case PictureControlBase.portrait:
        return 'portrait';
      case PictureControlBase.landscape:
        return 'landscape';
      case PictureControlBase.vivid:
        return 'night';
      case PictureControlBase.monochrome:
        return 'street';
      default:
        return 'street';
    }
  }

  static bool _looksLikeZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  static String _extractBaseTitle(String pathOrName) {
    final normalized = pathOrName.replaceAll('\\', '/');
    final last = normalized.split('/').last;
    final dot = last.lastIndexOf('.');
    return dot > 0 ? last.substring(0, dot).trim() : last.trim();
  }

  static String _hashBytes(Uint8List bytes) =>
      sha256.convert(bytes).toString().substring(0, 16);

  Future<void> _saveIndex() async {
    if (_storeDir == null) return;
    final indexFile = File('${_storeDir!.path}/index.json');
    final data = {
      'version': 1,
      'deletedBuiltinIds': _deletedBuiltinIds.toList(),
      'items': _items.map((e) => e.toIndexJson()).toList(),
    };
    await indexFile.writeAsString(jsonEncode(data), flush: true);
  }
}

enum _SingleImportStatus { added, duplicate, invalid }

class _SingleImportResult {
  final _SingleImportStatus status;
  final PictureControlLibraryItem? item;

  const _SingleImportResult(this.status, {this.item});
}
