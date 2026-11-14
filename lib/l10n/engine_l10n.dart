/// Engine / Preset / Filter / Template / Credit 三语词典映射。
///
/// 供无 `BuildContext` 的模型类（[PhotoFilterType]、[BuiltinGradePreset]、
/// [WatermarkTemplate]、[CollageTemplate]、[OpenSourceCredit]）以及
/// `L10n.tr` 按当前语言实时返回 English / 简体中文 / 日本語 文案。
abstract final class EngineL10n {
  /// 根据当前语言代码 (`en` / `zh` / `ja`) 翻译给定中文词条；未命中时返回原文。
  static String tr(String zhText, String langCode) {
    if (langCode == 'zh') return zhText;
    final pair = kPhraseTable[zhText];
    if (pair == null) return zhText;
    return langCode == 'ja' ? pair.ja : pair.en;
  }

  // ==================== GPS 与水印开关多语言访问器 ====================
  static String wmShowBrandLogo(String lang) => tr('品牌标识', lang);
  static String wmShowGps(String lang) => tr('经纬度坐标', lang);
  static String gpsShootingCoord(String lang) => tr('拍摄经纬度', lang);
  static String gpsQuickBarIdle(String lang) =>
      tr('拍摄经纬度参数 · 蓝牙定位注入 (BLE 0x2007)', lang);
  static String gpsEditOrSync(String lang) => tr('修改/注入', lang);
  static String gpsSetCoords(String lang) => tr('设置坐标', lang);
  static String gpsSheetTitle(String lang) => tr('拍摄经纬度参数与 BLE 定位同步', lang);
  static String gpsSheetDesc(String lang) => tr(
      '基于 furble / nsg 协议构造 41 字节 WGS-84 定位负载 (0x2007)，支持写入尼康相机 BLE 定位特征并自动注入照片 EXIF 与水印。',
      lang);
  static String gpsLatitudeLabel(String lang) => tr('拍摄纬度 (Latitude)', lang);
  static String gpsLongitudeLabel(String lang) => tr('拍摄经度 (Longitude)', lang);
  static String gpsAltitudeLabel(String lang) => tr('海拔 (m)', lang);
  static String gpsFetchPhoneButton(String lang) => tr('获取手机当前定位', lang);
  static String gpsFetchFailedToast(String lang) =>
      tr('未能获取手机定位，请检查定位权限或手动输入坐标', lang);
  static String gpsConnectedBleCamera(String lang) => tr('已连接 BLE 相机', lang);
  static String gpsOptionalBleHint(String lang) =>
      tr('可选：连接尼康 BLE 蓝牙以向机身写入 0x2007 坐标', lang);
  static String gpsScanningBle(String lang) => tr('扫描中...', lang);
  static String gpsScanBle(String lang) => tr('扫描 BLE', lang);
  static String gpsSaveAndSyncButton(String lang) =>
      tr('保存拍摄经纬度并同步 (BLE 0x2007)', lang);
  static String gpsInvalidRangeToast(String lang) =>
      tr('请输入有效的纬度 (-90~90) 与经度 (-180~180)', lang);
  static String gpsInjectedSuccessToast(String lang) =>
      tr('已注入相机 BLE 0x2007 并设为拍摄经纬度', lang);
  static String gpsSavedSuccessPrefix(String lang) => tr('已保存拍摄经纬度', lang);

  /// 滤镜 ID -> (en, ja) 名称与简介映射。
  static ({String label, String desc})? filterById(
    String id,
    String langCode,
  ) {
    if (langCode == 'zh') return null;
    final item = kFilterTable[id];
    if (item == null) return null;
    return langCode == 'ja'
        ? (label: item.labelJa, desc: item.descJa)
        : (label: item.labelEn, desc: item.descEn);
  }

