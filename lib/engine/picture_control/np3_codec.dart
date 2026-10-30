import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// 尼康优化校准配方文件格式枚举。
enum PictureControlFormat {
  /// 标准 NP3 ("0300") —— 支持 Z30 等 C1–C9 机内直写。
  np3Standard,

  /// 传统 NCP ("0100") —— 支持转换为 C1–C9 线上负载并机内直写。
  ncpLegacy,

  /// Flexible Color NP3 ("0310", 基底 0x0020) —— 支持本地参数查看与预览，不支持 C1–C9 直写。
  np3FlexibleColor,
}

/// 尼康优化校准基底类型枚举。
enum PictureControlBase {
  standard(wireId: 1, fileCode: 0x0001, codeName: 'SD'),
  neutral(wireId: 2, fileCode: 0x03C2, codeName: 'NL'),
  vivid(wireId: 3, fileCode: 0x00C3, codeName: 'VI'),
  monochrome(wireId: 4, fileCode: 0x064D, codeName: 'MC'),
  portrait(wireId: 5, fileCode: 0x0486, codeName: 'PT'),
  landscape(wireId: 6, fileCode: 0x04C7, codeName: 'LS'),
  flat(wireId: 2, fileCode: 0x0548, codeName: 'FL'),
  flexibleColor(wireId: 1, fileCode: 0x0020, codeName: 'FC');

  final int wireId;
  final int fileCode;
  final String codeName;

  const PictureControlBase({
    required this.wireId,
    required this.fileCode,
    required this.codeName,
  });

  String get labelZh => switch (this) {
        PictureControlBase.standard => '标准',
        PictureControlBase.neutral => '自然',
        PictureControlBase.vivid => '鲜艳',
        PictureControlBase.monochrome => '单色',
        PictureControlBase.portrait => '人像',
        PictureControlBase.landscape => '风景',
        PictureControlBase.flat => '平淡',
        PictureControlBase.flexibleColor => '灵活色彩',
      };

  static PictureControlBase fromFileCode(int code) {
    switch (code) {
      case 0x0001:
        return PictureControlBase.standard;
      case 0x03C2:
      case 2:
        return PictureControlBase.neutral;
      case 0x00C3:
      case 3:
        return PictureControlBase.vivid;
      case 0x0486:
      case 0x0802: // Rich Tone Portrait -> Portrait wire slot
      case 5:
        return PictureControlBase.portrait;
      case 0x04C7:
      case 6:
        return PictureControlBase.landscape;
      case 0x0548:
      case 7:
        return PictureControlBase.flat;
      case 0x064D:
      case 0x068E: // Flat Monochrome / Deep Tone Monochrome
      case 4:
        return PictureControlBase.monochrome;
      case 0x0020:
        return PictureControlBase.flexibleColor;
      default:
        return PictureControlBase.standard;
    }
  }

  static PictureControlBase fromWireId(int wireId) {
    switch (wireId) {
      case 1:
        return PictureControlBase.standard;
      case 2:
        return PictureControlBase.neutral;
      case 3:
        return PictureControlBase.vivid;
      case 4:
        return PictureControlBase.monochrome;
      case 5:
        return PictureControlBase.portrait;
      case 6:
        return PictureControlBase.landscape;
      default:
        return PictureControlBase.standard;
    }
  }
}

/// 曲线控制点 (0..255 归一化空间)。
class PictureControlCurvePoint {
  final int x;
  final int y;

  const PictureControlCurvePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory PictureControlCurvePoint.fromJson(Map<String, dynamic> json) =>
      PictureControlCurvePoint(
        (json['x'] as num?)?.toInt() ?? 0,
        (json['y'] as num?)?.toInt() ?? 0,
      );
}

/// Flexible Color 8 色混合器单项 (Red, Orange, Yellow, Green, Cyan, Blue, Purple, Magenta)。
class FlexibleColorBlenderBand {
  final String colorName;
  final int hue; // -100..+100
  final int chroma; // -100..+100
  final int brightness; // -100..+100

  const FlexibleColorBlenderBand({
    required this.colorName,
    required this.hue,
    required this.chroma,
    required this.brightness,
  });
}

/// 尼康优化校准完整配方结构。
class PictureControlRecipe {
  final PictureControlFormat format;
  final String cameraName;
  final PictureControlBase base;

  /// 参数单位均为「档位 (step)」，步进 0.25（内部存储为 quarters，即 step * 4）。
  /// null 表示 Auto 或当前基底不适用 (N/A)。
  final int? sharpeningQuarters; // -12..+36 (-3.0..+9.0)
  final int? midRangeSharpeningQuarters; // -20..+20 (-5.0..+5.0)
  final int? clarityQuarters; // -20..+20 (-5.0..+5.0)
  final int? contrastQuarters; // -12..+12 (-3.0..+3.0)
  final int? brightnessQuarters; // -6..+6 (-1.5..+1.5)
  final int? saturationQuarters; // -12..+12 (-3.0..+3.0)
  final int? hueQuarters; // -12..+12 (-3.0..+3.0)

  /// 单色模式专属字段
  final int monoFilter; // 0: Off, 1: Yellow, 2: Orange, 3: Red, 4: Green
  final int monoToning; // 0: B&W, 1..9: Sepia/Cyanotype/...
  final int monoToningSaturation; // 0..7

  /// 自定义色调曲线
  final bool hasCustomCurve;
  final List<PictureControlCurvePoint> curvePoints;

  /// 257 点 15-bit LUT (取值 0..32767)，若无曲线则为空。
  final List<int> curveLut257;

  /// 原始 578 字节曲线块（用于无损写入相机 0x90CD）。
  final Uint8List? rawCurveBlock;

