import 'package:exif/exif.dart';
import 'package:flutter/services.dart';
import '../../protocol/nikon_ble_lss.dart';
import 'capture_date.dart';

/// 照片拍摄元数据实体模型 (EXIF)
class PhotoMetadata {
  final String cameraMake;
  final String cameraModel;
  final String lensModel;
  final String shutterSpeed;
  final String aperture;
  final String iso;
  final String focalLength;
  final String capturedDate;
  final int orientation;
  final int width;
  final int height;
  final double? latitude;
  final double? longitude;
  final double? altitude;

  const PhotoMetadata({
    this.cameraMake = '',
    this.cameraModel = '',
    this.lensModel = '',
    this.shutterSpeed = '',
    this.aperture = '',
    this.iso = '',
    this.focalLength = '',
    this.capturedDate = '',
    this.orientation = 1,
    this.width = 6000,
    this.height = 4000,
    this.latitude,
    this.longitude,
    this.altitude,
  });

  /// 是否包含有效的相机或曝光信息
  bool get hasValidExif {
    return (cameraModel.isNotEmpty && cameraModel != 'Camera') ||
        shutterSpeed.isNotEmpty ||
        aperture.isNotEmpty ||
        iso.isNotEmpty;
  }

  /// 是否包含拍摄经纬度坐标
  bool get hasGps => latitude != null && longitude != null;

  /// 返回度分秒格式的拍摄经纬度: "31°13'49"N  121°28'25"E"
  String get gpsSummary {
    if (!hasGps) return '';
    return NikonBleLss.formatCoordinatesDms(latitude!, longitude!);
  }

  /// 返回标题栏简洁格式: "NIKON Z 30"
  String get titleText {
    final make = cameraMake
        .replaceAll(
            RegExp(r'NIKON CORPORATION|NIKON', caseSensitive: false), 'NIKON')
        .trim();
    var model = cameraModel.trim();
    if (make.isNotEmpty && model.isNotEmpty) {
      model = model
          .replaceAll(RegExp(RegExp.escape(make), caseSensitive: false), '')
          .trim();
    }
    return '$make $model'.trim().toUpperCase();
  }

  /// 返回曝光核心四参数组合: "40mm · f/2.0 · 1/250s · ISO 100"
  String get exposureSummary {
    final parts = <String>[];
    if (focalLength.isNotEmpty) parts.add(focalLength);
    if (aperture.isNotEmpty) parts.add(aperture);
    if (shutterSpeed.isNotEmpty) parts.add(shutterSpeed);
    if (iso.isNotEmpty) parts.add(iso);
    return parts.join(' · ');
  }

  /// 返回空格等宽分隔的曝光参数 (对标 build_apk: "40mm  f/2.0  1/250s  ISO 100")
  String get exposureMonospace {
    final parts = <String>[];
    if (focalLength.isNotEmpty) parts.add(focalLength);
    if (aperture.isNotEmpty) parts.add(aperture);
    if (shutterSpeed.isNotEmpty) parts.add(shutterSpeed);
    if (iso.isNotEmpty) parts.add(iso);
    return parts.join('   ');
  }

  PhotoMetadata copyWith({
    String? cameraMake,
    String? cameraModel,
    String? lensModel,
    String? shutterSpeed,
    String? aperture,
    String? iso,
    String? focalLength,
    String? capturedDate,
    int? orientation,
    int? width,
    int? height,
    double? latitude,
    double? longitude,
    double? altitude,
    bool clearGps = false,
  }) {
    return PhotoMetadata(
      cameraMake: cameraMake ?? this.cameraMake,
      cameraModel: cameraModel ?? this.cameraModel,
      lensModel: lensModel ?? this.lensModel,
      shutterSpeed: shutterSpeed ?? this.shutterSpeed,
      aperture: aperture ?? this.aperture,
      iso: iso ?? this.iso,
      focalLength: focalLength ?? this.focalLength,
      capturedDate: capturedDate ?? this.capturedDate,
      orientation: orientation ?? this.orientation,
      width: width ?? this.width,
      height: height ?? this.height,
      latitude: clearGps ? null : (latitude ?? this.latitude),
      longitude: clearGps ? null : (longitude ?? this.longitude),
      altitude: clearGps ? null : (altitude ?? this.altitude),
    );
  }
}

