import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/exif_helper.dart';
import '../filter/photo_filter.dart';
import 'watermark_painter.dart';
import 'watermark_template.dart';

/// 渲染导出的文件与元数据结果
class ExportResult {
  final File file;
  final int width;
  final int height;
  final int byteLength;

  const ExportResult({
    required this.file,
    required this.width,
    required this.height,
    required this.byteLength,
  });
}

/// 水印与胶片调色高清离线光栅化导出引擎
class WatermarkRenderer {
  WatermarkRenderer._();

  /// 在后台利用 PictureRecorder 离线合成高清带水印图片并保存至本地文件。
  ///
  /// 输出为高质量 JPEG（默认 92）：此前固定输出 PNG，会把 10MB 的 JPG 撑到 20MB+；
  /// JPEG 与来源格式一致，成品体积回到与原片接近的量级。
  static Future<ExportResult> exportWatermarkedPhoto({
    required ui.Image sourceImage,
    required PhotoMetadata metadata,
    required WatermarkTemplate template,
    PhotoFilterType filterType = PhotoFilterType.original,
    double filterIntensity = 1.0,
    PhotoEditAdjustments adjustments = const PhotoEditAdjustments(),
    double spacingScale = 1.0,
    bool showDetails = true,
    bool cardDark = false,
    bool textDark = false,
    Color? cardColorOverride,
    Color? textColorOverride,
    double titleTextScale = 1.0,
    double metaTextScale = 1.0,
    double letterSpacingScale = 1.0,
    double lineSpacingScale = 1.0,
    WatermarkFontWeight fontWeight = WatermarkFontWeight.auto,
    double borderThicknessScale = 1.0,
    String? fontFamily,
    int quarterTurns = 0,
    bool mirrorX = false,
    int jpegQuality = 92,
    List<String> customLines = const [],
    double customTextScale = 1.0,
    ui.Image? logoImage,
    double logoScale = 0.16,
    double logoOpacity = 1.0,
    Color accentColor = const Color(0xFFFFD100),
    WatermarkCardTone cardTone = WatermarkCardTone.auto,
    double cornerRadiusFactor = 1.0,
    bool showModel = true,
    bool showLens = true,
    bool showExposure = true,
    bool showDate = true,
    bool showBrandLogo = true,
    bool showGps = true,
    double watermarkOpacity = 1.0,
    WatermarkTextAlign customTextAlign = WatermarkTextAlign.left,
    WatermarkLogoCorner logoCorner = WatermarkLogoCorner.bottomRight,
    bool writeExif = true,
  }) async {
    final rotated = quarterTurns % 2 != 0;
    final srcW = rotated ? sourceImage.height.toDouble() : sourceImage.width.toDouble();
    final srcH = rotated ? sourceImage.width.toDouble() : sourceImage.height.toDouble();

    // 1. 精确计算目标排版物理像素总宽高 (含边框与展签留白)
    final layout = WatermarkCanvasPainter.computeLayout(srcW, srcH, template, spacingScale);
    final targetW = layout.totalWidth.round();
    final targetH = layout.totalHeight.round();

    // 2. 离线 Canvas 高保真光栅化记录
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, layout.totalWidth, layout.totalHeight));

    final painter = WatermarkCanvasPainter(
      image: sourceImage,
      metadata: metadata,
      template: template,
      filterType: filterType,
      filterIntensity: filterIntensity,
      adjustments: adjustments,
      spacingScale: spacingScale,
      showDetails: showDetails,
      cardDark: cardDark,
      textDark: textDark,
      cardColorOverride: cardColorOverride,
      textColorOverride: textColorOverride,
      titleTextScale: titleTextScale,
      metaTextScale: metaTextScale,
      letterSpacingScale: letterSpacingScale,
      lineSpacingScale: lineSpacingScale,
      fontWeight: fontWeight,
      borderThicknessScale: borderThicknessScale,
      fontFamily: fontFamily,
      quarterTurns: quarterTurns,
      mirrorX: mirrorX,
      customLines: customLines,
      customTextScale: customTextScale,
      logoImage: logoImage,
      logoScale: logoScale,
      logoOpacity: logoOpacity,
      accentColor: accentColor,
      cardTone: cardTone,
      cornerRadiusFactor: cornerRadiusFactor,
      showModel: showModel,
      showLens: showLens,
      showExposure: showExposure,
      showDate: showDate,
      showBrandLogo: showBrandLogo,
      showGps: showGps,
      watermarkOpacity: watermarkOpacity,
      customTextAlign: customTextAlign,
      logoCorner: logoCorner,
    );

    // 绘制完整合成图
    painter.paint(canvas, Size(layout.totalWidth, layout.totalHeight));

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(targetW, targetH);

    // 取原始像素后在独立 isolate 里编码 JPEG：
    // 24MP 大图纯 Dart 编码约需 1~3 秒，放在主 isolate 会冻结界面。
    final Uint8List bytes;
    try {
      final rgba = await renderedImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) {
        throw Exception('水印图片光栅化失败');
      }
      bytes = await _encodeJpegInIsolate(
        rgba,
        targetW,
        targetH,
        jpegQuality,
        writeExif ? _buildExif(metadata, targetW, targetH) : null,
      );
    } finally {
      renderedImage.dispose();
      picture.dispose();
    }

    // MediaStore 写入前只使用临时文件。
    final saveDir = await getTemporaryDirectory();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Zync_${metadata.cameraModel.replaceAll(' ', '_')}_$timestamp.jpg';
    final outFile = File('${saveDir.path}/$fileName');
    await outFile.writeAsBytes(bytes, flush: true);

    return ExportResult(
      file: outFile,
      width: targetW,
      height: targetH,
      byteLength: bytes.length,
    );
  }

  /// 在独立 isolate 中把 RGBA 像素编码成 JPEG。
  /// 用 TransferableTypedData 传递像素缓冲，避免 24MP 图再拷贝一份（约 96MB）。
  static Future<Uint8List> _encodeJpegInIsolate(
    ByteData rgba,
    int width,
    int height,
    int quality,
    img.ExifData? exif,
  ) {
    final transferable = TransferableTypedData.fromList([
      rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
    ]);
    return Isolate.run(() {
      final pixels = transferable.materialize().asUint8List();
      final frame = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      if (exif != null) frame.exif = exif;
      return img.encodeJpg(frame, quality: quality.clamp(1, 100));
    });
  }

  /// 用画面上的拍摄参数生成输出 EXIF。
  ///
  /// 尺寸与方向按成品写入（像素已按编辑结果烘焙），避免看图软件二次旋转；
  /// 机身 / 镜头 / 时间 / 光圈 / 快门 / ISO / 焦距 与用户在水印里看到的一致。
  static img.ExifData _buildExif(PhotoMetadata m, int width, int height) {
    final exif = img.ExifData();
    exif.imageIfd[0x0100] = img.IfdValueLong(width); // ImageWidth
    exif.imageIfd[0x0101] = img.IfdValueLong(height); // ImageLength
    exif.imageIfd[0x0112] = img.IfdValueShort(1); // Orientation = 1
    if (m.cameraMake.isNotEmpty) {
      exif.imageIfd[0x010F] = img.IfdValueAscii(m.cameraMake);
    }
    if (m.cameraModel.isNotEmpty) {
      exif.imageIfd[0x0110] = img.IfdValueAscii(m.cameraModel);
    }
    final date = _exifDate(m.capturedDate);
    if (date != null) {
      exif.imageIfd[0x0132] = img.IfdValueAscii(date); // DateTime
      exif.exifIfd[0x9003] = img.IfdValueAscii(date); // DateTimeOriginal
    }
    final exposure = _parseExposure(m.shutterSpeed);
    if (exposure != null) {
      exif.exifIfd[0x829A] = img.IfdValueRational(exposure[0], exposure[1]);
    }
    final fNumber = _parseNumber(m.aperture);
    if (fNumber != null) {
      exif.exifIfd[0x829D] = img.IfdValueRational((fNumber * 10).round(), 10);
    }
    final iso = _parseInt(m.iso);
    if (iso != null) exif.exifIfd[0x8827] = img.IfdValueShort(iso);
    final focal = _parseNumber(m.focalLength);
    if (focal != null) {
      exif.exifIfd[0x920A] = img.IfdValueRational((focal * 10).round(), 10);
    }
    if (m.lensModel.isNotEmpty) {
      exif.exifIfd[0xA434] = img.IfdValueAscii(m.lensModel);
    }
    if (m.latitude != null && m.longitude != null) {
      final lat = m.latitude!.clamp(-90.0, 90.0);
      final lon = m.longitude!.clamp(-180.0, 180.0);
      exif.gpsIfd[0x0001] = img.IfdValueAscii(lat >= 0 ? 'N' : 'S');
      exif.gpsIfd[0x0002] = _decimalToGpsRational(lat.abs());
      exif.gpsIfd[0x0003] = img.IfdValueAscii(lon >= 0 ? 'E' : 'W');
      exif.gpsIfd[0x0004] = _decimalToGpsRational(lon.abs());
      if (m.altitude != null) {
        final alt = m.altitude!;
        exif.gpsIfd[0x0005] = img.IfdByteValue(alt < 0 ? 1 : 0);
        exif.gpsIfd[0x0006] =
            img.IfdValueRational((alt.abs() * 100).round(), 100);
      }
    }
    return exif;
  }

  static img.IfdValueRational _decimalToGpsRational(double absDeg) {
    final deg = absDeg.floor();
    final minFull = (absDeg - deg) * 60.0;
    final min = minFull.floor();
    final secHundredths = ((minFull - min) * 6000.0).round().clamp(0, 5999);
    return img.IfdValueRational.list([
      img.IfdValueRational(deg, 1).toRational(),
      img.IfdValueRational(min, 1).toRational(),
      img.IfdValueRational(secHundredths, 100).toRational(),
    ]);
  }

  /// '2026.10.06 14:32' / '2026-10-06 14:32' → '2026:10:06 14:32:00'
  static String? _exifDate(String raw) {
    final match = RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})[ T](\d{1,2}):(\d{2})')
        .firstMatch(raw.trim());
    if (match == null) return null;
    String two(String v) => v.padLeft(2, '0');
    return '${match.group(1)}:${two(match.group(2)!)}:${two(match.group(3)!)} '
        '${two(match.group(4)!)}:${match.group(5)}:00';
  }

  /// '1/250s' → [1, 250]；'2s' → [2, 1]
  static List<int>? _parseExposure(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[sS]$'), '');
    final parts = text.split('/');
    if (parts.length == 2) {
      final n = int.tryParse(parts[0].trim());
      final d = int.tryParse(parts[1].trim());
      if (n != null && d != null && n > 0 && d > 0) return [n, d];
      return null;
    }
    final v = double.tryParse(text);
    if (v == null || v <= 0) return null;
    return [(v * 1000).round(), 1000];
  }

  static double? _parseNumber(String raw) {
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static int? _parseInt(String raw) {
    final match = RegExp(r'(\d+)').firstMatch(raw);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// 辅助方法：从原始字节快速解码 ui.Image
  static Future<ui.Image> decodeImageFromBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try { return (await codec.getNextFrame()).image; } finally { codec.dispose(); }
  }
}