# Zync

<p align="center">
  <img src="assets/icons/zync_logo.svg" width="112" height="112" alt="Zync 图标" />
</p>

<p align="center">
  <strong>面向尼康 Z 系列的传输、无线互联与水印工坊。</strong>
</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh-CN.md">简体中文</a> |
  <a href="README.ja.md">日本語</a>
</p>

Zync 是一款使用 Flutter 开发的开源摄影工具，围绕尼康 Z 系列相机整理出一条紧凑的工作流：连接相机、浏览与传输照片，然后完成调色、水印和导出。应用可直接通过 Wi-Fi PTP/IP 或 USB PTP 与相机通信，不依赖厂商账号、云服务或专有 SDK。

- 项目地址：<https://github.com/sa1to-asuka/Zync>
- 当前版本：`1.0.0`
- 许可证：MIT
- 主要平台：Android

## 功能概览

| 模块 | 能力 |
| --- | --- |
| 相机连接 | Wi-Fi PTP/IP 与 USB OTG PTP |
| 相机浏览 | 浏览 JPG、NEF、NRW，并提取 RAW 内嵌预览 |
| 文件传输 | 分块下载、任务队列、暂停、取消、重试与自动回传 |
| 水印工坊 | 11 款模板、EXIF 参数、自定义文字、Logo 与导出质量 |
| 照片处理 | 调色预设、曝光与影调调整、裁剪、旋转、对比与拼图 |
| 自适应界面 | 手机底部导航与大屏左侧导航栏 |
| 应用更新 | GitHub Releases 检查与安装前 SHA-256 校验 |

## 连接方式

### Wi-Fi PTP/IP

手机先加入相机创建的无线热点，再从 Zync 建立连接。Wi-Fi 传输使用独立的 Command 与 Event TCP 通道，并支持配置端口、心跳间隔和会话保活，以降低相机在传输过程中休眠的概率。

### USB PTP

使用 USB OTG 数据线连接相机，并将相机设置为 PTP 模式。Zync 通过 Android USB Host API 建立标准 Still Image 会话，可浏览相机、接收事件和下载文件。USB 与 Wi-Fi 共用同一套传输队列和导出历史。

### 蓝牙 LSS

蓝牙低功耗 LSS 通道属于实验功能，入口默认隐藏，不是 Wi-Fi 或 USB 常规传输的必要条件。

## 主要功能

### 相机相册

- 浏览相机存储卡中的 JPG、NEF 与 NRW 文件。
- 无需完整解码 RAW 时，从 NEF/NRW 中提取内嵌 JPEG 预览。
- 单张下载或多选批量导出。
- 显示文件类型、大小和已导出状态，减少重复下载。
- 根据 EXIF 方向正确显示照片，支持双指缩放、双击缩放与下拉关闭。
- 在相机能力支持时删除本地或相机侧文件。
- 将多张照片合成为拼图。

### 传输引擎

- 通过 `GetPartialObject` 按 4 MB 分块流式下载。
- 大图和 RAW 下载不会阻塞界面其他操作。
- 传输中心显示每条任务的进度与失败原因，支持暂停、继续、单条取消、失败重试和清理已完成任务。
- 后台传输使用前台服务与常驻进度通知，锁屏或切换应用后可继续执行。
- 监听 `ObjectAdded` 事件，可在拍摄后自动回传照片。
- 导出文件保存到 `/DCIM/Zync`，并记录导出历史。

### 水印工坊

- 提供 11 款画廊风格模板，包括高斯虚化边框、拍立得相纸、暗色玻璃、杂志字幕、胶片齿孔、渐变字幕和极简细线等样式。
- 可调整边框比例、强调色、卡片底色、圆角、透明度、字体与间距。
- 分别控制机型、镜头、曝光参数和拍摄日期的显示状态。
- 从 EXIF 自动读取机身、镜头、光圈、快门、ISO 与拍摄时间。
- 支持最多两行自定义文字，以及从相册添加 Logo 图层。
- 提供 95、92、85 三档 JPEG 导出质量。
- 将尺寸、方向、机型、镜头、曝光、焦距与时间写回导出图片的 EXIF。

### 调色与图像编辑

- 按胶片风格组织色彩预设，并提供经典胶卷外观。
- 可微调曝光、对比度、高光、阴影、色温、色调、饱和度、锐化、暗角与颗粒。
- 调色结果可与水印模板组合导出。
- 保存前可对比编辑结果与原始照片。

