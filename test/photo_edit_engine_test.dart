import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/editor/photo_edit_controller.dart';
import 'package:zync/engine/editor/photo_edit_engine.dart';
import 'package:zync/ui/widgets/photo_edit_tools.dart';

img.Image _redBlueImage(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // 左半红、右半蓝，方便验证水平翻转与裁切
      final c = x < w / 2 ? img.ColorRgb8(255, 0, 0) : img.ColorRgb8(0, 0, 255);
      image.setPixel(x, y, c);
    }
  }
  return image;
}

void main() {
  group('PhotoEditEngine 几何变换', () {
    test('旋转及翻转后仍保持固定画框且边缘不透明', () {
      final src = img.Image(width: 96, height: 64, numChannels: 4);
      for (var y = 0; y < src.height; y++) {
        for (var x = 0; x < src.width; x++) {
          src.setPixelRgba(x, y, x * 2, y * 3, 100, 255);
        }
      }
      for (final angle in [0.0, 90.0, 180.0, -90.0]) {
        for (final flip in [false, true]) {
          final actual = PhotoEditEngine.apply(
              src,
              PhotoEditTransform(
                  rotationDegrees: angle,
                  flipHorizontal: flip,
                  perspectiveHorizontal: .6,
                  perspectiveVertical: -.3));
          expect(actual.width, src.width, reason: '画框宽度不能随旋转变化');
          expect(actual.height, src.height, reason: '画框高度不能随旋转变化');
          expect(actual.getPixel(0, 0).a, greaterThan(200));
          expect(actual.getPixel(actual.width - 1, actual.height - 1).a,
              greaterThan(200));
        }
      }
    });

    test('任意角度旋转把画框内接进图片，四角不留黑边', () {
      // 3 通道源图：画框必须内接进图片，否则中间角度会露出黑角。
      final src = img.Image(width: 96, height: 64, numChannels: 3);
      for (var y = 0; y < src.height; y++) {
        for (var x = 0; x < src.width; x++) {
          src.setPixel(x, y, img.ColorRgb8(x * 2 + 40, y * 3 + 40, 100));
        }
      }
      for (final angle in [15.0, 37.0, 45.0, -64.0]) {
        final out =
            PhotoEditEngine.apply(src, PhotoEditTransform(rotationDegrees: angle));
        expect(out.width, 96);
        expect(out.height, 64);
        for (final c in [
          [0, 0],
          [95, 0],
          [95, 63],
          [0, 63]
        ]) {
          final p = out.getPixel(c[0], c[1]);
          expect(p.r, greaterThan(20),
              reason: '旋转 $angle 画框角 (${c[0]},${c[1]}) 必须取到图片内容而不是黑角');
        }
      }
    });

    test('水平校正短边贴画框，画框内取到真实内容而非边缘涂抹', () {
      final src = img.Image(width: 41, height: 41, numChannels: 3);
      for (var y = 0; y < src.height; y++) {
        for (var x = 0; x < src.width; x++) {
          src.setPixel(x, y, img.ColorRgb8(100, y * 4 + 5, 50));
        }
      }
      // +100：短边在左且与画框对齐，左上附近应采样到内容行；
      // 旧几何把短边缩进画框内，左角被钳制到边缘行（g=5）。
      final out = PhotoEditEngine.apply(
          src, const PhotoEditTransform(perspectiveHorizontal: 1));
      expect(out.getPixel(2, 6).g, greaterThan(10),
          reason: '画框左上区域必须是梯形内的真实内容');
      final flipped = PhotoEditEngine.apply(
          src, const PhotoEditTransform(perspectiveHorizontal: -1));
      expect(flipped.getPixel(38, 6).g, greaterThan(10),
          reason: '-100 短边贴右，右侧区域同样是真实内容');
    });

    test('极限校正与任意角度组合不产生交叉四边形', () {
      for (final angle in [-180.0, -95.0, -45.0, 0.0, 37.0, 90.0, 175.0]) {
        for (final horizontal in [-1.0, 0.0, 1.0]) {
          for (final vertical in [-1.0, 0.0, 1.0]) {
            final t = PhotoEditTransform(
                rotationDegrees: angle,
                perspectiveHorizontal: horizontal,
                perspectiveVertical: vertical);
            expect(PhotoEditEngine.validQuad(t, width: 4000, height: 6000),
                isTrue);
            expect(
                PhotoEditEngine.homography(t, width: 4000, height: 6000)
                    .every((v) => v.isFinite),
                isTrue);
          }
        }
      }
    });

    test('恒等变换不改变尺寸与像素', () {
      final src = _redBlueImage(20, 10);
      final out = PhotoEditEngine.apply(src, const PhotoEditTransform());
      expect(out.width, 20);
      expect(out.height, 10);
      expect(out.getPixel(1, 1).r, src.getPixel(1, 1).r);
    });

    test('旋转 90 度后仍保持原画框比例', () {
      final src = _redBlueImage(20, 10);
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(rotationDegrees: 90),
      );
      expect(out.width, 20);
      expect(out.height, 10);
      expect(out.getPixel(0, 0).a, greaterThan(200));
    });

    test('垂直翻转交换上下像素', () {
      final src = img.Image(width: 4, height: 2);
      src.setPixel(0, 0, img.ColorRgb8(255, 0, 0));
      src.setPixel(0, 1, img.ColorRgb8(0, 0, 255));
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(flipVertical: true),
      );
      expect(out.getPixel(0, 1).r, greaterThan(200));
      expect(out.getPixel(0, 0).b, greaterThan(200));
    });

    test('水平翻转把左侧红色移到右侧', () {
      final src = _redBlueImage(20, 4);
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(flipHorizontal: true),
      );
      expect(out.getPixel(19, 0).r, greaterThan(200));
      expect(out.getPixel(0, 0).b, greaterThan(200));
    });

    test('裁切按比例缩小输出尺寸', () {
      final src = img.Image(width: 100, height: 100);
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(
          crop: CropRect(left: 0.25, top: 0.25, right: 0.75, bottom: 0.75),
        ),
      );
      expect(out.width, 50);
      expect(out.height, 50);
    });

    test('透视与扭曲保持输出尺寸不变', () {
      final src = _redBlueImage(40, 30);
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(
          perspectiveHorizontal: 0.3,
          distortTopLeftX: 0.05,
          distortTopRightY: -0.04,
        ),
      );
      expect(out.width, 40);
      expect(out.height, 30);
    });

    test('自由变换缩放后仍输出原画布尺寸', () {
      final src = _redBlueImage(40, 30);
      final out = PhotoEditEngine.apply(
        src,
        const PhotoEditTransform(scale: 1.5, offsetX: 0.1, offsetY: -0.1),
      );
      expect(out.width, 40);
      expect(out.height, 30);
    });

    test('自由变换缩小露出的画布是不透明黑幕布', () {
      final src = _redBlueImage(40, 30);
      final out = PhotoEditEngine.apply(
          src, const PhotoEditTransform(scale: 0.5));
      final edge = out.getPixel(0, 15);
      expect(edge.a, greaterThan(200), reason: '黑幕布必须不透明');
      expect(edge.r, 0);
      expect(edge.g, 0);
      expect(edge.b, 0);
      final center = out.getPixel(20, 15);
      expect(center.r + center.b, greaterThan(100),
          reason: '中心仍是原图内容');
    });

    test('组合变换顺序固定且可复现', () {
      final src = _redBlueImage(30, 20);
      const t = PhotoEditTransform(
        rotationDegrees: 90,
        flipHorizontal: true,
        crop: CropRect(left: 0.0, top: 0.1, right: 1.0, bottom: 0.9),
      );
      final a = PhotoEditEngine.apply(src, t);
      final b = PhotoEditEngine.apply(src, t);
      expect(a.width, b.width);
      expect(a.height, b.height);
      expect(a.getPixel(1, 1).r, b.getPixel(1, 1).r);
    });
  });

  group('PhotoEditController 撤销重做', () {
    test('快捷旋转始终归一化角度并可撤销', () {
      final c = PhotoEditController();
      c.rotateBy(-90);
      expect(c.value.rotationDegrees, -90);
      c.rotateBy(-90);
      expect(c.value.rotationDegrees, 180);
      c.rotateBy(-90);
      expect(c.value.rotationDegrees, 90);
      c.rotateBy(-90);
      expect(c.value.rotationDegrees, 0);
      c.undo();
      expect(c.value.rotationDegrees, 90);
      c.dispose();
    });
    test('初始不可撤销，更新后可撤销', () {
      final c = PhotoEditController();
      expect(c.canUndo, isFalse);
      c.update(const PhotoEditTransform(rotationDegrees: 90));
      expect(c.canUndo, isTrue);
      expect(c.canRedo, isFalse);
    });

    test('撤销后值回到初始，重做恢复', () {
      final c = PhotoEditController();
      c.update(const PhotoEditTransform(rotationDegrees: 90));
      c.undo();
      expect(c.value.rotationDegrees, 0);
      c.redo();
      expect(c.value.rotationDegrees, 90);
    });

    test('相同变换不写入历史', () {
      final c = PhotoEditController();
      c.update(const PhotoEditTransform(rotationDegrees: 90));
      c.update(const PhotoEditTransform(rotationDegrees: 90));
      c.undo();
      expect(c.canUndo, isFalse);
    });
  });

  group('裁切比例换算', () {
    test('1:1 在宽图上得到居中正方形', () {
      final r = cropRectForAspect(1.0, 200, 100);
      expect(r.width, closeTo(0.5, 0.001));
      expect(r.height, closeTo(1.0, 0.001));
      expect(r.left, closeTo(0.25, 0.001));
    });

    test('比例为 0 时返回全图', () {
      expect(cropRectForAspect(0, 100, 100).isFull, isTrue);
    });

    test('连续切换预设按全图重算，显示窗口与导出同为 3:2', () {
      final c = PhotoEditController();
      c.sourceWidth = 4000;
      c.sourceHeight = 2250;
      applyCropAspect(c, 4 / 3);
      applyCropAspect(c, 3 / 2);
      final crop = c.value.crop;
      expect(crop.width * 4000 / (crop.height * 2250), closeTo(1.5, .01),
          reason: '裁切窗口本身必须是 3:2，而不是靠导出兜底');
      final out = PhotoEditEngine.apply(
          img.Image(width: 4000, height: 2250), c.value);
      expect(out.width / out.height, closeTo(1.5, .01));
      c.dispose();
    });

    test('手动改过窗口高亮自定义，锁定比例显示预设，原图恢复全幅', () {
      final c = PhotoEditController();
      c.sourceWidth = 4000;
      c.sourceHeight = 3000;
      expect(activeCropAspectKey(0, c.value.crop), '原图');
      c.update(c.value.copyWith(
          crop: const CropRect(left: .1, top: .1, right: .9, bottom: .6)));
      expect(activeCropAspectKey(c.value.cropAspect, c.value.crop), '自定义');
      applyCropAspect(c, 3 / 2);
      expect(activeCropAspectKey(c.value.cropAspect, c.value.crop), '3:2');
      applyCropAspect(c, -1);
      expect(c.value.cropAspect, 0);
      expect(c.value.crop.isFull, isFalse, reason: '切自定义不能丢掉窗口');
      expect(activeCropAspectKey(c.value.cropAspect, c.value.crop), '自定义');
      applyCropAspect(c, 0);
      expect(c.value.crop.isFull, isTrue);
      expect(activeCropAspectKey(c.value.cropAspect, c.value.crop), '原图');
      c.dispose();
    });
  });
}
