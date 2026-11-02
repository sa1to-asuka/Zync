import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_models.dart';

void main() {
  test('默认未启用，选择底片后激活', () {
    const settings = SpektrafilmSettings();
    expect(settings.isActive, isFalse);
    expect(settings.paperId, kSpektraDirectScanPaperId);
    expect(settings.copyWith(stockId: 'kodak_portra_400').isActive, isTrue);
    expect(
      settings.copyWith(stockId: 'kodak_portra_400').withoutStock().isActive,
      isFalse,
    );
  });

  test('原生参数顺序与 JNI 约定一致', () {
    final settings = const SpektrafilmSettings(
      stockId: 'kodak_portra_400',
      paperId: 'kodak_portra_endura',
    ).copyWith(
      filmExposure: 0.5,
      halation: 0.8,
      halationRadius: 2.0,
      grain: 0.6,
      grainRoughness: 0.5,
      enlargerWarmth: 25,
      enlargerTint: -10,
    );
    final params = settings.toNativeParams();
    expect(params, hasLength(12));
    expect(params[0], 0); // scanFilm
    expect(params[1], closeTo(0.5, 1e-9));
    expect(params[2], closeTo(0.8, 1e-9));
    expect(params[3], closeTo(2.0, 1e-9));
    expect(params[4], closeTo(0.6, 1e-9));
    expect(params[5], closeTo(0.15 + 0.5 * 0.85, 1e-9));
    expect(params[6], closeTo(10.0, 1e-9)); // warmth * 0.4
    expect(params[7], closeTo(-4.0, 1e-9)); // tint * 0.4
    expect(params[8], 1);
    expect(params[9], 1);
    expect(params[10], 1);
    expect(params[11], 42);
  });

  test('负片直扫映射为 scanFilm', () {
    const settings = SpektrafilmSettings(
      stockId: 'kodak_vision3_500t',
      paperId: kSpektraDirectScanPaperId,
    );
    expect(settings.directScan, isTrue);
    expect(settings.toNativeParams()[0], 1);
  });

  test('JSON 往返保持参数', () {
    final settings = SpektrafilmSettings(
      stockId: 'fujifilm_pro_400h',
      paperId: 'fujifilm_crystal_archive_typeii',
      intensity: 0.9,
      halation: 0.4,
      halationRadius: 1.4,
      grain: 0.7,
      grainRoughness: 0.3,
      enlargerWarmth: 8,
      enlargerTint: -6,
      filmExposure: -0.4,
    );
    expect(SpektrafilmSettings.fromJson(settings.toJson()), settings);
    expect(
      SpektrafilmSettings.fromJson(settings.toJson()).requestKey,
      settings.requestKey,
    );
  });

  test('参数范围被钳制', () {
    const settings = SpektrafilmSettings(stockId: 'kodak_portra_400');
    final clamped = settings.copyWith(
      intensity: 2,
      halation: -1,
      halationRadius: 9,
      grain: 5,
      grainRoughness: -2,
      enlargerWarmth: 400,
      enlargerTint: -400,
      filmExposure: 8,
    );
    expect(clamped.intensity, 1.0);
    expect(clamped.halation, 0.0);
    expect(clamped.halationRadius, 3.0);
    expect(clamped.grain, 1.0);
    expect(clamped.grainRoughness, 0.0);
    expect(clamped.enlargerWarmth, 100.0);
    expect(clamped.enlargerTint, -100.0);
    expect(clamped.filmExposure, 2.0);
  });
}
