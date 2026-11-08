import 'package:flutter/foundation.dart';

import '../../core/utils/app_log_manager.dart';
import '../../core/utils/camera_error_mapper.dart';
import '../../protocol/camera_driver.dart';
import '../liveview/live_view_controller.dart';
import 'camera_property.dart';
import 'ptp_device_prop_desc.dart';

/// 某个参数当前绑定到哪个属性 ID，以及该属性的能力与选项。
class PropertyBinding {
  final CameraParameter parameter;
  final int propertyId;
  final PtpDevicePropDesc descriptor;

  const PropertyBinding({
    required this.parameter,
    required this.propertyId,
    required this.descriptor,
  });

  bool get writable => descriptor.writable;
  int get currentValue => descriptor.currentValue;

  /// 可选值列表。
  ///
  /// 多数曝光属性是枚举型（直接给出档位表），但部分机身/部分档位会返回
  /// **范围型**（最小 / 最大 / 步进）。只认枚举会让滑条直接变成不可用，
  /// 所以这里把范围展开成等价列表；条目过多时放弃（避免生成上万个刻度）。
  List<int> get options {
    final values = descriptor.selectableValues;
    if (values.isNotEmpty) return values;

    final min = descriptor.minimum;
    final max = descriptor.maximum;
    final step = descriptor.step;
    if (min == null || max == null || step == null || step <= 0) {
      return const <int>[];
    }
    if (max <= min) return <int>[min];
    final count = ((max - min) ~/ step) + 1;
    if (count <= 0 || count > 256) return const <int>[];
    return List<int>.generate(count, (i) => min + step * i, growable: false);
  }

  String labelOf(int rawValue) =>
      parameter.format(rawValue, usedPropertyId: propertyId);
}

sealed class SettingsWriteOutcome {
  const SettingsWriteOutcome();
}

class SettingsApplied extends SettingsWriteOutcome {
  final int effectiveValue;
  const SettingsApplied(this.effectiveValue);
}

class SettingsRejected extends SettingsWriteOutcome {
  final SettingsRejectReason reason;

  /// 相机实际生效的值（回读得到），用于告诉用户「它自己跳到了多少」。
  final int? effectiveValue;

  const SettingsRejected(this.reason, {this.effectiveValue});
}

enum SettingsRejectReason {
  unavailable, // 读不到属性描述
  notWritable, // 当前机身模式不允许改
  busy,
  dialNotInManual, // 0x200F：典型原因是模式拨盘不在 M
  readbackMismatch,
  unsupported,
  deviceError,
}

/// 曝光参数的读写控制器。
///
/// 写入流程固定为「写 → 等 80 ms → 回读 → 比对」：相机在当前模式下会
/// **静默忽略**写入并返回成功，只有回读能发现。
class ExposureSettingsController extends ChangeNotifier {
  ExposureSettingsController({
    required CameraDriver driver,
    required LiveViewController liveView,
    this.staleAfter = const Duration(seconds: 2),
    Future<void> Function(Duration)? sleep,
  })  : _driver = driver,
        _liveView = liveView,
        _sleep = sleep ?? Future<void>.delayed;

  final CameraDriver _driver;
  final LiveViewController _liveView;
  final Future<void> Function(Duration) _sleep;
  final Duration staleAfter;

  final Map<CameraParameter, PropertyBinding> _bindings = {};
  final Map<CameraParameter, String> _descriptorSignatures = {};
  DateTime? _lastRefresh;
  bool _refreshing = false;

  /// 正在写相机时不要让轮询插进来，否则会在「写」和「回读」之间读到旧值。
  bool _writing = false;

  PropertyBinding? bindingOf(CameraParameter parameter) =>
      _bindings[parameter];

  bool get hasData => _bindings.isNotEmpty;

