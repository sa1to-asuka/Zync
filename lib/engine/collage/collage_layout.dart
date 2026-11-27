import 'dart:math' as math;
import 'dart:ui';

import '../../l10n/l10n.dart';

/// 拼图导出画布比例。
///
/// 短边固定 [CollageAspect.shortSide]（长边超限时等比封顶，避免超长比例内存溢出）。
enum CollageAspect {
  square('1:1', 1, 1),
  portrait34('3:4', 3, 4),
  portrait45('4:5', 4, 5),
  landscape43('4:3', 4, 3),
  landscape32('3:2', 3, 2),
  portrait23('2:3', 2, 3),
  story916('9:16', 9, 16),
  cinema169('16:9', 16, 9);

  final String label;
  final int w;
  final int h;

  const CollageAspect(this.label, this.w, this.h);

  /// 导出画布基准长边像素（1:1 → 2048×2048，3:4 → 1536×2048）。
  static const double shortSide = 2048;

  /// 导出画布像素尺寸（长边固定为 [shortSide]，短边按比例计算）。
  Size get outputSize => w >= h
      ? Size(shortSide, shortSide * h / w)
      : Size(shortSide * w / h, shortSide);
}

/// 拼图边框粗细（相对画布短边）。
///
/// 边框同时作用于成品外框与图片之间的分界线；[none] 表示完全没有线条。
enum CollageBorder {
  none('无', 0),
  s('S', 0.006),
  m('M', 0.012),
  l('L', 0.020);

  final String label;
  final double ratio;

  const CollageBorder(this.label, this.ratio);

  String get trLabel => L10n.tr(label);
}

/// 拼图拼接方式。每个模板只对固定张数 [count] 有效。
///
/// 单元格坐标为归一化 0..1 矩形（[cells]）；`topBottomDiagonal` 为特殊模板，
/// 单元格是斜切多边形而非矩形，[cells] 仅返回其外接矩形（数量校验用），
/// 实际绘制走 [CollageLayout.diagonalPolys]。
enum CollageTemplate {
  // ---- 2 张 ----
  topBottom('top_bottom', '上下', 2),
  leftRight('left_right', '左右', 2),
  topBottom21('top_bottom_21', '上 2 : 下 1', 2),
  leftRight21('left_right_21', '左 2 : 右 1', 2),
  topBottomDiagonal('top_bottom_diagonal', '上下中央斜切', 2),
  topBottom12('top_bottom_12', '上 1 : 下 2', 2),
  leftRight12('left_right_12', '左 1 : 右 2', 2),

  // ---- 3 张 ----
  threeTop1Bottom2('three_top1_bottom2', '上 1 下 2', 3),
  threeTop2Bottom1('three_top2_bottom1', '上 2 下 1', 3),
  threeLeft1Right2('three_left1_right2', '左 1 右 2', 3),
  threeColumns('three_columns', '三列', 3),

  // ---- 4 张 ----
  fourGrid2x2('four_grid2x2', '2 × 2', 4),
  fourTop1Bottom3('four_top1_bottom3', '上 1 下 3', 4),
  fourLeft1Right3('four_left1_right3', '左 1 右 3', 4),
  fourColumns('four_columns', '四列', 4),

  // ---- 5 张 ----
  fiveTop2Bottom3('five_top2_bottom3', '上 2 下 3', 5),
  fiveTop1Bottom4('five_top1_bottom4', '上 1 下 4', 5),
  fiveLeft1Right4('five_left1_right4', '左 1 右 4', 5),

  // ---- 6 张 ----
  sixGrid3x2('six_grid3x2', '上 3 下 3', 6),
  sixLeft2Right4('six_left2_right4', '左 2 右 4', 6),

  // ---- 7 张 ----
  sevenTop1Bottom6('seven_top1_bottom6', '上 1 下 6', 7),
  sevenTop3Bottom4('seven_top3_bottom4', '上 3 下 4', 7),

  // ---- 8 张 ----
  eightTop4Bottom4('eight_top4_bottom4', '上 4 下 4', 8),
  eightGrid2x4('eight_grid2x4', '两列 × 4', 8),

