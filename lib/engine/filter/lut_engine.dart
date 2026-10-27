import 'dart:math' as math;
import 'dart:typed_data';

/// 1D LUT：每个通道独立采样。
class Lut1D {
  final int size;
  final Float32List red;
  final Float32List green;
  final Float32List blue;

  const Lut1D(
      {required this.size,
      required this.red,
      required this.green,
      required this.blue});

  List<double> sample(double r, double g, double b) => [
        _sampleChannel(red, r),
        _sampleChannel(green, g),
        _sampleChannel(blue, b),
      ];

  static double _sampleChannel(Float32List table, double value) {
    if (table.isEmpty) return value.clamp(0.0, 1.0);
    final x = value.clamp(0.0, 1.0) * (table.length - 1);
    final i = x.floor().clamp(0, table.length - 1);
    final j = (i + 1).clamp(0, table.length - 1);
    final f = x - i;
    return (table[i] + (table[j] - table[i]) * f).clamp(0.0, 1.0);
  }
}

/// 3D LUT，按 .cube 的 R/G/B 嵌套顺序存储，使用四面体插值。
class Lut3D {
  final int size;
  final Float32List data; // size^3 * 3
  final List<double> domainMin;
  final List<double> domainMax;

  const Lut3D({
    required this.size,
    required this.data,
    this.domainMin = const [0, 0, 0],
    this.domainMax = const [1, 1, 1],
  });

  int _index(int r, int g, int b) => ((r * size + g) * size + b) * 3;

  List<double> sample(double r, double g, double b) {
    final rr = _normalize(r, 0);
    final gg = _normalize(g, 1);
    final bb = _normalize(b, 2);
    final x = rr * (size - 1);
    final y = gg * (size - 1);
    final z = bb * (size - 1);
    final x0 = x.floor().clamp(0, size - 1);
    final y0 = y.floor().clamp(0, size - 1);
    final z0 = z.floor().clamp(0, size - 1);
    final x1 = (x0 + 1).clamp(0, size - 1);
    final y1 = (y0 + 1).clamp(0, size - 1);
    final z1 = (z0 + 1).clamp(0, size - 1);
    final fx = x - x0;
    final fy = y - y0;
    final fz = z - z0;

    final c000 = _at(x0, y0, z0);
    final c100 = _at(x1, y0, z0);
    final c010 = _at(x0, y1, z0);
    final c110 = _at(x1, y1, z0);
    final c001 = _at(x0, y0, z1);
    final c101 = _at(x1, y0, z1);
    final c011 = _at(x0, y1, z1);
    final c111 = _at(x1, y1, z1);

    // 四面体插值：先确定单位立方体内的区域。
    final out = <double>[0, 0, 0];
    for (var channel = 0; channel < 3; channel++) {
      double value;
      if (fx >= fy && fy >= fz) {
        value = c000[channel] * (1 - fx) +
            c100[channel] * (fx - fy) +
            c110[channel] * (fy - fz) +
            c111[channel] * fz;
      } else if (fx >= fz && fz >= fy) {
        value = c000[channel] * (1 - fx) +
            c100[channel] * (fx - fz) +
            c101[channel] * (fz - fy) +
            c111[channel] * fy;
      } else if (fz >= fx && fx >= fy) {
        value = c000[channel] * (1 - fz) +
            c001[channel] * (fz - fx) +
            c101[channel] * (fx - fy) +
            c111[channel] * fy;
      } else if (fy >= fx && fx >= fz) {
        value = c000[channel] * (1 - fy) +
            c010[channel] * (fy - fx) +
            c110[channel] * (fx - fz) +
            c111[channel] * fz;
      } else if (fy >= fz && fz >= fx) {
        value = c000[channel] * (1 - fy) +
            c010[channel] * (fy - fz) +
            c011[channel] * (fz - fx) +
            c111[channel] * fx;
      } else {
        value = c000[channel] * (1 - fz) +
            c001[channel] * (fz - fy) +
            c011[channel] * (fy - fx) +
            c111[channel] * fx;
      }
      out[channel] = value.clamp(0.0, 1.0);
    }
    return out;
  }

  double _normalize(double value, int channel) {
    final lo = domainMin.length > channel ? domainMin[channel] : 0.0;
    final hi = domainMax.length > channel ? domainMax[channel] : 1.0;
    final span = hi - lo;
    if (span.abs() < 1e-12) return 0;
    return ((value - lo) / span).clamp(0.0, 1.0);
  }

  List<double> _at(int r, int g, int b) {
    final i = _index(r, g, b);
    return [data[i], data[i + 1], data[i + 2]];
  }

  List<double> apply(double r, double g, double b, {double strength = 1.0}) {
    final out = sample(r, g, b);
    final s = strength.clamp(0.0, 1.0);
    return [
      r + (out[0] - r) * s,
      g + (out[1] - g) * s,
      b + (out[2] - b) * s,
    ];
  }

  static Lut3D identity({int size = 33}) {
    final data = Float32List(size * size * size * 3);
    var i = 0;
    for (var r = 0; r < size; r++) {
      for (var g = 0; g < size; g++) {
        for (var b = 0; b < size; b++) {
          data[i++] = size == 1 ? 0 : r / (size - 1);
          data[i++] = size == 1 ? 0 : g / (size - 1);
          data[i++] = size == 1 ? 0 : b / (size - 1);
        }
      }
    }
    return Lut3D(size: size, data: data);
  }
}