  static const Map<String, ({String en, String ja})> kPhraseTable = {
    // ==================== 开源致谢 ====================
    'USB 实时取景、AF/MF 驱动、对焦点与峰值对焦参考': (
      en: 'USB live view, AF/MF drive, focus point and focus peaking reference',
      ja: 'USB ライブビュー、AF/MF 駆動、フォーカスポイント、ピーキングの参考'
    ),
    'Wi-Fi PTP/IP 导入行为参考': (
      en: 'Wi-Fi PTP/IP import behavior reference',
      ja: 'Wi-Fi PTP/IP 取り込み動作の参考'
    ),
    'Android 遥控与传输流程参考': (
      en: 'Android remote-control and transfer flow reference',
      ja: 'Android リモート操作と転送フローの参考'
    ),
    '取景循环与拍摄落盘确认行为参考': (
      en: 'Live-view loop and capture confirmation behavior reference',
      ja: 'ライブビューループと撮影確定動作の参考'
    ),
    'PTP/IP 取景与连接边界参考': (
      en: 'PTP/IP live view and connection boundary reference',
      ja: 'PTP/IP ライブビューと接続境界の参考'
    ),
    'Z 30 影调曲线负载结构参考': (
      en: 'Z 30 tone-curve payload structure reference',
      ja: 'Z 30 トーンカーブペイロード構造の参考'
    ),
    'PTP/IP、尼康操作码与响应码表参考': (
      en: 'PTP/IP, Nikon opcode and response-code table reference',
      ja: 'PTP/IP、Nikon オペコードとレスポンスコード表の参考'
    ),

    // ==================== 水印模板与枚举 ====================
    '跟随模板': (en: 'Follow Template', ja: 'テンプレートに従う'),
    '纯白': (en: 'Pure White', ja: 'ピュアホワイト'),
    '深黑': (en: 'Deep Black', ja: 'ディープブラック'),
    '米白': (en: 'Warm Cream', ja: 'ウォームクリーム'),
    '常规': (en: 'Regular', ja: '標準'),
    '中粗': (en: 'Medium', ja: 'ミディアム'),
    '粗体': (en: 'Bold', ja: 'ボールド'),
    '特粗': (en: 'Heavy', ja: 'ヘビー'),
    '左对齐': (en: 'Left', ja: '左揃え'),
    '居中': (en: 'Center', ja: '中央揃え'),
    '右对齐': (en: 'Right', ja: '右揃え'),
    '左上': (en: 'Top Left', ja: '左上'),
    '右上': (en: 'Top Right', ja: '右上'),
    '左下': (en: 'Bottom Left', ja: '左下'),
    '右下': (en: 'Bottom Right', ja: '右下'),

    '纯调色 · 无水印': (
      en: 'Color Grade Only · No Watermark',
      ja: 'カラー調整のみ・透かしなし',
    ),
    '保持原图尺寸与比例 · 不加任何边框与文字 · 仅导出直出胶片调色效果': (
      en: 'Keep original dimensions · No frame or text · Export color grading only',
      ja: '元のサイズと比率を維持・枠や文字を追加せずカラー調整のみ書き出し',
    ),
    '照片内嵌 · 参数入画': (
      en: 'In-Photo Overlay · Embedded EXIF',
      ja: '写真内オーバーレイ・EXIF埋め込み',
    ),
    '满幅无边框 · 机型与曝光参数直接排布在照片内部': (
      en: 'Borderless full bleed · Camera model and EXIF overlaid inside the photo',
      ja: 'フチなし全面表示・カメラ名と露出情報を写真内に配置',
    ),
    '高斯虚化 · 纯下边框': (
      en: 'Gaussian Blur · Bottom Banner',
      ja: 'ガウスぼかし・下部バナー',
    ),
    '朋友圈神图 · 周围全幅高斯虚化 · 悬浮立体阴影卡片 · 仅下边框无多余白边 · 品牌与参数双列精排': (
      en: 'Ambient Gaussian blur backdrop · Floating shadow card with clean bottom EXIF banner',
      ja: '全面ガウスぼかし背景・立体シャドウカードと下部2列EXIFバナー',
    ),
    '高斯虚化 · 上下双边框': (
      en: 'Gaussian Blur · Top & Bottom Frame',
      ja: 'ガウスぼかし・上下デュアルフレーム',
    ),
    '用户力荐款 · 周围全幅高斯虚化 · 悬浮柔和阴影 · 图片带精致上下留白边框 · 顶部光影微标与底部大师参数': (
      en: 'Gaussian blur backdrop · Soft floating shadow · Top header mark and bottom master EXIF bar',
      ja: 'ガウスぼかし背景・上下余白フレーム・上部タイトルと下部マスターEXIF',
    ),
    '高斯虚化 · 极光暗黑黑玻': (
      en: 'Gaussian Blur · Dark Frosted Glass',
      ja: 'ガウスぼかし・ダークフロストガラス',
    ),
    '电影级暗房 · 周围暗调虚化氛围 · 悬浮磨砂黑玻质感卡片 · 顶部微标与高反差银白参数': (
      en: 'Darkroom mood blur · Frosted obsidian card with high-contrast silver EXIF typography',
      ja: 'シネマ暗室ムード・すりガラス調ダークカードと高コントラスト白銀EXIF',
    ),
    '高斯虚化 · 拍立得相纸': (
      en: 'Gaussian Blur · Instant Film Frame',
      ja: 'ガウスぼかし・ポラロイド風フレーム',
    ),
    '周围全幅高斯虚化 · 浮动复古白卡立体相纸 · 四周留白与经典宽厚底标': (
      en: 'Ambient blur · Floating vintage instant film paper with classic wide bottom caption',
      ja: '全面ぼかし背景・クラシックな四辺余白と幅広ボトムキャプション',
    ),
    '大师画廊 · 纯净直出底栏': (
      en: 'Master Gallery · Clean Bottom Bar',
      ja: 'マスターギャラリー・クリーンボトムバー',
    ),
    '满幅照片直接拼接 · 无周围虚化背景 · 底部追加德味大师信息条 · 保留照片最大展示面积': (
      en: 'Full-width photo with a clean gallery spec bar appended below · Maximum image area',
      ja: 'ぼかし背景なし・写真下部にギャラリー情報バーを直結し写真面積を最大化',
    ),
    '杂志封面 · 标题压顶': (
      en: 'Magazine Editorial · Top Masthead',
      ja: 'マガジン表紙・トップタイトル',
    ),
    '米白卡纸 · 顶部大标题与强调色分割线 · 底部左右分栏署名与参数 · 杂志内页感': (
      en: 'Warm cream stock · Top masthead & accent rule · Two-column editorial footer',
      ja: 'クリーム紙調・上部タイトルとアクセント線・下部2段組エディトリアル仕様',
    ),
    '渐变字幕 · 沉浸压底': (
      en: 'Gradient Caption · Cinema Lower Third',
      ja: 'グラデーション字幕・シネマ風下部',
    ),
    '满幅无边框 · 底部黑色渐变遮罩 · 大标题与参数压底 · 沉浸式影院感': (
      en: 'Borderless full frame · Subtle bottom dark gradient with cinema lower-third specs',
      ja: 'フチなし全面・下部ダークグラデーションにタイトルとパラメータを配置',
    ),
    '极简细线 · 内嵌框': (
      en: 'Minimal Hairline · Inset Frame',
      ja: 'ミニマル細線・インセットフレーム',
    ),
    '满幅照片 · 内嵌极细线框 · 右下角极小参数 · 克制留白的高级感': (
      en: 'Full photo with delicate inset hairline border and understated corner EXIF',
      ja: '写真内に極細ラインフレームと控えめな右下EXIFを配置した上品なスタイル',
    ),
    '经典白边 · 品牌框': (
      en: 'Classic White · Brand Frame',
      ja: 'クラシック白枠・ブランドフレーム',
    ),
    '致敬 Copicseal / PicSeal · 经典白底信息栏 · 左侧机型镜头 + 右侧自动匹配相机品牌标识与曝光参数': (
      en: 'Inspired by Copicseal / PicSeal · Classic white bar · Left model/lens + Right auto-matched camera brand emblem & EXIF',
      ja: 'Copicseal / PicSeal 着想・クラシック白帯・左に機材名＋右にカメラブランド徽章と露出パラメータ',
    ),
    '徽标居中 · 展签框': (
      en: 'Centered Emblem · Exhibition Plaque',
      ja: '中央エンブレム・展示キャプション枠',
    ),
    '致敬 semi-utils · 四周留白艺术画框 · 底部居中展示相机品牌矢量徽标、曝光参数与经纬度': (
      en: 'Inspired by semi-utils · Surrounded mat frame · Bottom-centered vector camera emblem, EXIF & GPS coordinates',
      ja: 'semi-utils 着想・四辺余白アートフレーム・下部中央にカメラブランド徽章とEXIF・経緯度',
    ),
    '圆角阴影 · 品牌悬浮': (
      en: 'Floating Shadow · Brand Blur',
      ja: '角丸シャドウ・ブランドフロート',
    ),
    '致敬 semi-utils / camera-watermark · 全幅高斯模糊背景 + 圆角立体阴影 + 底部悬浮品牌徽标与参数': (
      en: 'Inspired by semi-utils / camera-watermark · Full Gaussian blur + rounded shadow + floating brand emblem & EXIF',
      ja: 'semi-utils / camera-watermark 着想・全面ガウスぼかし＋角丸立体シャドウ＋下部ブランド徽章とEXIF',
    ),
    '右下角 · 极简参数': (
      en: 'Bottom-Right · Minimal Capsule',
      ja: '右下・ミニマルパラメータ',
    ),
    '致敬 semi-utils · 零外框不裁切 · 右下角磨砂胶囊呈现相机品牌徽标与核心曝光参数': (
      en: 'Inspired by semi-utils · Borderless uncropped · Bottom-right frosted capsule with camera emblem & core EXIF',
      ja: 'semi-utils 着想・トリミングなし全面写真・右下にすりガラスカプセルでブランド徽章とEXIFを表示',
    ),
    '复古胶片 · 日期戳': (
      en: 'Retro Film · Quartz Date Stamp',
      ja: 'レトロフィルム・日付スタンプ',
    ),
    '致敬 Copicseal · 经典暖橙发光数码胶片日期戳 · 左下角极简机型与 GPS 坐标': (
      en: 'Inspired by Copicseal · Classic glowing orange quartz film date stamp · Bottom-left minimal model & GPS',
      ja: 'Copicseal 着想・クラシックな暖色発光フィルム日付スタンプ・左下に機材名とGPS座標',
    ),
    '胶片齿孔 · 卷式边框': (
      en: 'Film Sprocket · Negative Strip',
      ja: 'フィルムパーフォレーション・ネガストリップ',
    ),
    '35mm 卷式负片外观 · 上下齿孔与片边编码 · 自动使用当前底片名与拍摄日期': (
      en: '35mm negative strip look · Top/bottom sprocket holes & edge codes · Uses the selected film stock and capture date',
      ja: '35mmネガストリップ調・上下パーフォレーションとエッジコード・選択フィルム名と撮影日を自動表示',
    ),
    '地理坐标 · 经纬度展签': (
      en: 'Geo Coordinates · Lat/Lon Editorial',
      ja: '地理座標・緯度経度プレート',
    ),
    '风光与人文旅行专属 · 突出展示拍摄经纬度 DMS 坐标、相机品牌徽标与镜头曝光参数': (
      en: 'Designed for travel & landscape · Highlights DMS shooting coordinates, camera brand emblem & lens EXIF',
      ja: '風景・旅スナップ専用・撮影経緯度DMS座標とカメラブランド徽章・露出パラメータを強調表示',
    ),
    '品牌标识': (en: 'Brand Emblem', ja: 'ブランド徽章'),
    '经纬度坐标': (en: 'GPS Coordinates', ja: '緯度・経度座標'),
    '拍摄经纬度': (en: 'Shooting GPS', ja: '撮影緯度・経度'),
    '拍摄经纬度参数 · 蓝牙定位注入 (BLE 0x2007)': (
      en: 'Shooting Lat/Lon · BLE Location Sync (0x2007)',
      ja: '撮影緯度経度・BLE位置情報注入 (0x2007)',
    ),
    '修改/注入': (en: 'Edit / Sync', ja: '編集・注入'),
    '设置坐标': (en: 'Set Coords', ja: '座標設定'),
    '拍摄经纬度参数与 BLE 定位同步': (
      en: 'Shooting Coordinates & BLE Location Sync',
      ja: '撮影緯度経度パラメータと BLE 位置情報同期',
    ),
    '基于 furble / nsg 协议构造 41 字节 WGS-84 定位负载 (0x2007)，支持写入尼康相机 BLE 定位特征并自动注入照片 EXIF 与水印。':
        (
      en: 'Builds 41-byte WGS-84 location payload (0x2007) per furble / nsg protocol for Nikon BLE LSS and EXIF/watermark.',
      ja: 'furble / nsg プロトコルに基づき 41 バイト WGS-84 位置ペイロード (0x2007) を生成し、ニコン BLE および EXIF・透かしに反映します。',
    ),
    '拍摄纬度 (Latitude)': (en: 'Latitude', ja: '緯度 (Latitude)'),
    '拍摄经度 (Longitude)': (en: 'Longitude', ja: '経度 (Longitude)'),
    '海拔 (m)': (en: 'Altitude (m)', ja: '標高 (m)'),
    '获取手机当前定位': (
      en: 'Use Phone GPS Location',
      ja: 'スマホの現在地を取得',
    ),
    '未能获取手机定位，请检查定位权限或手动输入坐标': (
      en: 'Could not get phone location; check permissions or enter coordinates manually',
      ja: '位置情報を取得できませんでした。権限を確認するか手動で入力してください',
    ),
    '未能获取手机定位，请检查定位权限或手动输入经纬度': (
      en: 'Could not get phone location; check permissions or enter Lat/Lon manually',
      ja: '位置情報を取得できませんでした。権限を確認するか緯度・経度を手動で入力してください',
    ),
    '已连接 BLE 相机': (en: 'Connected BLE Camera', ja: '接続済み BLE カメラ'),
    '可选：连接尼康 BLE 蓝牙以向机身写入 0x2007 坐标': (
      en: 'Optional: Connect Nikon BLE to write 0x2007 coordinates to camera body',
      ja: '任意：ニコン BLE に接続してカメラ本体へ 0x2007 座標を書き込む',
    ),
    '扫描中...': (en: 'Scanning...', ja: 'スキャン中...'),
    '扫描 BLE': (en: 'Scan BLE', ja: 'BLE スキャン'),
    '保存拍摄经纬度并同步 (BLE 0x2007)': (
      en: 'Save Coordinates & Sync (BLE 0x2007)',
      ja: '撮影座標を保存して同期 (BLE 0x2007)',
    ),
    '请输入有效的纬度 (-90~90) 与经度 (-180~180)': (
      en: 'Please enter valid latitude (-90~90) and longitude (-180~180)',
      ja: '有効な緯度 (-90〜90) と経度 (-180〜180) を入力してください',
    ),
    '已注入相机 BLE 0x2007 并设为拍摄经纬度': (
      en: 'Injected BLE 0x2007 to camera and saved shooting coordinates',
      ja: 'カメラ BLE 0x2007 へ注入し、撮影座標として保存しました',
    ),
    '已保存拍摄经纬度': (
      en: 'Saved shooting coordinates',
      ja: '撮影座標を保存しました',
    ),

    // ==================== 拼图版式 ====================
    '无': (en: 'None', ja: 'なし'),
    '上下': (en: 'Top / Bottom', ja: '上下'),
    '左右': (en: 'Left / Right', ja: '左右'),
    '上 2 : 下 1': (en: 'Top 2 : Bottom 1', ja: '上 2 : 下 1'),
    '左 2 : 右 1': (en: 'Left 2 : Right 1', ja: '左 2 : 右 1'),
    '上下中央斜切': (en: 'Center Diagonal Split', ja: '上下斜め分割'),
    '上 1 : 下 2': (en: 'Top 1 : Bottom 2', ja: '上 1 : 下 2'),
    '左 1 : 右 2': (en: 'Left 1 : Right 2', ja: '左 1 : 右 2'),
    '上 1 下 2': (en: '1 Top + 2 Bottom', ja: '上 1 下 2'),
    '上 2 下 1': (en: '2 Top + 1 Bottom', ja: '上 2 下 1'),
    '左 1 右 2': (en: '1 Left + 2 Right', ja: '左 1 右 2'),
    '三列': (en: '3 Columns', ja: '3列'),
    '上 1 下 3': (en: '1 Top + 3 Bottom', ja: '上 1 下 3'),
    '左 1 右 3': (en: '1 Left + 3 Right', ja: '左 1 右 3'),
    '四列': (en: '4 Columns', ja: '4列'),
    '上 2 下 3': (en: '2 Top + 3 Bottom', ja: '上 2 下 3'),
    '上 1 下 4': (en: '1 Top + 4 Bottom', ja: '上 1 下 4'),
    '左 1 右 4': (en: '1 Left + 4 Right', ja: '左 1 右 4'),
    '上 3 下 3': (en: '3 Top + 3 Bottom', ja: '上 3 下 3'),
    '左 2 右 4': (en: '2 Left + 4 Right', ja: '左 2 右 4'),
    '上 1 下 6': (en: '1 Top + 6 Bottom', ja: '上 1 下 6'),
    '上 3 下 4': (en: '3 Top + 4 Bottom', ja: '上 3 下 4'),
    '上 4 下 4': (en: '4 Top + 4 Bottom', ja: '上 4 下 4'),
    '两列 × 4': (en: '2 Cols × 4', ja: '2列 × 4'),

    // ==================== 内置调色预设 ====================
    '通用': (en: 'General', ja: '汎用'),
    '人像': (en: 'Portrait', ja: 'ポートレート'),
    '风光': (en: 'Landscape', ja: '風景'),
    '黑白': (en: 'Monochrome', ja: 'モノクロ'),
    '胶片': (en: 'Film', ja: 'フィルム'),
    '标准': (en: 'Standard', ja: 'スタンダード'),
    '中性还原，不改动白平衡，仅做轻微对比与锐化': (
      en: 'Neutral reproduction with subtle contrast and sharpening',
      ja: 'ホワイトバランスを維持し、わずかなコントラストとシャープネスを付与',
    ),
    '明亮通透': (en: 'Bright & Airy', ja: 'ブライト＆クリア'),
    '提亮暗部、清爽肤色，适合室内与阴天': (
      en: 'Lifted shadows and clean skin tones for indoor or overcast light',
      ja: '暗部を持ち上げ透明感のある肌色に。室内や曇天に最適',
    ),
    '浓郁': (en: 'Vivid Punch', ja: 'ビビッドパンチ'),
    '高反差高饱和，适合花卉与美食': (
      en: 'Rich contrast and saturation for florals and food',
      ja: '高コントラスト・高彩度で花や料理を鮮やかに表現',
    ),
    '柔美人像': (en: 'Soft Portrait', ja: 'ソフトポートレート'),
    '柔化肤质、提亮面部，保留自然肤色': (
      en: 'Smooth skin texture and lifted facial tones with natural warmth',
      ja: '肌を滑らかに整え、自然な血色感と明るさを保つ',
    ),
    '暖调人像': (en: 'Warm Portrait', ja: 'ウォームポートレート'),
    '暖黄肤色配柔和高光，适合室内人像': (
      en: 'Golden warm skin tones with gentle highlight roll-off',
      ja: '温かみのある肌色と柔らかなハイライトで室内ポートレートに最適',
    ),
    '高反差黑白人像': (
      en: 'Dramatic Mono Portrait',
      ja: 'ハイコントラストB&W人物',
    ),
    '去饱和加高反差，突出五官与轮廓': (
      en: 'High-contrast monochrome that sculpts facial structure',
      ja: '力強い明暗対比で表情と輪郭を際立たせるモノクロ',
    ),
    '风光浓郁': (en: 'Vivid Landscape', ja: 'ビビッド風景'),
    '通透蓝天与浓郁植被，适合大场景': (
      en: 'Deep skies and lush foliage for sweeping vistas',
      ja: '澄んだ青空と深い緑を引き立てる大風景向け設定',
    ),
    '柔和风光': (en: 'Pastel Landscape', ja: 'ソフト風景'),
    '低反差淡雅色调，适合清晨薄雾': (
      en: 'Low-contrast pastel palette suited for morning mist',
      ja: '朝霧や柔らかな光に合う低コントラストな淡い色調',
    ),
    '青橙风光': (en: 'Teal & Orange', ja: 'ティール＆オレンジ'),
    '青色阴影配橙色高光，经典电影感': (
      en: 'Cool teal shadows paired with golden highlights',
      ja: 'ティールの暗部とオレンジの明部による映画的カラー',
    ),
    '经典黑白': (en: 'Classic B&W', ja: 'クラシックモノクロ'),
    '中灰调标准黑白，通用性强': (
      en: 'Balanced mid-grey monochrome for everyday subjects',
      ja: 'バランスの取れた標準的なモノクロ階調',
    ),
    '高反差黑白': (en: 'High-Contrast B&W', ja: 'ハードモノクロ'),
    '硬朗高反差，适合建筑与街拍': (
      en: 'Crisp blacks and punchy whites for street and architecture',
      ja: '建築やストリートスナップに映える硬調モノクロ',
    ),
    '柔调黑白': (en: 'Soft Matte B&W', ja: 'ソフトモノクロ'),
    '低反差灰调，细腻柔和': (
      en: 'Gentle matte greyscale with smooth tonal transitions',
      ja: '穏やかなコントラストで豊かな中間階調を残すモノクロ',
    ),
    '柯达胶片': (en: 'Kodak Warm Film', ja: 'コダック風ウォーム'),
    '暖调反转片风格，红润肤色': (
      en: 'Warm slide-film character with rich skin tones',
      ja: '温かみのあるリバーサルフィルム調と血色の良い肌色',
    ),
    '富士胶片': (en: 'Fujifilm Simulation', ja: '富士フイルム調'),
    '低饱和绿影，经典数码模拟感': (
      en: 'Subtle cyan-green shadows and classic film simulation tone',
      ja: '控えめな彩度とクールな暗部が特徴のフィルムシミュレーション調',
    ),
    '电影质感': (en: 'Cinematic Grade', ja: 'シネマティック'),
    '高对比暗部加轻微颗粒，影视调色风格': (
      en: 'Deep cinema shadows with organic film grain',
      ja: '引き締まった暗部と繊細な粒子によるシネマグレード',
    ),
    '黑白负片': (en: 'Silver Halide Neg', ja: '銀塩モノクロネガ'),
    '反转黑白负片，低反差银盐质感': (
      en: 'Classic silver-halide negative look with fine grain',
      ja: '銀塩ネガフィルムの落ち着いた階調と粒状感',
    ),

    // ==================== 滤镜分类 ====================
    '索尼大师': (en: 'Camera Profiles', ja: 'カメラプロファイル'),
    '索尼创意外观': (en: 'Sony Creative Look', ja: 'Sony クリエイティブルック'),
    '胶片模拟': (en: 'Film Simulation', ja: 'フィルムシミュレーション'),
    '经典胶卷': (en: 'Classic Roll Film', ja: 'クラシックフィルム'),
    '彩色负片': (en: 'Color Negative & Slide', ja: 'カラーネガ・リバーサル'),
    '柯达黑白': (en: 'Kodak B&W', ja: 'コダックモノクロ'),
    '电影特色': (en: 'Cinema & Instant', ja: 'シネマ＆インスタント'),
    '电影风格': (en: 'Cinema Stock', ja: 'シネマフィルム'),
    '理光人文': (en: 'Ricoh GR Street', ja: 'Ricoh GR ストリート'),
    'GR 影像控制': (en: 'GR Image Control', ja: 'GR イメージコントロール'),
    '徕卡与哈苏': (en: 'Leica & Hasselblad', ja: 'Leica & Hasselblad'),
    '佳能与尼康': (en: 'Canon & Nikon', ja: 'Canon & Nikon'),
    '松下奥林巴斯': (en: 'Lumix & OM System', ja: 'Lumix & OM'),
    '宝丽来爱克发': (en: 'Agfa & Instant', ja: 'Agfa & インスタント'),
    '伊尔福银盐': (en: 'Ilford Silver Halide', ja: 'Ilford 銀塩モノクロ'),
    '经典精选': (en: 'Curated Looks', ja: '厳選ルック'),
    '原片与精选': (en: 'Original & Curated', ja: 'オリジナル＆厳選'),

    // ==================== Spektrafilm 底片与印相纸 ====================
    '柔和肤色与细腻高光的经典负片，宽容度极高，适合人像与日常': (
      en: 'Classic negative stock with soft skin tones and delicate highlights, extremely forgiving for portraits and daily life',
      ja: '柔らかな肌色と繊細なハイライトを持つ定番ネガ。ラチチュードが広く、ポートレートや日常に最適',
    ),
    '温暖的黄金色调，饱和适中，带有浓郁的九十年代日常气息': (
      en: 'Warm golden tones with moderate saturation and a strong 1990s everyday feel',
      ja: '暖かなゴールドトーンと程よい彩度。90年代の日常的な雰囲気を漂わせる',
    ),
    '日光型电影底片，中性白平衡、极细颗粒与柔顺的高光过渡': (
      en: 'Daylight cinema stock: neutral white balance, extremely fine grain and gentle highlight roll-off',
      ja: 'デイライトタイプの映画用フィルム。ニュートラルな色温度、極細粒子、滑らかなハイライト',
    ),
    '灯光型电影底片，冷调阴影与温暖高光形成迷人电影感': (
      en: 'Tungsten cinema stock: cool shadows and warm highlights create a captivating cinematic look',
      ja: 'タングステンタイプの映画用フィルム。冷たい影と暖かなハイライトが映画的な雰囲気を生む',
    ),
    '世界最细腻的彩色负片之一，色彩干净浓烈，风光利器': (
      en: 'One of the finest color negatives, with clean vivid color — a landscape favorite',
      ja: '世界でもっとも繊細なカラーネガの一つ。クリーンで濃密な色は風景撮影の定番',
    ),
    '经典新闻黑白底片，粗犷颗粒与扎实黑位，街头纪实首选': (
      en: 'Classic press black-and-white stock with rugged grain and solid blacks — a street documentary staple',
      ja: '定番の報道用モノクロフィルム。粗い粒子と力強い黒はストリートスナップの定番',
    ),
    '轻盈通透的日系负片，青绿色阴影与柔和肤色，空气感十足': (
      en: 'Airy Japanese negative with teal shadows and soft skin tones — full of light',
      ja: '軽やかで透明感のある国産ネガ。青緑の影と柔らかな肌色で空気感が漂う',
    ),
    '高饱和的消费级负片，翠绿与洋红浓郁，随手拍出鲜活气息': (
      en: 'High-saturation consumer negative with lush greens and magentas — vivid in every snap',
      ja: '高彩度のコンシューマー向けネガ。鮮やかな緑とマゼンタが日常を生き生きと描く',
    ),
    '风光反转片之王，极高饱和与浓郁红绿，色彩一触即发': (
      en: 'The king of landscape slide film: ultra-saturated reds and greens that leap off the frame',
      ja: '風景リバーサルの王様。極めて高い彩度と濃厚な赤緑が飛び込んでくる',
    ),
    '去除防光晕层的灯光型电影底片，霓虹与光源周围泛起标志性红光晕': (
      en: 'Tungsten cinema stock with the anti-halation layer removed — signature red halation around neon and light sources',
      ja: 'ハレーション防止層を除去したタングステン映画用フィルム。ネオンや光源の周囲に象徴的な赤いハレーション',
    ),
    '英式经典黑白底片，宽容度与颗粒平衡，扫街与暗光表现从容': (
      en: 'Classic British black-and-white stock balancing latitude and grain — at home in low light and on the street',
      ja: '英国定番のモノクロフィルム。ラチチュードと粒子のバランスが良く、暗所やスナップに強い',
    ),
    '电影正片：深沉黑位、暖调高光与浓郁色彩': (
      en: 'Motion picture print film: deep blacks, warm highlights and rich color',
      ja: '映画用プリントフィルム。深い黒、暖かなハイライト、濃厚な色',
    ),
    'Première 冲印相纸：中性偏暖、宽容自然': (
      en: 'Première photo paper: neutral-warm with natural latitude',
      ja: 'Première 印画紙。ニュートラル寄りの暖色で自然なラチチュード',
    ),
    '富士晶彩相纸：清透冷调、绿色还原准确': (
      en: 'Fuji Crystal paper: clean cool tones with accurate greens',
      ja: '富士クリスタルペーパー。澄んだ冷調で緑の再現が正確',
    ),
    '扫描直出：保留底片原始密度，不做像纸补偿': (
      en: 'Direct scan: keeps the original negative density without paper compensation',
      ja: 'ダイレクトスキャン。印画紙補正を行わずフィルム本来の濃度を保持',
    ),
    '物理胶片光谱与感光化学模拟模型参考（H&D 曲线、染料耦合、红光晕、银盐颗粒）': (
      en: 'Reference for physical film spectral and photochemical simulation (H&D curves, dye coupling, halation, silver halide grain)',
      ja: '物理フィルムの分光・感光化学シミュレーションモデルのリファレンス（H&D曲線、色素カップリング、ハレーション、銀塩粒子）',
    ),
    '物理光谱胶片引擎：H&D 密度曲线、DIR 抑制剂、红光晕、银盐颗粒与印相纸冲印（独立原生实现）': (
      en: 'Physical spectral film engine: H&D density curves, DIR couplers, halation, silver-halide grain and print paper rendering (standalone native port)',
      ja: '物理スペクトルフィルムエンジン：H&D濃度曲線、DIRカプラー、ハレーション、銀塩粒子、印画紙処理（独立ネイティブ実装）',
    ),

    // ==================== 开源致谢描述 ====================
    'Z 系列三代能力分级、PTP/IP 0x000D 探活应答、0x9431 大文件分块与取景帧头遥测解析参考': (
      en: 'Reference for Z-series capability tiers, PTP/IP 0x000D keep-alive probe, 0x9431 large-object chunking and live-view header telemetry',
      ja: 'Zシリーズの世代別ケイパビリティ、PTP/IP 0x000D 生存確認、0x9431 大容量分割転送、ライブビューヘッダ解析のリファレンス',
    ),
    '断线重连状态机：单次超时、总恢复预算、退避与重连风暴防抖策略参考': (
      en: 'Reference for the reconnect state machine: per-attempt timeout, total recovery budget, backoff and reconnect-storm debouncing',
      ja: '再接続ステートマシンのリファレンス：試行タイムアウト、復旧予算、バックオフ、再接続ストームの抑制',
    ),
    '包围曝光序列生成与参数还原、A-B 点焦点堆叠交互参考': (
      en: 'Reference for bracketing sequence generation, parameter restoration, and A-B focus stacking interaction',
      ja: 'ブラケット撮影の系列生成・パラメータ復元、A-B フォーカススタッキング操作のリファレンス',
    ),
    '断点续传状态校验思路参考（临时文件长度校正、断连边界处理），未复用其源代码': (
      en: 'Reference for resumable-download validation (temp-file length correction, disconnect boundary handling); no source code reused',
      ja: 'レジューム転送の検証方針のリファレンス（一時ファイル長の補正、切断境界の扱い）。ソースコードは流用していません',
    ),
    '图像处理、滤镜与编辑交互参考': (
      en: 'Image processing, filter pipeline, and editor interaction reference',
      ja: '画像処理・フィルター・編集UIのリファレンス',
    ),
    '色彩配方与胶片模拟数据结构参考': (
      en: 'Color recipe and film simulation data model reference',
      ja: 'カラーレシピとフィルムシミュレーション構造のリファレンス',
    ),
    '尼康设备连接流程与交互参考': (
      en: 'Nikon device connection flow and UX reference',
      ja: 'ニコン機材接続フローとUIのリファレンス',
    ),
    '未声明许可证': (en: 'No license declared', ja: 'ライセンス未記載'),
    '尼康协议与设备能力参考': (
      en: 'Nikon protocol and device capability reference',
      ja: 'ニコンプロトコルおよびデバイス機能リファレンス',
    ),
    '尼康 BLE 0x2007 经纬度负载编码与设备协议参考': (
      en: 'Nikon BLE 0x2007 GEO location payload encoding and device protocol reference',
      ja: 'ニコン BLE 0x2007 経緯度ペイロード符号化およびプロトコルリファレンス',
    ),
    '尼康 BLE 快门控制与 0x2007 经纬度定位同步参考': (
      en: 'Nikon BLE shutter control and 0x2007 GPS location sync reference',
      ja: 'ニコン BLE シャッター制御および 0x2007 GPS 位置同期リファレンス',
    ),
    '相机 EXIF 水印模板（标准框、圆角阴影、极简参数、品牌匹配与地理坐标）设计参考': (
      en: 'Camera EXIF watermark templates (classic frame, rounded shadow, minimal corner, brand matching & GPS) reference',
      ja: 'カメラ EXIF 透かしテンプレート（標準枠・角丸シャドウ・ミニマル・ブランド自動一致・GPS座標）設計リファレンス',
    ),
    '相机参数边框、经典白边、无框与复古时间戳水印排版参考': (
      en: 'Camera EXIF border, classic white frame, borderless, and retro timestamp watermark layout reference',
      ja: 'カメラパラメータ枠・クラシック白枠・フチなし・レトロ日付スタンプ透かしレイアウトのリファレンス',
    ),
    '相机设备自动识别、品牌风格水印生成与 EXIF 保留参考': (
      en: 'Camera device recognition, brand-style watermark generation, and EXIF preservation reference',
      ja: 'カメラ機材自動認識・ブランド風透かし生成・EXIF保持のリファレンス',
    ),
    '单反/微单 EXIF 合成相机水印与参数自定义交互参考': (
      en: 'DSLR/mirrorless EXIF camera watermark synthesis and custom parameter UX reference',
      ja: '一眼・ミラーレス EXIF カメラ透かし合成およびパラメータカスタムUIのリファレンス',
    ),
    'PTP/IP 与尼康操作码参考': (
      en: 'PTP/IP and Nikon vendor opcode reference',
      ja: 'PTP/IP およびニコン拡張オペコードのリファレンス',
    ),
    'PTP/IP 与 USB PTP 行为参考': (
      en: 'PTP/IP and USB Still Image transport behavior reference',
      ja: 'PTP/IP および USB PTP 通信挙動のリファレンス',
    ),
    'PTP/IP 协议实现参考': (
      en: 'PTP/IP protocol implementation reference',
      ja: 'PTP/IP プロトコル実装リファレンス',
    ),
    'PTP/IP 与 USB PTP 实现参考': (
      en: 'PTP/IP and USB PTP implementation reference',
      ja: 'PTP/IP および USB PTP 実装リファレンス',
    ),
    'Android USB OTG PTP 文件访问参考': (
      en: 'Android USB Host OTG PTP file access reference',
      ja: 'Android USB OTG PTP ファイルアクセスのリファレンス',
    ),
    '尼康 BLE 快门行为参考': (
      en: 'Nikon BLE remote shutter behavior reference',
      ja: 'ニコン BLE リモートシャッター挙動のリファレンス',
    ),
    '尼康 BLE smart-device 协议参考': (
      en: 'Nikon BLE smart-device pairing protocol reference',
      ja: 'ニコン BLE スマートデバイス通信プロトコルのリファレンス',
    ),
    '跨平台 UI 与运行时框架': (
      en: 'Cross-platform UI toolkit and runtime',
      ja: 'クロスプラットフォーム UI フレームワーク',
    ),
    'Dart 语言与运行时': (
      en: 'Dart language and runtime SDK',
      ja: 'Dart 言語およびランタイム',
    ),
    '相机 RAW 解码': (
      en: '16-bit camera RAW decoding library',
      ja: '16-bit カメラ RAW デコードライブラリ',
    ),
    '视频播放、抽帧与编辑': (
      en: 'Android Media3 video playback, frame extraction, and editing',
      ja: '動画再生・フレーム抽出・編集パイプライン',
    ),
    'Android 原生层语言与运行时': (
      en: 'Android native layer language and standard library',
      ja: 'Android ネイティブ層言語およびランタイム',
    ),
    'SVG 图形渲染': (en: 'SVG vector graphics rendering', ja: 'SVG ベクター描画'),
    '图像编码与处理': (
      en: 'Pure Dart image encoding and processing',
      ja: '画像エンコード・処理ライブラリ'
    ),
    'EXIF 元数据读写': (en: 'EXIF metadata parser', ja: 'EXIF メタデータ解析'),
    'SHA-256 与摘要算法': (
      en: 'SHA-256 and cryptographic hashing',
      ja: 'SHA-256 暗号学的ハッシュ計算'
    ),
    '国际化与日期格式化': (
      en: 'Internationalization and locale formatting',
      ja: '国際化および日付・数値フォーマット',
    ),
    '多语言本地化委托与资源加载': (
      en: 'Official Flutter localization delegates and ARB runtime support',
      ja: 'Flutter 公式ローカリゼーション基盤',
    ),
    'Material 动效转场组件库（FadeThrough / SharedAxis）': (
      en: 'Official Material motion transitions (FadeThrough / SharedAxis)',
      ja: 'Material モーショントランジション（FadeThrough / SharedAxis）',
    ),
    '平台目录定位': (
      en: 'Platform filesystem directory lookup',
      ja: 'プラットフォーム標準ディレクトリの取得',
    ),
    '视频播放支持': (en: 'Flutter video playback plugin', ja: '動画再生プラグイン'),
    '尼康 Z30 PTP/IP (0x90CC/0x90CD/0xD200) 机内优化校准读写与 NP3/NCP 解析参考': (
      en: 'Nikon Z30 PTP/IP (0x90CC/0x90CD/0xD200) Picture Control read/write & NP3/NCP codec reference',
      ja: 'ニコン Z30 PTP/IP (0x90CC/0x90CD/0xD200) ピクチャーコントロール読み書き・NP3/NCP 解析リファレンス',
    ),
    '尼康 NP3 创意色彩灵感库配方合集与分类标签参考': (
      en: 'Nikon NP3 Creative Picture Control recipe collection & category tag reference',
      ja: 'ニコン NP3 クリエイティブ色彩レシピ集およびカテゴリタグリファレンス',
    ),
    '社区共享': (
      en: 'Community Shared',
      ja: 'コミュニティ共有',
    ),
    '尼康 Flexible Color NP3 (0310) 二进制偏移与色彩混合器结构解析参考': (
      en: 'Nikon Flexible Color NP3 (0310) binary layout & Color Blender parser reference',
      ja: 'ニコン Flexible Color NP3 (0310) バイナリ構造およびカラーブレンダー解析リファレンス',
    ),
    '色彩优化近似效果预览内置免费人像、街景、花朵与生活样片素材': (
      en: 'Free portrait, street, floral & lifestyle sample photos for Picture Control preview',
      ja: 'ピクチャーコントロール近似プレビュー用ポートレート・街並み・花・日常フリー素材',
    ),
    'Pakutaso 免费素材许可': (
      en: 'Pakutaso Free Stock License',
      ja: 'ぱくたそ無料写真素材ライセンス',
    ),
    '色彩优化近似效果预览内置风光与自然样片素材致谢': (
      en: 'Free landscape & nature sample photo credits for Picture Control preview',
      ja: 'ピクチャーコントロール近似プレビュー用風景・自然サンプル素材クレジット',
    ),
    '免费样片素材许可': (
      en: 'Free Sample Media License',
      ja: '無料サンプル素材ライセンス',
    ),
    '街景': (en: 'Street', ja: 'ストリート'),
    '风景': (en: 'Landscape', ja: '風景'),
    '樱花': (en: 'Sakura', ja: '桜'),
    '夜景': (en: 'Night', ja: '夜景'),
    '大海': (en: 'Ocean', ja: '海'),
    '猫咪': (en: 'Cat', ja: '猫'),
    '美食': (en: 'Food', ja: 'グルメ'),
    '自然': (en: 'Neutral', ja: 'ニュートラル'),
    '鲜艳': (en: 'Vivid', ja: 'ビビッド'),
    '单色': (en: 'Monochrome', ja: 'モノクローム'),
    '平淡': (en: 'Flat', ja: 'フラット'),
    '灵活色彩': (en: 'Flexible Color', ja: 'フレキシブルカラー'),

    // ==================== v2.6.0 致谢明细 ====================
    'Z 系列能力分级、0x000D 探活应答、0x9431 大文件分块与取景帧头遥测参考': (
      en: 'Z-series capability tiers, 0x000D keep-alive probe, 0x9431 large-file chunking, and live-view header telemetry reference',
      ja: 'Zシリーズの世代別ケイパビリティ、0x000D 生存確認、0x9431 大容量分割転送、ライブビューヘッダ解析のリファレンス',
    ),
    '断线重连状态机：单次超时、恢复预算、退避与重连风暴防抖参考': (
      en: 'Reconnect state machine: per-attempt timeout, recovery budget, backoff and storm debouncing reference',
      ja: '再接続ステートマシン（試行タイムアウト、復旧予算、バックオフ、再接続ストーム抑制）のリファレンス',
    ),
    'Z 30 模式编码、包围曝光序列与原值还原、A-B 点焦点堆叠参考': (
      en: 'Z 30 mode encoding, bracketing sequence with value restoration, and A-B focus stacking reference',
      ja: 'Z 30 のモード値、ブラケット撮影と元値復元、A-B フォーカススタッキングのリファレンス',
    ),
    '断点续传状态校验思路参考，未复用其源代码': (
      en: 'Resumable-download validation approach reference; no source code reused',
      ja: 'レジューム転送の検証方針のリファレンス。ソースコードは流用していません',
    ),
    'Z 系列三代能力分级、0x000D 探活应答、0x9431 大文件分块、取景帧头遥测与录像控制参考': (
      en: 'Z-series generation tiers, 0x000D keep-alive probe, 0x9431 large-file chunking, live-view header telemetry, and movie-control reference',
      ja: 'Zシリーズの世代別ケイパビリティ、0x000D 生存確認、0x9431 大容量分割転送、ライブビューヘッダ解析、動画制御のリファレンス',
    ),
    'Android 端断线重连状态机与 AP 重连策略参考': (
      en: 'Android reconnect state machine and access-point reconnection strategy reference',
      ja: 'Android 側の再接続ステートマシンと AP 再接続方針のリファレンス',
    ),
    'NikonZ30 专属模式编码、App 端包围曝光与原值还原、A-B 点焦点包围状态机参考': (
      en: 'Z 30-specific mode encoding, app-side bracketing with value restoration, and A-B focus-stacking state machine reference',
      ja: 'Z 30 固有のモード値、アプリ側ブラケット撮影と元値復元、A-B フォーカススタッキングの状態機械のリファレンス',
    ),
    '断点续传状态校验思路参考': (
      en: 'Reference for resumable-download state validation',
      ja: 'レジューム転送の状態検証方針のリファレンス',
    ),
    '尼康 BLE 快门控制、0x2007 经纬度同步，以及 SnapBridge BLE Blowfish 握手与 Wi-Fi 唤醒协议参考': (
      en: 'Nikon BLE shutter control, 0x2007 geotag sync, plus SnapBridge BLE Blowfish handshake and Wi-Fi wake protocol reference',
      ja: 'ニコン BLE シャッター制御、0x2007 位置情報同期、SnapBridge BLE Blowfish ハンドシェイクと Wi-Fi 起動プロトコルのリファレンス',
    ),
    'PTP/IP、尼康操作码与响应码表参考，含 0xD0A4 禁录位掩码与 0xC108 封盘事件': (
      en: 'PTP/IP and Nikon opcode/response tables, including the 0xD0A4 recording-prohibition mask and the 0xC108 finalize event',
      ja: 'PTP/IP とニコンの操作コード・応答コード表。0xD0A4 録画禁止ビットマスクと 0xC108 書き込み完了イベントを含む',
    ),
    '极高（核心参考）': (en: 'Very high (core reference)', ja: '非常に高い（中核リファレンス）'),
    '很高': (en: 'High', ja: '高い'),
    '中（实验性参考）': (en: 'Medium (experimental)', ja: '中（実験的）'),
    '高（协议规范）': (en: 'High (protocol spec)', ja: '高い（プロトコル仕様）'),
    '中（策略参考）': (en: 'Medium (strategy)', ja: '中（方針の参考）'),
    'Apache-2.0 兼容，可按 Dart 习惯重构移植并署名致谢': (
      en: 'Apache-2.0 compatible; may be restructured and ported to Dart with attribution',
      ja: 'Apache-2.0 互換。Dart 向けに再構成して移植でき、出典を明記します',
    ),
    'Apache-2.0 兼容': (en: 'Apache-2.0 compatible', ja: 'Apache-2.0 互換'),
    'MIT 兼容，可直接参考逻辑结构并署名': (
      en: 'MIT compatible; logic may be referenced directly with attribution',
      ja: 'MIT 互換。ロジックを参照し出典を明記できます',
    ),
    'GPL-3.0：仅借鉴状态与边界校验思路，禁止复制 Python 代码': (
      en: 'GPL-3.0: only the state and boundary-checking ideas are borrowed; no Python code is copied',
      ja: 'GPL-3.0：状態と境界検証の発想のみ参考にし、Python コードは複製していません',
    ),
    'MIT 兼容；BLE 唤醒在 UI 中标注为实验性开关': (
      en: 'MIT compatible; BLE wake-up is labelled experimental in the UI',
      ja: 'MIT 互換。BLE 起動は UI 上で実験的機能として明示しています',
    ),
    'LGPL-2.1：仅参考协议常数与交互顺序，禁止复制 C 代码': (
      en: 'LGPL-2.1: only protocol constants and command ordering are referenced; no C code is copied',
      ja: 'LGPL-2.1：プロトコル定数とコマンド順序のみ参考にし、C コードは複製していません',
    ),
  };

