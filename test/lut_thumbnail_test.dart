import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/editor/pro_photo_models.dart';
import 'package:zync/engine/filter/lut_engine.dart';
import 'package:zync/engine/filter/photo_filter.dart';
import 'package:zync/ui/widgets/grade_thumbnail.dart';

/// 写一个把画面整体压暗的 .cube，用于验证 LUT 是否真的进入缩略图。
File _writeDarkCube(Directory dir) {
  final buffer = StringBuffer()
    ..writeln('TITLE "darken"')
    ..writeln('LUT_3D_SIZE 5')
    ..writeln('DOMAIN_MIN 0.0 0.0 0.0')
    ..writeln('DOMAIN_MAX 1.0 1.0 1.0');
  for (var b = 0; b < 5; b++) {
    for (var g = 0; g < 5; g++) {
      for (var r = 0; r < 5; r++) {
        // 输出固定为 30% 灰：应用后整张图应变暗。
        buffer.writeln('0.3 0.3 0.3');
      }
    }
  }
  final file = File('${dir.path}/darken.cube');
  file.writeAsStringSync(buffer.toString());
  return file;
}

void main() {
  late Directory tempDir;
  late List<int> sampledR;
  late List<int> sampledG;
  late List<int> sampledB;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zync_lut_thumb');
    final image = img.Image(width: 64, height: 64, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(200, 190, 180));
    final decoded = img.decodeJpg(img.encodeJpg(image, quality: 95))!;
    sampledR = <int>[];
    sampledG = <int>[];
    sampledB = <int>[];
    for (var y = 0; y < 64; y++) {
      for (var x = 0; x < 64; x++) {
        final p = decoded.getPixel(x, y);
        sampledR.add(p.r.toInt());
        sampledG.add(p.g.toInt());
        sampledB.add(p.b.toInt());
      }
    }
  });

  tearDown(() async {
    GradeThumbnailCache.clear();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('空 LUT 路径直接返回 null，不触发文件 IO', () async {
    expect(await GradeThumbnailCache.loadLut('', 1.0), isNull);
  });

  test('强度为 0 时不加载 LUT', () async {
    expect(await GradeThumbnailCache.loadLut('/nonexistent.cube', 0.0), isNull);
  });

  test('文件不存在时返回 null', () async {
    expect(
      await GradeThumbnailCache.loadLut('${tempDir.path}/missing.cube', 1.0),
      isNull,
    );
  });

  test('非法 .cube 返回 null 而不抛异常', () async {
    final file = File('${tempDir.path}/bad.cube');
    file.writeAsStringSync('this is not a cube');
    expect(await GradeThumbnailCache.loadLut(file.path, 1.0), isNull);
  });

  test('合法 .cube 可解析并缓存复用', () async {
    final file = _writeDarkCube(tempDir);
    final first = await GradeThumbnailCache.loadLut(file.path, 1.0);
    expect(first, isNotNull);
    expect(first!.lut3d, isNotNull);
    expect(first.lut3d!.size, 5);

    final second = await GradeThumbnailCache.loadLut(file.path, 1.0);
    expect(identical(first, second), isTrue, reason: '同一 LUT 应命中缓存');
  });

  test('带 LUT 的预设产生不同于默认的缩略图', () async {
    final file = _writeDarkCube(tempDir);
    final withLut = ColorGrade(
      base: const PhotoEditAdjustments(),
      lut:
          LutRef(id: file.path, name: 'darken', path: file.path, strength: 1.0),
    );

    final base = await GradeThumbnailCache.render(
        sampledR, sampledG, sampledB, const ColorGrade());
    final graded =
        await GradeThumbnailCache.render(sampledR, sampledG, sampledB, withLut);

    expect(base, isNotNull);
    expect(graded, isNotNull);
    expect(identical(base, graded), isFalse,
        reason: 'LUT 应改变缩略图（缓存键需包含 lut 路径与强度）');
  });

  test('预加载 LUT 可跳过二次解析', () async {
    final file = _writeDarkCube(tempDir);
    final lut = CubeLutParser.parse(file.readAsStringSync());
    final withLut = ColorGrade(
      base: const PhotoEditAdjustments(),
      lut:
          LutRef(id: file.path, name: 'darken', path: file.path, strength: 1.0),
    );
    final image = await GradeThumbnailCache.render(
      sampledR,
      sampledG,
      sampledB,
      withLut,
      preloadedLut: lut,
    );
    expect(image, isNotNull);
    expect(image!.width, 64);
  });

  test('强度低于 1 时 LUT 仍生效但为混合结果', () async {
    final file = _writeDarkCube(tempDir);
    final weak = ColorGrade(
      base: const PhotoEditAdjustments(),
      lut:
          LutRef(id: file.path, name: 'darken', path: file.path, strength: 0.5),
    );
    final strong = ColorGrade(
      base: const PhotoEditAdjustments(),
      lut:
          LutRef(id: file.path, name: 'darken', path: file.path, strength: 1.0),
    );
    final a =
        await GradeThumbnailCache.render(sampledR, sampledG, sampledB, weak);
    final b =
        await GradeThumbnailCache.render(sampledR, sampledG, sampledB, strong);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(identical(a, b), isFalse, reason: '不同强度应产生不同缩略图');
  });
}
