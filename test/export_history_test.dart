import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';

void main() {
  group('ExportHistoryManager 本地历史导出管理器测试', () {
    final manager = ExportHistoryManager();

    test('cleanBaseName 文件名主干提取测试', () {
      expect(manager.isExported('DSC_0001'), isFalse);
      
      // 注册 DSC_0001.JPG
      manager.registerExported('DSC_0001.JPG');
      expect(manager.isExported('DSC_0001'), isTrue);
      expect(manager.isExported('DSC_0001.NEF'), isTrue);
      expect(manager.isExported('dsc_0001'), isTrue);
    });

    test('ExportedMediaItem 属性与格式角标测试', () {
      final tempFile = File('dummy.jpg');
      final item = ExportedMediaItem(
        file: tempFile,
        fileName: 'DSC_0002.NEF',
        baseName: 'DSC_0002',
        size: 25 * 1024 * 1024,
        modifiedTime: DateTime(2026, 10, 6, 15, 30),
      );

      expect(item.isRaw, isTrue);
      expect(item.formatBadge, equals('RAW'));
      expect(item.sizeFormatted, equals('25.0 MB'));
      expect(item.dateFormatted, equals('2026.10.06 15:30'));
    });
  });
}
