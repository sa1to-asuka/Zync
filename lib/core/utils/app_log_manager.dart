import 'dart:async';

/// 全局协议与硬件通信日志管理器 (统一在「设置」页集中展示与诊断)
class AppLogManager {
  static final AppLogManager instance = AppLogManager._();
  AppLogManager._();

  final List<String> _logs = [];
  final StreamController<String> _controller = StreamController<String>.broadcast();

  List<String> get logs => List.unmodifiable(_logs);
  Stream<String> get onLog => _controller.stream;

  void add(String msg) {
    final entry = '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg';
    _logs.insert(0, entry);
    if (_logs.length > 300) _logs.removeLast();
    _controller.add(entry);
  }

  void clear() {
    _logs.clear();
  }
}
