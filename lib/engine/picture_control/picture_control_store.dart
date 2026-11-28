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

/// 可注入的云端样片字节下载器，便于测试覆盖镜像回退与缓存校验。
typedef SampleDownloadTransport = Future<Uint8List?> Function(Uri uri);

class _RemoteSampleSpec {
  final int revision;
  final String sha256;
  final String fileName;

  const _RemoteSampleSpec({
    required this.revision,
    required this.sha256,
    required this.fileName,
  });
}

/// 手机本地尼康优化校准配方库持久化中心。
class PictureControlStore extends ChangeNotifier {
  static final PictureControlStore instance = PictureControlStore._();

  PictureControlStore._();

  static const String z30FiltersCatalogAsset =
      'assets/recipes/z30_filters/catalog.json';
  static const String _githubSampleBase =
      'https://raw.githubusercontent.com/sa1to-asuka/Zync/main/cloud_assets/pc_preview';
  static const String _jsdelivrSampleBase =
      'https://cdn.jsdelivr.net/gh/sa1to-asuka/Zync@main/cloud_assets/pc_preview';

  @visibleForTesting
  static SampleDownloadTransport? debugSampleTransport;

  final List<PictureControlLibraryItem> _items = [];
  final Set<String> _deletedBuiltinIds = <String>{};
  final Set<String> _favoriteIds = <String>{};
  static final Map<String, Uint8List> _sceneBytesCache = {};
  final Map<String, _RemoteSampleSpec> _remoteSampleSpecs = {};
  final Map<String, Map<String, dynamic>> _localSampleMeta = {};
  int _sampleCacheVersion = 0;
  bool _manifestRefreshedThisRun = false;
  Directory? _storeDir;
  bool _initialized = false;

  List<PictureControlLibraryItem> get items => List.unmodifiable(_items);
  bool get isInitialized => _initialized;
  int get sampleCacheVersion => _sampleCacheVersion;
  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get favoriteCount =>
      _items.where((e) => _favoriteIds.contains(e.id)).length;
  bool isFavorite(String id) => _favoriteIds.contains(id);

  /// 构造云端样片或 manifest 的多镜像候选下载地址。
  static List<Uri> sampleCandidateUrls(String fileName) {
    final clean = fileName.trim();
    if (clean.isEmpty) return const [];
    final raw = '$_githubSampleBase/$clean';
    return [
      Uri.parse(raw),
      Uri.parse('$_jsdelivrSampleBase/$clean'),
      Uri.parse('https://ghfast.top/$raw'),
      Uri.parse('https://gh-proxy.com/$raw'),
    ];
  }

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
    _favoriteIds.clear();
    if (overrideDirectory != null) {
      _sceneBytesCache.clear();
      _remoteSampleSpecs.clear();
      _localSampleMeta.clear();
      _manifestRefreshedThisRun = false;
    }

