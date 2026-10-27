import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/video/video_project.dart';

void main() {
  test('关键帧支持线性与缓入缓出插值', () {
    const track = KeyframeTrack(parameter: 'exposure', keys: [
      Keyframe(timeUs: 0, value: 0),
      Keyframe(
          timeUs: 1000000,
          value: 100,
          interpolation: KeyframeInterpolation.easeInOut),
    ]);
    expect(track.evaluate(0), 0);
    expect(track.evaluate(500000), closeTo(50, 1e-6));
    expect(track.evaluate(1000000), 100);
    expect(track.evaluate(-1), 0);
    expect(track.evaluate(2000000), 100);
  });

  test('时间线裁剪、分割和排序后自动归一化起点', () {
    const clip = VideoClip(
      id: 'a',
      assetId: 'asset',
      path: '/tmp/a.mp4',
      sourceInUs: 0,
      sourceOutUs: 10000000,
    );
    final project = VideoProject(id: 'p', clips: [clip]);
    final trimmed =
        project.trimClip('a', sourceInUs: 1000000, sourceOutUs: 8000000);
    expect(trimmed.clips.single.durationUs, 7000000);

    final split = trimmed.splitClip('a', 4000000);
    expect(split.clips.length, 2);
    expect(split.clips[0].sourceOutUs, 4000000);
    expect(split.clips[1].sourceInUs, 4000000);
    expect(split.clips[1].timelineStartUs, split.clips[0].durationUs);

    final reordered = split.reorderClips(0, 2);
    expect(reordered.clips.first.timelineStartUs, 0);
    expect(reordered.clips.last.timelineEndUs, reordered.durationUs);
  });

  test('项目 JSON 往返保留关键帧、章节和音频设置', () {
    const project = VideoProject(
      id: 'p1',
      clips: [
        VideoClip(
          id: 'c1',
          assetId: 'a1',
          path: '/tmp/a1.mp4',
          sourceInUs: 0,
          sourceOutUs: 5000000,
          assetDurationUs: 12000000,
          audio: VideoAudioSettings(
              muted: true, volume: 0.5, fadeInUs: 100000, fadeOutUs: 200000),
          keyframes: [
            KeyframeTrack(parameter: 'contrast', keys: [
              Keyframe(timeUs: 0, value: 0),
              Keyframe(
                  timeUs: 5000000,
                  value: 25,
                  interpolation: KeyframeInterpolation.easeInOut),
            ]),
          ],
        ),
      ],
      chapters: [ChapterMarker(timeUs: 1000000, title: '开场')],
    );
    final restored = VideoProject.fromJsonString(project.toJsonString());
    expect(restored.clips.single.audio.muted, isTrue);
    expect(restored.clips.single.audio.volume, 0.5);
    expect(restored.clips.single.assetDurationUs, 12000000);
    expect(restored.clips.single.keyframes.single.keys.length, 2);
    expect(restored.chapters.single.title, '开场');
    expect(restored.durationUs, 5000000);
  });
}