  /// 只刷新曝光模式（0x500E）这一个属性。
  ///
  /// 机身拨盘随时可能被转动，而整表刷新要 5 个事务；模式单独轮询便宜得多。
  /// 返回 `true` 表示模式发生了变化，调用方应再做一次整表刷新
  /// （档位变了，可写的参数和可选值都会跟着变）。
  /// 只在属性形态变化时记一条日志，避免 1 秒一次的轮询把日志刷满。
  void _logDescriptorOnce(CameraParameter parameter, String summary) {
    if (_descriptorSignatures[parameter] == summary) return;
    _descriptorSignatures[parameter] = summary;
    AppLogManager.instance.add('[曝光] ${parameter.name}: $summary');
  }

  String _describeBinding(PropertyBinding binding) {
    final d = binding.descriptor;
    final options = binding.options;
    return '0x${binding.propertyId.toRadixString(16)} '
        'type=${d.dataType} form=${d.form.name} writable=${d.writable} '
        'current=${d.currentValue} options=${options.length}'
        '${d.form == PtpPropForm.range ? ' range=${d.minimum}..${d.maximum} step=${d.step}' : ''}';
  }

  Future<bool> refreshMode() async {
    if (_refreshing || _writing || !_driver.isConnected) return false;
    final previous = _bindings[CameraParameter.mode]?.currentValue;
    final binding = await _resolve(CameraParameter.mode);
    if (binding == null) return false;
    _bindings[CameraParameter.mode] = binding;
    final changed = previous != binding.currentValue;
    if (changed) {
      AppLogManager.instance.add(
          '[曝光] 机身档位变化: ${_modeName(previous)} → ${_modeName(binding.currentValue)}');
      _lastRefresh = null; // 让下一次整表刷新不被时间窗挡住
      notifyListeners();
    }
    return changed;
  }

  String _modeName(int? mode) => switch (mode) {
        1 => 'M',
        2 => 'P',
        3 => 'A',
        4 => 'S',
        0x8010 || 0x8011 => 'AUTO',
        null => '未知',
        _ => '0x${mode.toRadixString(16)}',
      };

  /// 读取所有参数的属性描述。失败或过期的参数会被移除，不会留着旧值骗界面。
  Future<void> refresh({bool force = false}) async {
    if (_refreshing || _writing) return;
    final last = _lastRefresh;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < staleAfter &&
        _bindings.isNotEmpty) {
      return;
    }
    if (!_driver.isConnected) {
      _bindings.clear();
      _lastRefresh = null;
      notifyListeners();
      return;
    }

