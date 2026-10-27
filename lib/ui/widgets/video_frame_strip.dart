import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../engine/video/video_editor_bridge.dart';

/// 时间线帧序列缩略图条。
///
/// 职责：按时间点批量抽帧（原生后台线程）、后台解码为 [ui.Image]、
/// 按**真实时间位置**绘制到片段矩形内。
///
/// 关键点：帧位置由 [timesUs] 与片段时间区间换算，而不是按帧数等分。
/// 这样在片段被裁剪、分割或重排后，缩略图仍能对上正确的画面。
class VideoFrameStrip {
  VideoFrameStrip._({
    required this.frames,
    required this.timesUs,
    required this.sourcePath,
  });

  /// 仅供测试构造：直接给定帧与时间点，跳过抽帧与解码。
  @visibleForTesting
  factory VideoFrameStrip.forTesting({
    required List<ui.Image> frames,
    required List<int> timesUs,
    String sourcePath = '',
  }) =>
      VideoFrameStrip._(
        frames: frames,
        timesUs: timesUs,
        sourcePath: sourcePath,
      );

  /// 已解码的帧（按时间升序）。
  final List<ui.Image> frames;

  /// 每帧对应的时间点（微秒），与 [frames] 一一对应且严格递增。
  final List<int> timesUs;

  /// 源视频路径，用于缓存键。
  final String sourcePath;

  /// 抽帧条数量上限，避免超长视频产生过多帧。
  static const int maxFrames = 16;

  /// 单次抽帧的间隔下界，避免对极短视频做无意义的密集抽帧。
  static const int minFrameGapUs = 100000;

  static final Map<String, VideoFrameStrip> _cache =
      <String, VideoFrameStrip>{};

  bool get isEmpty => frames.isEmpty;

  /// 时间线区间内均匀取帧，抽帧并解码。
  ///
  /// 抽帧全部在原生后台线程完成；解码在 Dart 侧逐帧进行，不阻塞 UI。
  static Future<VideoFrameStrip?> load(
    String path, {
    required int fromUs,
    required int toUs,
    int count = maxFrames,
  }) async {
    if (path.isEmpty || toUs <= fromUs) return null;
    final key = '$path|$fromUs|$toUs|$count';
    final cached = _cache[key];
    if (cached != null) return cached;

    final span = toUs - fromUs;
    final effectiveCount = count.clamp(
      2,
      count > span ~/ minFrameGapUs
          ? (span ~/ minFrameGapUs).clamp(2, count)
          : count,
    );
    final step = span / effectiveCount;
    final times = <int>[
      for (var i = 0; i < effectiveCount; i++) fromUs + (step * i).round(),
    ];

    try {
      final encoded =
          await VideoEditorBridge.captureFrames(path, timesUs: times);
      final images = <ui.Image>[];
      final keptTimes = <int>[];
      for (var i = 0; i < encoded.length && i < times.length; i++) {
        final bytes = encoded[i];
        if (bytes == null || bytes.isEmpty) continue;
        final image = await _decode(bytes);
        if (image == null) continue;
        images.add(image);
        keptTimes.add(times[i]);
      }
      if (images.isEmpty) return null;
      final strip = VideoFrameStrip._(
        frames: images,
        timesUs: keptTimes,
        sourcePath: path,
      );
      _cache[key] = strip;
      return strip;
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// 把帧绘制到指定片段矩形内。
  ///
  /// 每帧按自身时间点在片段内的相对位置横向定位并延展到下一帧位置，
  /// 首帧贴左边界、末帧延展到右边界。
  void draw(
    Canvas canvas, {
    required Rect clip,
    required int clipTimelineStartUs,
    required int clipDurationUs,
  }) {
    if (frames.isEmpty || clip.width <= 0 || clip.height <= 0) return;
    if (clipDurationUs <= 0) return;

    canvas.save();
    canvas.clipRect(clip);
    final paint = Paint()..filterQuality = FilterQuality.low;

    // 片段可能整体落在所有帧之外（裁剪范围超出素材区间），
    // 此时记录最接近片段的帧作为兜底，确保不留白。
    int? nearestFallback;
    int? nearestDistance;
    var rectsDrawn = 0;

    for (var i = 0; i < frames.length; i++) {
      // 该帧在片段内的相对位置（0..1）。
      final relative =
          ((timesUs[i] - clipTimelineStartUs) / clipDurationUs).clamp(0.0, 1.0);
      // 片段整体区间在时间轴上的左右边界（相对片段起点）。
      final slotLeft = clip.left + clip.width * relative;
      // 延展到下一帧位置；末帧延展到片段右边界。
      final slotRight = i + 1 < frames.length
          ? clip.left +
              clip.width *
                  (((timesUs[i + 1] - clipTimelineStartUs) / clipDurationUs)
                      .clamp(0.0, 1.0))
          : clip.right;

      // 完全落在片段之外的帧不绘制。
      if (slotRight <= clip.left || slotLeft >= clip.right) {
        // 该帧完全在片段外：记录它到片段区间的距离，作为兜底候选。
        final distance = timesUs[i] < clipTimelineStartUs
            ? clipTimelineStartUs - timesUs[i]
            : timesUs[i] - (clipTimelineStartUs + clipDurationUs);
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestFallback = i;
        }
        continue;
      }
      // 有帧落在片段内，兜底候选作废。
      nearestFallback = null;
      nearestDistance = null;
      final drawLeft = slotLeft < clip.left ? clip.left : slotLeft;
      final drawRight = slotRight > clip.right ? clip.right : slotRight;
      if (drawRight - drawLeft <= 0.5) continue;

      canvas.drawImageRect(
        frames[i],
        Rect.fromLTWH(
            0, 0, frames[i].width.toDouble(), frames[i].height.toDouble()),
        Rect.fromLTRB(drawLeft, clip.top, drawRight, clip.bottom),
        paint,
      );
      rectsDrawn++;
    }
    // 所有帧都在片段外：用最接近的一帧铺满整段，避免时间线空白。
    if (rectsDrawn == 0 && nearestFallback != null) {
      final image = frames[nearestFallback];
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        clip,
        paint,
      );
    }
    canvas.restore();
  }

  /// 清空所有缓存并释放帧。
  static void clearCache() {
    for (final strip in _cache.values) {
      for (final image in strip.frames) {
        try {
          image.dispose();
        } catch (_) {}
      }
    }
    _cache.clear();
  }
}
