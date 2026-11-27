import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../protocol/camera_native_bridge.dart';
import 'ai_provider_config.dart';

/// AI 请求失败语义分类，便于前端给出准确诊断而非静默伪装离线结果。
enum AiErrorCategory {
  network,
  auth,
  endpointNotFound,
  unsupportedVision,
  rateLimit,
  serverError,
  parseError,
}

/// HTTP 请求异常（带分类错误码、语义类别、脱敏端点与消息）。
class AiHttpException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final AiErrorCategory category;
  final String? endpoint;

  const AiHttpException({
    this.statusCode = 0,
    required this.code,
    required this.message,
    this.category = AiErrorCategory.serverError,
    this.endpoint,
  });

  @override
  String toString() {
    final ep = endpoint != null && endpoint!.isNotEmpty ? ' [$endpoint]' : '';
    return 'AiHttpException($code, status=$statusCode)$ep: $message';
  }
}

/// 可注入 HTTP 传输接口（供单测 Mock 与真实网络共用）。
abstract class AiHttpTransport {
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 75),
    bool preferCellular = false,
  });
}

class DefaultAiHttpTransport implements AiHttpTransport {
  const DefaultAiHttpTransport();

  @override
  Future<({int statusCode, String body})> request({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    Duration timeout = const Duration(seconds: 75),
    bool preferCellular = false,
  }) async {
    Object? cellularFailure;
    if (preferCellular) {
      try {
        final cell = await CameraNativeBridge.httpRequestOverCellular(
          method: method,
          url: url,
          headers: headers,
          body: body,
          timeoutMs: timeout.inMilliseconds,
        );
        if (cell != null) {
          final status = cell['statusCode'] as int? ?? 0;
          if (status > 0) {
            return (
              statusCode: status,
              body: cell['body'] as String? ?? '',
            );
          }
          cellularFailure = AiHttpException(
            code: cell['errorCode'] as String? ?? 'CELLULAR_ERROR',
            message:
                cell['errorMessage'] as String? ?? 'Cellular request failed',
            category: AiErrorCategory.network,
            endpoint: url,
          );
        }
      } catch (e) {
        cellularFailure = e;
      }
    }

    try {
      return await _directRequest(
        method: method,
        url: url,
        headers: headers,
        body: body,
        timeout: timeout,
      );
    } catch (e) {
      if (e is AiHttpException) rethrow;
      final isTransientNet = e is SocketException ||
          e is HttpException ||
          e is HandshakeException ||
          e is TlsException ||
          e is TimeoutException;
      if (!isTransientNet) rethrow;

      if (!preferCellular && AiSettingsStore.instance.allowCellularBypassInAp) {
        try {
          final cell = await CameraNativeBridge.httpRequestOverCellular(
            method: method,
            url: url,
            headers: headers,
            body: body,
            timeoutMs: timeout.inMilliseconds,
          );
          if (cell != null) {
            final status = cell['statusCode'] as int? ?? 0;
            if (status > 0) {
              return (
                statusCode: status,
                body: cell['body'] as String? ?? '',
              );
            }
            final errCode = cell['errorCode'] as String? ?? 'NETWORK_ERROR';
            final errMsg =
                cell['errorMessage'] as String? ?? 'Network unreachable';
            throw AiHttpException(
              code: errCode,
              message: '$errMsg (direct error: $e)',
              category: AiErrorCategory.network,
              endpoint: url,
            );
          }
        } catch (cellErr) {
          if (cellErr is AiHttpException) rethrow;
        }
      }

      final detail = cellularFailure != null ? '$e ($cellularFailure)' : '$e';
      throw AiHttpException(
        code: e is TimeoutException ? 'TIMEOUT' : 'NETWORK_ERROR',
        message: detail,
        category: AiErrorCategory.network,
        endpoint: url,
      );
    }
  }

