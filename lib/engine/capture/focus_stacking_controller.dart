import 'package:flutter/foundation.dart';

import '../../protocol/camera_driver.dart' show CameraFileItem, MfDirection;

/// 焦点堆叠运行状态。
enum FocusStackState { idle, running, completed, stopped, failed }

/// A→B 总跨度 [totalSpan] 步，想拍 [shotCount] 张时每张应走的步数。
int stepForSpan(int totalSpan, int shotCount) {
  if (shotCount < 2) return totalSpan.abs().clamp(1, 32767);
  final span = totalSpan.abs();
  return (span / (shotCount - 1)).round().clamp(1, 32767);
}

/// 每张走 [step] 步、总跨度 [totalSpan] 时能拍多少张。
int shotsForSpan(int totalSpan, int step) {
  if (step <= 0) return 1;
  return (totalSpan.abs() ~/ step) + 1;
}

/// 一次焦点堆叠的配置。
class FocusStackConfig {
  const FocusStackConfig({
    required this.shotCount,
    required this.step,
    this.direction = MfDirection.far,
    this.settle = const Duration(milliseconds: 300),
    this.returnToStart = false,
  });

  final int shotCount;

  /// 每次移动的对焦步数（`0x9204` 的第二个参数）。
  final int step;
  final MfDirection direction;
  final Duration settle;

  /// 拍完把对焦环退回起点，方便重复拍同一组。
  final bool returnToStart;
}

/// 相机侧需要的最小能力。
abstract class FocusStackPort {
  bool get isConnected;

  /// 驱动对焦马达。返回 false 表示已到行程尽头（`0xA00C`）。
  Future<bool> drive(MfDirection direction, int steps);

  /// 触发一次快门，返回落盘后的文件（未确认时返回 null）。
  Future<CameraFileItem?> capture();
  Future<void> settle(Duration duration);
}

/// 焦点堆叠控制器：按固定步长推进 + 逐张拍摄。
///
/// 不做机内景深合成，只负责把焦点平面均匀地扫一遍；合成交给桌面端
/// （Helicon / PS）。每张照片会带同一个批次号，便于在相册里成组查看。
class FocusStackingController extends ChangeNotifier {
  FocusStackingController({required this.port});

  final FocusStackPort port;

  FocusStackState _state = FocusStackState.idle;
  FocusStackState get state => _state;

  FocusStackConfig? _config;
  FocusStackConfig? get config => _config;

  int _current = 0;
  int get currentShot => _current;
  int get totalShots => _config?.shotCount ?? 0;

  bool _stopRequested = false;
  bool _hitEnd = false;

  /// 本次序列拍到的文件，用于结束后可选合成。
  final List<CameraFileItem> _captured = <CameraFileItem>[];
  List<CameraFileItem> get capturedFiles => List.unmodifiable(_captured);

  /// 中途撞到对焦行程尽头时为 true：实际张数会少于设定值。
  bool get hitFocusEnd => _hitEnd;

  bool get isActive => _state == FocusStackState.running;

  Future<bool> start(FocusStackConfig config) async {
    if (isActive) return false;
    if (!port.isConnected) return false;
    if (config.shotCount <= 0) return false;

    _config = config;
    _current = 0;
    _stopRequested = false;
    _hitEnd = false;
    _captured.clear();
    _state = FocusStackState.running;
    notifyListeners();

    var taken = 0;
    try {
      while (taken < config.shotCount) {
        if (_stopRequested) break;
        _current = taken;
        notifyListeners();

        final file = await port.capture();
        if (file != null) _captured.add(file);
        taken++;

        if (taken >= config.shotCount) break;
        if (_stopRequested) break;

        final moved = await port.drive(config.direction, config.step);
        if (!moved) {
          // 到行程尽头：继续拍只会得到一串完全相同的照片。
          _hitEnd = true;
          break;
        }
        await port.settle(config.settle);
      }
    } catch (_) {
      _state = FocusStackState.failed;
    } finally {
      if (config.returnToStart && taken > 1 && !_hitEnd) {
        final backSteps = config.step * (taken - 1);
        try {
          await port.drive(
            config.direction == MfDirection.far
                ? MfDirection.near
                : MfDirection.far,
            backSteps.clamp(1, 32767),
          );
        } catch (_) {}
      }
      if (_state == FocusStackState.running) {
        _state =
            _stopRequested ? FocusStackState.stopped : FocusStackState.completed;
      }
      _current = taken;
      notifyListeners();
    }
    return true;
  }

  void stop() {
    if (!isActive) return;
    _stopRequested = true;
    notifyListeners();
  }

  void reset() {
    if (isActive) return;
    _state = FocusStackState.idle;
    _config = null;
    _current = 0;
    _hitEnd = false;
    notifyListeners();
  }
}
