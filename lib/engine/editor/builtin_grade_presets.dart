import '../../l10n/l10n.dart';
import 'color_grade_preset.dart';
import '../filter/photo_filter.dart';
import 'pro_photo_models.dart';

/// 内置调色库，参数按色彩空间手工调校。
/// 照片 RAW 管线和视频 GPU 3D LUT 烘焙共用同一份 [ColorGrade]。
class BuiltinGradePreset {
  final String id;
  final String name;
  final String category;
  final String description;
  final ColorGrade grade;

  const BuiltinGradePreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.grade,
  });

  String get trName => L10n.tr(name);
  String get trCategory => L10n.tr(category);
  String get trDescription => L10n.tr(description);

  ColorGradePreset toPreset({bool isGlobal = false}) => ColorGradePreset(
        id: 'builtin_$id',
        name: trName,
        isGlobal: isGlobal,
        grade: grade,
      );
}

/// 构造一份调色。所有参数范围与 [PhotoEditAdjustments] 一致。
ColorGrade _g({
  double temperature = 0,
  double tint = 0,
  double exposure = 0,
  double contrast = 0,
  double highlights = 0,
  double shadows = 0,
  double whites = 0,
  double blacks = 0,
  double texture = 0,
  double clarity = 0,
  double dehaze = 0,
  double vibrance = 0,
  double saturation = 0,
  int highlightHue = 40,
  double highlightSat = 0,
  int shadowHue = 220,
  double shadowSat = 0,
  double vignette = 0,
  double grain = 0,
  double sharpening = 0,
  double noiseReduction = 0,
  double lensVignette = 0,
}) {
  return ColorGrade(
    base: PhotoEditAdjustments(
      temperature: temperature,
      tint: tint,
      exposure: exposure,
      contrast: contrast,
      highlights: highlights,
      shadows: shadows,
      whites: whites,
      blacks: blacks,
      texture: texture,
      clarity: clarity,
      dehaze: dehaze,
      vibrance: vibrance,
      saturation: saturation,
      highlightHue: highlightHue.toDouble(),
      highlightSat: highlightSat,
      shadowHue: shadowHue.toDouble(),
      shadowSat: shadowSat,
      vignette: vignette,
      grain: grain,
    ),
    sharpening: sharpening,
    noiseReduction: noiseReduction,
    lensVignette: lensVignette,
  );
}

/// 内置预设分类。
const List<String> kBuiltinGradeCategories = <String>[
  '通用',
  '人像',
  '风光',
  '黑白',
  '胶片',
];

