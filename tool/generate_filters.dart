import 'dart:io';

class RecipeDef {
  final String enumName;
  final String label;
  final String code;
  final String category1;
  final String category2;
  final String creativeStyle;
  final int saturation;
  final int contrast;
  final int sharpness;
  final String wb;
  final String ab;
  final String gm;
  final double ev;
  final String dro;
  final String effect;
  final List<int> previewColors;
  final String desc;

  const RecipeDef({
    required this.enumName,
    required this.label,
    required this.code,
    required this.category1,
    required this.category2,
    required this.creativeStyle,
    required this.saturation,
    required this.contrast,
    required this.sharpness,
    this.wb = '自动',
    this.ab = '0',
    this.gm = '0',
    this.ev = 0.0,
    this.dro = '自动',
    this.effect = '关',
    required this.previewColors,
    required this.desc,
  });

  String get summary {
    final parts = <String>[];
    parts.add(creativeStyle);
    if (saturation != 0) parts.add('饱和${saturation > 0 ? "+$saturation" : "$saturation"}');
    if (contrast != 0) parts.add('对比${contrast > 0 ? "+$contrast" : "$contrast"}');
    if (sharpness != 0) parts.add('锐度${sharpness > 0 ? "+$sharpness" : "$sharpness"}');
    if (wb != '自动') parts.add(wb);
    if (ab != '0' || gm != '0') {
      final abStr = ab != '0' ? ab : '';
      final gmStr = gm != '0' ? gm : '';
      parts.add('$abStr $gmStr'.trim());
    }
    if (ev != 0.0) parts.add('${ev > 0 ? "+$ev" : "$ev"}EV');
    if (dro != '自动') parts.add('DRO $dro');
    if (effect != '关') parts.add(effect);
    return parts.join(' · ');
  }

  Map<String, double> computeAdjustments() {
    double temp = 0.0;
    double tint = 0.0;
    double exposure = ev * 30.0;
    double con = contrast * 10.0;
    double sat = saturation * 12.0;
    double vib = saturation * 8.0;
    double hl = 0.0;
    double sh = 0.0;
    double wh = 0.0;
    double bl = 0.0;
    double tex = 0.0;
    double cla = 0.0;
    double deh = 0.0;
    double hlHue = 40.0;
    double hlSat = 0.0;
    double shHue = 220.0;
    double shSat = 0.0;
    double vig = 0.0;
    double grn = 0.0;

    switch (creativeStyle) {
      case '肖像':
        temp += 2.0;
        hl -= 8.0;
        sh += 14.0;
        tex -= 10.0;
        cla -= 6.0;
        vib += 6.0;
        sat -= 4.0;
        hlHue = 350.0;
        hlSat = 6.0;
        break;
      case '中性':
        con -= 8.0;
        hl -= 10.0;
        sh += 14.0;
        vib -= 6.0;
        break;
      case '鲜艳':
        con += 8.0;
        sat += 12.0;
        vib += 16.0;
        deh += 6.0;
        break;
      case '清淡':
        exposure += 10.0;
        con -= 14.0;
        hl -= 10.0;
        sh += 18.0;
        wh += 8.0;
        tex -= 8.0;
        vib -= 6.0;
        break;
      case '黑白':
        sat = -100.0;
        vib = -100.0;
        con += 14.0;
        cla += 10.0;
        grn += 10.0;
        break;
      case '棕褐色':
        sat = -80.0;
        vib = -80.0;
        temp += 22.0;
        tint += 6.0;
        hlHue = 44.0;
        hlSat = 28.0;
        shHue = 36.0;
        shSat = 30.0;
        con += 6.0;
        break;
      case '清澈':
        con += 10.0;
        cla += 16.0;
        deh += 12.0;
        vib += 10.0;
        hl -= 10.0;
        sh += 8.0;
        break;
      case '深邃':
        con += 16.0;
        sh -= 12.0;
        bl -= 14.0;
        sat += 12.0;
        vib += 12.0;
        break;
      case '标准':
      default:
        break;
    }

    if (sharpness < 0) {
      tex -= 10.0;
      cla -= 8.0;
    } else if (sharpness > 0) {
      tex += sharpness * 10.0;
      cla += sharpness * 8.0;
    }

    switch (wb) {
      case '6000K': temp += 16.0; break;
      case '5600K': temp += 4.0; break;
      case '5500K': temp += 2.0; break;
      case '5000K': temp -= 12.0; break;
      case '4000K': temp -= 28.0; break;
      case '3200K': temp -= 45.0; break;
      case '2500K': temp -= 62.0; break;
    }

    switch (ab) {
      case 'A1': temp += 6.0; break;
      case 'A2': temp += 14.0; break;
      case 'A3': temp += 22.0; break;
      case 'B1': temp -= 7.0; break;
      case 'B2': temp -= 16.0; break;
    }

    switch (gm) {
      case 'G1': tint -= 6.0; break;
      case 'G2': tint -= 12.0; break;
      case 'G3': tint -= 18.0; break;
      case 'G4': tint -= 24.0; break;
      case 'M1': tint += 7.0; break;
      case 'M2': tint += 15.0; break;
    }

    switch (dro) {
      case '等级 3':
        sh += 22.0;
        hl -= 14.0;
        break;
      case '等级 5':
        sh += 40.0;
        hl -= 22.0;
        bl += 8.0;
        break;
      case '关闭':
        sh -= 10.0;
        bl -= 10.0;
        break;
    }

    switch (effect) {
      case '柔和高调 (蓝色)':
        exposure += 12.0;
        hl -= 14.0;
        sh += 22.0;
        tex -= 12.0;
        hlHue = 215.0;
        hlSat = 16.0;
        shHue = 210.0;
        shSat = 12.0;
        break;
      case '高对比度黑白':
        sat = -100.0;
        vib = -100.0;
        con += 36.0;
        cla += 24.0;
        bl -= 16.0;
        grn += 20.0;
        break;
      case '复古照片':
        temp += 22.0;
        tint += 8.0;
        hlHue = 45.0;
        hlSat = 20.0;
        shHue = 48.0;
        shSat = 18.0;
        vig += 18.0;
        grn += 18.0;
        break;
    }

    double clampV(double v, double min, double max) => v < min ? min : (v > max ? max : v);

    return {
      'temperature': clampV(temp, -100.0, 100.0),
      'tint': clampV(tint, -100.0, 100.0),
      'exposure': clampV(exposure, -100.0, 100.0),
      'contrast': clampV(con, -100.0, 100.0),
      'highlights': clampV(hl, -100.0, 100.0),
      'shadows': clampV(sh, -100.0, 100.0),
      'whites': clampV(wh, -100.0, 100.0),
      'blacks': clampV(bl, -100.0, 100.0),
      'texture': clampV(tex, -100.0, 100.0),
      'clarity': clampV(cla, -100.0, 100.0),
      'dehaze': clampV(deh, -100.0, 100.0),
      'vibrance': clampV(vib, -100.0, 100.0),
      'saturation': clampV(sat, -100.0, 100.0),
      'highlightHue': hlHue,
      'highlightSat': clampV(hlSat, 0.0, 100.0),
      'shadowHue': shHue,
      'shadowSat': clampV(shSat, 0.0, 100.0),
      'vignette': clampV(vig, -100.0, 100.0),
      'grain': clampV(grn, 0.0, 100.0),
    };
  }
}

