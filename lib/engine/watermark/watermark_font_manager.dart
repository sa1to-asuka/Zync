import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 字体来源类型。
enum WatermarkFontSource {
  system,
  bundledAsset,
  cloudStore,
  localImport,
}

/// 字体定义（系统、内置轻量英文字体、GitHub 云端开源字体、本地导入字体）。
class WatermarkFontEntry {
  final String id;
  final String? family;
  final String displayName;
  final String category;
  final String previewSample;
  final String license;
  final String sourceUrl;
  final WatermarkFontSource source;
  final String? fileName;
  final int sizeBytes;
  final String sha256;
  final String downloadUrl;

  const WatermarkFontEntry({
    required this.id,
    required this.family,
    required this.displayName,
    required this.category,
    this.previewSample = 'NIKON Z · 光影纪实',
    this.license = 'SIL OFL-1.1',
    this.sourceUrl = '',
    required this.source,
    this.fileName,
    this.sizeBytes = 0,
    this.sha256 = '',
    this.downloadUrl = '',
  });

  factory WatermarkFontEntry.fromManifestJson(Map<String, dynamic> json) =>
      WatermarkFontEntry(
        id: json['id'] as String? ?? '',
        family: json['family'] as String?,
        displayName: json['displayName'] as String? ??
            (json['id'] as String? ?? 'Unknown'),
        category: json['category'] as String? ?? 'chinese_art',
        previewSample: json['previewSample'] as String? ?? '光影纪实 · NIKON Z',
        license: json['license'] as String? ?? 'SIL OFL-1.1',
        sourceUrl: json['sourceUrl'] as String? ?? '',
        source: WatermarkFontSource.cloudStore,
        fileName: json['fileName'] as String?,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        sha256: (json['sha256'] as String? ?? '').toLowerCase(),
        downloadUrl: json['downloadUrl'] as String? ?? '',
      );

  Map<String, dynamic> toLocalIndexJson() => {
        'id': id,
        'family': family,
        'displayName': displayName,
        'category': category,
        'previewSample': previewSample,
        'license': license,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
      };
}

/// 可注入的字节下载器接口，便于单元测试脱离真实网络。
typedef FontDownloadTransport = Future<Uint8List> Function(
  Uri url, {
  void Function(int received, int total)? onProgress,
});

/// 水印与艺术字字体管理中心（APK 瘦身 + `sa1to-asuka/Zync` `fonts-v1` 云端开源商店 + 本地导入）。
class WatermarkFontManager extends ChangeNotifier {
  WatermarkFontManager._();
  static final WatermarkFontManager instance = WatermarkFontManager._();

  static const String manifestUrl =
      'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/manifest.json';

  static List<Uri> candidateUrlsFor(String directUrl) {
    final clean = directUrl.trim();
    if (clean.isEmpty) return const [];
    final list = <Uri>[];
    final primary = Uri.tryParse(clean);
    if (primary != null) list.add(primary);
    if (clean.startsWith('https://github.com/')) {
      final ghfast = Uri.tryParse('https://ghfast.top/$clean');
      if (ghfast != null) list.add(ghfast);
      final ghproxy = Uri.tryParse('https://gh-proxy.com/$clean');
      if (ghproxy != null) list.add(ghproxy);
    }
    return list;
  }