  static const Map<String,
          ({String labelEn, String labelJa, String descEn, String descJa})>
      kFilterTable = {
    'sonyFactoryST': (
      labelEn: 'Factory Standard',
      labelJa: 'ファクトリー ST',
      descEn: 'Neutral factory standard color reproduction',
      descJa: 'ニュートラルで忠実な標準色再現',
    ),
    'sonyPT': (
      labelEn: 'Sony PT (Portrait)',
      labelJa: 'Sony PT（ポートレート）',
      descEn: 'Smooth skin rendition with luminous portrait gradation',
      descJa: '滑らかな肌色表現と透明感のあるポートレート階調',
    ),
    'sonyNT': (
      labelEn: 'Sony NT (Neutral)',
      labelJa: 'Sony NT（ニュートラル）',
      descEn: 'Low-contrast smooth curve preserving dynamic range',
      descJa: '低コントラストで広いダイナミックレンジを保持',
    ),
    'sonyVV': (
      labelEn: 'Sony VV (Vivid)',
      labelJa: 'Sony VV（ビビッド）',
      descEn: 'Rich primary colors for landscapes and vibrant scenes',
      descJa: '風景や色彩豊かなシーン向けの鮮やかな発色',
    ),
    'sonyVV2': (
      labelEn: 'Sony VV2',
      labelJa: 'Sony VV2',
      descEn: 'High-impact vibrant clarity under bright sunlight',
      descJa: '晴天の下で際立つ高彩度・高明瞭ルック',
    ),
    'sonyFL': (
      labelEn: 'Sony FL (Film)',
      labelJa: 'Sony FL（フィルム調）',
      descEn: 'Warm amber highlights with cool teal-blue shadows',
      descJa: '暖かみのあるアンバー明部とクールな青緑暗部のフィルム調',
    ),
    'sonyIN': (
      labelEn: 'Sony IN (Instant)',
      labelJa: 'Sony IN（インスタント）',
      descEn: 'Matte atmospheric curve with subtle magenta tint',
      descJa: 'マットな質感とほのかなマゼンタによる情緒的トーン',
    ),
    'sonySH': (
      labelEn: 'Sony SH (Soft Highkey)',
      labelJa: 'Sony SH（ソフトハイキー）',
      descEn: 'Airy high-key palette with cool luminous highlights',
      descJa: '明るく透き通るようなソフトハイキー表現',
    ),
    'fujiProvia': (
      labelEn: 'PROVIA Standard',
      labelJa: 'PROVIA スタンダード',
      descEn: 'All-round benchmark with balanced Fujifilm color',
      descJa: '自然でバランスの取れた富士フイルムの標準発色',
    ),
    'fujiVelvia': (
      labelEn: 'Velvia Vivid',
      labelJa: 'Velvia ビビッド',
      descEn: 'Landscape icon with ultra-rich saturation and contrast',
      descJa: '風景写真の王道・超高彩度と力強いコントラスト',
    ),
    'fujiAstia': (
      labelEn: 'ASTIA Soft',
      labelJa: 'ASTIA ソフト',
      descEn: 'Refined portrait tone with gentle highlight roll-off',
      descJa: '柔らかなハイライトと温かみのある肌色トーン',
    ),
    'classicChrome': (
      labelEn: 'Classic Chrome',
      labelJa: 'クラシッククローム',
      descEn: 'Documentary legend with muted colors and crisp shadows',
      descJa: '落ち着いた彩度と引き締まった暗部によるドキュメンタリー調',
    ),
    'fujiClassicNegative': (
      labelEn: 'Classic Neg.',
      labelJa: 'クラシックネガ',
      descEn: 'Superia heritage with cyan-green shadows and warm reds',
      descJa: 'シアン寄りの暗部とメリハリのある懐かしいスナップ調',
    ),
    'fujiNostalgicNeg': (
      labelEn: 'Nostalgic Neg.',
      labelJa: 'ノスタルジックネガ',
      descEn: 'Amber-gold highlights inspired by 1970s New Color photography',
      descJa: 'アンバーがかった明部と深みのある暗部のニューカラー調',
    ),
    'fujiRealaAce': (
      labelEn: 'REALA ACE',
      labelJa: 'REALA ACE',
      descEn: 'True-to-life color with crisp modern tonal separation',
      descJa: '忠実な色再現と適度に引き締まった現代的トーン',
    ),
    'fujiProNegStd': (
      labelEn: 'PRO Neg. Std',
      labelJa: 'PRO Neg. Std',
      descEn: 'Studio portrait neutrality with ultra-smooth gradation',
      descJa: 'スタジオポートレート向けの滑らかな階調表現',
    ),
    'fujiProNegHi': (
      labelEn: 'PRO Neg. Hi',
      labelJa: 'PRO Neg. Hi',
      descEn: 'Outdoor portrait look with sculpted shadow depth',
      descJa: '肌色を保ちつつ陰影に立体感を与えるポートレート調',
    ),
    'fujiEterna': (
      labelEn: 'ETERNA Cinema',
      labelJa: 'ETERNA シネマ',
      descEn:
          'Motion-picture stock with understated saturation and wide latitude',
      descJa: '映画用フィルムの落ち着いた彩度と広い暗部階調',
    ),
    'fujiEternaBleach': (
      labelEn: 'ETERNA Bleach Bypass',
      labelJa: 'ETERNA ブリーチバイパス',
      descEn: 'Silver-retention look with metallic contrast and low saturation',
      descJa: '銀残し処理による低彩度・高コントラストの重厚な表現',
    ),
    'fujiAcros': (
      labelEn: 'ACROS Monochrome',
      labelJa: 'ACROS モノクロ',
      descEn: 'Fine-grain silver monochrome with rich micro-contrast',
      descJa: '緻密な粒状感と豊かな階調を持つモノクローム',
    ),
    'fujiAcrosYe': (
      labelEn: 'ACROS +Ye (Yellow)',
      labelJa: 'ACROS +Ye（黄フィルター）',
      descEn: 'Yellow filter darkens skies and accentuates clouds',
      descJa: '空を少し落とし雲の立体感を引き出す黄フィルター効果',
    ),
    'fujiAcrosR': (
      labelEn: 'ACROS +R (Red)',
      labelJa: 'ACROS +R（赤フィルター）',
      descEn: 'Red filter delivers dramatic high-contrast monochrome skies',
      descJa: '強いコントラストでドラマチックに描く赤フィルター効果',
    ),
    'fujiAcrosG': (
      labelEn: 'ACROS +G (Green)',
      labelJa: 'ACROS +G（緑フィルター）',
      descEn: 'Green filter flatters lip/skin tones and foliage texture',
      descJa: '肌や唇の階調、植物の質感を整える緑フィルター効果',
    ),
    'fujiSepia': (
      labelEn: 'Fujifilm Sepia',
      labelJa: 'フジ セピア',
      descEn: 'Warm antique silver-brown archival tone',
      descJa: 'ノスタルジックな温かみのあるセピア調',
    ),
    'fujiPro400H': (
      labelEn: 'Fujifilm Pro 400H',
      labelJa: 'Fujifilm Pro 400H',
      descEn: 'Airy cyan-green pastels with delicate blush highlights',
      descJa: '透明感のある青緑と柔らかなハイライトの定番フィルム',
    ),
    'fujiFortia50': (
      labelEn: 'Fujifilm Fortia 50',
      labelJa: 'Fujifilm Fortia 50',
      descEn: 'Limited-edition slide stock with ultra-vivid seasonal colors',
      descJa: '季節の色彩を強烈に描き出す高彩度リバーサル調',
    ),
    'fujiSuperia400': (
      labelEn: 'Fujifilm Superia 400',
      labelJa: 'Fujifilm Superia 400',
      descEn: 'Everyday negative stock with cool shadows and warm reds',
      descJa: '日常スナップに馴染む青緑の暗部と温かな赤み',
    ),
    'fujiC200': (
      labelEn: 'Fujifilm C200',
      labelJa: 'Fujifilm C200',
      descEn: 'Natural daylight negative with a subtle cool-green cast',
      descJa: '自然光で素直に発色するデイライトフィルム調',
    ),
    'fujiNatura1600': (
      labelEn: 'Fujifilm Natura 1600',
      labelJa: 'Fujifilm Natura 1600',
      descEn: 'High-speed ambient light stock with warm intimate grain',
      descJa: '暗所や室内の雰囲気を温かく残す高感度フィルム調',
    ),
    'kodakPortra160': (
      labelEn: 'Kodak Portra 160',
      labelJa: 'Kodak Portra 160',
      descEn: 'Ultra-fine grain and silky low-contrast skin tones',
      descJa: '極めて滑らかな肌色と穏やかなコントラスト',
    ),
    'kodakPortra400': (
      labelEn: 'Kodak Portra 400',
      labelJa: 'Kodak Portra 400',
      descEn: 'Golden-hour warmth and iconic natural skin rendition',
      descJa: '黄金色の暖かみと美しい肌色を持つ王道ポートレートネガ',
    ),
    'kodakPortra800': (
      labelEn: 'Kodak Portra 800',
      labelJa: 'Kodak Portra 800',
      descEn: 'High-speed warm negative with rich shadow latitude',
      descJa: '高感度ならではの豊かな粒子と温かみのある発色',
    ),
    'kodakGold200': (
      labelEn: 'Kodak Gold 200',
      labelJa: 'Kodak Gold 200',
      descEn: 'Sun-drenched golden nostalgia for everyday memories',
      descJa: '陽だまりのようなゴールデンイエローのレトロトーン',
    ),
    'kodakUltraMax400': (
      labelEn: 'Kodak UltraMax 400',
      labelJa: 'Kodak UltraMax 400',
      descEn: 'Punchy primary colors and crisp cobalt skies',
      descJa: '鮮やかな三原色と澄んだ青空が映えるスナップ調',
    ),
    'kodakColorPlus200': (
      labelEn: 'Kodak ColorPlus 200',
      labelJa: 'Kodak ColorPlus 200',
      descEn: 'Classic warm yellow cast with vintage snapshot charm',
      descJa: '懐かしい黄色みを帯びたクラシックネガ調',
    ),
    'kodakEktar100': (
      labelEn: 'Kodak Ektar 100',
      labelJa: 'Kodak Ektar 100',
      descEn: 'Ultra-fine grain negative with slide-like landscape saturation',
      descJa: '超微粒子とリバーサル並みの高彩度を持つ風景向けネガ',
    ),
    'kodakE100': (
      labelEn: 'Kodak Ektachrome E100',
      labelJa: 'Kodak Ektachrome E100',
      descEn: 'Legendary reversal slide film with pure blues and clean whites',
      descJa: '澄み切ったブルーと純白のハイライトが際立つリバーサル調',
    ),
    'kodachrome64': (
      labelEn: 'Kodachrome 64',
      labelJa: 'Kodachrome 64',
      descEn: 'Archival documentary warmth with deep reds and golden yellows',
      descJa: '深みのある赤と黄色が印象的な不朽のドキュメンタリー調',
    ),
    'kodakVision3500T': (
      labelEn: 'Kodak Vision3 500T',
      labelJa: 'Kodak Vision3 500T',
      descEn: 'Hollywood tungsten cinema stock with cool daylight balance',
      descJa: 'ハリウッド映画用タングステンフィルムのクールな陰影',
    ),
    'kodakVision200T': (
      labelEn: 'Kodak Vision 200T (Pastel)',
      labelJa: 'Kodak Vision 200T（パステル）',
      descEn: 'Storybook warm pastel palette with low-contrast highlights',
      descJa: '絵本のように柔らかなパステルウォームトーン',
    ),
    'kodakTriX400': (
      labelEn: 'Kodak Tri-X 400',
      labelJa: 'Kodak Tri-X 400',
      descEn: 'Photojournalism standard with classic grit and silver grain',
      descJa: '報道写真の礎となった力強いコントラストと銀塩粒子',
    ),
    'kodakTMax': (
      labelEn: 'Kodak T-Max',
      labelJa: 'Kodak T-Max',
      descEn: 'Tabular-grain emulsion with sharp clarity and deep blacks',
      descJa: 'T粒子技術による高いシャープネスと深い黒階調',
    ),
    'kodakTriX1600': (
      labelEn: 'Kodak Tri-X 1600 (Pushed)',
      labelJa: 'Kodak Tri-X 1600（増感）',
      descEn: 'Pushed darkroom development with bold grain and street contrast',
      descJa: '増感現像による粗い粒子と強烈なストリートコントラスト',
    ),
    'cineStill50D': (
      labelEn: 'CineStill 50D',
      labelJa: 'CineStill 50D',
      descEn: 'Remjet-free daylight cinema film with velvety cool highlights',
      descJa: 'デイライト映画フィルム特有の滑らかなクールハイライト',
    ),
    'cineStill800T': (
      labelEn: 'CineStill 800T',
      labelJa: 'CineStill 800T',
      descEn: 'Neon night cinema stock with cool teal base and warm halation',
      descJa: '夜景ネオンに映えるクールな青緑基調とハイライトの滲み',
    ),
    'classicCinema': (
      labelEn: 'Classic Cinema',
      labelJa: 'クラシックシネマ',
      descEn:
          'Widescreen narrative grade with warm highlights and deep shadows',
      descJa: '映画的な暖色ハイライトと奥行きのある暗部表現',
    ),
    'rec709Video': (
      labelEn: 'Rec.709 Low Contrast',
      labelJa: 'Rec.709（低コントラスト）',
      descEn: 'Broadcast-style gentle curve preserving midtone detail',
      descJa: '中間調を豊かに残す放送基準の穏やかなトーン',
    ),
    'ricohGRPositive': (
      labelEn: 'GR Positive Film',
      labelJa: 'GR ポジフィルム調',
      descEn: 'Signature street-snap punch with deep blacks and vivid color',
      descJa: 'ストリートスナップで映える高コントラスト・高彩度ポジ調',
    ),
    'ricohGRNegative': (
      labelEn: 'GR Negative Film',
      labelJa: 'GR ネガフィルム調',
      descEn: 'Airy documentary negative with cool-green shadow nuance',
      descJa: '爽やかな空気感と落ち着いた発色のネガフィルム調',
    ),
    'ricohGRBleach': (
      labelEn: 'GR Bleach Bypass',
      labelJa: 'GR ブリーチバイパス',
      descEn: 'Metallic steely tone with desaturated high contrast',
      descJa: '金属的な質感と渋い低彩度ハイコントラスト',
    ),
    'ricohGRRetro': (
      labelEn: 'GR Retro',
      labelJa: 'GR レトロ',
      descEn: 'Nostalgic warm lens cast with vignette and grain',
      descJa: '周辺減光と暖かな色あせ感を持つノスタルジック調',
    ),
    'ricohGRCross': (
      labelEn: 'GR Cross Process',
      labelJa: 'GR クロスプロセス',
      descEn: 'Experimental magenta-cyan shift from C-41/E-6 cross processing',
      descJa: '幻想的な色シフトを生み出すクロスプロセス調',
    ),
    'ricohGRHiBw': (
      labelEn: 'GR Hi-Contrast B&W',
      labelJa: 'GR ハイコントラスト白黒',
      descEn: 'Daido Moriyama-inspired gritty stark black and white',
      descJa: '粗粒子と強烈な明暗で切り取るストリート白黒',
    ),
    'ricohGRHardBw': (
      labelEn: 'GR Hard Monotone',
      labelJa: 'GR ハードモノトーン',
      descEn: 'Sculpted architectural monochrome with crisp edge contrast',
      descJa: '建築や光と影のラインを鋭く描くハードモノトーン',
    ),
    'ricohGRSoftBw': (
      labelEn: 'GR Soft Monotone',
      labelJa: 'GR ソフトモノトーン',
      descEn: 'Calm mid-grey monochrome with gentle transitions',
      descJa: '穏やかな中間階調で静けさを描くソフトモノトーン',
    ),
    'leicaContemporary': (
      labelEn: 'Leica Contemporary',
      labelJa: 'Leica コンテンポラリー',
      descEn: 'Grounded modern rangefinder color with dense shadows',
      descJa: '重厚な暗部と密度の高い現代レンジファインダー調',
    ),
    'leicaClassic': (
      labelEn: 'Leica Classic',
      labelJa: 'Leica クラシック',
      descEn: 'Warm organic rendering with three-dimensional micro-contrast',
      descJa: '微暖色の立体感と空気感を切り取るクラシック調',
    ),
    'leicaEternal': (
      labelEn: 'Leica Eternal',
      labelJa: 'Leica エターナル',
      descEn: 'Restrained timeless palette with wide tonal latitude',
      descJa: '彩度を抑えた落ち着きと深い階調を持つ叙事詩的トーン',
    ),
    'leicaMonochrome': (
      labelEn: 'Leica Monochrom',
      labelJa: 'Leica モノクローム',
      descEn: 'Pure rangefinder silver grayscale with deep tonal nuance',
      descJa: '純粋な銀塩の深みと繊細なグレー階調',
    ),
    'hasselbladHNCS': (
      labelEn: 'Hasselblad HNCS',
      labelJa: 'Hasselblad HNCS',
      descEn: 'Natural Color Solution with smooth medium-format transitions',
      descJa: '中判カメラのような自然で滑らかな色彩グラデーション',
    ),
    'canonStandard': (
      labelEn: 'Canon Standard',
      labelJa: 'Canon スタンダード',
      descEn: 'Pleasing warm-magenta highlights and vibrant clarity',
      descJa: '華やかで血色感の良いキヤノン標準トーン',
    ),
    'canonPortrait': (
      labelEn: 'Canon Portrait',
      labelJa: 'Canon ポートレート',
      descEn: 'Rosy luminous skin tones with gentle midtone softness',
      descJa: '透明感とほんのり桜色の肌色を引き出すポートレート調',
    ),
    'canonFaithful': (
      labelEn: 'Canon Faithful',
      labelJa: 'Canon 忠実設定',
      descEn: 'Colorimetric daylight accuracy for studio reproduction',
      descJa: '自然光下の被写体の色を忠実に再現する設定',
    ),
    'nikonFlat': (
      labelEn: 'Nikon Flat',
      labelJa: 'Nikon フラット',
      descEn: 'Maximum dynamic range curve protecting highlights and shadows',
      descJa: '明暗両端の情報を最大限に残すフラットカーブ',
    ),
    'nikonVivid': (
      labelEn: 'Nikon Vivid',
      labelJa: 'Nikon ビビッド',
      descEn: 'Crisp Nikon landscape punch with golden warmth and clear skies',
      descJa: '澄んだ空と鮮やかな風景をくっきり描くニコンビビッド',
    ),
    'panaLMonochromeD': (
      labelEn: 'Lumix L.Monochrome D',
      labelJa: 'Lumix L.モノクローム D',
      descEn: 'Dynamic monochrome with rich highlights and anchored blacks',
      descJa: '力強いハイライトと引き締まった黒を持つダイナミック白黒',
    ),
    'panaLClassicNeo': (
      labelEn: 'Lumix L.Classic Neo',
      labelJa: 'Lumix L.クラシックネオ',
      descEn: 'Nostalgic warm-yellow film softness',
      descJa: 'ノスタルジックで柔らかな暖色フィルムトーン',
    ),
    'olympusPopArt': (
      labelEn: 'Olympus Pop Art',
      labelJa: 'Olympus ポップアート',
      descEn: 'Signature deep Olympus blue and bold saturated colors',
      descJa: 'オリンパスブルーと濃厚な色彩が弾けるポップアート調',
    ),
    'olympusPaleLight': (
      labelEn: 'Olympus Pale & Light',
      labelJa: 'Olympus ペール＆ライト',
      descEn: 'Airy pastel high-key look with lifted shadows',
      descJa: '淡く軽やかなパステルハイキートーン',
    ),
    'agfaVista200': (
      labelEn: 'Agfa Vista 200',
      labelJa: 'Agfa Vista 200',
      descEn:
          'Classic European red-label punch with warm reds and cool shadows',
      descJa: '印象的な赤の発色と深みのあるクールシャドウ',
    ),
    'agfaUltra100': (
      labelEn: 'Agfa Ultra 100',
      labelJa: 'Agfa Ultra 100',
      descEn: 'Ultra-saturated European negative for vivid landscapes',
      descJa: '極めて高い彩度で風景を鮮烈に描くフィルム調',
    ),
    'polaroidInstax': (
      labelEn: 'Instant Film / Instax',
      labelJa: 'チェキ / ポラロイド調',
      descEn: 'Faded milky blacks and warm instant-film vignette',
      descJa: 'インスタントフィルム特有フェード感と温かな周辺減光',
    ),
    'ilfordHP5': (
      labelEn: 'Ilford HP5 Plus',
      labelJa: 'Ilford HP5 Plus',
      descEn:
          'British silver-halide classic with wide latitude and organic grain',
      descJa: '広いラティチュードと自然な粒子を持つ英国銀塩の定番',
    ),
    'ilfordFP4': (
      labelEn: 'Ilford FP4 Plus',
      labelJa: 'Ilford FP4 Plus',
      descEn: 'Medium-speed fine-grain monochrome with crisp tonal lines',
      descJa: '微粒子と明快なコントラストを備えた中感度モノクロ',
    ),
    'ilfordDelta100': (
      labelEn: 'Ilford Delta 100',
      labelJa: 'Ilford Delta 100',
      descEn: 'Core-shell crystal emulsion with razor-sharp grayscale detail',
      descJa: '緻密なディテールと滑らかな階調を両立したモノクロ',
    ),
    'ilfordDelta3200': (
      labelEn: 'Ilford Delta 3200',
      labelJa: 'Ilford Delta 3200',
      descEn: 'Low-light documentary monochrome with expressive grain',
      descJa: '夜間の光と影をドラマチックに捉える超高感度モノクロ',
    ),
    'ilfordPanF50': (
      labelEn: 'Ilford Pan F Plus 50',
      labelJa: 'Ilford Pan F Plus 50',
      descEn: 'Ultra-fine grain with silky smooth deep blacks',
      descJa: 'シルクのように滑らかな階調と深い黒を持つ超微粒子白黒',
    ),
    'original': (
      labelEn: 'Original (Unmodified)',
      labelJa: 'オリジナル（無補正）',
      descEn: 'Native camera color without filter adjustments',
      descJa: 'カメラ本来の色味をそのまま出力',
    ),
    'fairSkin': (
      labelEn: 'Cool Porcelain Portrait',
      labelJa: 'クリア美肌ポートレート',
      descEn: 'Reduces yellow cast for luminous, clean portrait skin tones',
      descJa: '黄みを抑え、透明感のある明るい肌色を表現',
    ),
    'warmPortrait': (
      labelEn: 'Golden Hour Warmth',
      labelJa: 'ゴールデンアワーウォーム',
      descEn: 'Warm sunset highlights paired with gentle cool shadows',
      descJa: '夕暮れの温かな光と柔らかな陰影を描くトーン',
    ),
    'japanesePure': (
      labelEn: 'Airy Street',
      labelJa: 'エアリーストリート',
      descEn: 'High-key airy brightness with breathable cyan-blue shadows',
      descJa: '明るく風通しの良いハイキーと爽やかな青みの暗部',
    ),
    'shinkaiAnime': (
      labelEn: 'Anime Sky & Foliage',
      labelJa: 'アニメ調スカイ＆グリーン',
      descEn: 'Vibrant cerulean skies and luminous emerald foliage',
      descJa: '澄み渡る青空と輝く新緑を強調するアニメーション調',
    ),
    'cityNight': (
      labelEn: 'Cyber City Night',
      labelJa: 'シティナイト',
      descEn: 'Deep midnight blues with controlled neon highlights',
      descJa: '深い群青の夜空とネオンの白飛びを抑えた夜景トーン',
    ),
    'forestGreen': (
      labelEn: 'Forest Emerald',
      labelJa: 'フォレストグリーン',
      descEn:
          'Clean emerald greens with reduced yellow cast and atmospheric depth',
      descJa: '黄色みを抑えた深いエメラルドグリーンと透明感',
    ),
    'floralBotanical': (
      labelEn: 'Botanical Macro',
      labelJa: 'ボタニカル・花木',
      descEn: 'Natural vibrance that protects delicate petal gradation',
      descJa: '花びらの繊細な階調を守りながら自然に彩度を高める',
    ),
    'clearSky': (
      labelEn: 'Azure Sky',
      labelJa: 'クリアスカイ',
      descEn: 'Enhances pure sky blues and cloud dimensionality',
      descJa: '晴天の澄んだ青と雲の立体感を引き立てる風景調',
    ),
    'cinematic': (
      labelEn: 'Cinema Teal & Amber',
      labelJa: 'シネマ・ティール＆アンバー',
      descEn: 'Widescreen narrative contrast with teal-orange color separation',
      descJa: '広い階調とティール＆アンバーの映画的カラー',
    ),
  };

