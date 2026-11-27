import 'dart:convert';
import 'dart:typed_data';

import 'ai_provider_config.dart';
import 'ai_vision_client.dart';

/// 从服务端 `/models` 接口探测到的单个模型元数据。
class DiscoveredAiModel {
  final String id;
  final String displayName;
  final bool likelyVision;
  final String visionReason;

  const DiscoveredAiModel({
    required this.id,
    required this.displayName,
    required this.likelyVision,
    this.visionReason = '',
  });
}

/// 16×16 实测识图校验结果。
class VisionVerifyResult {
  final bool supported;
  final int latencyMs;
  final String? errorMessage;

  const VisionVerifyResult({
    required this.supported,
    this.latencyMs = 0,
    this.errorMessage,
  });
}

/// 动态模型发现与识图能力筛选引擎。
class AiModelDiscovery {
  AiModelDiscovery({AiHttpTransport? transport})
      : _transport = transport ?? const DefaultAiHttpTransport(),
        _client = AiVisionClient(transport: transport);

  final AiHttpTransport _transport;
  final AiVisionClient _client;

  /// 内置 16×16 纯灰测试 JPEG（629 字节标准基线 JPEG），用于最小成本校验模型识图能力。
  static final Uint8List tinyTestJpegBytes = base64Decode(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYIDAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkFBQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBT/wAARCAAQABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwAooooA/9k=',
  );

  static const List<String> _nonVisionKeywords = <String>[
    'embedding',
    'embed',
    'whisper',
    'tts',
    'audio',
    'speech',
    'rerank',
    'moderation',
    'dall-e',
    'flux',
    'sdxl',
    'stable-diffusion',
    'coder',
    'bge-',
    'text-moderation',
  ];

  static const List<String> _visionKeywords = <String>[
    'vl',
    'vision',
    'gpt-4o',
    'gpt-4.1',
    'gpt-4.5',
    'gpt-5',
    'o1',
    'o3',
    'o4',
    'claude-3',
    'claude-4',
    'claude-sonnet',
    'claude-opus',
    'claude-haiku',
    'gemini',
    'glm-4v',
    'glm-4.5v',
    'glm-4.6v',
    'qwen-vl',
    'qwen2.5-vl',
    'qwen3-vl',
    'qvq',
    'doubao-1.5-vision',
    'doubao-vision',
    'internvl',
    'pixtral',
    'llava',
    'minicpm-v',
    'step-1v',
    'step-1o',
    'kimi-latest',
    'grok-2-vision',
    'grok-4',
    'multimodal',
  ];

  /// 结合接口元数据与模型命名规律判定该模型是否可能具备识图能力（Vision）。
  static ({bool likely, String reason}) inspectVisionCapability(
    String modelId, [
    Map<String, dynamic>? rawItem,
  ]) {
    if (rawItem != null) {
      // OpenRouter / 标准 capability 元数据优先判断
      final caps = rawItem['capabilities'];
      if (caps is Map && caps['vision'] == true) {
        return (likely: true, reason: 'API capability: vision');
      }
      if (caps is Map && caps['vision'] == false) {
        return (likely: false, reason: 'API capability: text-only');
      }
      final arch = rawItem['architecture'];
      if (arch is Map && arch['input_modalities'] is List) {
        final mods = (arch['input_modalities'] as List)
            .map((e) => e.toString().toLowerCase())
            .toList();
        if (mods.contains('image')) {
          return (likely: true, reason: 'API input_modalities: image');
        }
        return (likely: false, reason: 'No image modality');
      }
      final modalities = rawItem['modalities'];
      if (modalities is List) {
        final mods = modalities.map((e) => e.toString().toLowerCase()).toList();
        if (mods.contains('image')) {
          return (likely: true, reason: 'API modalities: image');
        }
      }
    }

    final lower = modelId.toLowerCase();
    for (final deny in _nonVisionKeywords) {
      if (lower.contains(deny)) {
        return (likely: false, reason: 'Non-vision keyword ($deny)');
      }
    }
    for (final allow in _visionKeywords) {
      if (lower.contains(allow)) {
        return (likely: true, reason: 'Matched vision pattern ($allow)');
      }
    }
    return (likely: false, reason: 'Unclassified');
  }