  /// Flexible Color ("0310") 扩展参数（可选）
  final int? fcHighlights;
  final int? fcShadows;
  final int? fcWhites;
  final int? fcBlacks;
  final List<FlexibleColorBlenderBand> fcBlenderBands;

  const PictureControlRecipe({
    required this.format,
    required this.cameraName,
    required this.base,
    this.sharpeningQuarters,
    this.midRangeSharpeningQuarters,
    this.clarityQuarters,
    this.contrastQuarters,
    this.brightnessQuarters,
    this.saturationQuarters,
    this.hueQuarters,
    this.monoFilter = 0,
    this.monoToning = 0,
    this.monoToningSaturation = 0,
    this.hasCustomCurve = false,
    this.curvePoints = const [],
    this.curveLut257 = const [],
    this.rawCurveBlock,
    this.fcHighlights,
    this.fcShadows,
    this.fcWhites,
    this.fcBlacks,
    this.fcBlenderBands = const [],
  });

  /// 是否允许通过 0x90CD 写入相机 C1–C9 槽位。
  bool get canWriteToCamera =>
      format == PictureControlFormat.np3Standard ||
      format == PictureControlFormat.ncpLegacy;

  /// 是否为 Flexible Color ("0310", base 0x0020) 配方。
  bool get isFlexibleColor =>
      format == PictureControlFormat.np3FlexibleColor ||
      base == PictureControlBase.flexibleColor;

  bool get isMonochrome => base == PictureControlBase.monochrome;

  double? get sharpening =>
      sharpeningQuarters != null ? sharpeningQuarters! / 4.0 : null;
  double? get midRangeSharpening => midRangeSharpeningQuarters != null
      ? midRangeSharpeningQuarters! / 4.0
      : null;
  double? get clarity =>
      clarityQuarters != null ? clarityQuarters! / 4.0 : null;
  double? get contrast =>
      contrastQuarters != null ? contrastQuarters! / 4.0 : null;
  double? get brightness =>
      brightnessQuarters != null ? brightnessQuarters! / 4.0 : null;
  double? get saturation =>
      saturationQuarters != null ? saturationQuarters! / 4.0 : null;
  double? get hue => hueQuarters != null ? hueQuarters! / 4.0 : null;

  static String formatStep(int? quarters) {
    if (quarters == null) return 'AUTO';
    final v = quarters / 4.0;
    final prefix = v > 0 ? '+' : '';
    return '$prefix${v.toStringAsFixed(2)}';
  }

  PictureControlRecipe copyWith({
    String? cameraName,
  }) {
    return PictureControlRecipe(
      format: format,
      cameraName: cameraName != null
          ? Np3Codec.sanitizeCameraName(cameraName)
          : this.cameraName,
      base: base,
      sharpeningQuarters: sharpeningQuarters,
      midRangeSharpeningQuarters: midRangeSharpeningQuarters,
      clarityQuarters: clarityQuarters,
      contrastQuarters: contrastQuarters,
      brightnessQuarters: brightnessQuarters,
      saturationQuarters: saturationQuarters,
      hueQuarters: hueQuarters,
      monoFilter: monoFilter,
      monoToning: monoToning,
      monoToningSaturation: monoToningSaturation,
      hasCustomCurve: hasCustomCurve,
      curvePoints: curvePoints,
      curveLut257: curveLut257,
      rawCurveBlock: rawCurveBlock,
      fcHighlights: fcHighlights,
      fcShadows: fcShadows,
      fcWhites: fcWhites,
      fcBlacks: fcBlacks,
      fcBlenderBands: fcBlenderBands,
    );
  }
}

/// 尼康 NP3 / NCP 二进制与 PTP 0x90CC/0x90CD 线上负载编解码器。
///
/// 协议与容器结构参考：
/// - yekong-nasa/Z30-Recipes (MIT)
/// - ssssota/nikon-flexible-color-picture-control (MIT)
class Np3Codec {
  Np3Codec._();

  static const int maxFileSizeBytes = 65536; // 64 KB 安全上限
  static const int wireShortLength = 36;
  static const int curveBlockLength = 578;
  static const int wireFullLength = 614; // 36 + 578

  // TLV Tag 定义
  static const int tagNcpBody = 0x00000001;
  static const int tagCurveBlock = 0x00000002;
  static const int tagVersion = 0x00000100;
  static const int tagName = 0x00000200;
  static const int tagBase = 0x00000300;
  static const int tagHeader400 = 0x00000400;
  static const int tagHeader500 = 0x00000500;
  static const int tagSharpening = 0x00000600;
  static const int tagClarity = 0x00000700;
  static const int tagContrast = 0x00000800;
  static const int tagBrightness = 0x00000900;
  static const int tagSaturation = 0x00000A00;
  static const int tagHue = 0x00000B00;
  static const int tagMonoFilter = 0x00000C00;
  static const int tagMonoToning = 0x00000D00;
  static const int tagMonoToningDensity = 0x00000E00;
  static const int tagMidRangeSharpening = 0x00001600;
  static const int tagFcContrast = 0x00001900;
  static const int tagFcHighlights = 0x00001A00;
  static const int tagFcShadows = 0x00001B00;
  static const int tagFcWhites = 0x00001C00;
  static const int tagFcBlacks = 0x00001D00;
  static const int tagFcSaturation = 0x00001E00;
  static const int tagFcColorBlender = 0x00001F00;
  static const int tagFcColorGrading = 0x00002000;

