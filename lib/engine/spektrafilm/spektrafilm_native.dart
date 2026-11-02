/// 原生 Spektrafilm 光谱引擎桥接。
///
/// 原生库与数据都是独立第三方组件（GPL-3.0 / CC BY-SA 4.0），
/// 这里只负责把光谱档案解包到应用私有目录并转发渲染请求。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'spektrafilm_models.dart';

class SpektrafilmNative {
  SpektrafilmNative._();

  static const MethodChannel _channel =
      MethodChannel('com.zync.app/spektrafilm');
  static const String assetPrefix = 'third_party/spektrafilm_native/data/';

  static String? _dataDirectory;
  static Future<String>? _prepareFuture;
  static List<SpektraStockInfo>? _stocks;
  static List<SpektraPaperInfo>? _papers;
  static bool _unavailable = false;

  /// Widget tests can inject the real profile catalog without the native
  /// library being present.
  @visibleForTesting
  static List<SpektraStockInfo>? debugStocks;
  @visibleForTesting
  static List<SpektraPaperInfo>? debugPapers;
  @visibleForTesting
  static String? debugDataDirectory;

  static bool get unavailable => _unavailable;

  static List<SpektraStockInfo> get stocks => _stocks ?? const [];
  static List<SpektraPaperInfo> get papers => _papers ?? const [];

  static Future<String> ensureData() {
    return _prepareFuture ??= _prepare();
  }

  static Future<String> _prepare() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/spektrafilm');
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((asset) => asset.startsWith(assetPrefix))
        .toList();
    for (final asset in assets) {
      final relative = asset.substring(assetPrefix.length);
      final file = File('${root.path}/$relative');
      final data = await rootBundle.load(asset);
      final length = data.lengthInBytes;
      if (await file.exists() && await file.length() == length) continue;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, length),
        flush: true,
      );
    }
    _dataDirectory = root.path;
    return root.path;
  }

  static Future<void> loadCatalog() async {
    if (_stocks != null) return;
    if (debugStocks != null) {
      _stocks = debugStocks;
      _papers = debugPapers ?? const [];
      return;
    }
    try {
      final directory = debugDataDirectory ?? await ensureData();
      final json = await _channel.invokeMethod<String>(
        'catalog',
        <String, Object?>{'dataDir': directory},
      );
      if (json == null || json.isEmpty) return;
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      _stocks = (decoded['stocks'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) =>
              SpektraStockInfo.fromJson(Map<String, dynamic>.from(item)))
          .where((stock) => stock.id.isNotEmpty)
          .toList(growable: false);
      _papers = (decoded['papers'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map((item) =>
              SpektraPaperInfo.fromJson(Map<String, dynamic>.from(item)))
          .where((paper) => paper.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      _unavailable = true;
    }
  }

  /// 返回 sRGB RGBA 像素；失败时返回 null。
  static Future<Uint8List?> render({
    required Uint8List rgba,
    required int width,
    required int height,
    required SpektrafilmSettings settings,
  }) async {
    if (!settings.isActive || width <= 0 || height <= 0) return null;
    try {
      final directory =
          debugDataDirectory ?? _dataDirectory ?? await ensureData();
      final result = await _channel
          .invokeMethod<Uint8List>(
            'render',
            <String, Object?>{
              'dataDir': directory,
              'stockId': settings.stockId,
              'paperId': settings.paperId,
              'params': Float32List.fromList(settings.toNativeParams()),
              'bytes': rgba,
              'width': width,
              'height': height,
            },
          )
          .timeout(const Duration(seconds: 45));
      if (result == null || result.length < width * height * 4) return null;
      if (settings.intensity >= 0.999) return result;
      final blended = Uint8List.fromList(result);
      final keep = 1.0 - settings.intensity;
      for (var i = 0; i < width * height; i++) {
        final o = i * 4;
        for (var c = 0; c < 3; c++) {
          blended[o + c] = (rgba[o + c] * keep + result[o + c] * settings.intensity)
              .round()
              .clamp(0, 255);
        }
      }
      return blended;
    } catch (_) {
      return null;
    }
  }

  /// 直接从 LibRaw 线性 ProPhoto 缓存渲染并返回 JPEG 字节。
  static Future<Uint8List?> renderRawFile({
    required String linearPath,
    required int width,
    required int height,
    required SpektrafilmSettings settings,
    int quality = 95,
  }) async {
    if (!settings.isActive || width <= 0 || height <= 0) return null;
    try {
      final directory =
          debugDataDirectory ?? _dataDirectory ?? await ensureData();
      return await _channel.invokeMethod<Uint8List>(
        'renderRaw',
        <String, Object?>{
          'dataDir': directory,
          'stockId': settings.stockId,
          'paperId': settings.paperId,
          'params': Float32List.fromList(settings.toNativeParams()),
          'linearPath': linearPath,
          'width': width,
          'height': height,
          'quality': quality,
        },
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> warmUp() async {
    await loadCatalog();
  }
}
