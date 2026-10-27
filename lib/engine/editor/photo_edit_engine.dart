import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// 裁剪区域（归一化 0..1，左上原点）
class CropRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const CropRect({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 1.0,
    this.bottom = 1.0,
  });

  double get width => right - left;
  double get height => bottom - top;

  bool get isFull =>
      left <= 0.001 && top <= 0.001 && right >= 0.999 && bottom >= 0.999;

  CropRect copyWith(
          {double? left, double? top, double? right, double? bottom}) =>
      CropRect(
        left: left ?? this.left,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );

  Map<String, dynamic> toJson() =>
      {'left': left, 'top': top, 'right': right, 'bottom': bottom};

  factory CropRect.fromJson(Map<String, dynamic> json) => CropRect(
        left: (json['left'] as num?)?.toDouble() ?? 0.0,
        top: (json['top'] as num?)?.toDouble() ?? 0.0,
        right: (json['right'] as num?)?.toDouble() ?? 1.0,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 1.0,
      );

  @override
  bool operator ==(Object other) =>
      other is CropRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// 图片编辑变换描述：预览与导出共用的唯一数据源。
///
/// 处理顺序固定为：透视/扭曲 -> 旋转 -> 翻转 -> 自由变换(缩放/平移) -> 裁切。
class PhotoEditTransform {
  /// 任意角度旋转，单位度，正值顺时针；范围 -180..180。
  final double rotationDegrees;
  final bool flipHorizontal;
  final bool flipVertical;

  /// 透视校正：-1..1。
  final double perspectiveHorizontal;
  final double perspectiveVertical;

  /// 扭曲：四角偏移，归一化比例（基于对应边长）。
  final double distortTopLeftX;
  final double distortTopLeftY;
  final double distortTopRightX;
  final double distortTopRightY;
  final double distortBottomLeftX;
  final double distortBottomLeftY;
  final double distortBottomRightX;
  final double distortBottomRightY;

  /// 自由变换：围绕中心的缩放与平移（平移为归一化比例）。
  final double scale;
  final double offsetX;
  final double offsetY;

  final CropRect crop;
  final double cropAspect;

  const PhotoEditTransform({
    this.rotationDegrees = 0.0,
    this.flipHorizontal = false,
    this.flipVertical = false,
    this.perspectiveHorizontal = 0.0,
    this.perspectiveVertical = 0.0,
    this.distortTopLeftX = 0.0,
    this.distortTopLeftY = 0.0,
    this.distortTopRightX = 0.0,
    this.distortTopRightY = 0.0,
    this.distortBottomLeftX = 0.0,
    this.distortBottomLeftY = 0.0,
    this.distortBottomRightX = 0.0,
    this.distortBottomRightY = 0.0,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.crop = const CropRect(),
    this.cropAspect = 0,
  });

  bool get hasPerspective =>
      perspectiveHorizontal.abs() > 0.001 || perspectiveVertical.abs() > 0.001;

  bool get hasDistortion =>
      distortTopLeftX.abs() > 0.001 ||
      distortTopLeftY.abs() > 0.001 ||
      distortTopRightX.abs() > 0.001 ||
      distortTopRightY.abs() > 0.001 ||
      distortBottomLeftX.abs() > 0.001 ||
      distortBottomLeftY.abs() > 0.001 ||
      distortBottomRightX.abs() > 0.001 ||
      distortBottomRightY.abs() > 0.001;

  bool get hasTransform =>
      (scale - 1.0).abs() > 0.0001 ||
      offsetX.abs() > 0.0001 ||
      offsetY.abs() > 0.0001;

  bool get isIdentity =>
      rotationDegrees.abs() < 0.001 &&
      !flipHorizontal &&
      !flipVertical &&
      !hasPerspective &&
      !hasDistortion &&
      !hasTransform &&
      crop.isFull &&
      cropAspect == 0;

