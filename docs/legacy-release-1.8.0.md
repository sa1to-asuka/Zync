# Zync 前身版本 1.8.0 构建存档

- 版本：1.8.0 (versionCode 24)
- 历史包名：com.nikon.snaplink
- compileSdk 36 / minSdk 24 / targetSdk 35
- 历史原生库：libsnaplink_raw.so（LibRaw 0.22.2，LGPL-2.1 / CDDL-1.0）
- ABI：arm64-v8a、armeabi-v7a、x86_64

## 产物

| 文件 | SHA-256 |
| --- | --- |
| SnapLink-release-1.8.0.apk | CCE4D064E2837DA7DB1BCFE4462E94683690E970CAD30455C2ED5984A2E30FB3 |
| SnapLink-release-1.8.0-arm64-v8a.apk | 11AC6AC82B7B4A9E599114172EB70694367E80E85997C9B6652906C1A7B679AA |
| SnapLink-symbols-1.8.0-arm64.zip | 70A7598CEBE27B6BC48639451B20477F9A676C2B59D43B9D6A56E7AC89C62331 |

## 验证状态

- `dart analyze lib`：无 error / warning（仅存量 info lint）
- `flutter test`：294 项全部通过
- APK 打包信息与 native-code 已用 aapt2 核对
- 真机验证（USB PTP、4K/30、HEVC 10-bit、HLG/N-Log、抽帧耗时、内存峰值）尚未进行：环境无 Android 设备连接
