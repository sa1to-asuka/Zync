import 'dart:convert';

import '../filter/photo_filter.dart';

/// 照片编辑源模式。普通流程保持 JPEG 速度，专业流程按需使用 RAW。
enum PhotoSourceMode {
  quickJpeg,
  professionalRaw;

  static PhotoSourceMode fromName(String? value) =>
      PhotoSourceMode.values.firstWhere((e) => e.name == value,
          orElse: () => PhotoSourceMode.quickJpeg);
}

/// 相册/下载层交给编辑器的源描述。字节预览不是唯一事实来源。
class PhotoSourceDescriptor {
  final String sourceId;
  final String fileName;
  final String mimeType;
  final String path;
  final int size;
  final bool isRaw;
  final bool hasEmbeddedPreview;
  final int width;
  final int height;
  final String cameraModel;
  final String lensModel;
  final String capturedDate;
  final String sha256;

  const PhotoSourceDescriptor({
    required this.sourceId,
    required this.fileName,
    required this.mimeType,
    required this.path,
    this.size = 0,
    this.isRaw = false,
    this.hasEmbeddedPreview = false,
    this.width = 0,
    this.height = 0,
    this.cameraModel = '',
    this.lensModel = '',
    this.capturedDate = '',
    this.sha256 = '',
  });

  bool get isJpeg {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        mimeType == 'image/jpeg';
  }

  bool get isPng =>
      fileName.toLowerCase().endsWith('.png') || mimeType == 'image/png';

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'fileName': fileName,
        'mimeType': mimeType,
        'path': path,
        'size': size,
        'isRaw': isRaw,
        'hasEmbeddedPreview': hasEmbeddedPreview,
        'width': width,
        'height': height,
        'cameraModel': cameraModel,
        'lensModel': lensModel,
        'capturedDate': capturedDate,
        'sha256': sha256,
      };

  factory PhotoSourceDescriptor.fromJson(Map<String, dynamic> json) =>
      PhotoSourceDescriptor(
        sourceId: json['sourceId'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
        path: json['path'] as String? ?? '',
        size: (json['size'] as num?)?.toInt() ?? 0,
        isRaw: json['isRaw'] as bool? ?? false,
        hasEmbeddedPreview: json['hasEmbeddedPreview'] as bool? ?? false,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        cameraModel: json['cameraModel'] as String? ?? '',
        lensModel: json['lensModel'] as String? ?? '',
        capturedDate: json['capturedDate'] as String? ?? '',
        sha256: json['sha256'] as String? ?? '',
      );
}

class ToneCurvePoint {
  final double x;
  final double y;

