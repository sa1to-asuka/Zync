import 'dart:convert';

import '../editor/pro_photo_models.dart';

enum KeyframeInterpolation { linear, easeInOut }

class Keyframe {
  final int timeUs;
  final double value;
  final KeyframeInterpolation interpolation;

  const Keyframe({
    required this.timeUs,
    required this.value,
    this.interpolation = KeyframeInterpolation.linear,
  });

  Map<String, dynamic> toJson() => {
        'timeUs': timeUs,
        'value': value,
        'interpolation': interpolation.name,
      };

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
        timeUs: (json['timeUs'] as num?)?.toInt() ?? 0,
        value: (json['value'] as num?)?.toDouble() ?? 0,
        interpolation: KeyframeInterpolation.values.firstWhere(
          (e) => e.name == json['interpolation'],
          orElse: () => KeyframeInterpolation.linear,
        ),
      );
}

class KeyframeTrack {
  final String parameter;
  final List<Keyframe> keys;

  const KeyframeTrack({required this.parameter, this.keys = const []});

  bool get isEmpty => keys.isEmpty;

  double evaluate(int timeUs, {double fallback = 0}) {
    if (keys.isEmpty) return fallback;
    final sorted = [...keys]..sort((a, b) => a.timeUs.compareTo(b.timeUs));
    if (timeUs <= sorted.first.timeUs) return sorted.first.value;
    if (timeUs >= sorted.last.timeUs) return sorted.last.value;
    for (var i = 1; i < sorted.length; i++) {
      final a = sorted[i - 1];
      final b = sorted[i];
      if (timeUs <= b.timeUs) {
        final span = b.timeUs - a.timeUs;
        if (span <= 0) return b.value;
        var f = (timeUs - a.timeUs) / span;
        if (b.interpolation == KeyframeInterpolation.easeInOut) {
          f = f < 0.5 ? 2 * f * f : 1 - ((-2 * f + 2) * (-2 * f + 2)) / 2;
        }
        return a.value + (b.value - a.value) * f;
      }
    }
    return sorted.last.value;
  }

  KeyframeTrack copyWith({String? parameter, List<Keyframe>? keys}) =>
      KeyframeTrack(
          parameter: parameter ?? this.parameter, keys: keys ?? this.keys);

  Map<String, dynamic> toJson() => {
        'parameter': parameter,
        'keys': keys.map((e) => e.toJson()).toList(),
      };

