/// Spektrafilm 参数模型。
///
/// 真正的底片/印相纸档案由原生光谱引擎读取，这里只保存用户选择与可调参数。
library;

/// 原生引擎返回的真实底片条目。
class SpektraStockInfo {
  final String id;
  final String name;
  final String targetPrint;
  final String use;

  const SpektraStockInfo({
    required this.id,
    required this.name,
    required this.targetPrint,
    required this.use,
  });

  factory SpektraStockInfo.fromJson(Map<String, dynamic> json) =>
      SpektraStockInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        targetPrint: json['targetPrint'] as String? ?? '',
        use: json['use'] as String? ?? 'still',
      );

  String get vendor {
    final lower = name.toLowerCase();
    if (lower.startsWith('kodak')) return 'Kodak';
    if (lower.startsWith('fujifilm') || lower.startsWith('fuji')) {
      return 'Fujifilm';
    }
    if (lower.contains('ilford')) return 'Ilford';
    if (lower.contains('cinestill')) return 'CineStill';
    return 'Film';
  }

  int get iso {
    final match = RegExp(r'(\d{2,4})').firstMatch(name);
    return match == null ? 400 : int.parse(match.group(1)!);
  }
}

/// 原生引擎返回的真实印相纸条目。
class SpektraPaperInfo {
  final String id;
  final String name;

  const SpektraPaperInfo({required this.id, required this.name});

  factory SpektraPaperInfo.fromJson(Map<String, dynamic> json) =>
      SpektraPaperInfo(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// 负片直扫（跳过印相纸）。
const String kSpektraDirectScanPaperId = 'negative_direct_scan';

/// 胶片模拟参数。
class SpektrafilmSettings {
  /// 选中的真实底片 id；为空表示未启用。
  final String? stockId;

  /// 冲印介质 id；[kSpektraDirectScanPaperId] 表示负片直扫。
  final String paperId;

  /// 最终输出与原图的混合比例 0..1。
  final double intensity;

  /// 红光晕强度 0..1。
  final double halation;

  /// 光晕扩散半径 0.5..3。
  final double halationRadius;

  /// 银盐颗粒强度 0..1。
  final double grain;

  /// 颗粒粗细 0..1（映射到物理粒子面积）。
  final double grainRoughness;

  /// 放大机黄滤色片偏移 -100..100。
  final double enlargerWarmth;

  /// 放大机品红滤色片偏移 -100..100。
  final double enlargerTint;

  /// 底片曝光补偿 -2..2 EV。
  final double filmExposure;

  const SpektrafilmSettings({
    this.stockId,
    this.paperId = kSpektraDirectScanPaperId,
    this.intensity = 1.0,
    this.halation = 1.0,
    this.halationRadius = 1.0,
    this.grain = 1.0,
    this.grainRoughness = 0.45,
    this.enlargerWarmth = 0.0,
    this.enlargerTint = 0.0,
    this.filmExposure = 0.0,
  });

  bool get isActive => stockId != null && stockId!.isNotEmpty;

  bool get directScan => paperId == kSpektraDirectScanPaperId;

  SpektrafilmSettings copyWith({
    String? stockId,
    bool clearStock = false,
    String? paperId,
    double? intensity,
    double? halation,
    double? halationRadius,
    double? grain,
    double? grainRoughness,
    double? enlargerWarmth,
    double? enlargerTint,
    double? filmExposure,
  }) {
    return SpektrafilmSettings(
      stockId: clearStock ? null : (stockId ?? this.stockId),
      paperId: paperId ?? this.paperId,
      intensity: (intensity ?? this.intensity).clamp(0.0, 1.0),
      halation: (halation ?? this.halation).clamp(0.0, 1.0),
      halationRadius: (halationRadius ?? this.halationRadius).clamp(0.5, 3.0),
      grain: (grain ?? this.grain).clamp(0.0, 1.0),
      grainRoughness: (grainRoughness ?? this.grainRoughness).clamp(0.0, 1.0),
      enlargerWarmth:
          (enlargerWarmth ?? this.enlargerWarmth).clamp(-100.0, 100.0),
      enlargerTint: (enlargerTint ?? this.enlargerTint).clamp(-100.0, 100.0),
      filmExposure: (filmExposure ?? this.filmExposure).clamp(-2.0, 2.0),
    );
  }

  SpektrafilmSettings withStock(String id, {String? paperId}) => copyWith(
        stockId: id,
        paperId: paperId,
      );

  SpektrafilmSettings withoutStock() => copyWith(clearStock: true);

  /// 原生渲染参数，顺序必须与 jni_bridge.cpp 一致。
  List<double> toNativeParams() => <double>[
        directScan ? 1 : 0,
        filmExposure,
        halation,
        halationRadius,
        grain,
        0.15 + grainRoughness * 0.85,
        enlargerWarmth * 0.4,
        enlargerTint * 0.4,
        1,
        1,
        1,
        42,
      ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stockId': stockId,
        'paperId': paperId,
        'intensity': intensity,
        'halation': halation,
        'halationRadius': halationRadius,
        'grain': grain,
        'grainRoughness': grainRoughness,
        'enlargerWarmth': enlargerWarmth,
        'enlargerTint': enlargerTint,
        'filmExposure': filmExposure,
      };

  factory SpektrafilmSettings.fromJson(Map<String, dynamic> json) {
    final stock = json['stockId'] as String?;
    return SpektrafilmSettings(
      stockId: stock == null || stock.isEmpty ? null : stock,
      paperId:
          json['paperId'] as String? ?? kSpektraDirectScanPaperId,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
      halation: (json['halation'] as num?)?.toDouble() ?? 1.0,
      halationRadius: (json['halationRadius'] as num?)?.toDouble() ?? 1.0,
      grain: (json['grain'] as num?)?.toDouble() ?? 1.0,
      grainRoughness: (json['grainRoughness'] as num?)?.toDouble() ?? 0.45,
      enlargerWarmth: (json['enlargerWarmth'] as num?)?.toDouble() ?? 0,
      enlargerTint: (json['enlargerTint'] as num?)?.toDouble() ?? 0,
      filmExposure: (json['filmExposure'] as num?)?.toDouble() ?? 0,
    );
  }

  String get requestKey =>
      '${stockId ?? '-'}|$paperId|${intensity.toStringAsFixed(3)}|'
      '${halation.toStringAsFixed(3)}|${halationRadius.toStringAsFixed(3)}|'
      '${grain.toStringAsFixed(3)}|${grainRoughness.toStringAsFixed(3)}|'
      '${enlargerWarmth.toStringAsFixed(2)}|'
      '${enlargerTint.toStringAsFixed(2)}|${filmExposure.toStringAsFixed(2)}';

  @override
  bool operator ==(Object other) =>
      other is SpektrafilmSettings &&
      other.stockId == stockId &&
      other.paperId == paperId &&
      other.intensity == intensity &&
      other.halation == halation &&
      other.halationRadius == halationRadius &&
      other.grain == grain &&
      other.grainRoughness == grainRoughness &&
      other.enlargerWarmth == enlargerWarmth &&
      other.enlargerTint == enlargerTint &&
      other.filmExposure == filmExposure;

  @override
  int get hashCode => Object.hash(
        stockId,
        paperId,
        intensity,
        halation,
        halationRadius,
        grain,
        grainRoughness,
        enlargerWarmth,
        enlargerTint,
        filmExposure,
      );
}
