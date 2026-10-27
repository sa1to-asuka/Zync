import 'dart:typed_data';

/// 尼康 LSS (Link Sub-System) 蓝牙 GATT 常量与编解码器。
///
/// Nikon BLE 服务的 UUID 与载荷布局。
/// 本文件只包含协议常量与解析逻辑，不打包任何厂商闭源库；BLE 入口默认隐藏，
/// 在真机验证前不会作为正式连接方式开放。
class NikonBleLss {
  NikonBleLss._();

  // ==========================================
  // 1. GATT UUID 定义（全小写标准格式）
  // ==========================================
  static const String serviceLss = "0000de00-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charAuthentication =
      "00002000-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charPowerControl = "00002001-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charClientDeviceName =
      "00002002-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charServerDeviceName =
      "00002003-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charConnectionConfiguration =
      "00002004-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charConnectionEstablishment =
      "00002005-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charCurrentTime = "00002006-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLocationInformation =
      "00002007-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssControlPoint =
      "00002008-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssFeature = "00002009-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charBatteryLevel = "00002a19-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssSerialNumber =
      "0000200b-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssCategoryInfo =
      "00002080-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssStatusForCapture =
      "00002081-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charLssStatusForControl =
      "00002020-3dd4-4255-8d62-6dc7b9bd5561";
  static const String charControlPointForControl =
      "00002021-3dd4-4255-8d62-6dc7b9bd5561";

  // ==========================================
  // 2. 指令构建器
  // ==========================================

  /// 构建命令相机开启 Wi-Fi AP 的 Control Point 指令 (写入 0x2008)
  /// [subCmd]: 1=启动 Wi-Fi, 2=关闭 Wi-Fi
  static Uint8List buildWifiControlCommand({required bool enable}) {
    return Uint8List.fromList([
      0x01, // 命令类目: Wi-Fi 启停
      enable ? 0x01 : 0x02, // 1: 开启, 2: 关闭
      0x00, 0x00 // 保留字段
    ]);
  }

  /// 当前会话预设的拍摄经纬度（由连接页定位注入或手动设置，供无 GPS 照片快捷复用）
  static double? sessionLatitude;
  static double? sessionLongitude;
  static double? sessionAltitude;

  /// 构建时间同步指令 (写入 0x2006)
  static Uint8List buildCurrentTimePayload([DateTime? time]) {
    final t = time ?? DateTime.now();
    final bb = BytesBuilder();
    final bd = ByteData(7);
    bd.setUint16(0, t.year, Endian.little);
    bd.setUint8(2, t.month);
    bd.setUint8(3, t.day);
    bd.setUint8(4, t.hour);
    bd.setUint8(5, t.minute);
    bd.setUint8(6, t.second);
    bb.add(bd.buffer.asUint8List());
    return bb.toBytes();
  }

  /// 构建 41 字节尼康 BLE 地理定位载荷 (写入 0x2007 charLocationInformation)
  ///
  /// 协议布局对齐 gkoh/furble (MIT) 与 hurui200320/nsg 的 0x2007 LocationInformation 规范：
  /// - [0..1]   : Header 0x007F (uint16 LE)
  /// - [2..6]   : 纬度方向 ('N'/'S') + 度 + 分 + 百分之一分高位 + 百分之一分低位
  /// - [7..11]  : 经度方向 ('E'/'W') + 度 + 分 + 百分之一分高位 + 百分之一分低位
  /// - [12]     : 卫星颗数 (默认 6)
  /// - [13]     : 海拔基准 ('P' = 正海拔)
  /// - [14..15] : 海拔高度（米，int16 LE）
  /// - [16..22] : 7 字节 UTC 时间 (年 uint16 LE, 月, 日, 时, 分, 秒)
  /// - [23]     : 百分之一秒 (0)
  /// - [24]     : 有效标志 0x01
  /// - [25..30] : 大地基准面 ASCII "WGS-84" (6 字节)
  /// - [31..40] : 10 字节 0x00 保留填充
  static Uint8List buildLocationPayload({
    required double latitude,
    required double longitude,
    double altitudeMeters = 0.0,
    int satellites = 6,
    DateTime? utcTime,
  }) {
    final clampedLat = latitude.clamp(-90.0, 90.0);
    final clampedLon = longitude.clamp(-180.0, 180.0);
    final utc = (utcTime ?? DateTime.now()).toUtc();

    final latDms = _decimalToNikonCoord(clampedLat, 'N', 'S');
    final lonDms = _decimalToNikonCoord(clampedLon, 'E', 'W');

    final out = Uint8List(41);
    final bd = ByteData.sublistView(out);

    // Header 0x007F (LE: 0x7F, 0x00)
    bd.setUint16(0, 0x007F, Endian.little);

    // Latitude (5 bytes)
    out[2] = latDms.directionCode;
    out[3] = latDms.degrees;
    out[4] = latDms.minutes;
    out[5] = latDms.submin1;
    out[6] = latDms.submin2;

    // Longitude (5 bytes)
    out[7] = lonDms.directionCode;
    out[8] = lonDms.degrees;
    out[9] = lonDms.minutes;
    out[10] = lonDms.submin1;
    out[11] = lonDms.submin2;

    // Satellites & Altitude
    out[12] = satellites.clamp(0, 99);
    out[13] = 0x50; // 'P'
    bd.setInt16(14, altitudeMeters.round().clamp(-32768, 32767), Endian.little);

    // 7-byte UTC Timestamp + subseconds
    bd.setUint16(16, utc.year, Endian.little);
    out[18] = utc.month;
    out[19] = utc.day;
    out[20] = utc.hour;
    out[21] = utc.minute;
    out[22] = utc.second;
    out[23] = 0; // subseconds

    // Valid flag + "WGS-84" + 10-byte zero padding
    out[24] = 0x01;
    const datum = [0x57, 0x47, 0x53, 0x2D, 0x38, 0x34]; // "WGS-84"
    out.setRange(25, 31, datum);
    // 31..40 默认已为 0
    return out;
  }