  PhotoEditTransform copyWith({
    double? rotationDegrees,
    bool? flipHorizontal,
    bool? flipVertical,
    double? perspectiveHorizontal,
    double? perspectiveVertical,
    double? distortTopLeftX,
    double? distortTopLeftY,
    double? distortTopRightX,
    double? distortTopRightY,
    double? distortBottomLeftX,
    double? distortBottomLeftY,
    double? distortBottomRightX,
    double? distortBottomRightY,
    double? scale,
    double? offsetX,
    double? offsetY,
    CropRect? crop,
    double? cropAspect,
  }) =>
      PhotoEditTransform(
        rotationDegrees: rotationDegrees ?? this.rotationDegrees,
        flipHorizontal: flipHorizontal ?? this.flipHorizontal,
        flipVertical: flipVertical ?? this.flipVertical,
        perspectiveHorizontal:
            perspectiveHorizontal ?? this.perspectiveHorizontal,
        perspectiveVertical: perspectiveVertical ?? this.perspectiveVertical,
        distortTopLeftX: distortTopLeftX ?? this.distortTopLeftX,
        distortTopLeftY: distortTopLeftY ?? this.distortTopLeftY,
        distortTopRightX: distortTopRightX ?? this.distortTopRightX,
        distortTopRightY: distortTopRightY ?? this.distortTopRightY,
        distortBottomLeftX: distortBottomLeftX ?? this.distortBottomLeftX,
        distortBottomLeftY: distortBottomLeftY ?? this.distortBottomLeftY,
        distortBottomRightX: distortBottomRightX ?? this.distortBottomRightX,
        distortBottomRightY: distortBottomRightY ?? this.distortBottomRightY,
        scale: scale ?? this.scale,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
        crop: crop ?? this.crop,
        cropAspect: cropAspect ?? this.cropAspect,
      );

  @override
  bool operator ==(Object other) =>
      other is PhotoEditTransform &&
      other.rotationDegrees == rotationDegrees &&
      other.flipHorizontal == flipHorizontal &&
      other.flipVertical == flipVertical &&
      other.perspectiveHorizontal == perspectiveHorizontal &&
      other.perspectiveVertical == perspectiveVertical &&
      other.distortTopLeftX == distortTopLeftX &&
      other.distortTopLeftY == distortTopLeftY &&
      other.distortTopRightX == distortTopRightX &&
      other.distortTopRightY == distortTopRightY &&
      other.distortBottomLeftX == distortBottomLeftX &&
      other.distortBottomLeftY == distortBottomLeftY &&
      other.distortBottomRightX == distortBottomRightX &&
      other.distortBottomRightY == distortBottomRightY &&
      other.scale == scale &&
      other.offsetX == offsetX &&
      other.offsetY == offsetY &&
      other.crop == crop &&
      other.cropAspect == cropAspect;

  @override
  int get hashCode => Object.hash(
        rotationDegrees,
        flipHorizontal,
        flipVertical,
        perspectiveHorizontal,
        perspectiveVertical,
        distortTopLeftX,
        distortTopLeftY,
        distortTopRightX,
        distortTopRightY,
        distortBottomLeftX,
        distortBottomLeftY,
        distortBottomRightX,
        distortBottomRightY,
        scale,
        offsetX,
        offsetY,
        crop,
        cropAspect,
      );

  Map<String, dynamic> toJson() => {
        'rotationDegrees': rotationDegrees,
        'flipHorizontal': flipHorizontal,
        'flipVertical': flipVertical,
        'perspectiveHorizontal': perspectiveHorizontal,
        'perspectiveVertical': perspectiveVertical,
        'distortTopLeftX': distortTopLeftX,
        'distortTopLeftY': distortTopLeftY,
        'distortTopRightX': distortTopRightX,
        'distortTopRightY': distortTopRightY,
        'distortBottomLeftX': distortBottomLeftX,
        'distortBottomLeftY': distortBottomLeftY,
        'distortBottomRightX': distortBottomRightX,
        'distortBottomRightY': distortBottomRightY,
        'scale': scale,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'crop': crop.toJson(),
        'cropAspect': cropAspect,
      };

