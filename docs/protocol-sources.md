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

## 3. 实时取景与遥控拍摄

- **Nikon 厂商操作码**（0x9201 / 0x9202 / 0x9203 / 0x9205 / 0x100E / 0x100E 的尼康备用 0x9207）为公开逆向资料中多份独立实现一致记录的操作码，本仓库按协议事实使用，未复制任何项目的源代码。
  - `0x9201` StartLiveView：无参数；相机忙时返回 `0x2019`，可短暂等待后重试。
  - `0x9203` GetLiveViewImage：Data-In 阶段返回「厂商头部 + JPEG」，头部长度随机型与固件变化，因此按 SOI (`FF D8`) / EOI (`FF D9`) 扫描提取，不假设固定偏移。
  - `0x9202` EndLiveView：任何退出路径都必须发送。
  - `0x100E` InitiateCapture：必须先退出取景；参数 `[0, 0]`。是否真正落盘由对象列表出现新 handle 判断，响应码只代表指令被接受。
  - `0x9205` ChangeAfArea：坐标为机身对焦区域坐标系（APS-C Z 机型为 5760 × 3840），不是取景帧像素坐标。
- **设备属性**：`0x1014` 返回可选值列表、是否可写与值宽度；`0x1016` 写入后必须回读比对，因为机身模式不允许时会静默返回成功。
- **行为参考**（仅阅读实现与文档以核对协议事实，未复制代码）：
  - [haecksenwerk/nico](https://github.com/haecksenwerk/nico)（MIT）
  - [LutCameraPro](https://github.com/laodamanbaout/LutCameraPro-)（Apache-2.0）
  - [Shotdeck](https://github.com/Fluoro-Antimonic-Acid/Shotdeck)（GPL-3.0，仅作行为对照）

本项目通过 `lib/engine/liveview/` 与 `lib/engine/capture/` 独立实现取景循环、帧合流与拍摄确认。

### 3.1 对焦与手动对焦

- `0x90C1` AfDrive（无参数）：触发一次自动对焦。
- `0x90C8` DeviceReady（无参数）：轮询对焦是否结束。响应码本身就是结果——
  `0x2001` 空闲、`0xA002` 未合焦、`0x2019` 仍在忙。
- `0x9204` MfDrive（2 参数：方向 `1=近 / 2=远`，步数 `1..32767`）：必须在实时取景中调用。
  到行程尽头返回 `0xA00C`，步长不足返回 `0xA00E`。
- `0x9206` AfDriveCancel（无参数）：取消进行中的对焦，部分固件不接受，按尽力而为处理。
- **约束**：自动/手动对焦都需要取景保持开启，因此**不能**走「关闭取景再执行」的独占路径；
  对焦命令会占用取景在途计数，快门流程会等它落地后才发 `0x9202`，避免与关闭取景竞争。

### 3.2 取景叠加是本地计算，不是相机功能

峰值对焦、斑马纹、直方图全部在手机上根据取景帧计算：

- 分析帧先缩到约 320px 宽（JPEG DCT 缩放），亮度按 `(54R + 183G + 19B) >> 8` 计算；
- 峰值用 3×3 Sobel 梯度幅值 `|Gx| + |Gy|` 与阈值比较；
- 斑马纹按亮度阈值加斜纹；
- 三者共用一张预乘 RGBA 叠加图，以 `ui.Image` 交给取景 painter。

因此这些叠加**只作用于预览**，不影响导出的照片，也不代表相机端的状态。

### 3.3 已知但本版本未采用的操作码

| 操作码 | 用途 | 备注 |
| --- | --- | --- |
| `0x90CB` AfCaptureSDRAM | 自动对焦 + 快门一步完成 | 无法区分对焦失败与快门失败 |
| `0x9207` InitiateCaptureRecInMedia | 拍照并存入卡 | 仅在 `0x100E` 返回不支持时作为备用 |
| `0x920A` / `0x920B` | 开始 / 结束录像 | 本版本不做视频录制 |
| `0x920C` TerminateCapture | 终止长曝光拍摄 | 尚未接入 B 门 |
| `0x9402`–`0x9406` | 点测白平衡 | 尚未接入 |
| `0x9423` / `0x9428` | 取景压缩尺寸 / 扩展取景图 | 分辨率尚未按机型探测 |

> 注意：`0x9403` 在本项目中是「结束点测白平衡」，**不是**对焦取消；
> 对焦取消只用 `0x9206`。

## 4. 项目与协议致谢

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
| [haecksenwerk/nico](https://github.com/haecksenwerk/nico) | USB 实时取景、对焦点与曝光属性读写 | MIT |
| [laodamanbaout/LutCameraPro-](https://github.com/laodamanbaout/LutCameraPro-) | PTP/IP 取景与连接边界 | Apache-2.0 |
| [Fluoro-Antimonic-Acid/Shotdeck](https://github.com/Fluoro-Antimonic-Acid/Shotdeck) | 取景循环与拍摄落盘确认行为 | GPL-3.0 |
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

## 5. 实现边界

- Wi-Fi 连接只面向手机加入相机热点的直连场景，不提供局域网相机发现或手动 IP 扫描。
- USB 传输不依赖厂商 SDK，设备识别覆盖标准 Still Image 类接口及常见相机厂商 ID。
- Nikon 私有操作码只在设备能力集或协议操作码支持时使用。
- 实时取景与遥控拍摄以 Nikon Z 30 为验证目标；其他机型按能力位尝试，失败时界面会明确提示而不是静默降级。
- 峰值对焦、斑马纹与直方图是本机图像处理，不是相机能力；关闭后不影响取景与导出。
- 构图参考线只依据机身朝向（0/90/180/270）绘制，PTP 未暴露俯仰/横滚角，因此不提供真正的水准泡。
- 不提供固件修改、刷机或任何写机内固件的能力。
