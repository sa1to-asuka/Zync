import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/settings/app_settings.dart';
import '../../protocol/camera_driver.dart';
import 'download_manager.dart';

/// 边拍边传 (Shoot & Transfer) 自动化任务控制器
class ShootAndTransferController extends ChangeNotifier {
  final CameraDriver driver;
  final DownloadManager downloadManager;

  bool _isEnabled = false;
  StreamSubscription<CameraFileItem>? _subscription;
  int _transferredCount = 0;

  ShootAndTransferController({
    required this.driver,
    required this.downloadManager,
  });

  bool get isEnabled => _isEnabled;
  bool get transferRaw => AppSettings.instance.downloadRaw;
  int get transferredCount => _transferredCount;

  set transferRaw(bool value) {
    AppSettings.instance.setDownloadRaw(value);
    notifyListeners();
  }

  /// 开启边拍边传
  void enable() {
    if (_isEnabled) return;
    _isEnabled = true;
    _subscription = driver.onPhotoCaptured.listen(_handleNewPhoto);
    notifyListeners();
  }

  /// 关闭边拍边传
  void disable() {
    _isEnabled = false;
    _subscription?.cancel();
    _subscription = null;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (value) {
      enable();
    } else {
      disable();
    }
  }

  void toggle() {
    if (_isEnabled) {
      disable();
    } else {
      enable();
    }
  }

  void _handleNewPhoto(CameraFileItem file) {
    if (!_isEnabled) return;

    // 如果未勾选传输 RAW，且该文件为 NEF/RAW，则跳过
    if (!AppSettings.instance.downloadRaw && file.isRaw) {
      return;
    }

    _transferredCount++;
    downloadManager.enqueue(file);
    notifyListeners();
  }

  @override
  void dispose() {
    disable();
    super.dispose();
  }
}