  factory PhotoEditTransform.fromJson(Map<String, dynamic> json) =>
      PhotoEditTransform(
        rotationDegrees: (json['rotationDegrees'] as num?)?.toDouble() ?? 0.0,
        flipHorizontal: json['flipHorizontal'] as bool? ?? false,
        flipVertical: json['flipVertical'] as bool? ?? false,
        perspectiveHorizontal:
            (json['perspectiveHorizontal'] as num?)?.toDouble() ?? 0.0,
        perspectiveVertical:
            (json['perspectiveVertical'] as num?)?.toDouble() ?? 0.0,
        distortTopLeftX: (json['distortTopLeftX'] as num?)?.toDouble() ?? 0.0,
        distortTopLeftY: (json['distortTopLeftY'] as num?)?.toDouble() ?? 0.0,
        distortTopRightX: (json['distortTopRightX'] as num?)?.toDouble() ?? 0.0,
        distortTopRightY: (json['distortTopRightY'] as num?)?.toDouble() ?? 0.0,
        distortBottomLeftX:
            (json['distortBottomLeftX'] as num?)?.toDouble() ?? 0.0,
        distortBottomLeftY:
            (json['distortBottomLeftY'] as num?)?.toDouble() ?? 0.0,
        distortBottomRightX:
            (json['distortBottomRightX'] as num?)?.toDouble() ?? 0.0,
        distortBottomRightY:
            (json['distortBottomRightY'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        offsetX: (json['offsetX'] as num?)?.toDouble() ?? 0.0,
        offsetY: (json['offsetY'] as num?)?.toDouble() ?? 0.0,
        cropAspect: (json['cropAspect'] as num?)?.toDouble() ?? 0,
        crop: json['crop'] is Map
            ? CropRect.fromJson(Map<String, dynamic>.from(json['crop'] as Map))
            : const CropRect(),
      );
}

/// 纯函数变换管线：预览与保存共用，保证所见即所得。
class PhotoEditEngine {
  PhotoEditEngine._();

  static bool needsProcessing(PhotoEditTransform t) => !t.isIdentity;

  /// 固定输出画框：旋转和透视只改变图片内容，不让画框随包围盒变化。
  /// 裁切比例或非全幅裁切是唯一会主动改变画框尺寸的输入。
  static ({int width, int height}) frameDimensions(
      int width, int height, PhotoEditTransform t,
      {bool includeCrop = true}) {
    if (includeCrop && (!t.crop.isFull || t.cropAspect > 0)) {
      final r = cropBounds(width, height, t.crop, t.cropAspect);
      return (width: r.width, height: r.height);
    }
    return (width: math.max(1, width), height: math.max(1, height));
  }

  /// 按固定顺序把变换应用到原始图像。
  static img.Image apply(img.Image source, PhotoEditTransform t) {
    if (t.toJson().values.whereType<num>().any((v) => !v.isFinite) ||
        t.scale <= 0 ||
        t.cropAspect < 0 ||
        t.crop.toJson().values.any((v) => !(v as double).isFinite) ||
        t.crop.width <= 0 ||
        t.crop.height <= 0) {
      throw ArgumentError('无效的图像变换参数');
    }
    var out = source;
    final frame = frameDimensions(source.width, source.height, t,
        includeCrop: false);

    if (t.hasPerspective || t.hasDistortion) {
      out = _applyPerspective(out, t);
    }
    if (t.rotationDegrees.abs() > 0.001) {
      out = _applyRotation(out, t.rotationDegrees, frame.width, frame.height);
    }
    if (t.flipHorizontal) {
      out = _flip(out, img.FlipDirection.horizontal);
    }
    if (t.flipVertical) {
      out = _flip(out, img.FlipDirection.vertical);
    }
    if (t.hasTransform) {
      out = _applyFreeTransform(out, t);
    }
    if (!t.crop.isFull || t.cropAspect > 0) {
      out = _applyCrop(out, t.crop, t.cropAspect);
    }
    return out;
  }

  static ({int left, int top, int width, int height}) cropBounds(
      int width, int height, CropRect crop,
      [double aspect = 0]) {
    final left =
        (crop.left.clamp(0.0, 1.0) * width).round().clamp(0, width - 1);
    final top =
        (crop.top.clamp(0.0, 1.0) * height).round().clamp(0, height - 1);
    final right = (crop.right.clamp(0.0, 1.0) * width).round();
    final bottom = (crop.bottom.clamp(0.0, 1.0) * height).round();
    final availableW = math.max(1, right - left),
        availableH = math.max(1, bottom - top);
    var w = availableW, h = availableH;
    if (aspect > 0) {
      if (w / h > aspect) {
        w = math.max(1, (h * aspect).round());
      } else {
        h = math.max(1, (w / aspect).round());
      }
    }
    return (
      left: left + (availableW - w) ~/ 2,
      top: top + (availableH - h) ~/ 2,
      width: w,
      height: h
    );
  }

  static img.Image _applyCrop(img.Image src, CropRect crop,
      [double aspect = 0]) {
    final r = cropBounds(src.width, src.height, crop, aspect);
    final sd = src.numFrames == 1 ? _u8bytes(src) : null;
    if (sd != null) {
      final out = img.Image(
              width: r.width, height: r.height, numChannels: src.numChannels)
        ..exif = src.exif;
      final od = _u8bytes(out)!;
      final channels = src.numChannels;
      final rowBytes = r.width * channels, srcRow = src.width * channels;
      for (var row = 0; row < r.height; row++) {
        od.setRange(row * rowBytes, (row + 1) * rowBytes, sd,
            (r.top + row) * srcRow + r.left * channels);
      }
      return out;
    }
    return img.copyCrop(src,
        x: r.left, y: r.top, width: r.width, height: r.height);
  }

  /// uint8 非调色板图的紧凑字节视图；16 位等格式返回 null，走通用慢路径。
  static Uint8List? _u8bytes(img.Image image) {
    if (image.hasPalette || image.format != img.Format.uint8) return null;
    final bytes = image.toUint8List();
    return bytes.length == image.width * image.height * image.numChannels
        ? bytes
        : null;
  }

  /// 裸字节双线性采样：u/v 须已钳到 [0..w-1]/[0..h-1]，结果写入 o。
  /// package:image 的 getPixelInterpolate 每像素分配 Color 对象，
  /// 12MP 要 5 秒以上，大图保存全靠这条快路径。
  static void _sampleU8(Uint8List data, int w, int h, int c, double u,
      double v, Uint8List o) {
    final x0 = u.floor(), y0 = v.floor();
    final x1 = x0 + 1 < w ? x0 + 1 : x0;
    final y1 = y0 + 1 < h ? y0 + 1 : y0;
    final fx = u - x0, fy = v - y0;
    final i00 = (y0 * w + x0) * c, i10 = (y0 * w + x1) * c;
    final i01 = (y1 * w + x0) * c, i11 = (y1 * w + x1) * c;
    for (var k = 0; k < c; k++) {
      final top = data[i00 + k] + (data[i10 + k] - data[i00 + k]) * fx;
      final bottom = data[i01 + k] + (data[i11 + k] - data[i01 + k]) * fx;
      final value = top + (bottom - top) * fy + .5;
      o[k] = value < 0 ? 0 : (value > 255 ? 255 : value.toInt());
    }
  }

  static img.Image _flip(img.Image src, img.FlipDirection direction) {
    final sd = src.numFrames == 1 ? _u8bytes(src) : null;
    if (sd == null) return img.copyFlip(src, direction: direction);
    final out = src.clone();
    final od = _u8bytes(out)!;
    final w = src.width, h = src.height, c = src.numChannels;
    final rowBytes = w * c;
    if (direction != img.FlipDirection.vertical) {
      for (var y = 0; y < h; y++) {
        final o = y * rowBytes;
        for (var x = 0; x < (w + 1) ~/ 2; x++) {
          final a = o + x * c, b = o + (w - 1 - x) * c;
          for (var k = 0; k < c; k++) {
            final t = od[a + k];
            od[a + k] = od[b + k];
            od[b + k] = t;
          }
        }
      }
    }
    if (direction != img.FlipDirection.horizontal) {
      final tmp = Uint8List(rowBytes);
      for (var y = 0; y < h ~/ 2; y++) {
        final a = y * rowBytes, b = (h - 1 - y) * rowBytes;
        tmp.setAll(0, Uint8List.sublistView(od, a, a + rowBytes));
        od.setRange(a, a + rowBytes, od, b);
        od.setRange(b, b + rowBytes, tmp);
      }
    }
    return out;
  }


  /// 原图单位矩形投影到目标四边形，顺序为左上、右上、右下、左下。
  ///
  /// 水平/垂直校正把图片拉成等腰梯形：短边与画框同侧对齐（贴住画框边），
  /// 对面的长边向外扩展，保证画框内接于梯形、只裁掉溢出部分。
  /// 长边除纵向张开外还沿画边方向推出去（像素为纵向的一半），
  /// 预览里梯形轮廓能从画框旁露出，导出则裁掉这 6% 左右的边料。
  static List<math.Point<double>> corners(PhotoEditTransform t,
      {double width = 1, double height = 1}) {
    final h = t.perspectiveHorizontal.clamp(-1.0, 1.0) * .2;
    final v = t.perspectiveVertical.clamp(-1.0, 1.0) * .2;
    final hx = h * .5 * height / width;
    final ey = v * .5 * width / height;
    const unit = [
      math.Point(0.0, 0.0),
      math.Point(1.0, 0.0),
      math.Point(1.0, 1.0),
      math.Point(0.0, 1.0)
    ];
    var points = unit.toList();
    if (t.hasPerspective) {
      final projection = _quadHomography(unit, [
        math.Point(math.min(0, math.min(v, hx)), math.min(0, math.min(h, ey))),
        math.Point(
            math.max(1, math.max(1 - v, 1 + hx)), math.min(0, math.min(-h, ey))),
        math.Point(math.max(1, math.max(1 + v, 1 + hx)),
            math.max(1, math.max(1 + h, 1 + ey))),
        math.Point(
            math.min(0, math.min(-v, hx)), math.max(1, math.max(1 - h, 1 + ey))),
      ]);
      final angle = t.rotationDegrees * math.pi / 180,
          co = math.cos(angle),
          si = math.sin(angle);
      final rw = width * co.abs() + height * si.abs(),
          rh = width * si.abs() + height * co.abs();
      // R^-1 * P * R：校正轴以当前显示方向为准，处理顺序仍保持透视先于旋转。
      points = unit.map((p) {
        var x = ((p.x - .5) * width * co - (p.y - .5) * height * si) / rw + .5;
        var y = ((p.x - .5) * width * si + (p.y - .5) * height * co) / rh + .5;
        if (t.flipHorizontal) x = 1 - x;
        if (t.flipVertical) y = 1 - y;
        final d = projection[6] * x + projection[7] * y + 1;
        var px = (projection[0] * x + projection[1] * y + projection[2]) / d;
        var py = (projection[3] * x + projection[4] * y + projection[5]) / d;
        if (t.flipHorizontal) px = 1 - px;
        if (t.flipVertical) py = 1 - py;
        final dx = (px - .5) * rw, dy = (py - .5) * rh;
        return math.Point((dx * co + dy * si) / width + .5,
            (-dx * si + dy * co) / height + .5);
      }).toList();
    }
    return [
      points[0] + math.Point(t.distortTopLeftX, t.distortTopLeftY),
      points[1] + math.Point(t.distortTopRightX, t.distortTopRightY),
      points[2] + math.Point(t.distortBottomRightX, t.distortBottomRightY),
      points[3] + math.Point(t.distortBottomLeftX, t.distortBottomLeftY)
    ];
  }

  static bool validQuad(PhotoEditTransform t,
      {double width = 1, double height = 1}) {
    final p = corners(t, width: width, height: height);
    for (var i = 0; i < 4; i++) {
      final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (!cross.isFinite || cross < .02) return false;
    }
    return true;
  }

  static List<double> homography(PhotoEditTransform t,
      {bool inverse = false, double width = 1, double height = 1}) {
    if (!validQuad(t, width: width, height: height))
      throw ArgumentError('四边形不能交叉或退化');
    final dest = corners(t, width: width, height: height);
    const unit = [
      math.Point(0.0, 0.0),
      math.Point(1.0, 0.0),
      math.Point(1.0, 1.0),
      math.Point(0.0, 1.0)
    ];
    return inverse ? _quadHomography(dest, unit) : _quadHomography(unit, dest);
  }

  static List<double> _quadHomography(
      List<math.Point<double>> source, List<math.Point<double>> target) {
    final rows = <List<double>>[];
    for (var i = 0; i < 4; i++) {
      final from = source[i], to = target[i];
      final x = from.x, y = from.y, u = to.x, v = to.y;
      rows.add([x, y, 1, 0, 0, 0, -u * x, -u * y, u]);
      rows.add([0, 0, 0, x, y, 1, -v * x, -v * y, v]);
    }
    for (var col = 0; col < 8; col++) {
      var pivot = col;
      for (var row = col + 1; row < 8; row++) {
        if (rows[row][col].abs() > rows[pivot][col].abs()) pivot = row;
      }
      if (rows[pivot][col].abs() < 1e-9) throw ArgumentError('投影不可逆');
      final temp = rows[col];
      rows[col] = rows[pivot];
      rows[pivot] = temp;
      final divisor = rows[col][col];
      for (var j = col; j < 9; j++) {
        rows[col][j] /= divisor;
      }
      for (var row = 0; row < 8; row++) {
        if (row == col) continue;
        final factor = rows[row][col];
        for (var j = col; j < 9; j++) {
          rows[row][j] -= factor * rows[col][j];
        }
      }
    }
    return rows.map((row) => row[8]).toList();
  }

  static img.Image _applyPerspective(img.Image src, PhotoEditTransform t) {
    final m = homography(t,
        inverse: true,
        width: src.width.toDouble(),
        height: src.height.toDouble());
    final out = img.Image(
            width: src.width, height: src.height, numChannels: src.numChannels)
      ..exif = src.exif;
    final w = math.max(1, src.width - 1), h = math.max(1, src.height - 1);
    final channels = src.numChannels;
    final sd = _u8bytes(src), od = _u8bytes(out);
    if (sd != null && od != null) {
      // 画布外（投影趋于无穷的极少数像素）保持黑幕布。
      out.clear(img.ColorRgba8(0, 0, 0, 255));
      final sample = Uint8List(channels);
      final maxX = w.toDouble(), maxY = h.toDouble();
      for (var y = 0; y < src.height; y++) {
        final rowOff = y * src.width * channels;
        final ny = y / h;
        for (var x = 0; x < src.width; x++) {
          final nx = x / w, d = m[6] * nx + m[7] * ny + 1;
          if (d.abs() < 1e-9) continue;
          final u = (m[0] * nx + m[1] * ny + m[2]) / d * w;
          final v = (m[3] * nx + m[4] * ny + m[5]) / d * h;
          // 校正四边形可能把边缘映射到画框外，钳制到原图边缘，
          // 避免透视结果出现透明三角和黑色背景。
          _sampleU8(
              sd,
              src.width,
              src.height,
              channels,
              u < 0 ? 0.0 : (u > maxX ? maxX : u),
              v < 0 ? 0.0 : (v > maxY ? maxY : v),
              sample);
          od.setAll(rowOff + x * channels, sample);
        }
      }
      return out;
    }
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final nx = x / w, ny = y / h, d = m[6] * nx + m[7] * ny + 1;
        if (d.abs() < 1e-9) continue;
        final u = (m[0] * nx + m[1] * ny + m[2]) / d,
            v = (m[3] * nx + m[4] * ny + m[5]) / d;
        out.setPixel(
            x,
            y,
            src.getPixelInterpolate(u.clamp(0, 1) * w, v.clamp(0, 1) * h,
                interpolation: img.Interpolation.linear));
      }
    }
    return out;
  }

