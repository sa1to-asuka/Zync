import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/collage/collage_layout.dart';

void main() {
  group('Collage Studio 2.0 引擎能力', () {
    test('CollageAspect 扩展至 8 种常用与映画画幅比例', () {
      expect(CollageAspect.values.length, 8);
      expect(CollageAspect.story916.label, '9:16');
      expect(CollageAspect.cinema169.label, '16:9');
    });

    test('CollageImageTransform 支持 90° 旋转宽高互换与水平镜像与 5x 最大倍率', () {
      expect(kCollageMaxImageScale, 5.0);
      const t = CollageImageTransform(
        scale: 2.0,
        offset: Offset(0.1, -0.05),
        quarterTurns: 1,
        flipX: true,
      );
      expect(effectiveCollageImageSize(const Size(3000, 2000), t),
          const Size(2000, 3000));
      expect(
        effectiveCollageImageSize(
          const Size(3000, 2000),
          t.copyWith(quarterTurns: 2),
        ),
        const Size(3000, 2000),
      );
    });

    test('computeFocalZoomTransform 保持焦点缩放不露白且夹取到 5x 上限', () {
      const imgSize = Size(1600, 1200);
      const cell = Rect.fromLTWH(0, 0, 400, 400);
      const start = CollageImageTransform(scale: 1.5);
      final zoomed = computeFocalZoomTransform(
        imageSize: imgSize,
        cell: cell,
        start: start,
        gestureScale: 2.0,
        startFocalCanvas: const Offset(280, 140),
        currentFocalCanvas: const Offset(280, 140),
      );
      expect(zoomed.scale, closeTo(3.0, 1e-6));

      final overZoomed = computeFocalZoomTransform(
        imageSize: imgSize,
        cell: cell,
        start: start,
        gestureScale: 10.0,
        startFocalCanvas: const Offset(200, 200),
        currentFocalCanvas: const Offset(220, 210),
      );
      expect(overZoomed.scale, kCollageMaxImageScale);
    });

    test('CollageDividerSpec 手柄锚点偏置在 82% 位置避免与中心图片拖拽冲突', () {
      const spec = CollageDividerSpec(
        isVerticalDivider: true,
        start: Offset(200, 0),
        end: Offset(200, 1000),
        currentRatio: 0.5,
      );
      expect(spec.handleAnchor.dx, closeTo(200, 1e-6));
      expect(spec.handleAnchor.dy, closeTo(820, 1e-6));
      expect(spec.midpoint.dy, closeTo(500, 1e-6));
    });
  });
}
