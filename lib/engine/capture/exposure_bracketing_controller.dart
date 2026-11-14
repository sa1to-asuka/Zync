import 'package:flutter/foundation.dart';

/// 包围曝光要偏移哪一轴。
enum BracketAxis { exposureCompensation, shutter, iso }

/// 拍摄顺序。
enum BracketOrder {
  /// 正常 → 偏暗 → 偏亮（`0, -, +`），后期挑片最顺手。
  normalFirst,

  /// 从暗到亮，适合做 HDR 合成时按顺序检查。
  darkToLight,
}

/// 包围曝光运行状态。
enum BracketState { idle, running, completed, stopped, failed }

/// 一次包围曝光的配置。
class ExposureBracketConfig {
  const ExposureBracketConfig({
    required this.axis,
    required this.shotCount,
    required this.step,
    this.order = BracketOrder.normalFirst,
    this.settle = const Duration(milliseconds: 300),
  });

  final BracketAxis axis;
  final int shotCount;

  /// 相邻两张之间跨几个档位（以相机属性档位表的下标为单位）。
  final int step;
  final BracketOrder order;

  /// 写入参数后到触发快门的稳定等待，防止机震。
  final Duration settle;
}

/// 相机侧需要的最小能力。
///
/// 单独抽接口：真实实现接 `ExposureSettingsController` + `CaptureController`，
/// 单测里换成纯内存实现。
abstract class BracketPort {
  bool get isConnected;

  /// `0xD0C0`：机身内置包围曝光是否已开启。开启时 App 再叠加会双重偏移。
  Future<int?> readBuiltInBracketing();

  /// 该轴可选的原始值，必须升序（越往后越亮）。
  Future<List<int>> optionsOf(BracketAxis axis);

  /// 当前值。
  Future<int?> currentOf(BracketAxis axis);

  /// 写入并回读校验；返回 false 表示相机没有接受这个值。
  Future<bool> write(BracketAxis axis, int raw);

  /// 触发一次快门。
  Future<void> capture();

  /// 等待相机稳定。
  Future<void> settle(Duration duration);
}

/// 生成包围曝光的取值序列（纯函数，便于单测）。
///
/// [anchorIndex] 是当前值在 [options] 里的下标；[step] 是相邻两张跨越的档位数。
/// 到达档位表两端时会截断并去重——与其把相机顶在极限值上重复拍同一档，
/// 不如少拍几张并在界面上说明。
List<int> buildBracketSequence({
  required List<int> options,
  required int anchorIndex,
  required int shotCount,
  required int step,
  BracketOrder order = BracketOrder.normalFirst,
}) {
  if (options.isEmpty || shotCount <= 0) return const <int>[];
  final anchor = anchorIndex.clamp(0, options.length - 1);
  final safeStep = step <= 0 ? 1 : step;

  final offsets = <int>[0];
  final half = shotCount ~/ 2;
  for (var i = 1; i <= half; i++) {
    offsets.add(-i * safeStep);
    offsets.add(i * safeStep);
  }
  if (shotCount.isEven && offsets.length > shotCount) {
    // 偶数张时宁可多拍一张偏亮的，也不要在两端各缺一半。
    offsets.add(half * safeStep);
  }

  final seen = <int>{};
  final values = <int>[];
  for (final offset in offsets.take(shotCount)) {
    final index = (anchor + offset).clamp(0, options.length - 1);
    if (!seen.add(index)) continue;
    values.add(options[index]);
  }

  if (order == BracketOrder.darkToLight) {
    values.sort();
  }
  return values;
}

/// 包围曝光控制器。
///
/// 关键约束：无论正常结束、用户停止还是中途异常，**必须**把参数还原成
/// 拍摄前的值，否则相机会带着一档偏移悄悄继续拍后面的照片。
class ExposureBracketingController extends ChangeNotifier {
  ExposureBracketingController({required this.port});

  final BracketPort port;

  BracketState _state = BracketState.idle;
  BracketState get state => _state;

  ExposureBracketConfig? _config;
  ExposureBracketConfig? get config => _config;

  List<int> _sequence = const <int>[];
  List<int> get sequence => _sequence;

  int _current = 0;
  int get currentShot => _current;
  int get totalShots => _sequence.length;

  bool _stopRequested = false;
  bool _restoreFailed = false;
  bool get restoreFailed => _restoreFailed;

  bool get isActive => _state == BracketState.running;

  /// 开始一次包围曝光。返回 false 表示被前置条件挡下。
  Future<bool> start(ExposureBracketConfig config) async {
    if (isActive) return false;
    if (!port.isConnected) return false;

    // 机身自己也在包围的话，叠加起来会得到完全失控的曝光。
    final builtIn = await port.readBuiltInBracketing();
    if (builtIn != null && builtIn != 0) {
      _state = BracketState.failed;
      notifyListeners();
      return false;
    }

    final options = await port.optionsOf(config.axis);
    if (options.length < 2) {
      _state = BracketState.failed;
      notifyListeners();
      return false;
    }
    final current = await port.currentOf(config.axis);
    final anchorIndex = current == null ? options.length ~/ 2 : options.indexOf(current);
    if (anchorIndex < 0) {
      _state = BracketState.failed;
      notifyListeners();
      return false;
    }

    final sequence = buildBracketSequence(
      options: options,
      anchorIndex: anchorIndex,
      shotCount: config.shotCount,
      step: config.step,
      order: config.order,
    );
    if (sequence.isEmpty) {
      _state = BracketState.failed;
      notifyListeners();
      return false;
    }

    _config = config;
    _sequence = sequence;
    _current = 0;
    _stopRequested = false;
    _restoreFailed = false;
    _state = BracketState.running;
    notifyListeners();

    final original = current;
    try {
      for (var i = 0; i < sequence.length; i++) {
        if (_stopRequested) break;
        _current = i;
        notifyListeners();

        final applied = await port.write(config.axis, sequence[i]);
        if (!applied) {
          _state = BracketState.failed;
          break;
        }
        await port.settle(config.settle);
        if (_stopRequested) break;
        await port.capture();
      }
    } catch (_) {
      _state = BracketState.failed;
    } finally {
      // 还原是硬性要求：宁可多用一个事务，也不能把相机留在偏移档位上。
      if (original != null) {
        try {
          final ok = await port.write(config.axis, original);
          _restoreFailed = !ok;
        } catch (_) {
          _restoreFailed = true;
        }
      }
      if (_state == BracketState.running) {
        _state = _stopRequested ? BracketState.stopped : BracketState.completed;
      }
      _current = _sequence.length;
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
    _state = BracketState.idle;
    _sequence = const <int>[];
    _current = 0;
    _config = null;
    notifyListeners();
  }
}