  Future<({int statusCode, String body})> _directRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    final uri = Uri.parse(url);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.openUrl(method.toUpperCase(), uri).timeout(timeout);
      headers.forEach((k, v) => req.headers.set(k, v));
      if (body != null) {
        final bytes = utf8.encode(body);
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final resp = await req.close().timeout(timeout);
      final respBody =
          await resp.transform(utf8.decoder).join().timeout(timeout);
      return (statusCode: resp.statusCode, body: respBody);
    } finally {
      client.close(force: true);
    }
  }
}

/// 统一多模态图像理解客户端（支持 OpenAI 兼容 + Anthropic 兼容协议）。
class AiVisionClient {
  AiVisionClient({AiHttpTransport? transport})
      : _transport = transport ?? const DefaultAiHttpTransport();

  final AiHttpTransport _transport;

  /// 根据协议与输入 Base URL 智能补全完整聊天/消息请求端点。
  static String resolveEndpointUrl(AiApiProtocol protocol, String baseUrl) {
    final clean = AiProviderProfile.normalizeBaseUrl(baseUrl);
    if (clean.isEmpty) return '';
    if (protocol == AiApiProtocol.openAiCompatible) {
      if (clean.endsWith('/chat/completions')) return clean;
      if (RegExp(r'/v\d+(?:beta)?(?:/openai)?$').hasMatch(clean)) {
        return '$clean/chat/completions';
      }
      return '$clean/v1/chat/completions';
    } else {
      if (clean.endsWith('/messages')) return clean;
      if (RegExp(r'/v\d+(?:/[a-z]+)?$').hasMatch(clean)) {
        return '$clean/messages';
      }
      if (clean.endsWith('/anthropic')) {
        return '$clean/v1/messages';
      }
      return '$clean/v1/messages';
    }
  }

  /// 判断是否为推理模型（如 `deepseek-reasoner`、`qwq`、`o1`/`o3` 等），
  /// 此类模型若受限过小的 `max_tokens` 或 `temperature` 极易被思考链耗尽输出预算。
  static bool isReasoningModel(String modelId) => RegExp(
        r'(reasoner|deepseek-r1|\br1\b|\bqwq\b|thinking|\bo1\b|\bo3\b|\bo4\b)',
        caseSensitive: false,
      ).hasMatch(modelId);