/// EXIF 数据解析与格式化工具
class ExifHelper {
  ExifHelper._();

  static const MethodChannel _nativeChannel =
      MethodChannel('com.zync.app/native_camera');

  /// 从图像二进制字节中解析全套 EXIF 标签（含 GPS 经纬度与海拔）
  static Future<PhotoMetadata> parseBytes(Uint8List imageBytes) async {
    try {
      final tags = await readExifFromBytes(imageBytes);
      if (tags.isEmpty) {
        return PhotoMetadata(
          latitude: NikonBleLss.sessionLatitude,
          longitude: NikonBleLss.sessionLongitude,
          altitude: NikonBleLss.sessionAltitude,
        );
      }

      // 1. 提取相机制造商与机型
      var make = tags['Image Make']?.printable ?? '';
      var model = tags['Image Model']?.printable ?? '';

      make = make
          .replaceAll(
              RegExp(r'NIKON CORPORATION|NIKON', caseSensitive: false), 'Nikon')
          .trim();
      if (make.isNotEmpty) {
        model = model
            .replaceAll(RegExp(RegExp.escape(make), caseSensitive: false), '')
            .trim();
      } else {
        model = model.trim();
      }

      // 2. 提取镜头规格
      final lens = tags['EXIF LensModel']?.printable ??
          tags['EXIF LensSpecification']?.printable ??
          '';

      // 3. 提取曝光三要素
      final rawShutter = tags['EXIF ExposureTime']?.printable ?? '';
      final formattedShutter =
          rawShutter.isNotEmpty ? _formatShutterSpeed(rawShutter) : '';

      final rawAperture = tags['EXIF FNumber']?.printable ?? '';
      final formattedAperture =
          rawAperture.isNotEmpty ? _formatAperture(rawAperture) : '';

      final rawIso = tags['EXIF ISOSpeedRatings']?.printable ??
          tags['EXIF PhotographicSensitivity']?.printable ??
          '';
      final formattedIso = rawIso.isNotEmpty ? 'ISO $rawIso' : '';

      // 4. 焦距与拍摄时间
      final rawFocal = tags['EXIF FocalLength']?.printable ?? '';
      final formattedFocal =
          rawFocal.isNotEmpty ? _formatFocalLength(rawFocal) : '';

      final date = tags['EXIF DateTimeOriginal']?.printable ??
          tags['Image DateTime']?.printable ??
          '';
      final formattedDate = _formatDateTime(date);

      final orientation =
          tags['Image Orientation']?.values.toList().firstOrNull as int? ?? 1;

      // 5. 提取 GPS 经纬度与海拔（若照片无 GPS，则回退使用连接页预设的会话经纬度）
      final parsedLat = _parseGpsCoord(
            tags['GPS GPSLatitude'],
            tags['GPS GPSLatitudeRef']?.printable,
          ) ??
          NikonBleLss.sessionLatitude;
      final parsedLon = _parseGpsCoord(
            tags['GPS GPSLongitude'],
            tags['GPS GPSLongitudeRef']?.printable,
          ) ??
          NikonBleLss.sessionLongitude;
      final parsedAlt = _parseGpsAltitude(
            tags['GPS GPSAltitude'],
            tags['GPS GPSAltitudeRef']?.printable,
          ) ??
          NikonBleLss.sessionAltitude;

      return PhotoMetadata(
        cameraMake: make,
        cameraModel: model,
        lensModel: lens.trim(),
        shutterSpeed: formattedShutter,
        aperture: formattedAperture,
        iso: formattedIso,
        focalLength: formattedFocal,
        capturedDate: formattedDate,
        orientation: orientation,
        latitude: parsedLat,
        longitude: parsedLon,
        altitude: parsedAlt,
      );
    } catch (_) {
      return PhotoMetadata(
        latitude: NikonBleLss.sessionLatitude,
        longitude: NikonBleLss.sessionLongitude,
        altitude: NikonBleLss.sessionAltitude,
      );
    }
  }

