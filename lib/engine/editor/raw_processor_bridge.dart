import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../filter/photo_filter.dart';
import 'pro_photo_models.dart';

class RawProbeResult {
  final bool supported;
  final int width;
  final int height;
  final int bitDepth;
  final String cameraMake;
  final String cameraModel;
  final String lensModel;
  final int iso;
  final double aperture;
  final String shutter;
  final double focalLength;
  final int orientation;
  final bool hasEmbeddedPreview;
  final String colorMatrix;
  final String asShotWhiteBalance;
  final String reason;

  const RawProbeResult({
    this.supported = false,
    this.width = 0,
    this.height = 0,
    this.bitDepth = 16,
    this.cameraMake = '',
    this.cameraModel = '',
    this.lensModel = '',
    this.iso = 0,
    this.aperture = 0,
    this.shutter = '',
    this.focalLength = 0,
    this.orientation = 1,
    this.hasEmbeddedPreview = false,
    this.colorMatrix = '',
    this.asShotWhiteBalance = '',
    this.reason = '',
  });

  factory RawProbeResult.fromMap(Map<dynamic, dynamic> map) => RawProbeResult(
        supported: map['supported'] as bool? ?? false,
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        bitDepth: (map['bitDepth'] as num?)?.toInt() ?? 16,
        cameraMake: map['cameraMake'] as String? ?? '',
        cameraModel: map['cameraModel'] as String? ?? '',
        lensModel: map['lensModel'] as String? ?? '',
        iso: (map['iso'] as num?)?.toInt() ?? 0,
        aperture: (map['aperture'] as num?)?.toDouble() ?? 0,
        shutter: map['shutter'] as String? ?? '',
        focalLength: (map['focalLength'] as num?)?.toDouble() ?? 0,
        orientation: (map['orientation'] as num?)?.toInt() ?? 1,
        hasEmbeddedPreview: map['hasEmbeddedPreview'] as bool? ?? false,
        colorMatrix: map['colorMatrix'] as String? ?? '',
        asShotWhiteBalance: map['asShotWhiteBalance'] as String? ?? '',
        reason: map['reason'] as String? ?? '',
      );
}

class RawRenderResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final bool isProxy;

  const RawRenderResult({
    required this.bytes,
    required this.width,
    required this.height,
    this.isProxy = false,
  });

  factory RawRenderResult.fromMap(Map<dynamic, dynamic> map) => RawRenderResult(
        bytes: map['bytes'] as Uint8List? ?? Uint8List(0),
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        isProxy: map['isProxy'] as bool? ?? false,
      );
}

/// LibRaw/原生 RAW 管线的 Dart 入口。原生不可用时返回明确原因，由 UI 回退到 JPEG。
class RawProcessorBridge {
  static const MethodChannel _channel =
      MethodChannel('com.zync.app/raw_processor');
  static bool? _available;

  static Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  static Future<RawProbeResult> probe(String path) async {
    try {
      final map = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('probe', {'path': path});
      return RawProbeResult.fromMap(map ?? const {});
    } catch (e) {
      return RawProbeResult(reason: e.toString());
    }
  }

  static Future<RawRenderResult> renderPreview({
    required String path,
    int maxEdge = 2048,
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
    ColorGrade? grade,
  }) async {
    final recipe = PhotoEditRecipe(
      sourceMode: PhotoSourceMode.professionalRaw,
      filterTypeName: filterType.name,
      filterIntensity: filterIntensity,
      grade: grade ?? ColorGrade(base: adjustments),
    );
    final map =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('renderPreview', {
      'path': path,
      'maxEdge': maxEdge,
      'recipe': recipe.toJsonString(),
    });
    return RawRenderResult.fromMap(map ?? const {});
  }

  static Future<RawRenderResult> renderFull({
    required String path,
    String outputPath = '',
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
    ColorGrade? grade,
    int jpegQuality = 95,
  }) async {
    final recipe = PhotoEditRecipe(
      sourceMode: PhotoSourceMode.professionalRaw,
      filterTypeName: filterType.name,
      filterIntensity: filterIntensity,
      grade: grade ?? ColorGrade(base: adjustments),
    );
    final map =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('renderFull', {
      'path': path,
      'outputPath': outputPath,
      'jpegQuality': jpegQuality,
      'recipe': recipe.toJsonString(),
    });
    return RawRenderResult.fromMap(map ?? const {});
  }

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