  static img.Image _applyFreeTransform(img.Image src, PhotoEditTransform t) {
    final scale = t.scale <= 0 ? 1.0 : t.scale;
    if ((scale - 1.0).abs() <= 0.0001 &&
        t.offsetX.abs() <= 0.0001 &&
        t.offsetY.abs() <= 0.0001) {
      return src;
    }
    final w = src.width, h = src.height;
    final out =
        img.Image(width: w, height: h, numChannels: src.numChannels)
          ..exif = src.exif;
    final channels = src.numChannels;
    final sd = _u8bytes(src), od = _u8bytes(out);
    if (sd != null && od != null) {
      // 黑幕布：画布外铺黑，预览、导出一致。
      out.clear(img.ColorRgba8(0, 0, 0, 255));
      final cx = w / 2, cy = h / 2;
      final ox = t.offsetX * w, oy = t.offsetY * h;
      final maxX = (w - 1).toDouble(), maxY = (h - 1).toDouble();
      final sample = Uint8List(channels);
      for (var y = 0; y < h; y++) {
        // 与预览画布同一映射：q = (p - c) * scale + c + offset。
        final v = (y + .5 - cy - oy) / scale + cy;
        if (v < 0 || v > maxY) continue;
        final rowOff = y * w * channels;
        for (var x = 0; x < w; x++) {
          final u = (x + .5 - cx - ox) / scale + cx;
          if (u < 0 || u > maxX) continue;
          _sampleU8(sd, w, h, channels, u, v, sample);
          od.setAll(rowOff + x * channels, sample);
        }
      }
      return out;
    }
    final newW = math.max(1, (w * scale).round());
    final newH = math.max(1, (h * scale).round());
    final scaled = scale == 1.0
        ? src
        : img.copyResize(
            src,
            width: newW,
            height: newH,
            interpolation: img.Interpolation.linear,
          );
    final canvas =
        img.Image(width: w, height: h, numChannels: src.numChannels)
          ..exif = src.exif;
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));
    final dx = ((w - newW) / 2 + t.offsetX * w).round();
    final dy = ((h - newH) / 2 + t.offsetY * h).round();
    img.compositeImage(canvas, scaled,
        dstX: dx, dstY: dy, dstW: newW, dstH: newH);
    return canvas;
  }

  /// 旋转并放大，让画框内接于旋转后的图片：四角都取到图片内容，
  /// 溢出部分裁掉。缩放系数由画框角反推，不能用外接矩形比例
  ///（外接矩形填满画框时，中间角度的画框角仍在图片外，露出底图）。
  static img.Image _applyRotation(
      img.Image src, double degrees, int frameWidth, int frameHeight) {
    final rad = degrees * math.pi / 180;
    final co = math.cos(rad), si = math.sin(rad);
    final aco = co.abs(), asi = si.abs();
    final s = math.max(
        (frameWidth * aco + frameHeight * asi) / src.width,
        (frameWidth * asi + frameHeight * aco) / src.height);
    final out = img.Image(
            width: frameWidth, height: frameHeight, numChannels: src.numChannels)
      ..exif = src.exif;
    final cxs = src.width / 2, cys = src.height / 2;
    final maxX = src.width - 1, maxY = src.height - 1;
    final channels = src.numChannels;
    final sd = _u8bytes(src), od = _u8bytes(out);
    if (sd != null && od != null) {
      final sample = Uint8List(channels);
      for (var y = 0; y < frameHeight; y++) {
        final dy = (y - frameHeight / 2) / s;
        final rowOff = y * frameWidth * channels;
        for (var x = 0; x < frameWidth; x++) {
          final dx = (x - frameWidth / 2) / s;
          final px = dx * co + dy * si + cxs;
          final py = -dx * si + dy * co + cys;
          // 内接构造下采样点必在图内，clamp 只兜浮点误差。
          _sampleU8(
              sd,
              src.width,
              src.height,
              channels,
              px < 0 ? 0.0 : (px > maxX ? maxX.toDouble() : px),
              py < 0 ? 0.0 : (py > maxY ? maxY.toDouble() : py),
              sample);
          od.setAll(rowOff + x * channels, sample);
        }
      }
      return out;
    }
    for (var y = 0; y < frameHeight; y++) {
      for (var x = 0; x < frameWidth; x++) {
        final dx = (x - frameWidth / 2) / s, dy = (y - frameHeight / 2) / s;
        final px = dx * co + dy * si + cxs;
        final py = -dx * si + dy * co + cys;
        out.setPixel(
            x,
            y,
            src.getPixelInterpolate(px.clamp(0.0, maxX.toDouble()),
                py.clamp(0.0, maxY.toDouble()),
                interpolation: img.Interpolation.linear));
      }
    }
    return out;
  }

}