  const ToneCurvePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory ToneCurvePoint.fromJson(Map<String, dynamic> json) => ToneCurvePoint(
        (json['x'] as num?)?.toDouble() ?? 0.0,
        (json['y'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 0..1 输入输出的单调色调曲线。至少保留两端点。
class ToneCurve {
  final List<ToneCurvePoint> points;

  const ToneCurve(
      {this.points = const [ToneCurvePoint(0, 0), ToneCurvePoint(1, 1)]});

  bool get isIdentity =>
      points.length == 2 &&
      points.first.x == 0 &&
      points.first.y == 0 &&
      points.last.x == 1 &&
      points.last.y == 1;

  double evaluate(double x) {
    if (points.isEmpty) return x.clamp(0.0, 1.0);
    final t = x.clamp(0.0, 1.0);
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    if (t <= sorted.first.x) return sorted.first.y.clamp(0.0, 1.0);
    for (var i = 1; i < sorted.length; i++) {
      final a = sorted[i - 1];
      final b = sorted[i];
      if (t <= b.x) {
        final span = b.x - a.x;
        if (span.abs() < 1e-9) return b.y.clamp(0.0, 1.0);
        final f = (t - a.x) / span;
        return (a.y + (b.y - a.y) * f).clamp(0.0, 1.0);
      }
    }
    return sorted.last.y.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() =>
      {'points': points.map((e) => e.toJson()).toList()};

  factory ToneCurve.fromJson(Map<String, dynamic> json) => ToneCurve(
        points: (json['points'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) => ToneCurvePoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class HslBandAdjustment {
  final String band;
  final double hue;
  final double saturation;
  final double luminance;

  const HslBandAdjustment({
    required this.band,
    this.hue = 0,
    this.saturation = 0,
    this.luminance = 0,
  });

  Map<String, dynamic> toJson() => {
        'band': band,
        'hue': hue,
        'saturation': saturation,
        'luminance': luminance,
      };

  factory HslBandAdjustment.fromJson(Map<String, dynamic> json) =>
      HslBandAdjustment(
        band: json['band'] as String? ?? 'red',
        hue: (json['hue'] as num?)?.toDouble() ?? 0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
        luminance: (json['luminance'] as num?)?.toDouble() ?? 0,
      );
}

class HslAdjustments {
  final List<HslBandAdjustment> bands;

  const HslAdjustments({this.bands = const []});

  bool get isDefault =>
      bands.every((e) => e.hue == 0 && e.saturation == 0 && e.luminance == 0);

  HslAdjustments copyWith({List<HslBandAdjustment>? bands}) =>
      HslAdjustments(bands: bands ?? this.bands);

  Map<String, dynamic> toJson() =>
      {'bands': bands.map((e) => e.toJson()).toList()};

  factory HslAdjustments.fromJson(Map<String, dynamic> json) => HslAdjustments(
        bands: (json['bands'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
                (e) => HslBandAdjustment.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ColorWheelAdjustment {
  final double hue;
  final double saturation;
  final double luminance;

  const ColorWheelAdjustment(
      {this.hue = 0, this.saturation = 0, this.luminance = 0});

  bool get isDefault => hue == 0 && saturation == 0 && luminance == 0;

  ColorWheelAdjustment copyWith(
          {double? hue, double? saturation, double? luminance}) =>
      ColorWheelAdjustment(
        hue: hue ?? this.hue,
        saturation: saturation ?? this.saturation,
        luminance: luminance ?? this.luminance,
      );

  Map<String, dynamic> toJson() =>
      {'hue': hue, 'saturation': saturation, 'luminance': luminance};

  factory ColorWheelAdjustment.fromJson(Map<String, dynamic> json) =>
      ColorWheelAdjustment(
        hue: (json['hue'] as num?)?.toDouble() ?? 0,
        saturation: (json['saturation'] as num?)?.toDouble() ?? 0,
        luminance: (json['luminance'] as num?)?.toDouble() ?? 0,
      );
}

class ColorGradingWheels {
  final ColorWheelAdjustment shadows;
  final ColorWheelAdjustment midtones;
  final ColorWheelAdjustment highlights;

  const ColorGradingWheels({
    this.shadows = const ColorWheelAdjustment(),
    this.midtones = const ColorWheelAdjustment(),
    this.highlights = const ColorWheelAdjustment(),
  });

  bool get isDefault =>
      shadows.isDefault && midtones.isDefault && highlights.isDefault;

  ColorGradingWheels copyWith({
    ColorWheelAdjustment? shadows,
    ColorWheelAdjustment? midtones,
    ColorWheelAdjustment? highlights,
  }) =>
      ColorGradingWheels(
        shadows: shadows ?? this.shadows,
        midtones: midtones ?? this.midtones,
        highlights: highlights ?? this.highlights,
      );

  Map<String, dynamic> toJson() => {
        'shadows': shadows.toJson(),
        'midtones': midtones.toJson(),
        'highlights': highlights.toJson(),
      };

  factory ColorGradingWheels.fromJson(Map<String, dynamic> json) =>
      ColorGradingWheels(
        shadows: ColorWheelAdjustment.fromJson(
            Map<String, dynamic>.from(json['shadows'] as Map? ?? const {})),
        midtones: ColorWheelAdjustment.fromJson(
            Map<String, dynamic>.from(json['midtones'] as Map? ?? const {})),
        highlights: ColorWheelAdjustment.fromJson(
            Map<String, dynamic>.from(json['highlights'] as Map? ?? const {})),
      );
}

class LutRef {
  final String id;
  final String name;
  final String format;
  final int size;
  final double strength;
  final String path;

  const LutRef({
    this.id = '',
    this.name = '',
    this.format = 'cube',
    this.size = 0,
    this.strength = 1.0,
    this.path = '',
  });

  bool get isDefault => id.isEmpty || strength <= 0;

  LutRef copyWith(
          {String? id,
          String? name,
          String? format,
          int? size,
          double? strength,
          String? path}) =>
      LutRef(
        id: id ?? this.id,
        name: name ?? this.name,
        format: format ?? this.format,
        size: size ?? this.size,
        strength: strength ?? this.strength,
        path: path ?? this.path,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'format': format,
        'size': size,
        'strength': strength,
        'path': path,
      };

  factory LutRef.fromJson(Map<String, dynamic> json) => LutRef(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        format: json['format'] as String? ?? 'cube',
        size: (json['size'] as num?)?.toInt() ?? 0,
        strength: (json['strength'] as num?)?.toDouble() ?? 1.0,
        path: json['path'] as String? ?? '',
      );
}

/// 新专业调色模型。保留旧 PhotoEditAdjustments 以兼容 1.7.0 工程。
class ColorGrade {
  final PhotoEditAdjustments base;
  final ToneCurve toneCurve;
  final HslAdjustments hsl;
  final ColorGradingWheels colorGrading;
  final LutRef lut;
  final double sharpening;
  final double noiseReduction;
  final double lensDistortion;
  final double lensVignette;
  final double chromaticAberration;

  const ColorGrade({
    this.base = const PhotoEditAdjustments(),
    this.toneCurve = const ToneCurve(),
    this.hsl = const HslAdjustments(),
    this.colorGrading = const ColorGradingWheels(),
    this.lut = const LutRef(),
    this.sharpening = 0,
    this.noiseReduction = 0,
    this.lensDistortion = 0,
    this.lensVignette = 0,
    this.chromaticAberration = 0,
  });

  bool get isDefault =>
      base.isDefault &&
      toneCurve.isIdentity &&
      hsl.isDefault &&
      colorGrading.isDefault &&
      lut.isDefault &&
      sharpening == 0 &&
      noiseReduction == 0 &&
      lensDistortion == 0 &&
      lensVignette == 0 &&
      chromaticAberration == 0;

  ColorGrade copyWith({
    PhotoEditAdjustments? base,
    ToneCurve? toneCurve,
    HslAdjustments? hsl,
    ColorGradingWheels? colorGrading,
    LutRef? lut,
    double? sharpening,
    double? noiseReduction,
    double? lensDistortion,
    double? lensVignette,
    double? chromaticAberration,
  }) =>
      ColorGrade(
        base: base ?? this.base,
        toneCurve: toneCurve ?? this.toneCurve,
        hsl: hsl ?? this.hsl,
        colorGrading: colorGrading ?? this.colorGrading,
        lut: lut ?? this.lut,
        sharpening: sharpening ?? this.sharpening,
        noiseReduction: noiseReduction ?? this.noiseReduction,
        lensDistortion: lensDistortion ?? this.lensDistortion,
        lensVignette: lensVignette ?? this.lensVignette,
        chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      );

  Map<String, dynamic> toJson() => {
        'base': {
          'temperature': base.temperature,
          'tint': base.tint,
          'exposure': base.exposure,
          'contrast': base.contrast,
          'highlights': base.highlights,
          'shadows': base.shadows,
          'whites': base.whites,
          'blacks': base.blacks,
          'texture': base.texture,
          'clarity': base.clarity,
          'dehaze': base.dehaze,
          'vibrance': base.vibrance,
          'saturation': base.saturation,
          'highlightHue': base.highlightHue,
          'highlightSat': base.highlightSat,
          'shadowHue': base.shadowHue,
          'shadowSat': base.shadowSat,
          'vignette': base.vignette,
          'grain': base.grain,
        },
        'toneCurve': toneCurve.toJson(),
        'hsl': hsl.toJson(),
        'colorGrading': colorGrading.toJson(),
        'lut': lut.toJson(),
        'sharpening': sharpening,
        'noiseReduction': noiseReduction,
        'lensDistortion': lensDistortion,
        'lensVignette': lensVignette,
        'chromaticAberration': chromaticAberration,
      };

  factory ColorGrade.fromJson(Map<String, dynamic> json) {
    final b = Map<String, dynamic>.from(json['base'] as Map? ?? const {});
    return ColorGrade(
      base: PhotoEditAdjustments(
        temperature: (b['temperature'] as num?)?.toDouble() ?? 0,
        tint: (b['tint'] as num?)?.toDouble() ?? 0,
        exposure: (b['exposure'] as num?)?.toDouble() ?? 0,
        contrast: (b['contrast'] as num?)?.toDouble() ?? 0,
        highlights: (b['highlights'] as num?)?.toDouble() ?? 0,
        shadows: (b['shadows'] as num?)?.toDouble() ?? 0,
        whites: (b['whites'] as num?)?.toDouble() ?? 0,
        blacks: (b['blacks'] as num?)?.toDouble() ?? 0,
        texture: (b['texture'] as num?)?.toDouble() ?? 0,
        clarity: (b['clarity'] as num?)?.toDouble() ?? 0,
        dehaze: (b['dehaze'] as num?)?.toDouble() ?? 0,
        vibrance: (b['vibrance'] as num?)?.toDouble() ?? 0,
        saturation: (b['saturation'] as num?)?.toDouble() ?? 0,
        highlightHue: (b['highlightHue'] as num?)?.toDouble() ?? 40,
        highlightSat: (b['highlightSat'] as num?)?.toDouble() ?? 0,
        shadowHue: (b['shadowHue'] as num?)?.toDouble() ?? 220,
        shadowSat: (b['shadowSat'] as num?)?.toDouble() ?? 0,
        vignette: (b['vignette'] as num?)?.toDouble() ?? 0,
        grain: (b['grain'] as num?)?.toDouble() ?? 0,
      ),
      toneCurve: ToneCurve.fromJson(
          Map<String, dynamic>.from(json['toneCurve'] as Map? ?? const {})),
      hsl: HslAdjustments.fromJson(
          Map<String, dynamic>.from(json['hsl'] as Map? ?? const {})),
      colorGrading: ColorGradingWheels.fromJson(
          Map<String, dynamic>.from(json['colorGrading'] as Map? ?? const {})),
      lut: LutRef.fromJson(
          Map<String, dynamic>.from(json['lut'] as Map? ?? const {})),
      sharpening: (json['sharpening'] as num?)?.toDouble() ?? 0,
      noiseReduction: (json['noiseReduction'] as num?)?.toDouble() ?? 0,
      lensDistortion: (json['lensDistortion'] as num?)?.toDouble() ?? 0,
      lensVignette: (json['lensVignette'] as num?)?.toDouble() ?? 0,
      chromaticAberration:
          (json['chromaticAberration'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// 可序列化的非破坏性照片编辑配方。
class PhotoEditRecipe {
  static const int currentVersion = 2;

  final int version;
  final PhotoSourceMode sourceMode;
  final String filterTypeName;
  final double filterIntensity;
  final ColorGrade grade;
  final Map<String, dynamic> geometry;

  const PhotoEditRecipe({
    this.version = currentVersion,
    this.sourceMode = PhotoSourceMode.quickJpeg,
    this.filterTypeName = 'original',
    this.filterIntensity = 1.0,
    this.grade = const ColorGrade(),
    this.geometry = const {},
  });

  factory PhotoEditRecipe.fromLegacy({
    required PhotoFilterType filterType,
    required double filterIntensity,
    required PhotoEditAdjustments adjustments,
    PhotoSourceMode sourceMode = PhotoSourceMode.quickJpeg,
  }) =>
      PhotoEditRecipe(
        sourceMode: sourceMode,
        filterTypeName: filterType.name,
        filterIntensity: filterIntensity,
        grade: ColorGrade(base: adjustments),
      );

  Map<String, dynamic> toJson() => {
        'version': currentVersion,
        'sourceMode': sourceMode.name,
        'filterTypeName': filterTypeName,
        'filterIntensity': filterIntensity,
        'grade': grade.toJson(),
        'geometry': geometry,
      };

  String toJsonString() => jsonEncode(toJson());

  factory PhotoEditRecipe.fromJson(Map<String, dynamic> json) =>
      PhotoEditRecipe(
        version: (json['version'] as num?)?.toInt() ?? 1,
        sourceMode: PhotoSourceMode.fromName(json['sourceMode'] as String?),
        filterTypeName: json['filterTypeName'] as String? ?? 'original',
        filterIntensity: (json['filterIntensity'] as num?)?.toDouble() ?? 1.0,
        grade: ColorGrade.fromJson(
            Map<String, dynamic>.from(json['grade'] as Map? ?? const {})),
        geometry:
            Map<String, dynamic>.from(json['geometry'] as Map? ?? const {}),
      );

  static PhotoEditRecipe fromJsonString(String source) =>
      PhotoEditRecipe.fromJson(
          Map<String, dynamic>.from(jsonDecode(source) as Map));
}
