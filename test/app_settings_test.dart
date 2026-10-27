import 'dart:typed_data';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/settings/app_settings.dart';
import 'package:zync/core/utils/lru_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings 默认值与归一化', () {
    setUp(() => AppSettings.instance.resetForTest());

    test('默认值', () {
      expect(AppSettings.instance.powerThreshold, equals(15));
      expect(AppSettings.instance.powerProtectionEnabled, isTrue);
      expect(AppSettings.instance.downloadRaw, isFalse);
      expect(AppSettings.instance.cameraIp, equals('192.168.0.1'));
      expect(AppSettings.instance.cameraPort, equals(15740));
      expect(AppSettings.instance.themeMode, equals(AppThemeMode.system));
      expect(AppSettings.instance.confirmDelete, isTrue);
    });

    test('删除确认开关可切换', () {
      AppSettings.instance.setConfirmDelete(false);
      expect(AppSettings.instance.confirmDelete, isFalse);
      AppSettings.instance.setConfirmDelete(true);
      expect(AppSettings.instance.confirmDelete, isTrue);
    });

    test('外观模式切换并映射到 Material ThemeMode', () {
      AppSettings.instance.setThemeMode(AppThemeMode.light);
      expect(AppSettings.instance.themeMode, equals(AppThemeMode.light));
      expect(AppSettings.instance.materialThemeMode, equals(ThemeMode.light));

      AppSettings.instance.setThemeMode(AppThemeMode.dark);
      expect(AppSettings.instance.themeMode, equals(AppThemeMode.dark));
      expect(AppSettings.instance.materialThemeMode, equals(ThemeMode.dark));

      AppSettings.instance.setThemeMode(AppThemeMode.system);
      expect(AppSettings.instance.materialThemeMode, equals(ThemeMode.system));
    });

    test('非法阈值被归一化到合法集合', () {
      AppSettings.instance.setPowerThreshold(99);
      expect(
          AppSettings.powerThresholdOptions
              .contains(AppSettings.instance.powerThreshold),
          isTrue);
    });

    test('相机端口拒绝非法值', () {
      AppSettings.instance.setCameraPort(0);
      expect(AppSettings.instance.cameraPort, equals(15740));
      AppSettings.instance.setCameraPort(70000);
      expect(AppSettings.instance.cameraPort, equals(15740));
      AppSettings.instance.setCameraPort(15741);
      expect(AppSettings.instance.cameraPort, equals(15741));
    });

    test('PTP/IP 客户端 GUID 稳定且为 16 字节', () {
      final first = AppSettings.instance.ptpClientGuidBytes;
      final second = AppSettings.instance.ptpClientGuidBytes;
      expect(first.length, equals(16));
      expect(second, equals(first));
      expect(AppSettings.instance.ptpClientGuid.length, equals(32));
    });
  });

  group('LruImageCache 容量约束与跨卡槽键', () {
    test('超过 maxEntries 时淘汰最久未使用项', () {
      final cache = LruImageCache(maxEntries: 2, maxBytes: 1 << 30);
      cache['a'] = Uint8List.fromList([1]);
      cache['b'] = Uint8List.fromList([2]);
      expect(cache['a'], isNotNull);
      cache['c'] = Uint8List.fromList([3]);
      expect(cache.containsKey('b'), isFalse, reason: 'b 应被淘汰');
      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('c'), isTrue);
    });

    test('超过 maxBytes 时按字节淘汰', () {
      final cache = LruImageCache(maxEntries: 100, maxBytes: 10);
      cache['a'] = Uint8List(6);
      cache['b'] = Uint8List(6);
      expect(cache.containsKey('a'), isFalse);
      expect(cache.containsKey('b'), isTrue);
    });

    test('cameraCacheKey 组合 storageId 与 handle', () {
      expect(cameraCacheKey(0x00010001, 100), equals('65537_100'));
      expect(cameraCacheKey(0x00020002, 100),
          isNot(equals(cameraCacheKey(0x00010001, 100))));
    });
  });
}
