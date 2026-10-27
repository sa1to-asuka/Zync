# Zync

<p align="center">
  <img src="assets/icons/zync_logo.svg" width="112" height="112" alt="Zync logo" />
</p>

<p align="center">
  <strong>Nikon Z-series transfer, wireless tethering, and watermark studio.</strong>
</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="README.zh-CN.md">简体中文</a> |
  <a href="README.ja.md">日本語</a>
</p>

Zync is an open-source Flutter application built around a focused workflow for Nikon Z-series cameras: connect to the camera, browse and transfer photos, then finish and export them with a watermark or color treatment. It is designed to work directly with the camera over Wi-Fi PTP/IP or USB PTP without requiring a vendor account, cloud service, or proprietary SDK.

- Project: <https://github.com/sa1to-asuka/Zync>
- Version: `1.0.0`
- License: MIT
- Primary platform: Android

## Highlights

| Area | What Zync provides |
| --- | --- |
| Camera connection | Wi-Fi PTP/IP and USB PTP over OTG |
| Camera browsing | JPG, NEF, and NRW browsing with embedded RAW previews |
| Transfer | Chunked downloads, transfer queue, pause, cancel, retry, and auto-transfer |
| Watermark studio | 11 templates, EXIF data, custom text, logo overlays, and quality controls |
| Photo finishing | Color presets, exposure and tone controls, crop, rotate, compare, and collage |
| Adaptive interface | Bottom navigation on phones and a navigation rail on larger screens |
| Updates | GitHub Releases checks with SHA-256 verification before installation |

## Connection modes

### Wi-Fi PTP/IP

Join the access point created by the camera, then connect from Zync. The Wi-Fi transport uses separate command and event TCP channels, configurable port and heartbeat settings, and a keep-alive path intended to prevent the camera from sleeping during a session.

### USB PTP

Connect the camera with a USB OTG cable and select the camera's PTP mode. Zync uses the Android USB Host API to open a standard Still Image session, browse the camera, receive events, and download files. USB transfers use the same queue and export history as Wi-Fi transfers.

### Bluetooth LSS

The Bluetooth Low Energy LSS path is experimental and hidden by default. It is not required for normal Wi-Fi or USB transfer.

## Features

### Camera gallery

- Browse camera storage and preview JPG, NEF, and NRW files.
- Extract an embedded JPEG preview from RAW files when a full RAW decode is unnecessary.
- Download one file or select multiple files for batch export.
- Show file type, size, and exported state to reduce duplicate downloads.
- Apply EXIF orientation and browse large images with pinch zoom, double-tap zoom, and pull-to-close gestures.
- Delete local or camera-side items when supported by the connected camera.
- Create collages from selected photos.

### Transfer engine

- Use `GetPartialObject` for streaming downloads in 4 MB chunks.
- Continue large photo and RAW downloads without blocking the rest of the interface.
- Manage every task in the Transfer Center with progress, failure details, pause, resume, cancel, retry, and completed-task cleanup.
- Keep transfers alive in the background with a foreground service and progress notification.
- Listen for `ObjectAdded` events to implement optional capture-to-phone auto-transfer.
- Save exported photos under `/DCIM/Zync` and maintain export history.

### Watermark studio

- Choose from 11 gallery-oriented watermark layouts, including blurred borders, Polaroid paper, dark glass, editorial caption, film perforation, gradient caption, and minimal line styles.
- Adjust border scale, accent color, card color, corner radius, opacity, typography, and spacing.
- Toggle camera model, lens, exposure settings, and capture date independently.
- Read EXIF values and populate watermark fields automatically.
- Add up to two custom text lines and a logo image from the gallery.
- Export a high-quality JPEG at 95, 92, or 85 quality.
- Write dimensions, orientation, camera, lens, exposure, focal length, and timestamp back to the exported EXIF block.

### Color and editing

- Apply film-inspired color groups and classic stock looks.
- Fine-tune exposure, contrast, highlights, shadows, temperature, tint, saturation, sharpness, vignette, and grain.
- Combine color edits with a watermark template in the same export flow.
- Compare the edited result with the original before saving.