  /// 将输入字符串规整为符合尼康机内要求的 ASCII 名称（仅限可见 ASCII 0x20..0x7E，最多 19 字符）。
  static String sanitizeCameraName(String raw) {
    final buf = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= 0x20 && rune <= 0x7E) {
        buf.writeCharCode(rune);
        if (buf.length >= 19) break;
      }
    }
    final res = buf.toString().trim();
    return res.isEmpty ? 'CUSTOM PC' : res;
  }

  /// 将机内名称编码为 20 字节 NUL 填充的 ASCII 字节数组。
  static Uint8List encodeCameraName20(String name) {
    final clean = sanitizeCameraName(name);
    final out = Uint8List(20);
    final units = ascii.encode(clean);
    final copyLen = math.min(19, units.length);
    for (var i = 0; i < copyLen; i++) {
      out[i] = units[i];
    }
    return out;
  }

  /// 从 20 字节 NUL 填充数组中解码 ASCII 名称。
  static String decodeCameraName20(Uint8List bytes, [int offset = 0]) {
    final chars = <int>[];
    final end = math.min(bytes.length, offset + 20);
    for (var i = offset; i < end; i++) {
      final b = bytes[i];
      if (b == 0) break;
      if (b >= 0x20 && b <= 0x7E) {
        chars.add(b);
      }
    }
    final s = String.fromCharCodes(chars).trim();
    return s.isEmpty ? 'CUSTOM' : s;
  }

  /// 解析 .NP3 或 .NCP 文件二进制。
  static PictureControlRecipe parse(Uint8List bytes) {
    if (bytes.length < 16 || bytes.length > maxFileSizeBytes) {
      throw const FormatException('Invalid NP3/NCP file size.');
    }
    // 校验魔数 "NCP\0" (0x4E 0x43 0x50 0x00)
    if (bytes[0] != 0x4E ||
        bytes[1] != 0x43 ||
        bytes[2] != 0x50 ||
        bytes[3] != 0x00) {
      throw const FormatException('Invalid magic header: expected "NCP\\0".');
    }

    final records = <int, Uint8List>{};
    final bd = ByteData.sublistView(bytes);
    var offset = 4;
    while (offset + 4 <= bytes.length) {
      final tag = bd.getUint32(offset, Endian.big);
      offset += 4;
      if (tag == 0) break; // 结束标记
      if (offset + 4 > bytes.length) {
        throw const FormatException('Truncated TLV length field.');
      }
      final len = bd.getUint32(offset, Endian.big);
      offset += 4;
      if (len < 0 || offset + len > bytes.length) {
        throw const FormatException('Truncated TLV record payload.');
      }
      records[tag] = Uint8List.sublistView(bytes, offset, offset + len);
      offset += len;
    }

    // 1. 判断是否为传统 NCP ("0100"，包含 tag 0x00000001)
    if (records.containsKey(tagNcpBody)) {
      return _parseLegacyNcp(records[tagNcpBody]!, records[tagCurveBlock]);
    }

    // 2. 解析 NP3 ("0300" 或 "0310")
    final nameBytes = records[tagName];
    final cameraName = nameBytes != null && nameBytes.isNotEmpty
        ? decodeCameraName20(nameBytes)
        : 'CUSTOM NP3';

    final baseBytes = records[tagBase];
    final baseCode = (baseBytes != null && baseBytes.length >= 2)
        ? ((baseBytes[0] << 8) | baseBytes[1])
        : 0x0001;
    final base = PictureControlBase.fromFileCode(baseCode);

    // 仅当基底为 0x0020 (Flexible Color) 时判定为 Flexible Color NP3；
    // 常规基底（如 Standard/Portrait/Rich Tone Portrait）即便版本号为 "0310" 亦可按标准参数处理。
    final isFlexible =
        base == PictureControlBase.flexibleColor || baseCode == 0x0020;

    int? readQuarterParam(int tag, {int minQ = -80, int maxQ = 144}) {
      final rec = records[tag];
      if (rec == null || rec.isEmpty) return null;
      final b = rec[0];
      if (b == 0xFF || b == 0x7F) return null; // Auto / N/A 哨兵
      final q = b - 128;
      return q.clamp(minQ, maxQ);
    }

    final curveRec = records[tagCurveBlock];
    final hasCurve = curveRec != null && curveRec.length == curveBlockLength;
    final parsedCurve =
        hasCurve ? _parseCurveBlock(curveRec) : const _ParsedCurve();

    var contrastQ = readQuarterParam(tagContrast, minQ: -12, maxQ: 12);
    var brightnessQ = readQuarterParam(tagBrightness, minQ: -6, maxQ: 6);
    if (hasCurve) {
      // 有自定义曲线时 0x800 / 0x900 存的是 [1, 4] 标志位
      final cRec = records[tagContrast];
      if (cRec != null && cRec.length >= 2 && cRec[0] == 1 && cRec[1] == 4) {
        contrastQ = 0;
      }
      final bRec = records[tagBrightness];
      if (bRec != null && bRec.length >= 2 && bRec[0] == 1 && bRec[1] == 4) {
        brightnessQ = 0;
      }
    }

    final monoFilterRec = records[tagMonoFilter];
    final monoToningRec = records[tagMonoToning];
    final monoDensityRec = records[tagMonoToningDensity];

    // Flexible Color ("0310", base 0x0020) TLV 记录解析
    int? fcHighlights;
    int? fcShadows;
    int? fcWhites;
    int? fcBlacks;
    final blenderBands = <FlexibleColorBlenderBand>[];
    if (isFlexible) {
      int? readFcParam(int tag, {bool zeroWhenCurve = true}) {
        final rec = records[tag];
        if (rec == null || rec.isEmpty) return null;
        if (rec[0] == 0xFF) return null;
        if (zeroWhenCurve &&
            hasCurve &&
            rec.length >= 2 &&
            rec[0] == 1 &&
            rec[1] == 1) {
          return 0;
        }
        return (rec[0] - 128).clamp(-100, 100);
      }

      final fcContrastVal = readFcParam(tagFcContrast);
      if (contrastQ == null && fcContrastVal != null) {
        contrastQ = (fcContrastVal * 12 / 100).round().clamp(-12, 12);
      }
      final fcSatVal = readFcParam(tagFcSaturation, zeroWhenCurve: false);
      fcHighlights = readFcParam(tagFcHighlights);
      fcShadows = readFcParam(tagFcShadows);
      fcWhites = readFcParam(tagFcWhites);
      fcBlacks = readFcParam(tagFcBlacks);

      final blenderRec = records[tagFcColorBlender];
      if (blenderRec != null && blenderRec.length >= 24) {
        const bandNames = [
          'Red',
          'Orange',
          'Yellow',
          'Green',
          'Cyan',
          'Blue',
          'Purple',
          'Magenta',
        ];
        for (var i = 0; i < bandNames.length; i++) {
          final off = i * 3;
          int decodeBand(int b) => (b == 0xFF) ? 0 : (b - 128).clamp(-100, 100);
          blenderBands.add(FlexibleColorBlenderBand(
            colorName: bandNames[i],
            hue: decodeBand(blenderRec[off]),
            chroma: decodeBand(blenderRec[off + 1]),
            brightness: decodeBand(blenderRec[off + 2]),
          ));
        }
      }

      return PictureControlRecipe(
        format: PictureControlFormat.np3FlexibleColor,
        cameraName: cameraName,
        base: base,
        sharpeningQuarters:
            readQuarterParam(tagSharpening, minQ: -12, maxQ: 36),
        midRangeSharpeningQuarters:
            readQuarterParam(tagMidRangeSharpening, minQ: -20, maxQ: 20),
        clarityQuarters: readQuarterParam(tagClarity, minQ: -20, maxQ: 20),
        contrastQuarters: contrastQ,
        brightnessQuarters: brightnessQ,
        saturationQuarters: fcSatVal != null
            ? (fcSatVal * 12 / 100).round().clamp(-12, 12)
            : readQuarterParam(tagSaturation, minQ: -12, maxQ: 12),
        hueQuarters: readQuarterParam(tagHue, minQ: -12, maxQ: 12),
        hasCustomCurve: hasCurve,
        curvePoints: parsedCurve.points,
        curveLut257: parsedCurve.lut257,
        rawCurveBlock: hasCurve ? Uint8List.fromList(curveRec) : null,
        fcHighlights: fcHighlights,
        fcShadows: fcShadows,
        fcWhites: fcWhites,
        fcBlacks: fcBlacks,
        fcBlenderBands: blenderBands,
      );
    }

    return PictureControlRecipe(
      format: isFlexible
          ? PictureControlFormat.np3FlexibleColor
          : PictureControlFormat.np3Standard,
      cameraName: cameraName,
      base: base,
      sharpeningQuarters: readQuarterParam(tagSharpening, minQ: -12, maxQ: 36),
      midRangeSharpeningQuarters:
          readQuarterParam(tagMidRangeSharpening, minQ: -20, maxQ: 20),
      clarityQuarters: readQuarterParam(tagClarity, minQ: -20, maxQ: 20),
      contrastQuarters: contrastQ,
      brightnessQuarters: brightnessQ,
      saturationQuarters: base == PictureControlBase.monochrome
          ? null
          : readQuarterParam(tagSaturation, minQ: -12, maxQ: 12),
      hueQuarters: base == PictureControlBase.monochrome
          ? null
          : readQuarterParam(tagHue, minQ: -12, maxQ: 12),
      monoFilter: monoFilterRec != null && monoFilterRec.isNotEmpty
          ? (monoFilterRec[0] == 0xFF ? 0 : monoFilterRec[0].clamp(0, 4))
          : 0,
      monoToning: monoToningRec != null && monoToningRec.isNotEmpty
          ? (monoToningRec[0] == 0xFF ? 0 : monoToningRec[0].clamp(0, 9))
          : 0,
      monoToningSaturation: monoDensityRec != null && monoDensityRec.isNotEmpty
          ? (monoDensityRec[0] == 0xFF ? 0 : monoDensityRec[0].clamp(0, 7))
          : 0,
      hasCustomCurve: hasCurve,
      curvePoints: parsedCurve.points,
      curveLut257: parsedCurve.lut257,
      rawCurveBlock: hasCurve ? Uint8List.fromList(curveRec) : null,
      fcHighlights: fcHighlights,
      fcShadows: fcShadows,
      fcWhites: fcWhites,
      fcBlacks: fcBlacks,
      fcBlenderBands: blenderBands,
    );
  }

  static PictureControlRecipe _parseLegacyNcp(
    Uint8List body,
    Uint8List? curveRec,
  ) {
    if (body.length < 36) {
      throw const FormatException('Invalid NCP body length (< 36 bytes).');
    }
    final name = decodeCameraName20(body, 4);
    final baseCode = (body[24] << 8) | body[25];
    final base = PictureControlBase.fromFileCode(baseCode);

    int? readNcpStepAsQuarters(int byteVal, int minQ, int maxQ) {
      if (byteVal == 0 || byteVal == 0xFF) return null;
      return ((byteVal - 128) * 4).clamp(minQ, maxQ);
    }

    final hasCurve = curveRec != null && curveRec.length == curveBlockLength;
    final parsedCurve =
        hasCurve ? _parseCurveBlock(curveRec) : const _ParsedCurve();

    return PictureControlRecipe(
      format: PictureControlFormat.ncpLegacy,
      cameraName: name,
      base: base,
      sharpeningQuarters: readNcpStepAsQuarters(body[28], -12, 36),
      midRangeSharpeningQuarters: 0,
      clarityQuarters: 0,
      contrastQuarters: hasCurve ? 0 : readNcpStepAsQuarters(body[29], -12, 12),
      brightnessQuarters: hasCurve ? 0 : readNcpStepAsQuarters(body[30], -6, 6),
      saturationQuarters: base == PictureControlBase.monochrome
          ? null
          : readNcpStepAsQuarters(body[31], -12, 12),
      hueQuarters: base == PictureControlBase.monochrome
          ? null
          : readNcpStepAsQuarters(body[32], -12, 12),
      monoFilter: body[33] == 0xFF ? 0 : body[33].clamp(0, 4),
      monoToning: body[34] == 0xFF ? 0 : body[34].clamp(0, 9),
      monoToningSaturation: body[35] == 0xFF ? 0 : body[35].clamp(0, 7),
      hasCustomCurve: hasCurve,
      curvePoints: parsedCurve.points,
      curveLut257: parsedCurve.lut257,
      rawCurveBlock: hasCurve ? Uint8List.fromList(curveRec) : null,
    );
  }

  static _ParsedCurve _parseCurveBlock(Uint8List block) {
    if (block.length < curveBlockLength) return const _ParsedCurve();
    final numPoints = block[8].clamp(2, 20);
    final points = <PictureControlCurvePoint>[];
    for (var i = 0; i < numPoints; i++) {
      final pos = 9 + i * 2;
      if (pos + 1 < 64) {
        points.add(PictureControlCurvePoint(block[pos], block[pos + 1]));
      }
    }
    final bd = ByteData.sublistView(block);
    final lut = List<int>.filled(257, 0);
    for (var i = 0; i < 257; i++) {
      final off = 64 + i * 2;
      lut[i] = bd.getUint16(off, Endian.big).clamp(0, 32767);
    }
    return _ParsedCurve(points: points, lut257: lut);
  }

  /// 修改 .NP3 或 .NCP 二进制文件中的机内 ASCII 名称，返回修改后的新字节数组。
  static Uint8List rewriteCameraName(Uint8List originalBytes, String newName) {
    final out = Uint8List.fromList(originalBytes);
    final encodedName = encodeCameraName20(newName);

    if (out.length < 16 ||
        out[0] != 0x4E ||
        out[1] != 0x43 ||
        out[2] != 0x50 ||
        out[3] != 0x00) {
      return out;
    }

    final bd = ByteData.sublistView(out);
    var offset = 4;
    while (offset + 8 <= out.length) {
      final tag = bd.getUint32(offset, Endian.big);
      if (tag == 0) break;
      final len = bd.getUint32(offset + 4, Endian.big);
      final valStart = offset + 8;
      if (valStart + len > out.length) break;

      if (tag == tagName && len >= 20) {
        out.setRange(valStart, valStart + 20, encodedName);
        break;
      } else if (tag == tagNcpBody && len >= 36) {
        out.setRange(valStart + 4, valStart + 24, encodedName);
        break;
      }
      offset = valStart + len;
    }
    return out;
  }

  /// 将配方编码为相机 PTP 0x90CD 线上负载（36 字节或 614 字节）。
  ///
  /// [nativeBaseTemplate] 为可选的从相机 `0x90CC [baseWireId, 0]` 读出的内置基底数据，
  /// 用于合并 `payload[1]` 原生标志位与单色默认字段。
  static Uint8List toWirePayload(
    PictureControlRecipe recipe, {
    Uint8List? nativeBaseTemplate,
  }) {
    if (!recipe.canWriteToCamera) {
      throw UnsupportedError(
        'Flexible Color NP3 (0310) cannot be encoded to C1-C9 wire payload.',
      );
    }

    final hasCurve = recipe.hasCustomCurve &&
        recipe.rawCurveBlock != null &&
        recipe.rawCurveBlock!.length == curveBlockLength;
    final totalLen = hasCurve ? wireFullLength : wireShortLength;
    final payload = Uint8List(totalLen);

    // Offset 0: Base ID (1..6)
    payload[0] = recipe.base.wireId;

    // Offset 1: 相机原生基底标志位
    if (nativeBaseTemplate != null && nativeBaseTemplate.length >= 2) {
      payload[1] = nativeBaseTemplate[1];
    } else {
      payload[1] = _defaultNativeBaseFlag(recipe.base);
    }

    // Offset 2..21: 20 字节 ASCII 名称 (NUL 填充)
    final name20 = encodeCameraName20(recipe.cameraName);
    payload.setRange(2, 22, name20);

    // Offset 22: 0, Offset 23: 状态字节 0, Offset 24: 0xFF 哨兵
    payload[22] = 0;
    payload[23] = 0;
    payload[24] = 0xFF;

    int encodeSignedQuarter(int? q, {int sentinel = 0x7F}) {
      if (q == null) return sentinel;
      return q.clamp(-127, 127) & 0xFF;
    }

    // Offset 25..31: 7 项核心参数 (有符号 int8, 1/4 档)
    payload[25] = encodeSignedQuarter(recipe.sharpeningQuarters);
    payload[26] = encodeSignedQuarter(recipe.midRangeSharpeningQuarters ?? 0);
    payload[27] = encodeSignedQuarter(recipe.clarityQuarters ?? 0);
    payload[28] =
        hasCurve ? 0 : encodeSignedQuarter(recipe.contrastQuarters ?? 0);
    payload[29] =
        hasCurve ? 0 : encodeSignedQuarter(recipe.brightnessQuarters ?? 0);

    if (recipe.isMonochrome) {
      payload[30] =
          (nativeBaseTemplate != null && nativeBaseTemplate.length > 30)
              ? nativeBaseTemplate[30]
              : 0x80;
      payload[31] =
          (nativeBaseTemplate != null && nativeBaseTemplate.length > 31)
              ? nativeBaseTemplate[31]
              : 0x80;
      payload[32] = recipe.monoFilter.clamp(0, 4);
      payload[33] = recipe.monoToning.clamp(0, 9);
      payload[34] = recipe.monoToningSaturation.clamp(0, 7);
    } else {
      payload[30] = encodeSignedQuarter(recipe.saturationQuarters ?? 0);
      payload[31] = encodeSignedQuarter(recipe.hueQuarters ?? 0);
      payload[32] = 0xFF;
      payload[33] = 0xFF;
      payload[34] = 0xFF;
    }

    // Offset 35: 自定义曲线标志
    payload[35] = hasCurve ? 1 : 0;

    // Offset 36..613: 578 字节曲线块
    if (hasCurve) {
      payload.setRange(36, wireFullLength, recipe.rawCurveBlock!);
    }

    return payload;
  }

  static int _defaultNativeBaseFlag(PictureControlBase base) {
    switch (base) {
      case PictureControlBase.standard:
        return 0x00;
      case PictureControlBase.neutral:
        return 0x00;
      case PictureControlBase.vivid:
        return 0x00;
      case PictureControlBase.monochrome:
        return 0x01;
      case PictureControlBase.portrait:
        return 0x00;
      case PictureControlBase.landscape:
        return 0x00;
      default:
        return 0x00;
    }
  }

  /// 从相机 PTP 0x90CC 读回的 36 或 614 字节线上负载反序列化出配方结构。
  static PictureControlRecipe fromWirePayload(Uint8List wire) {
    if (wire.length < wireShortLength) {
      throw FormatException(
        'Wire payload too short: ${wire.length} bytes (expected 36 or 614).',
      );
    }
    final base = PictureControlBase.fromWireId(wire[0]);
    final name = decodeCameraName20(wire, 2);

    int? decodeSignedQuarter(int byteVal) {
      if (byteVal == 0x7F || byteVal == 0x80 || byteVal == 0xFF) return null;
      return byteVal >= 128 ? byteVal - 256 : byteVal;
    }

    final hasCurve = wire[35] == 1 && wire.length >= wireFullLength;
    final curveBlock =
        hasCurve ? Uint8List.fromList(wire.sublist(36, wireFullLength)) : null;
    final parsedCurve = curveBlock != null
        ? _parseCurveBlock(curveBlock)
        : const _ParsedCurve();

    final isMono = base == PictureControlBase.monochrome;

    return PictureControlRecipe(
      format: PictureControlFormat.np3Standard,
      cameraName: name,
      base: base,
      sharpeningQuarters: decodeSignedQuarter(wire[25]),
      midRangeSharpeningQuarters: decodeSignedQuarter(wire[26]),
      clarityQuarters: decodeSignedQuarter(wire[27]),
      contrastQuarters: hasCurve ? 0 : decodeSignedQuarter(wire[28]),
      brightnessQuarters: hasCurve ? 0 : decodeSignedQuarter(wire[29]),
      saturationQuarters: isMono ? null : decodeSignedQuarter(wire[30]),
      hueQuarters: isMono ? null : decodeSignedQuarter(wire[31]),
      monoFilter: isMono && wire[32] != 0xFF ? wire[32].clamp(0, 4) : 0,
      monoToning: isMono && wire[33] != 0xFF ? wire[33].clamp(0, 9) : 0,
      monoToningSaturation:
          isMono && wire[34] != 0xFF ? wire[34].clamp(0, 7) : 0,
      hasCustomCurve: hasCurve,
      curvePoints: parsedCurve.points,
      curveLut257: parsedCurve.lut257,
      rawCurveBlock: curveBlock,
    );
  }

  /// 校验写入负载与从相机读回的 mode 0 负载是否一致（按照协议规范仅忽略 byte 23 状态位）。
  static bool verifyWireReadback(Uint8List written, Uint8List readback) {
    if (written.length != readback.length) return false;
    for (var i = 0; i < written.length; i++) {
      if (i == 23) continue; // 状态字节允许 0 / 1 差异
      if (written[i] != readback[i]) return false;
    }
    return true;
  }

  /// 比较两份配方在成像参数上是否等价。
  ///
  /// 相机写入后可能把 36 字节短负载归一化为 614 字节长负载、改写名称填充与
  /// 原生标志位，逐字节比较会误报失败；这里只比较真正影响成像的字段。
  static bool sameParameters(
    PictureControlRecipe a,
    PictureControlRecipe b,
  ) {
    if (a.base != b.base) return false;

    // 写入时 null 会编码成 0x7F（锐度）或 0，读回 null 归一成 0，两边统一按 0 比较。
    int q(int? value) => value ?? 0;

    if (q(a.sharpeningQuarters) != q(b.sharpeningQuarters)) return false;
    if (q(a.midRangeSharpeningQuarters) != q(b.midRangeSharpeningQuarters)) {
      return false;
    }
    if (q(a.clarityQuarters) != q(b.clarityQuarters)) return false;

    if (a.hasCustomCurve) {
      if (!b.hasCustomCurve) return false;
      if (!_curveSamplesMatch(a.curveLut257, b.curveLut257)) return false;
      // 有自定义曲线时 contrast/brightness 在编码阶段被强制置 0，不参与比较。
    } else if (!b.hasCustomCurve) {
      // 相机可能给无曲线配方补上曲线块，此时读回的 contrast/brightness 为 0，跳过比较。
      if (q(a.contrastQuarters) != q(b.contrastQuarters)) return false;
      if (q(a.brightnessQuarters) != q(b.brightnessQuarters)) return false;
    }

    if (a.isMonochrome) {
      if (a.monoFilter != b.monoFilter) return false;
      if (a.monoToning != b.monoToning) return false;
      if (a.monoToningSaturation != b.monoToningSaturation) return false;
    } else {
      if (q(a.saturationQuarters) != q(b.saturationQuarters)) return false;
      if (q(a.hueQuarters) != q(b.hueQuarters)) return false;
    }
    return true;
  }

  static bool _curveSamplesMatch(List<int> a, List<int> b) {
    if (a.isEmpty || b.isEmpty) return a.isEmpty && b.isEmpty;
    const sampleIndexes = [0, 64, 128, 192, 255];
    for (final index in sampleIndexes) {
      final ai = a[index < a.length ? index : a.length - 1];
      final bi = b[index < b.length ? index : b.length - 1];
      // 相机可能对 15-bit LUT 做轻微量化，允许 0.2% 偏差。
      if ((ai - bi).abs() > 64) return false;
    }
    return true;
  }

  /// 将配方或从相机读回的线上负载编码为标准 "0300" .NP3 文件二进制。
  static Uint8List encodeNp3File(PictureControlRecipe recipe) {
    final builder = BytesBuilder();

    // Magic "NCP\0"
    builder.add(const [0x4E, 0x43, 0x50, 0x00]);

    void writeTlv(int tag, List<int> value) {
      final header = ByteData(8);
      header.setUint32(0, tag, Endian.big);
      header.setUint32(4, value.length, Endian.big);
      builder.add(header.buffer.asUint8List());
      builder.add(value);
    }

    void writeQuarterRecord(int tag, int? quarters) {
      final b = quarters == null ? 0xFF : (quarters + 128).clamp(0, 254);
      writeTlv(tag, [b, 4]);
    }

    // 0x100: Version "0300"
    writeTlv(tagVersion, ascii.encode('0300'));
    // 0x200: 20-byte ASCII name
    writeTlv(tagName, encodeCameraName20(recipe.cameraName));
    // 0x300: Base u16 BE
    final baseCode = recipe.base.fileCode;
    writeTlv(tagBase, [(baseCode >> 8) & 0xFF, baseCode & 0xFF]);
    // 0x400 & 0x500: 固定头记录
    writeTlv(tagHeader400, const [0, 0]);
    writeTlv(tagHeader500, const [255, 1]);

    // 核心参数记录
    writeQuarterRecord(tagSharpening, recipe.sharpeningQuarters);
    writeQuarterRecord(
        tagMidRangeSharpening, recipe.midRangeSharpeningQuarters);
    writeQuarterRecord(tagClarity, recipe.clarityQuarters);

    final hasCurve = recipe.hasCustomCurve &&
        recipe.rawCurveBlock != null &&
        recipe.rawCurveBlock!.length == curveBlockLength;

    if (hasCurve) {
      writeTlv(tagContrast, const [1, 4]);
      writeTlv(tagBrightness, const [1, 4]);
    } else {
      writeQuarterRecord(tagContrast, recipe.contrastQuarters ?? 0);
      writeQuarterRecord(tagBrightness, recipe.brightnessQuarters ?? 0);
    }

    if (recipe.isMonochrome) {
      writeTlv(tagSaturation, const [255, 4]);
      writeTlv(tagHue, const [255, 4]);
      writeTlv(tagMonoFilter, [recipe.monoFilter.clamp(0, 4), 1]);
      writeTlv(tagMonoToning, [recipe.monoToning.clamp(0, 9), 1]);
      writeTlv(
          tagMonoToningDensity, [recipe.monoToningSaturation.clamp(0, 7), 1]);
    } else {
      writeQuarterRecord(tagSaturation, recipe.saturationQuarters ?? 0);
      writeQuarterRecord(tagHue, recipe.hueQuarters ?? 0);
      writeTlv(tagMonoFilter, const [255, 1]);
      writeTlv(tagMonoToning, const [255, 1]);
      writeTlv(tagMonoToningDensity, const [255, 1]);
    }

    if (hasCurve) {
      writeTlv(tagCurveBlock, recipe.rawCurveBlock!);
    }

    // 4-byte 0x00000000 结束标记
    builder.add(const [0, 0, 0, 0]);
    return builder.toBytes();
  }

  /// 将 Flexible Color ("0310", base 0x0020) 配方拟合转换为标准 "0300" NP3 配方，
  /// 以便在不支持 Flexible Color 的机身（如 Z30）上写入 C1–C9 槽位。
  ///
  /// - 若原配方已包含 578 字节曲线块，则直接保留该曲线块；
  /// - 若原配方无曲线块，但设置了高光/阴影/白色/黑色色阶或对比度，则自动拟合成 5 点自定义曲线块。
  static Uint8List convertFlexibleToStandardNp3Bytes(
    PictureControlRecipe recipe, {
    String? overrideCameraName,
  }) {
    Uint8List? curveBlock = recipe.rawCurveBlock;
    List<PictureControlCurvePoint> points = recipe.curvePoints;
    var hasCurve = recipe.hasCustomCurve &&
        curveBlock != null &&
        curveBlock.length == curveBlockLength;

    if (!hasCurve) {
      final hi = (recipe.fcHighlights ?? 0).clamp(-100, 100);
      final sh = (recipe.fcShadows ?? 0).clamp(-100, 100);
      final wh = (recipe.fcWhites ?? 0).clamp(-100, 100);
      final bk = (recipe.fcBlacks ?? 0).clamp(-100, 100);
      final cQ = (recipe.contrastQuarters ?? 0).clamp(-12, 12);

      if (hi != 0 || sh != 0 || wh != 0 || bk != 0 || cQ != 0) {
        final y0 = (0 - bk * 0.22).round().clamp(0, 45);
        final y64 = (64 + sh * 0.28 - cQ * 1.2).round().clamp(8, 120);
        final y128 = (128 + (sh + hi) * 0.08).round().clamp(80, 176);
        final y192 = (192 + hi * 0.28 + cQ * 1.2).round().clamp(136, 248);
        final y255 = (255 + wh * 0.22).round().clamp(210, 255);
        points = [
          PictureControlCurvePoint(0, y0),
          PictureControlCurvePoint(64, y64),
          PictureControlCurvePoint(128, y128),
          PictureControlCurvePoint(192, y192),
          PictureControlCurvePoint(255, y255),
        ];
        curveBlock = buildCurveBlockFromPoints(points);
        hasCurve = true;
      }
    }

    // 从 8 色混合器提取整体色相微调倾向
    var hueQ = recipe.hueQuarters ?? 0;
    if (hueQ == 0 && recipe.fcBlenderBands.isNotEmpty) {
      final avgHue = recipe.fcBlenderBands
              .map((b) => b.hue)
              .fold<int>(0, (a, b) => a + b) /
          recipe.fcBlenderBands.length;
      hueQ = (avgHue / 12.0).round().clamp(-12, 12);
    }

    final standardRecipe = PictureControlRecipe(
      format: PictureControlFormat.np3Standard,
      cameraName: sanitizeCameraName(overrideCameraName ?? recipe.cameraName),
      base: PictureControlBase.standard,
      sharpeningQuarters: recipe.sharpeningQuarters ?? 8,
      midRangeSharpeningQuarters: recipe.midRangeSharpeningQuarters ?? 4,
      clarityQuarters: recipe.clarityQuarters ?? 0,
      contrastQuarters: hasCurve ? 0 : (recipe.contrastQuarters ?? 0),
      brightnessQuarters: hasCurve ? 0 : (recipe.brightnessQuarters ?? 0),
      saturationQuarters: recipe.saturationQuarters ?? 0,
      hueQuarters: hueQ,
      hasCustomCurve: hasCurve,
      curvePoints: points,
      rawCurveBlock: curveBlock,
    );
    return encodeNp3File(standardRecipe);
  }

  /// 根据控制点列表（0..255）构造标准 578 字节曲线块（包含头部与单调分段插值 257 点 15-bit LUT）。
  static Uint8List buildCurveBlockFromPoints(
    List<PictureControlCurvePoint> points,
  ) {
    final sorted = List<PictureControlCurvePoint>.from(points)
      ..sort((a, b) => a.x.compareTo(b.x));
    if (sorted.length < 2) {
      sorted
        ..clear()
        ..add(const PictureControlCurvePoint(0, 0))
        ..add(const PictureControlCurvePoint(255, 255));
    }
    final count = math.min(20, sorted.length);
    final block = Uint8List(curveBlockLength);

    // Header magic 0x49, 0x30 + bounds + gamma 0x0100
    block[0] = 0x49;
    block[1] = 0x30;
    block[2] = 0x00; // inMin
    block[3] = 0xFF; // inMax
    block[4] = 0x00; // outMin
    block[5] = 0xFF; // outMax
    block[6] = 0x01; // gamma high
    block[7] = 0x00; // gamma low
    block[8] = count;

    for (var i = 0; i < count; i++) {
      block[9 + i * 2] = sorted[i].x.clamp(0, 255);
      block[10 + i * 2] = sorted[i].y.clamp(0, 255);
    }

    // 生成 257 点 15-bit (0..32767) 平滑插值 LUT
    final bd = ByteData.sublistView(block);
    for (var i = 0; i < 257; i++) {
      final t = (i / 256.0) * 255.0;
      final yNorm =
          _evaluateSmoothCurve(sorted.take(count).toList(), t) / 255.0;
      final lutVal = (yNorm.clamp(0.0, 1.0) * 32767.0).round().clamp(0, 32767);
      bd.setUint16(64 + i * 2, lutVal, Endian.big);
    }
    return block;
  }

  static double _evaluateSmoothCurve(
    List<PictureControlCurvePoint> pts,
    double x,
  ) {
    if (x <= pts.first.x) return pts.first.y.toDouble();
    if (x >= pts.last.x) return pts.last.y.toDouble();

    // Catmull-Rom / Hermite 分段插值，确保曲线自然顺滑
    var idx = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      if (x >= pts[i].x && x <= pts[i + 1].x) {
        idx = i;
        break;
      }
    }
    final p1 = pts[idx];
    final p2 = pts[idx + 1];
    final span = (p2.x - p1.x).toDouble();
    if (span <= 1e-5) return p2.y.toDouble();
    final u = (x - p1.x) / span;

    final p0 = idx > 0 ? pts[idx - 1] : p1;
    final p3 = idx + 2 < pts.length ? pts[idx + 2] : p2;

    final m1 = (p2.y - p0.y) / math.max(1.0, (p2.x - p0.x).toDouble()) * span;
    final m2 = (p3.y - p1.y) / math.max(1.0, (p3.x - p1.x).toDouble()) * span;

    final u2 = u * u;
    final u3 = u2 * u;
    final h00 = 2 * u3 - 3 * u2 + 1;
    final h10 = u3 - 2 * u2 + u;
    final h01 = -2 * u3 + 3 * u2;
    final h11 = u3 - u2;

    return (h00 * p1.y + h10 * m1 + h01 * p2.y + h11 * m2).clamp(0.0, 255.0);
  }
}

class _ParsedCurve {
  final List<PictureControlCurvePoint> points;
  final List<int> lut257;

  const _ParsedCurve({
    this.points = const [],
    this.lut257 = const [],
  });
}
