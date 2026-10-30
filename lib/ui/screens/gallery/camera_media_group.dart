part of '../gallery_screen.dart';

/// 相机同名媒体组 (对齐 Zync 高端双格式合并逻辑: 如 DSC_0108.NEF + DSC_0108.JPG 合并展示)
class CameraMediaGroup {
  final String baseName;
  CameraFileItem? jpegItem;
  CameraFileItem? rawItem;
  CameraFileItem? videoItem;

  CameraMediaGroup({
    required this.baseName,
    this.jpegItem,
    this.rawItem,
    this.videoItem,
  });

  /// 主展示对象 (优先用 JPG 提取缩略图与 EXIF，若无则用 RAW 或视频)
  CameraFileItem get primaryItem => (jpegItem ?? rawItem ?? videoItem)!;

  bool get isRawAndJpeg => rawItem != null && jpegItem != null;
  bool get isRawOnly => rawItem != null && jpegItem == null && videoItem == null;
  bool get isJpegOnly =>
      jpegItem != null && rawItem == null && videoItem == null;
  bool get isVideo => videoItem != null;

  /// 左上角格式徽标文案 (对齐 JPG+RAW, JPG, RAW, MP4)
  String get formatBadge {
    if (isRawAndJpeg) return 'JPG+RAW';
    if (isRawOnly) return 'RAW';
    if (isVideo) return 'MP4';
    return 'JPG';
  }

  /// 格式徽标配色（基于 ZyncPalette 令牌）
  Color get formatBadgeColor => formatBadgeColorOf(ZyncPalette.dark);

  Color formatBadgeColorOf(ZyncPalette zc) {
    if (isRawAndJpeg) return zc.accent;
    if (isRawOnly) return zc.warning;
    if (isVideo) return zc.danger;
    return zc.success;
  }

  /// 总文件大小 (字节)
  int get totalBytes =>
      (jpegItem?.size ?? 0) + (rawItem?.size ?? 0) + (videoItem?.size ?? 0);

  String get totalSizeFormatted {
    final bytes = totalBytes;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

/// 滑动多选的纯函数规则：
/// 以长按起点时的已选下标集合 [snapshot] 为基准，
/// 把闭区间 `[min(start, current), max(start, current)]` 内的每一项相对 [snapshot] 取反，
/// 区间外保持 [snapshot] 原样。
Set<int> applyDragRangeToggle(Set<int> snapshot, int start, int current) {
  final lo = start < current ? start : current;
  final hi = start < current ? current : start;
  final result = Set<int>.from(snapshot);
  for (var i = lo; i <= hi; i++) {
    if (!result.remove(i)) result.add(i);
  }
  return result;
}

/// 多选删除范围：仅本地 / 本地 + 相机存储卡。
enum _DeleteScope { localOnly, localAndCamera }

/// 相册筛选枚举（避免将本地化文案作为状态值对比）。
enum _GalleryFilter {
  all,
  unviewed,
  unsynced,
  synced,
  jpg,
  raw,
  jpgRaw,
  mp4,
}

/// 当前激活网格的几何描述，供 [_gridIndexAt] 把手指全局坐标换算成格子下标。
class _GridGeometry {
  const _GridGeometry({
    required this.key,
    required this.controller,
    required this.padding,
    required this.aspect,
  });

  final GlobalKey key;
  final ScrollController controller;
  final EdgeInsets padding;
  final double aspect;
}