    _refreshing = true;
    try {
      for (final parameter in CameraParameter.values) {
        final binding = await _resolve(parameter);
        if (binding == null) {
          _bindings.remove(parameter);
          _logDescriptorOnce(parameter, '不可用（相机未提供该属性描述）');
        } else {
          _bindings[parameter] = binding;
          _logDescriptorOnce(parameter, _describeBinding(binding));
        }
      }
      _lastRefresh = DateTime.now();
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  Future<PropertyBinding?> _resolve(CameraParameter parameter) async {
    final candidates = <int>[
      parameter.propertyId,
      ...parameter.fallbackPropertyIds,
    ];
    for (final id in candidates) {
      try {
        final raw = await _driver.fetchDevicePropDesc(id);
        final descriptor = PtpDevicePropDesc.parse(raw);
        if (descriptor != null) {
          return PropertyBinding(
            parameter: parameter,
            propertyId: id,
            descriptor: descriptor,
          );
        }
      } catch (_) {
        // 该机型没有这个属性，试下一个候选。
      }
    }
    return null;
  }

  /// 写入参数并回读确认。
  Future<SettingsWriteOutcome> apply(
    CameraParameter parameter,
    int rawValue,
  ) async {
    if (!_driver.isConnected) {
      return const SettingsRejected(SettingsRejectReason.unavailable);
    }
    var candidate = _bindings[parameter];
    candidate ??= await _resolve(parameter);
    if (candidate == null) {
      return const SettingsRejected(SettingsRejectReason.unavailable);
    }
    final binding = candidate;
    _bindings[parameter] = binding;

    if (!binding.writable) {
      return const SettingsRejected(SettingsRejectReason.notWritable);
    }

    return _liveView.runExclusive(() async {
      _writing = true;
      try {
        await _writeWithRetry(
          binding.propertyId,
          binding.descriptor.encodeValue(rawValue),
        );
        await _sleep(const Duration(milliseconds: 80));

        final readbackBytes =
            await _driver.fetchDevicePropValue(binding.propertyId);
        final readback = binding.descriptor.decodeValue(readbackBytes);
        if (readback == null) {
          return const SettingsRejected(SettingsRejectReason.deviceError);
        }

        _bindings[parameter] = PropertyBinding(
          parameter: parameter,
          propertyId: binding.propertyId,
          descriptor: _withCurrent(binding.descriptor, readback),
        );
        notifyListeners();

        if (readback == rawValue) {
          AppLogManager.instance
              .add('[曝光] 写入 ${parameter.name} = $rawValue，回读一致');
          return SettingsApplied(readback);
        }
        AppLogManager.instance.add(
            '[曝光] 写入 ${parameter.name} = $rawValue，回读 $readback（不一致，可能被档位或自动 ISO 接管）');
        return SettingsRejected(
          SettingsRejectReason.readbackMismatch,
          effectiveValue: readback,
        );
      } catch (e) {
        // USB 侧的错误是 PlatformException，响应码藏在 message 里，
        // 必须统一抠出来才能区分「忙」和「不支持」。
        final code = CameraErrorMapper.responseCodeOf(e);
        AppLogManager.instance.add(code == null
            ? '[曝光] 写入 ${parameter.name} 异常: $e'
            : '[曝光] 写入 ${parameter.name} = $rawValue 被拒绝: 0x${code.toRadixString(16)}');
        if (code != null) return SettingsRejected(_reasonFrom(code));
        return const SettingsRejected(SettingsRejectReason.deviceError);
      } finally {
        _writing = false;
      }
    });
  }

  /// 部分 USB 固件在连续写属性时会偶发返回 0x2019 / 0x201A / 0x201C，
  /// 隔一小会儿重试通常就成功，没必要让用户再点一次。
  bool _isTransient(int? code) =>
      code == 0x2019 || code == 0x201A || code == 0x201C;

  Future<void> _writeWithRetry(int propertyId, Uint8List payload) async {
    for (var attempt = 0;; attempt++) {
      try {
        await _driver.writeDevicePropValue(propertyId, payload);
        return;
      } catch (e) {
        final code = CameraErrorMapper.responseCodeOf(e);
        if (attempt == 0 && _isTransient(code)) {
          AppLogManager.instance.add(
              '[曝光] 写入 0x${propertyId.toRadixString(16)} 返回 0x${code!.toRadixString(16)}，重试一次');
          await _sleep(const Duration(milliseconds: 150));
          continue;
        }
        rethrow;
      }
    }
  }

  SettingsRejectReason _reasonFrom(int responseCode) {
    switch (responseCode) {
      case 0x200F:
        return SettingsRejectReason.dialNotInManual;
      case 0x2019:
      case 0x201A:
      case 0x201C:
        return SettingsRejectReason.busy;
      case 0x2005:
      case 0x2006:
        return SettingsRejectReason.unsupported;
      default:
        return SettingsRejectReason.deviceError;
    }
  }

  PtpDevicePropDesc _withCurrent(PtpDevicePropDesc desc, int current) {
    return PtpDevicePropDesc(
      property: desc.property,
      dataType: desc.dataType,
      writable: desc.writable,
      factoryDefault: desc.factoryDefault,
      currentValue: current,
      form: desc.form,
      minimum: desc.minimum,
      maximum: desc.maximum,
      step: desc.step,
      enumValues: desc.enumValues,
    );
  }

  /// 断开连接时清空缓存，避免下一次连接沿用上一台相机的选项。
  void clear() {
    _bindings.clear();
    _lastRefresh = null;
    notifyListeners();
  }
}