  /// 调用原生 LocationManager 获取当前手机定位
  static Future<({double latitude, double longitude, double altitude})?>
      fetchPhoneLocation() async {
    try {
      final res =
          await _nativeChannel.invokeMethod<dynamic>('getCurrentLocation');
      if (res is Map && res['success'] == true) {
        final lat = (res['latitude'] as num?)?.toDouble();
        final lon = (res['longitude'] as num?)?.toDouble();
        final alt = (res['altitude'] as num?)?.toDouble() ?? 0.0;
        if (lat != null && lon != null) {
          return (latitude: lat, longitude: lon, altitude: alt);
        }
      }
    } catch (_) {}
    return null;
  }

  static double? _parseGpsCoord(IfdTag? coordTag, String? ref) {
    if (coordTag == null) return null;
    final values = coordTag.values.toList();
    if (values.length >= 3) {
      final deg = _ratioToDouble(values[0]);
      final min = _ratioToDouble(values[1]);
      final sec = _ratioToDouble(values[2]);
      if (deg != null && min != null && sec != null) {
        var result = deg + min / 60.0 + sec / 3600.0;
        final upperRef = (ref ?? '').trim().toUpperCase();
        if (upperRef == 'S' || upperRef == 'W') {
          result = -result;
        }
        return result;
      }
    }
    final isLat = (ref ?? '').toUpperCase().contains(RegExp(r'[NS]'));
    return NikonBleLss.tryParseCoordinate(
      '${coordTag.printable} ${ref ?? ''}',
      isLatitude: isLat,
    );
  }

  static double? _parseGpsAltitude(IfdTag? altTag, String? ref) {
    if (altTag == null) return null;
    final values = altTag.values.toList();
    if (values.isNotEmpty) {
      final val = _ratioToDouble(values.first);
      if (val != null) {
        return (ref != null && ref.trim() == '1') ? -val : val;
      }
    }
    return double.tryParse(altTag.printable.trim());
  }

  static double? _ratioToDouble(dynamic v) {
    if (v is Ratio) {
      if (v.denominator == 0) return 0.0;
      return v.numerator / v.denominator;
    }
    if (v is num) return v.toDouble();
    final str = v.toString();
    if (str.contains('/')) {
      final parts = str.split('/');
      final n = double.tryParse(parts[0]);
      final d = double.tryParse(parts[1]);
      if (n != null && d != null && d != 0) return n / d;
    }
    return double.tryParse(str);
  }

  static String _formatShutterSpeed(String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[sS]$'), '').trim();
    final val = _ratioToDouble(text);
    if (val != null && val > 0) {
      if (val >= 1.0) {
        return '${val.toStringAsFixed(val == val.roundToDouble() ? 0 : 1)}s';
      }
      return '1/${(1.0 / val).round()}s';
    }
    return '${raw}s';
  }

  static String _formatAperture(String raw) {
    if (raw.startsWith('f/') || raw.startsWith('F/')) return raw.toLowerCase();
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den != 0) {
        final f = num / den;
        return 'f/${f.toStringAsFixed(1)}';
      }
    }
    final val = double.tryParse(raw);
    if (val != null) {
      return 'f/${val.toStringAsFixed(1)}';
    }
    return 'f/$raw';
  }

  static String _formatFocalLength(String raw) {
    if (raw.endsWith('mm')) return raw;
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final num = double.tryParse(parts[0]);
      final den = double.tryParse(parts[1]);
      if (num != null && den != null && den != 0) {
        final f = num / den;
        return '${f.round()}mm';
      }
    }
    final val = double.tryParse(raw.replaceAll('mm', '').trim());
    if (val != null) {
      return '${val.round()}mm';
    }
    return '${raw}mm';
  }

  static String _formatDateTime(String raw) => formatCaptureDate(raw);
}
