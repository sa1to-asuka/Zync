/// 触控对焦的坐标换算。
///
/// `ChangeAfArea 0x9205` 接受的**不是**取景帧的像素坐标，而是机身的对焦区域
/// 坐标系：APS-C Z 机身为 5760 × 3840（取景放大区域上限的两倍）。
/// 用取景帧尺寸换算会把对焦点推到画面之外，所以这里固定按机身坐标系映射。
class AfAreaMapper {
  AfAreaMapper._();

  /// APS-C Z 机身的对焦区域坐标上限。
  static const int defaultWidth = 5760;
  static const int defaultHeight = 3840;

  /// 归一化点击位置（0..1，左上为原点）→ 对焦区域坐标。
  static ({int x, int y}) fromNormalized(
    double normalizedX,
    double normalizedY, {
    int width = defaultWidth,
    int height = defaultHeight,
  }) {
    final x = (normalizedX.clamp(0.0, 1.0) * width).round();
    final y = (normalizedY.clamp(0.0, 1.0) * height).round();
    return (x: x, y: y);
  }

  /// 对焦区域坐标 → 归一化位置，用于在取景画面上回显对焦点。
  static ({double x, double y}) toNormalized(
    int x,
    int y, {
    int width = defaultWidth,
    int height = defaultHeight,
  }) {
    return (
      x: width <= 0 ? 0.0 : (x / width).clamp(0.0, 1.0),
      y: height <= 0 ? 0.0 : (y / height).clamp(0.0, 1.0),
    );
  }
}
