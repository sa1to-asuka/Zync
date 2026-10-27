import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/nikon_ble_lss.dart';

/// BLE LSS 载荷解析的离线测试。
///
/// BLE 入口默认隐藏；这些测试只验证纯数据编解码，不需要相机或厂商二进制。
void main() {
  test('解析 ConnectionConfiguration (0x2004) 的 SSID / 密码 / 加密方式', () {
    final raw = List<int>.filled(98, 0);
    raw[0] = 1; // hasWifi
    final ssid = 'NIKON_Z_8'.codeUnits;
    for (var i = 0; i < ssid.length; i++) {
      raw[1 + i] = ssid[i];
    }
    final password = 'password123'.codeUnits;
    for (var i = 0; i < password.length; i++) {
      raw[33 + i] = password[i];
    }
    raw[97] = 1; // WPA2

    final config = NikonBleLss.parseConnectionConfiguration(
      Uint8List.fromList(raw),
    );
    expect(config, isNotNull);
    expect(config!.ssid, equals('NIKON_Z_8'));
    expect(config.password, equals('password123'));
    expect(config.encryptMode, equals(1));
    expect(config.isOpen, isFalse);
  });

  test('没有 Wi-Fi 配置时返回 null', () {
    final raw = Uint8List(98);
    expect(NikonBleLss.parseConnectionConfiguration(raw), isNull);
  });

  test('构建开启/关闭 Wi-Fi AP 的控制指令', () {
    expect(
      NikonBleLss.buildWifiControlCommand(enable: true).toList(),
      equals([1, 1, 0, 0]),
    );
    expect(
      NikonBleLss.buildWifiControlCommand(enable: false).toList(),
      equals([1, 2, 0, 0]),
    );
  });

  test('构建时间同步载荷（7 字节小端）', () {
    final payload = NikonBleLss.buildCurrentTimePayload(
      DateTime(2026, 10, 18, 9, 30, 15),
    );
    expect(payload.length, equals(7));
    final data = ByteData.sublistView(payload);
    expect(data.getUint16(0, Endian.little), equals(2026));
    expect(payload[2], equals(10));
    expect(payload[3], equals(18));
    expect(payload[4], equals(9));
    expect(payload[5], equals(30));
    expect(payload[6], equals(15));
  });

  test('构建 41 字节 0x2007 经纬度定位载荷（对齐 furble / nsg GeoPayloadGenerator）', () {
    // 对齐 nsg GeoPayloadGeneratorTest: lat=37.4219983, lon=-122.084, alt=5
    final payload = NikonBleLss.buildLocationPayload(
      latitude: 37.4219983,
      longitude: -122.084,
      altitudeMeters: 5.0,
      satellites: 6,
      utcTime: DateTime.utc(2026, 10, 18, 12, 0, 0),
    );
    expect(payload.length, equals(41));
    final bd = ByteData.sublistView(payload);
    expect(bd.getUint16(0, Endian.little), equals(0x007F));
    // Latitude: 'N', 37°, 25', 31, 98
    expect(String.fromCharCode(payload[2]), equals('N'));
    expect(payload[3], equals(37));
    expect(payload[4], equals(25));
    expect(payload[5], equals(31));
    // Longitude: 'W', 122°, 5', 4, 0
    expect(String.fromCharCode(payload[7]), equals('W'));
    expect(payload[8], equals(122));
    expect(payload[9], equals(5));
    expect(payload[10], equals(4));
    // Satellites & 'P' & altitude
    expect(payload[12], equals(6));
    expect(String.fromCharCode(payload[13]), equals('P'));
    expect(bd.getInt16(14, Endian.little), equals(5));
    // Valid flag & WGS-84
    expect(payload[24], equals(0x01));
    expect(String.fromCharCodes(payload.sublist(25, 31)), equals('WGS-84'));
    // 10 zero padding bytes
    expect(payload.sublist(31, 41).every((b) => b == 0), isTrue);
  });

  test('经纬度十进制与度分秒解析与格式化', () {
    final dms = NikonBleLss.formatCoordinatesDms(31.230416, 121.473701);
    expect(dms, contains('31°13\''));
    expect(dms, contains('N'));
    expect(dms, contains('121°28\''));
    expect(dms, contains('E'));

    expect(
      NikonBleLss.tryParseCoordinate('31.230416', isLatitude: true),
      closeTo(31.230416, 1e-6),
    );
    expect(
      NikonBleLss.tryParseCoordinate('31°13\'49"S', isLatitude: true),
      closeTo(-(31 + 13 / 60 + 49 / 3600), 1e-4),
    );
    expect(
      NikonBleLss.tryParseCoordinate('95.0', isLatitude: true),
      isNull,
      reason: '超出纬度范围 [-90, 90] 应拒绝',
    );
  });
}
