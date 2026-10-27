import 'package:flutter/foundation.dart';

import '../../protocol/camera_native_bridge.dart';

/// 前台保活仲裁：多个传输任务共用同一个前台服务与通知，
/// 避免其中一个结束时把另一个的通知也一起清掉。
///
/// 规则：只要有任一来源处于活动状态，服务就保持运行；显示优先级 transfer > 其他。
class KeepAliveArbiter {
  KeepAliveArbiter._();

  static final KeepAliveArbiter instance = KeepAliveArbiter._();

  final Map<String, _KeepAliveSource> _sources = {};
  bool _running = false;
  bool _permissionRequested = false;
  String? _shownKey;

  /// 开始保活（重复调用只更新标题）。
  void acquire(String key, {required String title}) {
    _sources[key] = _KeepAliveSource(title: title);
    _sync();
  }

  /// 更新进度文案（未 acquire 过的 key 会被忽略）。
  void update(
    String key, {
    required int completed,
    required int total,
    bool paused = false,
  }) {
    final source = _sources[key];
    if (source == null) return;
    source.completed = completed;
    source.total = total;
    source.paused = paused;
    _sync();
  }

  /// 释放保活；全部释放后停止前台服务并清除通知。
  void release(String key) {
    if (_sources.remove(key) == null) return;
    _sync();
  }

  @visibleForTesting
  bool get isRunning => _running;

  @visibleForTesting
  void resetForTest() {
    _sources.clear();
    _running = false;
    _shownKey = null;
    _permissionRequested = false;
  }

  void _sync() {
    if (_sources.isEmpty) {
      if (_running) {
        _running = false;
        _shownKey = null;
        CameraNativeBridge.stopTransferKeepAlive();
      }
      return;
    }

    final key =
        _sources.containsKey('transfer') ? 'transfer' : _sources.keys.first;
    final source = _sources[key]!;

    if (!_permissionRequested) {
      _permissionRequested = true;
      CameraNativeBridge.requestNotificationPermission();
    }
    if (!_running || _shownKey != key) {
      _running = true;
      _shownKey = key;
      CameraNativeBridge.startTransferKeepAlive(source.title);
    }
    CameraNativeBridge.updateTransferKeepAlive(
      completed: source.completed,
      total: source.total,
      paused: source.paused,
    );
  }
}

class _KeepAliveSource {
  _KeepAliveSource({required this.title});

  final String title;
  int completed = 0;
  int total = 0;
  bool paused = false;
}
