import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/widgets/video_frame_strip.dart';

void main() {
  test('抽帧数量受最小间隔约束，极短视频不会密集抽帧', () {
    // 该约束是防止 1 秒视频被抽 16 帧导致无意义开销。
    expect(VideoFrameStrip.maxFrames, greaterThan(1));
    expect(VideoFrameStrip.minFrameGapUs, greaterThan(0));
  });

  test('空路径或非法区间不发起抽帧', () async {
    expect(
      await VideoFrameStrip.load('', fromUs: 0, toUs: 1000000),
      isNull,
    );
    expect(
      await VideoFrameStrip.load('/tmp/x.mp4', fromUs: 500, toUs: 500),
      isNull,
    );
    expect(
      await VideoFrameStrip.load('/tmp/x.mp4', fromUs: 1000, toUs: 500),
      isNull,
    );
  });

  test('clearCache 可重复调用且不抛异常', () {
    VideoFrameStrip.clearCache();
    VideoFrameStrip.clearCache();
  });
}