/// .cube 解析结果，兼容 1D 和 3D LUT。
class CubeLut {
  final Lut1D? lut1d;
  final Lut3D? lut3d;

  const CubeLut({this.lut1d, this.lut3d});

  bool get is3D => lut3d != null;
  int get size => lut3d?.size ?? lut1d?.size ?? 0;

  List<double> apply(double r, double g, double b, {double strength = 1.0}) {
    final s = strength.clamp(0.0, 1.0);
    final out = lut3d?.sample(r, g, b) ?? lut1d?.sample(r, g, b) ?? [r, g, b];
    return [
      r + (out[0] - r) * s,
      g + (out[1] - g) * s,
      b + (out[2] - b) * s,
    ];
  }
}

class CubeLutParser {
  static CubeLut parse(String source) {
    final lines = source.split(RegExp(r'\r?\n'));
    int? size1d;
    int? size3d;
    final domainMin = <double>[0, 0, 0];
    final domainMax = <double>[1, 1, 1];
    final rows = <List<double>>[];

    for (final raw in lines) {
      var line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final hash = line.indexOf('#');
      if (hash >= 0) line = line.substring(0, hash).trim();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      if (upper.startsWith('TITLE')) continue;
      if (upper.startsWith('LUT_1D_SIZE')) {
        size1d = int.tryParse(line.split(RegExp(r'\s+')).last);
        continue;
      }
      if (upper.startsWith('LUT_3D_SIZE')) {
        size3d = int.tryParse(line.split(RegExp(r'\s+')).last);
        continue;
      }
      if (upper.startsWith('DOMAIN_MIN')) {
        final parts = line
            .split(RegExp(r'\s+'))
            .skip(1)
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (parts.length >= 3) {
          domainMin
            ..clear()
            ..addAll(parts.take(3));
        }
        continue;
      }
      if (upper.startsWith('DOMAIN_MAX')) {
        final parts = line
            .split(RegExp(r'\s+'))
            .skip(1)
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (parts.length >= 3) {
          domainMax
            ..clear()
            ..addAll(parts.take(3));
        }
        continue;
      }
      final values = line
          .split(RegExp(r'\s+'))
          .map(double.tryParse)
          .whereType<double>()
          .toList();
      if (values.length >= 3) rows.add(values.take(3).toList());
    }

    if (size3d != null && size3d > 1) {
      final expected = size3d * size3d * size3d;
      if (rows.length < expected) {
        throw FormatException(
            '3D LUT 数据不足: 需要 $expected 行，实际 ${rows.length} 行');
      }
      final data = Float32List(expected * 3);
      for (var i = 0; i < expected; i++) {
        data[i * 3] = rows[i][0];
        data[i * 3 + 1] = rows[i][1];
        data[i * 3 + 2] = rows[i][2];
      }
      return CubeLut(
        lut3d: Lut3D(
          size: size3d,
          data: data,
          domainMin: domainMin,
          domainMax: domainMax,
        ),
      );
    }

    if (size1d != null && size1d > 1) {
      if (rows.length < size1d) {
        throw FormatException('1D LUT 数据不足: 需要 $size1d 行，实际 ${rows.length} 行');
      }
      final red = Float32List(size1d);
      final green = Float32List(size1d);
      final blue = Float32List(size1d);
      for (var i = 0; i < size1d; i++) {
        red[i] = rows[i][0];
        green[i] = rows[i][1];
        blue[i] = rows[i][2];
      }
      return CubeLut(
          lut1d: Lut1D(size: size1d, red: red, green: green, blue: blue));
    }

    throw const FormatException('未找到 LUT_1D_SIZE 或 LUT_3D_SIZE');
  }
}

/// 常见视频对数/HLG 到 Rec.709 的技术转换。
class VideoColorTransforms {
  static List<double> nLogToRec709(double r, double g, double b) {
    double f(double v) {
      final x = v.clamp(0.0, 1.0);
      // Nikon N-Log 传递函数近似：线性化后再做 Rec.709 对比度映射。
      final linear = x <= 0.3285
          ? (x - 0.095) / 0.26
          : math.pow((x - 0.3285) / 0.67, 1 / 0.45).toDouble();
      final mapped = linear * 1.08 + 0.02;
      return mapped.clamp(0.0, 1.0);
    }

    return [f(r), f(g), f(b)];
  }

  static List<double> hlgToRec709(double r, double g, double b) {
    double f(double v) {
      final x = v.clamp(0.0, 1.0);
      // HLG 场景光到显示光的常用近似，再做 Rec.709 显示映射。
      final a = 0.17883277;
      final b = 0.28466892;
      final c = 0.55991073;
      final linear =
          x <= 0.5 ? (x * x) / 3.0 : (math.exp((x - c) / a) + b) / 12.0;
      final mapped =
          math.pow(linear.clamp(0.0, 1.0), 1 / 2.2).toDouble() * 1.05;
      return mapped.clamp(0.0, 1.0);
    }

    return [f(r), f(g), f(b)];
  }

  static List<double> applyInputTransform(
      String transform, double r, double g, double b) {
    switch (transform.toLowerCase()) {
      case 'nlog':
      case 'n-log':
        return nLogToRec709(r, g, b);
      case 'hlg':
        return hlgToRec709(r, g, b);
      default:
        return [r, g, b];
    }
  }
}