### Responsive interface and navigation

- Dark and light themes with system-theme support.
- Bottom navigation on narrow phone layouts and a left navigation rail at 600 dp and above.
- Consistent back behavior: close top-level editors and dialogs first, then leave selection modes, return to the Connect tab, and require a second back action before exiting.

## Workflow

1. Enable Wi-Fi on the Nikon Z camera or connect it by USB OTG.
2. Open **Connect** and establish a PTP/IP or USB PTP session.
3. Open **Camera Gallery**, select files, and add them to the transfer queue.
4. Open **Watermark Studio** to apply a template, edits, and optional custom branding.
5. Export the finished JPEG to the phone.

## Compatibility

- Intended for Nikon Z-series mirrorless cameras.
- Android 7.0 (API 24) or later.
- Wi-Fi mode requires the phone to join the access point created by the camera.
- USB mode requires OTG support and a camera that exposes a standard PTP Still Image interface with Bulk IN/OUT endpoints.
- Behavior can vary by camera model, firmware, cable, and Android USB controller. Real-device feedback is welcome.
- iOS and desktop targets have not been fully validated.

Zync is an independent third-party project. It is not affiliated with Nikon, does not use a Nikon proprietary SDK, and uses the Nikon and Z-series names only to describe compatibility. All trademarks belong to their respective owners.

## Requirements

- Flutter with Dart 3.0 or later. The project declares Flutter 3.10 or later.
- Android SDK with compile SDK 36.
- JDK 17.
- Android NDK `28.2.13676358` for the native RAW processing module.

## Getting started

```bash
git clone https://github.com/sa1to-asuka/Zync.git
cd Zync
flutter pub get
flutter run
```

## Build

Build a universal release APK:

```bash
flutter build apk --release
```

The output is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Build an ARM64-only package with separate debug symbols:

```bash
flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols/1.0.0-arm64
```

The output is:

```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Keep the generated symbols with the matching APK so crash reports can be symbolized later. Do not install a debug build for normal use.

### Windows build path

Flutter release AOT builds can fail when the project path contains non-ASCII characters. If `gen_snapshot` reports an error such as `Unable to read file: ...app.dill`, copy the project to an ASCII-only path and build again:

```powershell
robocopy . D:\zync_ascii /E /XD build .dart_tool .git
cd D:\zync_ascii
flutter build apk --release
```

### Release signing

If `android/key.properties` is absent, the build falls back to debug signing for local testing. Configure a release keystore before distributing an APK:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

Fill in the generated passwords and paths in `android/key.properties`. Both the properties file and `*.jks` files are ignored by Git.

### Release assets and update integrity

Zync checks releases at <https://github.com/sa1to-asuka/Zync/releases>. Publish the APK and a SHA-256 file with a matching name:

```text
Zync-release-1.0.0.apk
Zync-release-1.0.0.apk.sha256
```

The checksum file should contain the APK hash and filename:

```text
<sha256>  Zync-release-1.0.0.apk
```

The in-app updater verifies the checksum before installation and refuses to install a mismatched file.

### Tests and analysis

```bash
flutter test
flutter analyze
```

## Project layout

```text
zync/
├── assets/icons/              Application icon assets
├── android/                   Android host, USB PTP, BLE, and native RAW module
├── lib/
│   ├── core/                  Constants, settings, theme, and utilities
│   ├── protocol/              PTP/IP, USB PTP, and camera driver layers
│   ├── engine/                Transfer, editing, watermark, video, and update logic
│   └── ui/                    Screens, widgets, and adaptive navigation
├── test/                      Unit and widget tests
├── docs/                      Protocol and release notes
└── pubspec.yaml
```

The protocol, engine, and UI layers are kept separate. Camera access is exposed through driver interfaces so that additional transports or camera-specific behavior can be added without coupling it to the interface layer.

## Protocol references

The Wi-Fi and USB transports follow the public Picture Transfer Protocol model:

- ISO 15740 / PIMA 15740 for PTP operations, datasets, responses, and USB Bulk-Only containers.
- [gPhoto PTP/IP documentation](http://www.gphoto.org/doc/ptpip.php) for PTP/IP packet types, handshake behavior, and data-phase layout.
- [Android USB Host API](https://developer.android.com/guide/topics/connectivity/usb/host) for USB device discovery, interfaces, endpoints, and bulk transfers.
- [libgphoto2](https://github.com/gphoto/libgphoto2) as a public reference for PTP/IP and Nikon operation behavior.

`docs/protocol-sources.md` contains additional implementation notes. Zync does not copy third-party source code into its protocol implementation.

## Open-source acknowledgements

Thank you to the maintainers and contributors of the projects below. Each project remains the property of its authors and is governed by its own license.

### Core projects and protocol references

| Project | Purpose | License |
| --- | --- | --- |
| [ImageToolbox](https://github.com/T8RIN/ImageToolbox) | Image processing, filters, and editor interaction reference | Apache-2.0 |
| [Recipe Lab](https://github.com/voxivoid/recipe-lab-sony-pmca) | Color-recipe and film-look data structure reference | GPL-3.0 |
| [SnapBridge-Enhanced](https://github.com/MXWF0/SnapBridge-Enhanced) | Nikon connection flow and interaction reference | No license file currently declared |
| [nsg](https://github.com/hurui200320/nsg) | Nikon protocol and device-capability reference | AGPL-3.0 |
| [libgphoto2](https://github.com/gphoto/libgphoto2) | PTP/IP and Nikon operation-code reference | LGPL-2.1 |
| [ptplibrary](https://github.com/laheller/ptplibrary) | PTP/IP and USB PTP behavior reference | No license file currently declared |
| [ptpip](https://github.com/mmattes/ptpip) | PTP/IP implementation reference | Apache-2.0 |
| [libptp](https://github.com/Fimagena/libptp) | PTP/IP and USB PTP implementation reference | LGPL-2.1 |
| [NikonCopy](https://github.com/Zephyrion-Yuan/NikonCopy) | Android USB OTG PTP file-access reference | No license file currently declared |
| [furble](https://github.com/gkoh/furble) | Nikon BLE shutter behavior reference | MIT |
| [nikongeotag](https://github.com/rjmendez/nikongeotag) | Nikon BLE smart-device protocol reference | GPL-3.0 |

### Runtime and foundational dependencies

| Project | Purpose | License |
| --- | --- | --- |
| [Flutter](https://github.com/flutter/flutter) | Cross-platform UI and runtime | BSD-3-Clause |
| [Dart SDK](https://github.com/dart-lang/sdk) | Dart language and runtime | BSD-3-Clause |
| [LibRaw](https://github.com/LibRaw/LibRaw) | Camera RAW decoding | LGPL-2.1 / CDDL-1.0 |
| [AndroidX Media3](https://github.com/androidx/media) | Video playback, frame extraction, and editing | Apache-2.0 |
| [Kotlin](https://github.com/JetBrains/kotlin) | Android native language and runtime | Apache-2.0 |
| [flutter_svg](https://github.com/dnfield/flutter_svg) | SVG rendering | MIT |
| [image](https://github.com/brendan-duncan/image) | Image encoding and processing | MIT |
| [exif](https://github.com/bigflood/dartexif) | EXIF metadata reading and writing | MIT |
| [crypto](https://github.com/dart-lang/crypto) | SHA-256 and digest algorithms | BSD-3-Clause |
| [intl](https://github.com/dart-lang/i18n) | Internationalization and date formatting | BSD-3-Clause |
| [path_provider](https://github.com/flutter/packages/tree/main/packages/path_provider) | Platform directory resolution | BSD-3-Clause |
| [video_player](https://github.com/flutter/packages/tree/main/packages/video_player) | Video playback support | BSD-3-Clause |

The same acknowledgement data is available in the app under **Settings → About Zync → Project & Licenses → Open-source Acknowledgements**. Projects without a declared license are listed for transparency and are not described as open source.

## License

Zync is released under the [MIT License](LICENSE). Issues and pull requests are welcome at <https://github.com/sa1to-asuka/Zync>.
