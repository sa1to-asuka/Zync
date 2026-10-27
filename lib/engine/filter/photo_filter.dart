import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// Lightroom 级专业照片调色参数模型
class PhotoEditAdjustments {
  // 1. 白平衡 (White Balance)
  final double temperature; // 色温: -100 (冷蓝) ~ +100 (暖黄)
  final double tint;        // 色调: -100 (偏绿) ~ +100 (洋红/品红)

  // 2. 基础色调 (Tone)
  final double exposure;    // 曝光度: -100 ~ +100 (-2EV ~ +2EV)
  final double contrast;    // 对比度: -100 (柔和灰阶) ~ +100 (高反差)
  final double highlights;  // 高光: -100 (压暗高光) ~ +100 (提亮高光)
  final double shadows;     // 阴影: -100 (压暗阴影) ~ +100 (提亮暗部死黑)
  final double whites;      // 白色色阶: -100 ~ +100 (高光白色剪切阈值)
  final double blacks;      // 黑色色阶: -100 ~ +100 (纯黑深度阈值)

  // 3. 偏好与细节质感 (Presence & Details)
  final double texture;     // 纹理: -100 (柔肤柔和) ~ +100 (微观表面肌理强化)
  final double clarity;     // 清晰度: -100 ~ +100 (中间调微反差质感)
  final double dehaze;      // 去朦胧: -100 (朦胧薄雾) ~ +100 (通透除霾)
  final double vibrance;    // 鲜艳度/自然饱和度: -100 ~ +100 (智能保肤色饱和度)
  final double saturation;  // 全局饱和度: -100 (灰度纯黑白) ~ +100 (浓郁纯色)

  // 4. 颜色分级 / 分离色调 (Color Grading / Split Toning)
  final double highlightHue; // 高光色相: 0° ~ 360° (如橙黄 35°~50°)
  final double highlightSat; // 高光饱和度: 0 ~ 100
  final double shadowHue;    // 阴影色相: 0° ~ 360° (如青蓝 200°~230°)
  final double shadowSat;    // 阴影饱和度: 0 ~ 100

  // 5. 镜头与质感效果 (Effects)
  final double vignette;    // 镜头暗角: -100 (高调白角) ~ +100 (经典电影黑暗角)
  final double grain;       // 胶片颗粒: 0 ~ 100 (真实银盐胶片颗粒感)

  const PhotoEditAdjustments({
    this.temperature = 0.0,
    this.tint = 0.0,
    this.exposure = 0.0,
    this.contrast = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.whites = 0.0,
    this.blacks = 0.0,
    this.texture = 0.0,
    this.clarity = 0.0,
    this.dehaze = 0.0,
    this.vibrance = 0.0,
    this.saturation = 0.0,
    this.highlightHue = 40.0,
    this.highlightSat = 0.0,
    this.shadowHue = 220.0,
    this.shadowSat = 0.0,
    this.vignette = 0.0,
    this.grain = 0.0,
  });

  /// 是否为完全默认状态 (零调节)
  bool get isDefault =>
      temperature == 0.0 &&
      tint == 0.0 &&
      exposure == 0.0 &&
      contrast == 0.0 &&
      highlights == 0.0 &&
      shadows == 0.0 &&
      whites == 0.0 &&
      blacks == 0.0 &&
      texture == 0.0 &&
      clarity == 0.0 &&
      dehaze == 0.0 &&
      vibrance == 0.0 &&
      saturation == 0.0 &&
      highlightSat == 0.0 &&
      shadowSat == 0.0 &&
      vignette == 0.0 &&
      grain == 0.0;

  PhotoEditAdjustments copyWith({
    double? temperature,
    double? tint,
    double? exposure,
    double? contrast,
    double? highlights,
    double? shadows,
    double? whites,
    double? blacks,
    double? texture,
    double? clarity,
    double? dehaze,
    double? vibrance,
    double? saturation,
    double? highlightHue,
    double? highlightSat,
    double? shadowHue,
    double? shadowSat,
    double? vignette,
    double? grain,
  }) {
    return PhotoEditAdjustments(
      temperature: temperature ?? this.temperature,
      tint: tint ?? this.tint,
      exposure: exposure ?? this.exposure,
      contrast: contrast ?? this.contrast,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      whites: whites ?? this.whites,
      blacks: blacks ?? this.blacks,
      texture: texture ?? this.texture,
      clarity: clarity ?? this.clarity,
      dehaze: dehaze ?? this.dehaze,
      vibrance: vibrance ?? this.vibrance,
      saturation: saturation ?? this.saturation,
      highlightHue: highlightHue ?? this.highlightHue,
      highlightSat: highlightSat ?? this.highlightSat,
      shadowHue: shadowHue ?? this.shadowHue,
      shadowSat: shadowSat ?? this.shadowSat,
      vignette: vignette ?? this.vignette,
      grain: grain ?? this.grain,
    );
  }

  static const PhotoEditAdjustments initial = PhotoEditAdjustments();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhotoEditAdjustments &&
          runtimeType == other.runtimeType &&
          temperature == other.temperature &&
          tint == other.tint &&
          exposure == other.exposure &&
          contrast == other.contrast &&
          highlights == other.highlights &&
          shadows == other.shadows &&
          whites == other.whites &&
          blacks == other.blacks &&
          texture == other.texture &&
          clarity == other.clarity &&
          dehaze == other.dehaze &&
          vibrance == other.vibrance &&
          saturation == other.saturation &&
          highlightHue == other.highlightHue &&
          highlightSat == other.highlightSat &&
          shadowHue == other.shadowHue &&
          shadowSat == other.shadowSat &&
          vignette == other.vignette &&
          grain == other.grain;

  @override
  int get hashCode => Object.hashAll([
        temperature,
        tint,
        exposure,
        contrast,
        highlights,
        shadows,
        whites,
        blacks,
        texture,
        clarity,
        dehaze,
        vibrance,
        saturation,
        highlightHue,
        highlightSat,
        shadowHue,
        shadowSat,
        vignette,
        grain,
      ]);
}

