import '../../core/utils/exif_helper.dart';

/// 自由文字图层的背景/印章样式。
enum OverlayBgStyle {
  none,
  glassPill,
  solidTag,
  vermilionSealYang, // 阳文朱红印章：白底/透底红框红字
  vermilionSealYin, // 阴文朱红印章：实心朱红底白字
  cinemaBar;

  static OverlayBgStyle fromName(String? name) =>
      OverlayBgStyle.values.firstWhere(
        (e) => e.name == name,
        orElse: () => OverlayBgStyle.none,
      );
}

/// 自由可拖拽/旋转/缩放/竖排的艺术字图层。
///
/// 坐标 [nx], [ny] 以总画布（含水印边框）[0.0, 1.0] 归一化存储，
/// 保证在手机预览与 24MP–45MP 高清导出中像素位置 100% 一致。
class WatermarkTextLayer {
  final String id;
  final String text;
  final double nx;
  final double ny;
  final double scale;
  final double rotation;
  final String fontId;
  final int colorValue;
  final double opacity;
  final double letterSpacing;
  final double lineHeight;
  final int weightIndex;
  final bool italic;
  final bool vertical;
  final int? strokeColorValue;
  final double strokeWidth;
  final double shadowBlur;
  final OverlayBgStyle bgStyle;
  final int? bgColorValue;
  final bool locked;

  const WatermarkTextLayer({
    required this.id,
    required this.text,
    this.nx = 0.5,
    this.ny = 0.85,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.fontId = 'default',
    this.colorValue = 0xFFFFFFFF,
    this.opacity = 1.0,
    this.letterSpacing = 1.0,
    this.lineHeight = 1.25,
    this.weightIndex = 0,
    this.italic = false,
    this.vertical = false,
    this.strokeColorValue,
    this.strokeWidth = 0.0,
    this.shadowBlur = 6.0,
    this.bgStyle = OverlayBgStyle.none,
    this.bgColorValue,
    this.locked = false,
  });

  static const Object _unset = Object();

  WatermarkTextLayer copyWith({
    String? id,
    String? text,
    double? nx,
    double? ny,
    double? scale,
    double? rotation,
    String? fontId,
    int? colorValue,
    double? opacity,
    double? letterSpacing,
    double? lineHeight,
    int? weightIndex,
    bool? italic,
    bool? vertical,
    Object? strokeColorValue = _unset,
    double? strokeWidth,
    double? shadowBlur,
    OverlayBgStyle? bgStyle,
    Object? bgColorValue = _unset,
    bool? locked,
  }) =>
      WatermarkTextLayer(
        id: id ?? this.id,
        text: text ?? this.text,
        nx: (nx ?? this.nx).clamp(0.02, 0.98),
        ny: (ny ?? this.ny).clamp(0.02, 0.98),
        scale: (scale ?? this.scale).clamp(0.4, 4.0),
        rotation: rotation ?? this.rotation,
        fontId: fontId ?? this.fontId,
        colorValue: colorValue ?? this.colorValue,
        opacity: (opacity ?? this.opacity).clamp(0.1, 1.0),
        letterSpacing: (letterSpacing ?? this.letterSpacing).clamp(-2.0, 16.0),
        lineHeight: (lineHeight ?? this.lineHeight).clamp(0.9, 2.2),
        weightIndex: (weightIndex ?? this.weightIndex).clamp(0, 4),
        italic: italic ?? this.italic,
        vertical: vertical ?? this.vertical,
        strokeColorValue: identical(strokeColorValue, _unset)
            ? this.strokeColorValue
            : strokeColorValue as int?,
        strokeWidth: (strokeWidth ?? this.strokeWidth).clamp(0.0, 8.0),
        shadowBlur: (shadowBlur ?? this.shadowBlur).clamp(0.0, 24.0),
        bgStyle: bgStyle ?? this.bgStyle,
        bgColorValue: identical(bgColorValue, _unset)
            ? this.bgColorValue
            : bgColorValue as int?,
        locked: locked ?? this.locked,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'nx': nx,
        'ny': ny,
        'scale': scale,
        'rotation': rotation,
        'fontId': fontId,
        'colorValue': colorValue,
        'opacity': opacity,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
        'weightIndex': weightIndex,
        'italic': italic,
        'vertical': vertical,
        'strokeColorValue': strokeColorValue,
        'strokeWidth': strokeWidth,
        'shadowBlur': shadowBlur,
        'bgStyle': bgStyle.name,
        'bgColorValue': bgColorValue,
        'locked': locked,
      };