  static ({
    int directionCode,
    int degrees,
    int minutes,
    int submin1,
    int submin2,
  }) _decimalToNikonCoord(
    double decimal,
    String posDir,
    String negDir,
  ) {
    final dir = decimal < 0 ? negDir : posDir;
    final absVal = decimal.abs();
    final deg = absVal.floor();
    final minFull = (absVal - deg) * 60.0;
    final min = minFull.floor();
    final sub1Full = (minFull - min) * 100.0;
    final sub1 = sub1Full.floor();
    final sub2Full = (sub1Full - sub1) * 100.0;
    final sub2 = sub2Full.floor();
    return (
      directionCode: dir.codeUnitAt(0),
      degrees: deg,
      minutes: min,
      submin1: sub1,
      submin2: sub2,
    );
  }

  /// 将十进制经纬度格式化为标准度分秒展示文案，如 `31°13'49"N  121°28'25"E`
  static String formatCoordinatesDms(double latitude, double longitude) {
    return '${formatSingleCoordDms(latitude, isLatitude: true)}  '
        '${formatSingleCoordDms(longitude, isLatitude: false)}';
  }

  static String formatSingleCoordDms(
    double value, {
    required bool isLatitude,
  }) {
    final dir = isLatitude
        ? (value >= 0 ? 'N' : 'S')
        : (value >= 0 ? 'E' : 'W');
    final absVal = value.abs();
    final deg = absVal.floor();
    final minFull = (absVal - deg) * 60.0;
    final min = minFull.floor();
    final sec = ((minFull - min) * 60.0).round().clamp(0, 59);
    return '$deg°${min.toString().padLeft(2, '0')}\'${sec.toString().padLeft(2, '0')}"$dir';
  }

  /// 解析用户输入的十进制或度分秒经纬度字符串（例如 `31.2304`、`31.2304 N`、`31°13'49"N`）
  static double? tryParseCoordinate(String raw, {bool isLatitude = false}) {
    final text = raw.trim().toUpperCase();
    if (text.isEmpty) return null;
    final negative = text.contains('S') || text.contains('W') || text.startsWith('-');
    final nums = RegExp(r'\d+(?:\.\d+)?')
        .allMatches(text)
        .map((m) => double.tryParse(m.group(0)!))
        .whereType<double>()
        .toList();
    if (nums.isEmpty) return null;
    double result;
    if (nums.length >= 3) {
      result = nums[0] + nums[1] / 60.0 + nums[2] / 3600.0;
    } else if (nums.length == 2) {
      result = nums[0] + nums[1] / 60.0;
    } else {
      result = nums[0];
    }
    if (negative) result = -result;
    final maxAbs = isLatitude ? 90.0 : 180.0;
    if (result.abs() > maxAbs) return null;
    return result;
  }

  // ==========================================
  // 3. 载荷解码器 (读取 0x2004 ConnectionConfiguration)
  // ==========================================

  /// 解码读取到的相机 Wi-Fi AP 凭证
  static NikonBleWifiConfig? parseConnectionConfiguration(Uint8List rawBytes) {
    if (rawBytes.length < 98) return null;

    final mask = rawBytes[0];
    final hasWifi = (mask & 0x01) > 0;
    if (!hasWifi) return null;

    // SSID 位于 1..32 (32 字节以 Null 结尾)
    final ssidBytes = rawBytes.sublist(1, 33);
    final ssid = _decodeNullTerminatedAscii(ssidBytes);

    // 密码位于 33..96 (64 字节以 Null 结尾)
    final pwdBytes = rawBytes.sublist(33, 97);
    final password = _decodeNullTerminatedAscii(pwdBytes);

    // 加密类型位于 97
    final encryptCode = rawBytes[97];

    return NikonBleWifiConfig(
      ssid: ssid,
      password: password,
      encryptMode: encryptCode,
    );
  }

  static String _decodeNullTerminatedAscii(Uint8List bytes) {
    int end = bytes.indexOf(0);
    if (end < 0) end = bytes.length;
    final sub = bytes.sublist(0, end);
    return String.fromCharCodes(sub.where((c) => c >= 32 && c <= 126)).trim();
  }
}

/// 相机 Wi-Fi 配置信息模型
class NikonBleWifiConfig {
  final String ssid;
  final String password;
  final int encryptMode; // 0=Open, 1=WPA2, 2=WPA3, 3=WPA2/WPA3

  const NikonBleWifiConfig({
    required this.ssid,
    required this.password,
    required this.encryptMode,
  });

  bool get isOpen => encryptMode == 0 || password.isEmpty;

  @override
  String toString() =>
      'NikonBleWifiConfig(ssid: $ssid, isOpen: $isOpen, security: $encryptMode)';
}
