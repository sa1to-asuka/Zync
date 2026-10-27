import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'video_project.dart';

class VideoCapabilities {
  final bool available;
  final bool hardwareDecodeHevc;
  final bool hardwareDecodeHevcMain10;
  final bool hardwareEncodeH264;
  final bool hardwareEncodeHevc;
  final bool media3Available;
  final String reason;

  const VideoCapabilities({
    this.available = false,
    this.hardwareDecodeHevc = false,
    this.hardwareDecodeHevcMain10 = false,
    this.hardwareEncodeH264 = false,
    this.hardwareEncodeHevc = false,
    this.media3Available = false,
    this.reason = '',
  });

  factory VideoCapabilities.fromMap(Map<dynamic, dynamic> map) =>
      VideoCapabilities(
        available: map['available'] as bool? ?? false,
        hardwareDecodeHevc: map['hardwareDecodeHevc'] as bool? ?? false,
        hardwareDecodeHevcMain10:
            map['hardwareDecodeHevcMain10'] as bool? ?? false,
        hardwareEncodeH264: map['hardwareEncodeH264'] as bool? ?? false,
        hardwareEncodeHevc: map['hardwareEncodeHevc'] as bool? ?? false,
        media3Available: map['media3Available'] as bool? ?? false,
        reason: map['reason'] as String? ?? '',
      );
}

class VideoProxyResult {
  final String path;
  final int width;
  final int height;
  final int durationUs;

  const VideoProxyResult({
    required this.path,
    this.width = 0,
    this.height = 0,
    this.durationUs = 0,
  });

  factory VideoProxyResult.fromMap(Map<dynamic, dynamic> map) =>
      VideoProxyResult(
        path: map['path'] as String? ?? '',
        width: (map['width'] as num?)?.toInt() ?? 0,
        height: (map['height'] as num?)?.toInt() ?? 0,
        durationUs: (map['durationUs'] as num?)?.toInt() ?? 0,
      );
}

class VideoExportResult {
  final String path;
  final int durationUs;
  final int sizeBytes;
  final String mimeType;

  const VideoExportResult({
    required this.path,
    this.durationUs = 0,
    this.sizeBytes = 0,
    this.mimeType = 'video/mp4',
  });

  factory VideoExportResult.fromMap(Map<dynamic, dynamic> map) =>
      VideoExportResult(
        path: map['path'] as String? ?? '',
        durationUs: (map['durationUs'] as num?)?.toInt() ?? 0,
        sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
        mimeType: map['mimeType'] as String? ?? 'video/mp4',
      );
}

/// Media3 视频引擎的 Dart 入口。
class VideoEditorBridge {
  static const MethodChannel _channel =
      MethodChannel('com.zync.app/video_editor');
  static final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  static bool _handlerInstalled = false;

  static Stream<double> get progressStream => _progressController.stream;

  static void _installHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'videoProgress') {
        final arguments = call.arguments;
        final value = arguments is Map ? arguments['progress'] : null;
        if (value is num) {
          _progressController.add(value.toDouble().clamp(0.0, 1.0));
        }
      }
      return null;
    });
  }

  static Future<VideoCapabilities> capabilities() async {
    _installHandler();
    try {
      final map =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('capabilities');
      return VideoCapabilities.fromMap(map ?? const {});
    } catch (e) {
      return VideoCapabilities(reason: e.toString());
    }
  }

  static Future<VideoAssetInfo?> importAsset(String path) async {
    _installHandler();
    try {
      final map = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('importAsset', {'path': path});
      if (map == null) return null;
      return VideoAssetInfo.fromJson(Map<String, dynamic>.from(map));
    } catch (_) {
      return null;
    }
  }

  static Future<VideoProxyResult?> createProxy(String path,
      {int targetHeight = 1080}) async {
    _installHandler();
    try {
      final map =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('createProxy', {
        'path': path,
        'targetHeight': targetHeight,
      });
      if (map == null) return null;
      return VideoProxyResult.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<VideoExportResult?> export(VideoProject project,
      {String outputPath = ''}) async {
    _installHandler();
    try {
      final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('export', {
        'project': project.toJsonString(),
        'outputPath': outputPath,
      });
      if (map == null) return null;
      return VideoExportResult.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  static Future<VideoExportResult?> renderPreview(VideoProject project,
      {String? clipId}) async {
    _installHandler();
    try {
      final map =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('renderPreview', {
        'project': project.toJsonString(),
        'clipId': clipId ?? '',
      });
      if (map == null) return null;
      return VideoExportResult.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// 抓取当前播放头附近的一帧，供示波器分析（波形图 / 矢量示波器 / RGB Parade）。
  static Future<Uint8List?> captureFrame(String path,
      {required int timeUs, int maxEdge = 480}) async {
    _installHandler();
    try {
      final map =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('captureFrame', {
        'path': path,
        'timeUs': timeUs,
        'maxEdge': maxEdge,
      });
      return map?['bytes'] as Uint8List?;
    } catch (_) {
      return null;
    }
  }

  /// 批量抽帧，供时间线缩略图条使用。返回列表与 [timesUs] 一一对应，
  /// 抽不到的位置为 null。
  static Future<List<Uint8List?>> captureFrames(
    String path, {
    required List<int> timesUs,
    int maxEdge = 160,
  }) async {
    _installHandler();
    if (timesUs.isEmpty) return const [];
    try {
      final map =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('captureFrames', {
        'path': path,
        'timesUs': timesUs,
        'maxEdge': maxEdge,
      });
      final frames = map?['frames'];
      if (frames is! List) return const [];
      return frames
          .map((e) => e is Uint8List ? e : null)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> cancel() async {
    _installHandler();
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