  // ==================== 传输与保活后台文案 ====================
  static String transferKeepAliveTitle(String langCode) => switch (langCode) {
        'ja' => 'Zync 転送中',
        'en' => 'Zync Transferring',
        _ => 'Zync 正在传输',
      };

  static String powerPausePowerSave(String langCode) => switch (langCode) {
        'ja' => '省電力モードが有効なため、新規転送を一時停止しました',
        'en' => 'Battery Saver is active; new transfers are paused',
        _ => '手机已开启省电模式，已暂停新传输任务',
      };

  static String powerPausePhoneLow(String langCode, int level, int threshold) =>
      switch (langCode) {
        'ja' => '端末のバッテリー残量が低下しています ($level% ≤ $threshold%)。新規転送を一時停止しました',
        'en' =>
          'Phone battery low ($level% ≤ $threshold%); new transfers paused',
        _ => '手机电量较低 ($level% ≤ $threshold%)，已暂停新传输任务',
      };

  static String powerPauseCameraLow(
          String langCode, int level, int threshold) =>
      switch (langCode) {
        'ja' => 'カメラのバッテリー残量が低下しています ($level% ≤ $threshold%)。新規転送を一時停止しました',
        'en' =>
          'Camera battery low ($level% ≤ $threshold%); new transfers paused',
        _ => '相机电量较低 ($level% ≤ $threshold%)，已暂停新传输任务',
      };

