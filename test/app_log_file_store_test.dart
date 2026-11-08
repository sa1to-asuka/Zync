import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/utils/app_log_file_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('zync_log_store_');
    AppLogFileStore.instance.setEnabled(true);
  });

  tearDown(() async {
    await AppLogFileStore.instance.dispose();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } on FileSystemException {
      // Windows 上句柄可能还没释放，交给系统临时目录清理。
    }
  });

  test('写入的日志会落盘并可导出', () async {
    final store = AppLogFileStore.instance;
    await store.init(directoryOverride: root);
    store.setEnabled(true);

    store.append('[12:00:00] hello');
    store.append('[12:00:01] world');
    await store.flush();

    final bundle = await store.exportBundle(
      appVersion: '2.5.0+12',
      deviceSummary: 'test-device',
    );

    expect(bundle, isNotNull);
    final text = await bundle!.readAsString();
    expect(text, contains('hello'));
    expect(text, contains('world'));
    expect(text, contains('2.5.0+12'));
    expect(text, contains('test-device'));
  });

  test('没有日志时导出返回 null', () async {
    final store = AppLogFileStore.instance;
    await store.init(directoryOverride: root);

    final bundle = await store.exportBundle();

    expect(bundle, isNull);
  });

  test('超过 1 MB 会在初始化时轮转', () async {
    final log = File('${root.path}${Platform.pathSeparator}zync.log');
    await log.writeAsString('x' * (1024 * 1024 + 10));

    final store = AppLogFileStore.instance;
    await store.init(directoryOverride: root);

    final rotated =
        File('${root.path}${Platform.pathSeparator}zync.1.log');
    expect(await rotated.exists(), isTrue);
    expect(await rotated.length(), greaterThan(1024 * 1024));
  });

  test('关闭后 append 不再写盘', () async {
    final store = AppLogFileStore.instance;
    await store.init(directoryOverride: root);
    store.setEnabled(false);
    store.append('[12:00:00] should be dropped');
    await store.flush();

    expect(await store.exportBundle(), isNull);
  });

  test('未初始化时导出返回 null 而不是抛异常', () async {
    final store = AppLogFileStore.instance;
    final bundle = await store.exportBundle();
    expect(bundle, isNull);
  });
}