  // ---- 9 张 ----
  nineGrid3x3('nine_grid3x3', '3 × 3', 9);

  final String id;
  final String label;
  final int count;

  const CollageTemplate(this.id, this.label, this.count);

  String get trLabel => L10n.tr(label);

  bool get isDiagonal => this == CollageTemplate.topBottomDiagonal;

  /// 指定张数可用的拼接方式。
  static List<CollageTemplate> forCount(int count) =>
      CollageTemplate.values.where((t) => t.count == count).toList(growable: false);

  /// 归一化单元格矩形（左上为原点，右下为 (1,1)）。
  List<Rect> get cells {
    switch (this) {
      case CollageTemplate.topBottom:
        return const [Rect.fromLTRB(0, 0, 1, .5), Rect.fromLTRB(0, .5, 1, 1)];
      case CollageTemplate.leftRight:
        return const [Rect.fromLTRB(0, 0, .5, 1), Rect.fromLTRB(.5, 0, 1, 1)];
      case CollageTemplate.topBottom21:
        return const [Rect.fromLTRB(0, 0, 1, 2 / 3), Rect.fromLTRB(0, 2 / 3, 1, 1)];
      case CollageTemplate.leftRight21:
        return const [Rect.fromLTRB(0, 0, 2 / 3, 1), Rect.fromLTRB(2 / 3, 0, 1, 1)];
      case CollageTemplate.topBottom12:
        return const [Rect.fromLTRB(0, 0, 1, 1 / 3), Rect.fromLTRB(0, 1 / 3, 1, 1)];
      case CollageTemplate.leftRight12:
        return const [Rect.fromLTRB(0, 0, 1 / 3, 1), Rect.fromLTRB(1 / 3, 0, 1, 1)];
      case CollageTemplate.topBottomDiagonal:
        // 斜切模板的实际单元格是多边形，这里返回上下外接矩形仅供数量校验。
        return const [
          Rect.fromLTRB(0, 0, 1, .5 + kCollageDiagonalSlant),
          Rect.fromLTRB(0, .5 - kCollageDiagonalSlant, 1, 1),
        ];

      case CollageTemplate.threeTop1Bottom2:
        return const [
          Rect.fromLTRB(0, 0, 1, .5),
          Rect.fromLTRB(0, .5, .5, 1),
          Rect.fromLTRB(.5, .5, 1, 1),
        ];
      case CollageTemplate.threeTop2Bottom1:
        return const [
          Rect.fromLTRB(0, 0, .5, .5),
          Rect.fromLTRB(.5, 0, 1, .5),
          Rect.fromLTRB(0, .5, 1, 1),
        ];
      case CollageTemplate.threeLeft1Right2:
        return const [
          Rect.fromLTRB(0, 0, .5, 1),
          Rect.fromLTRB(.5, 0, 1, .5),
          Rect.fromLTRB(.5, .5, 1, 1),
        ];
      case CollageTemplate.threeColumns:
        return const [
          Rect.fromLTRB(0, 0, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, 0, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, 0, 1, 1),
        ];

      case CollageTemplate.fourGrid2x2:
        return const [
          Rect.fromLTRB(0, 0, .5, .5),
          Rect.fromLTRB(.5, 0, 1, .5),
          Rect.fromLTRB(0, .5, .5, 1),
          Rect.fromLTRB(.5, .5, 1, 1),
        ];
      case CollageTemplate.fourTop1Bottom3:
        return const [
          Rect.fromLTRB(0, 0, 1, .5),
          Rect.fromLTRB(0, .5, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, .5, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, .5, 1, 1),
        ];
      case CollageTemplate.fourLeft1Right3:
        return const [
          Rect.fromLTRB(0, 0, .5, 1),
          Rect.fromLTRB(.5, 0, 1, 1 / 3),
          Rect.fromLTRB(.5, 1 / 3, 1, 2 / 3),
          Rect.fromLTRB(.5, 2 / 3, 1, 1),
        ];
      case CollageTemplate.fourColumns:
        return const [
          Rect.fromLTRB(0, 0, .25, 1),
          Rect.fromLTRB(.25, 0, .5, 1),
          Rect.fromLTRB(.5, 0, .75, 1),
          Rect.fromLTRB(.75, 0, 1, 1),
        ];

      case CollageTemplate.fiveTop2Bottom3:
        return const [
          Rect.fromLTRB(0, 0, .5, .5),
          Rect.fromLTRB(.5, 0, 1, .5),
          Rect.fromLTRB(0, .5, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, .5, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, .5, 1, 1),
        ];
      case CollageTemplate.fiveTop1Bottom4:
        return const [
          Rect.fromLTRB(0, 0, 1, .5),
          Rect.fromLTRB(0, .5, .25, 1),
          Rect.fromLTRB(.25, .5, .5, 1),
          Rect.fromLTRB(.5, .5, .75, 1),
          Rect.fromLTRB(.75, .5, 1, 1),
        ];
      case CollageTemplate.fiveLeft1Right4:
        return const [
          Rect.fromLTRB(0, 0, .5, 1),
          Rect.fromLTRB(.5, 0, 1, .25),
          Rect.fromLTRB(.5, .25, 1, .5),
          Rect.fromLTRB(.5, .5, 1, .75),
          Rect.fromLTRB(.5, .75, 1, 1),
        ];

      case CollageTemplate.sixGrid3x2:
        return const [
          Rect.fromLTRB(0, 0, 1 / 3, .5),
          Rect.fromLTRB(1 / 3, 0, 2 / 3, .5),
          Rect.fromLTRB(2 / 3, 0, 1, .5),
          Rect.fromLTRB(0, .5, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, .5, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, .5, 1, 1),
        ];
      case CollageTemplate.sixLeft2Right4:
        return const [
          Rect.fromLTRB(0, 0, .5, .5),
          Rect.fromLTRB(0, .5, .5, 1),
          Rect.fromLTRB(.5, 0, .75, .5),
          Rect.fromLTRB(.75, 0, 1, .5),
          Rect.fromLTRB(.5, .5, .75, 1),
          Rect.fromLTRB(.75, .5, 1, 1),
        ];

      case CollageTemplate.sevenTop1Bottom6:
        return const [
          Rect.fromLTRB(0, 0, 1, .5),
          Rect.fromLTRB(0, .5, 1 / 3, 2 / 3),
          Rect.fromLTRB(1 / 3, .5, 2 / 3, 2 / 3),
          Rect.fromLTRB(2 / 3, .5, 1, 2 / 3),
          Rect.fromLTRB(0, 2 / 3, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, 2 / 3, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, 2 / 3, 1, 1),
        ];
      case CollageTemplate.sevenTop3Bottom4:
        return const [
          Rect.fromLTRB(0, 0, 1 / 3, .5),
          Rect.fromLTRB(1 / 3, 0, 2 / 3, .5),
          Rect.fromLTRB(2 / 3, 0, 1, .5),
          Rect.fromLTRB(0, .5, .25, 1),
          Rect.fromLTRB(.25, .5, .5, 1),
          Rect.fromLTRB(.5, .5, .75, 1),
          Rect.fromLTRB(.75, .5, 1, 1),
        ];

      case CollageTemplate.eightTop4Bottom4:
        return const [
          Rect.fromLTRB(0, 0, .25, .5),
          Rect.fromLTRB(.25, 0, .5, .5),
          Rect.fromLTRB(.5, 0, .75, .5),
          Rect.fromLTRB(.75, 0, 1, .5),
          Rect.fromLTRB(0, .5, .25, 1),
          Rect.fromLTRB(.25, .5, .5, 1),
          Rect.fromLTRB(.5, .5, .75, 1),
          Rect.fromLTRB(.75, .5, 1, 1),
        ];
      case CollageTemplate.eightGrid2x4:
        return const [
          Rect.fromLTRB(0, 0, .5, .25),
          Rect.fromLTRB(.5, 0, 1, .25),
          Rect.fromLTRB(0, .25, .5, .5),
          Rect.fromLTRB(.5, .25, 1, .5),
          Rect.fromLTRB(0, .5, .5, .75),
          Rect.fromLTRB(.5, .5, 1, .75),
          Rect.fromLTRB(0, .75, .5, 1),
          Rect.fromLTRB(.5, .75, 1, 1),
        ];

      case CollageTemplate.nineGrid3x3:
        return const [
          Rect.fromLTRB(0, 0, 1 / 3, 1 / 3),
          Rect.fromLTRB(1 / 3, 0, 2 / 3, 1 / 3),
          Rect.fromLTRB(2 / 3, 0, 1, 1 / 3),
          Rect.fromLTRB(0, 1 / 3, 1 / 3, 2 / 3),
          Rect.fromLTRB(1 / 3, 1 / 3, 2 / 3, 2 / 3),
          Rect.fromLTRB(2 / 3, 1 / 3, 1, 2 / 3),
          Rect.fromLTRB(0, 2 / 3, 1 / 3, 1),
          Rect.fromLTRB(1 / 3, 2 / 3, 2 / 3, 1),
          Rect.fromLTRB(2 / 3, 2 / 3, 1, 1),
        ];
    }
  }
}