  static String transferRetryNotice(
          String langCode, int delaySec, int retryCount) =>
      switch (langCode) {
        'ja' => '転送中断、$delaySec秒後に再試行します ($retryCount回目)...',
        'en' =>
          'Transfer interrupted; retrying (#$retryCount) in ${delaySec}s...',
        _ => '下载遇阻，$delaySec秒后第$retryCount次重试...',
      };

  // ==================== v2.6.0 断线重连 ====================

  /// 队列项：等待重连后续传。
  static String transferWaitingReconnect(String langCode) => switch (langCode) {
        'ja' => '再接続後に自動で続きから転送します',
        'en' => 'Will resume automatically after reconnecting',
        _ => '等待重连后自动续传',
      };

  /// 传输中心顶部横幅：正在恢复连接。
  static String recoveryBanner(String langCode, String phase, int attempt) =>
      switch (langCode) {
        'ja' => 'カメラとの接続を復元中… $phase (試行 $attempt)',
        'en' => 'Restoring camera connection… $phase (attempt $attempt)',
        _ => '正在恢复相机连接… $phase（第 $attempt 次）',
      };

  /// 恢复阶段名。
  static String recoveryPhase(String langCode, String phase) => switch (phase) {
        'waitingForNetwork' => switch (langCode) {
            'ja' => 'ネットワーク待機',
            'en' => 'waiting for network',
            _ => '等待网络',
          },
        'probing' => switch (langCode) {
            'ja' => 'ポート確認',
            'en' => 'probing port',
            _ => '探测端口',
          },
        'reconnecting' => switch (langCode) {
            'ja' => '再接続中',
            'en' => 'reconnecting',
            _ => '重连中',
          },
        'restoringSession' => switch (langCode) {
            'ja' => 'セッション復元',
            'en' => 'restoring session',
            _ => '恢复会话',
          },
        _ => phase,
      };