### 自适应界面与返回逻辑

- 支持深色、浅色及跟随系统三种主题模式。
- 手机窄屏使用底部导航；窗口宽度达到 600 dp 后切换为左侧导航栏。
- 返回操作先关闭编辑器和弹窗，再退出多选等页面内部状态，然后回到「连接」页；首页连续两次返回才会退出应用。

## 使用流程

1. 开启尼康 Z 系列相机的 Wi-Fi，或使用 OTG 数据线连接相机。
2. 打开 **连接**，建立 Wi-Fi PTP/IP 或 USB PTP 会话。
3. 打开 **相机相册**，选择文件并加入传输队列。
4. 打开 **水印工坊**，应用模板、调色和自定义署名。
5. 将完成的 JPEG 导出到手机。

## 兼容性

- 面向尼康 Z 系列微单相机。
- Android 7.0（API 24）及以上。
- Wi-Fi 模式要求手机加入相机创建的无线热点。
- USB 模式要求手机支持 OTG，且相机提供标准 PTP Still Image 接口与 Bulk IN/OUT 端点。
- 实际表现可能随机型、固件、数据线和 Android USB 控制器而异，欢迎提交真机反馈。
- iOS 与桌面端尚未完整验证。

Zync 是独立开发的第三方项目，与尼康官方无关联，不使用尼康专有 SDK。「Nikon」「Z SERIES」等名称仅用于说明兼容范围，相关商标归各自权利人所有。

## 构建环境

- 支持 Dart 3.0 及以上的 Flutter SDK；项目声明最低 Flutter 版本为 3.10。
- Android compile SDK 36。
- JDK 17。
- 原生 RAW 处理模块使用 Android NDK `28.2.13676358`。

## 快速开始

```bash
git clone https://github.com/sa1to-asuka/Zync.git
cd Zync
flutter pub get
flutter run
```

## 构建应用

构建通用 Release APK：

```bash
flutter build apk --release
```

产物位置：

```text
build/app/outputs/flutter-apk/app-release.apk
```

