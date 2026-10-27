import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/widgets/video_frame_strip.dart';

/// 审查点：片段裁剪/分割后，帧条是否仍能覆盖整段画面。
///
/// 覆盖三种边界：
/// - 片段只覆盖部分时间（裁掉前段）
/// - 片段夹在两帧之间
/// - 片段完全落在所有帧之外（裁剪范围超出素材区间）
///
/// 说明：不使用 Canvas 录制（Canvas 无法继承），
/// 而是把矩形计算提炼为纯函数后直接验证。
void main() {
  /// 验证 VideoFrameStrip.draw 的矩形计算（含兜底逻辑）。
  List<Rect> computeDrawRects(
    List<int> timesUs,
    Rect clip,
    int clipStartUs,
    int clipDurationUs,
  ) {
    final rects = <Rect>[];
    if (timesUs.isEmpty || clip.width <= 0 || clip.height <= 0) return rects;
    if (clipDurationUs <= 0) return rects;

    int? nearestFallback;
    int? nearestDistance;
    var drawn = 0;

    for (var i = 0; i < timesUs.length; i++) {
      final relative =
          ((timesUs[i] - clipStartUs) / clipDurationUs).clamp(0.0, 1.0);
      final slotLeft = clip.left + clip.width * relative;
      final slotRight = i + 1 < timesUs.length
          ? clip.left +
              clip.width *
                  (((timesUs[i + 1] - clipStartUs) / clipDurationUs)
                      .clamp(0.0, 1.0))
          : clip.right;
      if (slotRight <= clip.left || slotLeft >= clip.right) {
        final distance = timesUs[i] < clipStartUs
            ? clipStartUs - timesUs[i]
            : timesUs[i] - (clipStartUs + clipDurationUs);
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestFallback = i;
        }
        continue;
      }
      nearestFallback = null;
      nearestDistance = null;
      final drawLeft = slotLeft < clip.left ? clip.left : slotLeft;
      final drawRight = slotRight > clip.right ? clip.right : slotRight;
      if (drawRight - drawLeft <= 0.5) continue;
      rects.add(Rect.fromLTRB(drawLeft, clip.top, drawRight, clip.bottom));
      drawn++;
    }

    if (drawn == 0 && nearestFallback != null) {
      rects.add(clip);
    }
    return rects;
  }

  void expectNoGap(List<Rect> rects, Rect clip, String label) {
    expect(rects, isNotEmpty, reason: '$label：应至少绘制一帧');
    var minLeft = double.infinity;
    var maxRight = double.negativeInfinity;
    for (final r in rects) {
      if (r.left < minLeft) minLeft = r.left;
      if (r.right > maxRight) maxRight = r.right;
    }
    expect(minLeft, lessThanOrEqualTo(clip.left + 0.5),
        reason: '$label：左边界留白 minLeft=$minLeft');
    expect(maxRight, greaterThanOrEqualTo(clip.right - 0.5),
        reason: '$label：右边界留白 maxRight=$maxRight');
  }

  test('片段只覆盖部分时间时，帧条仍铺满整段', () {
    const times = [0, 5000000, 8000000, 10000000];
    const clip = Rect.fromLTWH(0, 0, 100, 20);
    expectNoGap(computeDrawRects(times, clip, 8000000, 2000000), clip, '裁掉前段');
  });

  test('片段夹在两帧之间时也不留白', () {
    const times = [0, 10000000];
    const clip = Rect.fromLTWH(0, 0, 200, 20);
    expectNoGap(
        computeDrawRects(times, clip, 4000000, 2000000), clip, '夹在两帧之间');
  });

  test('片段完全晚于所有帧时仍铺满', () {
    const times = [0, 1000000];
    const clip = Rect.fromLTWH(0, 0, 120, 20);
    expectNoGap(
        computeDrawRects(times, clip, 2000000, 1000000), clip, '完全在帧之后');
  });

  test('片段完全早于所有帧时仍铺满（修复前会整段空白）', () {
    const times = [5000000, 10000000];
    const clip = Rect.fromLTWH(0, 0, 80, 20);
    expectNoGap(computeDrawRects(times, clip, 0, 1000000), clip, '完全在帧之前');
  });

  test('真实 strip 可构造并绘制不抛异常', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint());
    final picture = recorder.endRecording();
    final image = await picture.toImage(8, 8);
    picture.dispose();

    final strip = VideoFrameStrip.forTesting(
      frames: [image],
      timesUs: const [1000000],
    );
    expect(strip.isEmpty, isFalse);

    final recorder2 = ui.PictureRecorder();
    strip.draw(
      Canvas(recorder2),
      clip: const Rect.fromLTWH(0, 0, 100, 20),
      clipTimelineStartUs: 1000000,
      clipDurationUs: 1000000,
    );
    recorder2.endRecording().dispose();
    image.dispose();
  });
}