  /// 自动恢复最终失败。
  static String recoveryExhausted(String langCode, String error) =>
      switch (langCode) {
        'ja' => '自動再接続を断念しました。カメラの Wi-Fi を確認してください ${error.isEmpty ? '' : '($error)'}',
        'en' =>
          'Automatic reconnect gave up. Check the camera Wi-Fi. ${error.isEmpty ? '' : '($error)'}',
        _ => '自动重连已停止，请检查相机 Wi-Fi${error.isEmpty ? '' : '（$error）'}',
      };

  /// 重连成功提示。
  static String recoverySucceeded(String langCode) => switch (langCode) {
        'ja' => 'カメラに再接続しました',
        'en' => 'Reconnected to the camera',
        _ => '已重新连接相机',
      };

  /// 重连后文件已不在相机上。
  static String transferObjectGone(String langCode) => switch (langCode) {
        'ja' => '再接続後、このファイルはカメラ内に見つかりません',
        'en' => 'File is no longer on the camera after reconnecting',
        _ => '重连后相机端已找不到该文件',
      };

  // ==================== v2.6.0 录像控制 ====================

  static String capturePhotoMode(String langCode) => switch (langCode) {
        'ja' => '静止画',
        'en' => 'Photo',
        _ => '拍照',
      };

  static String captureVideoMode(String langCode) => switch (langCode) {
        'ja' => '動画',
        'en' => 'Video',
        _ => '录像',
      };

