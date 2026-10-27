import '../../l10n/l10n.dart';

/// 卡片底色基调（水印设置里的「卡片底色」）。
enum WatermarkCardTone {
  auto('跟随模板'),
  white('纯白'),
  black('深黑'),
  cream('米白');

  final String label;
  const WatermarkCardTone(this.label);

  String get trLabel => L10n.tr(label);
}

/// 全局字重覆盖；auto 保留各模板原有的层级字重。
enum WatermarkFontWeight {
  auto('跟随模板'),
  regular('常规'),
  medium('中粗'),
  bold('粗体'),
  black('特粗');

  final String label;
  const WatermarkFontWeight(this.label);

  String get trLabel => L10n.tr(label);
}

/// 自定义文字对齐方式。
enum WatermarkTextAlign {
  left('左对齐'),
  center('居中'),
  right('右对齐');

  final String label;
  const WatermarkTextAlign(this.label);

  String get trLabel => L10n.tr(label);
}

/// Logo 贴图位置（保留兼容枚举）。
enum WatermarkLogoCorner {
  topLeft('左上'),
  topRight('右上'),
  bottomLeft('左下'),
  bottomRight('右下');

  final String label;
  const WatermarkLogoCorner(this.label);

  String get trLabel => L10n.tr(label);
}

/// 摄影画廊水印模板枚举（含 semi-utils / Copicseal / PicSeal / camera-watermark 经典版式）
enum WatermarkTemplate {
  none(
    'none',
    '纯调色 · 无水印',
    '保持原图尺寸与比例 · 不加任何边框与文字 · 仅导出直出胶片调色效果',
    false,
    false,
  ),
  brandClassicWhite(
    'brand_classic_white',
    '经典白边 · 品牌框',
    '致敬 Copicseal / PicSeal · 经典白底信息栏 · 左侧机型镜头 + 右侧自动匹配相机品牌标识与曝光参数',
    false,
    true,
  ),
  brandEmblemCenter(
    'brand_emblem_center',
    '徽标居中 · 展签框',
    '致敬 semi-utils · 四周留白艺术画框 · 底部居中展示相机品牌矢量徽标、曝光参数与经纬度',
    false,
    true,
  ),
  blurFloatingShadow(
    'blur_floating_shadow',
    '圆角阴影 · 品牌悬浮',
    '致敬 semi-utils / camera-watermark · 全幅高斯模糊背景 + 圆角立体阴影 + 底部悬浮品牌徽标与参数',
    true,
    false,
  ),
  minimalCornerParam(
    'minimal_corner_param',
    '右下角 · 极简参数',
    '致敬 semi-utils · 零外框不裁切 · 右下角磨砂胶囊呈现相机品牌徽标与核心曝光参数',
    true,
    false,
  ),
  retroTimestamp(
    'retro_timestamp',
    '复古胶片 · 日期戳',
    '致敬 Copicseal · 经典暖橙发光数码胶片日期戳 · 左下角极简机型与 GPS 坐标',
    false,
    false,
  ),
  geoLocationEditorial(
    'geo_location_editorial',
    '地理坐标 · 经纬度展签',
    '风光与人文旅行专属 · 突出展示拍摄经纬度 DMS 坐标、相机品牌徽标与镜头曝光参数',
    false,
    true,
  ),
  bottomBannerBlur(
    'bottom_banner_blur',
    '高斯虚化 · 纯下边框',
    '朋友圈神图 · 周围全幅高斯虚化 · 悬浮立体阴影卡片 · 仅下边框无多余白边 · 品牌与参数双列精排',
    false,
    true,
  ),
  topBottomBannerBlur(
    'top_bottom_banner_blur',
    '高斯虚化 · 上下双边框',
    '用户力荐款 · 周围全幅高斯虚化 · 悬浮柔和阴影 · 图片带精致上下留白边框 · 顶部光影微标与底部大师参数',
    false,
    true,
  ),
  darkGlassBlur(
    'dark_glass_blur',
    '高斯虚化 · 极光暗黑黑玻',
    '电影级暗房 · 周围暗调虚化氛围 · 悬浮磨砂黑玻质感卡片 · 顶部微标与高反差银白参数',
    true,
    false,
  ),
  polaroidBlur(
    'polaroid_blur',
    '高斯虚化 · 拍立得相纸',
    '周围全幅高斯虚化 · 浮动复古白卡立体相纸 · 四周留白与经典宽厚底标',
    false,
    true,
  ),
  flushMasterBar(
    'flush_master_bar',
    '大师画廊 · 纯净直出底栏',
    '满幅照片直接拼接 · 无周围虚化背景 · 底部追加德味大师信息条 · 保留照片最大展示面积',
    false,
    true,
  ),
  magazineCover(
    'magazine_cover',
    '杂志封面 · 标题压顶',
    '米白卡纸 · 顶部大标题与强调色分割线 · 底部左右分栏署名与参数 · 杂志内页感',
    false,
    true,
  ),
  gradientCaption(
    'gradient_caption',
    '渐变字幕 · 沉浸压底',
    '满幅无边框 · 底部黑色渐变遮罩 · 大标题与参数压底 · 沉浸式影院感',
    true,
    false,
  ),
  inPhotoOverlay(
    'in_photo',
    '照片内嵌 · 参数入画',
    '满幅无边框 · 机型与曝光参数直接排布在照片内部',
    false,
    false,
  ),
  minimalLine(
    'minimal_line',
    '极简细线 · 内嵌框',
    '满幅照片 · 内嵌极细线框 · 右下角极小参数 · 克制留白的高级感',
    false,
    false,
  );

  final String id;
  final String label;
  final String description;

  String get trLabel => L10n.tr(label);
  String get trDescription => L10n.tr(description);

  /// 模板默认边框颜色是否为黑底 (false = 白底)
  final bool defaultCardDark;

  /// 模板默认字体颜色是否为黑字 (false = 白字)
  final bool defaultTextDark;

  const WatermarkTemplate(
    this.id,
    this.label,
    this.description,
    this.defaultCardDark,
    this.defaultTextDark,
  );

  static WatermarkTemplate fromId(String id) {
    if (id == 'blur_card_gallery') return WatermarkTemplate.bottomBannerBlur;
    if (id == 'cinema_black') return WatermarkTemplate.darkGlassBlur;
    if (id == 'classic_white' || id == 'white_card') {
      return WatermarkTemplate.polaroidBlur;
    }
    if (id == 'pro_master_bar' ||
        id == 'exposure_grid' ||
        id == 'immersive_minimal') {
      return WatermarkTemplate.flushMasterBar;
    }
    if (id == 'film_strip') return WatermarkTemplate.bottomBannerBlur;

    return WatermarkTemplate.values.firstWhere(
      (e) => e.id == id,
      orElse: () => WatermarkTemplate.none,
    );
  }
}