  factory WatermarkTextLayer.fromJson(Map<String, dynamic> json) =>
      WatermarkTextLayer(
        id: json['id'] as String? ?? 'layer_0',
        text: json['text'] as String? ?? '',
        nx: ((json['nx'] as num?)?.toDouble() ?? 0.5).clamp(0.02, 0.98),
        ny: ((json['ny'] as num?)?.toDouble() ?? 0.85).clamp(0.02, 0.98),
        scale: ((json['scale'] as num?)?.toDouble() ?? 1.0).clamp(0.4, 4.0),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        fontId: json['fontId'] as String? ?? 'default',
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFFFFF,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.1, 1.0),
        letterSpacing:
            ((json['letterSpacing'] as num?)?.toDouble() ?? 1.0).clamp(-2.0, 16.0),
        lineHeight:
            ((json['lineHeight'] as num?)?.toDouble() ?? 1.25).clamp(0.9, 2.2),
        weightIndex: ((json['weightIndex'] as num?)?.toInt() ?? 0).clamp(0, 4),
        italic: json['italic'] as bool? ?? false,
        vertical: json['vertical'] as bool? ?? false,
        strokeColorValue: (json['strokeColorValue'] as num?)?.toInt(),
        strokeWidth:
            ((json['strokeWidth'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 8.0),
        shadowBlur:
            ((json['shadowBlur'] as num?)?.toDouble() ?? 6.0).clamp(0.0, 24.0),
        bgStyle: OverlayBgStyle.fromName(json['bgStyle'] as String?),
        bgColorValue: (json['bgColorValue'] as num?)?.toInt(),
        locked: json['locked'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is WatermarkTextLayer &&
      other.id == id &&
      other.text == text &&
      other.nx == nx &&
      other.ny == ny &&
      other.scale == scale &&
      other.rotation == rotation &&
      other.fontId == fontId &&
      other.colorValue == colorValue &&
      other.opacity == opacity &&
      other.letterSpacing == letterSpacing &&
      other.lineHeight == lineHeight &&
      other.weightIndex == weightIndex &&
      other.italic == italic &&
      other.vertical == vertical &&
      other.strokeColorValue == strokeColorValue &&
      other.strokeWidth == strokeWidth &&
      other.shadowBlur == shadowBlur &&
      other.bgStyle == bgStyle &&
      other.bgColorValue == bgColorValue &&
      other.locked == locked;

  @override
  int get hashCode => Object.hashAll([
        id,
        text,
        nx,
        ny,
        scale,
        rotation,
        fontId,
        colorValue,
        opacity,
        letterSpacing,
        lineHeight,
        weightIndex,
        italic,
        vertical,
        strokeColorValue,
        strokeWidth,
        shadowBlur,
        bgStyle,
        bgColorValue,
        locked,
      ]);
}

/// 替换文字模板中的 EXIF 动态令牌：
/// `{model}` `{make}` `{lens}` `{focal}` `{aperture}` `{shutter}` `{iso}` `{date}` `{gps}` `{exposure}`。
String resolveWatermarkExifTokens(String raw, PhotoMetadata meta) {
  if (!raw.contains('{')) return raw;
  final replacements = <String, String>{
    '{model}': meta.titleText,
    '{make}': meta.cameraMake.trim(),
    '{lens}': meta.lensModel.trim(),
    '{focal}': meta.focalLength.trim(),
    '{aperture}': meta.aperture.trim(),
    '{shutter}': meta.shutterSpeed.trim(),
    '{iso}': meta.iso.trim(),
    '{date}': meta.capturedDate.trim(),
    '{gps}': meta.gpsSummary,
    '{exposure}': meta.exposureSummary,
  };
  var out = raw;
  replacements.forEach((token, value) {
    out = out.replaceAll(token, value);
  });
  // 清理因缺失字段产生的多余连续分隔符
  out = out
      .replaceAll(RegExp(r'\s*[·|]\s*(?=[·|]|$)'), '')
      .replaceAll(RegExp(r'^[\s·|]+'), '')
      .trim();
  return out;
}

/// 可选自由摆放的品牌/自定义 PNG 贴图图层。
class WatermarkStampLayer {
  final String id;
  final double nx;
  final double ny;
  final double scale;
  final double rotation;
  final double opacity;

  const WatermarkStampLayer({
    required this.id,
    this.nx = 0.85,
    this.ny = 0.85,
    this.scale = 0.16,
    this.rotation = 0.0,
    this.opacity = 1.0,
  });

  WatermarkStampLayer copyWith({
    String? id,
    double? nx,
    double? ny,
    double? scale,
    double? rotation,
    double? opacity,
  }) =>
      WatermarkStampLayer(
        id: id ?? this.id,
        nx: (nx ?? this.nx).clamp(0.03, 0.97),
        ny: (ny ?? this.ny).clamp(0.03, 0.97),
        scale: (scale ?? this.scale).clamp(0.05, 0.6),
        rotation: rotation ?? this.rotation,
        opacity: (opacity ?? this.opacity).clamp(0.1, 1.0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nx': nx,
        'ny': ny,
        'scale': scale,
        'rotation': rotation,
        'opacity': opacity,
      };

  factory WatermarkStampLayer.fromJson(Map<String, dynamic> json) =>
      WatermarkStampLayer(
        id: json['id'] as String? ?? 'stamp_0',
        nx: ((json['nx'] as num?)?.toDouble() ?? 0.85).clamp(0.03, 0.97),
        ny: ((json['ny'] as num?)?.toDouble() ?? 0.85).clamp(0.03, 0.97),
        scale: ((json['scale'] as num?)?.toDouble() ?? 0.16).clamp(0.05, 0.6),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        opacity: ((json['opacity'] as num?)?.toDouble() ?? 1.0).clamp(0.1, 1.0),
      );
}