  /// 发送图像与 Prompt，返回解析后的文本与耗时毫秒。
  /// 当端点拒绝多模态 `image_url` 结构（例如 DeepSeek 官方纯文本模型）时，
  /// 自动计算本地 3×3 空间亮度/色彩/边缘结构遥测并降级为纯文本推理请求。
  Future<({String text, int latencyMs})> analyzeImage({
    required AiProviderProfile profile,
    required String modelId,
    required String apiKey,
    required Uint8List imageBytes,
    required String systemPrompt,
    required String userPrompt,
    int maxEdge = 1024,
    int jpegQuality = 82,
    int maxTokens = 4096,
    double temperature = 0.25,
    Duration timeout = const Duration(seconds: 75),
    bool skipResize = false,
    bool preferCellular = false,
  }) async {
    final cleanBase = AiProviderProfile.normalizeBaseUrl(profile.baseUrl);
    if (cleanBase.isEmpty) {
      throw const AiHttpException(
        code: 'INVALID_BASE_URL',
        message: 'Base URL is empty',
        category: AiErrorCategory.endpointNotFound,
      );
    }

    final Uint8List preparedJpeg = skipResize
        ? imageBytes
        : await prepareJpegForVision(
            imageBytes,
            maxEdge: maxEdge,
            quality: jpegQuality,
          );
    final b64 = base64Encode(preparedJpeg);

    final stopwatch = Stopwatch()..start();
    final ({String url, Map<String, String> headers, String payload}) reqSpec =
        switch (profile.protocol) {
      AiApiProtocol.openAiCompatible => _buildOpenAiRequest(
          baseUrl: cleanBase,
          apiKey: apiKey,
          modelId: modelId,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          jpegBase64: b64,
          maxTokens: maxTokens,
          temperature: temperature,
        ),
      AiApiProtocol.anthropicCompatible => _buildAnthropicRequest(
          baseUrl: cleanBase,
          apiKey: apiKey,
          modelId: modelId,
          systemPrompt: systemPrompt,
          userPrompt: userPrompt,
          jpegBase64: b64,
          maxTokens: maxTokens,
          temperature: temperature,
        ),
    };

    try {
      final resp = await _transport.request(
        method: 'POST',
        url: reqSpec.url,
        headers: reqSpec.headers,
        body: reqSpec.payload,
        timeout: timeout,
        preferCellular: preferCellular,
      );
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw _classifyHttpError(
          resp.statusCode,
          resp.body,
          apiKey,
          endpoint: reqSpec.url,
        );
      }
      stopwatch.stop();
      final text = _extractAssistantText(profile.protocol, resp.body);
      return (text: text, latencyMs: stopwatch.elapsedMilliseconds);
    } on AiHttpException catch (e) {
      if (e.category != AiErrorCategory.unsupportedVision) rethrow;

      final visualSummary = await buildStructuredVisualSummary(preparedJpeg);
      final augmentedPrompt =
          '$userPrompt\n\n[Measured Image Visual Telemetry — endpoint does not accept raw image bytes, reason strictly from these real spatial/color measurements of the user\'s photo]\n$visualSummary';

      final ({String url, Map<String, String> headers, String payload}) textSpec =
          switch (profile.protocol) {
        AiApiProtocol.openAiCompatible => _buildOpenAiTextRequest(
            baseUrl: cleanBase,
            apiKey: apiKey,
            modelId: modelId,
            systemPrompt: systemPrompt,
            userPrompt: augmentedPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
        AiApiProtocol.anthropicCompatible => _buildAnthropicTextRequest(
            baseUrl: cleanBase,
            apiKey: apiKey,
            modelId: modelId,
            systemPrompt: systemPrompt,
            userPrompt: augmentedPrompt,
            maxTokens: maxTokens,
            temperature: temperature,
          ),
      };

      final textResp = await _transport.request(
        method: 'POST',
        url: textSpec.url,
        headers: textSpec.headers,
        body: textSpec.payload,
        timeout: timeout,
        preferCellular: preferCellular,
      );
      stopwatch.stop();
      if (textResp.statusCode < 200 || textResp.statusCode >= 300) {
        throw _classifyHttpError(
          textResp.statusCode,
          textResp.body,
          apiKey,
          endpoint: textSpec.url,
        );
      }
      final text = _extractAssistantText(profile.protocol, textResp.body);
      return (text: text, latencyMs: stopwatch.elapsedMilliseconds);
    }
  }

