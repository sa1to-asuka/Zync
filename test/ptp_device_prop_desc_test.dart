import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/ptp_device_prop_desc.dart';

/// 构造一条 `GetDevicePropDesc 0x1014` 数据集。
Uint8List _descriptor({
  required int property,
  required int dataType,
  required int getSet,
  required int factoryDefault,
  required int currentValue,
  int formFlag = 0,
  List<int> range = const <int>[],
  List<int> enumValues = const <int>[],
}) {
  final builder = BytesBuilder();
  final view = ByteData(8);

  void u16(int value) {
    view.setUint16(0, value, Endian.little);
    builder.add(view.buffer.asUint8List(0, 2));
  }

  void u8(int value) => builder.add(<int>[value]);

  void value(int raw) {
    final width = PtpDevicePropDesc(
      property: property,
      dataType: dataType,
      writable: getSet == 1,
      factoryDefault: 0,
      currentValue: 0,
      form: PtpPropForm.none,
    ).valueByteWidth;
    switch (width) {
      case 1:
        u8(raw & 0xFF);
      case 2:
        u16(raw & 0xFFFF);
      case 4:
        view.setUint32(0, raw & 0xFFFFFFFF, Endian.little);
        builder.add(view.buffer.asUint8List(0, 4));
      case 8:
        view.setUint64(0, raw, Endian.little);
        builder.add(view.buffer.asUint8List(0, 8));
    }
  }

  u16(property);
  u16(dataType);
  u8(getSet);
  value(factoryDefault);
  value(currentValue);
  u8(formFlag);
  if (formFlag == 1) {
    for (final v in range) {
      value(v);
    }
  } else if (formFlag == 2) {
    u16(enumValues.length);
    for (final v in enumValues) {
      value(v);
    }
  }

  return builder.toBytes();
}

void main() {
  group('PtpDevicePropDesc.parse', () {
    test('解析枚举型属性（光圈 0x5007 / UINT16）', () {
      final bytes = _descriptor(
        property: 0x5007,
        dataType: 0x0004,
        getSet: 1,
        factoryDefault: 560,
        currentValue: 280,
        formFlag: 2,
        enumValues: <int>[280, 400, 560],
      );

      final desc = PtpDevicePropDesc.parse(bytes)!;

      expect(desc.property, 0x5007);
      expect(desc.dataType, 0x0004);
      expect(desc.writable, isTrue);
      expect(desc.factoryDefault, 560);
      expect(desc.currentValue, 280);
      expect(desc.form, PtpPropForm.enumeration);
      expect(desc.selectableValues, <int>[280, 400, 560]);
      expect(desc.valueByteWidth, 2);
    });

    test('解析范围型属性', () {
      final bytes = _descriptor(
        property: 0x5010,
        dataType: 0x0003,
        getSet: 1,
        factoryDefault: 0,
        currentValue: -333,
        formFlag: 1,
        range: <int>[-5000, 5000, 333],
      );

      final desc = PtpDevicePropDesc.parse(bytes)!;

      expect(desc.form, PtpPropForm.range);
      expect(desc.minimum, -5000);
      expect(desc.maximum, 5000);
      expect(desc.step, 333);
      expect(desc.currentValue, -333);
      expect(desc.selectableValues, isEmpty);
    });

    test('只读属性 getSet = 0', () {
      final bytes = _descriptor(
        property: 0x5001,
        dataType: 0x0002,
        getSet: 0,
        factoryDefault: 0,
        currentValue: 80,
        formFlag: 0,
      );

      final desc = PtpDevicePropDesc.parse(bytes)!;

      expect(desc.writable, isFalse);
      expect(desc.form, PtpPropForm.none);
      expect(desc.currentValue, 80);
    });

    test('UINT32 属性宽度为 4', () {
      final bytes = _descriptor(
        property: 0xD100,
        dataType: 0x0006,
        getSet: 1,
        factoryDefault: 0x00010064,
        currentValue: 0x000100FA,
        formFlag: 2,
        enumValues: <int>[0x00010064, 0x000100FA],
      );

      final desc = PtpDevicePropDesc.parse(bytes)!;

      expect(desc.valueByteWidth, 4);
      expect(desc.selectableValues, <int>[0x00010064, 0x000100FA]);
    });

    test('字符串类型返回 null', () {
      final bytes = _descriptor(
        property: 0x5002,
        dataType: 0xFFFF,
        getSet: 1,
        factoryDefault: 0,
        currentValue: 0,
      );

      expect(PtpDevicePropDesc.parse(bytes), isNull);
    });

    test('数据被截断时返回 null', () {
      final bytes = _descriptor(
        property: 0x5007,
        dataType: 0x0004,
        getSet: 1,
        factoryDefault: 560,
        currentValue: 280,
        formFlag: 2,
        enumValues: <int>[280, 400, 560],
      );

      expect(
        PtpDevicePropDesc.parse(Uint8List.sublistView(bytes, 0, 6)),
        isNull,
      );
    });

    test('枚举计数超过合理上限时判为损坏', () {
      final bytes = BytesBuilder()
        ..add(<int>[0x07, 0x50, 0x04, 0x00, 0x01])
        ..add(<int>[0x30, 0x02, 0x18, 0x01, 0x02, 0xFF, 0xFF]);

      expect(PtpDevicePropDesc.parse(bytes.toBytes()), isNull);
    });

    test('空数据返回 null', () {
      expect(PtpDevicePropDesc.parse(Uint8List(0)), isNull);
    });
  });

  group('PtpDevicePropDesc.encodeValue', () {
    PtpDevicePropDesc desc(int dataType) => PtpDevicePropDesc(
          property: 0x5007,
          dataType: dataType,
          writable: true,
          factoryDefault: 0,
          currentValue: 0,
          form: PtpPropForm.none,
        );

    test('UINT8 编成 1 字节', () {
      expect(desc(0x0002).encodeValue(0x12), <int>[0x12]);
    });

    test('UINT16 小端编码', () {
      expect(desc(0x0004).encodeValue(0x01FA), <int>[0xFA, 0x01]);
    });

    test('UINT32 小端编码', () {
      expect(
        desc(0x0006).encodeValue(0x000100FA),
        <int>[0xFA, 0x00, 0x01, 0x00],
      );
    });

    test('超出位宽的值被截断而不是抛异常', () {
      expect(desc(0x0002).encodeValue(0x1FF), <int>[0xFF]);
    });
  });
}