/// 中央斜切的垂直偏移比例：分割线由 (0, .5-s) 到 (1, .5+s)。
const double kCollageDiagonalSlant = 0.18;

/// 单元格内单张图片的相对变换。
///
/// [scale] 以 BoxFit.cover 为 1.0 基准（取值范围 1.0–[kCollageMaxImageScale]）；
/// [offset] 相对单元格宽高归一化，0.5 表示偏移半个单元格；
/// [quarterTurns] 为顺时针 90° 旋转次数（0..3），[flipX] 为水平镜像。
class CollageImageTransform {
  final double scale;
  final Offset offset;
  final int quarterTurns;
  final bool flipX;

  const CollageImageTransform({
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.quarterTurns = 0,
    this.flipX = false,
  });

  /// 默认状态：恰好 cover 铺满并居中。
  static const CollageImageTransform identity = CollageImageTransform();

  bool get isIdentity =>
      scale == 1.0 &&
      offset == Offset.zero &&
      (quarterTurns % 4) == 0 &&
      !flipX;

  CollageImageTransform copyWith({
    double? scale,
    Offset? offset,
    int? quarterTurns,
    bool? flipX,
  }) =>
      CollageImageTransform(
        scale: scale ?? this.scale,
        offset: offset ?? this.offset,
        quarterTurns: ((quarterTurns ?? this.quarterTurns) % 4 + 4) % 4,
        flipX: flipX ?? this.flipX,
      );