/// 每个编辑会话一个 worker：只解码一次，所有大图处理都在后台。
class PhotoEditWorker {
  Isolate? _isolate;
  SendPort? _port;
  final ReceivePort _replies = ReceivePort();
  Completer<SendPort>? _ready;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _id = 0;
  bool _disposed = false;

  Future<Map<String, dynamic>> open(Uint8List bytes) async {
    final ready = _ready = Completer<SendPort>();
    ready.future.ignore();
    _replies.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      final row = Map<String, dynamic>.from(message as Map);
      final completer = _pending.remove(row['id']);
      if (completer == null) return;
      if (row['error'] != null) {
        completer.completeError(StateError(row['error'] as String));
      } else {
        completer.complete(row);
      }
    });
    final isolate = await Isolate.spawn(_photoWorkerMain, _replies.sendPort);
    if (_disposed) {
      isolate.kill();
      throw StateError('编辑会话已关闭');
    }
    _isolate = isolate;
    _port = await ready.future;
    return _send({'mode': 'open', 'bytes': bytes});
  }

  Future<Map<String, dynamic>> render(PhotoEditTransform transform,
          {bool preview = true,
          bool omitCrop = false,
          String format = 'png'}) =>
      _send({
        'mode': 'render',
        'transform': transform.toJson(),
        'preview': preview,
        'omitCrop': omitCrop,
        'format': format
      });

  Future<Map<String, dynamic>> _send(Map<String, dynamic> request) {
    if (_disposed || _port == null) return Future.error(StateError('编辑会话不可用'));
    final id = ++_id, completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _port!.send({...request, 'id': id});
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _isolate?.kill(priority: Isolate.immediate);
    _replies.close();
    if (_ready != null && !_ready!.isCompleted)
      _ready!.completeError(StateError('编辑会话已关闭'));
    for (final c in _pending.values) {
      c.completeError(StateError('编辑会话已关闭'));
    }
    _pending.clear();
  }
}