  static String movieRecording(String langCode) => switch (langCode) {
        'ja' => '録画中',
        'en' => 'REC',
        _ => '录制中',
      };

  static String movieStartingHint(String langCode) => switch (langCode) {
        'ja' => '録画を開始しています…',
        'en' => 'Starting recording…',
        _ => '正在开始录制…',
      };

  static String movieFinalizingHint(String langCode) => switch (langCode) {
        'ja' => 'ファイルを書き込み中です。少々お待ちください…',
        'en' => 'Finalizing the file, please wait…',
        _ => '正在封盘，请稍候…',
      };

  /// Z30 顶部拨杆不在视频档。
  static String movieNeedPhysicalLever(String langCode) => switch (langCode) {
        'ja' => 'カメラ上部のレバーを動画アイコンに合わせてください',
        'en' => 'Move the camera lever to the video icon',
        _ => '请把机身顶部拨杆拨到视频档',
      };

  /// 要切回拍照，但拨杆仍在视频档。
  static String movieNeedPhysicalLeverToPhoto(String langCode) =>
      switch (langCode) {
        'ja' => '静止画に戻すには、カメラ上部のレバーを静止画アイコンに合わせてください',
        'en' => 'Move the camera lever back to the still-image icon',
        _ => '请把机身顶部拨杆拨回拍照档',
      };

  /// 0xD0A4 禁录原因。bit 为位序号。
  static String movieProhibitionReason(String langCode, int bit) =>
      switch (bit) {
        0 => switch (langCode) {
            'ja' => 'メモリーカードが入っていません',
            'en' => 'No memory card',
            _ => '未插入存储卡',
          },
        1 => switch (langCode) {
            'ja' => 'メモリーカードに異常があります',
            'en' => 'Memory card error',
            _ => '存储卡异常',
          },
        2 => switch (langCode) {
            'ja' => 'メモリーカードがフォーマットされていません',
            'en' => 'Memory card is not formatted',
            _ => '存储卡未格式化',
          },
        3 => switch (langCode) {
            'ja' => 'メモリーカードがいっぱいです',
            'en' => 'Memory card is full',
            _ => '存储卡已满',
          },
        9 => switch (langCode) {
            'ja' => 'バッファ書き込み中です',
            'en' => 'Still writing the buffer',
            _ => '缓存尚未写完',
          },
        10 => switch (langCode) {
            'ja' => 'すでに録画中です',
            'en' => 'Already recording',
            _ => '已经在录制中',
          },
        11 => switch (langCode) {
            'ja' => 'カードが書き込み禁止です',
            'en' => 'Card is write-protected',
            _ => '存储卡处于写保护',
          },
        12 => switch (langCode) {
            'ja' => 'ライブビュー拡大中は録画できません',
            'en' => 'Cannot record while live view is magnified',
            _ => '实时取景放大时不可录制',
          },
        13 => switch (langCode) {
            'ja' => 'レバーが動画モードになっていません',
            'en' => 'Lever is not in video mode',
            _ => '切换杆未在录像档',
          },
        14 => switch (langCode) {
            'ja' => '現在のアプリモードでは録画できません',
            'en' => 'Recording is not allowed in this app mode',
            _ => '当前应用模式不允许录制',
          },
        _ => switch (langCode) {
            'ja' => '録画できません (理由コード $bit)',
            'en' => 'Recording not allowed (reason bit $bit)',
            _ => '当前不可录制（原因位 $bit）',
          },
      };

  // ==================== v2.6.0 包围曝光 / 焦点包围 ====================

  static String bracketTitle(String langCode) => switch (langCode) {
        'ja' => '露出ブラケット',
        'en' => 'Exposure Bracketing',
        _ => '包围曝光',
      };

  static String focusStackTitle(String langCode) => switch (langCode) {
        'ja' => 'フォーカスブラケット',
        'en' => 'Focus Stacking',
        _ => '焦点包围',
      };

  static String bracketRunning(int current, int total) => '$current / $total';

  static String bracketRestored(String langCode) => switch (langCode) {
        'ja' => '元の露出設定に戻しました',
        'en' => 'Restored the original exposure settings',
        _ => '已恢复拍摄前的曝光参数',
      };

  static String bracketRestoreWarning(String langCode) => switch (langCode) {
        'ja' => '元の露出パラメータを復元できませんでした。手動で確認してください',
        'en' => 'Could not restore the original exposure settings; please check',
        _ => '未能恢复原始曝光参数，请手动检查',
      };