  /// 系统与随 APK 内置的超轻量英文 OFL-1.1 艺术字体（共约 1MB）。
  static const List<WatermarkFontEntry> builtinEntries = [
    WatermarkFontEntry(
      id: 'default',
      family: null,
      displayName: '系统默认',
      category: 'system',
      previewSample: 'NIKON Z · 光影纪实',
      license: 'System',
      source: WatermarkFontSource.system,
    ),
    WatermarkFontEntry(
      id: 'serif',
      family: 'serif',
      displayName: '经典衬线 Serif',
      category: 'system',
      previewSample: 'Gallery Edition 1979',
      license: 'System',
      source: WatermarkFontSource.system,
    ),
    WatermarkFontEntry(
      id: 'mono',
      family: 'monospace',
      displayName: '等宽参数 Mono',
      category: 'system',
      previewSample: '50mm f/1.4 1/500s ISO100',
      license: 'System',
      source: WatermarkFontSource.system,
    ),
    WatermarkFontEntry(
      id: 'condensed',
      family: 'sans-serif-condensed',
      displayName: '窄体海报 Condensed',
      category: 'system',
      previewSample: 'ARCHITECTURAL FRAME',
      license: 'System',
      source: WatermarkFontSource.system,
    ),
    WatermarkFontEntry(
      id: 'playfair',
      family: 'ZyncPlayfair',
      displayName: 'Playfair 杂志衬线',
      category: 'english_art',
      previewSample: 'La Lumière · Editorial',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/google/fonts/tree/main/ofl/playfairdisplay',
      source: WatermarkFontSource.bundledAsset,
    ),
    WatermarkFontEntry(
      id: 'cinzel',
      family: 'ZyncCinzel',
      displayName: 'Cinzel 电影碑铭',
      category: 'english_art',
      previewSample: 'CINEMA ARCHIVE XXIV',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/google/fonts/tree/main/ofl/cinzel',
      source: WatermarkFontSource.bundledAsset,
    ),
    WatermarkFontEntry(
      id: 'caveat',
      family: 'ZyncCaveat',
      displayName: 'Caveat 手写签名',
      category: 'english_art',
      previewSample: 'Shot on Nikon Z · Memory',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/google/fonts/tree/main/ofl/caveat',
      source: WatermarkFontSource.bundledAsset,
    ),
    WatermarkFontEntry(
      id: 'jetbrains_mono',
      family: 'ZyncJetBrainsMono',
      displayName: 'JetBrains 极客参数',
      category: 'english_art',
      previewSample: '35mm  F/1.8  1/2000s  ISO64',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/google/fonts/tree/main/ofl/jetbrainsmono',
      source: WatermarkFontSource.bundledAsset,
    ),
  ];

  /// 离线兜底目录：即使暂未请求 manifest.json，商店内也可立即展示开源中文字体简介。
  static const List<WatermarkFontEntry> fallbackCloudEntries = [
    WatermarkFontEntry(
      id: 'ma_shan_zheng',
      family: 'ZyncMaShanZheng',
      displayName: '马善政毛笔楷书',
      category: 'chinese_calligraphy',
      previewSample: '山河远阔 · 光影流年',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/googlefonts/mashanzheng',
      source: WatermarkFontSource.cloudStore,
      fileName: 'MaShanZheng-Regular.ttf',
      sizeBytes: 5857936,
      sha256:
          '6d2546bb189c732a8ca29af9e22457b152387d158aa459e4ac2ce1e51788b7fb',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/MaShanZheng-Regular.ttf',
    ),
    WatermarkFontEntry(
      id: 'long_cang',
      family: 'ZyncLongCang',
      displayName: '龙藏体手写行楷',
      category: 'chinese_calligraphy',
      previewSample: '浮生若梦 · 快门定格',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/m4rc1e/longcang',
      source: WatermarkFontSource.cloudStore,
      fileName: 'LongCang-Regular.ttf',
      sizeBytes: 5162508,
      sha256:
          'e5bf2c3f24ef2327c6f136d8f73e2f9dfdf44896fdbeb35a9515f44777bb91bc',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/LongCang-Regular.ttf',
    ),
    WatermarkFontEntry(
      id: 'zcool_xiaowei',
      family: 'ZyncZcoolXiaoWei',
      displayName: '站酷小薇文艺宋',
      category: 'chinese_serif',
      previewSample: '城市漫游 · 人文展签',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/googlefonts/zcool-xiaowei',
      source: WatermarkFontSource.cloudStore,
      fileName: 'ZCOOLXiaoWei-Regular.ttf',
      sizeBytes: 6313808,
      sha256:
          'a42b620140f493db42f741351dfbf343c0936d58588ee8004b8b2a218d997ff1',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/ZCOOLXiaoWei-Regular.ttf',
    ),
    WatermarkFontEntry(
      id: 'zhi_mang_xing',
      family: 'ZyncZhiMangXing',
      displayName: '钟齐志莽行书',
      category: 'chinese_calligraphy',
      previewSample: '风起云涌 · 见天地',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/googlefonts/zhimangxing',
      source: WatermarkFontSource.cloudStore,
      fileName: 'ZhiMangXing-Regular.ttf',
      sizeBytes: 4063532,
      sha256:
          '644e0cae9b40f0b10ab729a01bd32032e3973bac22be3dccae01bf6ae7fde969',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/ZhiMangXing-Regular.ttf',
    ),
    WatermarkFontEntry(
      id: 'lxgw_wenkai',
      family: 'ZyncLxgwWenKai',
      displayName: '霞鹜文楷',
      category: 'chinese_handwriting',
      previewSample: '温柔岁月 · 人像随笔',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/lxgw/LxgwWenKai',
      source: WatermarkFontSource.cloudStore,
      fileName: 'LXGWWenKai-Regular.ttf',
      sizeBytes: 25928940,
      sha256:
          '2d73eea94ad808999d90c0000c239a84a33b09d4bc6ab6c5b8bbf1eda8a7fc8b',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/LXGWWenKai-Regular.ttf',
    ),
    WatermarkFontEntry(
      id: 'zhuque_fangsong',
      family: 'ZyncZhuqueFangsong',
      displayName: '朱雀仿宋',
      category: 'chinese_serif',
      previewSample: '南宋活字 · 典雅诗行',
      license: 'SIL OFL-1.1',
      sourceUrl: 'https://github.com/TrionesType/zhuque',
      source: WatermarkFontSource.cloudStore,
      fileName: 'ZhuqueFangsong-Regular.ttf',
      sizeBytes: 8824084,
      sha256:
          '558c62730844fe54ba220146ed62f859d4e2880188d92d985f8921c6e3743bc',
      downloadUrl:
          'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/ZhuqueFangsong-Regular.ttf',
    ),
  ];