    final indexFile = File('${_storeDir!.path}/index.json');
    if (indexFile.existsSync()) {
      try {
        final decoded =
            jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
        final deleted = (decoded['deletedBuiltinIds'] as List<dynamic>?)
                ?.whereType<String>() ??
            const <String>[];
        _deletedBuiltinIds.addAll(deleted);
        final favs = (decoded['favoriteIds'] as List<dynamic>?)
                ?.whereType<String>() ??
            const <String>[];
        _favoriteIds.addAll(favs);

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

    await _loadLocalSampleMeta();

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

    // 加载打包自 1dlut-z30-filters 的 121 款社区与影调曲线配方（全部编码为标准 0300 NP3）
    try {
      final catalogJson = await rootBundle.loadString(z30FiltersCatalogAsset);
      final z30Entries = parseZ30FiltersCatalogJson(
        catalogJson,
        seedStartMs: seedTime,
      );
      for (final entry in z30Entries) {
        if (existingIds.contains(entry.id) ||
            _deletedBuiltinIds.contains(entry.id)) {
          continue;
        }
        final binFile = File('${_storeDir!.path}/${entry.fileName}');
        await binFile.writeAsBytes(entry.rawBytes, flush: true);
        _items.add(entry);
        existingIds.add(entry.id);
        seedTime++;
        modified = true;
      }
    } catch (_) {
      // 测试环境未挂载 asset bundle 时静默跳过
    }

    if (modified) {
      await _saveIndex();
    }
    _initialized = true;
    notifyListeners();
    // 异步刷新云端 manifest 并按需预下载 11 张预览样片（仅首次覆盖/版本变更时触发下载）
    if (overrideDirectory == null || debugSampleTransport != null) {
      unawaited(_refreshManifestAndPreload());
    }
  }

  /// 解析 `assets/recipes/z30_filters/catalog.json` 并生成标准 0300 .NP3 配方列表。
  @visibleForTesting
  static List<PictureControlLibraryItem> parseZ30FiltersCatalogJson(
    String catalogJson, {
    int seedStartMs = 0,
  }) {
    final decoded = jsonDecode(catalogJson);
    if (decoded is! Map<String, dynamic>) return const [];
    final rawRecipes = decoded['recipes'];
    if (rawRecipes is! List) return const [];

    final out = <PictureControlLibraryItem>[];
    var ts = seedStartMs;
    for (final raw in rawRecipes.whereType<Map<String, dynamic>>()) {
      final id = (raw['id'] as String? ?? '').trim();
      final camName = Np3Codec.sanitizeCameraName(
        (raw['cameraName'] as String? ?? id),
      );
      if (id.isEmpty) continue;

      final baseName = raw['base'] as String? ?? 'neutral';
      final base = PictureControlBase.values.firstWhere(
        (b) => b.name == baseName,
        orElse: () => PictureControlBase.neutral,
      );
      final catName = raw['category'] as String? ?? 'vintage';
      final category = PictureControlCategory.values.firstWhere(
        (c) => c.name == catName && c != PictureControlCategory.all,
        orElse: () => PictureControlCategory.vintage,
      );

      final rawPts = (raw['pts'] as List<dynamic>?) ?? const [];
      final points = <PictureControlCurvePoint>[];
      for (final p in rawPts) {
        if (p is List && p.length >= 2) {
          points.add(
            PictureControlCurvePoint(
              (p[0] as num).toInt().clamp(0, 255),
              (p[1] as num).toInt().clamp(0, 255),
            ),
          );
        }
      }
      final rawLut = (raw['lut257'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt().clamp(0, 32767))
              .toList() ??
          const <int>[];
      final Uint8List? curveBlock = rawLut.length == 257
          ? Np3Codec.buildCurveBlockFromLut257(
              rawLut,
              controlPoints: points.length >= 2 ? points : null,
            )
          : (points.length >= 2
              ? Np3Codec.buildCurveBlockFromPoints(points)
              : null);
      final hasCurve = curveBlock != null;

      final isMono = base == PictureControlBase.monochrome;
      final tempRecipe = PictureControlRecipe(
        format: PictureControlFormat.np3Standard,
        cameraName: camName,
        base: base,
        sharpeningQuarters: (raw['sharpeningQ'] as num?)?.toInt() ?? 0,
        midRangeSharpeningQuarters:
            (raw['midSharpeningQ'] as num?)?.toInt() ?? 0,
        clarityQuarters: (raw['clarityQ'] as num?)?.toInt() ?? 0,
        contrastQuarters:
            hasCurve ? 0 : ((raw['contrastQ'] as num?)?.toInt() ?? 0),
        brightnessQuarters:
            hasCurve ? 0 : ((raw['brightnessQ'] as num?)?.toInt() ?? 0),
        saturationQuarters:
            isMono ? null : ((raw['saturationQ'] as num?)?.toInt() ?? 0),
        hueQuarters: isMono ? null : ((raw['hueQ'] as num?)?.toInt() ?? 0),
        hasCustomCurve: hasCurve,
        curvePoints: points,
        rawCurveBlock: curveBlock,
      );

      final bytes = Np3Codec.encodeNp3File(tempRecipe);
      final parsed = Np3Codec.parse(bytes);
      out.add(
        PictureControlLibraryItem(
          id: id,
          fileName: '$id.NP3',
          cameraName: parsed.cameraName,
          noteName: (raw['noteNameZh'] as String? ?? camName).trim(),
          description: (raw['descriptionZh'] as String? ?? '').trim(),
          recommendedSceneId:
              (raw['recommendedSceneId'] as String? ?? 'street').trim(),
          category: category,
          isBuiltIn: true,
          importedAtMs: ts++,
          recipe: parsed,
          rawBytes: bytes,
        ),
      );
    }
    return out;
  }

  /// 切换指定配方的收藏状态并持久化。
  Future<bool> toggleFavorite(String id) async {
    await ensureInitialized();
    final bool nowFavorite;
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
      nowFavorite = false;
    } else {
      _favoriteIds.add(id);
      nowFavorite = true;
    }
    await _saveIndex();
    notifyListeners();
    return nowFavorite;
  }

  /// 恢复所有被删除的内置经典初始配方。
  Future<void> restoreBuiltInSeeds() async {
    await ensureInitialized();
    _deletedBuiltinIds.clear();
    await _saveIndex();
    _initialized = false;
    await ensureInitialized(overrideDirectory: _storeDir?.parent);
  }

  Future<void> _loadLocalSampleMeta() async {
    _localSampleMeta.clear();
    if (_storeDir == null) return;
    final metaFile = File('${_storeDir!.path}/samples/samples_meta.json');
    if (!metaFile.existsSync()) return;
    try {
      final decoded = jsonDecode(await metaFile.readAsString());
      if (decoded is Map<String, dynamic>) {
        final scenes = decoded['scenes'];
        if (scenes is Map<String, dynamic>) {
          for (final entry in scenes.entries) {
            if (entry.value is Map<String, dynamic>) {
              _localSampleMeta[entry.key] =
                  Map<String, dynamic>.from(entry.value as Map);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveLocalSampleMeta() async {
    if (_storeDir == null) return;
    final sampleDir = Directory('${_storeDir!.path}/samples');
    if (!sampleDir.existsSync()) {
      sampleDir.createSync(recursive: true);
    }
    final metaFile = File('${sampleDir.path}/samples_meta.json');
    await metaFile.writeAsString(
      jsonEncode({'version': 2, 'scenes': _localSampleMeta}),
      flush: true,
    );
  }

  /// 静默拉取 GitHub 云端样片清单：如远端版本号或 SHA-256 更新，自动清理旧缓存并通知界面刷新。
  Future<void> refreshSampleManifestInBackground({bool force = false}) async {
    if (_manifestRefreshedThisRun && !force) return;
    _manifestRefreshedThisRun = true;
    await ensureInitialized();

    Uint8List? rawManifest;
    for (final uri in sampleCandidateUrls('manifest.json')) {
      rawManifest = await _downloadUrlBytes(uri, timeoutSeconds: 6);
      if (rawManifest != null && rawManifest.isNotEmpty) break;
    }
    if (rawManifest == null || rawManifest.isEmpty) return;

    try {
      final decoded = jsonDecode(utf8.decode(rawManifest));
      if (decoded is! Map<String, dynamic>) return;
      final list = decoded['scenes'];
      if (list is! List) return;

      var invalidatedAny = false;
      final sampleDir = Directory('${_storeDir!.path}/samples');

      for (final raw in list.whereType<Map<String, dynamic>>()) {
        final id = (raw['id'] as String? ?? '').trim();
        if (id.isEmpty) continue;
        final rev = (raw['revision'] as num?)?.toInt() ?? 1;
        final sha = (raw['sha256'] as String? ?? '').trim().toLowerCase();
        final fileName = (raw['fileName'] as String? ?? '$id.jpg').trim();

        _remoteSampleSpecs[id] = _RemoteSampleSpec(
          revision: rev,
          sha256: sha,
          fileName: fileName,
        );

        final localMeta = _localSampleMeta[id];
        final localRev = (localMeta?['revision'] as num?)?.toInt() ?? 0;
        final localSha =
            (localMeta?['sha256'] as String? ?? '').trim().toLowerCase();
        final cachedFile = File('${sampleDir.path}/$id.jpg');

        final revOutdated = rev > localRev;
        final shaChanged = sha.isNotEmpty && localSha != sha;
        if (cachedFile.existsSync() &&
            (localMeta == null || revOutdated || shaChanged)) {
          try {
            cachedFile.deleteSync();
          } catch (_) {}
          _localSampleMeta.remove(id);
          _sceneBytesCache.remove(id);
          invalidatedAny = true;
        }
      }

      if (invalidatedAny) {
        await _saveLocalSampleMeta();
        _sampleCacheVersion++;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _refreshManifestAndPreload() async {
    await refreshSampleManifestInBackground();
    await preloadAllSampleScenes();
  }

  /// 加载预览样片原始字节（内存缓存 > 版本/哈希匹配沙盒缓存 > GitHub 多镜像云端下载，不随包内嵌）。
  Future<Uint8List?> loadSampleSceneBytes(
    PictureControlSampleScene scene, {
    bool forceRefresh = false,
  }) async {
    await ensureInitialized();
    final remoteSpec = _remoteSampleSpecs[scene.id];
    final targetRev = (remoteSpec != null && remoteSpec.revision > scene.revision)
        ? remoteSpec.revision
        : scene.revision;
    final targetSha = (remoteSpec != null && remoteSpec.sha256.isNotEmpty)
        ? remoteSpec.sha256
        : scene.sha256.trim().toLowerCase();
    final targetFileName =
        (remoteSpec != null && remoteSpec.fileName.isNotEmpty)
            ? remoteSpec.fileName
            : scene.fileName;

    final sampleDir = Directory('${_storeDir!.path}/samples');
    if (!sampleDir.existsSync()) {
      sampleDir.createSync(recursive: true);
    }
    final cachedFile = File('${sampleDir.path}/${scene.id}.jpg');

    if (!forceRefresh) {
      final inMem = _sceneBytesCache[scene.id];
      final localMeta = _localSampleMeta[scene.id];
      if (inMem != null &&
          inMem.isNotEmpty &&
          _isMetaValid(localMeta, targetRev, targetSha)) {
        return inMem;
      }

      if (cachedFile.existsSync()) {
        try {
          if (_isMetaValid(localMeta, targetRev, targetSha) &&
              cachedFile.lengthSync() > 8 * 1024) {
            final bytes = await cachedFile.readAsBytes();
            if (_looksLikeValidSampleImage(bytes) &&
                (targetSha.isEmpty ||
                    sha256.convert(bytes).toString().toLowerCase() ==
                        targetSha)) {
              _sceneBytesCache[scene.id] = bytes;
              return bytes;
            }
          }
          // 旧版本（如 v3.0.x 无 samples_meta）或版本/SHA 不匹配：强制淘汰旧缓存！
          try {
            cachedFile.deleteSync();
          } catch (_) {}
          _localSampleMeta.remove(scene.id);
          _sceneBytesCache.remove(scene.id);
        } catch (_) {}
      }
    } else {
      try {
        if (cachedFile.existsSync()) cachedFile.deleteSync();
      } catch (_) {}
      _localSampleMeta.remove(scene.id);
      _sceneBytesCache.remove(scene.id);
    }

    for (final uri in sampleCandidateUrls(targetFileName)) {
      final downloaded = await _downloadUrlBytes(uri, timeoutSeconds: 12);
      if (downloaded == null || !_looksLikeValidSampleImage(downloaded)) {
        continue;
      }
      final actualSha = sha256.convert(downloaded).toString().toLowerCase();
      if (targetSha.isNotEmpty && actualSha != targetSha) {
        continue;
      }
      try {
        final tmpFile = File('${cachedFile.path}.tmp');
        await tmpFile.writeAsBytes(downloaded, flush: true);
        await tmpFile.rename(cachedFile.path);
        _localSampleMeta[scene.id] = {
          'revision': targetRev,
          'sha256': actualSha,
          'fileName': targetFileName,
        };
        await _saveLocalSampleMeta();
      } catch (_) {}
      _sceneBytesCache[scene.id] = downloaded;
      _sampleCacheVersion++;
      notifyListeners();
      return downloaded;
    }

    return null;
  }

  static bool _isMetaValid(
    Map<String, dynamic>? meta,
    int targetRev,
    String targetSha,
  ) {
    if (meta == null) return false;
    final metaRev = (meta['revision'] as num?)?.toInt() ?? 0;
    if (metaRev < targetRev) return false;
    if (targetSha.isNotEmpty) {
      final metaSha = (meta['sha256'] as String? ?? '').trim().toLowerCase();
      if (metaSha != targetSha) return false;
    }
    return true;
  }

  static bool _looksLikeValidSampleImage(Uint8List bytes) {
    if (bytes.length < 8 * 1024) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    return false;
  }

  static Future<Uint8List?> _downloadUrlBytes(
    Uri uri, {
    int timeoutSeconds = 10,
  }) async {
    if (debugSampleTransport != null) {
      try {
        return await debugSampleTransport!(uri);
      } catch (_) {
        return null;
      }
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 1);
    try {
      final request = await client.getUrl(uri);
      final response =
          await request.close().timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      return builder.toBytes();
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// 后台异步静默预下载并持久化全部 11 张高清云端样片在手机沙盒中。
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
    _favoriteIds.remove(removed.id);
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
      'version': 2,
      'deletedBuiltinIds': _deletedBuiltinIds.toList(),
      'favoriteIds': _favoriteIds.toList(),
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