  static String bracketBuiltinConflict(String langCode) => switch (langCode) {
        'ja' => 'カメラ本体のブラケットが有効です。先にオフにしてください',
        'en' => 'In-camera bracketing is on; turn it off first',
        _ => '机身内置包围曝光已开启，请先在相机上关闭',
      };

  static String taskBusyHint(String langCode) => switch (langCode) {
        'ja' => '他のシーケンスが実行中です',
        'en' => 'Another sequence is running',
        _ => '其他序列任务正在运行',
      };

  // ==================== v2.6.0 序列参数面板 ====================

  static String seqShotCount(String langCode, int n) => switch (langCode) {
        'ja' => '$n 枚',
        'en' => '$n shots',
        _ => '$n 张',
      };

  static String seqStepCount(String langCode, int n) => switch (langCode) {
        'ja' => '間隔 $n 段',
        'en' => 'Step $n stop(s)',
        _ => '间隔 $n 档',
      };

  static String seqSettleMs(String langCode, int ms) => switch (langCode) {
        'ja' => '安定 $ms ms',
        'en' => 'Settle $ms ms',
        _ => '稳定 $ms ms',
      };

  static String seqOrderNormalFirst(String langCode) => switch (langCode) {
        'ja' => '標準 → 暗 → 明',
        'en' => 'Normal → dark → bright',
        _ => '正常 → 暗 → 亮',
      };

  static String seqOrderDarkToLight(String langCode) => switch (langCode) {
        'ja' => '暗 → 明',
        'en' => 'Dark → bright',
        _ => '暗 → 亮',
      };

  static String axisLabel(String langCode, String axis) => switch (axis) {
        'exposureCompensation' => switch (langCode) {
            'ja' => '露出補正',
            'en' => 'EV',
            _ => '曝光补偿',
          },
        'shutter' => switch (langCode) {
            'ja' => 'シャッター',
            'en' => 'Shutter',
            _ => '快门',
          },
        _ => 'ISO',
      };

  static String focusStepPerShot(String langCode, int n) =>
      switch (langCode) {
        'ja' => '1 枚あたり $n ステップ',
        'en' => '$n steps per shot',
        _ => '每张 $n 步',
      };

  static String focusFarToNear(String langCode) => switch (langCode) {
        'ja' => '遠 → 近',
        'en' => 'Far → near',
        _ => '由远到近',
      };

  static String focusNearToFar(String langCode) => switch (langCode) {
        'ja' => '近 → 遠',
        'en' => 'Near → far',
        _ => '由近到远',
      };

  static String focusReturnToStart(String langCode) => switch (langCode) {
        'ja' => '完了後に起点へ戻す',
        'en' => 'Return to start when done',
        _ => '完成后回到起点',
      };

  static String bracketSubtitle(String langCode) => switch (langCode) {
        'ja' => 'EV / シャッター / ISO の3軸、撮影後に元の値へ戻します',
        'en' => 'EV / shutter / ISO axes; restores the original values',
        _ => 'EV / 快门 / ISO 三轴可选，自动还原原始参数',
      };

  static String focusStackSubtitle(String langCode) => switch (langCode) {
        'ja' => '一定ステップでピントを送り、後工程で合成できる連写を撮ります',
        'en' => 'Steps the focus and captures a set for desktop stacking',
        _ => '按固定步长推进焦点，拍完整组供桌面端合成',
      };

  /// 序列拍摄期间关闭取景的提示。
  static String liveViewClosedForSequence(String langCode) =>
      switch (langCode) {
        'ja' => 'バッテリー節約のため、シーケンス中はライブビューを停止しました',
        'en' => 'Live view is off during the sequence to save battery',
        _ => '为保证手机与相机电量，序列拍摄期间已关闭实时取景',
      };

  // ==================== v2.6.0 机内 HDR ====================

  static String hdrTitle(String langCode) => switch (langCode) {
        'ja' => 'カメラ内 HDR',
        'en' => 'In-camera HDR',
        _ => '机内 HDR',
      };

  static String hdrSubtitle(String langCode) => switch (langCode) {
        'ja' => 'カメラが2枚撮影して1枚に合成します。元画像はカードに残せます',
        'en' => 'The camera takes two frames and merges them; originals can stay on the card',
        _ => '由相机拍两张并合成一张，原片可保留在存储卡',
      };

  static String hdrEvAuto(String langCode) => switch (langCode) {
        'ja' => '自動',
        'en' => 'Auto',
        _ => '自动',
      };

  static String hdrEv(int ev) => '±$ev EV';

  static String hdrSucceeded(String langCode) => switch (langCode) {
        'ja' => 'カメラ内で合成しました',
        'en' => 'Merged in the camera',
        _ => '已由相机完成合成',
      };

  static String hdrUnsupported(String langCode) => switch (langCode) {
        'ja' => 'この機種ではカメラ内 HDR を利用できません',
        'en' => 'In-camera HDR is not available on this body',
        _ => '这台机身不支持机内 HDR',
      };

  static String hdrCaptureFailed(String langCode) => switch (langCode) {
        'ja' => 'カメラ内 HDR の撮影に失敗しました',
        'en' => 'In-camera HDR capture failed',
        _ => '机内 HDR 拍摄失败',
      };

  static String hdrKeepsOriginals(String langCode) => switch (langCode) {
        'ja' => '元画像もカードに保存',
        'en' => 'Keep the originals on the card',
        _ => '同时在存储卡保留原片',
      };

  // ==================== v2.6.0 App 内序列合成 ====================

  static String compositeOfferTitle(String langCode) => switch (langCode) {
        'ja' => '1枚に合成しますか？',
        'en' => 'Merge into one image?',
        _ => '合成一张？',
      };

  static String compositeOfferBody(String langCode, int count) =>
      switch (langCode) {
        'ja' => '今回は $count 枚撮影しました。元画像はカメラのカードに残っています。アプリ内で1枚に合成しますか？（共有向けの解像度になります）',
        'en' =>
          'You captured $count frames. The originals stay on the camera card. Merge them into one image in the app? (Share-resolution output)',
        _ => '这次拍了 $count 张，原片都还在相机存储卡里。要在 App 内合成一张吗？（合成图是分享级分辨率）',
      };

  static String compositeConfirm(String langCode) => switch (langCode) {
        'ja' => '合成する',
        'en' => 'Merge',
        _ => '合成',
      };

  static String compositeKeepOriginals(String langCode) => switch (langCode) {
        'ja' => '元画像のみ',
        'en' => 'Originals only',
        _ => '只保留原片',
      };

  static String compositeWorking(String langCode) => switch (langCode) {
        'ja' => '合成中…',
        'en' => 'Merging…',
        _ => '正在合成…',
      };

  static String compositeSuccess(String langCode) => switch (langCode) {
        'ja' => '合成して保存しました',
        'en' => 'Merged and saved',
        _ => '已合成并保存',
      };

  static String compositeFailed(String langCode) => switch (langCode) {
        'ja' => '合成に失敗しました。元画像はカメラに残っています',
        'en' => 'Merge failed; the originals are still on the camera',
        _ => '合成失败，原片仍在相机里',
      };

  static String compositeRawUnsupported(String langCode) => switch (langCode) {
        'ja' => 'RAW を含むためアプリ内合成はできません',
        'en' => 'In-app merging is not available for RAW sequences',
        _ => '序列里有 RAW，App 内合成暂不支持',
      };

  // ==================== 相机端文件夹 ====================

  static String cameraFolderTitle(String langCode) => switch (langCode) {
        'ja' => 'カメラ側フォルダー',
        'en' => 'Camera folder',
        _ => '相机文件夹',
      };

  static String cameraFolderCurrent(String langCode, int folder) =>
      switch (langCode) {
        'ja' => '現在: $folder',
        'en' => 'Current: $folder',
        _ => '当前：$folder',
      };

  static String cameraFolderUnreadable(String langCode) => switch (langCode) {
        'ja' => 'カメラ側フォルダーを読み取れません',
        'en' => 'Cannot read the camera folder',
        _ => '读不到相机文件夹',
      };

  static String cameraFolderReadOnly(String langCode) => switch (langCode) {
        'ja' =>
          'この機種は外部からのフォルダー変更を受け付けません。カメラのメニューで作成・切り替えしてください',
        'en' =>
          'This body does not allow changing the folder over USB. Create or switch it in the camera menu.',
        _ => '这台机身不允许通过数据线改文件夹，请在相机菜单里新建或切换',
      };

  static String cameraFolderHint(String langCode) => switch (langCode) {
        'ja' => 'フォルダー番号（100–999）',
        'en' => 'Folder number (100–999)',
        _ => '文件夹编号（100–999）',
      };

  static String cameraFolderApplied(String langCode, int folder) =>
      switch (langCode) {
        'ja' => 'カメラ側フォルダーを $folder に切り替えました',
        'en' => 'Camera folder switched to $folder',
        _ => '相机文件夹已切换到 $folder',
      };

  static String cameraFolderFailed(String langCode) => switch (langCode) {
        'ja' => 'フォルダーの切り替えに失敗しました',
        'en' => 'Failed to switch the camera folder',
        _ => '切换相机文件夹失败',
      };

  // ==================== USB 诊断 ====================

  static String usbDiagTitle(String langCode) => switch (langCode) {
        'ja' => 'USB 接続診断',
        'en' => 'USB connection diagnostics',
        _ => 'USB 连接诊断',
      };

  static String usbDiagSubtitle(String langCode) => switch (langCode) {
        'ja' => '接続できないときに、端末が USB 機器を認識しているか確認します',
        'en' => 'Check whether the phone even sees the camera as a USB device',
        _ => '连不上时，先看手机有没有把相机识别成 USB 设备',
      };

  static String usbDiagEmpty(String langCode) => switch (langCode) {
        'ja' => 'USB 機器が1台も認識されていません',
        'en' => 'No USB devices are enumerated at all',
        _ => '系统没有枚举到任何 USB 设备',
      };

  static String usbDiagEmptyHint(String langCode) => switch (langCode) {
        'ja' =>
          '端末の設定で USB OTG（ホストモード）を有効にし、データ転送対応のケーブルで接続し直してください。それでも変わらない場合は端末側の制限です',
        'en' =>
          'Enable USB OTG / host mode in system settings and reconnect with a data-capable cable. If it still shows nothing, the phone is blocking host mode.',
        _ => '请在系统设置里打开 USB OTG（主机模式），换一根支持数据传输的线重插。如果仍然是空的，说明是手机系统侧有限制。',
      };

  static String usbDiagNoPtp(String langCode) => switch (langCode) {
        'ja' => '認識はされていますが、静止画(PTP)インターフェースがありません',
        'en' => 'Enumerated, but it exposes no Still Image (PTP) interface',
        _ => '设备已被识别，但没有静态图像（PTP）接口',
      };

  static String usbDiagClose(String langCode) => switch (langCode) {
        'ja' => '閉じる',
        'en' => 'Close',
        _ => '关闭',
      };

  /// 连接页：USB 插上却完全没有反应时的提示。
  static String usbNoDeviceHint(String langCode) => switch (langCode) {
        'ja' =>
          '新しい Android 端末では USB ホスト（OTG）が制限され、ケーブルを挿しても何も起きないことがあります。他社アプリでも同じ症状が出る場合は端末側の制限です。設定で OTG を確認し、データ転送対応のケーブルで試してください',
        'en' =>
          'Some recent Android phones restrict USB host (OTG), so plugging the cable does nothing at all. If other camera apps behave the same way, it is the phone. Check OTG in system settings and use a data-capable cable.',
        _ => '较新的安卓机型可能限制了 USB 主机（OTG），插上线也不会有任何反应。如果其他相机 App 也一样，那就是手机系统侧的限制。请在系统设置里确认 OTG，并换一根支持数据传输的线再试。',
      };

  static String usbOpenDiagnostics(String langCode) => switch (langCode) {
        'ja' => 'USB 診断を見る',
        'en' => 'Open USB diagnostics',
        _ => '查看 USB 诊断',
      };
}