  @override
  bool operator ==(Object other) =>
      other is CollageImageTransform &&
      other.scale == scale &&
      other.offset == offset &&
      (other.quarterTurns % 4) == (quarterTurns % 4) &&
      other.flipX == flipX;

  @override
  int get hashCode =>
      Object.hash(scale, offset, ((quarterTurns % 4) + 4) % 4, flipX);
}

/// 图片相对单元格的最大缩放倍数。
const double kCollageMaxImageScale = 5.0;

/// 考虑单格旋转后的有效图像尺寸（奇数次 90° 旋转会互换宽高）。
Size effectiveCollageImageSize(Size imageSize, CollageImageTransform t) =>
    (t.quarterTurns % 2 != 0)
        ? Size(imageSize.height, imageSize.width)
        : imageSize;

/// 把变换夹取到合法范围：缩放 [1, kCollageMaxImageScale]，
/// 位移不越出「图片始终盖满单元格」的边界（永不露白）。
CollageImageTransform clampCollageTransform(
  Size imageSize,
  Rect cell,
  CollageImageTransform t,
) {
  final effSize = effectiveCollageImageSize(imageSize, t);
  final scale = t.scale.clamp(1.0, kCollageMaxImageScale).toDouble();
  final draw = effSize * (_coverScale(effSize, cell) * scale);
  final maxDx =
      draw.width <= cell.width ? 0.0 : (draw.width - cell.width) / 2 / cell.width;
  final maxDy = draw.height <= cell.height
      ? 0.0
      : (draw.height - cell.height) / 2 / cell.height;
  return CollageImageTransform(
    scale: scale,
    offset: Offset(
      t.offset.dx.clamp(-maxDx, maxDx).toDouble(),
      t.offset.dy.clamp(-maxDy, maxDy).toDouble(),
    ),
    quarterTurns: ((t.quarterTurns % 4) + 4) % 4,
    flipX: t.flipX,
  );
}

