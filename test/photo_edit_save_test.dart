import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';

void main() {
  group('ExportedMediaItem 编辑状态识别', () {
    test('_edit 后缀识别为另存', () {
      final item = ExportedMediaItem(
        file: File('x.jpg'),
        fileName: 'DSC_0001_edit_1.jpg',
        baseName: 'DSC_0001_EDIT_1',
        size: 1,
        modifiedTime: DateTime(2026, 10, 10),
      );
      expect(item.isSavedAsCopy, isTrue);
      expect(item.isOverwritten, isFalse);
    });

    test('普通导出既不是另存也不是覆盖', () {
      final item = ExportedMediaItem(
        file: File('x.jpg'),
        fileName: 'DSC_0001.JPG',
        baseName: 'DSC_0001',
        size: 1,
        modifiedTime: DateTime(2026, 10, 10),
      );
      expect(item.isSavedAsCopy, isFalse);
      expect(item.isOverwritten, isFalse);
    });

    test('isOverwritten 为 true 时标记覆盖', () {
      final item = ExportedMediaItem(
        file: File('x.jpg'),
        fileName: 'DSC_0001.JPG',
        baseName: 'DSC_0001',
        size: 1,
        modifiedTime: DateTime(2026, 10, 10),
        isOverwritten: true,
      );
      expect(item.isOverwritten, isTrue);
      expect(item.isSavedAsCopy, isFalse);
    });
  });

}