  bool _initialized = false;
  Directory? _rootDir;
  List<WatermarkFontEntry> _cloudCatalog = List.of(fallbackCloudEntries);
  final List<WatermarkFontEntry> _importedEntries = [];
  final Set<String> _installedIds = {
    for (final e in builtinEntries) e.id,
  };
  final Set<String> _loadedFamilies = {};
  final Map<String, double> _downloadProgress = {};

  bool _manifestLoading = false;
  String? _manifestError;

  bool get manifestLoading => _manifestLoading;
  String? get manifestError => _manifestError;

  List<WatermarkFontEntry> get cloudCatalog => List.unmodifiable(_cloudCatalog);
  List<WatermarkFontEntry> get importedEntries =>
      List.unmodifiable(_importedEntries);

  List<WatermarkFontEntry> get allEntries => [
        ...builtinEntries,
        ..._cloudCatalog,
        ..._importedEntries,
      ];

  /// 仅返回当前可直接用于画布渲染的字体（内置 + 已下载 + 已导入）。
  List<WatermarkFontEntry> get installedEntries =>
      allEntries.where((e) => isInstalled(e.id)).toList(growable: false);

  bool isInstalled(String fontId) => _installedIds.contains(fontId);

  double? progressOf(String fontId) => _downloadProgress[fontId];

  WatermarkFontEntry? findById(String fontId) {
    for (final e in allEntries) {
      if (e.id == fontId) return e;
    }
    return null;
  }

  /// 根据 [fontId] 解析实际传递给 Flutter `TextStyle.fontFamily` 的家族名称；
  /// 未安装或为默认字体时返回 null（使用系统默认字体）。
  String? resolveFontFamily(String fontId) {
    if (!isInstalled(fontId)) return null;
    return findById(fontId)?.family;
  }

