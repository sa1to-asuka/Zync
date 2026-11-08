import 'dart:async';

import 'app_log_file_store.dart';

/// 全局协议与硬件通信日志管理器 (统一在「设置」页集中展示与诊断)
class AppLogManager {
  static final AppLogManager instance = AppLogManager._();
  AppLogManager._();

  final List<String> _logs = [];
  final StreamController<String> _controller =
      StreamController<String>.broadcast();

  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get onLog => _controller.stream;

  void add(String msg) {
    final entry = '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg';
    _logs.insert(0, entry);
    if (_logs.length > 300) _logs.removeLast();
    if (!_controller.isClosed) _controller.add(entry);
    AppLogFileStore.instance.append(entry);
  }

  /// 记录未捕获异常。崩溃信息必须带上来源与堆栈，否则日志没有诊断价值。
  void addError(Object error, StackTrace? stack, {String source = ''}) {
    final tag = source.isEmpty ? 'ERROR' : 'ERROR/$source';
    add('[$tag] $error');
    if (stack != null) {
      final lines = stack.toString().trim().split('\n');
      for (final line in lines.take(20)) {
        add('[$tag]   $line');
      }
    }
  }

  void clear() {
    _logs.clear();
  }
}
