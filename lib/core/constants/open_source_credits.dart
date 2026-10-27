import 'package:flutter/widgets.dart';
import '../../l10n/l10n.dart';

/// 第三方项目与运行时依赖的致谢信息。
class OpenSourceCredit {
  final String name;
  final String description;
  final String url;
  final String license;

  const OpenSourceCredit({
    required this.name,
    required this.description,
    required this.url,
    required this.license,
  });

  /// 按当前应用语言返回致谢描述。
  String trDescription(BuildContext context) =>
      EngineL10n.tr(description, context.l10n.localeName);

  /// 按当前应用语言返回许可证文案。
  String trLicense(BuildContext context) =>
      EngineL10n.tr(license, context.l10n.localeName);
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
    name: 'libgphoto2',
    description: 'PTP/IP 与尼康操作码参考',
    url: 'https://github.com/gphoto/libgphoto2',
    license: 'LGPL-2.1',
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
    description: '尼康 BLE 快门控制与 0x2007 经纬度定位同步参考',
    url: 'https://github.com/gkoh/furble',
    license: 'MIT',
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