  /// 在后台 Isolate 压缩图像并重新编码为干净 JPEG（天然剥离 GPS 等敏感 EXIF）。
  static Future<Uint8List> prepareJpegForVision(
    Uint8List sourceBytes, {
    int maxEdge = 1024,
    int quality = 82,
  }) {
    return Isolate.run(() {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;
      final longest =
          decoded.width > decoded.height ? decoded.width : decoded.height;
      final resized = longest > maxEdge
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? maxEdge : null,
              height: decoded.height > decoded.width ? maxEdge : null,
              interpolation: img.Interpolation.linear,
            )
          : decoded;
      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    });
  }

  /// 从 JPEG 字节计算紧凑的 3×3 空间影调、色彩与边缘显著性摘要（用于纯文本大模型精准推理）。
  static Future<String> buildStructuredVisualSummary(Uint8List jpegBytes) {
    return Isolate.run(() {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return 'dimensions: unknown';
      }
      final small = decoded.width > 192
          ? img.copyResize(decoded, width: 192)
          : decoded;
      final w = small.width;
      final h = small.height;
      final totalPx = math.max(1, w * h);
      final orient = (decoded.width - decoded.height).abs() <
              (math.max(decoded.width, decoded.height) * 0.05)
          ? 'square'
          : (decoded.width > decoded.height ? 'landscape' : 'portrait');

      var sumLuma = 0.0;
      var shadows = 0;
      var highlights = 0;
      var clipped = 0;
      var sumWarm = 0.0;
      var sumTint = 0.0;
      var sumSat = 0.0;

      final lumaGrid = Float64List(totalPx);
      const zoneNames = [
        'top-left',
        'top-center',
        'top-right',
        'mid-left',
        'center',
        'mid-right',
        'bottom-left',
        'bottom-center',
        'bottom-right',
      ];
      final zCount = List<int>.filled(9, 0);
      final zR = List<double>.filled(9, 0);
      final zG = List<double>.filled(9, 0);
      final zB = List<double>.filled(9, 0);
      final zLuma = List<double>.filled(9, 0);
      final zSat = List<double>.filled(9, 0);
      final zEdge = List<double>.filled(9, 0);

      for (var y = 0; y < h; y++) {
        final zy = (y * 3 ~/ h).clamp(0, 2);
        for (var x = 0; x < w; x++) {
          final zx = (x * 3 ~/ w).clamp(0, 2);
          final zi = zy * 3 + zx;
          final p = small.getPixel(x, y);
          final r = p.r.toDouble() / 255.0;
          final g = p.g.toDouble() / 255.0;
          final b = p.b.toDouble() / 255.0;
          final l = 0.2126 * r + 0.7152 * g + 0.0722 * b;
          lumaGrid[y * w + x] = l;
          sumLuma += l;
          if (l < 0.20) shadows++;
          if (l > 0.85) highlights++;
          if (l > 0.96) clipped++;
          sumWarm += (r - b);
          sumTint += (g - (r + b) * 0.5);
          final maxC = math.max(r, math.max(g, b));
          final minC = math.min(r, math.min(g, b));
          final sat = maxC > 1e-4 ? (maxC - minC) / maxC : 0.0;
          sumSat += sat;

          zCount[zi]++;
          zR[zi] += p.r.toDouble();
          zG[zi] += p.g.toDouble();
          zB[zi] += p.b.toDouble();
          zLuma[zi] += l;
          zSat[zi] += sat;
        }
      }

      var wx = 0.0;
      var wy = 0.0;
      var wSum = 0.0;
      for (var y = 1; y < h - 1; y++) {
        final zy = (y * 3 ~/ h).clamp(0, 2);
        for (var x = 1; x < w - 1; x++) {
          final zx = (x * 3 ~/ w).clamp(0, 2);
          final zi = zy * 3 + zx;
          final gx = -lumaGrid[(y - 1) * w + (x - 1)] +
              lumaGrid[(y - 1) * w + (x + 1)] -
              2.0 * lumaGrid[y * w + (x - 1)] +
              2.0 * lumaGrid[y * w + (x + 1)] -
              lumaGrid[(y + 1) * w + (x - 1)] +
              lumaGrid[(y + 1) * w + (x + 1)];
          final gy = -lumaGrid[(y - 1) * w + (x - 1)] -
              2.0 * lumaGrid[(y - 1) * w + x] -
              lumaGrid[(y - 1) * w + (x + 1)] +
              lumaGrid[(y + 1) * w + (x - 1)] +
              2.0 * lumaGrid[(y + 1) * w + x] +
              lumaGrid[(y + 1) * w + (x + 1)];
          final mag = math.sqrt(gx * gx + gy * gy);
          zEdge[zi] += mag;
          if (mag > 0.25) {
            wx += x * mag;
            wy += y * mag;
            wSum += mag;
          }
        }
      }

      final cx = wSum > 0 ? (wx / wSum / w).clamp(0.18, 0.82) : 0.50;
      final cy = wSum > 0 ? (wy / wSum / h).clamp(0.18, 0.82) : 0.50;
      const boxW = 0.54;
      const boxH = 0.64;
      final bx = (cx - boxW * 0.5).clamp(0.05, 1.0 - boxW - 0.05);
      final by = (cy - boxH * 0.5).clamp(0.05, 1.0 - boxH - 0.05);

      final buf = StringBuffer()
        ..writeln(
          'Frame: ${decoded.width}x${decoded.height} ($orient), '
          'meanLuma=${(sumLuma / totalPx * 100).round()}%, '
          'shadows=${(shadows / totalPx * 100).round()}%, '
          'highlights=${(highlights / totalPx * 100).round()}%, '
          'clipped=${(clipped / totalPx * 100).round()}%, '
          'warmBias=${(sumWarm / totalPx).toStringAsFixed(2)}, '
          'greenTint=${(sumTint / totalPx).toStringAsFixed(2)}, '
          'avgSat=${(sumSat / totalPx * 100).round()}%',
        )
        ..writeln(
          'Sobel saliency centroid=(${cx.toStringAsFixed(2)}, ${cy.toStringAsFixed(2)}), '
          'suggestedCropBox=[${bx.toStringAsFixed(2)}, ${by.toStringAsFixed(2)}, ${boxW.toStringAsFixed(2)}, ${boxH.toStringAsFixed(2)}]',
        )
        ..writeln('3x3 Spatial Grid:');
      for (var i = 0; i < 9; i++) {
        final cnt = math.max(1, zCount[i]);
        buf.writeln(
          '  ${zoneNames[i]}: luma=${(zLuma[i] / cnt * 100).round()}% '
          'rgb=(${(zR[i] / cnt).round()},${(zG[i] / cnt).round()},${(zB[i] / cnt).round()}) '
          'sat=${(zSat[i] / cnt * 100).round()}% edge=${(zEdge[i] / cnt * 100).round()}',
        );
      }
      return buf.toString().trimRight();
    });
  }

  /// 从模型输出中稳健提取 JSON 对象：
  /// 1) 剥离完整或未闭合 `<think>` 思考过程；
  /// 2) 剥离完整或截断的代码围栏；
  /// 3) 遇到尾部截断（如 DeepSeek 触发 token 上限）时自动闭合已完成节点挽救可用方案。
  static Map<String, dynamic> extractJsonObject(String rawText) {
    var trimmed = rawText
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
    final openThinkIdx = trimmed.toLowerCase().indexOf('<think>');
    if (openThinkIdx >= 0) {
      trimmed = trimmed.substring(0, openThinkIdx).trim();
    }
    if (trimmed.isEmpty) {
      throw const FormatException(
        'Model output truncated inside <think> reasoning block',
      );
    }

    trimmed = trimmed
        .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'\s*```\s*$'), '')
        .trim();

    final firstBrace = trimmed.indexOf('{');
    if (firstBrace < 0) {
      throw const FormatException('AI response does not contain a JSON object');
    }

    final jsonCandidate = trimmed.substring(firstBrace);
    final lastBrace = jsonCandidate.lastIndexOf('}');
    if (lastBrace > 0) {
      try {
        final decoded = jsonDecode(jsonCandidate.substring(0, lastBrace + 1));
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        // 继续尝试从截断前最后一个完整闭合节点挽救
      }
    }

    return tryRepairTruncatedJson(jsonCandidate);
  }

  /// 挽救被服务端 `max_tokens` 截断的不完整 JSON：
  /// 扫描最近一次安全闭合嵌套 `{}` / `[]` 的切分点，补全剩余闭合括号后重新解析。
  static Map<String, dynamic> tryRepairTruncatedJson(String input) {
    final stack = <String>[];
    var inString = false;
    var escaped = false;
    final safeCuts = <({int endIndex, List<String> remaining})>[];

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }

      if (ch == '"') {
        inString = true;
      } else if (ch == '{' || ch == '[') {
        stack.add(ch);
      } else if (ch == '}' || ch == ']') {
        final expected = ch == '}' ? '{' : '[';
        if (stack.isNotEmpty && stack.last == expected) {
          stack.removeLast();
          if (i + 1 > 1) {
            safeCuts.add((
              endIndex: i + 1,
              remaining: List<String>.from(stack),
            ));
          }
        }
      }
    }

    for (final cut in safeCuts.reversed) {
      var prefix = input.substring(0, cut.endIndex).trimRight();
      while (prefix.endsWith(',')) {
        prefix = prefix.substring(0, prefix.length - 1).trimRight();
      }
      final closers = cut.remaining.reversed
          .map((open) => open == '{' ? '}' : ']')
          .join();
      try {
        final decoded = jsonDecode('$prefix$closers');
        if (decoded is Map && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        continue;
      }
    }

    throw const FormatException('Unexpected end of truncated JSON response');
  }

  /// 脱敏任意日志字符串，防止 API Key 泄露。
  static String sanitizeForLog(String text, {String? secretKey}) {
    var out = text;
    if (secretKey != null && secretKey.trim().length > 4) {
      out = out.replaceAll(secretKey.trim(), '***');
    }
    out = out.replaceAll(
        RegExp(r'sk-[A-Za-z0-9_\-]{10,}'), 'sk-***');
    out = out.replaceAll(
        RegExp(r'Bearer\s+[A-Za-z0-9._\-]{8,}', caseSensitive: false),
        'Bearer ***');
    return out;
  }

  static ({String url, Map<String, String> headers, String payload})
      _buildOpenAiRequest({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String systemPrompt,
    required String userPrompt,
    required String jpegBase64,
    required int maxTokens,
    required double temperature,
  }) {
    final url = resolveEndpointUrl(AiApiProtocol.openAiCompatible, baseUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final reasoning = isReasoningModel(modelId);
    final payloadMap = <String, dynamic>{
      'model': modelId,
      if (!reasoning) 'temperature': temperature,
      if (!reasoning) 'max_tokens': maxTokens < 4096 ? 4096 : maxTokens,
      'messages': [
        if (systemPrompt.trim().isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$jpegBase64',
                'detail': 'high',
              },
            },
          ],
        },
      ],
    };
    return (url: url, headers: headers, payload: jsonEncode(payloadMap));
  }

  static ({String url, Map<String, String> headers, String payload})
      _buildOpenAiTextRequest({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) {
    final url = resolveEndpointUrl(AiApiProtocol.openAiCompatible, baseUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${apiKey.trim()}',
    };
    final reasoning = isReasoningModel(modelId);
    final payloadMap = <String, dynamic>{
      'model': modelId,
      if (!reasoning) 'temperature': temperature,
      if (!reasoning) 'max_tokens': maxTokens < 4096 ? 4096 : maxTokens,
      'messages': [
        if (systemPrompt.trim().isNotEmpty)
          {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': userPrompt,
        },
      ],
    };
    return (url: url, headers: headers, payload: jsonEncode(payloadMap));
  }

  static ({String url, Map<String, String> headers, String payload})
      _buildAnthropicRequest({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String systemPrompt,
    required String userPrompt,
    required String jpegBase64,
    required int maxTokens,
    required double temperature,
  }) {
    final url = resolveEndpointUrl(AiApiProtocol.anthropicCompatible, baseUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
    };
    final body = jsonEncode({
      'model': modelId,
      'max_tokens': maxTokens < 4096 ? 4096 : maxTokens,
      'temperature': temperature,
      if (systemPrompt.trim().isNotEmpty) 'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': jpegBase64,
              },
            },
            {'type': 'text', 'text': userPrompt},
          ],
        },
      ],
    });
    return (url: url, headers: headers, payload: body);
  }

  static ({String url, Map<String, String> headers, String payload})
      _buildAnthropicTextRequest({
    required String baseUrl,
    required String apiKey,
    required String modelId,
    required String systemPrompt,
    required String userPrompt,
    required int maxTokens,
    required double temperature,
  }) {
    final url = resolveEndpointUrl(AiApiProtocol.anthropicCompatible, baseUrl);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      if (apiKey.trim().isNotEmpty) 'x-api-key': apiKey.trim(),
    };
    final body = jsonEncode({
      'model': modelId,
      'max_tokens': maxTokens < 4096 ? 4096 : maxTokens,
      'temperature': temperature,
      if (systemPrompt.trim().isNotEmpty) 'system': systemPrompt,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userPrompt},
          ],
        },
      ],
    });
    return (url: url, headers: headers, payload: body);
  }

  static String _extractAssistantText(AiApiProtocol protocol, String rawBody) {
    final decoded = jsonDecode(rawBody);
    if (decoded is! Map) {
      throw const FormatException('Invalid API response JSON');
    }
    if (protocol == AiApiProtocol.openAiCompatible) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final choice = choices.first as Map;
        final msg = choice['message'];
        if (msg is Map) {
          final content = msg['content'];
          var extracted = '';
          if (content is String) {
            extracted = content;
          } else if (content is List) {
            extracted = content
                .whereType<Map>()
                .map((e) => e['text']?.toString() ?? '')
                .join('\n')
                .trim();
          }
          if (extracted.trim().isNotEmpty) return extracted;
          final reasoning = msg['reasoning_content'];
          if (reasoning is String &&
              reasoning.contains('{') &&
              reasoning.contains('}')) {
            return reasoning;
          }
          if (choice['finish_reason'] == 'length') {
            throw const AiHttpException(
              statusCode: 200,
              code: 'OUTPUT_TRUNCATED',
              message: 'Model output hit token limit before completing JSON',
              category: AiErrorCategory.parseError,
            );
          }
        }
      }
      throw const FormatException('Missing choices[0].message.content');
    } else {
      final content = decoded['content'];
      if (content is List) {
        final text = content
            .whereType<Map>()
            .where((e) => e['type'] == 'text')
            .map((e) => e['text']?.toString() ?? '')
            .join('\n')
            .trim();
        if (text.isNotEmpty) return text;
      }
      throw const FormatException(
          'Missing content[].text in Anthropic response');
    }
  }

  static AiHttpException _classifyHttpError(
    int statusCode,
    String body,
    String apiKey, {
    String? endpoint,
  }) {
    var msg = 'HTTP $statusCode';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] != null) {
          msg = err['message'].toString();
        } else if (decoded['message'] != null) {
          msg = decoded['message'].toString();
        }
      }
    } catch (_) {
      final trimmed = body.trim();
      if (trimmed.isNotEmpty) {
        msg = trimmed.length > 240 ? trimmed.substring(0, 240) : trimmed;
      }
    }
    final safeMsg = sanitizeForLog(msg, secretKey: apiKey);
    final lower = safeMsg.toLowerCase();
    final isVisionRejection =
        (statusCode == 400 || statusCode == 422 || statusCode == 415) &&
            (lower.contains('untagged enum') ||
                lower.contains('deserialize') ||
                lower.contains('invalid type: sequence') ||
                lower.contains('unknown variant') ||
                lower.contains('image_url') ||
                lower.contains('expected a string') ||
                lower.contains('multimodal') ||
                lower.contains('vision') ||
                lower.contains('image input') ||
                lower.contains('does not support image') ||
                lower.contains('content must be a string'));

    final AiErrorCategory category;
    final String code;
    if (isVisionRejection) {
      category = AiErrorCategory.unsupportedVision;
      code = 'VISION_NOT_SUPPORTED';
    } else {
      switch (statusCode) {
        case 401 || 403:
          category = AiErrorCategory.auth;
          code = 'AUTH_FAILED';
        case 402:
          category = AiErrorCategory.rateLimit;
          code = 'INSUFFICIENT_QUOTA';
        case 404:
          category = AiErrorCategory.endpointNotFound;
          code = 'ENDPOINT_OR_MODEL_NOT_FOUND';
        case 429:
          category = AiErrorCategory.rateLimit;
          code = 'RATE_LIMITED';
        default:
          category = AiErrorCategory.serverError;
          code = 'HTTP_ERROR';
      }
    }
    return AiHttpException(
      statusCode: statusCode,
      code: code,
      message: safeMsg,
      category: category,
      endpoint: endpoint,
    );
  }
}