构建仅含 ARM64 架构并分离调试符号的版本：

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols/1.0.0-arm64
```

产物位置：

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

请将调试符号与对应 APK 一同归档，以便后续解析崩溃堆栈。日常安装不要使用 Debug 包。

### Windows 构建路径

Flutter Release AOT 构建可能无法处理包含非 ASCII 字符的项目路径。如果 `gen_snapshot` 报错 `Unable to read file: ...app.dill`，请复制到纯 ASCII 路径后重新构建：

```powershell
robocopy . D:\zync_ascii /E /XD build .dart_tool .git
cd D:\zync_ascii
flutter build apk --release
```

### Release 签名

如果缺少 `android/key.properties`，构建会回退到 Debug 签名，仅适合本地调试。正式分发前请配置自己的 keystore：

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

然后在 `android/key.properties` 中填写密码和路径。该文件与 `*.jks` 均已加入 Git 忽略列表。

### Release 资产与更新校验

Zync 从 <https://github.com/sa1to-asuka/Zync/releases> 检查更新。发布时请上传 APK 和同名 SHA-256 文件：

```text
Zync-release-1.0.0.apk
Zync-release-1.0.0.apk.sha256
```

校验文件内容格式：

```text
<sha256>  Zync-release-1.0.0.apk
```

应用内更新会在安装前校验文件完整性，校验失败时不会继续安装。

### 测试与静态检查

```bash
flutter test
flutter analyze
```

## 项目结构

```text
zync/
├── assets/icons/              应用图标资源
├── android/                   Android 宿主、USB PTP、BLE 与原生 RAW 模块
├── lib/
│   ├── core/                  常量、设置、主题与通用工具
│   ├── protocol/              PTP/IP、USB PTP 与相机驱动层
│   ├── engine/                传输、编辑、水印、视频与更新逻辑
│   └── ui/                    页面、组件与自适应导航
├── test/                      单元测试与组件测试
├── docs/                      协议说明与版本记录
└── pubspec.yaml
```

协议层、业务引擎与界面层保持分离。相机能力通过驱动接口暴露，便于后续增加新的传输方式或机型适配，而不影响界面层。

## 协议依据

Wi-Fi 与 USB 传输遵循公开的 Picture Transfer Protocol 模型：

- ISO 15740 / PIMA 15740：PTP 操作码、数据集、响应以及 USB Bulk-Only 容器。
- [gPhoto PTP/IP 文档](http://www.gphoto.org/doc/ptpip.php)：PTP/IP 包类型、握手行为与数据阶段布局。
- [Android USB Host API](https://developer.android.com/guide/topics/connectivity/usb/host)：USB 设备发现、接口、端点与批量传输。
- [libgphoto2](https://github.com/gphoto/libgphoto2)：公开的 PTP/IP 与尼康操作行为资料。

更多实现说明见 `docs/protocol-sources.md`。Zync 的协议实现不包含从第三方项目复制而来的源代码。

## 开源致谢

感谢以下项目的维护者与贡献者。各项目的版权与许可证归原作者所有。

### 核心项目与协议参考

| 项目 | 用途 | 许可证 |
| --- | --- | --- |
| [ImageToolbox](https://github.com/T8RIN/ImageToolbox) | 图像处理、滤镜与编辑交互参考 | Apache-2.0 |
| [Recipe Lab](https://github.com/voxivoid/recipe-lab-sony-pmca) | 色彩配方与胶片外观数据结构参考 | GPL-3.0 |
| [SnapBridge-Enhanced](https://github.com/MXWF0/SnapBridge-Enhanced) | 尼康连接流程与交互参考 | 仓库当前未声明许可证 |
| [nsg](https://github.com/hurui200320/nsg) | 尼康协议与设备能力参考 | AGPL-3.0 |
| [libgphoto2](https://github.com/gphoto/libgphoto2) | PTP/IP 与尼康操作码参考 | LGPL-2.1 |
| [ptplibrary](https://github.com/laheller/ptplibrary) | PTP/IP 与 USB PTP 行为参考 | 仓库当前未声明许可证 |
| [ptpip](https://github.com/mmattes/ptpip) | PTP/IP 实现参考 | Apache-2.0 |
| [libptp](https://github.com/Fimagena/libptp) | PTP/IP 与 USB PTP 实现参考 | LGPL-2.1 |
| [NikonCopy](https://github.com/Zephyrion-Yuan/NikonCopy) | Android USB OTG PTP 文件访问参考 | 仓库当前未声明许可证 |
| [furble](https://github.com/gkoh/furble) | 尼康 BLE 快门行为参考 | MIT |
| [nikongeotag](https://github.com/rjmendez/nikongeotag) | 尼康 BLE smart-device 协议参考 | GPL-3.0 |

### 运行时与基础依赖

| 项目 | 用途 | 许可证 |
| --- | --- | --- |
| [Flutter](https://github.com/flutter/flutter) | 跨平台 UI 与运行时 | BSD-3-Clause |
| [Dart SDK](https://github.com/dart-lang/sdk) | Dart 语言与运行时 | BSD-3-Clause |
| [LibRaw](https://github.com/LibRaw/LibRaw) | 相机 RAW 解码 | LGPL-2.1 / CDDL-1.0 |
| [AndroidX Media3](https://github.com/androidx/media) | 视频播放、抽帧与编辑 | Apache-2.0 |
| [Kotlin](https://github.com/JetBrains/kotlin) | Android 原生语言与运行时 | Apache-2.0 |
| [flutter_svg](https://github.com/dnfield/flutter_svg) | SVG 渲染 | MIT |
| [image](https://github.com/brendan-duncan/image) | 图像编码与处理 | MIT |
| [exif](https://github.com/bigflood/dartexif) | EXIF 元数据读写 | MIT |
| [crypto](https://github.com/dart-lang/crypto) | SHA-256 与摘要算法 | BSD-3-Clause |
| [intl](https://github.com/dart-lang/i18n) | 国际化与日期格式 | BSD-3-Clause |
| [path_provider](https://github.com/flutter/packages/tree/main/packages/path_provider) | 平台目录定位 | BSD-3-Clause |
| [video_player](https://github.com/flutter/packages/tree/main/packages/video_player) | 视频播放支持 | BSD-3-Clause |

应用内也可通过 **设置 → 关于 Zync → 项目与许可 → 开源致谢** 查看同一份致谢数据。当前未声明许可证的项目会如实标注，不会被描述为已开源许可。

## 开源许可

Zync 使用 [MIT License](LICENSE) 开源。欢迎在 <https://github.com/sa1to-asuka/Zync> 提交 Issue 或 Pull Request。
