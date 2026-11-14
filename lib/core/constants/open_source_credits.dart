import 'package:flutter/widgets.dart';
import '../../l10n/l10n.dart';

/// 第三方项目与运行时依赖的致谢信息。
class OpenSourceCredit {
  final String name;
  final String description;
  final String url;
  final String license;

  /// 核对时的提交号（短哈希）。
  final String? commit;

  /// 实际参考过的关键文件，按仓库内相对路径书写。
  final List<String> codePaths;

  /// 对 Z 30 (Gen 2) 的可用度评估。
  final String? z30Usability;

  /// 源码合规边界（哪些能抄、哪些只能看）。
  final String? compliance;

  const OpenSourceCredit({
    required this.name,
    required this.description,
    required this.url,
    required this.license,
    this.commit,
    this.codePaths = const <String>[],
    this.z30Usability,
    this.compliance,
  });

  /// 按当前应用语言返回致谢描述。
  String trDescription(BuildContext context) =>
      EngineL10n.tr(description, context.l10n.localeName);

  /// 按当前应用语言返回许可证文案。
  String trLicense(BuildContext context) =>
      EngineL10n.tr(license, context.l10n.localeName);

  /// 按当前应用语言返回 Z 30 可用度。
  String? trZ30(BuildContext context) => z30Usability == null
      ? null
      : EngineL10n.tr(z30Usability!, context.l10n.localeName);

  /// 按当前应用语言返回合规边界。
  String? trCompliance(BuildContext context) => compliance == null
      ? null
      : EngineL10n.tr(compliance!, context.l10n.localeName);
}