  Future<Directory> _fontsDir({Directory? overrideDirectory}) async {
    final base = overrideDirectory ??
        _rootDir ??
        await getApplicationDocumentsDirectory();
    _rootDir = base;
    final dir = Directory('${base.path}/fonts_store');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> ensureInitialized({Directory? overrideDirectory}) async {
    if (_initialized && overrideDirectory == null) return;
    try {
      final dir = await _fontsDir(overrideDirectory: overrideDirectory);

      // 1. 读取已导入的本地字体清单
      _importedEntries.clear();
      final localIdx = File('${dir.path}/imported_index.json');
      if (await localIdx.exists()) {
        try {
          final raw = jsonDecode(await localIdx.readAsString());
          if (raw is List) {
            for (final item in raw.whereType<Map>()) {
              final map = Map<String, dynamic>.from(item);
              final fileName = map['fileName'] as String? ?? '';
              if (fileName.isEmpty) continue;
              final file = File('${dir.path}/$fileName');
              if (!await file.exists()) continue;
              final entry = WatermarkFontEntry(
                id: map['id'] as String? ?? 'custom_${_importedEntries.length}',
                family: map['family'] as String? ??
                    'ZyncCustom_${_importedEntries.length}',
                displayName: map['displayName'] as String? ?? fileName,
                category: 'local_import',
                license: 'User Imported',
                source: WatermarkFontSource.localImport,
                fileName: fileName,
                sizeBytes: await file.length(),
                sha256: map['sha256'] as String? ?? '',
              );
              _importedEntries.add(entry);
              await _registerFontFile(entry, file);
            }
          }
        } catch (_) {}
      }

      // 2. 扫描已缓存的云端下载字体并预加载到 FontLoader
      for (final entry in _cloudCatalog) {
        final fName = entry.fileName;
        if (fName == null || fName.isEmpty) continue;
        final file = File('${dir.path}/$fName');
        if (await file.exists() && await file.length() > 1024) {
          await _registerFontFile(entry, file);
        }
      }
    } catch (_) {
      // Widget 测试或无 path_provider 环境下保持内置字体可用
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _registerFontFile(
    WatermarkFontEntry entry,
    File file,
  ) async {
    final family = entry.family;
    if (family == null || family.isEmpty) {
      _installedIds.add(entry.id);
      return;
    }
    if (!_loadedFamilies.contains(family)) {
      try {
        final bytes = await file.readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
        await loader.load();
        _loadedFamilies.add(family);
      } catch (_) {
        // 单元测试无引擎时 FontLoader 可能抛错，仍标记文件就绪以便验证逻辑。
      }
    }
    _installedIds.add(entry.id);
  }

  /// 从 `sa1to-asuka/Zync` (`fonts-v1`) 拉取最新字体索引。
  Future<void> refreshCloudManifest({
    FontDownloadTransport? transport,
  }) async {
    _manifestLoading = true;
    _manifestError = null;
    notifyListeners();
    try {
      final bytes = await _downloadWithFallback(
        manifestUrl,
        transport: transport ?? _defaultHttpDownload,
      );
      final parsed = parseManifestJson(utf8.decode(bytes));
      if (parsed.isNotEmpty) {
        _cloudCatalog = parsed;
        // 同步刷新哪些云端字体已在本地缓存
        final dir = await _fontsDir();
        for (final e in _cloudCatalog) {
          final fn = e.fileName;
          if (fn != null && await File('${dir.path}/$fn').exists()) {
            _installedIds.add(e.id);
          }
        }
      }
    } catch (e) {
      _manifestError = '$e';
    } finally {
      _manifestLoading = false;
      notifyListeners();
    }
  }

  static List<WatermarkFontEntry> parseManifestJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final list = decoded['fonts'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) =>
            WatermarkFontEntry.fromManifestJson(Map<String, dynamic>.from(m)))
        .where((e) => e.id.isNotEmpty && e.downloadUrl.isNotEmpty)
        .toList(growable: false);
  }

  /// 下载云端艺术字并校验 SHA-256 后实时加载到画布。
  Future<void> downloadFont(
    WatermarkFontEntry entry, {
    FontDownloadTransport? transport,
    Directory? overrideDirectory,
  }) async {
    if (entry.downloadUrl.isEmpty) {
      throw StateError('Missing download URL for ${entry.id}');
    }
    final dir = await _fontsDir(overrideDirectory: overrideDirectory);
    final fileName = entry.fileName?.isNotEmpty == true
        ? entry.fileName!
        : '${entry.id}.ttf';
    final targetFile = File('${dir.path}/$fileName');
    final partFile = File('${dir.path}/$fileName.part');

    _downloadProgress[entry.id] = 0.01;
    notifyListeners();

    try {
      final bytes = await _downloadWithFallback(
        entry.downloadUrl,
        transport: transport ?? _defaultHttpDownload,
        onProgress: (received, total) {
          final p = total > 0
              ? (received / total).clamp(0.01, 0.99)
              : 0.5;
          _downloadProgress[entry.id] = p;
          notifyListeners();
        },
      );

      if (!_hasValidFontMagic(bytes)) {
        throw const FormatException('Downloaded file is not a valid TTF/OTF');
      }
      if (entry.sha256.isNotEmpty) {
        final actual = sha256.convert(bytes).toString().toLowerCase();
        if (actual != entry.sha256.toLowerCase()) {
          throw StateError(
              'SHA-256 mismatch: expected ${entry.sha256}, got $actual');
        }
      }

      await partFile.writeAsBytes(bytes, flush: true);
      if (await targetFile.exists()) await targetFile.delete();
      await partFile.rename(targetFile.path);
      await _registerFontFile(entry, targetFile);
    } finally {
      _downloadProgress.remove(entry.id);
      if (await partFile.exists()) {
        try {
          await partFile.delete();
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  /// 导入用户本地 `.ttf` / `.otf` 字体文件并零重启激活。
  Future<WatermarkFontEntry> importLocalFontFile(
    String sourcePath, {
    String? displayName,
    Directory? overrideDirectory,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('Font file not found');
    }
    final bytes = await src.readAsBytes();
    if (!_hasValidFontMagic(bytes)) {
      throw const FormatException('Unsupported font format (need TTF/OTF)');
    }
    final dir = await _fontsDir(overrideDirectory: overrideDirectory);
    final rawName = src.uri.pathSegments.last;
    final cleanBase = rawName.replaceAll(RegExp(r'\.(ttf|otf|ttc)$', caseSensitive: false), '');
    final digest = sha256.convert(bytes).toString().substring(0, 8);
    final ext = rawName.toLowerCase().endsWith('.otf') ? 'otf' : 'ttf';
    final storedName = 'custom_$digest.$ext';
    final targetFile = File('${dir.path}/$storedName');
    await targetFile.writeAsBytes(bytes, flush: true);

    final id = 'local_$digest';
    final family = 'ZyncLocal_$digest';
    final entry = WatermarkFontEntry(
      id: id,
      family: family,
      displayName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : cleanBase,
      category: 'local_import',
      previewSample: '山河岁月 · NIKON Z',
      license: 'User Imported',
      source: WatermarkFontSource.localImport,
      fileName: storedName,
      sizeBytes: bytes.length,
      sha256: digest,
    );

    _importedEntries.removeWhere((e) => e.id == id);
    _importedEntries.insert(0, entry);
    await File('${dir.path}/imported_index.json').writeAsString(
      jsonEncode(_importedEntries.map((e) => e.toLocalIndexJson()).toList()),
      flush: true,
    );
    await _registerFontFile(entry, targetFile);
    notifyListeners();
    return entry;
  }

  Future<void> deleteFont(
    String fontId, {
    Directory? overrideDirectory,
  }) async {
    final entry = findById(fontId);
    if (entry == null ||
        entry.source == WatermarkFontSource.system ||
        entry.source == WatermarkFontSource.bundledAsset) {
      return;
    }
    final dir = await _fontsDir(overrideDirectory: overrideDirectory);
    final fileName = entry.fileName;
    if (fileName != null && fileName.isNotEmpty) {
      final f = File('${dir.path}/$fileName');
      if (await f.exists()) await f.delete();
    }
    _installedIds.remove(fontId);
    if (entry.source == WatermarkFontSource.localImport) {
      _importedEntries.removeWhere((e) => e.id == fontId);
      await File('${dir.path}/imported_index.json').writeAsString(
        jsonEncode(_importedEntries.map((e) => e.toLocalIndexJson()).toList()),
        flush: true,
      );
    }
    notifyListeners();
  }

  static bool _hasValidFontMagic(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];
    // TTF (0x00010000 or 'true'), OTF ('OTTO'), TTC ('ttcf')
    final isSfnt = b0 == 0x00 && b1 == 0x01 && b2 == 0x00 && b3 == 0x00;
    final isOtto = b0 == 0x4F && b1 == 0x54 && b2 == 0x54 && b3 == 0x4F;
    final isTrue = b0 == 0x74 && b1 == 0x72 && b2 == 0x75 && b3 == 0x65;
    final isTtcf = b0 == 0x74 && b1 == 0x74 && b2 == 0x63 && b3 == 0x66;
    return isSfnt || isOtto || isTrue || isTtcf;
  }

  static Future<Uint8List> _downloadWithFallback(
    String directUrl, {
    required FontDownloadTransport transport,
    void Function(int received, int total)? onProgress,
  }) async {
    final candidates = candidateUrlsFor(directUrl);
    Object? lastErr;
    for (final uri in candidates) {
      try {
        return await transport(uri, onProgress: onProgress);
      } catch (e) {
        lastErr = e;
      }
    }
    throw lastErr ?? StateError('No valid download URL');
  }

  static Future<Uint8List> _defaultHttpDownload(
    Uri url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(url).timeout(const Duration(seconds: 12));
      req.headers.set('User-Agent', 'Zync-FontStore/3.0.0');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}', uri: url);
      }
      final total = resp.contentLength;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in resp.timeout(const Duration(seconds: 25))) {
        builder.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }
}
