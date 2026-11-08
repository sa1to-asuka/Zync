import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 磁盘日志：把内存里的诊断日志落盘，便于崩溃后导出。
///
/// 这里刻意「永不抛异常」：日志系统自己崩掉比没有日志更糟。
/// 所有 IO 失败都静默吞掉，界面侧通过返回值判断是否成功。
class AppLogFileStore {
  static final AppLogFileStore instance = AppLogFileStore._();
  AppLogFileStore._();

  static const int _maxBytes = 1024 * 1024;
  static const String _logName = 'zync.log';
  static const String _rotatedName = 'zync.1.log';

  Directory? _directory;
  File? _file;
  IOSink? _sink;
  final List<String> _buffer = <String>[];
  Timer? _flushTimer;
  bool _enabled = true;

  bool get isReady => _file != null;
  String? get logPath => _file?.path;

  /// 测试时降低噪声。
  void setEnabled(bool value) => _enabled = value;

  Future<void> init({Directory? directoryOverride}) async {
    try {
      final Directory directory;
      if (directoryOverride != null) {
        directory = directoryOverride;
      } else {
        final docs = await getApplicationDocumentsDirectory();
        directory = Directory(
          '${docs.path}${Platform.pathSeparator}zync_logs',
        );
      }
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _directory = directory;

      final file =
          File('${directory.path}${Platform.pathSeparator}$_logName');
      if (await file.exists() && await file.length() > _maxBytes) {
        await _rotate(directory);
      }
      _file = file;
      _sink = file.openWrite(mode: FileMode.append);
    } catch (_) {
      _sink = null;
      _file = null;
    }
  }

  Future<void> _rotate(Directory directory) async {
    try {
      final current =
          File('${directory.path}${Platform.pathSeparator}$_logName');
      final rotated =
          File('${directory.path}${Platform.pathSeparator}$_rotatedName');
      if (await rotated.exists()) await rotated.delete();
      if (await current.exists()) await current.rename(rotated.path);
    } catch (_) {}
  }

  void append(String line) {
    if (!_enabled || _sink == null) return;
    _buffer.add(line);
    _flushTimer ??= Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => flush(),
    );
    if (_buffer.length >= 200) flush();
  }

  Future<void> flush() async {
    final sink = _sink;
    if (sink == null || _buffer.isEmpty) return;
    final pending = List<String>.from(_buffer);
    _buffer.clear();
    try {
      for (final line in pending) {
        sink.writeln(line);
      }
      await sink.flush();
    } catch (_) {
      // 写盘失败时丢弃这批日志，避免无限堆积。
    }
  }

  /// 把当前日志导出成一个可分享的文本文件。没有日志时返回 `null`。
  Future<File?> exportBundle({
    String? appVersion,
    String? deviceSummary,
  }) async {
    final directory = _directory;
    if (directory == null) return null;

    await flush();
    try {
      final source =
          File('${directory.path}${Platform.pathSeparator}$_logName');
      final rotated =
          File('${directory.path}${Platform.pathSeparator}$_rotatedName');
      final parts = <String>[];
      if (await rotated.exists()) parts.add(await rotated.readAsString());
      if (await source.exists()) parts.add(await source.readAsString());
      final body = parts.join();
      if (body.trim().isEmpty) return null;

      final buffer = StringBuffer()
        ..writeln('Zync diagnostic log')
        ..writeln('exported: ${DateTime.now().toIso8601String()}');
      if (appVersion != null) buffer.writeln('version: $appVersion');
      if (deviceSummary != null) buffer.writeln('device: $deviceSummary');
      buffer
        ..writeln('---')
        ..write(body);

      final target = File(
        '${directory.path}${Platform.pathSeparator}'
        'Zync-logs-${_timestamp(DateTime.now())}.txt',
      );
      await target.writeAsString(buffer.toString(), flush: true);
      return target;
    } catch (_) {
      return null;
    }
  }

  String _timestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  Future<void> dispose() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
    try {
      await _sink?.close();
    } catch (_) {}
    _sink = null;
    _file = null;
    _directory = null;
  }
}