void _photoWorkerMain(SendPort reply) {
  final requests = ReceivePort();
  reply.send(requests.sendPort);
  img.Image? original, previewSource;
  requests.listen((dynamic message) {
    final request = Map<String, dynamic>.from(message as Map);
    try {
      if (request['mode'] == 'open') {
        final decoded = img.decodeImage(request['bytes'] as Uint8List);
        if (decoded == null) throw StateError('图片解码失败');
        final orientation = decoded.exif.imageIfd.orientation;
        final oriented = orientation == null || orientation == 1
            ? decoded
            : img.bakeOrientation(decoded);
        original = oriented.numChannels == 4
            ? oriented
            : oriented.convert(numChannels: 4);
        final longest = math.max(original!.width, original!.height);
        previewSource = longest <= 1024
            ? original
            : img.copyResize(original!,
                width: math.max(1, (original!.width * 1024 / longest).round()),
                height:
                    math.max(1, (original!.height * 1024 / longest).round()),
                interpolation: img.Interpolation.average);
        reply.send({
          'id': request['id'],
          'width': original!.width,
          'height': original!.height,
          'previewBytes': Uint8List.fromList(img.encodePng(previewSource!)),
        });
        return;
      }
      if (original == null) throw StateError('没有工作图');
      var t = PhotoEditTransform.fromJson(
          Map<String, dynamic>.from(request['transform'] as Map));
      if (request['omitCrop'] == true)
        t = t.copyWith(crop: const CropRect(), cropAspect: 0);
      final src = request['preview'] == true ? previewSource! : original!;
      final geometry = PhotoEditEngine.apply(
          src, t.copyWith(crop: const CropRect(), cropAspect: 0));
      var result = t.crop.isFull && t.cropAspect == 0
          ? geometry
          : PhotoEditEngine._applyCrop(geometry, t.crop, t.cropAspect);
      // JPEG 编码器对 RGBA 会自动按白底合成，无需先转 3 通道（省一次全图拷贝）。
      final bytes = request['format'] == 'jpg'
          ? img.encodeJpg(result, quality: 92)
          : img.encodePng(result);
      reply.send({
        'id': request['id'],
        'bytes': Uint8List.fromList(bytes),
        'width': result.width,
        'height': result.height,
        'canvasWidth': geometry.width,
        'canvasHeight': geometry.height
      });
    } catch (e) {
      reply.send({'id': request['id'], 'error': e.toString()});
    }
  });
}
