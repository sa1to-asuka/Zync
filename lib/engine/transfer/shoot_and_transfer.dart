import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/settings/app_settings.dart';
import '../../protocol/camera_driver.dart';
import 'download_manager.dart';

/// 边拍边传 (Shoot & Transfer) 自动化任务控制器
class ShootAndTransferController extends ChangeNotifier {
  final CameraDriver driver;
  final DownloadManager downloadManager;

  StreamSubscription<CameraFileItem>? _subscription;
  int _transferredCount = 0;

  ShootAndTransferController({
    required this.driver,
    required this.downloadManager,
  }) {
    _lastEnabled = AppSettings.instance.shootAndTransferEnabled;
    AppSettings.instance.addListener(_onSettingsChanged);
    _syncSubscription();
  }

  bool _lastEnabled = false;

  /// 开关状态存在设置里：主页开关、设置页开关、应用内快门都读同一个值，
  /// 重启后也不会莫名其妙自己打开。
  bool get isEnabled => AppSettings.instance.shootAndTransferEnabled;
  bool get transferRaw => AppSettings.instance.downloadRaw;
  int get transferredCount => _transferredCount;

  set transferRaw(bool value) {
    AppSettings.instance.setDownloadRaw(value);
    notifyListeners();
  }

  /// 开启边拍边传
  void enable() => setEnabled(true);

  /// 关闭边拍边传
  void disable() => setEnabled(false);

  void setEnabled(bool value) {
    AppSettings.instance.setShootAndTransferEnabled(value);
    // AppSettings 会通知 _onSettingsChanged，由它同步订阅与界面。
  }

  void toggle() => setEnabled(!isEnabled);

  void _onSettingsChanged() {
    // AppSettings 会因为水印滑条等无关设置频繁通知，
    // 只有「边拍边传」本身变了才需要同步订阅与刷新界面。
    final enabled = isEnabled;
    if (enabled == _lastEnabled) return;
    _lastEnabled = enabled;
    _syncSubscription();
    notifyListeners();
  }

  void _syncSubscription() {
    final enabled = isEnabled;
    if (enabled && _subscription == null) {
      _subscription = driver.onPhotoCaptured.listen(_handleNewPhoto);
    } else if (!enabled && _subscription != null) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  /// 应用内快门拍到的照片。
  ///
  /// 与「相机事件」走同一条策略：开关关着就不传，没勾选 RAW 就跳过 RAW。
  /// 之前拍摄台直接调用下载队列，绕过了这里，导致关掉边拍边传照样回传。
  void handleCaptured(CameraFileItem file) => _handleNewPhoto(file);

  void _handleNewPhoto(CameraFileItem file) {
    if (!isEnabled) return;

    // 如果未勾选传输 RAW，且该文件为 NEF/RAW，则跳过
    if (!AppSettings.instance.downloadRaw && file.isRaw) {
      return;
    }

    _transferredCount++;
    downloadManager.enqueue(file);
    if (!_disposed) notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    AppSettings.instance.removeListener(_onSettingsChanged);
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
