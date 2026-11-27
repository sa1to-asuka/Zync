import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/ai/ai_model_discovery.dart';
import 'package:zync/engine/ai/ai_provider_config.dart';
import 'package:zync/engine/ai/ai_vision_client.dart';

class _InMemoryVault implements AiSecretVault {
  final Map<String, String> store = {};

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;
}

class _FakeDiscoveryTransport implements AiHttpTransport {
  final Map<String, ({int statusCode, String body})> routes;

  _FakeDiscoveryTransport(this.routes);

  @override
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 45),
    bool preferCellular = false,
  }) async {
    for (final e in routes.entries) {
      if (url.contains(e.key)) return e.value;
    }
    return (statusCode: 404, body: '{"error":{"message":"not found"}}');
  }
}

void main() {
  group('AI Provider 配置与 Key 隔离存储', () {
    test('API Key 仅存放在 AiSecretVault，绝不写入明文 JSON 配置文件', () async {
      final tmp = await Directory.systemTemp.createTemp('zync_ai_cfg_');
      try {
        final vault = _InMemoryVault();
        final store = AiSettingsStore.createForTesting(vault: vault);
        await store.ensureInitialized(overrideDirectory: tmp);

        const secret = 'sk-super-secret-token-987654';
        const profile = AiProviderProfile(
          id: 'p_openai',
          name: 'OpenAI',
          protocol: AiApiProtocol.openAiCompatible,
          baseUrl: 'https://api.openai.com/v1///',
          importedModels: [
            AiImportedModel(id: 'gpt-4o', displayName: 'GPT-4o'),
          ],
        );

        await store.upsertProfile(profile, apiKey: secret);
        final jsonFile = File('${tmp.path}/zync_ai_settings.json');
        expect(await jsonFile.exists(), isTrue);
        final plainText = await jsonFile.readAsString();
        expect(plainText, isNot(contains(secret)));
        expect(vault.store.values, contains(secret));

        final target = store.resolveCoachTarget();
        expect(target, isNotNull);
        expect(target!.profile.baseUrl, 'https://api.openai.com/v1');
        expect(target.apiKey, secret);
        expect(store.isTargetMissingApiKey(target), isFalse);
        expect(store.hasConfiguredApiKey, isTrue);
        expect(AiSettingsStore.maskApiKey(secret), 'sk-••••7654');

        // 校验云端无 Key 档案判定缺失，本地 Ollama 带模型允许无 Key
        await store.upsertProfile(
          const AiProviderProfile(
            id: 'p_empty_cloud',
            name: 'Empty Cloud',
            protocol: AiApiProtocol.openAiCompatible,
            baseUrl: 'https://api.deepseek.com/v1',
            importedModels: [
              AiImportedModel(id: 'deepseek-chat', displayName: 'deepseek-chat'),
            ],
          ),
          apiKey: '',
        );
        await store.setActiveGrade('p_empty_cloud', 'deepseek-chat');
        expect(store.isTargetMissingApiKey(store.resolveGradeTarget()), isTrue);
        expect(AiSettingsStore.isLocalBaseUrl('http://192.168.1.100:11434/v1'), isTrue);
        expect(AiSettingsStore.isLocalBaseUrl('https://api.deepseek.com/v1'), isFalse);
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });

  group('AiModelDiscovery 模型探测与识图能力筛选', () {
    test('inspectVisionCapability 不拦截 DeepSeek 模型并保留多语言预设', () {
      expect(AiModelDiscovery.inspectVisionCapability('qwen-vl-max').likely, isTrue);
      expect(AiModelDiscovery.inspectVisionCapability('claude-3-7-sonnet').likely, isTrue);
      expect(AiModelDiscovery.inspectVisionCapability('text-embedding-3-large').likely, isFalse);
      expect(
        AiModelDiscovery.inspectVisionCapability('custom-model', {
          'capabilities': {'vision': true},
        }).likely,
        isTrue,
      );
      final deepseek = AiEndpointQuickPreset.presets
          .where((p) => p.id == 'deepseek')
          .firstOrNull;
      expect(deepseek, isNotNull);
      expect(deepseek!.defaultBaseUrl, 'https://api.deepseek.com/v1');
      expect(deepseek.localizedName('zh'), 'DeepSeek 官方');
      expect(deepseek.localizedName('en'), 'DeepSeek Official');
      expect(deepseek.localizedName('ja'), 'DeepSeek 公式');
    });

    test('fetchAvailableModels 将识图模型置顶排序，verifyVisionSupport 校验 16x16 识图', () async {
      final transport = _FakeDiscoveryTransport({
        '/models': (
          statusCode: 200,
          body: jsonEncode({
            'data': [
              {'id': 'text-embedding-3-small'},
              {'id': 'gpt-4o-mini'},
              {'id': 'qwen2.5-vl-72b'},
            ],
          }),
        ),
        '/chat/completions': (
          statusCode: 200,
          body: jsonEncode({
            'choices': [
              {
                'message': {'content': 'OK'}
              }
            ],
          }),
        ),
      });

      final discovery = AiModelDiscovery(transport: transport);
      final models = await discovery.fetchAvailableModels(
        protocol: AiApiProtocol.openAiCompatible,
        baseUrl: 'https://api.example.com/v1',
        apiKey: 'sk-test',
      );
      expect(models.length, 3);
      expect(models.first.likelyVision, isTrue);
      expect(models.last.id, 'text-embedding-3-small');
      expect(models.last.likelyVision, isFalse);

      const profile = AiProviderProfile(
        id: 'p1',
        name: 'Test',
        protocol: AiApiProtocol.openAiCompatible,
        baseUrl: 'https://api.example.com/v1',
      );
      final verify = await discovery.verifyVisionSupport(
        profile: profile,
        modelId: 'gpt-4o-mini',
        apiKey: 'sk-test',
      );
      expect(verify.supported, isTrue);
    });

    test('resolveEndpointUrl、extractJsonObject(<think>) 与错误语义分类', () async {
      expect(
        AiVisionClient.resolveEndpointUrl(
          AiApiProtocol.openAiCompatible,
          'https://api.deepseek.com',
        ),
        'https://api.deepseek.com/v1/chat/completions',
      );
      expect(
        AiVisionClient.resolveEndpointUrl(
          AiApiProtocol.anthropicCompatible,
          'https://api.deepseek.com/anthropic',
        ),
        'https://api.deepseek.com/anthropic/v1/messages',
      );

      final parsed = AiVisionClient.extractJsonObject(
        '<think>Reasoning process with {brace}</think>\n```json\n{"ok":true,"score":95}\n```',
      );
      expect(parsed['ok'], isTrue);
      expect(parsed['score'], 95);

      // 模拟第 29 行截断的未闭合代码块 JSON（复现 DeepSeek token 截断场景）
      const truncated29Lines = '''<think>先分析逆光树墙...</think>
```json
{
  "diagnosis": "树影与石墙夕阳暖光",
  "variants": [
    {
      "id": "natural",
      "name": "新海诚晴空",
      "recipeId": "filter:shinkaiAnime",
      "recipeIntensity": 0.85,
      "rationale": "提亮暗部同时保留夕阳暖调",
      "adjustments": {
        "temperature": 6,
        "tint": 0,
        "exposure": 8,
        "contrast": 6,
        "highlights": -16,
        "shadows": 18,
        "whites": 2,
        "blacks": -4,
        "texture": 0,
        "clarity": 4,
        "dehaze": 0,
        "vibrance": 12,
        "saturation": 4,
        "highlightHue": 40,
        "highlightSat": 8,
        "vignette": -4,
        "grain": 4
      }
    },
    {
      "id": "cinem''';
      final repaired = AiVisionClient.extractJsonObject(truncated29Lines);
      expect(repaired['diagnosis'], '树影与石墙夕阳暖光');
      expect((repaired['variants'] as List).length, 1);
      expect(
        ((repaired['variants'] as List).first as Map)['name'],
        '新海诚晴空',
      );

      // 模拟 DeepSeek 官方纯文本端点首次拒绝 image_url (untagged enum)，自动桥接空间视觉遥测并成功返回中文结果
      final capturedBodies = <String>[];
      final deepSeekBridgeTransport = _CallbackTransport((body) {
        final reqText = body ?? '';
        capturedBodies.add(reqText);
        if (reqText.contains('"image_url"')) {
          return (
            statusCode: 422,
            body:
                '{"error":{"message":"Failed to deserialize the JSON body into the target type: messages[1]: data did not match any variant of untagged enum"}}',
          );
        }
        return (
          statusCode: 200,
          body: jsonEncode({
            'choices': [
              {
                'message': {
                  'content': '{"diagnosis":"暖阳树影石墙","ok":true}',
                },
              },
            ],
          }),
        );
      });
      final bridgeClient = AiVisionClient(transport: deepSeekBridgeTransport);
      final bridgeRes = await bridgeClient.analyzeImage(
        profile: const AiProviderProfile(
          id: 'd_official',
          name: 'DeepSeek 官方',
          protocol: AiApiProtocol.openAiCompatible,
          baseUrl: 'https://api.deepseek.com/v1',
        ),
        modelId: 'deepseek-reasoner',
        apiKey: 'sk-test',
        imageBytes: AiModelDiscovery.tinyTestJpegBytes,
        systemPrompt: 'sys',
        userPrompt: '请给出中文调色',
        skipResize: true,
      );
      expect(capturedBodies.length, 2);
      // deepseek-reasoner 不携带过小的 max_tokens 限制
      expect(jsonDecode(capturedBodies.first).containsKey('max_tokens'), isFalse);
      expect(capturedBodies.last, contains('Measured Image Visual Telemetry'));
      expect(capturedBodies.last, isNot(contains('"image_url"')));
      expect(AiVisionClient.extractJsonObject(bridgeRes.text)['diagnosis'], '暖阳树影石墙');

      // 若纯文本与多模态均返回 400 vision 错误，则抛出可诊断的 unsupportedVision 异常
      final transport400 = _FakeDiscoveryTransport({
        '/chat/completions': (
          statusCode: 400,
          body: '{"error":{"message":"unknown variant `image_url`, expected text"}}',
        ),
      });
      final client = AiVisionClient(transport: transport400);
      await expectLater(
        () => client.analyzeImage(
          profile: const AiProviderProfile(
            id: 'd1',
            name: 'DeepSeek',
            protocol: AiApiProtocol.openAiCompatible,
            baseUrl: 'https://api.deepseek.com/v1',
          ),
          modelId: 'deepseek-chat',
          apiKey: 'sk-test',
          imageBytes: AiModelDiscovery.tinyTestJpegBytes,
          systemPrompt: 'sys',
          userPrompt: 'usr',
          skipResize: true,
        ),
        throwsA(
          isA<AiHttpException>()
              .having((e) => e.category, 'category', AiErrorCategory.unsupportedVision)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });
  });
}

class _CallbackTransport implements AiHttpTransport {
  final ({int statusCode, String body}) Function(String? body) handler;

  _CallbackTransport(this.handler);

  @override
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 75),
    bool preferCellular = false,
  }) async {
    return handler(body);
  }
}