final List<RecipeDef> recipes = [
  // 1. 索尼风格 (Sony) · 8 款
  const RecipeDef(
    enumName: 'sonyFactoryST',
    label: '出厂标准',
    code: 'FACTORY ST',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '标准',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '索尼出厂标准色彩 · 真实中性还原',
    previewColors: [0xFF333333, 0xFF888888, 0xFFCCCCCC],
  ),
  const RecipeDef(
    enumName: 'sonyPT',
    label: '索尼 PT（人像）',
    code: 'Sony PT',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '肖像',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '柔和肤色优化 · 肖像透亮层次',
    previewColors: [0xFFFAD0C4, 0xFFFFD1FF, 0xFFE0C3FC],
  ),
  const RecipeDef(
    enumName: 'sonyNT',
    label: '索尼 NT（中性）',
    code: 'Sony NT',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '中性',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '低反差平滑曲线 · 宽容度保留',
    previewColors: [0xFF757F9A, 0xFFD7DDE8, 0xFF9E9E9E],
  ),
  const RecipeDef(
    enumName: 'sonyVV',
    label: '索尼 VV（鲜艳）',
    code: 'Sony VV',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '鲜艳',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '高纯度原色强化 · 风光与艳丽场景',
    previewColors: [0xFFFF512F, 0xFFDD2476, 0xFFFF8A00],
  ),
  const RecipeDef(
    enumName: 'sonyVV2',
    label: '索尼 VV2',
    code: 'Sony VV2',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '鲜艳',
    saturation: 2,
    contrast: 1,
    sharpness: 0,
    desc: '进阶浓郁鲜活 · 阳光明媚视觉张力',
    previewColors: [0xFFFF416C, 0xFFFF4B2B, 0xFFF7971E],
  ),
  const RecipeDef(
    enumName: 'sonyFL',
    label: '索尼 FL（胶片风格）',
    code: 'Sony FL',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -1,
    sharpness: 0,
    ab: 'A1',
    desc: '网红复古胶片感 · 暖琥珀调色与青蓝暗调',
    previewColors: [0xFF2C3E50, 0xFF4CA1AF, 0xFFE8D3A2],
  ),
  const RecipeDef(
    enumName: 'sonyIN',
    label: '索尼 IN（即时）',
    code: 'Sony IN',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -3,
    sharpness: 0,
    gm: 'M1',
    desc: '哑光柔雾质感 · 洋红微调 · 日系情绪片',
    previewColors: [0xFFE0C3FC, 0xFF8EC5FC, 0xFFD4B2D8],
  ),
  const RecipeDef(
    enumName: 'sonySH',
    label: '索尼 SH（柔和高调）',
    code: 'Sony SH',
    category1: '索尼大师',
    category2: '索尼创意外观',
    creativeStyle: '清淡',
    saturation: -2,
    contrast: -2,
    sharpness: 0,
    ab: 'A1',
    ev: 1.0,
    effect: '柔和高调 (蓝色)',
    desc: '通透高光泛蓝 · 梦幻空灵高调人像',
    previewColors: [0xFFE0F7FA, 0xFFB2EBF2, 0xFF80DEEA],
  ),

  // 2. 富士胶片模拟 (Fuji Sim) · 16 款
  const RecipeDef(
    enumName: 'fujiProvia',
    label: 'PROVIA 标准',
    code: 'Provia',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 0,
    sharpness: 0,
    desc: '全能基准 · 真实平衡的富士标志性直出',
    previewColors: [0xFF1E88E5, 0xFF43A047, 0xFFE53935],
  ),
  const RecipeDef(
    enumName: 'fujiVelvia',
    label: 'Velvia 鲜艳',
    code: 'Velvia',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '鲜艳',
    saturation: 3,
    contrast: 2,
    sharpness: 0,
    desc: '风光王者 · 极高饱和度与反差 · 碧海蓝天翠绿',
    previewColors: [0xFFD81B60, 0xFF00ACC1, 0xFF7CB342],
  ),
  const RecipeDef(
    enumName: 'fujiAstia',
    label: 'ASTIA 柔和',
    code: 'Astia',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '肖像',
    saturation: 0,
    contrast: -1,
    sharpness: 0,
    ab: 'A1',
    ev: 0.3,
    desc: '人像特调 · 柔和高光过渡与通透暖色肤感',
    previewColors: [0xFFFFAB91, 0xFFFFCC80, 0xFFF48FB1],
  ),
  const RecipeDef(
    enumName: 'classicChrome',
    label: '经典正片',
    code: 'Classic Chrome',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '标准',
    saturation: -1,
    contrast: 2,
    sharpness: 0,
    ab: 'A3',
    gm: 'G1',
    ev: -0.3,
    desc: '人文纪实传奇 · 低彩度硬反差 · 沉稳冷峻青蓝',
    previewColors: [0xFF455A64, 0xFF78909C, 0xFFD7CCC8],
  ),
  const RecipeDef(
    enumName: 'fujiClassicNegative',
    label: '经典负片',
    code: 'Classic Neg',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '标准',
    saturation: -3,
    contrast: 3,
    sharpness: 1,
    ab: 'B1',
    gm: 'G1',
    desc: 'Superia 负片风骨 · 独特青绿暗部与高反差怀旧',
    previewColors: [0xFF2E7D32, 0xFF8D6E63, 0xFFC2185B],
  ),
  const RecipeDef(
    enumName: 'fujiNostalgicNeg',
    label: '怀旧负片',
    code: 'Nostalgic Neg',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 0,
    sharpness: 0,
    ab: 'A3',
    desc: '琥珀金色高光 · 70年代美国新彩色摄影色调',
    previewColors: [0xFFFFB74D, 0xFFFFA726, 0xFF8D6E63],
  ),
  const RecipeDef(
    enumName: 'fujiRealaAce',
    label: 'REALA ACE',
    code: 'Reala Ace',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '标准',
    saturation: 0,
    contrast: 1,
    sharpness: 0,
    desc: '第四感色层技术 · 真实细腻 · 硬朗适中现代感',
    previewColors: [0xFF29B6F6, 0xFF66BB6A, 0xFFFFA726],
  ),
  const RecipeDef(
    enumName: 'fujiProNegStd',
    label: 'PRO Neg. 标准',
    code: 'Pro Neg Std',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '肖像',
    saturation: -2,
    contrast: -1,
    sharpness: 0,
    desc: '影棚专业人像 · 极度平滑渐变 · 肤色柔和自然',
    previewColors: [0xFFFFCCBC, 0xFFD7CCC8, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'fujiProNegHi',
    label: 'PRO Neg. 高',
    code: 'Pro Neg Hi',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '肖像',
    saturation: -2,
    contrast: 1,
    sharpness: 0,
    desc: '户外人像首选 · 保持肤色同时增强背景立体轮廓',
    previewColors: [0xFFFFAB91, 0xFFB0BEC5, 0xFF8D6E63],
  ),
  const RecipeDef(
    enumName: 'fujiEterna',
    label: 'ETERNA 影院',
    code: 'Eterna',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -2,
    sharpness: -1,
    ev: -0.3,
    dro: '等级 3',
    desc: '电影工业级胶卷 · 柔和低保真 · 宽广暗部动态',
    previewColors: [0xFF546E7A, 0xFF78909C, 0xFF90A4AE],
  ),
  const RecipeDef(
    enumName: 'fujiEternaBleach',
    label: 'ETERNA 漂白效果',
    code: 'Eterna Bleach',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '中性',
    saturation: -3,
    contrast: 3,
    sharpness: 0,
    ev: -0.3,
    dro: '关闭',
    desc: '跳银冲洗洗印工艺 · 极低饱和度与强烈金属反差',
    previewColors: [0xFF37474F, 0xFF607D8B, 0xFFB0BEC5],
  ),
  const RecipeDef(
    enumName: 'fujiAcros',
    label: 'ACROS 黑白',
    code: 'Acros',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 1,
    desc: '富士顶级银盐黑白 · 极其细腻的灰阶过渡与微反差',
    previewColors: [0xFF212121, 0xFF757575, 0xFFE0E0E0],
  ),
  const RecipeDef(
    enumName: 'fujiAcrosYe',
    label: 'ACROS +Ye（黄滤镜）',
    code: 'Acros +Ye',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 1,
    wb: '4000K',
    desc: '加黄滤镜压暗天空 · 强化云层质感与人像轮廓',
    previewColors: [0xFF263238, 0xFF607D8B, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'fujiAcrosR',
    label: 'ACROS +R（红滤镜）',
    code: 'Acros +R',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    wb: '2500K',
    effect: '高对比度黑白',
    desc: '红镜强对比戏剧张力 · 强烈黑白视觉冲击',
    previewColors: [0xFF1A1A1A, 0xFF616161, 0xFFF5F5F5],
  ),
  const RecipeDef(
    enumName: 'fujiAcrosG',
    label: 'ACROS +G（绿滤镜）',
    code: 'Acros +G',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 1,
    wb: '5600K',
    gm: 'G4',
    desc: '绿镜保肤色唇色 · 柔和肖像与植物细腻层次',
    previewColors: [0xFF2E3D30, 0xFF6A8572, 0xFFD8E2DC],
  ),
  const RecipeDef(
    enumName: 'fujiSepia',
    label: '富士 棕褐色',
    code: 'Sepia',
    category1: '富士胶片',
    category2: '胶片模拟',
    creativeStyle: '棕褐色',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '世纪初银盐暖棕调 · 岁月痕迹与怀旧典雅氛围',
    previewColors: [0xFF5D4037, 0xFF8D6E63, 0xFFD7CCC8],
  ),

  // 3. 富士经典胶卷 (Fuji Film) · 5 款
  const RecipeDef(
    enumName: 'fujiPro400H',
    label: '富士 Pro 400H',
    code: 'Pro 400H',
    category1: '富士胶片',
    category2: '经典胶卷',
    creativeStyle: '清淡',
    saturation: -2,
    contrast: -2,
    sharpness: 0,
    ab: 'B1',
    gm: 'G1',
    ev: 0.7,
    desc: '清新通透日系胶卷 · 蓝绿空气感与高光柔粉',
    previewColors: [0xFF80DEEA, 0xFFA5D6A7, 0xFFFFF59D],
  ),
  const RecipeDef(
    enumName: 'fujiFortia50',
    label: '富士 Fortia 50',
    code: 'Fortia 50',
    category1: '富士胶片',
    category2: '经典胶卷',
    creativeStyle: '鲜艳',
    saturation: 3,
    contrast: 2,
    sharpness: 0,
    ab: 'B1',
    ev: -0.3,
    desc: '限定版高饱和反转片 · 极度鲜艳强烈的四季色彩',
    previewColors: [0xFF00B0FF, 0xFF00E676, 0xFFFF3D00],
  ),
  const RecipeDef(
    enumName: 'fujiSuperia400',
    label: '富士 Superia 400',
    code: 'Superia 400',
    category1: '富士胶片',
    category2: '经典胶卷',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 1,
    sharpness: 0,
    ab: 'A1',
    gm: 'G1',
    ev: 0.3,
    desc: '生活纪实常备负片 · 标志性青绿暗部与红橙暖意',
    previewColors: [0xFF26A69A, 0xFFFF7043, 0xFFFFA726],
  ),
  const RecipeDef(
    enumName: 'fujiC200',
    label: '富士 C200',
    code: 'Fuji C200',
    category1: '富士胶片',
    category2: '经典胶卷',
    creativeStyle: '标准',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    ab: 'B1',
    gm: 'G1',
    desc: '日常随身胶片 · 平实自然带微青的日光还原',
    previewColors: [0xFF4DB6AC, 0xFFFFB74D, 0xFFE0E0E0],
  ),
  const RecipeDef(
    enumName: 'fujiNatura1600',
    label: '富士 Natura 1600',
    code: 'Natura 1600',
    category1: '富士胶片',
    category2: '经典胶卷',
    creativeStyle: '肖像',
    saturation: -2,
    contrast: -2,
    sharpness: 0,
    ab: 'A1',
    ev: 0.3,
    desc: '夜景与室内弱光神卷 · 温暖通透的微光纪实氛围',
    previewColors: [0xFFFFCC80, 0xFFB0BEC5, 0xFFD7CCC8],
  ),

  // 4. 柯达胶片 (Kodak) · 14 款
  const RecipeDef(
    enumName: 'kodakPortra160',
    label: '柯达 Portra 160',
    code: 'Portra 160',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '肖像',
    saturation: -3,
    contrast: -2,
    sharpness: 0,
    ab: 'A1',
    gm: 'M1',
    ev: 0.7,
    desc: '极其细腻平滑的低反差肤色表现 · 时尚大片首选',
    previewColors: [0xFFFFCCBC, 0xFFFFE0B2, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'kodakPortra400',
    label: '柯达 Portra 400',
    code: 'Portra 400',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '肖像',
    saturation: -1,
    contrast: -1,
    sharpness: 0,
    ab: 'A3',
    gm: 'G1',
    ev: 0.7,
    desc: '全球最畅销胶卷 · 温暖金黄日光感 · 绝美自然肤质',
    previewColors: [0xFFFFB74D, 0xFFFF8A65, 0xFF90A4AE],
  ),
  const RecipeDef(
    enumName: 'kodakPortra800',
    label: '柯达 Portra 800',
    code: 'Portra 800',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '肖像',
    saturation: -2,
    contrast: -2,
    sharpness: 0,
    ab: 'A1',
    gm: 'G1',
    ev: 0.3,
    desc: '高感光暖调色彩 · 柔和阴影细节与丰富质感',
    previewColors: [0xFFFFA726, 0xFF81C784, 0xFFB0BEC5],
  ),
  const RecipeDef(
    enumName: 'kodakGold200',
    label: '柯达 Gold 200',
    code: 'Gold 200',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '标准',
    saturation: 2,
    contrast: 1,
    sharpness: 0,
    ab: 'A3',
    gm: 'G1',
    ev: 0.3,
    desc: '夏日午后阳光金黄 · 浓郁暖调复古生活画卷',
    previewColors: [0xFFFFB300, 0xFFF57C00, 0xFF43A047],
  ),
  const RecipeDef(
    enumName: 'kodakUltraMax400',
    label: '柯达 Ultra Max 400',
    code: 'UltraMax 400',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '标准',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    gm: 'G1',
    ev: 0.3,
    desc: '鲜活纯正的三原色对比 · 蔚蓝晴空与明快生活纪实',
    previewColors: [0xFF1976D2, 0xFFFFA000, 0xFF388E3C],
  ),
  const RecipeDef(
    enumName: 'kodakColorPlus200',
    label: '柯达 Color Plus 200',
    code: 'ColorPlus 200',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 1,
    sharpness: 0,
    ab: 'A2',
    gm: 'G1',
    ev: 0.3,
    desc: '平价经典暖胶卷 · 泛黄复古胶片感与老照片记忆',
    previewColors: [0xFFFF8F00, 0xFFF4511E, 0xFF43A047],
  ),
  const RecipeDef(
    enumName: 'kodakEktar100',
    label: '柯达 Ektar 100',
    code: 'Ektar 100',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '标准',
    saturation: 3,
    contrast: 1,
    sharpness: 1,
    ev: -0.3,
    desc: '世界上最细腻胶卷 · 极致高饱和与锐利风光色彩',
    previewColors: [0xFFD32F2F, 0xFF1976D2, 0xFF388E3C],
  ),
  const RecipeDef(
    enumName: 'kodakE100',
    label: '柯达 Ektachrome E100',
    code: 'E100',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '清澈',
    saturation: 3,
    contrast: 1,
    sharpness: 0,
    ab: 'B1',
    ev: -0.3,
    desc: '传奇彩色反转片复产 · 清澈透蓝与纯净高光反差',
    previewColors: [0xFF0288D1, 0xFF0097A7, 0xFFE64A19],
  ),
  const RecipeDef(
    enumName: 'kodachrome64',
    label: 'Kodachrome 64',
    code: 'Kodachrome 64',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '深邃',
    saturation: 3,
    contrast: 2,
    sharpness: 1,
    ab: 'B1',
    ev: -0.3,
    desc: '国家地理封面传奇 · 深邃厚重的红黄质感与不朽经典',
    previewColors: [0xFFB71C1C, 0xFF0D47A1, 0xFFF57F17],
  ),
  const RecipeDef(
    enumName: 'kodakVision3500T',
    label: '柯达 Vision3 500T（日光）',
    code: 'Vision3 500T',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '中性',
    saturation: -1,
    contrast: 0,
    sharpness: 0,
    wb: '3200K',
    ev: 0.3,
    dro: '等级 3',
    desc: '好莱坞钨丝灯电影卷 · 蓝调日光对撞与光晕暗部',
    previewColors: [0xFF0277BD, 0xFF455A64, 0xFFFF7043],
  ),
  const RecipeDef(
    enumName: 'kodakVision200T',
    label: '柯达 Vision 200T（小行星城）',
    code: 'Vision 200T',
    category1: '柯达胶片',
    category2: '彩色负片',
    creativeStyle: '中性',
    saturation: -2,
    contrast: -3,
    sharpness: 0,
    wb: '5000K',
    ab: 'A2',
    gm: 'G3',
    ev: 0.3,
    dro: '等级 3',
    desc: '韦斯安德森风复古色调 · 柔和低反差黄绿粉黛童话感',
    previewColors: [0xFFFBC02D, 0xFF80CBC4, 0xFFBCAAA4],
  ),
  const RecipeDef(
    enumName: 'kodakTriX400',
    label: '柯达 Tri-X 400',
    code: 'Tri-X 400',
    category1: '柯达胶片',
    category2: '柯达黑白',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 2,
    sharpness: 2,
    ev: 0.3,
    desc: '新闻摄影不朽标杆 · 硬朗反差与经典银盐颗粒',
    previewColors: [0xFF212121, 0xFF616161, 0xFFE0E0E0],
  ),
  const RecipeDef(
    enumName: 'kodakTMax',
    label: '柯达 T-Max',
    code: 'T-Max',
    category1: '柯达胶片',
    category2: '柯达黑白',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 2,
    sharpness: 3,
    desc: 'T 颗粒现代乳剂 · 极高清晰度与纯净深邃黑阶',
    previewColors: [0xFF1A1A1A, 0xFF757575, 0xFFEEEEEE],
  ),
  const RecipeDef(
    enumName: 'kodakTriX1600',
    label: '柯达 Tri-X 1600（增感）',
    code: 'Tri-X 1600',
    category1: '柯达胶片',
    category2: '柯达黑白',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    ev: 0.3,
    effect: '高对比度黑白',
    desc: '增感暗房暴力冲洗 · 粗粝颗粒与高反差街头纪实',
    previewColors: [0xFF000000, 0xFF424242, 0xFFFFFFFF],
  ),

  // 5. 电影风格 (Cine) · 4 款
  const RecipeDef(
    enumName: 'cineStill50D',
    label: 'CineStill 50D（蓝丝绒）',
    code: 'CineStill 50D',
    category1: '电影特色',
    category2: '电影风格',
    creativeStyle: '标准',
    saturation: -2,
    contrast: -1,
    sharpness: 0,
    wb: '5500K',
    ab: 'B1',
    gm: 'M1',
    desc: '日光电影胶卷去碳层 · 细腻纯净与冷蓝丝绒高光',
    previewColors: [0xFF1565C0, 0xFF8E24AA, 0xFFE0E0E0],
  ),
  const RecipeDef(
    enumName: 'cineStill800T',
    label: 'CineStill 800T',
    code: 'CineStill 800T',
    category1: '电影特色',
    category2: '电影风格',
    creativeStyle: '中性',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    wb: '3200K',
    gm: 'M1',
    ev: 0.3,
    desc: '夜景霓虹神卷 · 冷艳青蓝基调与高光红色光晕光斑',
    previewColors: [0xFF0D47A1, 0xFFD81B60, 0xFF00ACC1],
  ),
  const RecipeDef(
    enumName: 'classicCinema',
    label: '经典电影',
    code: 'Classic Cinema',
    category1: '电影特色',
    category2: '电影风格',
    creativeStyle: '标准',
    saturation: 0,
    contrast: -1,
    sharpness: 0,
    wb: '6000K',
    ab: 'A2',
    dro: '等级 3',
    desc: '大银幕叙事色调 · 暖黄暖调高光与高宽容度暗部',
    previewColors: [0xFFE65100, 0xFF006064, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'rec709Video',
    label: 'Rec.709 视频（低对比）',
    code: 'Rec.709',
    category1: '电影特色',
    category2: '电影风格',
    creativeStyle: '中性',
    saturation: -2,
    contrast: -2,
    sharpness: 0,
    dro: '等级 5',
    desc: '广电级低反差Log还原 · 超柔和中间调灰阶',
    previewColors: [0xFF607D8B, 0xFF78909C, 0xFF90A4AE],
  ),

  // 6. 理光 GR 影像控制 (Ricoh GR) · 8 款
  const RecipeDef(
    enumName: 'ricohGRPositive',
    label: 'GR 正片',
    code: 'GR Positive',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '标准',
    saturation: 3,
    contrast: 2,
    sharpness: 0,
    ab: 'A2',
    ev: -0.3,
    desc: '街头抓拍之王 · 极具冲击力的高反差高饱和正片色',
    previewColors: [0xFF0288D1, 0xFFF57C00, 0xFF388E3C],
  ),
  const RecipeDef(
    enumName: 'ricohGRNegative',
    label: 'GR 负片',
    code: 'GR Negative',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '中性',
    saturation: -2,
    contrast: 1,
    sharpness: 0,
    ab: 'B1',
    gm: 'G1',
    ev: 0.3,
    desc: 'GR3 固件新宠 · 偏青冷绿的人文纪实空气感',
    previewColors: [0xFF455A64, 0xFF8D6E63, 0xFF00897B],
  ),
  const RecipeDef(
    enumName: 'ricohGRBleach',
    label: 'GR 漂白效果',
    code: 'GR Bleach',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '中性',
    saturation: -3,
    contrast: 3,
    sharpness: 1,
    dro: '关闭',
    desc: '硬朗冷峻 · 工业金属感与高反差褪色质感',
    previewColors: [0xFF37474F, 0xFF78909C, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'ricohGRRetro',
    label: 'GR 复古',
    code: 'GR Retro',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '标准',
    saturation: -3,
    contrast: -1,
    sharpness: 0,
    ab: 'A3',
    gm: 'M1',
    effect: '复古照片',
    desc: '泛黄怀旧老镜头感 · 暗角胶片颗粒与咖啡馆暖调',
    previewColors: [0xFF6D4C41, 0xFFFFA000, 0xFFD7CCC8],
  ),
  const RecipeDef(
    enumName: 'ricohGRCross',
    label: 'GR 正负逆冲',
    code: 'GR Cross Proc',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '鲜艳',
    saturation: 2,
    contrast: 2,
    sharpness: 0,
    ab: 'B2',
    gm: 'G4',
    desc: '暗房正片负冲 · 迷幻品青对撞与超现实色偏',
    previewColors: [0xFF00BFA5, 0xFFAA00FF, 0xFFFFD600],
  ),
  const RecipeDef(
    enumName: 'ricohGRHiBw',
    label: 'GR 高对比度黑白',
    code: 'GR Hi-B&W',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 3,
    sharpness: 1,
    effect: '高对比度黑白',
    desc: '森山大道式粗粝硬派 · 纯黑纯白极致张力',
    previewColors: [0xFF000000, 0xFF616161, 0xFFFFFFFF],
  ),
  const RecipeDef(
    enumName: 'ricohGRHardBw',
    label: 'GR 硬调黑白',
    code: 'GR Hard Mono',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 2,
    sharpness: 2,
    desc: '硬调清晰反差 · 建筑与光影线条雕刻感',
    previewColors: [0xFF212121, 0xFF757575, 0xFFEEEEEE],
  ),
  const RecipeDef(
    enumName: 'ricohGRSoftBw',
    label: 'GR 柔调黑白',
    code: 'GR Soft Mono',
    category1: '理光人文',
    category2: 'GR 影像控制',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: -2,
    sharpness: -1,
    desc: '柔和灰调 · 丰富中间调灰阶 · 细腻宁静',
    previewColors: [0xFF616161, 0xFF9E9E9E, 0xFFE0E0E0],
  ),

  // 7. 徕卡风格 (Leica) · 4 款
  const RecipeDef(
    enumName: 'leicaContemporary',
    label: '徕卡 当代',
    code: 'Leica Contemp',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 1,
    sharpness: 0,
    desc: '现代德味高保真 · 扎实厚重色彩与纯正暗部',
    previewColors: [0xFFD32F2F, 0xFF1976D2, 0xFF212121],
  ),
  const RecipeDef(
    enumName: 'leicaClassic',
    label: '徕卡 经典',
    code: 'Leica Classic',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    creativeStyle: '标准',
    saturation: -1,
    contrast: 2,
    sharpness: 0,
    ab: 'A1',
    desc: '经典古典德味 · 微暖油润层次 · 空气切割感',
    previewColors: [0xFFC62828, 0xFF455A64, 0xFFECEFF1],
  ),
  const RecipeDef(
    enumName: 'leicaEternal',
    label: '徕卡 永恒',
    code: 'Leica Eternal',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -1,
    sharpness: 0,
    ab: 'A1',
    dro: '等级 3',
    desc: '沉稳克制 · 高动态灰调与电影旁轴叙事',
    previewColors: [0xFF78909C, 0xFFB0BEC5, 0xFFD7CCC8],
  ),
  const RecipeDef(
    enumName: 'leicaMonochrome',
    label: '徕卡 黑白',
    code: 'Leica Mono',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 2,
    sharpness: 1,
    desc: '旁轴纯粹银盐 · 无与伦比的深沉灰阶与影调',
    previewColors: [0xFF1A1A1A, 0xFF757575, 0xFFE0E0E0],
  ),

  // 8. 哈苏自然色彩 (Hasselblad) · 1 款
  const RecipeDef(
    enumName: 'hasselbladHNCS',
    label: '哈苏 HNCS 自然',
    code: 'Hasselblad HNCS',
    category1: '索尼大师',
    category2: '徕卡与哈苏',
    creativeStyle: '中性',
    saturation: -1,
    contrast: -1,
    sharpness: 0,
    desc: '哈苏自然色彩解决方案 · 真实平顺细腻的大画幅质感',
    previewColors: [0xFF37474F, 0xFF8D6E63, 0xFFECEFF1],
  ),

  // 9. 佳能 / 尼康 (Canon / Nikon) · 5 款
  const RecipeDef(
    enumName: 'canonStandard',
    label: '佳能 标准',
    code: 'Canon Std',
    category1: '索尼大师',
    category2: '佳能与尼康',
    creativeStyle: '标准',
    saturation: 1,
    contrast: 1,
    sharpness: 0,
    ab: 'A1',
    gm: 'M1',
    desc: '佳能明亮发色 · 洋红微提暖调 · 讨喜高光',
    previewColors: [0xFFE53935, 0xFFFFB74D, 0xFF1E88E5],
  ),
  const RecipeDef(
    enumName: 'canonPortrait',
    label: '佳能 人像',
    code: 'Canon Portrait',
    category1: '索尼大师',
    category2: '佳能与尼康',
    creativeStyle: '肖像',
    saturation: 0,
    contrast: 0,
    sharpness: -1,
    ab: 'A1',
    gm: 'M1',
    desc: '白里透红神级肤质 · 柔焦中间调微反差',
    previewColors: [0xFFFFCDD2, 0xFFFFE0B2, 0xFFE1BEE7],
  ),
  const RecipeDef(
    enumName: 'canonFaithful',
    label: '佳能 可靠设置',
    code: 'Canon Faithful',
    category1: '索尼大师',
    category2: '佳能与尼康',
    creativeStyle: '中性',
    saturation: 0,
    contrast: 0,
    sharpness: 0,
    desc: '商业摄影标准还原 · 严格遵从日光色准',
    previewColors: [0xFF78909C, 0xFFB0BEC5, 0xFFECEFF1],
  ),
  const RecipeDef(
    enumName: 'nikonFlat',
    label: '尼康 平面',
    code: 'Nikon Flat',
    category1: '索尼大师',
    category2: '佳能与尼康',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -3,
    sharpness: -1,
    dro: '等级 5',
    desc: '尼康极致宽容度 · 压高光提暗部平直曲线',
    previewColors: [0xFF607D8B, 0xFF90A4AE, 0xFFCFD8DC],
  ),
  const RecipeDef(
    enumName: 'nikonVivid',
    label: '尼康 鲜艳',
    code: 'Nikon Vivid',
    category1: '索尼大师',
    category2: '佳能与尼康',
    creativeStyle: '鲜艳',
    saturation: 1,
    contrast: 1,
    sharpness: 1,
    desc: '尼康经典风景 · 金黄色调与青透天空高锐度',
    previewColors: [0xFFFFD700, 0xFF0D47A1, 0xFF2E7D32],
  ),

  // 10. 松下 / 奥林巴斯 (Pana / Olympus) · 4 款
  const RecipeDef(
    enumName: 'panaLMonochromeD',
    label: '松下 L.黑白 D',
    code: 'Pana L.Mono D',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 3,
    sharpness: 1,
    desc: '动态黑白 · 亮部沉稳暗部扎实 · 层次分明',
    previewColors: [0xFF1A1A1A, 0xFF616161, 0xFFEEEEEE],
  ),
  const RecipeDef(
    enumName: 'panaLClassicNeo',
    label: '松下 L.经典 Neo',
    code: 'Pana L.Neo',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    creativeStyle: '中性',
    saturation: -3,
    contrast: -1,
    sharpness: 0,
    ab: 'A2',
    ev: 0.3,
    desc: '复古胶片低保真 · 柔暖黄光影感 · 岁月静好',
    previewColors: [0xFF546E7A, 0xFFFFA726, 0xFFB0BEC5],
  ),
  const RecipeDef(
    enumName: 'olympusPopArt',
    label: '奥林巴斯 浓郁色调',
    code: 'Olympus PopArt',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    creativeStyle: '鲜艳',
    saturation: 3,
    contrast: 3,
    sharpness: 0,
    desc: '奥巴蓝传奇 · 浓郁饱满视觉冲击波普艺术',
    previewColors: [0xFFFF1744, 0xFF00E676, 0xFF2979FF],
  ),
  const RecipeDef(
    enumName: 'olympusPaleLight',
    label: '奥林巴斯 淡化增亮',
    code: 'Olympus Pale',
    category1: '索尼大师',
    category2: '松下奥林巴斯',
    creativeStyle: '清淡',
    saturation: -3,
    contrast: -2,
    sharpness: 0,
    ev: 0.7,
    desc: '淡雅高光增亮 · 柔美清透马卡龙日系空气感',
    previewColors: [0xFFE0F7FA, 0xFFFFF9C4, 0xFFF8BBD0],
  ),

  // 11. 其他胶片 (Other Stocks) · 3 款
  const RecipeDef(
    enumName: 'agfaVista200',
    label: '爱克发 Vista 200',
    code: 'Vista 200',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    creativeStyle: '标准',
    saturation: 2,
    contrast: 1,
    sharpness: 0,
    ab: 'A2',
    gm: 'M1',
    ev: 0.3,
    desc: '爱克发经典红标色彩 · 艳丽红暖与深沉冷色对撞',
    previewColors: [0xFFC62828, 0xFF1565C0, 0xFFF57F17],
  ),
  const RecipeDef(
    enumName: 'agfaUltra100',
    label: '爱克发 Ultra 100',
    code: 'Ultra 100',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    creativeStyle: '鲜艳',
    saturation: 3,
    contrast: 1,
    sharpness: 0,
    desc: '超高饱和度欧洲胶片 · 纯度极高的风光艳丽感',
    previewColors: [0xFFE53935, 0xFF43A047, 0xFF039BE5],
  ),
  const RecipeDef(
    enumName: 'polaroidInstax',
    label: '宝丽来 / instax',
    code: 'Polaroid',
    category1: '电影特色',
    category2: '宝丽来爱克发',
    creativeStyle: '标准',
    saturation: -3,
    contrast: -2,
    sharpness: 0,
    ab: 'A1',
    gm: 'M2',
    ev: 0.3,
    effect: '复古照片',
    desc: '即显胶片独有泛白褪色 · 暖调暗角与岁月印记',
    previewColors: [0xFFECEFF1, 0xFFFFE082, 0xFF80CBC4],
  ),

  // 12. 伊尔福黑白 (Ilford) · 5 款
  const RecipeDef(
    enumName: 'ilfordHP5',
    label: '伊尔福 HP5',
    code: 'Ilford HP5',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 0,
    ev: 0.3,
    desc: '英国专业银盐之冠 · 极佳宽容度与柔和颗粒',
    previewColors: [0xFF212121, 0xFF616161, 0xFFE0E0E0],
  ),
  const RecipeDef(
    enumName: 'ilfordFP4',
    label: '伊尔福 FP4',
    code: 'Ilford FP4',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 1,
    desc: '中速高反差精细胶卷 · 锐利明朗的黑白线条',
    previewColors: [0xFF263238, 0xFF78909C, 0xFFECEFF1],
  ),
  const RecipeDef(
    enumName: 'ilfordDelta100',
    label: '伊尔福 Delta 100',
    code: 'Delta 100',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 1,
    sharpness: 1,
    desc: '现代结晶乳剂 · 纤毫毕现的微观灰阶质感',
    previewColors: [0xFF1C1C1C, 0xFF666666, 0xFFDFDFDF],
  ),
  const RecipeDef(
    enumName: 'ilfordDelta3200',
    label: '伊尔福 Delta 3200',
    code: 'Delta 3200',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 3,
    sharpness: -2,
    ev: 0.7,
    desc: '极限夜色弱光纪实 · 粗粝银盐与强烈戏剧明暗',
    previewColors: [0xFF0D0D0D, 0xFF555555, 0xFFFAFAFA],
  ),
  const RecipeDef(
    enumName: 'ilfordPanF50',
    label: '伊尔福 Pan F 50',
    code: 'Pan F 50',
    category1: '经典黑白',
    category2: '伊尔福银盐',
    creativeStyle: '黑白',
    saturation: 0,
    contrast: 2,
    sharpness: 2,
    desc: '超细微颗粒 · 丝绸般平滑深邃的影调画质',
    previewColors: [0xFF1F1F1F, 0xFF707070, 0xFFEEEEEE],
  ),
];

void main() {
  final buf = StringBuffer();
  buf.writeln("import 'dart:math' as math;");
  buf.writeln("import 'dart:ui' as ui;");
  buf.writeln("import 'package:flutter/material.dart';");
  buf.writeln();
  buf.writeln("/// Lightroom 级专业照片调色参数模型");
  buf.writeln("class PhotoEditAdjustments {");
  buf.writeln("  // 1. 白平衡 (White Balance)");
  buf.writeln("  final double temperature; // 色温: -100 (冷蓝) ~ +100 (暖黄)");
  buf.writeln("  final double tint;        // 色调: -100 (偏绿) ~ +100 (洋红/品红)");
  buf.writeln();
  buf.writeln("  // 2. 基础色调 (Tone)");
  buf.writeln("  final double exposure;    // 曝光度: -100 ~ +100 (-2EV ~ +2EV)");
  buf.writeln("  final double contrast;    // 对比度: -100 (柔和灰阶) ~ +100 (高反差)");
  buf.writeln("  final double highlights;  // 高光: -100 (压暗高光) ~ +100 (提亮高光)");
  buf.writeln("  final double shadows;     // 阴影: -100 (压暗阴影) ~ +100 (提亮暗部死黑)");
  buf.writeln("  final double whites;      // 白色色阶: -100 ~ +100 (高光白色剪切阈值)");
  buf.writeln("  final double blacks;      // 黑色色阶: -100 ~ +100 (纯黑深度阈值)");
  buf.writeln();
  buf.writeln("  // 3. 偏好与细节质感 (Presence & Details)");
  buf.writeln("  final double texture;     // 纹理: -100 (柔肤柔和) ~ +100 (微观表面肌理强化)");
  buf.writeln("  final double clarity;     // 清晰度: -100 ~ +100 (中间调微反差质感)");
  buf.writeln("  final double dehaze;      // 去朦胧: -100 (朦胧薄雾) ~ +100 (通透除霾)");
  buf.writeln("  final double vibrance;    // 鲜艳度/自然饱和度: -100 ~ +100 (智能保肤色饱和度)");
  buf.writeln("  final double saturation;  // 全局饱和度: -100 (灰度纯黑白) ~ +100 (浓郁纯色)");
  buf.writeln();
  buf.writeln("  // 4. 颜色分级 / 分离色调 (Color Grading / Split Toning)");
  buf.writeln("  final double highlightHue; // 高光色相: 0° ~ 360° (如橙黄 35°~50°)");
  buf.writeln("  final double highlightSat; // 高光饱和度: 0 ~ 100");
  buf.writeln("  final double shadowHue;    // 阴影色相: 0° ~ 360° (如青蓝 200°~230°)");
  buf.writeln("  final double shadowSat;    // 阴影饱和度: 0 ~ 100");
  buf.writeln();
  buf.writeln("  // 5. 镜头与质感效果 (Effects)");
  buf.writeln("  final double vignette;    // 镜头暗角: -100 (高调白角) ~ +100 (经典电影黑暗角)");
  buf.writeln("  final double grain;       // 胶片颗粒: 0 ~ 100 (真实银盐胶片颗粒感)");
  buf.writeln();
  buf.writeln("  const PhotoEditAdjustments({");
  buf.writeln("    this.temperature = 0.0,");
  buf.writeln("    this.tint = 0.0,");
  buf.writeln("    this.exposure = 0.0,");
  buf.writeln("    this.contrast = 0.0,");
  buf.writeln("    this.highlights = 0.0,");
  buf.writeln("    this.shadows = 0.0,");
  buf.writeln("    this.whites = 0.0,");
  buf.writeln("    this.blacks = 0.0,");
  buf.writeln("    this.texture = 0.0,");
  buf.writeln("    this.clarity = 0.0,");
  buf.writeln("    this.dehaze = 0.0,");
  buf.writeln("    this.vibrance = 0.0,");
  buf.writeln("    this.saturation = 0.0,");
  buf.writeln("    this.highlightHue = 40.0,");
  buf.writeln("    this.highlightSat = 0.0,");
  buf.writeln("    this.shadowHue = 220.0,");
  buf.writeln("    this.shadowSat = 0.0,");
  buf.writeln("    this.vignette = 0.0,");
  buf.writeln("    this.grain = 0.0,");
  buf.writeln("  });");
  buf.writeln();
  buf.writeln("  /// 是否为完全默认状态 (零调节)");
  buf.writeln("  bool get isDefault =>");
  buf.writeln("      temperature == 0.0 &&");
  buf.writeln("      tint == 0.0 &&");
  buf.writeln("      exposure == 0.0 &&");
  buf.writeln("      contrast == 0.0 &&");
  buf.writeln("      highlights == 0.0 &&");
  buf.writeln("      shadows == 0.0 &&");
  buf.writeln("      whites == 0.0 &&");
  buf.writeln("      blacks == 0.0 &&");
  buf.writeln("      texture == 0.0 &&");
  buf.writeln("      clarity == 0.0 &&");
  buf.writeln("      dehaze == 0.0 &&");
  buf.writeln("      vibrance == 0.0 &&");
  buf.writeln("      saturation == 0.0 &&");
  buf.writeln("      highlightSat == 0.0 &&");
  buf.writeln("      shadowSat == 0.0 &&");
  buf.writeln("      vignette == 0.0 &&");
  buf.writeln("      grain == 0.0;");
  buf.writeln();
  buf.writeln("  PhotoEditAdjustments copyWith({");
  buf.writeln("    double? temperature,");
  buf.writeln("    double? tint,");
  buf.writeln("    double? exposure,");
  buf.writeln("    double? contrast,");
  buf.writeln("    double? highlights,");
  buf.writeln("    double? shadows,");
  buf.writeln("    double? whites,");
  buf.writeln("    double? blacks,");
  buf.writeln("    double? texture,");
  buf.writeln("    double? clarity,");
  buf.writeln("    double? dehaze,");
  buf.writeln("    double? vibrance,");
  buf.writeln("    double? saturation,");
  buf.writeln("    double? highlightHue,");
  buf.writeln("    double? highlightSat,");
  buf.writeln("    double? shadowHue,");
  buf.writeln("    double? shadowSat,");
  buf.writeln("    double? vignette,");
  buf.writeln("    double? grain,");
  buf.writeln("  }) {");
  buf.writeln("    return PhotoEditAdjustments(");
  buf.writeln("      temperature: temperature ?? this.temperature,");
  buf.writeln("      tint: tint ?? this.tint,");
  buf.writeln("      exposure: exposure ?? this.exposure,");
  buf.writeln("      contrast: contrast ?? this.contrast,");
  buf.writeln("      highlights: highlights ?? this.highlights,");
  buf.writeln("      shadows: shadows ?? this.shadows,");
  buf.writeln("      whites: whites ?? this.whites,");
  buf.writeln("      blacks: blacks ?? this.blacks,");
  buf.writeln("      texture: texture ?? this.texture,");
  buf.writeln("      clarity: clarity ?? this.clarity,");
  buf.writeln("      dehaze: dehaze ?? this.dehaze,");
  buf.writeln("      vibrance: vibrance ?? this.vibrance,");
  buf.writeln("      saturation: saturation ?? this.saturation,");
  buf.writeln("      highlightHue: highlightHue ?? this.highlightHue,");
  buf.writeln("      highlightSat: highlightSat ?? this.highlightSat,");
  buf.writeln("      shadowHue: shadowHue ?? this.shadowHue,");
  buf.writeln("      shadowSat: shadowSat ?? this.shadowSat,");
  buf.writeln("      vignette: vignette ?? this.vignette,");
  buf.writeln("      grain: grain ?? this.grain,");
  buf.writeln("    );");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static const PhotoEditAdjustments initial = PhotoEditAdjustments();");
  buf.writeln();
  buf.writeln("  @override");
  buf.writeln("  bool operator ==(Object other) =>");
  buf.writeln("      identical(this, other) ||");
  buf.writeln("      other is PhotoEditAdjustments &&");
  buf.writeln("          runtimeType == other.runtimeType &&");
  buf.writeln("          temperature == other.temperature &&");
  buf.writeln("          tint == other.tint &&");
  buf.writeln("          exposure == other.exposure &&");
  buf.writeln("          contrast == other.contrast &&");
  buf.writeln("          highlights == other.highlights &&");
  buf.writeln("          shadows == other.shadows &&");
  buf.writeln("          whites == other.whites &&");
  buf.writeln("          blacks == other.blacks &&");
  buf.writeln("          texture == other.texture &&");
  buf.writeln("          clarity == other.clarity &&");
  buf.writeln("          dehaze == other.dehaze &&");
  buf.writeln("          vibrance == other.vibrance &&");
  buf.writeln("          saturation == other.saturation &&");
  buf.writeln("          highlightHue == other.highlightHue &&");
  buf.writeln("          highlightSat == other.highlightSat &&");
  buf.writeln("          shadowHue == other.shadowHue &&");
  buf.writeln("          shadowSat == other.shadowSat &&");
  buf.writeln("          vignette == other.vignette &&");
  buf.writeln("          grain == other.grain;");
  buf.writeln();
  buf.writeln("  @override");
  buf.writeln("  int get hashCode => Object.hashAll([");
  buf.writeln("        temperature,");
  buf.writeln("        tint,");
  buf.writeln("        exposure,");
  buf.writeln("        contrast,");
  buf.writeln("        highlights,");
  buf.writeln("        shadows,");
  buf.writeln("        whites,");
  buf.writeln("        blacks,");
  buf.writeln("        texture,");
  buf.writeln("        clarity,");
  buf.writeln("        dehaze,");
  buf.writeln("        vibrance,");
  buf.writeln("        saturation,");
  buf.writeln("        highlightHue,");
  buf.writeln("        highlightSat,");
  buf.writeln("        shadowHue,");
  buf.writeln("        shadowSat,");
  buf.writeln("        vignette,");
  buf.writeln("        grain,");
  buf.writeln("      ]);");
  buf.writeln("}");
  buf.writeln();

  buf.writeln("/// 直出胶片与大师调色预设枚举 (涵盖 77 款相机实拍配方 + 10 款经典精选)");
  buf.writeln("enum PhotoFilterType {");

  // Output 77 recipes
  for (final r in recipes) {
    final adj = r.computeAdjustments();
    final colorsStr = r.previewColors.map((c) => "Color(0x${c.toRadixString(16).toUpperCase()})").join(', ');
    buf.writeln("  ${r.enumName}(");
    buf.writeln("    label: '${r.label}',");
    buf.writeln("    code: '${r.code}',");
    buf.writeln("    category1: '${r.category1}',");
    buf.writeln("    category2: '${r.category2}',");
    buf.writeln("    description: '${r.desc}',");
    buf.writeln("    recipeSummary: '${r.summary}',");
    buf.writeln("    previewColors: [$colorsStr],");
    buf.writeln("    presetAdjustments: const PhotoEditAdjustments(");
    if (adj['temperature'] != 0.0) buf.writeln("      temperature: ${adj['temperature']},");
    if (adj['tint'] != 0.0) buf.writeln("      tint: ${adj['tint']},");
    if (adj['exposure'] != 0.0) buf.writeln("      exposure: ${adj['exposure']},");
    if (adj['contrast'] != 0.0) buf.writeln("      contrast: ${adj['contrast']},");
    if (adj['highlights'] != 0.0) buf.writeln("      highlights: ${adj['highlights']},");
    if (adj['shadows'] != 0.0) buf.writeln("      shadows: ${adj['shadows']},");
    if (adj['whites'] != 0.0) buf.writeln("      whites: ${adj['whites']},");
    if (adj['blacks'] != 0.0) buf.writeln("      blacks: ${adj['blacks']},");
    if (adj['texture'] != 0.0) buf.writeln("      texture: ${adj['texture']},");
    if (adj['clarity'] != 0.0) buf.writeln("      clarity: ${adj['clarity']},");
    if (adj['dehaze'] != 0.0) buf.writeln("      dehaze: ${adj['dehaze']},");
    if (adj['vibrance'] != 0.0) buf.writeln("      vibrance: ${adj['vibrance']},");
    if (adj['saturation'] != 0.0) buf.writeln("      saturation: ${adj['saturation']},");
    if (adj['highlightSat'] != 0.0) {
      buf.writeln("      highlightHue: ${adj['highlightHue']},");
      buf.writeln("      highlightSat: ${adj['highlightSat']},");
    }
    if (adj['shadowSat'] != 0.0) {
      buf.writeln("      shadowHue: ${adj['shadowHue']},");
      buf.writeln("      shadowSat: ${adj['shadowSat']},");
    }
    if (adj['vignette'] != 0.0) buf.writeln("      vignette: ${adj['vignette']},");
    if (adj['grain'] != 0.0) buf.writeln("      grain: ${adj['grain']},");
    buf.writeln("    ),");
    buf.writeln("  ),");
  }

  // Output 10 classic presets
  final classics = [
    {
      'enum': 'original',
      'label': '原片直出',
      'code': 'Original',
      'desc': '相机原生色彩 · 零修饰直出',
      'summary': '原片 · 零调节',
      'colors': 'const [Color(0xFF333333), Color(0xFF888888), Color(0xFFE0E0E0)]',
      'adj': 'PhotoEditAdjustments.initial',
    },
    {
      'enum': 'fairSkin',
      'label': '冷白皮人像',
      'code': 'Fair Skin',
      'desc': '去黄冷白 · 白里透红 · 柔肤清透高级感',
      'summary': '肖像 · 去黄 · 柔光白皙',
      'colors': 'const [Color(0xFFFFCDD2), Color(0xFFF8BBD0), Color(0xFFE1BEE7)]',
      'adj': 'const PhotoEditAdjustments(temperature: -12.0, tint: 6.0, exposure: 15.0, contrast: 8.0, highlights: -25.0, shadows: 28.0, texture: -15.0, clarity: -12.0, vibrance: 12.0, saturation: -5.0, highlightHue: 345.0, highlightSat: 8.0, shadowHue: 215.0, shadowSat: 10.0)',
    },
    {
      'enum': 'warmPortrait',
      'label': '暖色温馨',
      'code': 'Warm Gold',
      'desc': '黄金时刻 · 暖高光冷阴影 · 治愈午后日光',
      'summary': '暖阳 · 金黄高光 · 治愈人像',
      'colors': 'const [Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFB0BEC5)]',
      'adj': 'const PhotoEditAdjustments(temperature: 20.0, tint: 6.0, exposure: 10.0, contrast: 5.0, highlights: -30.0, shadows: 30.0, vibrance: 22.0, highlightHue: 42.0, highlightSat: 25.0, shadowHue: 215.0, shadowSat: 15.0)',
    },
    {
      'enum': 'japanesePure',
      'label': '日系街道',
      'code': 'Japanese Pure',
      'desc': '空气感高明度 · 低反差 · 暗部透气微泛青蓝',
      'summary': '日系 · 低反差 · 空气感',
      'colors': 'const [Color(0xFF81D4FA), Color(0xFFA5D6A7), Color(0xFFFFF9C4)]',
      'adj': 'const PhotoEditAdjustments(temperature: -25.0, tint: 4.0, exposure: 25.0, contrast: -28.0, highlights: -40.0, shadows: 45.0, whites: -15.0, blacks: 20.0, texture: -10.0, clarity: 12.0, vibrance: -10.0, vignette: 10.0, grain: 15.0, shadowHue: 220.0, shadowSat: 12.0)',
    },
    {
      'enum': 'shinkaiAnime',
      'label': '新海诚风',
      'code': 'Shinkai Anime',
      'desc': '梦幻动画感 · 高纯度青蓝晴空与鲜翠草木',
      'summary': '动漫 · 翠绿晴空 · 高纯度',
      'colors': 'const [Color(0xFF29B6F6), Color(0xFF66BB6A), Color(0xFFFFEE58)]',
      'adj': 'const PhotoEditAdjustments(temperature: -35.0, tint: 25.0, exposure: 15.0, contrast: -20.0, highlights: -22.0, shadows: 50.0, clarity: 25.0, dehaze: 15.0, vibrance: 40.0, saturation: 25.0, highlightHue: 200.0, highlightSat: 15.0, shadowHue: 215.0, shadowSat: 20.0)',
    },
    {
      'enum': 'cityNight',
      'label': '城市夜景',
      'code': 'City Night',
      'desc': '冷夜深蓝 · 高反差深邃黑 · 压制霓虹高光',
      'summary': '深蓝冷夜 · 纯黑深邃 · 压制高光',
      'colors': 'const [Color(0xFF0D47A1), Color(0xFF37474F), Color(0xFFFFB300)]',
      'adj': 'const PhotoEditAdjustments(temperature: -20.0, tint: 5.0, exposure: -5.0, contrast: 20.0, highlights: -25.0, shadows: 15.0, whites: 15.0, blacks: -12.0, clarity: 20.0, dehaze: 15.0, shadowHue: 220.0, shadowSat: 15.0)',
    },
    {
      'enum': 'forestGreen',
      'label': '绿色森林',
      'code': 'Forest Green',
      'desc': '纯净翠绿 · 去黄透光感 · 去朦胧胶片氛围',
      'summary': '翠绿 · 透光去黄 · 胶片森林',
      'colors': 'const [Color(0xFF2E7D32), Color(0xFF43A047), Color(0xFF81C784)]',
      'adj': 'const PhotoEditAdjustments(temperature: -10.0, tint: 15.0, exposure: 5.0, contrast: 12.0, highlights: -28.0, shadows: 25.0, whites: 10.0, blacks: -10.0, clarity: 15.0, dehaze: 18.0, vibrance: 25.0, saturation: 10.0, shadowHue: 155.0, shadowSat: 12.0)',
    },
    {
      'enum': 'floralBotanical',
      'label': '花木生机',
      'code': 'Floral Botanical',
      'desc': '微距质感 · 自然饱和保花蕊 · 花瓣层次分明',
      'summary': '微距 · 鲜活花木 · 细节微反差',
      'colors': 'const [Color(0xFFEC407A), Color(0xFFAB47BC), Color(0xFF66BB6A)]',
      'adj': 'const PhotoEditAdjustments(temperature: 5.0, tint: 12.0, exposure: 8.0, contrast: 10.0, highlights: -15.0, shadows: 20.0, texture: 20.0, clarity: 15.0, dehaze: 8.0, vibrance: 30.0, saturation: 8.0)',
    },
    {
      'enum': 'clearSky',
      'label': '通透蓝天',
      'code': 'Clear Sky',
      'desc': '风光专属 · 强化晴空纯净天蓝 · 白云立体层次',
      'summary': '纯净晴空 · 立体云层 · 去雾',
      'colors': 'const [Color(0xFF0288D1), Color(0xFF29B6F6), Color(0xFFB3E5FC)]',
      'adj': 'const PhotoEditAdjustments(temperature: -15.0, tint: 8.0, exposure: 10.0, contrast: 10.0, highlights: -25.0, shadows: 20.0, dehaze: 20.0, vibrance: 25.0, saturation: 10.0, highlightHue: 205.0, highlightSat: 15.0)',
    },
    {
      'enum': 'cinematic',
      'label': '电影质感',
      'code': 'Cinematic',
      'desc': '大片光影 · 高宽容度叙事 · 青橙对撞暗调',
      'summary': '青橙胶片 · 好莱坞大片光影',
      'colors': 'const [Color(0xFF00695C), Color(0xFFE65100), Color(0xFF263238)]',
      'adj': 'const PhotoEditAdjustments(temperature: -10.0, tint: 8.0, exposure: 5.0, contrast: 22.0, highlights: -20.0, shadows: 15.0, clarity: 18.0, vibrance: 12.0, vignette: 15.0, grain: 18.0, highlightHue: 35.0, highlightSat: 25.0, shadowHue: 215.0, shadowSat: 20.0)',
    },
  ];

  for (final c in classics) {
    buf.writeln("  ${c['enum']}(");
    buf.writeln("    label: '${c['label']}',");
    buf.writeln("    code: '${c['code']}',");
    buf.writeln("    category1: '经典精选',");
    buf.writeln("    category2: '原片与精选',");
    buf.writeln("    description: '${c['desc']}',");
    buf.writeln("    recipeSummary: '${c['summary']}',");
    buf.writeln("    previewColors: ${c['colors']},");
    buf.writeln("    presetAdjustments: ${c['adj']},");
    buf.writeln("  ),");
  }

  buf.writeln(";");
  buf.writeln();

  buf.writeln("  final String label;");
  buf.writeln("  final String code;");
  buf.writeln("  final String category1;");
  buf.writeln("  final String category2;");
  buf.writeln("  final String description;");
  buf.writeln("  final String recipeSummary;");
  buf.writeln("  final List<Color> previewColors;");
  buf.writeln("  final PhotoEditAdjustments presetAdjustments;");
  buf.writeln();
  buf.writeln("  const PhotoFilterType({");
  buf.writeln("    required this.label,");
  buf.writeln("    required this.code,");
  buf.writeln("    required this.category1,");
  buf.writeln("    required this.category2,");
  buf.writeln("    required this.description,");
  buf.writeln("    required this.recipeSummary,");
  buf.writeln("    required this.previewColors,");
  buf.writeln("    required this.presetAdjustments,");
  buf.writeln("  });");
  buf.writeln();
  buf.writeln("  /// 所有一级分类定义 (按摄影流派规范排列)");
  buf.writeln("  static const List<String> categories1 = [");
  buf.writeln("    '富士胶片',");
  buf.writeln("    '柯达胶片',");
  buf.writeln("    '理光人文',");
  buf.writeln("    '索尼大师',");
  buf.writeln("    '经典黑白',");
  buf.writeln("    '电影特色',");
  buf.writeln("    '经典精选',");
  buf.writeln("  ];");
  buf.writeln();
  buf.writeln("  /// 根据一级分类获取其包含的二级分类列表");
  buf.writeln("  static List<String> getCategories2(String cat1) {");
  buf.writeln("    final list = <String>[];");
  buf.writeln("    for (final f in values) {");
  buf.writeln("      if (f.category1 == cat1 && !list.contains(f.category2)) {");
  buf.writeln("        list.add(f.category2);");
  buf.writeln("      }");
  buf.writeln("    }");
  buf.writeln("    return list;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// 根据一级分类与二级分类获取匹配的预设列表");
  buf.writeln("  static List<PhotoFilterType> getByCategories(String cat1, [String? cat2]) {");
  buf.writeln("    return values.where((f) {");
  buf.writeln("      if (f.category1 != cat1) return false;");
  buf.writeln("      if (cat2 != null && cat2.isNotEmpty && f.category2 != cat2) return false;");
  buf.writeln("      return true;");
  buf.writeln("    }).toList();");
  buf.writeln("  }");
  buf.writeln("}");
  buf.writeln();

  buf.writeln("/// 胶片色彩矩阵与硬件加速图像调色引擎");
  buf.writeln("class PhotoFilterEngine {");
  buf.writeln("  PhotoFilterEngine._();");
  buf.writeln();
  buf.writeln("  /// 标准单位矩阵 (Identity Matrix)");
  buf.writeln("  static const List<double> identityMatrix = <double>[");
  buf.writeln("    1, 0, 0, 0, 0,");
  buf.writeln("    0, 1, 0, 0, 0,");
  buf.writeln("    0, 0, 1, 0, 0,");
  buf.writeln("    0, 0, 0, 1, 0,");
  buf.writeln("  ];");
  buf.writeln();
  buf.writeln("  /// 专业摄影 4x5 调色微调矩阵库 (精选经典手调矩阵)");
  buf.writeln("  static const Map<PhotoFilterType, List<double>> _filterMatrices = {");
  buf.writeln("    PhotoFilterType.original: identityMatrix,");
  buf.writeln("    PhotoFilterType.fairSkin: <double>[");
  buf.writeln("      1.08, -0.02, -0.02, 0, 12,");
  buf.writeln("      -0.02, 1.05, -0.01, 0, 6,");
  buf.writeln("      -0.01, -0.01, 1.15, 0, 14,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.warmPortrait: <double>[");
  buf.writeln("      1.18,  0.04, -0.08, 0, 16,");
  buf.writeln("      0.02,  1.08, -0.06, 0, 8,");
  buf.writeln("      -0.10, -0.04, 0.95, 0, -4,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.japanesePure: <double>[");
  buf.writeln("      0.95,  0.04,  0.05, 0, 18,");
  buf.writeln("      0.02,  1.03,  0.04, 0, 18,");
  buf.writeln("      0.04,  0.04,  1.16, 0, 26,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.shinkaiAnime: <double>[");
  buf.writeln("      1.14, -0.05, -0.04, 0, 10,");
  buf.writeln("      -0.04, 1.28, -0.06, 0, 14,");
  buf.writeln("      -0.08, 0.05, 1.38,  0, 24,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.cityNight: <double>[");
  buf.writeln("      1.15, -0.08, -0.08, 0, -8,");
  buf.writeln("      -0.06, 1.10,  0.02, 0, -6,");
  buf.writeln("      -0.12,  0.04, 1.35, 0, 12,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.forestGreen: <double>[");
  buf.writeln("      0.98, -0.06, -0.04, 0, 4,");
  buf.writeln("      -0.04, 1.35, -0.06, 0, 18,");
  buf.writeln("      -0.06,  0.06, 1.12, 0, 8,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.floralBotanical: <double>[");
  buf.writeln("      1.12, -0.04, -0.02, 0, 8,");
  buf.writeln("      -0.02, 1.24, -0.04, 0, 12,");
  buf.writeln("      -0.04,  0.02, 1.18, 0, 10,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.classicChrome: <double>[");
  buf.writeln("      1.08, -0.05, -0.03, 0, -2,");
  buf.writeln("      -0.03, 1.02, -0.02, 0, 1,");
  buf.writeln("      -0.05, -0.02, 1.12, 0, 4,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.leicaMonochrome: <double>[");
  buf.writeln("      0.35, 0.65, 0.15, 0, -10,");
  buf.writeln("      0.35, 0.65, 0.15, 0, -10,");
  buf.writeln("      0.35, 0.65, 0.15, 0, -10,");
  buf.writeln("      0,    0,    0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.clearSky: <double>[");
  buf.writeln("      1.02, -0.02, -0.08, 0, 2,");
  buf.writeln("      -0.02, 1.05, -0.04, 0, 4,");
  buf.writeln("      -0.10,  0.08, 1.38, 0, 24,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("    PhotoFilterType.cinematic: <double>[");
  buf.writeln("      1.24, -0.06, -0.12, 0, 6,");
  buf.writeln("      -0.06, 1.08,  0.06, 0, -4,");
  buf.writeln("      -0.14,  0.04, 1.28, 0, 8,");
  buf.writeln("      0,     0,     0,    1, 0,");
  buf.writeln("    ],");
  buf.writeln("  };");
  buf.writeln();
  buf.writeln("  /// 获取指定预设对应的基础调色模型");
  buf.writeln("  static PhotoEditAdjustments getPresetAdjustments(PhotoFilterType type) {");
  buf.writeln("    return type.presetAdjustments;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// 获取指定滤镜在特定强度下的 4x5 混合矩阵");
  buf.writeln("  static List<double> getMatrix(PhotoFilterType type, [double intensity = 1.0]) {");
  buf.writeln("    final clamped = intensity.clamp(0.0, 1.0);");
  buf.writeln("    if (clamped <= 0.01 || type == PhotoFilterType.original) return identityMatrix;");
  buf.writeln("    final target = _filterMatrices[type] ?? buildAdjustmentsMatrix(type.presetAdjustments);");
  buf.writeln("    if (clamped >= 0.99) return target;");
  buf.writeln();
  buf.writeln("    final mixed = List<double>.filled(20, 0.0);");
  buf.writeln("    for (int i = 0; i < 20; i++) {");
  buf.writeln("      mixed[i] = identityMatrix[i] + (target[i] - identityMatrix[i]) * clamped;");
  buf.writeln("    }");
  buf.writeln("    return mixed;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// 4x5 仿射色彩矩阵数学乘法 (Matrix A * Matrix B)");
  buf.writeln("  static List<double> multiplyMatrices(List<double> a, List<double> b) {");
  buf.writeln("    final result = List<double>.filled(20, 0.0);");
  buf.writeln("    for (int row = 0; row < 4; row++) {");
  buf.writeln("      for (int col = 0; col < 4; col++) {");
  buf.writeln("        double sum = 0.0;");
  buf.writeln("        for (int k = 0; k < 4; k++) {");
  buf.writeln("          sum += a[row * 5 + k] * b[k * 5 + col];");
  buf.writeln("        }");
  buf.writeln("        result[row * 5 + col] = sum;");
  buf.writeln("      }");
  buf.writeln("      double offsetSum = a[row * 5 + 4];");
  buf.writeln("      for (int k = 0; k < 4; k++) {");
  buf.writeln("        offsetSum += a[row * 5 + k] * b[k * 5 + 4];");
  buf.writeln("      }");
  buf.writeln("      result[row * 5 + 4] = offsetSum;");
  buf.writeln("    }");
  buf.writeln("    return result;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// HSV 转换为单位 RGB 分量");
  buf.writeln("  static List<double> _hsvToRgb(double hue, double sat) {");
  buf.writeln("    if (sat <= 0.01) return [0.5, 0.5, 0.5];");
  buf.writeln("    final h = (hue % 360) / 60.0;");
  buf.writeln("    final c = sat;");
  buf.writeln("    final x = c * (1.0 - (h % 2 - 1.0).abs());");
  buf.writeln("    double r = 0, g = 0, b = 0;");
  buf.writeln("    if (h >= 0 && h < 1) {");
  buf.writeln("      r = c; g = x;");
  buf.writeln("    } else if (h >= 1 && h < 2) {");
  buf.writeln("      r = x; g = c;");
  buf.writeln("    } else if (h >= 2 && h < 3) {");
  buf.writeln("      g = c; b = x;");
  buf.writeln("    } else if (h >= 3 && h < 4) {");
  buf.writeln("      g = x; b = c;");
  buf.writeln("    } else if (h >= 4 && h < 5) {");
  buf.writeln("      r = x; b = c;");
  buf.writeln("    } else {");
  buf.writeln("      r = c; b = x;");
  buf.writeln("    }");
  buf.writeln("    final m = 1.0 - c;");
  buf.writeln("    return [r + m * 0.5, g + m * 0.5, b + m * 0.5];");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// 基于 Adobe Lightroom 核心调色算法计算 4x5 色彩调色矩阵");
  buf.writeln("  static List<double> buildAdjustmentsMatrix(PhotoEditAdjustments adj) {");
  buf.writeln("    if (adj.isDefault) return identityMatrix;");
  buf.writeln();
  buf.writeln("    double expFactor = 1.0;");
  buf.writeln("    if (adj.exposure >= 0) {");
  buf.writeln("      expFactor = 1.0 + (adj.exposure / 100.0) * 1.0;");
  buf.writeln("    } else {");
  buf.writeln("      expFactor = 1.0 + (adj.exposure / 100.0) * 0.75;");
  buf.writeln("    }");
  buf.writeln("    final expOffset = adj.exposure * 0.25;");
  buf.writeln("    final hiGain = 1.0 + (adj.highlights / 100.0) * 0.18;");
  buf.writeln("    final wOffset = (adj.whites / 100.0) * 18.0;");
  buf.writeln("    final shOffset = (adj.shadows / 100.0) * 22.0;");
  buf.writeln("    final blOffset = (adj.blacks / 100.0) * 16.0;");
  buf.writeln();
  buf.writeln("    final cFactor = 1.0 +");
  buf.writeln("        (adj.contrast / 100.0) * 0.65 +");
  buf.writeln("        (adj.clarity / 100.0) * 0.25 +");
  buf.writeln("        (adj.texture / 100.0) * 0.15 +");
  buf.writeln("        (adj.dehaze / 100.0) * 0.20;");
  buf.writeln("    final cOffset = 128.0 * (1.0 - cFactor);");
  buf.writeln("    final dhCut = -(adj.dehaze / 100.0) * 14.0;");
  buf.writeln();
  buf.writeln("    final tempRScale = 1.0 + (adj.temperature / 100.0) * 0.22;");
  buf.writeln("    final tempBScale = 1.0 - (adj.temperature / 100.0) * 0.22;");
  buf.writeln("    final tempROffset = (adj.temperature / 100.0) * 16.0;");
  buf.writeln("    final tempBOffset = -(adj.temperature / 100.0) * 16.0;");
  buf.writeln();
  buf.writeln("    final tintGScale = 1.0 - (adj.tint / 100.0) * 0.18;");
  buf.writeln("    final tintRBScale = 1.0 + (adj.tint / 100.0) * 0.10;");
  buf.writeln("    final tintGOffset = -(adj.tint / 100.0) * 12.0;");
  buf.writeln("    final tintRBOffset = (adj.tint / 100.0) * 6.0;");
  buf.writeln();
  buf.writeln("    double splitROffset = 0.0;");
  buf.writeln("    double splitGOffset = 0.0;");
  buf.writeln("    double splitBOffset = 0.0;");
  buf.writeln("    if (adj.highlightSat > 0.01) {");
  buf.writeln("      final hlRgb = _hsvToRgb(adj.highlightHue, adj.highlightSat / 100.0);");
  buf.writeln("      splitROffset += (hlRgb[0] - 0.5) * 28.0;");
  buf.writeln("      splitGOffset += (hlRgb[1] - 0.5) * 28.0;");
  buf.writeln("      splitBOffset += (hlRgb[2] - 0.5) * 28.0;");
  buf.writeln("    }");
  buf.writeln("    if (adj.shadowSat > 0.01) {");
  buf.writeln("      final shRgb = _hsvToRgb(adj.shadowHue, adj.shadowSat / 100.0);");
  buf.writeln("      splitROffset += (shRgb[0] - 0.5) * 22.0;");
  buf.writeln("      splitGOffset += (shRgb[1] - 0.5) * 22.0;");
  buf.writeln("      splitBOffset += (shRgb[2] - 0.5) * 22.0;");
  buf.writeln("    }");
  buf.writeln();
  buf.writeln("    final sVal = 1.0 + (adj.saturation / 100.0) * 1.25 + (adj.vibrance / 100.0) * 0.65;");
  buf.writeln("    const double lr = 0.299;");
  buf.writeln("    const double lg = 0.587;");
  buf.writeln("    const double lb = 0.114;");
  buf.writeln("    final double invS = 1.0 - sVal;");
  buf.writeln("    final double sr = invS * lr;");
  buf.writeln("    final double sg = invS * lg;");
  buf.writeln("    final double sb = invS * lb;");
  buf.writeln();
  buf.writeln("    final rGain = expFactor * hiGain * tempRScale * tintRBScale;");
  buf.writeln("    final gGain = expFactor * hiGain * tintGScale;");
  buf.writeln("    final bGain = expFactor * hiGain * tempBScale * tintRBScale;");
  buf.writeln();
  buf.writeln("    final rOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tempROffset + tintRBOffset + splitROffset;");
  buf.writeln("    final gOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tintGOffset + splitGOffset;");
  buf.writeln("    final bOff = expOffset + wOffset + shOffset + blOffset + cOffset + dhCut + tempBOffset + tintRBOffset + splitBOffset;");
  buf.writeln();
  buf.writeln("    return <double>[");
  buf.writeln("      (sr + sVal) * cFactor * rGain, sg * cFactor * rGain,          sb * cFactor * rGain,          0, rOff,");
  buf.writeln("      sr * cFactor * gGain,          (sg + sVal) * cFactor * gGain, sb * cFactor * gGain,          0, gOff,");
  buf.writeln("      sr * cFactor * bGain,          sg * cFactor * bGain,          (sb + sVal) * cFactor * bGain, 0, bOff,");
  buf.writeln("      0,                             0,                             0,                             1, 0,");
  buf.writeln("    ];");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  /// 计算指定预设滤镜与其特定调节项叠加后的终极 4x5 色彩调色矩阵");
  buf.writeln("  static List<double> getCompositeMatrix({");
  buf.writeln("    PhotoFilterType filterType = PhotoFilterType.original,");
  buf.writeln("    double filterIntensity = 1.0,");
  buf.writeln("    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),");
  buf.writeln("  }) {");
  buf.writeln("    final baseFilterMatrix = getMatrix(filterType, filterIntensity);");
  buf.writeln("    if (adjustments.isDefault) {");
  buf.writeln("      return baseFilterMatrix;");
  buf.writeln("    }");
  buf.writeln("    final adjMatrix = buildAdjustmentsMatrix(adjustments);");
  buf.writeln("    if (filterType == PhotoFilterType.original || filterIntensity <= 0.01) {");
  buf.writeln("      return adjMatrix;");
  buf.writeln("    }");
  buf.writeln("    return multiplyMatrices(baseFilterMatrix, adjMatrix);");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static List<double> createCompositeMatrix({");
  buf.writeln("    PhotoFilterType filterType = PhotoFilterType.original,");
  buf.writeln("    double filterIntensity = 1.0,");
  buf.writeln("    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),");
  buf.writeln("  }) => getCompositeMatrix(filterType: filterType, filterIntensity: filterIntensity, adjustments: adjustments);");
  buf.writeln();
  buf.writeln("  static List<int> applyMatrixToRgb(int r, int g, int b, List<double> matrix) {");
  buf.writeln("    final newR = (matrix[0] * r + matrix[1] * g + matrix[2] * b + matrix[4]).clamp(0.0, 255.0).toInt();");
  buf.writeln("    final newG = (matrix[5] * r + matrix[6] * g + matrix[7] * b + matrix[9]).clamp(0.0, 255.0).toInt();");
  buf.writeln("    final newB = (matrix[10] * r + matrix[11] * g + matrix[12] * b + matrix[14]).clamp(0.0, 255.0).toInt();");
  buf.writeln("    return [newR, newG, newB];");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static ColorFilter createColorFilter(PhotoFilterType type, [double intensity = 1.0]) {");
  buf.writeln("    return ColorFilter.matrix(getMatrix(type, intensity));");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static ColorFilter createCompositeFilter({");
  buf.writeln("    PhotoFilterType filterType = PhotoFilterType.original,");
  buf.writeln("    double filterIntensity = 1.0,");
  buf.writeln("    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),");
  buf.writeln("  }) {");
  buf.writeln("    if (filterType == PhotoFilterType.original && adjustments.isDefault && filterIntensity <= 0.01) {");
  buf.writeln("      return const ColorFilter.matrix(identityMatrix);");
  buf.writeln("    }");
  buf.writeln("    final matrix = getCompositeMatrix(");
  buf.writeln("      filterType: filterType,");
  buf.writeln("      filterIntensity: filterIntensity,");
  buf.writeln("      adjustments: adjustments,");
  buf.writeln("    );");
  buf.writeln("    return ColorFilter.matrix(matrix);");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static Paint createFilterPaint(PhotoFilterType type, [double intensity = 1.0]) {");
  buf.writeln("    return Paint()");
  buf.writeln("      ..colorFilter = createColorFilter(type, intensity)");
  buf.writeln("      ..isAntiAlias = true");
  buf.writeln("      ..filterQuality = FilterQuality.high;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static Paint createCompositeFilterPaint({");
  buf.writeln("    PhotoFilterType filterType = PhotoFilterType.original,");
  buf.writeln("    double filterIntensity = 1.0,");
  buf.writeln("    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),");
  buf.writeln("  }) {");
  buf.writeln("    return Paint()");
  buf.writeln("      ..colorFilter = createCompositeFilter(");
  buf.writeln("        filterType: filterType,");
  buf.writeln("        filterIntensity: filterIntensity,");
  buf.writeln("        adjustments: adjustments,");
  buf.writeln("      )");
  buf.writeln("      ..isAntiAlias = true");
  buf.writeln("      ..filterQuality = FilterQuality.high;");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static void drawVignette(Canvas canvas, Rect bounds, double vignette) {");
  buf.writeln("    if (vignette.abs() < 1.0) return;");
  buf.writeln("    final isDark = vignette > 0;");
  buf.writeln("    final alpha = (vignette.abs() / 100.0 * 220).clamp(0, 255).toInt();");
  buf.writeln("    final edgeColor = isDark ? Color.fromARGB(alpha, 0, 0, 0) : Color.fromARGB(alpha, 255, 255, 255);");
  buf.writeln("    final center = bounds.center;");
  buf.writeln("    final radius = math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height) / 2.0;");
  buf.writeln("    final paint = Paint()");
  buf.writeln("      ..shader = ui.Gradient.radial(");
  buf.writeln("        center,");
  buf.writeln("        radius,");
  buf.writeln("        [const Color(0x00000000), edgeColor],");
  buf.writeln("        [0.45, 1.0],");
  buf.writeln("      )");
  buf.writeln("      ..blendMode = isDark ? BlendMode.multiply : BlendMode.screen;");
  buf.writeln("    canvas.drawRect(bounds, paint);");
  buf.writeln("  }");
  buf.writeln();
  buf.writeln("  static void drawGrain(Canvas canvas, Rect bounds, double grain) {");
  buf.writeln("    if (grain < 1.0) return;");
  buf.writeln("    final random = math.Random(42);");
  buf.writeln("    final count = ((bounds.width * bounds.height) / 600.0 * (grain / 100.0)).toInt().clamp(50, 2500);");
  buf.writeln("    final alpha = (grain / 100.0 * 38).clamp(5, 50).toInt();");
  buf.writeln("    final darkPaint = Paint()");
  buf.writeln("      ..color = Colors.black.withAlpha(alpha)");
  buf.writeln("      ..strokeWidth = 1.0");
  buf.writeln("      ..style = PaintingStyle.stroke;");
  buf.writeln("    final lightPaint = Paint()");
  buf.writeln("      ..color = Colors.white.withAlpha(alpha)");
  buf.writeln("      ..strokeWidth = 1.0");
  buf.writeln("      ..style = PaintingStyle.stroke;");
  buf.writeln("    for (int i = 0; i < count; i++) {");
  buf.writeln("      final x = bounds.left + random.nextDouble() * bounds.width;");
  buf.writeln("      final y = bounds.top + random.nextDouble() * bounds.height;");
  buf.writeln("      final paint = random.nextBool() ? darkPaint : lightPaint;");
  buf.writeln("      canvas.drawPoints(ui.PointMode.points, [Offset(x, y)], paint);");
  buf.writeln("    }");
  buf.writeln("  }");
  buf.writeln("}");
  buf.writeln();

  final outFile = File('lib/engine/filter/photo_filter.dart');
  outFile.writeAsStringSync(buf.toString());
  print('Successfully generated lib/engine/filter/photo_filter.dart with ${recipes.length + classics.length} presets!');
}
