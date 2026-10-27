# 协议来源与实现说明

本文记录 Zync 相机连接层的协议依据，便于维护与许可审查。

## 1. Wi-Fi PTP/IP

- **ISO 15740:2013 / PIMA 15740**：Picture Transfer Protocol 定义了操作码、响应码、设备属性、对象信息和数据集布局。
- **gPhoto PTP/IP 文档**：<http://www.gphoto.org/doc/ptpip.php>
  - 数据包由 4 字节长度、4 字节类型和负载组成；
  - 默认 TCP 端口为 15740；
  - 命令通道用于初始化与操作请求/响应，事件通道通过连接号绑定并接收异步事件。
- **libgphoto2 `camlibs/ptp2/ptpip.c`**：<https://github.com/gphoto/libgphoto2/blob/master/camlibs/ptp2/ptpip.c>
  - 作为 PTP/IP 握手、数据阶段与事件读取行为参考。

本项目通过 `lib/protocol/ptp_ip_client.dart` 独立实现双 Socket 客户端，并在连接阶段对命令通道和事件通道分别执行有限次重试。

## 2. USB PTP

- **ISO 15740 / PIMA 15740**：PTP over USB Bulk-Only。
  - Command 容器：`length(4) + type=1(2) + opcode(2) + transactionId(4) + params(4*N)`
  - Data 容器：`length(4) + type=2(2) + reserved(2) + transactionId(4) + payload`
  - Response 容器：`length(4) + type=3(2) + responseCode(2) + transactionId(4) + params`
- **Android USB Host API**：<https://developer.android.com/guide/topics/connectivity/usb/host>
  - 使用 `UsbManager`、`UsbDeviceConnection`、`UsbInterface`、`UsbEndpoint` 与 `UsbRequest`；
  - 识别 Still Image 类接口，选择 Bulk IN/OUT 与可用的中断 IN 端点；
  - 处理零长度包、端点 halt、旧版 Android 单次请求大小限制以及相机侧残留会话。

本项目通过 `android/app/src/main/kotlin/com/zync/app/UsbPtpSession.kt` 独立实现会话、容器收发与事件泵。

## 3. 项目与协议致谢

| 项目 | 用途 | 许可证 |
| --- | --- | --- |
| [ImageToolbox](https://github.com/T8RIN/ImageToolbox) | 图像处理、滤镜与编辑交互参考 | Apache-2.0 |
| [Recipe Lab](https://github.com/voxivoid/recipe-lab-sony-pmca) | 色彩配方与胶片模拟数据结构参考 | GPL-3.0 |
| [SnapBridge-Enhanced](https://github.com/MXWF0/SnapBridge-Enhanced) | 尼康设备连接流程与交互参考 | 仓库未声明许可证 |
| [nsg](https://github.com/hurui200320/nsg) | 尼康 BLE `0x2007` 经纬度负载编码与设备协议参考 | AGPL-3.0 |
| [gphoto/libgphoto2](https://github.com/gphoto/libgphoto2) | PTP/IP、Nikon 操作码、设备属性解析 | LGPL-2.1 |
| [laheller/ptplibrary](https://github.com/laheller/ptplibrary) | PTP/IP 与 PTP/USB | 仓库未声明许可证 |
| [mmattes/ptpip](https://github.com/mmattes/ptpip) | PTP/IP | Apache-2.0 |
| [Fimagena/libptp](https://github.com/Fimagena/libptp) | Java PTP / PTPIP | LGPL-2.1 |
| [Zephyrion-Yuan/NikonCopy](https://github.com/Zephyrion-Yuan/NikonCopy) | Android USB OTG PTP 文件访问 | 仓库未声明许可证 |
| [gkoh/furble](https://github.com/gkoh/furble) | Nikon BLE 快门控制与 `0x2007` 经纬度定位同步参考 | MIT |
| [rjmendez/nikongeotag](https://github.com/rjmendez/nikongeotag) | Nikon BLE smart-device 协议参考 | GPL-3.0 |
| [semi-utils](https://github.com/leslievan/semi-utils) | 相机 EXIF 水印模板（标准框、圆角阴影、极简参数、品牌匹配与地理坐标）设计参考 | Apache-2.0 |
| [Copicseal (可图匠)](https://github.com/copicseal/copicseal) | 相机参数边框、经典白边、无框与复古时间戳水印排版参考 | Apache-2.0 |
| [PicSeal](https://github.com/pipiqiang/PicSeal) | 相机设备自动识别、品牌风格水印生成与 EXIF 保留参考 | MIT |
| [camera-watermark](https://github.com/myWsq/camera-watermark) | 单反/微单 EXIF 合成相机水印与参数自定义交互参考 | MIT |
| [LibRaw](https://github.com/LibRaw/LibRaw) | RAW 解码 | LGPL-2.1 / CDDL-1.0 |
| [AndroidX Media3](https://github.com/androidx/media) | 视频播放与编辑 | Apache-2.0 |

> 第三方项目的版权与许可证归原作者所有，具体以各仓库当前许可证文件为准。

## 4. 实现边界

- Wi-Fi 连接只面向手机加入相机热点的直连场景，不提供局域网相机发现或手动 IP 扫描。
- USB 传输不依赖厂商 SDK，设备识别覆盖标准 Still Image 类接口及常见相机厂商 ID。
- Nikon 私有操作码只在设备能力集或协议操作码支持时使用。
