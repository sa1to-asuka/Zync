import 'dart:typed_data';

/// PTP 设备属性描述（`GetDevicePropDesc 0x1014`）的解析结果。
///
/// 数据集布局（ISO 15740）：
/// ```
/// DevicePropertyCode : UINT16
/// DataType           : UINT16
/// GetSet             : UINT8   (0 = 只读, 1 = 可读可写)
/// FactoryDefaultValue: DataType
/// CurrentValue       : DataType
/// FormFlag           : UINT8   (0 = 无, 1 = 范围, 2 = 枚举)
///   [范围]   MinimumValue, MaximumValue, StepSize  各 DataType
///   [枚举]   NumberOfValues UINT16, 之后 NumberOfValues 个 DataType
/// ```
class PtpDevicePropDesc {
  final int property;
  final int dataType;
  final bool writable;
  final int factoryDefault;
  final int currentValue;
  final PtpPropForm form;
  final int? minimum;
  final int? maximum;
  final int? step;
  final List<int> enumValues;

  const PtpDevicePropDesc({
    required this.property,
    required this.dataType,
    required this.writable,
    required this.factoryDefault,
    required this.currentValue,
    required this.form,
    this.minimum,
    this.maximum,
    this.step,
    this.enumValues = const <int>[],
  });

  /// 该属性值在 `SetDevicePropValue 0x1016` 负载里占几个字节。
  int get valueByteWidth => _byteWidthOf(dataType);

  /// 界面可直接列出的候选值。范围型属性不展开——档位由相机决定，
  /// 用范围最低值 + 步进自行推算会与机身实际档位不一致。
  List<int> get selectableValues =>
      form == PtpPropForm.enumeration ? enumValues : const <int>[];

  bool get hasChoices => selectableValues.isNotEmpty;

  /// 解析失败（数据过短、类型不支持、长度自相矛盾）时返回 `null`，
  /// 调用方据此降级为「只读」而不是抛异常。
  static PtpDevicePropDesc? parse(Uint8List data) {
    final reader = _Reader(data);
    final property = reader.uint16();
    final dataType = reader.uint16();
    if (property == null || dataType == null) return null;

    final width = _byteWidthOf(dataType);
    if (width == 0) return null; // 字符串/数组型不用于曝光参数

    final getSet = reader.uint8();
    final factoryDefault = reader.value(dataType);
    final currentValue = reader.value(dataType);
    final formFlag = reader.uint8();
    if (getSet == null ||
        factoryDefault == null ||
        currentValue == null ||
        formFlag == null) {
      return null;
    }

    var minimum = null as int?;
    var maximum = null as int?;
    var step = null as int?;
    var enumValues = const <int>[];
    var form = PtpPropForm.none;

    switch (formFlag) {
      case 1:
        minimum = reader.value(dataType);
        maximum = reader.value(dataType);
        step = reader.value(dataType);
        if (minimum == null || maximum == null || step == null) return null;
        form = PtpPropForm.range;
      case 2:
        final count = reader.uint16();
        if (count == null) return null;
        // 枚举项可能很多（如 ISO 档位），但异常的超大计数说明数据损坏。
        if (count > 4096) return null;
        final values = <int>[];
        for (var i = 0; i < count; i++) {
          final value = reader.value(dataType);
          if (value == null) return null;
          values.add(value);
        }
        enumValues = List<int>.unmodifiable(values);
        form = PtpPropForm.enumeration;
      default:
        form = PtpPropForm.none;
    }

    return PtpDevicePropDesc(
      property: property,
      dataType: dataType,
      writable: getSet == 1,
      factoryDefault: factoryDefault,
      currentValue: currentValue,
      form: form,
      minimum: minimum,
      maximum: maximum,
      step: step,
      enumValues: enumValues,
    );
  }

  /// 值宽度；不支持的 PTP 数据类型返回 0。
  static int _byteWidthOf(int dataType) {
    switch (dataType) {
      case 0x0001: // INT8
      case 0x0002: // UINT8
        return 1;
      case 0x0003: // INT16
      case 0x0004: // UINT16
        return 2;
      case 0x0005: // INT32
      case 0x0006: // UINT32
        return 4;
      case 0x0007: // INT64
      case 0x0008: // UINT64
        return 8;
      default:
        return 0;
    }
  }

  /// 把 [rawValue] 编码成 `0x1016` 需要的负载。
  Uint8List encodeValue(int rawValue) {
    final width = valueByteWidth;
    final bytes = Uint8List(width);
    final view = ByteData.sublistView(bytes);
    switch (width) {
      case 1:
        view.setUint8(0, rawValue & 0xFF);
      case 2:
        view.setUint16(0, rawValue & 0xFFFF, Endian.little);
      case 4:
        view.setUint32(0, rawValue & 0xFFFFFFFF, Endian.little);
      case 8:
        view.setUint64(0, rawValue, Endian.little);
    }
    return bytes;
  }

  /// 解码 `0x1015` 回读值。数据不足或类型不支持时返回 `null`。
  int? decodeValue(Uint8List data) {
    final width = valueByteWidth;
    if (width == 0 || data.length < width) return null;
    final view = ByteData.sublistView(data);
    switch (dataType) {
      case 0x0001:
        return view.getInt8(0);
      case 0x0002:
        return view.getUint8(0);
      case 0x0003:
        return view.getInt16(0, Endian.little);
      case 0x0004:
        return view.getUint16(0, Endian.little);
      case 0x0005:
        return view.getInt32(0, Endian.little);
      case 0x0006:
        return view.getUint32(0, Endian.little);
      case 0x0007:
        return view.getInt64(0, Endian.little);
      case 0x0008:
        return view.getUint64(0, Endian.little);
      default:
        return null;
    }
  }
}

enum PtpPropForm { none, range, enumeration }

/// 带边界检查的小端读取器：任何越界都返回 `null` 而不是抛异常。
class _Reader {
  _Reader(this._data);

  final Uint8List _data;
  late final ByteData _view = ByteData.sublistView(_data);
  int _offset = 0;

  int? get remaining => _data.length - _offset;

  int? uint8() {
    if (_offset + 1 > _data.length) return null;
    return _data[_offset++];
  }

  int? uint16() {
    if (_offset + 2 > _data.length) return null;
    final value = _view.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  /// 按 PTP DataType 读取一个值，带符号类型做符号扩展。
  int? value(int dataType) {
    switch (dataType) {
      case 0x0001:
        if (_offset + 1 > _data.length) return null;
        return _view.getInt8(_offset++);
      case 0x0002:
        return uint8();
      case 0x0003:
        if (_offset + 2 > _data.length) return null;
        final v = _view.getInt16(_offset, Endian.little);
        _offset += 2;
        return v;
      case 0x0004:
        return uint16();
      case 0x0005:
        if (_offset + 4 > _data.length) return null;
        final v = _view.getInt32(_offset, Endian.little);
        _offset += 4;
        return v;
      case 0x0006:
        if (_offset + 4 > _data.length) return null;
        final v = _view.getUint32(_offset, Endian.little);
        _offset += 4;
        return v;
      case 0x0007:
        if (_offset + 8 > _data.length) return null;
        final v = _view.getInt64(_offset, Endian.little);
        _offset += 8;
        return v;
      case 0x0008:
        if (_offset + 8 > _data.length) return null;
        final v = _view.getUint64(_offset, Endian.little);
        _offset += 8;
        return v;
      default:
        return null;
    }
  }
}