/// 直出胶片与大师调色预设枚举 (涵盖 77 款相机实拍配方 + 10 款经典精选)
enum PhotoFilterType {
  sonyFactoryST(
    label: '出厂标准',
    code: 'FACTORY ST',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '索尼出厂标准色彩 · 真实中性还原',
    recipeSummary: '标准',
    previewColors: [Color(0xFF333333), Color(0xFF888888), Color(0xFFCCCCCC)],
    presetAdjustments: const PhotoEditAdjustments(
    ),
  ),
  sonyPT(
    label: '索尼 PT（人像）',
    code: 'Sony PT',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '柔和肤色优化 · 肖像透亮层次',
    recipeSummary: '肖像',
    previewColors: [Color(0xFFFAD0C4), Color(0xFFFFD1FF), Color(0xFFE0C3FC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 2.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: 6.0,
      saturation: -4.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  sonyNT(
    label: '索尼 NT（中性）',
    code: 'Sony NT',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '低反差平滑曲线 · 宽容度保留',
    recipeSummary: '中性',
    previewColors: [Color(0xFF757F9A), Color(0xFFD7DDE8), Color(0xFF9E9E9E)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -8.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -6.0,
    ),
  ),
  sonyVV(
    label: '索尼 VV（鲜艳）',
    code: 'Sony VV',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '高纯度原色强化 · 风光与艳丽场景',
    recipeSummary: '鲜艳',
    previewColors: [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFFFF8A00)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 8.0,
      dehaze: 6.0,
      vibrance: 16.0,
      saturation: 12.0,
    ),
  ),
  sonyVV2(
    label: '索尼 VV2',
    code: 'Sony VV2',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '进阶浓郁鲜活 · 阳光明媚视觉张力',
    recipeSummary: '鲜艳 · 饱和+2 · 对比+1',
    previewColors: [Color(0xFFFF416C), Color(0xFFFF4B2B), Color(0xFFF7971E)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 18.0,
      dehaze: 6.0,
      vibrance: 32.0,
      saturation: 36.0,
    ),
  ),
  sonyFL(
    label: '索尼 FL（胶片风格）',
    code: 'Sony FL',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '网红复古胶片感 · 暖琥珀调色与青蓝暗调',
    recipeSummary: '中性 · 饱和-3 · 对比-1 · A1',
    previewColors: [Color(0xFF2C3E50), Color(0xFF4CA1AF), Color(0xFFE8D3A2)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      contrast: -18.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  sonyIN(
    label: '索尼 IN（即时）',
    code: 'Sony IN',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '哑光柔雾质感 · 洋红微调 · 日系情绪片',
    recipeSummary: '中性 · 饱和-3 · 对比-3 · M1',
    previewColors: [Color(0xFFE0C3FC), Color(0xFF8EC5FC), Color(0xFFD4B2D8)],
    presetAdjustments: const PhotoEditAdjustments(
      tint: 7.0,
      contrast: -38.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  sonySH(
    label: '索尼 SH（柔和高调）',
    code: 'Sony SH',
    category1: '索尼大师',
    category2: '索尼创意外观',
    description: '通透高光泛蓝 · 梦幻空灵高调人像',
    recipeSummary: '清淡 · 饱和-2 · 对比-2 · A1 · +1.0EV · 柔和高调 (蓝色)',
    previewColors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      exposure: 52.0,
      contrast: -34.0,
      highlights: -24.0,
      shadows: 40.0,
      whites: 8.0,
      texture: -20.0,
      vibrance: -22.0,
      saturation: -24.0,
      highlightHue: 215.0,
      highlightSat: 16.0,
      shadowHue: 210.0,
      shadowSat: 12.0,
    ),
  ),
  fujiProvia(
    label: 'PROVIA 标准',
    code: 'Provia',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '全能基准 · 真实平衡的富士标志性直出',
    recipeSummary: '标准 · 饱和+1',
    previewColors: [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFE53935)],
    presetAdjustments: const PhotoEditAdjustments(
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  fujiVelvia(
    label: 'Velvia 鲜艳',
    code: 'Velvia',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '风光王者 · 极高饱和度与反差 · 碧海蓝天翠绿',
    recipeSummary: '鲜艳 · 饱和+3 · 对比+2',
    previewColors: [Color(0xFFD81B60), Color(0xFF00ACC1), Color(0xFF7CB342)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 28.0,
      dehaze: 6.0,
      vibrance: 40.0,
      saturation: 48.0,
    ),
  ),
  fujiAstia(
    label: 'ASTIA 柔和',
    code: 'Astia',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '人像特调 · 柔和高光过渡与通透暖色肤感',
    recipeSummary: '肖像 · 对比-1 · A1 · +0.3EV',
    previewColors: [Color(0xFFFFAB91), Color(0xFFFFCC80), Color(0xFFF48FB1)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 8.0,
      exposure: 9.0,
      contrast: -10.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: 6.0,
      saturation: -4.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  classicChrome(
    label: '经典正片',
    code: 'Classic Chrome',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '人文纪实传奇 · 低彩度硬反差 · 沉稳冷峻青蓝',
    recipeSummary: '标准 · 饱和-1 · 对比+2 · A3 G1 · -0.3EV',
    previewColors: [Color(0xFF455A64), Color(0xFF78909C), Color(0xFFD7CCC8)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 22.0,
      tint: -6.0,
      exposure: -9.0,
      contrast: 20.0,
      vibrance: -8.0,
      saturation: -12.0,
    ),
  ),
  fujiClassicNegative(
    label: '经典负片',
    code: 'Classic Neg',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: 'Superia 负片风骨 · 独特青绿暗部与高反差怀旧',
    recipeSummary: '标准 · 饱和-3 · 对比+3 · 锐度+1 · B1 G1',
    previewColors: [Color(0xFF2E7D32), Color(0xFF8D6E63), Color(0xFFC2185B)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      tint: -6.0,
      contrast: 30.0,
      texture: 10.0,
      clarity: 8.0,
      vibrance: -24.0,
      saturation: -36.0,
    ),
  ),
  fujiNostalgicNeg(
    label: '怀旧负片',
    code: 'Nostalgic Neg',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '琥珀金色高光 · 70年代美国新彩色摄影色调',
    recipeSummary: '标准 · 饱和+1 · A3',
    previewColors: [Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFF8D6E63)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 22.0,
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  fujiRealaAce(
    label: 'REALA ACE',
    code: 'Reala Ace',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '第四感色层技术 · 真实细腻 · 硬朗适中现代感',
    recipeSummary: '标准 · 对比+1',
    previewColors: [Color(0xFF29B6F6), Color(0xFF66BB6A), Color(0xFFFFA726)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 10.0,
    ),
  ),
  fujiProNegStd(
    label: 'PRO Neg. 标准',
    code: 'Pro Neg Std',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '影棚专业人像 · 极度平滑渐变 · 肤色柔和自然',
    recipeSummary: '肖像 · 饱和-2 · 对比-1',
    previewColors: [Color(0xFFFFCCBC), Color(0xFFD7CCC8), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 2.0,
      contrast: -10.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -10.0,
      saturation: -28.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  fujiProNegHi(
    label: 'PRO Neg. 高',
    code: 'Pro Neg Hi',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '户外人像首选 · 保持肤色同时增强背景立体轮廓',
    recipeSummary: '肖像 · 饱和-2 · 对比+1',
    previewColors: [Color(0xFFFFAB91), Color(0xFFB0BEC5), Color(0xFF8D6E63)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 2.0,
      contrast: 10.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -10.0,
      saturation: -28.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  fujiEterna(
    label: 'ETERNA 影院',
    code: 'Eterna',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '电影工业级胶卷 · 柔和低保真 · 宽广暗部动态',
    recipeSummary: '中性 · 饱和-3 · 对比-2 · 锐度-1 · -0.3EV · DRO 等级 3',
    previewColors: [Color(0xFF546E7A), Color(0xFF78909C), Color(0xFF90A4AE)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: -9.0,
      contrast: -28.0,
      highlights: -24.0,
      shadows: 36.0,
      texture: -10.0,
      clarity: -8.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  fujiEternaBleach(
    label: 'ETERNA 漂白效果',
    code: 'Eterna Bleach',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '跳银冲洗洗印工艺 · 极低饱和度与强烈金属反差',
    recipeSummary: '中性 · 饱和-3 · 对比+3 · -0.3EV · DRO 关闭',
    previewColors: [Color(0xFF37474F), Color(0xFF607D8B), Color(0xFFB0BEC5)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: -9.0,
      contrast: 22.0,
      highlights: -10.0,
      shadows: 4.0,
      blacks: -10.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  fujiAcros(
    label: 'ACROS 黑白',
    code: 'Acros',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '富士顶级银盐黑白 · 极其细腻的灰阶过渡与微反差',
    recipeSummary: '黑白 · 对比+1 · 锐度+1',
    previewColors: [Color(0xFF212121), Color(0xFF757575), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 24.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  fujiAcrosYe(
    label: 'ACROS +Ye（黄滤镜）',
    code: 'Acros +Ye',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '加黄滤镜压暗天空 · 强化云层质感与人像轮廓',
    recipeSummary: '黑白 · 对比+1 · 锐度+1 · 4000K',
    previewColors: [Color(0xFF263238), Color(0xFF607D8B), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -28.0,
      contrast: 24.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  fujiAcrosR(
    label: 'ACROS +R（红滤镜）',
    code: 'Acros +R',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '红镜强对比戏剧张力 · 强烈黑白视觉冲击',
    recipeSummary: '黑白 · 2500K · 高对比度黑白',
    previewColors: [Color(0xFF1A1A1A), Color(0xFF616161), Color(0xFFF5F5F5)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -62.0,
      contrast: 50.0,
      blacks: -16.0,
      clarity: 34.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 30.0,
    ),
  ),
  fujiAcrosG(
    label: 'ACROS +G（绿滤镜）',
    code: 'Acros +G',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '绿镜保肤色唇色 · 柔和肖像与植物细腻层次',
    recipeSummary: '黑白 · 对比+1 · 锐度+1 · 5600K · G4',
    previewColors: [Color(0xFF2E3D30), Color(0xFF6A8572), Color(0xFFD8E2DC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 4.0,
      tint: -24.0,
      contrast: 24.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  fujiSepia(
    label: '富士 棕褐色',
    code: 'Sepia',
    category1: '富士胶片',
    category2: '胶片模拟',
    description: '世纪初银盐暖棕调 · 岁月痕迹与怀旧典雅氛围',
    recipeSummary: '棕褐色',
    previewColors: [Color(0xFF5D4037), Color(0xFF8D6E63), Color(0xFFD7CCC8)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 22.0,
      tint: 6.0,
      contrast: 6.0,
      vibrance: -80.0,
      saturation: -80.0,
      highlightHue: 44.0,
      highlightSat: 28.0,
      shadowHue: 36.0,
      shadowSat: 30.0,
    ),
  ),
  fujiPro400H(
    label: '富士 Pro 400H',
    code: 'Pro 400H',
    category1: '富士胶片',
    category2: '经典胶卷',
    description: '清新通透日系胶卷 · 蓝绿空气感与高光柔粉',
    recipeSummary: '清淡 · 饱和-2 · 对比-2 · B1 G1 · +0.7EV',
    previewColors: [Color(0xFF80DEEA), Color(0xFFA5D6A7), Color(0xFFFFF59D)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      tint: -6.0,
      exposure: 31.0,
      contrast: -34.0,
      highlights: -10.0,
      shadows: 18.0,
      whites: 8.0,
      texture: -8.0,
      vibrance: -22.0,
      saturation: -24.0,
    ),
  ),
  fujiFortia50(
    label: '富士 Fortia 50',
    code: 'Fortia 50',
    category1: '富士胶片',
    category2: '经典胶卷',
    description: '限定版高饱和反转片 · 极度鲜艳强烈的四季色彩',
    recipeSummary: '鲜艳 · 饱和+3 · 对比+2 · B1 · -0.3EV',
    previewColors: [Color(0xFF00B0FF), Color(0xFF00E676), Color(0xFFFF3D00)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      exposure: -9.0,
      contrast: 28.0,
      dehaze: 6.0,
      vibrance: 40.0,
      saturation: 48.0,
    ),
  ),
  fujiSuperia400(
    label: '富士 Superia 400',
    code: 'Superia 400',
    category1: '富士胶片',
    category2: '经典胶卷',
    description: '生活纪实常备负片 · 标志性青绿暗部与红橙暖意',
    recipeSummary: '标准 · 饱和+1 · 对比+1 · A1 G1 · +0.3EV',
    previewColors: [Color(0xFF26A69A), Color(0xFFFF7043), Color(0xFFFFA726)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      tint: -6.0,
      exposure: 9.0,
      contrast: 10.0,
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  fujiC200(
    label: '富士 C200',
    code: 'Fuji C200',
    category1: '富士胶片',
    category2: '经典胶卷',
    description: '日常随身胶片 · 平实自然带微青的日光还原',
    recipeSummary: '标准 · B1 G1',
    previewColors: [Color(0xFF4DB6AC), Color(0xFFFFB74D), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      tint: -6.0,
    ),
  ),
  fujiNatura1600(
    label: '富士 Natura 1600',
    code: 'Natura 1600',
    category1: '富士胶片',
    category2: '经典胶卷',
    description: '夜景与室内弱光神卷 · 温暖通透的微光纪实氛围',
    recipeSummary: '肖像 · 饱和-2 · 对比-2 · A1 · +0.3EV',
    previewColors: [Color(0xFFFFCC80), Color(0xFFB0BEC5), Color(0xFFD7CCC8)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 8.0,
      exposure: 9.0,
      contrast: -20.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -10.0,
      saturation: -28.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  kodakPortra160(
    label: '柯达 Portra 160',
    code: 'Portra 160',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '极其细腻平滑的低反差肤色表现 · 时尚大片首选',
    recipeSummary: '肖像 · 饱和-3 · 对比-2 · A1 M1 · +0.7EV',
    previewColors: [Color(0xFFFFCCBC), Color(0xFFFFE0B2), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 8.0,
      tint: 7.0,
      exposure: 21.0,
      contrast: -20.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -18.0,
      saturation: -40.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  kodakPortra400(
    label: '柯达 Portra 400',
    code: 'Portra 400',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '全球最畅销胶卷 · 温暖金黄日光感 · 绝美自然肤质',
    recipeSummary: '肖像 · 饱和-1 · 对比-1 · A3 G1 · +0.7EV',
    previewColors: [Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFF90A4AE)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 24.0,
      tint: -6.0,
      exposure: 21.0,
      contrast: -10.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -2.0,
      saturation: -16.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  kodakPortra800(
    label: '柯达 Portra 800',
    code: 'Portra 800',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '高感光暖调色彩 · 柔和阴影细节与丰富质感',
    recipeSummary: '肖像 · 饱和-2 · 对比-2 · A1 G1 · +0.3EV',
    previewColors: [Color(0xFFFFA726), Color(0xFF81C784), Color(0xFFB0BEC5)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 8.0,
      tint: -6.0,
      exposure: 9.0,
      contrast: -20.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -10.0,
      clarity: -6.0,
      vibrance: -10.0,
      saturation: -28.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  kodakGold200(
    label: '柯达 Gold 200',
    code: 'Gold 200',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '夏日午后阳光金黄 · 浓郁暖调复古生活画卷',
    recipeSummary: '标准 · 饱和+2 · 对比+1 · A3 G1 · +0.3EV',
    previewColors: [Color(0xFFFFB300), Color(0xFFF57C00), Color(0xFF43A047)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 22.0,
      tint: -6.0,
      exposure: 9.0,
      contrast: 10.0,
      vibrance: 16.0,
      saturation: 24.0,
    ),
  ),
  kodakUltraMax400(
    label: '柯达 Ultra Max 400',
    code: 'UltraMax 400',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '鲜活纯正的三原色对比 · 蔚蓝晴空与明快生活纪实',
    recipeSummary: '标准 · G1 · +0.3EV',
    previewColors: [Color(0xFF1976D2), Color(0xFFFFA000), Color(0xFF388E3C)],
    presetAdjustments: const PhotoEditAdjustments(
      tint: -6.0,
      exposure: 9.0,
    ),
  ),
  kodakColorPlus200(
    label: '柯达 Color Plus 200',
    code: 'ColorPlus 200',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '平价经典暖胶卷 · 泛黄复古胶片感与老照片记忆',
    recipeSummary: '标准 · 饱和+1 · 对比+1 · A2 G1 · +0.3EV',
    previewColors: [Color(0xFFFF8F00), Color(0xFFF4511E), Color(0xFF43A047)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 14.0,
      tint: -6.0,
      exposure: 9.0,
      contrast: 10.0,
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  kodakEktar100(
    label: '柯达 Ektar 100',
    code: 'Ektar 100',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '世界上最细腻胶卷 · 极致高饱和与锐利风光色彩',
    recipeSummary: '标准 · 饱和+3 · 对比+1 · 锐度+1 · -0.3EV',
    previewColors: [Color(0xFFD32F2F), Color(0xFF1976D2), Color(0xFF388E3C)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: -9.0,
      contrast: 10.0,
      texture: 10.0,
      clarity: 8.0,
      vibrance: 24.0,
      saturation: 36.0,
    ),
  ),
  kodakE100(
    label: '柯达 Ektachrome E100',
    code: 'E100',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '传奇彩色反转片复产 · 清澈透蓝与纯净高光反差',
    recipeSummary: '清澈 · 饱和+3 · 对比+1 · B1 · -0.3EV',
    previewColors: [Color(0xFF0288D1), Color(0xFF0097A7), Color(0xFFE64A19)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      exposure: -9.0,
      contrast: 20.0,
      highlights: -10.0,
      shadows: 8.0,
      clarity: 16.0,
      dehaze: 12.0,
      vibrance: 34.0,
      saturation: 36.0,
    ),
  ),
  kodachrome64(
    label: 'Kodachrome 64',
    code: 'Kodachrome 64',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '国家地理封面传奇 · 深邃厚重的红黄质感与不朽经典',
    recipeSummary: '深邃 · 饱和+3 · 对比+2 · 锐度+1 · B1 · -0.3EV',
    previewColors: [Color(0xFFB71C1C), Color(0xFF0D47A1), Color(0xFFF57F17)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      exposure: -9.0,
      contrast: 36.0,
      shadows: -12.0,
      blacks: -14.0,
      texture: 10.0,
      clarity: 8.0,
      vibrance: 36.0,
      saturation: 48.0,
    ),
  ),
  kodakVision3500T(
    label: '柯达 Vision3 500T（日光）',
    code: 'Vision3 500T',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '好莱坞钨丝灯电影卷 · 蓝调日光对撞与光晕暗部',
    recipeSummary: '中性 · 饱和-1 · 3200K · +0.3EV · DRO 等级 3',
    previewColors: [Color(0xFF0277BD), Color(0xFF455A64), Color(0xFFFF7043)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -45.0,
      exposure: 9.0,
      contrast: -8.0,
      highlights: -24.0,
      shadows: 36.0,
      vibrance: -14.0,
      saturation: -12.0,
    ),
  ),
  kodakVision200T(
    label: '柯达 Vision 200T（小行星城）',
    code: 'Vision 200T',
    category1: '柯达胶片',
    category2: '彩色负片',
    description: '韦斯安德森风复古色调 · 柔和低反差黄绿粉黛童话感',
    recipeSummary: '中性 · 饱和-2 · 对比-3 · 5000K · A2 G3 · +0.3EV · DRO 等级 3',
    previewColors: [Color(0xFFFBC02D), Color(0xFF80CBC4), Color(0xFFBCAAA4)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 2.0,
      tint: -18.0,
      exposure: 9.0,
      contrast: -38.0,
      highlights: -24.0,
      shadows: 36.0,
      vibrance: -22.0,
      saturation: -24.0,
    ),
  ),
  kodakTriX400(
    label: '柯达 Tri-X 400',
    code: 'Tri-X 400',
    category1: '柯达胶片',
    category2: '柯达黑白',
    description: '新闻摄影不朽标杆 · 硬朗反差与经典银盐颗粒',
    recipeSummary: '黑白 · 对比+2 · 锐度+2 · +0.3EV',
    previewColors: [Color(0xFF212121), Color(0xFF616161), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: 9.0,
      contrast: 34.0,
      texture: 20.0,
      clarity: 26.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  kodakTMax(
    label: '柯达 T-Max',
    code: 'T-Max',
    category1: '柯达胶片',
    category2: '柯达黑白',
    description: 'T 颗粒现代乳剂 · 极高清晰度与纯净深邃黑阶',
    recipeSummary: '黑白 · 对比+2 · 锐度+3',
    previewColors: [Color(0xFF1A1A1A), Color(0xFF757575), Color(0xFFEEEEEE)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 34.0,
      texture: 30.0,
      clarity: 34.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  kodakTriX1600(
    label: '柯达 Tri-X 1600（增感）',
    code: 'Tri-X 1600',
    category1: '柯达胶片',
    category2: '柯达黑白',
    description: '增感暗房暴力冲洗 · 粗粝颗粒与高反差街头纪实',
    recipeSummary: '黑白 · +0.3EV · 高对比度黑白',
    previewColors: [Color(0xFF000000), Color(0xFF424242), Color(0xFFFFFFFF)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: 9.0,
      contrast: 50.0,
      blacks: -16.0,
      clarity: 34.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 30.0,
    ),
  ),
  cineStill50D(
    label: 'CineStill 50D（蓝丝绒）',
    code: 'CineStill 50D',
    category1: '电影特色',
    category2: '电影风格',
    description: '日光电影胶卷去碳层 · 细腻纯净与冷蓝丝绒高光',
    recipeSummary: '标准 · 饱和-2 · 对比-1 · 5500K · B1 M1',
    previewColors: [Color(0xFF1565C0), Color(0xFF8E24AA), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -5.0,
      tint: 7.0,
      contrast: -10.0,
      vibrance: -16.0,
      saturation: -24.0,
    ),
  ),
  cineStill800T(
    label: 'CineStill 800T',
    code: 'CineStill 800T',
    category1: '电影特色',
    category2: '电影风格',
    description: '夜景霓虹神卷 · 冷艳青蓝基调与高光红色光晕光斑',
    recipeSummary: '中性 · 3200K · M1 · +0.3EV',
    previewColors: [Color(0xFF0D47A1), Color(0xFFD81B60), Color(0xFF00ACC1)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -45.0,
      tint: 7.0,
      exposure: 9.0,
      contrast: -8.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -6.0,
    ),
  ),
  classicCinema(
    label: '经典电影',
    code: 'Classic Cinema',
    category1: '电影特色',
    category2: '电影风格',
    description: '大银幕叙事色调 · 暖黄暖调高光与高宽容度暗部',
    recipeSummary: '标准 · 对比-1 · 6000K · A2 · DRO 等级 3',
    previewColors: [Color(0xFFE65100), Color(0xFF006064), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 30.0,
      contrast: -10.0,
      highlights: -14.0,
      shadows: 22.0,
    ),
  ),
  rec709Video(
    label: 'Rec.709 视频（低对比）',
    code: 'Rec.709',
    category1: '电影特色',
    category2: '电影风格',
    description: '广电级低反差Log还原 · 超柔和中间调灰阶',
    recipeSummary: '中性 · 饱和-2 · 对比-2 · DRO 等级 5',
    previewColors: [Color(0xFF607D8B), Color(0xFF78909C), Color(0xFF90A4AE)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -28.0,
      highlights: -32.0,
      shadows: 54.0,
      blacks: 8.0,
      vibrance: -22.0,
      saturation: -24.0,
    ),
  ),
  ricohGRPositive(
    label: 'GR 正片',
    code: 'GR Positive',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '街头抓拍之王 · 极具冲击力的高反差高饱和正片色',
    recipeSummary: '标准 · 饱和+3 · 对比+2 · A2 · -0.3EV',
    previewColors: [Color(0xFF0288D1), Color(0xFFF57C00), Color(0xFF388E3C)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 14.0,
      exposure: -9.0,
      contrast: 20.0,
      vibrance: 24.0,
      saturation: 36.0,
    ),
  ),
  ricohGRNegative(
    label: 'GR 负片',
    code: 'GR Negative',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: 'GR3 固件新宠 · 偏青冷绿的人文纪实空气感',
    recipeSummary: '中性 · 饱和-2 · 对比+1 · B1 G1 · +0.3EV',
    previewColors: [Color(0xFF455A64), Color(0xFF8D6E63), Color(0xFF00897B)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -7.0,
      tint: -6.0,
      exposure: 9.0,
      contrast: 2.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -22.0,
      saturation: -24.0,
    ),
  ),
  ricohGRBleach(
    label: 'GR 漂白效果',
    code: 'GR Bleach',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '硬朗冷峻 · 工业金属感与高反差褪色质感',
    recipeSummary: '中性 · 饱和-3 · 对比+3 · 锐度+1 · DRO 关闭',
    previewColors: [Color(0xFF37474F), Color(0xFF78909C), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 22.0,
      highlights: -10.0,
      shadows: 4.0,
      blacks: -10.0,
      texture: 10.0,
      clarity: 8.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  ricohGRRetro(
    label: 'GR 复古',
    code: 'GR Retro',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '泛黄怀旧老镜头感 · 暗角胶片颗粒与咖啡馆暖调',
    recipeSummary: '标准 · 饱和-3 · 对比-1 · A3 M1 · 复古照片',
    previewColors: [Color(0xFF6D4C41), Color(0xFFFFA000), Color(0xFFD7CCC8)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 44.0,
      tint: 15.0,
      contrast: -10.0,
      vibrance: -24.0,
      saturation: -36.0,
      highlightHue: 45.0,
      highlightSat: 20.0,
      shadowHue: 48.0,
      shadowSat: 18.0,
      vignette: 18.0,
      grain: 18.0,
    ),
  ),
  ricohGRCross(
    label: 'GR 正负逆冲',
    code: 'GR Cross Proc',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '暗房正片负冲 · 迷幻品青对撞与超现实色偏',
    recipeSummary: '鲜艳 · 饱和+2 · 对比+2 · B2 G4',
    previewColors: [Color(0xFF00BFA5), Color(0xFFAA00FF), Color(0xFFFFD600)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: -16.0,
      tint: -24.0,
      contrast: 28.0,
      dehaze: 6.0,
      vibrance: 32.0,
      saturation: 36.0,
    ),
  ),
  ricohGRHiBw(
    label: 'GR 高对比度黑白',
    code: 'GR Hi-B&W',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '森山大道式粗粝硬派 · 纯黑纯白极致张力',
    recipeSummary: '黑白 · 对比+3 · 锐度+1 · 高对比度黑白',
    previewColors: [Color(0xFF000000), Color(0xFF616161), Color(0xFFFFFFFF)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 80.0,
      blacks: -16.0,
      texture: 10.0,
      clarity: 42.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 30.0,
    ),
  ),
  ricohGRHardBw(
    label: 'GR 硬调黑白',
    code: 'GR Hard Mono',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '硬调清晰反差 · 建筑与光影线条雕刻感',
    recipeSummary: '黑白 · 对比+2 · 锐度+2',
    previewColors: [Color(0xFF212121), Color(0xFF757575), Color(0xFFEEEEEE)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 34.0,
      texture: 20.0,
      clarity: 26.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  ricohGRSoftBw(
    label: 'GR 柔调黑白',
    code: 'GR Soft Mono',
    category1: '理光人文',
    category2: 'GR 影像控制',
    description: '柔和灰调 · 丰富中间调灰阶 · 细腻宁静',
    recipeSummary: '黑白 · 对比-2 · 锐度-1',
    previewColors: [Color(0xFF616161), Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -6.0,
      texture: -10.0,
      clarity: 2.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  leicaContemporary(
    label: '徕卡 当代',
    code: 'Leica Contemp',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    description: '现代德味高保真 · 扎实厚重色彩与纯正暗部',
    recipeSummary: '标准 · 饱和+1 · 对比+1',
    previewColors: [Color(0xFFD32F2F), Color(0xFF1976D2), Color(0xFF212121)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 10.0,
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  leicaClassic(
    label: '徕卡 经典',
    code: 'Leica Classic',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    description: '经典古典德味 · 微暖油润层次 · 空气切割感',
    recipeSummary: '标准 · 饱和-1 · 对比+2 · A1',
    previewColors: [Color(0xFFC62828), Color(0xFF455A64), Color(0xFFECEFF1)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      contrast: 20.0,
      vibrance: -8.0,
      saturation: -12.0,
    ),
  ),
  leicaEternal(
    label: '徕卡 永恒',
    code: 'Leica Eternal',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    description: '沉稳克制 · 高动态灰调与电影旁轴叙事',
    recipeSummary: '中性 · 饱和-3 · 对比-1 · A1 · DRO 等级 3',
    previewColors: [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFD7CCC8)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      contrast: -18.0,
      highlights: -24.0,
      shadows: 36.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  leicaMonochrome(
    label: '徕卡 黑白',
    code: 'Leica Mono',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    description: '旁轴纯粹银盐 · 无与伦比的深沉灰阶与影调',
    recipeSummary: '黑白 · 对比+2 · 锐度+1',
    previewColors: [Color(0xFF1A1A1A), Color(0xFF757575), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 34.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  hasselbladHNCS(
    label: '哈苏 HNCS 自然',
    code: 'Hasselblad HNCS',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    description: '哈苏自然色彩解决方案 · 真实平顺细腻的大画幅质感',
    recipeSummary: '中性 · 饱和-1 · 对比-1',
    previewColors: [Color(0xFF37474F), Color(0xFF8D6E63), Color(0xFFECEFF1)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -18.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -14.0,
      saturation: -12.0,
    ),
  ),
  canonStandard(
    label: '佳能 标准',
    code: 'Canon Std',
    category1: '索尼大师',
    category2: '佳能与尼康',
    description: '佳能明亮发色 · 洋红微提暖调 · 讨喜高光',
    recipeSummary: '标准 · 饱和+1 · 对比+1 · A1 M1',
    previewColors: [Color(0xFFE53935), Color(0xFFFFB74D), Color(0xFF1E88E5)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 6.0,
      tint: 7.0,
      contrast: 10.0,
      vibrance: 8.0,
      saturation: 12.0,
    ),
  ),
  canonPortrait(
    label: '佳能 人像',
    code: 'Canon Portrait',
    category1: '索尼大师',
    category2: '佳能与尼康',
    description: '白里透红神级肤质 · 柔焦中间调微反差',
    recipeSummary: '肖像 · 锐度-1 · A1 M1',
    previewColors: [Color(0xFFFFCDD2), Color(0xFFFFE0B2), Color(0xFFE1BEE7)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 8.0,
      tint: 7.0,
      highlights: -8.0,
      shadows: 14.0,
      texture: -20.0,
      clarity: -14.0,
      vibrance: 6.0,
      saturation: -4.0,
      highlightHue: 350.0,
      highlightSat: 6.0,
    ),
  ),
  canonFaithful(
    label: '佳能 可靠设置',
    code: 'Canon Faithful',
    category1: '索尼大师',
    category2: '佳能与尼康',
    description: '商业摄影标准还原 · 严格遵从日光色准',
    recipeSummary: '中性',
    previewColors: [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFECEFF1)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -8.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -6.0,
    ),
  ),
  nikonFlat(
    label: '尼康 平面',
    code: 'Nikon Flat',
    category1: '索尼大师',
    category2: '佳能与尼康',
    description: '尼康极致宽容度 · 压高光提暗部平直曲线',
    recipeSummary: '中性 · 饱和-3 · 对比-3 · 锐度-1 · DRO 等级 5',
    previewColors: [Color(0xFF607D8B), Color(0xFF90A4AE), Color(0xFFCFD8DC)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: -38.0,
      highlights: -32.0,
      shadows: 54.0,
      blacks: 8.0,
      texture: -10.0,
      clarity: -8.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  nikonVivid(
    label: '尼康 鲜艳',
    code: 'Nikon Vivid',
    category1: '索尼大师',
    category2: '佳能与尼康',
    description: '尼康经典风景 · 金黄色调与青透天空高锐度',
    recipeSummary: '鲜艳 · 饱和+1 · 对比+1 · 锐度+1',
    previewColors: [Color(0xFFFFD700), Color(0xFF0D47A1), Color(0xFF2E7D32)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 18.0,
      texture: 10.0,
      clarity: 8.0,
      dehaze: 6.0,
      vibrance: 24.0,
      saturation: 24.0,
    ),
  ),
  panaLMonochromeD(
    label: '松下 L.黑白 D',
    code: 'Pana L.Mono D',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    description: '动态黑白 · 亮部沉稳暗部扎实 · 层次分明',
    recipeSummary: '黑白 · 对比+3 · 锐度+1',
    previewColors: [Color(0xFF1A1A1A), Color(0xFF616161), Color(0xFFEEEEEE)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 44.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  panaLClassicNeo(
    label: '松下 L.经典 Neo',
    code: 'Pana L.Neo',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    description: '复古胶片低保真 · 柔暖黄光影感 · 岁月静好',
    recipeSummary: '中性 · 饱和-3 · 对比-1 · A2 · +0.3EV',
    previewColors: [Color(0xFF546E7A), Color(0xFFFFA726), Color(0xFFB0BEC5)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 14.0,
      exposure: 9.0,
      contrast: -18.0,
      highlights: -10.0,
      shadows: 14.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  olympusPopArt(
    label: '奥林巴斯 浓郁色调',
    code: 'Olympus PopArt',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    description: '奥巴蓝传奇 · 浓郁饱满视觉冲击波普艺术',
    recipeSummary: '鲜艳 · 饱和+3 · 对比+3',
    previewColors: [Color(0xFFFF1744), Color(0xFF00E676), Color(0xFF2979FF)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 38.0,
      dehaze: 6.0,
      vibrance: 40.0,
      saturation: 48.0,
    ),
  ),
  olympusPaleLight(
    label: '奥林巴斯 淡化增亮',
    code: 'Olympus Pale',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    description: '淡雅高光增亮 · 柔美清透马卡龙日系空气感',
    recipeSummary: '清淡 · 饱和-3 · 对比-2 · +0.7EV',
    previewColors: [Color(0xFFE0F7FA), Color(0xFFFFF9C4), Color(0xFFF8BBD0)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: 31.0,
      contrast: -34.0,
      highlights: -10.0,
      shadows: 18.0,
      whites: 8.0,
      texture: -8.0,
      vibrance: -30.0,
      saturation: -36.0,
    ),
  ),
  agfaVista200(
    label: '爱克发 Vista 200',
    code: 'Vista 200',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    description: '爱克发经典红标色彩 · 艳丽红暖与深沉冷色对撞',
    recipeSummary: '标准 · 饱和+2 · 对比+1 · A2 M1 · +0.3EV',
    previewColors: [Color(0xFFC62828), Color(0xFF1565C0), Color(0xFFF57F17)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 14.0,
      tint: 7.0,
      exposure: 9.0,
      contrast: 10.0,
      vibrance: 16.0,
      saturation: 24.0,
    ),
  ),
  agfaUltra100(
    label: '爱克发 Ultra 100',
    code: 'Ultra 100',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    description: '超高饱和度欧洲胶片 · 纯度极高的风光艳丽感',
    recipeSummary: '鲜艳 · 饱和+3 · 对比+1',
    previewColors: [Color(0xFFE53935), Color(0xFF43A047), Color(0xFF039BE5)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 18.0,
      dehaze: 6.0,
      vibrance: 40.0,
      saturation: 48.0,
    ),
  ),
  polaroidInstax(
    label: '宝丽来 / instax',
    code: 'Polaroid',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    description: '即显胶片独有泛白褪色 · 暖调暗角与岁月印记',
    recipeSummary: '标准 · 饱和-3 · 对比-2 · A1 M2 · +0.3EV · 复古照片',
    previewColors: [Color(0xFFECEFF1), Color(0xFFFFE082), Color(0xFF80CBC4)],
    presetAdjustments: const PhotoEditAdjustments(
      temperature: 28.0,
      tint: 23.0,
      exposure: 9.0,
      contrast: -20.0,
      vibrance: -24.0,
      saturation: -36.0,
      highlightHue: 45.0,
      highlightSat: 20.0,
      shadowHue: 48.0,
      shadowSat: 18.0,
      vignette: 18.0,
      grain: 18.0,
    ),
  ),
  ilfordHP5(
    label: '伊尔福 HP5',
    code: 'Ilford HP5',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    description: '英国专业银盐之冠 · 极佳宽容度与柔和颗粒',
    recipeSummary: '黑白 · 对比+1 · +0.3EV',
    previewColors: [Color(0xFF212121), Color(0xFF616161), Color(0xFFE0E0E0)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: 9.0,
      contrast: 24.0,
      clarity: 10.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  ilfordFP4(
    label: '伊尔福 FP4',
    code: 'Ilford FP4',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    description: '中速高反差精细胶卷 · 锐利明朗的黑白线条',
    recipeSummary: '黑白 · 对比+1 · 锐度+1',
    previewColors: [Color(0xFF263238), Color(0xFF78909C), Color(0xFFECEFF1)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 24.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  ilfordDelta100(
    label: '伊尔福 Delta 100',
    code: 'Delta 100',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    description: '现代结晶乳剂 · 纤毫毕现的微观灰阶质感',
    recipeSummary: '黑白 · 对比+1 · 锐度+1',
    previewColors: [Color(0xFF1C1C1C), Color(0xFF666666), Color(0xFFDFDFDF)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 24.0,
      texture: 10.0,
      clarity: 18.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  ilfordDelta3200(
    label: '伊尔福 Delta 3200',
    code: 'Delta 3200',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    description: '极限夜色弱光纪实 · 粗粝银盐与强烈戏剧明暗',
    recipeSummary: '黑白 · 对比+3 · 锐度-2 · +0.7EV',
    previewColors: [Color(0xFF0D0D0D), Color(0xFF555555), Color(0xFFFAFAFA)],
    presetAdjustments: const PhotoEditAdjustments(
      exposure: 21.0,
      contrast: 44.0,
      texture: -10.0,
      clarity: 2.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  ilfordPanF50(
    label: '伊尔福 Pan F 50',
    code: 'Pan F 50',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    description: '超细微颗粒 · 丝绸般平滑深邃的影调画质',
    recipeSummary: '黑白 · 对比+2 · 锐度+2',
    previewColors: [Color(0xFF1F1F1F), Color(0xFF707070), Color(0xFFEEEEEE)],
    presetAdjustments: const PhotoEditAdjustments(
      contrast: 34.0,
      texture: 20.0,
      clarity: 26.0,
      vibrance: -100.0,
      saturation: -100.0,
      grain: 10.0,
    ),
  ),
  original(
    label: '原片直出',
    code: 'Original',
    category1: '经典精选',
    category2: '原片与精选',
    description: '相机原生色彩 · 零修饰直出',
    recipeSummary: '原片 · 零调节',
    previewColors: const [Color(0xFF333333), Color(0xFF888888), Color(0xFFE0E0E0)],
    presetAdjustments: PhotoEditAdjustments.initial,
  ),
  fairSkin(
    label: '冷白皮人像',
    code: 'Fair Skin',
    category1: '经典精选',
    category2: '原片与精选',
    description: '去黄冷白 · 白里透红 · 柔肤清透高级感',
    recipeSummary: '肖像 · 去黄 · 柔光白皙',
    previewColors: const [Color(0xFFFFCDD2), Color(0xFFF8BBD0), Color(0xFFE1BEE7)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -12.0, tint: 6.0, exposure: 15.0, contrast: 8.0, highlights: -25.0, shadows: 28.0, texture: -15.0, clarity: -12.0, vibrance: 12.0, saturation: -5.0, highlightHue: 345.0, highlightSat: 8.0, shadowHue: 215.0, shadowSat: 10.0),
  ),
  warmPortrait(
    label: '暖色温馨',
    code: 'Warm Gold',
    category1: '经典精选',
    category2: '原片与精选',
    description: '黄金时刻 · 暖高光冷阴影 · 治愈午后日光',
    recipeSummary: '暖阳 · 金黄高光 · 治愈人像',
    previewColors: const [Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFB0BEC5)],
    presetAdjustments: const PhotoEditAdjustments(temperature: 20.0, tint: 6.0, exposure: 10.0, contrast: 5.0, highlights: -30.0, shadows: 30.0, vibrance: 22.0, highlightHue: 42.0, highlightSat: 25.0, shadowHue: 215.0, shadowSat: 15.0),
  ),
  japanesePure(
    label: '日系街道',
    code: 'Japanese Pure',
    category1: '经典精选',
    category2: '原片与精选',
    description: '空气感高明度 · 低反差 · 暗部透气微泛青蓝',
    recipeSummary: '日系 · 低反差 · 空气感',
    previewColors: const [Color(0xFF81D4FA), Color(0xFFA5D6A7), Color(0xFFFFF9C4)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -25.0, tint: 4.0, exposure: 25.0, contrast: -28.0, highlights: -40.0, shadows: 45.0, whites: -15.0, blacks: 20.0, texture: -10.0, clarity: 12.0, vibrance: -10.0, vignette: 10.0, grain: 15.0, shadowHue: 220.0, shadowSat: 12.0),
  ),
  shinkaiAnime(
    label: '新海诚风',
    code: 'Shinkai Anime',
    category1: '经典精选',
    category2: '原片与精选',
    description: '梦幻动画感 · 高纯度青蓝晴空与鲜翠草木',
    recipeSummary: '动漫 · 翠绿晴空 · 高纯度',
    previewColors: const [Color(0xFF29B6F6), Color(0xFF66BB6A), Color(0xFFFFEE58)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -35.0, tint: 25.0, exposure: 15.0, contrast: -20.0, highlights: -22.0, shadows: 50.0, clarity: 25.0, dehaze: 15.0, vibrance: 40.0, saturation: 25.0, highlightHue: 200.0, highlightSat: 15.0, shadowHue: 215.0, shadowSat: 20.0),
  ),
  cityNight(
    label: '城市夜景',
    code: 'City Night',
    category1: '经典精选',
    category2: '原片与精选',
    description: '冷夜深蓝 · 高反差深邃黑 · 压制霓虹高光',
    recipeSummary: '深蓝冷夜 · 纯黑深邃 · 压制高光',
    previewColors: const [Color(0xFF0D47A1), Color(0xFF37474F), Color(0xFFFFB300)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -20.0, tint: 5.0, exposure: -5.0, contrast: 20.0, highlights: -25.0, shadows: 15.0, whites: 15.0, blacks: -12.0, clarity: 20.0, dehaze: 15.0, shadowHue: 220.0, shadowSat: 15.0),
  ),
  forestGreen(
    label: '绿色森林',
    code: 'Forest Green',
    category1: '经典精选',
    category2: '原片与精选',
    description: '纯净翠绿 · 去黄透光感 · 去朦胧胶片氛围',
    recipeSummary: '翠绿 · 透光去黄 · 胶片森林',
    previewColors: const [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF81C784)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -10.0, tint: 15.0, exposure: 5.0, contrast: 12.0, highlights: -28.0, shadows: 25.0, whites: 10.0, blacks: -10.0, clarity: 15.0, dehaze: 18.0, vibrance: 25.0, saturation: 10.0, shadowHue: 155.0, shadowSat: 12.0),
  ),
  floralBotanical(
    label: '花木生机',
    code: 'Floral Botanical',
    category1: '经典精选',
    category2: '原片与精选',
    description: '微距质感 · 自然饱和保花蕊 · 花瓣层次分明',
    recipeSummary: '微距 · 鲜活花木 · 细节微反差',
    previewColors: const [Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF66BB6A)],
    presetAdjustments: const PhotoEditAdjustments(temperature: 5.0, tint: 12.0, exposure: 8.0, contrast: 10.0, highlights: -15.0, shadows: 20.0, texture: 20.0, clarity: 15.0, dehaze: 8.0, vibrance: 30.0, saturation: 8.0),
  ),
  clearSky(
    label: '通透蓝天',
    code: 'Clear Sky',
    category1: '经典精选',
    category2: '原片与精选',
    description: '风光专属 · 强化晴空纯净天蓝 · 白云立体层次',
    recipeSummary: '纯净晴空 · 立体云层 · 去雾',
    previewColors: const [Color(0xFF0288D1), Color(0xFF29B6F6), Color(0xFFB3E5FC)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -15.0, tint: 8.0, exposure: 10.0, contrast: 10.0, highlights: -25.0, shadows: 20.0, dehaze: 20.0, vibrance: 25.0, saturation: 10.0, highlightHue: 205.0, highlightSat: 15.0),
  ),
  cinematic(
    label: '电影质感',
    code: 'Cinematic',
    category1: '经典精选',
    category2: '原片与精选',
    description: '大片光影 · 高宽容度叙事 · 青橙对撞暗调',
    recipeSummary: '青橙胶片 · 好莱坞大片光影',
    previewColors: const [Color(0xFF00695C), Color(0xFFE65100), Color(0xFF263238)],
    presetAdjustments: const PhotoEditAdjustments(temperature: -10.0, tint: 8.0, exposure: 5.0, contrast: 22.0, highlights: -20.0, shadows: 15.0, clarity: 18.0, vibrance: 12.0, vignette: 15.0, grain: 18.0, highlightHue: 35.0, highlightSat: 25.0, shadowHue: 215.0, shadowSat: 20.0),
  ),
;

  final String label;
  final String code;
  final String category1;
  final String category2;
  final String description;
  final String recipeSummary;
  final List<Color> previewColors;
  final PhotoEditAdjustments presetAdjustments;

  const PhotoFilterType({
    required this.label,
    required this.code,
    required this.category1,
    required this.category2,
    required this.description,
    required this.recipeSummary,
    required this.previewColors,
    required this.presetAdjustments,
  });

  String get trLabel =>
      EngineL10n.filterById(name, L10n.current.localeName)?.label ??
      L10n.tr(label);

  String get trCategory1 => L10n.tr(category1);

  String get trCategory2 => L10n.tr(category2);

  String get trDescription =>
      EngineL10n.filterById(name, L10n.current.localeName)?.desc ??
      L10n.tr(description);

  /// 所有一级分类定义 (按摄影流派规范排列)
  static const List<String> categories1 = [
    '富士胶片',
    '柯达胶片',
    '理光人文',
    '索尼大师',
    '经典黑白',
    '电影特色',
    '经典精选',
  ];

  /// 根据一级分类获取其包含的二级分类列表
  static List<String> getCategories2(String cat1) {
    final list = <String>[];
    for (final f in values) {
      if (f.category1 == cat1 && !list.contains(f.category2)) {
        list.add(f.category2);
      }
    }
    return list;
  }

  /// 根据一级分类与二级分类获取匹配的预设列表
  static List<PhotoFilterType> getByCategories(String cat1, [String? cat2]) {
    return values.where((f) {
      if (f.category1 != cat1) return false;
      if (cat2 != null && cat2.isNotEmpty && f.category2 != cat2) return false;
      return true;
    }).toList();
  }
}

/// 胶片色彩矩阵与硬件加速图像调色引擎
class PhotoFilterEngine {
  PhotoFilterEngine._();

  /// 标准单位矩阵 (Identity Matrix)
  static const List<double> identityMatrix = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// 专业摄影 4x5 调色微调矩阵库 (精选经典手调矩阵)
  static const Map<PhotoFilterType, List<double>> _filterMatrices = {
    PhotoFilterType.original: identityMatrix,
    PhotoFilterType.fairSkin: <double>[
      1.08, -0.02, -0.02, 0, 12,
      -0.02, 1.05, -0.01, 0, 6,
      -0.01, -0.01, 1.15, 0, 14,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.warmPortrait: <double>[
      1.18,  0.04, -0.08, 0, 16,
      0.02,  1.08, -0.06, 0, 8,
      -0.10, -0.04, 0.95, 0, -4,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.japanesePure: <double>[
      0.95,  0.04,  0.05, 0, 18,
      0.02,  1.03,  0.04, 0, 18,
      0.04,  0.04,  1.16, 0, 26,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.shinkaiAnime: <double>[
      1.14, -0.05, -0.04, 0, 10,
      -0.04, 1.28, -0.06, 0, 14,
      -0.08, 0.05, 1.38,  0, 24,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.cityNight: <double>[
      1.15, -0.08, -0.08, 0, -8,
      -0.06, 1.10,  0.02, 0, -6,
      -0.12,  0.04, 1.35, 0, 12,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.forestGreen: <double>[
      0.98, -0.06, -0.04, 0, 4,
      -0.04, 1.35, -0.06, 0, 18,
      -0.06,  0.06, 1.12, 0, 8,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.floralBotanical: <double>[
      1.12, -0.04, -0.02, 0, 8,
      -0.02, 1.24, -0.04, 0, 12,
      -0.04,  0.02, 1.18, 0, 10,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.classicChrome: <double>[
      1.08, -0.05, -0.03, 0, -2,
      -0.03, 1.02, -0.02, 0, 1,
      -0.05, -0.02, 1.12, 0, 4,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.leicaMonochrome: <double>[
      0.35, 0.65, 0.15, 0, -10,
      0.35, 0.65, 0.15, 0, -10,
      0.35, 0.65, 0.15, 0, -10,
      0,    0,    0,    1, 0,
    ],
    PhotoFilterType.clearSky: <double>[
      1.02, -0.02, -0.08, 0, 2,
      -0.02, 1.05, -0.04, 0, 4,
      -0.10,  0.08, 1.38, 0, 24,
      0,     0,     0,    1, 0,
    ],
    PhotoFilterType.cinematic: <double>[
      1.24, -0.06, -0.12, 0, 6,
      -0.06, 1.08,  0.06, 0, -4,
      -0.14,  0.04, 1.28, 0, 8,
      0,     0,     0,    1, 0,
    ],
  };

  /// 获取指定预设对应的基础调色模型
  static PhotoEditAdjustments getPresetAdjustments(PhotoFilterType type) {
    return type.presetAdjustments;
  }

  /// 获取指定滤镜在特定强度下的 4x5 混合矩阵
  static List<double> getMatrix(PhotoFilterType type, [double intensity = 1.0]) {
    final clamped = intensity.clamp(0.0, 1.0);
    if (clamped <= 0.01 || type == PhotoFilterType.original) return identityMatrix;
    final target = _filterMatrices[type] ?? buildAdjustmentsMatrix(type.presetAdjustments);
    if (clamped >= 0.99) return target;

    final mixed = List<double>.filled(20, 0.0);
    for (int i = 0; i < 20; i++) {
      mixed[i] = identityMatrix[i] + (target[i] - identityMatrix[i]) * clamped;
    }
    return mixed;
  }

  /// 4x5 仿射色彩矩阵数学乘法 (Matrix A * Matrix B)
  static List<double> multiplyMatrices(List<double> a, List<double> b) {
    final result = List<double>.filled(20, 0.0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        result[row * 5 + col] = sum;
      }
      double offsetSum = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        offsetSum += a[row * 5 + k] * b[k * 5 + 4];
      }
      result[row * 5 + 4] = offsetSum;
    }
    return result;
  }

  /// HSV 转换为单位 RGB 分量
  static List<double> _hsvToRgb(double hue, double sat) {
    if (sat <= 0.01) return [0.5, 0.5, 0.5];
    final h = (hue % 360) / 60.0;
    final c = sat;
    final x = c * (1.0 - (h % 2 - 1.0).abs());
    double r = 0, g = 0, b = 0;
    if (h >= 0 && h < 1) {
      r = c; g = x;
    } else if (h >= 1 && h < 2) {
      r = x; g = c;
    } else if (h >= 2 && h < 3) {
      g = c; b = x;
    } else if (h >= 3 && h < 4) {
      g = x; b = c;
    } else if (h >= 4 && h < 5) {
      r = x; b = c;
    } else {
      r = c; b = x;
    }
    final m = 1.0 - c;
    return [r + m * 0.5, g + m * 0.5, b + m * 0.5];
  }

  /// 基于 Adobe Lightroom 核心调色算法计算 4x5 色彩调色矩阵
  static List<double> buildAdjustmentsMatrix(PhotoEditAdjustments adj) {
    if (adj.isDefault) return identityMatrix;

    double expFactor = 1.0;
    if (adj.exposure >= 0) {
      expFactor = 1.0 + (adj.exposure / 100.0) * 1.0;
    } else {
      expFactor = 1.0 + (adj.exposure / 100.0) * 0.75;
    }
    final expOffset = adj.exposure * 0.25;
    final hiGain = 1.0 + (adj.highlights / 100.0) * 0.18;
    final wOffset = (adj.whites / 100.0) * 18.0;
    final shOffset = (adj.shadows / 100.0) * 22.0;
    final blOffset = (adj.blacks / 100.0) * 16.0;

    final cFactor = 1.0 +
        (adj.contrast / 100.0) * 0.65 +
        (adj.clarity / 100.0) * 0.25 +
        (adj.texture / 100.0) * 0.15 +
        (adj.dehaze / 100.0) * 0.20;
    final cOffset = 128.0 * (1.0 - cFactor);
    final dhCut = -(adj.dehaze / 100.0) * 14.0;

    final tempRScale = 1.0 + (adj.temperature / 100.0) * 0.22;
    final tempBScale = 1.0 - (adj.temperature / 100.0) * 0.22;
    final tempROffset = (adj.temperature / 100.0) * 16.0;
    final tempBOffset = -(adj.temperature / 100.0) * 16.0;

    final tintGScale = 1.0 - (adj.tint / 100.0) * 0.18;
    final tintRBScale = 1.0 + (adj.tint / 100.0) * 0.10;
    final tintGOffset = -(adj.tint / 100.0) * 12.0;
    final tintRBOffset = (adj.tint / 100.0) * 6.0;

    double splitROffset = 0.0;
    double splitGOffset = 0.0;
    double splitBOffset = 0.0;
    if (adj.highlightSat > 0.01) {
      final hlRgb = _hsvToRgb(adj.highlightHue, adj.highlightSat / 100.0);
      splitROffset += (hlRgb[0] - 0.5) * 28.0;
      splitGOffset += (hlRgb[1] - 0.5) * 28.0;
      splitBOffset += (hlRgb[2] - 0.5) * 28.0;
    }
    if (adj.shadowSat > 0.01) {
      final shRgb = _hsvToRgb(adj.shadowHue, adj.shadowSat / 100.0);
      splitROffset += (shRgb[0] - 0.5) * 22.0;
      splitGOffset += (shRgb[1] - 0.5) * 22.0;
      splitBOffset += (shRgb[2] - 0.5) * 22.0;
    }

    final sVal = 1.0 + (adj.saturation / 100.0) * 1.25 + (adj.vibrance / 100.0) * 0.65;
    const double lr = 0.299;
    const double lg = 0.587;
    const double lb = 0.114;
    final double invS = 1.0 - sVal;
    final double sr = invS * lr;
    final double sg = invS * lg;
    final double sb = invS * lb;

    final rGain = expFactor * hiGain * tempRScale * tintRBScale;
    final gGain = expFactor * hiGain * tintGScale;
    final bGain = expFactor * hiGain * tempBScale * tintRBScale;

    final rOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tempROffset + tintRBOffset + splitROffset;
    final gOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tintGOffset + splitGOffset;
    final bOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tempBOffset + tintRBOffset + splitBOffset;

    return <double>[
      (sr + sVal) * cFactor * rGain, sg * cFactor * rGain,          sb * cFactor * rGain,          0, rOff,
      sr * cFactor * gGain,          (sg + sVal) * cFactor * gGain, sb * cFactor * gGain,          0, gOff,
      sr * cFactor * bGain,          sg * cFactor * bGain,          (sb + sVal) * cFactor * bGain, 0, bOff,
      0,                             0,                             0,                             1, 0,
    ];
  }

  /// 计算指定预设滤镜与其特定调节项叠加后的终极 4x5 色彩调色矩阵
  static List<double> getCompositeMatrix({
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
  }) {
    final baseFilterMatrix = getMatrix(filterType, filterIntensity);
    if (adjustments.isDefault) {
      return baseFilterMatrix;
    }
    final adjMatrix = buildAdjustmentsMatrix(adjustments);
    if (filterType == PhotoFilterType.original || filterIntensity <= 0.01) {
      return adjMatrix;
    }
    return multiplyMatrices(baseFilterMatrix, adjMatrix);
  }

  static List<double> createCompositeMatrix({
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
  }) => getCompositeMatrix(filterType: filterType, filterIntensity: filterIntensity, adjustments: adjustments);

  static List<int> applyMatrixToRgb(int r, int g, int b, List<double> matrix) {
    final newR = (matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[4]).clamp(0.0, 255.0).toInt();
    final newG = (matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[9]).clamp(0.0, 255.0).toInt();
    final newB = (matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[14]).clamp(0.0, 255.0).toInt();
    return [newR, newG, newB];
  }

  static ColorFilter createColorFilter(PhotoFilterType type, [double intensity = 1.0]) {
    return ColorFilter.matrix(getMatrix(type, intensity));
  }

  static ColorFilter createCompositeFilter({
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
  }) {
    if (filterType == PhotoFilterType.original && adjustments.isDefault && filterIntensity <= 0.01) {
      return const ColorFilter.matrix(identityMatrix);
    }
    final matrix = getCompositeMatrix(
      filterType: filterType,
      filterIntensity: filterIntensity,
      adjustments: adjustments,
    );
    return ColorFilter.matrix(matrix);
  }

  static Paint createFilterPaint(PhotoFilterType type, [double intensity = 1.0]) {
    return Paint()
      ..colorFilter = createColorFilter(type, intensity)
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
  }

  static Paint createCompositeFilterPaint({
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
  }) {
    return Paint()
      ..colorFilter = createCompositeFilter(
        filterType: filterType,
        filterIntensity: filterIntensity,
        adjustments: adjustments,
      )
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high;
  }

  static void drawVignette(Canvas canvas, Rect bounds, double vignette) {
    if (vignette.abs() < 1.0) return;
    final isDark = vignette > 0;
    final alpha = (vignette.abs() / 100.0 * 220).clamp(0, 255).toInt();
    final edgeColor = isDark ? Color.fromARGB(alpha, 0, 0, 0) : Color.fromARGB(alpha, 255, 255, 255);
    final center = bounds.center;
    final radius = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) / 2.0;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [const Color(0x00000000), edgeColor],
        [0.45, 1.0],
      )
      ..blendMode = isDark ? BlendMode.multiply : BlendMode.screen;
    canvas.drawRect(bounds, paint);
  }

  static void drawGrain(Canvas canvas, Rect bounds, double grain) {
    if (grain < 1.0) return;
    final random = math.Random(42);
    final count = ((bounds.width * bounds.height) / 600.0 * (grain / 100.0)).toInt().clamp(50, 2500);
    final alpha = (grain / 100.0 * 38).clamp(5, 50).toInt();
    final darkPaint = Paint()
      ..color = Colors.black.withAlpha(alpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final lightPaint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < count; i++) {
      final x = bounds.left + random.nextDouble() * bounds.width;
      final y = bounds.top + random.nextDouble() * bounds.height;
      final paint = random.nextBool() ? darkPaint : lightPaint;
      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);
    }
  }
}

