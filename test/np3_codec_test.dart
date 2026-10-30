import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/picture_control/builtin_np3_recipes.dart';
import 'package:zync/engine/picture_control/np3_codec.dart';

void main() {
  group('Np3Codec — 标准 NP3 ("0300")、传统 NCP ("0100") 与 Flexible Color ("0310") 编解码测试', () {
    test('内置经典初始 NP3 配方全部可无损解析并转换为 36/614 字节线上负载', () {
      expect(BuiltinNp3Catalog.seeds.length, greaterThanOrEqualTo(8));
      for (final seed in BuiltinNp3Catalog.seeds) {
        final parsed = Np3Codec.parse(seed.np3Bytes);
        expect(parsed.format, PictureControlFormat.np3Standard);
        expect(parsed.canWriteToCamera, isTrue);
        expect(parsed.cameraName, seed.cameraName);
        expect(parsed.hasCustomCurve, isTrue);
        expect(parsed.curveLut257.length, 257);

        // 编码为 PTP 0x90CD 614 字节线上负载并验证读回一致性
        final wire = Np3Codec.toWirePayload(parsed);
        expect(wire.length, Np3Codec.wireFullLength);

        // 模拟相机读回（状态字节 byte[23] 变为 1）
        final simulatedReadback = Uint8List.fromList(wire);
        simulatedReadback[23] = 1;
        expect(Np3Codec.verifyWireReadback(wire, simulatedReadback), isTrue);

        // 从线上负载反序列化回 Recipe
        final roundTrip = Np3Codec.fromWirePayload(simulatedReadback);
        expect(roundTrip.cameraName, parsed.cameraName);
        expect(roundTrip.base, parsed.base);
        expect(roundTrip.sharpeningQuarters, parsed.sharpeningQuarters);
        expect(roundTrip.hasCustomCurve, isTrue);
      }
    });

    test('无曲线 36 字节短线上负载编解码与内嵌 ASCII 名称重命名', () {
      const recipe = PictureControlRecipe(
        format: PictureControlFormat.np3Standard,
        cameraName: 'STREET FILM 01',
        base: PictureControlBase.vivid,
        sharpeningQuarters: 10, // +2.50
        midRangeSharpeningQuarters: 4, // +1.00
        clarityQuarters: -4, // -1.00
        contrastQuarters: 6, // +1.50
        brightnessQuarters: -2, // -0.50
        saturationQuarters: -4, // -1.00
        hueQuarters: 2, // +0.50
      );

      final np3Bytes = Np3Codec.encodeNp3File(recipe);
      final parsed = Np3Codec.parse(np3Bytes);
      expect(parsed.cameraName, 'STREET FILM 01');
      expect(parsed.hasCustomCurve, isFalse);

      final wire = Np3Codec.toWirePayload(parsed);
      expect(wire.length, Np3Codec.wireShortLength);

      // 测试双名称重命名中的内嵌 0x200 ASCII 重写
      final renamedBytes =
          Np3Codec.rewriteCameraName(np3Bytes, 'RENAMED Z30 RECIPE LONG NAME');
      final renamedParsed = Np3Codec.parse(renamedBytes);
      expect(renamedParsed.cameraName.length, lessThanOrEqualTo(19));
      expect(renamedParsed.cameraName, 'RENAMED Z30 RECIPE');
    });

    test('传统 NCP ("0100", tag 0x00000001) 解析与 C1–C9 线上负载转换', () {
      final body = Uint8List(36);
      // 写入名称 "LEGACY NCP" 到 body[4..23]
      final nameBytes = Np3Codec.encodeCameraName20('LEGACY NCP');
      body.setRange(4, 24, nameBytes);
      // Base = Portrait (0x0486)
      body[24] = 0x04;
      body[25] = 0x86;
      body[28] = 128 + 3; // Sharpening +3 steps (+12 quarters)
      body[29] = 128 - 1; // Contrast -1 step (-4 quarters)
      body[30] = 128; // Brightness 0
      body[31] = 128 + 2; // Saturation +2 steps (+8 quarters)
      body[32] = 128; // Hue 0
      body[33] = 0xFF;
      body[34] = 0xFF;
      body[35] = 0xFF;

      final builder = BytesBuilder()
        ..add(const [0x4E, 0x43, 0x50, 0x00]) // "NCP\0"
        ..add(const [0x00, 0x00, 0x00, 0x01]) // tagNcpBody = 1
        ..add(const [0x00, 0x00, 0x00, 36]) // len = 36
        ..add(body)
        ..add(const [0, 0, 0, 0]);

      final parsed = Np3Codec.parse(builder.toBytes());
      expect(parsed.format, PictureControlFormat.ncpLegacy);
      expect(parsed.canWriteToCamera, isTrue);
      expect(parsed.cameraName, 'LEGACY NCP');
      expect(parsed.base, PictureControlBase.portrait);
      expect(parsed.sharpeningQuarters, 12);
      expect(parsed.contrastQuarters, -4);
      expect(parsed.saturationQuarters, 8);

      final wire = Np3Codec.toWirePayload(parsed);
      expect(wire.length, Np3Codec.wireShortLength);
      expect(wire[0], PictureControlBase.portrait.wireId);
    });

    test('收录自 Timor88/NikonNP3 的 32 款社区配方全部可解析且 Flexible Color 支持一键转标准 NP3', () {
      expect(BuiltinNp3Catalog.timor88Seeds.length, 32);
      var standardCount = 0;
      var flexibleCount = 0;

      for (final seed in BuiltinNp3Catalog.timor88Seeds) {
        final file = File(seed.assetPath);
        expect(file.existsSync(), isTrue, reason: '缺少资源文件 ${seed.assetPath}');
        final bytes = file.readAsBytesSync();
        final recipe = Np3Codec.parse(bytes);
        expect(recipe.cameraName, isNotEmpty);

        if (recipe.format == PictureControlFormat.np3Standard) {
          standardCount++;
          expect(recipe.canWriteToCamera, isTrue);
          final wire = Np3Codec.toWirePayload(recipe);
          expect(
            wire.length == Np3Codec.wireShortLength ||
                wire.length == Np3Codec.wireFullLength,
            isTrue,
          );
        } else if (recipe.format == PictureControlFormat.np3FlexibleColor) {
          flexibleCount++;
          expect(recipe.canWriteToCamera, isFalse);
          expect(
            () => Np3Codec.toWirePayload(recipe),
            throwsA(isA<UnsupportedError>()),
          );

          // 一键拟合适配为标准 "0300" NP3 后可写入 C1–C9
          final stdBytes = Np3Codec.convertFlexibleToStandardNp3Bytes(recipe);
          final stdParsed = Np3Codec.parse(stdBytes);
          expect(stdParsed.format, PictureControlFormat.np3Standard);
          expect(stdParsed.canWriteToCamera, isTrue);
          final wire = Np3Codec.toWirePayload(stdParsed);
          expect(
            wire.length == Np3Codec.wireShortLength ||
                wire.length == Np3Codec.wireFullLength,
            isTrue,
          );
        }
      }

      expect(standardCount, greaterThanOrEqualTo(1));
      expect(flexibleCount, greaterThanOrEqualTo(30));
    });

    test('损坏魔数或截断 TLV 抛出 FormatException', () {
      expect(
        () => Np3Codec.parse(Uint8List.fromList(utf8.encode('NOT_AN_NP3_FILE'))),
        throwsFormatException,
      );
      expect(
        () => Np3Codec.parse(Uint8List.fromList([0x4E, 0x43, 0x50, 0x00, 0, 0, 1, 0, 0, 0, 99, 99])),
        throwsFormatException,
      );
    });
  });

  group('Np3Codec.sameParameters — 写入后的语义读回校验', () {
    const shortRecipe = PictureControlRecipe(
      format: PictureControlFormat.np3Standard,
      cameraName: 'STREET FILM 01',
      base: PictureControlBase.vivid,
      sharpeningQuarters: 10,
      midRangeSharpeningQuarters: 4,
      clarityQuarters: -4,
      contrastQuarters: 6,
      brightnessQuarters: -2,
      saturationQuarters: -4,
      hueQuarters: 2,
    );

    test('36 字节短负载往返后参数一致', () {
      final wire = Np3Codec.toWirePayload(shortRecipe);
      expect(wire.length, Np3Codec.wireShortLength);
      final readback = Np3Codec.fromWirePayload(wire);
      expect(Np3Codec.sameParameters(shortRecipe, readback), isTrue);
    });

    test('相机改写名称填充与原生标志位不影响判定', () {
      final wire = Np3Codec.toWirePayload(shortRecipe);
      final normalized = Uint8List.fromList(wire);
      normalized[1] = 0x01;
      for (var i = 2; i < 22; i++) {
        normalized[i] = 0x20; // 相机用空格填充名称
      }
      final readback = Np3Codec.fromWirePayload(normalized);
      expect(readback.cameraName, isNot(shortRecipe.cameraName));
      expect(Np3Codec.sameParameters(shortRecipe, readback), isTrue);
    });

    test('相机把 36 字节补成 614 字节曲线负载仍判定成功', () {
      final wire = Np3Codec.toWirePayload(shortRecipe);
      final normalized = Uint8List(Np3Codec.wireFullLength);
      normalized.setRange(0, wire.length, wire);
      normalized[35] = 1; // 相机补上了曲线标志
      final readback = Np3Codec.fromWirePayload(normalized);
      expect(readback.hasCustomCurve, isTrue);
      expect(Np3Codec.sameParameters(shortRecipe, readback), isTrue);
    });

    test('参数不同则判定失败', () {
      final readback = Np3Codec.fromWirePayload(
        Np3Codec.toWirePayload(shortRecipe),
      );
      const different = PictureControlRecipe(
        format: PictureControlFormat.np3Standard,
        cameraName: 'STREET FILM 01',
        base: PictureControlBase.vivid,
        sharpeningQuarters: 12,
        midRangeSharpeningQuarters: 4,
        clarityQuarters: -4,
        contrastQuarters: 6,
        brightnessQuarters: -2,
        saturationQuarters: -4,
        hueQuarters: 2,
      );
      expect(Np3Codec.sameParameters(different, readback), isFalse);
    });

    test('曲线配方：曲线一致判定成功，丢失曲线判定失败', () {
      final curved = Np3Codec.parse(BuiltinNp3Catalog.seeds.first.np3Bytes);
      expect(curved.hasCustomCurve, isTrue);
      final wire = Np3Codec.toWirePayload(curved);
      expect(wire.length, Np3Codec.wireFullLength);

      final readback = Np3Codec.fromWirePayload(wire);
      expect(Np3Codec.sameParameters(curved, readback), isTrue);

      final withoutCurve = Uint8List.fromList(
        wire.sublist(0, Np3Codec.wireShortLength),
      );
      withoutCurve[35] = 0;
      final dropped = Np3Codec.fromWirePayload(withoutCurve);
      expect(dropped.hasCustomCurve, isFalse);
      expect(Np3Codec.sameParameters(curved, dropped), isFalse);
    });
  });
}