const List<OpenSourceCredit> openSourceProjectCredits = [
  OpenSourceCredit(
    name: 'ImageToolbox',
    description: '图像处理、滤镜与编辑交互参考',
    url: 'https://github.com/T8RIN/ImageToolbox',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'Recipe Lab',
    description: '色彩配方与胶片模拟数据结构参考',
    url: 'https://github.com/voxivoid/recipe-lab-sony-pmca',
    license: 'GPL-3.0',
  ),
  OpenSourceCredit(
    name: 'SnapBridge-Enhanced',
    description: '尼康设备连接流程与交互参考',
    url: 'https://github.com/MXWF0/SnapBridge-Enhanced',
    license: '未声明许可证',
  ),
  OpenSourceCredit(
    name: 'nsg',
    description: '尼康 BLE 0x2007 经纬度负载编码与设备协议参考',
    url: 'https://github.com/hurui200320/nsg',
    license: 'AGPL-3.0',
  ),
  OpenSourceCredit(
    name: 'NICO',
    description: 'USB 实时取景、AF/MF 驱动、对焦点与峰值对焦参考',
    url: 'https://github.com/haecksenwerk/nico',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'aero-shutter',
    description: 'Wi-Fi PTP/IP 导入行为参考',
    url: 'https://github.com/subhashraveendran/aero-shutter',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'NikonCameraControl',
    description: 'Android 遥控与传输流程参考',
    url: 'https://github.com/youdangshi/NikonCameraControl',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'Shotdeck',
    description: '取景循环与拍摄落盘确认行为参考',
    url: 'https://github.com/Fluoro-Antimonic-Acid/Shotdeck',
    license: 'GPL-3.0',
  ),
  OpenSourceCredit(
    name: 'LutCameraPro',
    description: 'PTP/IP 取景与连接边界参考',
    url: 'https://github.com/laodamanbaout/LutCameraPro-',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: '1dlut-z30-filters',
    description: 'Z 30 影调曲线负载结构参考',
    url: 'https://github.com/haotiandi1011-lgtm/1dlut-z30-filters',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'libgphoto2',
    description: 'PTP/IP、尼康操作码与响应码表参考，含 0xD0A4 禁录位掩码与 0xC108 封盘事件',
    url: 'https://github.com/gphoto/libgphoto2',
    license: 'LGPL-2.1',
    commit: '31a2f40',
    codePaths: <String>[
      'camlibs/ptp2/ptp.h',
      'camlibs/ptp2/config.c (L10331 _put_Nikon_Movie)',
    ],
    z30Usability: '高（协议规范）',
    compliance: 'LGPL-2.1：仅参考协议常数与交互顺序，禁止复制 C 代码',
  ),
  OpenSourceCredit(
    name: 'ptplibrary',
    description: 'PTP/IP 与 USB PTP 行为参考',
    url: 'https://github.com/laheller/ptplibrary',
    license: '未声明许可证',
  ),
  OpenSourceCredit(
    name: 'ptpip',
    description: 'PTP/IP 协议实现参考',
    url: 'https://github.com/mmattes/ptpip',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'libptp',
    description: 'PTP/IP 与 USB PTP 实现参考',
    url: 'https://github.com/Fimagena/libptp',
    license: 'LGPL-2.1',
  ),
  OpenSourceCredit(
    name: 'NikonCopy',
    description: 'Android USB OTG PTP 文件访问参考',
    url: 'https://github.com/Zephyrion-Yuan/NikonCopy',
    license: '未声明许可证',
  ),
  OpenSourceCredit(
    name: 'furble',
    description: '尼康 BLE 快门控制、0x2007 经纬度同步，以及 SnapBridge BLE Blowfish 握手与 Wi-Fi 唤醒协议参考',
    url: 'https://github.com/gkoh/furble',
    license: 'MIT',
    commit: '0cac22a',
    codePaths: <String>[
      'lib/furble/NikonSmart.cpp (L1-100)',
      'lib/furble/NikonSmart.h (L1-100)',
    ],
    z30Usability: '中（实验性参考）',
    compliance: 'MIT 兼容；BLE 唤醒在 UI 中标注为实验性开关',
  ),
  OpenSourceCredit(
    name: 'nikongeotag',
    description: '尼康 BLE smart-device 协议参考',
    url: 'https://github.com/rjmendez/nikongeotag',
    license: 'GPL-3.0',
  ),
  OpenSourceCredit(
    name: 'semi-utils',
    description: '相机 EXIF 水印模板（标准框、圆角阴影、极简参数、品牌匹配与地理坐标）设计参考',
    url: 'https://github.com/leslievan/semi-utils',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'Copicseal (可图匠)',
    description: '相机参数边框、经典白边、无框与复古时间戳水印排版参考',
    url: 'https://github.com/copicseal/copicseal',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'PicSeal',
    description: '相机设备自动识别、品牌风格水印生成与 EXIF 保留参考',
    url: 'https://github.com/pipiqiang/PicSeal',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'camera-watermark',
    description: '单反/微单 EXIF 合成相机水印与参数自定义交互参考',
    url: 'https://github.com/myWsq/camera-watermark',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'Z30-Recipes',
    description: '尼康 Z30 PTP/IP (0x90CC/0x90CD/0xD200) 机内优化校准读写与 NP3/NCP 解析参考',
    url: 'https://github.com/yekong-nasa/Z30-Recipes',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'NikonNP3',
    description: '尼康 NP3 创意色彩灵感库配方合集与分类标签参考',
    url: 'https://github.com/Timor88/NikonNP3',
    license: '社区共享',
  ),
  OpenSourceCredit(
    name: 'nikon-flexible-color-picture-control',
    description: '尼康 Flexible Color NP3 (0310) 二进制偏移与色彩混合器结构解析参考',
    url: 'https://github.com/ssssota/nikon-flexible-color-picture-control',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'Nikon Imaging (ニコンイメージング)',
    description: '色彩优化近似效果预览官方样片素材（Z 30 / Z fc / Z f / Z 8 实拍样片）',
    url: 'https://www.nikon-image.com/',
    license: 'Nikon 官方样片展示许可',
  ),
  OpenSourceCredit(
    name: 'Pakutaso (ぱくたそ)',
    description: '色彩优化近似效果预览免费人像与生活样片素材备选参考',
    url: 'https://www.pakutaso.com/',
    license: 'Pakutaso 免费素材许可',
  ),
  OpenSourceCredit(
    name: '影视飓风 (YSJF)',
    description: '色彩优化近似效果预览风光与自然样片素材致谢',
    url: 'https://www.ysjf.com/index',
    license: '免费样片素材许可',
  ),
  OpenSourceCredit(
    name: 'Spektrafilm',
    description: '物理光谱胶片引擎：H&D 密度曲线、DIR 抑制剂、红光晕、银盐颗粒与印相纸冲印（独立原生实现）',
    url: 'https://github.com/andreavolpato/spektrafilm',
    license: 'GPL-3.0 / CC BY-SA 4.0',
  ),
  OpenSourceCredit(
    name: 'OpenCine',
    description: 'Z 系列三代能力分级、0x000D 探活应答、0x9431 大文件分块、取景帧头遥测与录像控制参考',
    url: 'https://github.com/erik-sutton95/OpenCine',
    license: 'Apache-2.0',
    commit: '5e93770',
    codePaths: <String>[
      'Sources/OpenCineNikon/ZCameraCapabilityProfile.swift',
      'Sources/OpenCineNikon/PTPIPTransport.swift (L482-499)',
      'NikonBodyWake.swift',
      'PTPObjectTransfer.swift',
      'PTPLiveViewObject.swift (L1-95)',
      'PTPCameraProperties.swift / StillCapture.swift / NativeCameraSession.swift',
    ],
    z30Usability: '极高（核心参考）',
    compliance: 'Apache-2.0 兼容，可按 Dart 习惯重构移植并署名致谢',
  ),
  OpenSourceCredit(
    name: 'OpenZCine',
    description: 'Android 端断线重连状态机与 AP 重连策略参考',
    url: 'https://github.com/erik-sutton95/OpenZCine',
    license: 'Apache-2.0',
    commit: 'c5423f4',
    codePaths: <String>[
      'Apps/Android/.../MonitorSessionRecovery.kt',
      'pairing/CameraApReconnect.kt',
      'pairing/SavedCameraConnector.kt',
    ],
    z30Usability: '极高（核心参考）',
    compliance: 'Apache-2.0 兼容',
  ),
  OpenSourceCredit(
    name: 'digiCamControl',
    description: 'NikonZ30 专属模式编码、App 端包围曝光与原值还原、A-B 点焦点包围状态机参考',
    url: 'https://github.com/dukus/digiCamControl',
    license: 'MIT',
    commit: 'c420d40',
    codePaths: <String>[
      'CameraControl.Devices/Nikon/NikonZ30.cs (L1-44)',
      'CameraControl/ViewModel/BracketingViewModel.cs (L470-540)',
      'CameraControl/ViewModel/LiveViewViewModel.cs (L3010-3100)',
      'NikonBase.cs (L1960-1969)',
    ],
    z30Usability: '很高',
    compliance: 'MIT 兼容，可直接参考逻辑结构并署名',
  ),
  OpenSourceCredit(
    name: 'airnef',
    description: '断点续传状态校验思路参考',
    url: 'https://github.com/besi/airnef',
    license: 'GPL-3.0',
    commit: 'e03adda',
    codePaths: <String>[
      'airnefcmd.py (L2720+)',
      'mtpwifi.py',
    ],
    z30Usability: '中（策略参考）',
    compliance: 'GPL-3.0：仅借鉴状态与边界校验思路，禁止复制 Python 代码',
  ),
];

