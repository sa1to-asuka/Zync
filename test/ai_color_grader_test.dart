import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/ai/ai_color_grader.dart';
import 'package:zync/engine/ai/ai_provider_config.dart';
import 'package:zync/engine/ai/ai_recipe_catalog.dart';
import 'package:zync/engine/ai/ai_vision_client.dart';
import 'package:zync/engine/filter/photo_filter.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_models.dart';

class _MockColorHttpTransport implements AiHttpTransport {
  final String replyBody;
  int callCount = 0;

  _MockColorHttpTransport(this.replyBody);

  @override
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 45),
    bool preferCellular = false,
  }) async {
    callCount++;
    return (statusCode: 200, body: replyBody);
  }
}

void main() {
  group('AiColorGrader 安全护栏、强度缩放与离线兜底', () {
    test('ImageColorStats 计算亮部/暗部占比与冷暖偏移', () {
      final stats = ImageColorStats.fromRgbSamples(
        [250, 200, 10, 5],
        [248, 190, 12, 8],
        [240, 170, 20, 15],
      );
      expect(stats.avgLuma, inInclusiveRange(0.0, 1.0));
      expect(stats.highlightFraction, greaterThan(0.2));
      expect(stats.shadowFraction, greaterThan(0.2));
      expect(stats.dynamicSpread, greaterThan(0.5));
    });

    test('clampSafeAdjustments 限制极端幻觉参数并归一化色相角', () {
      const crazy = PhotoEditAdjustments(
        temperature: 120,
        tint: -95,
        exposure: 99,
        contrast: -80,
        highlights: 100,
        shadows: -90,
        whites: 90,
        blacks: -90,
        texture: 80,
        clarity: 80,
        dehaze: 80,
        vibrance: 95,
        saturation: 90,
        highlightHue: 400,
        highlightSat: 99,
        shadowHue: -30,
        shadowSat: 99,
        vignette: 95,
        grain: 90,
      );
      final clamped = AiColorGrader.clampSafeAdjustments(crazy);
      expect(clamped.temperature, 55);
      expect(clamped.tint, -40);
      expect(clamped.exposure, 55);
      expect(clamped.contrast, -45);
      expect(clamped.highlights, 55);
      expect(clamped.shadows, -45);
      expect(clamped.highlightHue, 40);
      expect(clamped.shadowHue, 330);
      expect(clamped.highlightSat, 55);
      expect(clamped.grain, 45);
    });

    test('scaleAdjustments 支持 0% 到 150% 缩放并保留色相角', () {
      const base = PhotoEditAdjustments(
        exposure: 20,
        contrast: 10,
        highlightHue: 42,
        highlightSat: 20,
      );
      final zero = AiColorGrader.scaleAdjustments(base, 0.0);
      expect(zero.exposure, 0);
      expect(zero.contrast, 0);
      expect(zero.highlightSat, 0);
      expect(zero.highlightHue, 42);

      final boost = AiColorGrader.scaleAdjustments(base, 1.5);
      expect(boost.exposure, closeTo(30, 1e-6));
      expect(boost.contrast, closeTo(15, 1e-6));
      expect(boost.highlightSat, closeTo(30, 1e-6));
    });

    test('analyzeOfflineFallback 生成 Natural / Cinematic / Film 三套合法方案', () {
      const stats = ImageColorStats(
        avgLuma: 0.72,
        shadowFraction: 0.05,
        highlightFraction: 0.25,
        dynamicSpread: 0.4,
        warmBias: 0.1,
        greenTint: 0.0,
        avgSaturation: 0.22,
      );
      final bundle = AiColorGrader.analyzeOfflineFallback(
        stats: stats,
        styleHint: '日系通透',
        localeCode: 'zh',
      );
      expect(bundle.isOfflineFallback, isTrue);
      expect(bundle.variants.length, 3);
      expect(
        bundle.variants.map((v) => v.id).toList(),
        ['natural', 'cinematic', 'film'],
      );
      expect(bundle.variants[0].adjustments.highlights, lessThan(0));
      // 中文环境下离线兜底必须 100% 中文，不再残留英文 Luma / Clean Natural
      expect(bundle.diagnosis, contains('画面平均亮度'));
      expect(bundle.diagnosis, isNot(contains('Luma')));
      for (final v in bundle.variants) {
        expect(v.name, isNot(equals('Clean Natural')));
        expect(v.name, isNot(equals('Teal Cinema')));
        expect(v.name, isNot(equals('Nostalgic Film')));
      }
    });

    test('Mock 视觉 API 解析 gradePhoto 3 套方案与 refineVariant 微调', () async {
      final gradeTransport = _MockColorHttpTransport('''
{
  "choices": [{
    "message": {
      "content": "{\\"diagnosis\\":\\"Slightly underexposed\\",\\"variants\\":[{\\"id\\":\\"natural\\",\\"name\\":\\"Clear\\",\\"rationale\\":\\"Balanced\\",\\"adjustments\\":{\\"exposure\\":18,\\"shadows\\":24}},{\\"id\\":\\"cinematic\\",\\"name\\":\\"Teal\\",\\"rationale\\":\\"Drama\\",\\"adjustments\\":{\\"contrast\\":20,\\"shadowHue\\":205,\\"shadowSat\\":25}},{\\"id\\":\\"film\\",\\"name\\":\\"Kodak\\",\\"rationale\\":\\"Warm\\",\\"adjustments\\":{\\"temperature\\":12,\\"grain\\":16}}]}"
    }
  }]
}
''');
      final grader = AiColorGrader(
        client: AiVisionClient(transport: gradeTransport),
      );
      const profile = AiProviderProfile(
        id: 'p1',
        name: 'Test',
        protocol: AiApiProtocol.openAiCompatible,
        baseUrl: 'https://api.example.com/v1',
      );
      final validJpeg = AiColorGraderTestAssets.tinyJpeg;
      final bundle = await grader.gradePhoto(
        profile: profile,
        modelId: 'gpt-4o',
        apiKey: 'sk-test',
        imageBytes: validJpeg,
        styleHint: 'warm portrait',
      );
      expect(bundle.variants.length, 3);
      expect(bundle.variants[1].adjustments.shadowHue, 205);

      final refineTransport = _MockColorHttpTransport('''
{
  "choices": [{
    "message": {
      "content": "{\\"id\\":\\"natural\\",\\"name\\":\\"Brighter Clear\\",\\"rationale\\":\\"Lifted exposure\\",\\"adjustments\\":{\\"exposure\\":28,\\"shadows\\":32}}"
    }
  }]
}
''');
      final refiner = AiColorGrader(
        client: AiVisionClient(transport: refineTransport),
      );
      final refined = await refiner.refineVariant(
        profile: profile,
        modelId: 'gpt-4o',
        apiKey: 'sk-test',
        imageBytes: validJpeg,
        currentVariant: bundle.variants.first,
        instruction: '再提亮一点',
      );
      expect(refined.name, 'Brighter Clear');
      expect(refined.adjustments.exposure, 28);
    });

    test('AiRecipeCatalog 注入三大库目录并把 AI 返回 recipeId 映射至真实滤镜/胶片',
        () async {
      late String capturedPromptBody;
      final transport = _MockColorHttpTransportWithCapture(
        onRequest: (body) {
          capturedPromptBody = body ?? '';
          return '''
{
  "choices": [{
    "message": {
      "content": "<think>Analyzing street photo for Shinkai sky...</think>{\\"diagnosis\\":\\"晴朗街头画面\\",\\"variants\\":[{\\"id\\":\\"best_match\\",\\"name\\":\\"晴空新海诚\\",\\"recipeId\\":\\"filter:shinkaiAnime\\",\\"recipeIntensity\\":0.85,\\"rationale\\":\\"提亮蓝青空气感\\",\\"adjustments\\":{\\"exposure\\":8,\\"vibrance\\":12}},{\\"id\\":\\"atmospheric\\",\\"name\\":\\"日系通透\\",\\"recipeId\\":\\"spektra:fujifilm_pro_400h\\",\\"recipeIntensity\\":0.8,\\"rationale\\":\\"真实物理底片柔和高光\\",\\"adjustments\\":{\\"highlights\\":-10}},{\\"id\\":\\"film_alt\\",\\"name\\":\\"兜底纠偏\\",\\"recipeId\\":\\"hallucinated_fake_filter\\",\\"recipeIntensity\\":0.9,\\"rationale\\":\\"新海诚日系晴空\\",\\"adjustments\\":{\\"contrast\\":6}}]}"
    }
  }]
}
''';
        },
      );

      final stocks = [
        const SpektraStockInfo(
          id: 'fujifilm_pro_400h',
          name: 'Fujifilm PRO 400H',
          targetPrint: 'kodak_endura',
          use: 'still',
        ),
      ];
      final grader = AiColorGrader(
        client: AiVisionClient(transport: transport),
      );
      const profile = AiProviderProfile(
        id: 'p1',
        name: 'Test',
        protocol: AiApiProtocol.openAiCompatible,
        baseUrl: 'https://api.example.com/v1',
      );
      final bundle = await grader.gradePhoto(
        profile: profile,
        modelId: 'gpt-4o',
        apiKey: 'sk-test',
        imageBytes: AiColorGraderTestAssets.tinyJpeg,
        styleHint: '新海诚日系风格',
        spektraStocks: stocks,
      );

      expect(capturedPromptBody, contains('filter:shinkaiAnime'));
      expect(capturedPromptBody, contains('spektra:fujifilm_pro_400h'));
      expect(capturedPromptBody, contains('preset:'));
      expect(capturedPromptBody, contains('简体中文'));
      expect(capturedPromptBody, contains('4096'));

      expect(bundle.variants[0].kind, AiGradeRecipeKind.filter);
      expect(bundle.variants[0].recipeId, 'filter:shinkaiAnime');
      expect(bundle.variants[0].recipeIntensity, closeTo(0.85, 1e-6));

      expect(bundle.variants[1].kind, AiGradeRecipeKind.spektraFilm);
      expect(bundle.variants[1].recipeId, 'spektra:fujifilm_pro_400h');

      // 第三条返回幻觉 ID 时应自动纠偏映射到真实目录，不保留虚假 ID
      expect(
        bundle.variants[2].recipeId,
        isNot(equals('hallucinated_fake_filter')),
      );
      expect(bundle.variants[2].kind, isNot(AiGradeRecipeKind.customAdjustments));
      // 验证 selectForPrompt 精简为 <= 36 条目且三大库均被代表（大幅降低推理延迟）
      final fullCatalog = AiRecipeCatalog.buildAll(spektraStocks: stocks);
      final compactPromptList =
          fullCatalog.selectForPrompt(styleHint: '新海诚日系风格');
      expect(compactPromptList.length, lessThanOrEqualTo(36));
      expect(
        compactPromptList.any((e) => e.id == 'filter:shinkaiAnime'),
        isTrue,
      );
      expect(
        compactPromptList.any((e) => e.kind == AiGradeRecipeKind.spektraFilm),
        isTrue,
      );
      expect(
        compactPromptList.any((e) => e.kind == AiGradeRecipeKind.builtinPreset),
        isTrue,
      );
    });
  });
}

class _MockColorHttpTransportWithCapture implements AiHttpTransport {
  final String Function(String? body) onRequest;

  _MockColorHttpTransportWithCapture({required this.onRequest});

  @override
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 45),
    bool preferCellular = false,
  }) async {
    return (statusCode: 200, body: onRequest(body));
  }
}

class AiColorGraderTestAssets {
  static final Uint8List tinyJpeg = () {
    final im = img.Image(width: 24, height: 16);
    img.fill(im, color: img.ColorRgb8(128, 128, 128));
    return Uint8List.fromList(img.encodeJpg(im, quality: 80));
  }();
}
