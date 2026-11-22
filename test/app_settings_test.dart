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
      expect(AppSettings.instance.galleryFilter, equals('unviewed'));
    });

    test('相册筛选记忆切换', () {
      AppSettings.instance.setGalleryFilter('all');
      expect(AppSettings.instance.galleryFilter, equals('all'));
      AppSettings.instance.setGalleryFilter('synced');
      expect(AppSettings.instance.galleryFilter, equals('synced'));
      AppSettings.instance.setGalleryFilter('   ');
      expect(AppSettings.instance.galleryFilter, equals('synced'),
          reason: '空白值被安全忽略');
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

  group('自定义保存文件夹', () {
    setUp(() => AppSettings.instance.resetForTest());

    test('默认目录是 Zync', () {
      expect(AppSettings.instance.exportFolder, equals('Zync'));
      expect(AppSettings.defaultExportFolder, equals('Zync'));
    });

    test('归一化：去空白、统一分隔符、去掉 DCIM 前缀', () {
      expect(AppSettings.normalizeExportFolder('  Zync/星空  '), 'Zync/星空');
      expect(AppSettings.normalizeExportFolder('DCIM/Zync/星空'), 'Zync/星空');
      expect(AppSettings.normalizeExportFolder(r'Zync\星空'), 'Zync/星空');
      expect(AppSettings.normalizeExportFolder('Zync//星空/'), 'Zync/星空');
    });

    test('归一化：拒绝路径穿越与空值', () {
      expect(AppSettings.normalizeExportFolder('../evil'), 'evil');
      expect(AppSettings.normalizeExportFolder('..'), 'Zync');
      expect(AppSettings.normalizeExportFolder('   '), 'Zync');
      expect(AppSettings.normalizeExportFolder('/'), 'Zync');
    });

    test('归一化：非法字符替换、层级截断', () {
      expect(AppSettings.normalizeExportFolder('a:b'), 'a_b');
      expect(
        AppSettings.normalizeExportFolder('a/b/c/d/e'),
        'a/b/c',
        reason: '最多三层，避免 MediaStore 里出现过深目录',
      );
    });

    test('设置后会进入最近使用列表并去重', () {
      AppSettings.instance.setExportFolder('Zync/星空');
      expect(AppSettings.instance.exportFolder, 'Zync/星空');
      expect(AppSettings.instance.recentExportFolders.first, 'Zync/星空');

      AppSettings.instance.setExportFolder('Zync');
      expect(AppSettings.instance.recentExportFolders.first, 'Zync');
      expect(
        AppSettings.instance.recentExportFolders
            .where((f) => f == 'Zync')
            .length,
        1,
      );
    });

    test('最近列表最多保留 8 项', () {
      for (var i = 0; i < 12; i++) {
        AppSettings.instance.setExportFolder('Zync/f$i');
      }
      expect(AppSettings.instance.recentExportFolders.length, 8);
      expect(AppSettings.instance.recentExportFolders.first, 'Zync/f11');
    });
  });

  group('局域网连接记忆', () {
    setUp(() => AppSettings.instance.resetForTest());

    test('默认值', () {
      expect(AppSettings.instance.staLanHost, isEmpty);
      expect(AppSettings.instance.staLanPort, 15740);
      expect(AppSettings.instance.lastLinkMethod, 'hotspot');
    });

    test('保存相机 IP、端口与连接方式', () {
      AppSettings.instance.setStaLanHost(' 192.168.43.23 ');
      AppSettings.instance.setStaLanPort(15741);
      AppSettings.instance.setLastLinkMethod('lan');

      expect(AppSettings.instance.staLanHost, '192.168.43.23');
      expect(AppSettings.instance.staLanPort, 15741);
      expect(AppSettings.instance.lastLinkMethod, 'lan');
    });

    test('局域网端口拒绝非法值', () {
      AppSettings.instance.setStaLanPort(0);
      expect(AppSettings.instance.staLanPort, 15740);
      AppSettings.instance.setStaLanPort(70000);
      expect(AppSettings.instance.staLanPort, 15740);
    });

    test('路由器与手机热点 STA 子模式独立记忆各自 IP', () {
      expect(AppSettings.instance.staSubMode, 'router');
      AppSettings.instance.setStaHostForSubMode('router', '192.168.1.88');
      AppSettings.instance.setStaSubMode('hotspot');
      AppSettings.instance.setStaHostForSubMode('hotspot', '192.168.43.23');

      expect(AppSettings.instance.staHostForSubMode('router'), '192.168.1.88');
      expect(
          AppSettings.instance.staHostForSubMode('hotspot'), '192.168.43.23');
      expect(AppSettings.instance.staSubMode, 'hotspot');
    });

    test('PTP/IP 客户端 GUID 校验导入与重置', () {
      expect(AppSettings.instance.setPtpClientGuid('not-valid'), isFalse);
      expect(AppSettings.instance.setPtpClientGuid('00112233'), isFalse);

      expect(
        AppSettings.instance.setPtpClientGuid(
            '00112233-4455-6677-8899-AABBCCDDEEFF'),
        isTrue,
      );
      expect(
        AppSettings.instance.ptpClientGuidHex,
        equals('00112233445566778899aabbccddeeff'),
      );
      expect(AppSettings.instance.ptpClientGuidBytes.first, equals(0x00));
      expect(AppSettings.instance.ptpClientGuidBytes.last, equals(0xFF));

      final next = AppSettings.instance.regeneratePtpClientGuid();
      expect(next.length, equals(32));
    });
  });
}