/// 单元格内图片的最终绘制矩形（已应用旋转等效尺寸、缩放/位移并夹取到铺满单元格）。
Rect collageImageDstRect(
  Size imageSize,
  Rect cell,
  CollageImageTransform t,
) {
  final c = clampCollageTransform(imageSize, cell, t);
  final effSize = effectiveCollageImageSize(imageSize, c);
  final draw = effSize * (_coverScale(effSize, cell) * c.scale);
  return Rect.fromCenter(
    center: Offset(
      cell.center.dx + c.offset.dx * cell.width,
      cell.center.dy + c.offset.dy * cell.height,
    ),
    width: draw.width,
    height: draw.height,
  );
}

/// 双指焦点不变性缩放：缩放时保持双指焦点对应的画面内容点位不漂移，并叠加平移增量。
CollageImageTransform computeFocalZoomTransform({
  required Size imageSize,
  required Rect cell,
  required CollageImageTransform start,
  required double gestureScale,
  required Offset startFocalCanvas,
  required Offset currentFocalCanvas,
}) {
  if (cell.width <= 0 || cell.height <= 0) return start;
  final nextScale =
      (start.scale * gestureScale).clamp(1.0, kCollageMaxImageScale).toDouble();
  final ratio = start.scale <= 0 ? 1.0 : nextScale / start.scale;
  final fx = (startFocalCanvas.dx - cell.center.dx) / cell.width;
  final fy = (startFocalCanvas.dy - cell.center.dy) / cell.height;
  final panX = (currentFocalCanvas.dx - startFocalCanvas.dx) / cell.width;
  final panY = (currentFocalCanvas.dy - startFocalCanvas.dy) / cell.height;
  final nextOffset = Offset(
    fx - (fx - start.offset.dx) * ratio + panX,
    fy - (fy - start.offset.dy) * ratio + panY,
  );
  return clampCollageTransform(
    imageSize,
    cell,
    start.copyWith(scale: nextScale, offset: nextOffset),
  );
}

/// 主分隔线描述（供 UI 渲染手柄与命中拖拽）。
class CollageDividerSpec {
  /// 分割方向：`vertical` 表示左右分割（水平拖动调节），`horizontal` 表示上下分割（垂直拖动调节）。
  final bool isVerticalDivider;
  final Offset start;
  final Offset end;
  final double currentRatio;

  const CollageDividerSpec({
    required this.isVerticalDivider,
    required this.start,
    required this.end,
    required this.currentRatio,
  });

  /// 拖拽手柄锚点（置于分隔线 82% 处，避免与画布正中单格图片拖拽冲突）。
  Offset get handleAnchor => Offset.lerp(start, end, 0.82)!;

  Offset get midpoint =>
      Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
}

/// BoxFit.cover 需要的缩放倍数。
double _coverScale(Size imageSize, Rect cell) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      cell.width <= 0 ||
      cell.height <= 0) {
    return 1;
  }
  return math.max(cell.width / imageSize.width, cell.height / imageSize.height);
}