  /// 调用 `/models` 拉取服务端当前可用模型列表。
  Future<List<DiscoveredAiModel>> fetchAvailableModels({
    required AiApiProtocol protocol,
    required String baseUrl,
    required String apiKey,
    Duration timeout = const Duration(seconds: 20),
    bool preferCellular = false,
  }) async {
    final cleanBase = AiProviderProfile.normalizeBaseUrl(baseUrl);
    if (cleanBase.isEmpty) {
      throw const AiHttpException(
        code: 'INVALID_BASE_URL',
        message: 'Base URL is empty',
        category: AiErrorCategory.endpointNotFound,
      );
    }

    final url = cleanBase.endsWith('/models')
        ? cleanBase
        : (RegExp(r'/v\d+(?:beta)?(?:/[a-z]+)?$').hasMatch(cleanBase)
            ? '$cleanBase/models'
            : '$cleanBase/v1/models');
    final headers = switch (protocol) {
      AiApiProtocol.openAiCompatible => <String, String>{
          'Accept': 'application/json',
          if (apiKey.trim().isNotEmpty)
            'Authorization': 'Bearer ${apiKey.trim()}',
        },
      AiApiProtocol.anthropicCompatible => <String, String>{
          'Accept': 'application/json',
          'anthropic-version': '2023-06-01',
          if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
        },
    };

    final resp = await _transport.request(
      method: 'GET',
      url: url,
      headers: headers,
      timeout: timeout,
      preferCellular: preferCellular,
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AiHttpException(
        statusCode: resp.statusCode,
        code: resp.statusCode == 401 || resp.statusCode == 403
            ? 'AUTH_FAILED'
            : 'MODELS_FETCH_FAILED',
        category: resp.statusCode == 401 || resp.statusCode == 403
            ? AiErrorCategory.auth
            : AiErrorCategory.endpointNotFound,
        endpoint: url,
        message: AiVisionClient.sanitizeForLog(
          'GET /models failed (${resp.statusCode})',
          secretKey: apiKey,
        ),
      );
    }

    return parseModelsResponse(resp.body);
  }

  static List<DiscoveredAiModel> parseModelsResponse(String rawJson) {
    final decoded = jsonDecode(rawJson);
    List<dynamic> rawList = const [];
    if (decoded is Map && decoded['data'] is List) {
      rawList = decoded['data'] as List<dynamic>;
    } else if (decoded is Map && decoded['models'] is List) {
      rawList = decoded['models'] as List<dynamic>;
    } else if (decoded is List) {
      rawList = decoded;
    }

    final models = <DiscoveredAiModel>[];
    for (final entry in rawList) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final id = (map['id'] as String? ?? map['name'] as String? ?? '').trim();
      if (id.isEmpty) continue;
      final display = (map['display_name'] as String?)?.trim();
      final inspection = inspectVisionCapability(id, map);
      models.add(DiscoveredAiModel(
        id: id,
        displayName: (display != null && display.isNotEmpty) ? display : id,
        likelyVision: inspection.likely,
        visionReason: inspection.reason,
      ));
    }

    models.sort((a, b) {
      if (a.likelyVision != b.likelyVision) {
        return a.likelyVision ? -1 : 1;
      }
      return a.id.compareTo(b.id);
    });
    return models;
  }

  /// 真实发送一张 16×16 微型 JPEG 校验模型是否支持多模态识图并测量 RTT 延迟。
  Future<VisionVerifyResult> verifyVisionSupport({
    required AiProviderProfile profile,
    required String modelId,
    required String apiKey,
  }) async {
    try {
      final res = await _client.analyzeImage(
        profile: profile,
        modelId: modelId,
        apiKey: apiKey,
        imageBytes: tinyTestJpegBytes,
        systemPrompt: 'Reply with OK only.',
        userPrompt: 'Can you see this image? Reply OK.',
        maxTokens: 16,
        temperature: 0.0,
        timeout: const Duration(seconds: 25),
        skipResize: true,
      );
      return VisionVerifyResult(
        supported: res.text.trim().isNotEmpty,
        latencyMs: res.latencyMs,
      );
    } catch (e) {
      return VisionVerifyResult(
        supported: false,
        errorMessage: AiVisionClient.sanitizeForLog('$e', secretKey: apiKey),
      );
    }
  }
}