  factory KeyframeTrack.fromJson(Map<String, dynamic> json) => KeyframeTrack(
        parameter: json['parameter'] as String? ?? '',
        keys: (json['keys'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => Keyframe.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ChapterMarker {
  final int timeUs;
  final String title;
  final int colorValue;

  const ChapterMarker({
    required this.timeUs,
    required this.title,
    this.colorValue = 0xFFFFD100,
  });

  Map<String, dynamic> toJson() => {
        'timeUs': timeUs,
        'title': title,
        'colorValue': colorValue,
      };

  factory ChapterMarker.fromJson(Map<String, dynamic> json) => ChapterMarker(
        timeUs: (json['timeUs'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFD100,
      );
}

class VideoAssetInfo {
  final String id;
  final String path;
  final String fileName;
  final int durationUs;
  final int width;
  final int height;
  final double fps;
  final String videoCodec;
  final String audioCodec;
  final String colorTransfer;
  final String colorPrimaries;
  final bool isHdr;
  final bool isHlg;
  final int bitDepth;
  final int rotationDegrees;
  final bool hasAudio;

  const VideoAssetInfo({
    required this.id,
    required this.path,
    required this.fileName,
    this.durationUs = 0,
    this.width = 0,
    this.height = 0,
    this.fps = 0,
    this.videoCodec = '',
    this.audioCodec = '',
    this.colorTransfer = 'sdr',
    this.colorPrimaries = 'bt709',
    this.isHdr = false,
    this.isHlg = false,
    this.bitDepth = 8,
    this.rotationDegrees = 0,
    this.hasAudio = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'fileName': fileName,
        'durationUs': durationUs,
        'width': width,
        'height': height,
        'fps': fps,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'colorTransfer': colorTransfer,
        'colorPrimaries': colorPrimaries,
        'isHdr': isHdr,
        'isHlg': isHlg,
        'bitDepth': bitDepth,
        'rotationDegrees': rotationDegrees,
        'hasAudio': hasAudio,
      };

  factory VideoAssetInfo.fromJson(Map<String, dynamic> json) => VideoAssetInfo(
        id: json['id'] as String? ?? '',
        path: json['path'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        durationUs: (json['durationUs'] as num?)?.toInt() ?? 0,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        fps: (json['fps'] as num?)?.toDouble() ?? 0,
        videoCodec: json['videoCodec'] as String? ?? '',
        audioCodec: json['audioCodec'] as String? ?? '',
        colorTransfer: json['colorTransfer'] as String? ?? 'sdr',
        colorPrimaries: json['colorPrimaries'] as String? ?? 'bt709',
        isHdr: json['isHdr'] as bool? ?? false,
        isHlg: json['isHlg'] as bool? ?? false,
        bitDepth: (json['bitDepth'] as num?)?.toInt() ?? 8,
        rotationDegrees: (json['rotationDegrees'] as num?)?.toInt() ?? 0,
        hasAudio: json['hasAudio'] as bool? ?? false,
      );
}

class VideoAudioSettings {
  final bool muted;
  final double volume;
  final int fadeInUs;
  final int fadeOutUs;

  const VideoAudioSettings({
    this.muted = false,
    this.volume = 1.0,
    this.fadeInUs = 0,
    this.fadeOutUs = 0,
  });

  bool get isDefault =>
      !muted && volume == 1.0 && fadeInUs == 0 && fadeOutUs == 0;

  VideoAudioSettings copyWith(
          {bool? muted, double? volume, int? fadeInUs, int? fadeOutUs}) =>
      VideoAudioSettings(
        muted: muted ?? this.muted,
        volume: volume ?? this.volume,
        fadeInUs: fadeInUs ?? this.fadeInUs,
        fadeOutUs: fadeOutUs ?? this.fadeOutUs,
      );

  Map<String, dynamic> toJson() => {
        'muted': muted,
        'volume': volume,
        'fadeInUs': fadeInUs,
        'fadeOutUs': fadeOutUs,
      };

  factory VideoAudioSettings.fromJson(Map<String, dynamic> json) =>
      VideoAudioSettings(
        muted: json['muted'] as bool? ?? false,
        volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
        fadeInUs: (json['fadeInUs'] as num?)?.toInt() ?? 0,
        fadeOutUs: (json['fadeOutUs'] as num?)?.toInt() ?? 0,
      );
}

class VideoClip {
  final String id;
  final String assetId;
  final String path;
  final int sourceInUs;
  final int sourceOutUs;

  /// 源素材完整时长。裁剪后仍保留该值，便于重新扩展裁剪范围。
  final int assetDurationUs;
  final int timelineStartUs;
  final ColorGrade grade;
  final VideoAudioSettings audio;
  final List<KeyframeTrack> keyframes;

  const VideoClip({
    required this.id,
    required this.assetId,
    required this.path,
    required this.sourceInUs,
    required this.sourceOutUs,
    this.assetDurationUs = 0,
    this.timelineStartUs = 0,
    this.grade = const ColorGrade(),
    this.audio = const VideoAudioSettings(),
    this.keyframes = const [],
  });

  int get durationUs => (sourceOutUs - sourceInUs).clamp(0, 1 << 62);

  int get timelineEndUs => timelineStartUs + durationUs;

  VideoClip copyWith({
    String? id,
    String? assetId,
    String? path,
    int? sourceInUs,
    int? sourceOutUs,
    int? assetDurationUs,
    int? timelineStartUs,
    ColorGrade? grade,
    VideoAudioSettings? audio,
    List<KeyframeTrack>? keyframes,
  }) =>
      VideoClip(
        id: id ?? this.id,
        assetId: assetId ?? this.assetId,
        path: path ?? this.path,
        sourceInUs: sourceInUs ?? this.sourceInUs,
        sourceOutUs: sourceOutUs ?? this.sourceOutUs,
        assetDurationUs: assetDurationUs ?? this.assetDurationUs,
        timelineStartUs: timelineStartUs ?? this.timelineStartUs,
        grade: grade ?? this.grade,
        audio: audio ?? this.audio,
        keyframes: keyframes ?? this.keyframes,
      );

  double evaluateKeyframe(
      String parameter, int timelineTimeUs, double fallback) {
    final track = keyframes.where((e) => e.parameter == parameter).firstOrNull;
    if (track == null) return fallback;
    final localUs = timelineTimeUs - timelineStartUs;
    return track.evaluate(localUs, fallback: fallback);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetId': assetId,
        'path': path,
        'sourceInUs': sourceInUs,
        'sourceOutUs': sourceOutUs,
        'assetDurationUs': assetDurationUs,
        'timelineStartUs': timelineStartUs,
        'grade': grade.toJson(),
        'audio': audio.toJson(),
        'keyframes': keyframes.map((e) => e.toJson()).toList(),
      };

  factory VideoClip.fromJson(Map<String, dynamic> json) => VideoClip(
        id: json['id'] as String? ?? '',
        assetId: json['assetId'] as String? ?? '',
        path: json['path'] as String? ?? '',
        sourceInUs: (json['sourceInUs'] as num?)?.toInt() ?? 0,
        sourceOutUs: (json['sourceOutUs'] as num?)?.toInt() ?? 0,
        assetDurationUs: (json['assetDurationUs'] as num?)?.toInt() ?? 0,
        timelineStartUs: (json['timelineStartUs'] as num?)?.toInt() ?? 0,
        grade: ColorGrade.fromJson(
            Map<String, dynamic>.from(json['grade'] as Map? ?? const {})),
        audio: VideoAudioSettings.fromJson(
            Map<String, dynamic>.from(json['audio'] as Map? ?? const {})),
        keyframes: (json['keyframes'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => KeyframeTrack.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

enum VideoCodec { h264, hevc }

class VideoExportSpec {
  final VideoCodec codec;
  final int width;
  final int height;
  final double fps;
  final int bitrate;
  final String container;

  const VideoExportSpec({
    this.codec = VideoCodec.h264,
    this.width = 3840,
    this.height = 2160,
    this.fps = 30,
    this.bitrate = 40000000,
    this.container = 'mp4',
  });

  Map<String, dynamic> toJson() => {
        'codec': codec.name,
        'width': width,
        'height': height,
        'fps': fps,
        'bitrate': bitrate,
        'container': container,
      };

  VideoExportSpec copyWith({
    VideoCodec? codec,
    int? width,
    int? height,
    double? fps,
    int? bitrate,
    String? container,
  }) =>
      VideoExportSpec(
        codec: codec ?? this.codec,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps ?? this.fps,
        bitrate: bitrate ?? this.bitrate,
        container: container ?? this.container,
      );

  VideoExportSpec copyWithCodec(VideoCodec value) => copyWith(codec: value);

  VideoExportSpec copyWith4K() => copyWith(width: 3840, height: 2160);

  VideoExportSpec copyWith1080p() => copyWith(width: 1920, height: 1080);

  VideoExportSpec copyWithFps(double value) => copyWith(fps: value);

  VideoExportSpec copyWithBitrate(int value) => copyWith(bitrate: value);
  factory VideoExportSpec.fromJson(Map<String, dynamic> json) =>
      VideoExportSpec(
        codec: VideoCodec.values.firstWhere((e) => e.name == json['codec'],
            orElse: () => VideoCodec.h264),
        width: (json['width'] as num?)?.toInt() ?? 3840,
        height: (json['height'] as num?)?.toInt() ?? 2160,
        fps: (json['fps'] as num?)?.toDouble() ?? 30,
        bitrate: (json['bitrate'] as num?)?.toInt() ?? 40000000,
        container: json['container'] as String? ?? 'mp4',
      );
}

class VideoProject {
  static const int currentVersion = 1;

  final int version;
  final String id;
  final String name;
  final List<VideoClip> clips;
  final ColorGrade globalGrade;
  final List<ChapterMarker> chapters;
  final VideoExportSpec exportSpec;
  final int createdAtMs;
  final int modifiedAtMs;

  const VideoProject({
    this.version = currentVersion,
    required this.id,
    this.name = 'Zync Video',
    this.clips = const [],
    this.globalGrade = const ColorGrade(),
    this.chapters = const [],
    this.exportSpec = const VideoExportSpec(),
    this.createdAtMs = 0,
    this.modifiedAtMs = 0,
  });

  int get durationUs {
    if (clips.isEmpty) return 0;
    var end = 0;
    for (final clip in clips) {
      if (clip.timelineEndUs > end) end = clip.timelineEndUs;
    }
    return end;
  }

  VideoProject copyWith({
    int? version,
    String? id,
    String? name,
    List<VideoClip>? clips,
    ColorGrade? globalGrade,
    List<ChapterMarker>? chapters,
    VideoExportSpec? exportSpec,
    int? createdAtMs,
    int? modifiedAtMs,
  }) =>
      VideoProject(
        version: version ?? this.version,
        id: id ?? this.id,
        name: name ?? this.name,
        clips: clips ?? this.clips,
        globalGrade: globalGrade ?? this.globalGrade,
        chapters: chapters ?? this.chapters,
        exportSpec: exportSpec ?? this.exportSpec,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        modifiedAtMs: modifiedAtMs ?? this.modifiedAtMs,
      );

  VideoProject normalizeTimeline() {
    var cursor = 0;
    final normalized = <VideoClip>[];
    for (final clip in clips) {
      normalized.add(clip.copyWith(timelineStartUs: cursor));
      cursor += clip.durationUs;
    }
    return copyWith(clips: normalized);
  }

  VideoProject trimClip(String clipId, {int? sourceInUs, int? sourceOutUs}) {
    final next = clips.map((clip) {
      if (clip.id != clipId) return clip;
      final inUs = (sourceInUs ?? clip.sourceInUs).clamp(0, clip.sourceOutUs);
      final outUs = (sourceOutUs ?? clip.sourceOutUs).clamp(inUs + 1, 1 << 62);
      return clip.copyWith(sourceInUs: inUs, sourceOutUs: outUs);
    }).toList();
    return copyWith(clips: next).normalizeTimeline();
  }

  VideoProject splitClip(String clipId, int sourceSplitUs) {
    final index = clips.indexWhere((e) => e.id == clipId);
    if (index < 0) return this;
    final clip = clips[index];
    if (sourceSplitUs <= clip.sourceInUs || sourceSplitUs >= clip.sourceOutUs)
      return this;
    final left = clip.copyWith(
      id: '${clip.id}_a',
      sourceOutUs: sourceSplitUs,
    );
    final right = clip.copyWith(
      id: '${clip.id}_b',
      sourceInUs: sourceSplitUs,
    );
    final next = [...clips]..replaceRange(index, index + 1, [left, right]);
    return copyWith(clips: next).normalizeTimeline();
  }

  VideoProject reorderClips(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= clips.length) return this;
    final next = [...clips];
    final item = next.removeAt(oldIndex);
    final target = newIndex.clamp(0, next.length);
    next.insert(target, item);
    return copyWith(clips: next).normalizeTimeline();
  }

  VideoProject removeClip(String clipId) =>
      copyWith(clips: clips.where((e) => e.id != clipId).toList())
          .normalizeTimeline();

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'id': id,
        'name': name,
        'clips': clips.map((e) => e.toJson()).toList(),
        'globalGrade': globalGrade.toJson(),
        'chapters': chapters.map((e) => e.toJson()).toList(),
        'exportSpec': exportSpec.toJson(),
        'createdAtMs': createdAtMs,
        'modifiedAtMs': modifiedAtMs,
      };

  String toJsonString() => jsonEncode(toJson());

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
        version: (json['version'] as num?)?.toInt() ?? 1,
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Zync Video',
        clips: (json['clips'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => VideoClip.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        globalGrade: ColorGrade.fromJson(
            Map<String, dynamic>.from(json['globalGrade'] as Map? ?? const {})),
        chapters: (json['chapters'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => ChapterMarker.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        exportSpec: VideoExportSpec.fromJson(
            Map<String, dynamic>.from(json['exportSpec'] as Map? ?? const {})),
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        modifiedAtMs: (json['modifiedAtMs'] as num?)?.toInt() ?? 0,
      );

  static VideoProject fromJsonString(String source) => VideoProject.fromJson(
      Map<String, dynamic>.from(jsonDecode(source) as Map));
}