/// 内置预设库，使用手工调校的色彩参数。
final List<BuiltinGradePreset> kBuiltinGradePresets = <BuiltinGradePreset>[
  // ==================== 通用 ====================
  BuiltinGradePreset(
    id: 'neutral',
    name: '标准',
    category: '通用',
    description: '中性还原，不改动白平衡，仅做轻微对比与锐化',
    grade: _g(contrast: 8, whites: 5, blacks: -4, sharpening: 20),
  ),
  BuiltinGradePreset(
    id: 'bright',
    name: '明亮通透',
    category: '通用',
    description: '提亮暗部、清爽肤色，适合室内与阴天',
    grade: _g(exposure: 12, contrast: 6, shadows: 22, blacks: -6, vibrance: 8),
  ),
  BuiltinGradePreset(
    id: 'punch',
    name: '浓郁',
    category: '通用',
    description: '高反差高饱和，适合花卉与美食',
    grade: _g(
        contrast: 22,
        highlights: -12,
        shadows: 10,
        clarity: 14,
        vibrance: 18,
        saturation: 10,
        sharpening: 25),
  ),

  // ==================== 人像 ====================
  BuiltinGradePreset(
    id: 'portrait_soft',
    name: '柔美人像',
    category: '人像',
    description: '柔化肤质、提亮面部，保留自然肤色',
    grade: _g(
        exposure: 8,
        contrast: -4,
        highlights: -14,
        shadows: 16,
        texture: -18,
        clarity: -8,
        vibrance: 6),
  ),
  BuiltinGradePreset(
    id: 'portrait_warm',
    name: '暖调人像',
    category: '人像',
    description: '暖黄肤色配柔和高光，适合室内人像',
    grade: _g(
      temperature: 14,
      exposure: 8,
      highlights: -12,
      shadows: 14,
      texture: -12,
      highlightHue: 38,
      highlightSat: 12,
    ),
  ),
  BuiltinGradePreset(
    id: 'portrait_mono',
    name: '高反差黑白人像',
    category: '人像',
    description: '去饱和加高反差，突出五官与轮廓',
    grade: _g(
        contrast: 30,
        highlights: -10,
        blacks: -14,
        clarity: 18,
        saturation: -100),
  ),

  // ==================== 风光 ====================
  BuiltinGradePreset(
    id: 'landscape_vivid',
    name: '风光浓郁',
    category: '风光',
    description: '通透蓝天与浓郁植被，适合大场景',
    grade: _g(
        contrast: 18,
        highlights: -18,
        shadows: 18,
        clarity: 20,
        dehaze: 18,
        vibrance: 22,
        saturation: 8,
        sharpening: 30),
  ),
  BuiltinGradePreset(
    id: 'landscape_soft',
    name: '柔和风光',
    category: '风光',
    description: '低反差淡雅色调，适合清晨薄雾',
    grade: _g(
      exposure: 6,
      contrast: -8,
      highlights: -10,
      shadows: 20,
      vibrance: 6,
      shadowHue: 215,
      shadowSat: 14,
    ),
  ),
  BuiltinGradePreset(
    id: 'landscape_teal',
    name: '青橙风光',
    category: '风光',
    description: '青色阴影配橙色高光，经典电影感',
    grade: _g(
      contrast: 16,
      highlights: -14,
      shadows: 12,
      highlightHue: 36,
      highlightSat: 26,
      shadowHue: 200,
      shadowSat: 22,
      vignette: 18,
      grain: 12,
    ),
  ),

  // ==================== 黑白 ====================
  BuiltinGradePreset(
    id: 'mono_classic',
    name: '经典黑白',
    category: '黑白',
    description: '中灰调标准黑白，通用性强',
    grade: _g(contrast: 20, blacks: -8, saturation: -100, sharpening: 20),
  ),
  BuiltinGradePreset(
    id: 'mono_high',
    name: '高反差黑白',
    category: '黑白',
    description: '硬朗高反差，适合建筑与街拍',
    grade: _g(
        contrast: 38,
        highlights: -16,
        blacks: -18,
        clarity: 22,
        saturation: -100),
  ),
  BuiltinGradePreset(
    id: 'mono_soft',
    name: '柔调黑白',
    category: '黑白',
    description: '低反差灰调，细腻柔和',
    grade: _g(contrast: -14, blacks: 12, saturation: -100, grain: 16),
  ),

  // ==================== 胶片 ====================
  BuiltinGradePreset(
    id: 'film_kodak',
    name: '柯达胶片',
    category: '胶片',
    description: '暖调反转片风格，红润肤色',
    grade: _g(
      temperature: 10,
      contrast: 12,
      highlights: -10,
      shadows: 12,
      vibrance: 10,
      grain: 18,
      vignette: 12,
    ),
  ),
  BuiltinGradePreset(
    id: 'film_fuji',
    name: '富士胶片',
    category: '胶片',
    description: '低饱和绿影，经典数码模拟感',
    grade: _g(
      temperature: 4,
      contrast: 4,
      highlights: -6,
      shadows: 18,
      vibrance: -6,
      shadowHue: 150,
      shadowSat: 18,
      grain: 22,
      vignette: 16,
    ),
  ),
  BuiltinGradePreset(
    id: 'film_cinema',
    name: '电影质感',
    category: '胶片',
    description: '高对比暗部加轻微颗粒，影视调色风格',
    grade: _g(
      contrast: 26,
      highlights: -20,
      shadows: -6,
      blacks: -14,
      clarity: 10,
      highlightHue: 34,
      highlightSat: 18,
      shadowHue: 210,
      shadowSat: 16,
      grain: 14,
      vignette: 24,
    ),
  ),
  BuiltinGradePreset(
    id: 'film_bw_negative',
    name: '黑白负片',
    category: '胶片',
    description: '反转黑白负片，低反差银盐质感',
    grade: _g(
      contrast: -18,
      blacks: 16,
      saturation: -100,
      grain: 26,
      vignette: 10,
    ),
  ),
];

/// 按分类筛选内置预设。
List<BuiltinGradePreset> builtinPresetsIn(String category) =>
    kBuiltinGradePresets.where((e) => e.category == category).toList();

/// 内置预设是否已存在于用户预设列表（按 builtin_ 前缀的 id 判断）。
bool isBuiltinPresetId(String id) => id.startsWith('builtin_');