/// 多边形外接矩形。
Rect _polyBounds(List<Offset> poly) {
  if (poly.isEmpty) return Rect.zero;
  var l = poly.first.dx, t = poly.first.dy, r = l, b = t;
  for (final p in poly) {
    l = math.min(l, p.dx);
    t = math.min(t, p.dy);
    r = math.max(r, p.dx);
    b = math.max(b, p.dy);
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// 一套拼图版式（比例 + 边框 + 拼接方式 + 精细调节），负责坐标换算。
class CollageLayout {
  static const int defaultBorderColorValue = 0xFFFFFFFF;
  static const double minSplitRatio = 0.25;
  static const double maxSplitRatio = 0.75;

  final CollageTemplate template;
  final CollageAspect aspect;
  final CollageBorder border;

  /// 自定义内间距比例（相对画布短边）；null 时沿用 [border.ratio]。
  final double? innerGapRatio;

  /// 自定义外边距比例（相对画布短边）；null 时沿用 [border.ratio]。
  final double? outerMarginRatio;

  /// 单元格圆角比例（相对画布短边，0..0.12）。
  final double cornerRadiusRatio;

  /// 边框与分界线 ARGB32 颜色（默认纯白）。
  final int borderColorValue;

  /// 可拖主分隔线比例（0.25..0.75）；null 时采用模板默认比例。
  final double? splitRatio;

  const CollageLayout({
    required this.template,
    this.aspect = CollageAspect.square,
    this.border = CollageBorder.none,
    this.innerGapRatio,
    this.outerMarginRatio,
    this.cornerRadiusRatio = 0.0,
    this.borderColorValue = defaultBorderColorValue,
    this.splitRatio,
  });

  static const Object _unset = Object();

  CollageLayout copyWith({
    CollageTemplate? template,
    CollageAspect? aspect,
    CollageBorder? border,
    Object? innerGapRatio = _unset,
    Object? outerMarginRatio = _unset,
    double? cornerRadiusRatio,
    int? borderColorValue,
    Object? splitRatio = _unset,
  }) =>
      CollageLayout(
        template: template ?? this.template,
        aspect: aspect ?? this.aspect,
        border: border ?? this.border,
        innerGapRatio: identical(innerGapRatio, _unset)
            ? this.innerGapRatio
            : innerGapRatio as double?,
        outerMarginRatio: identical(outerMarginRatio, _unset)
            ? this.outerMarginRatio
            : outerMarginRatio as double?,
        cornerRadiusRatio:
            (cornerRadiusRatio ?? this.cornerRadiusRatio).clamp(0.0, 0.12),
        borderColorValue: borderColorValue ?? this.borderColorValue,
        splitRatio: identical(splitRatio, _unset)
            ? this.splitRatio
            : (splitRatio as double?)?.clamp(minSplitRatio, maxSplitRatio),
      );

  bool get isDiagonal => template.isDiagonal;

  Size get canvasSize => aspect.outputSize;

  /// 有效内间距比例。
  double get effectiveInnerGapRatio =>
      (innerGapRatio ?? border.ratio).clamp(0.0, 0.04);

  /// 有效外边距比例。
  double get effectiveOuterMarginRatio =>
      (outerMarginRatio ?? border.ratio).clamp(0.0, 0.06);

  /// 画布短边对应的实际内间距/标准边框像素宽度。
  double get borderWidth => effectiveInnerGapRatio * canvasSize.shortestSide;

  /// 画布短边对应的实际外边距像素宽度。
  double get outerBorderWidth =>
      effectiveOuterMarginRatio * canvasSize.shortestSide;

  /// 单元格圆角半径（画布像素）。
  double get cornerRadiusPx =>
      cornerRadiusRatio.clamp(0.0, 0.12) * canvasSize.shortestSide;

  /// 当前模板是否支持主分隔线拖拽。
  double? get defaultSplitRatio => switch (template) {
        CollageTemplate.topBottom ||
        CollageTemplate.leftRight ||
        CollageTemplate.threeTop1Bottom2 ||
        CollageTemplate.threeTop2Bottom1 ||
        CollageTemplate.threeLeft1Right2 =>
          0.5,
        CollageTemplate.topBottom21 || CollageTemplate.leftRight21 => 2 / 3,
        CollageTemplate.topBottom12 || CollageTemplate.leftRight12 => 1 / 3,
        _ => null,
      };

  /// 主分隔线描述（不支持拖拽的模板返回 null）。
  CollageDividerSpec? get primaryDivider {
    final def = defaultSplitRatio;
    if (def == null) return null;
    final r = (splitRatio ?? def).clamp(minSplitRatio, maxSplitRatio);
    final size = canvasSize;
    final vertical = template == CollageTemplate.leftRight ||
        template == CollageTemplate.leftRight21 ||
        template == CollageTemplate.leftRight12 ||
        template == CollageTemplate.threeLeft1Right2;
    if (vertical) {
      final x = r * size.width;
      return CollageDividerSpec(
        isVerticalDivider: true,
        start: Offset(x, 0),
        end: Offset(x, size.height),
        currentRatio: r,
      );
    }
    final y = r * size.height;
    return CollageDividerSpec(
      isVerticalDivider: false,
      start: Offset(0, y),
      end: Offset(size.width, y),
      currentRatio: r,
    );
  }

  /// 归一化单元格列表（已应用 [splitRatio]）。
  List<Rect> get normalizedCells {
    final def = defaultSplitRatio;
    if (def == null || splitRatio == null) return template.cells;
    final r = splitRatio!.clamp(minSplitRatio, maxSplitRatio).toDouble();
    return switch (template) {
      CollageTemplate.topBottom ||
      CollageTemplate.topBottom21 ||
      CollageTemplate.topBottom12 =>
        [Rect.fromLTRB(0, 0, 1, r), Rect.fromLTRB(0, r, 1, 1)],
      CollageTemplate.leftRight ||
      CollageTemplate.leftRight21 ||
      CollageTemplate.leftRight12 =>
        [Rect.fromLTRB(0, 0, r, 1), Rect.fromLTRB(r, 0, 1, 1)],
      CollageTemplate.threeTop1Bottom2 => [
          Rect.fromLTRB(0, 0, 1, r),
          Rect.fromLTRB(0, r, .5, 1),
          Rect.fromLTRB(.5, r, 1, 1),
        ],
      CollageTemplate.threeTop2Bottom1 => [
          Rect.fromLTRB(0, 0, .5, r),
          Rect.fromLTRB(.5, 0, 1, r),
          Rect.fromLTRB(0, r, 1, 1),
        ],
      CollageTemplate.threeLeft1Right2 => [
          Rect.fromLTRB(0, 0, r, 1),
          Rect.fromLTRB(r, 0, 1, .5),
          Rect.fromLTRB(r, .5, 1, 1),
        ],
      _ => template.cells,
    };
  }

  /// 缩放到画布坐标的单元格矩形。
  List<Rect> get cellRects {
    final size = canvasSize;
    return normalizedCells
        .map((r) => Rect.fromLTRB(
              r.left * size.width,
              r.top * size.height,
              r.right * size.width,
              r.bottom * size.height,
            ))
        .toList(growable: false);
  }

  /// 中央斜切分割线（画布坐标）。
  List<Offset> get diagonalLine {
    final size = canvasSize;
    return [
      Offset(0, (0.5 - kCollageDiagonalSlant) * size.height),
      Offset(size.width, (0.5 + kCollageDiagonalSlant) * size.height),
    ];
  }

  /// 中央斜切上下两个多边形（画布坐标）。
  List<List<Offset>> get diagonalPolys {
    final size = canvasSize;
    final p1 = diagonalLine[0];
    final p2 = diagonalLine[1];
    return [
      [Offset.zero, Offset(size.width, 0), p2, p1],
      [p1, p2, Offset(size.width, size.height), Offset(0, size.height)],
    ];
  }

  /// 每格用于图片变换/绘制的矩形：矩形模板为内缩后的单元格，
  /// 中央斜切模板为对应多边形的外接矩形（最终仍按多边形裁剪）。
  List<Rect> imageCells({bool drawOuterFrame = true}) {
    if (isDiagonal) {
      return diagonalPolys.map(_polyBounds).toList(growable: false);
    }
    return cellRects
        .map((c) => insetRect(c, drawOuterFrame: drawOuterFrame))
        .toList(growable: false);
  }

  /// 单个单元格的实际绘制矩形：外边缘内缩 [outerBorderWidth]，相邻格各内缩 [borderWidth]/2。
  ///
  /// [drawOuterFrame] 为 false 时（叠加了水印模板），外围边框不占位，
  /// 只保留图片之间的分界线。
  Rect insetRect(Rect cell, {bool drawOuterFrame = true}) {
    final size = canvasSize;
    final half = borderWidth / 2;
    final outer = drawOuterFrame ? outerBorderWidth : 0.0;
    const eps = 0.0001;
    final atLeft = cell.left <= eps;
    final atTop = cell.top <= eps;
    final atRight = cell.right >= size.width - eps;
    final atBottom = cell.bottom >= size.height - eps;
    return Rect.fromLTRB(
      cell.left + (atLeft ? outer : half),
      cell.top + (atTop ? outer : half),
      cell.right - (atRight ? outer : half),
      cell.bottom - (atBottom ? outer : half),
    );
  }
}