const List<OpenSourceCredit> openSourceRuntimeCredits = [
  OpenSourceCredit(
    name: 'Flutter',
    description: '跨平台 UI 与运行时框架',
    url: 'https://github.com/flutter/flutter',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'Dart SDK',
    description: 'Dart 语言与运行时',
    url: 'https://github.com/dart-lang/sdk',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'LibRaw',
    description: '相机 RAW 解码',
    url: 'https://github.com/LibRaw/LibRaw',
    license: 'LGPL-2.1 / CDDL-1.0',
  ),
  OpenSourceCredit(
    name: 'AndroidX Media3',
    description: '视频播放、抽帧与编辑',
    url: 'https://github.com/androidx/media',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'Kotlin',
    description: 'Android 原生层语言与运行时',
    url: 'https://github.com/JetBrains/kotlin',
    license: 'Apache-2.0',
  ),
  OpenSourceCredit(
    name: 'flutter_localizations',
    description: '多语言本地化委托与资源加载',
    url:
        'https://github.com/flutter/flutter/tree/master/packages/flutter_localizations',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'animations',
    description: 'Material 动效转场组件库（FadeThrough / SharedAxis）',
    url: 'https://github.com/flutter/packages/tree/main/packages/animations',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'flutter_svg',
    description: 'SVG 图形渲染',
    url: 'https://github.com/dnfield/flutter_svg',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'image',
    description: '图像编码与处理',
    url: 'https://github.com/brendan-duncan/image',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'exif',
    description: 'EXIF 元数据读写',
    url: 'https://github.com/bigflood/dartexif',
    license: 'MIT',
  ),
  OpenSourceCredit(
    name: 'crypto',
    description: 'SHA-256 与摘要算法',
    url: 'https://github.com/dart-lang/crypto',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'intl',
    description: '国际化与日期格式化',
    url: 'https://github.com/dart-lang/i18n',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'path_provider',
    description: '平台目录定位',
    url: 'https://github.com/flutter/packages/tree/main/packages/path_provider',
    license: 'BSD-3-Clause',
  ),
  OpenSourceCredit(
    name: 'video_player',
    description: '视频播放支持',
    url: 'https://github.com/flutter/packages/tree/main/packages/video_player',
    license: 'BSD-3-Clause',
  ),
];

const List<OpenSourceCredit> openSourceCredits = [
  ...openSourceProjectCredits,
  ...openSourceRuntimeCredits,
];
