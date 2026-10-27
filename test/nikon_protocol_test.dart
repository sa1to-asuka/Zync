import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/nikon_ble_lss.dart';
import 'package:zync/protocol/nikon_driver.dart';

void main() {
  group('Nikon BLE LSS 凭证解析验证', () {
    test('解析 ConnectionConfiguration (0x2004) Wi-Fi SSID 与密码', () {
      final payload = Uint8List(128);
      payload[0] = 0x01; // hasWifiSetting = true

      // 写入 SSID: "NIKON_Z6III_TEST"
      const ssidStr = "NIKON_Z6III_TEST";
      for (int i = 0; i < ssidStr.length; i++) {
        payload[1 + i] = ssidStr.codeUnitAt(i);
      }

      // 写入密码: "nikon12345"
      const pwdStr = "nikon12345";
      for (int i = 0; i < pwdStr.length; i++) {
        payload[33 + i] = pwdStr.codeUnitAt(i);
      }

      payload[97] = 1; // WPA2

      final config = NikonBleLss.parseConnectionConfiguration(payload);
      expect(config, isNotNull);
      expect(config!.ssid, equals("NIKON_Z6III_TEST"));
      expect(config.password, equals("nikon12345"));
      expect(config.encryptMode, equals(1));
      expect(config.isOpen, isFalse);
    });

    test('构建 BLE 开启 Wi-Fi AP 控制指令', () {
      final cmd = NikonBleLss.buildWifiControlCommand(enable: true);
      expect(cmd.length, equals(4));
      expect(cmd[0], equals(0x01));
      expect(cmd[1], equals(0x01)); // 开启
    });
  });

  group('尼康机型与卡槽架构识别测试', () {
    test('Nikon Z 30 机型归一化识别与单卡槽判定', () {
      expect(NikonDeviceInfo.normalizeModelName('NIKON Z 30'),
          equals('NIKON Z 30'));
      expect(NikonDeviceInfo.normalizeModelName('Z30'), equals('NIKON Z 30'));
      expect(NikonDeviceInfo.normalizeModelName('NIKON DSC Z 30'),
          equals('NIKON Z 30'));
      expect(NikonDeviceInfo.normalizeModelName('NIKON_Z_30_1024'),
          equals('NIKON Z 30'));

      expect(NikonDeviceInfo.normalizeModelName('Z fc'), equals('NIKON Z fc'));
      expect(NikonDeviceInfo.normalizeModelName('Z50'), equals('NIKON Z 50'));
      expect(
          NikonDeviceInfo.normalizeModelName('NIKON Z 8'), equals('NIKON Z 8'));
    });

    test('JPEG 缩略图完整性结构校验（拒绝半截/无 SOF/无 SOS 的损坏缩略图）', () {
      // 完整最小 JPEG 结构：SOI (FF D8) + SOF0 (FF C0, len=11) + SOS (FF DA, len=8) + 扫描数据 + EOI (FF D9)
      final validJpeg = Uint8List.fromList([
        0x00, 0x11, // 前导头噪声
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x04, 0x4A, 0x46, // APP0
        0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x10, 0x00, 0x10, 0x01, 0x01, 0x11,
        0x00, // SOF0
        0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, // SOS
        ...List<int>.filled(160, 0x42), // Entropy scan data (>= 128 bytes)
        0xFF, 0xD9, // EOI
      ]);
      final extracted = NikonDriver.extractValidJpegSlice(validJpeg);
      expect(extracted, isNotNull);
      expect(extracted!.first, equals(0xFF));
      expect(extracted[1], equals(0xD8));
      expect(extracted[extracted.length - 2], equals(0xFF));
      expect(extracted.last, equals(0xD9));

      // 截断的半截 JPEG（无 EOI FF D9）必须返回 null，防止渲染出灰块花屏缩略图
      final truncatedJpeg = validJpeg.sublist(0, validJpeg.length - 2);
      expect(NikonDriver.extractValidJpegSlice(truncatedJpeg), isNull);

      // 仅有 SOI + EOI 但没有 SOF/SOS 的伪 JPEG 片段必须返回 null
      final fakeJpeg = Uint8List.fromList([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9]);
      expect(NikonDriver.extractValidJpegSlice(fakeJpeg), isNull);
    });
  });
}
