import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/engine_l10n.dart';
import '../../protocol/camera_native_bridge.dart';

/// 支持的 AI 接口协议（全量覆盖主流与自定义中转端点）。
enum AiApiProtocol {
  openAiCompatible,
  anthropicCompatible;

  static AiApiProtocol fromName(String? raw) =>
      AiApiProtocol.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AiApiProtocol.openAiCompatible,
      );
}

/// 常见 AI 服务商快捷端点模板（仅快速填入 Base URL 与协议）。
class AiEndpointQuickPreset {
  final String id;
  final String name;
  final AiApiProtocol protocol;
  final String defaultBaseUrl;

  const AiEndpointQuickPreset({
    required this.id,
    required this.name,
    required this.protocol,
    required this.defaultBaseUrl,
  });

  String localizedName(String lang) => EngineL10n.tr(name, lang);

  static const List<AiEndpointQuickPreset> presets = [
    AiEndpointQuickPreset(
      id: 'deepseek',
      name: 'DeepSeek 官方',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://api.deepseek.com/v1',
    ),
    AiEndpointQuickPreset(
      id: 'dashscope',
      name: '阿里云百炼 (Qwen-VL)',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    ),
    AiEndpointQuickPreset(
      id: 'zhipu',
      name: '智谱清言 (GLM-4V)',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    ),
    AiEndpointQuickPreset(
      id: 'siliconflow',
      name: '硅基流动 (SiliconFlow)',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://api.siliconflow.cn/v1',
    ),
    AiEndpointQuickPreset(
      id: 'ark',
      name: '火山方舟 (豆包视觉)',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    ),
    AiEndpointQuickPreset(
      id: 'gemini_openai',
      name: 'Google Gemini (OpenAI兼容)',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    ),
    AiEndpointQuickPreset(
      id: 'openai',
      name: 'OpenAI 官方',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://api.openai.com/v1',
    ),
    AiEndpointQuickPreset(
      id: 'anthropic',
      name: 'Anthropic Claude',
      protocol: AiApiProtocol.anthropicCompatible,
      defaultBaseUrl: 'https://api.anthropic.com/v1',
    ),
    AiEndpointQuickPreset(
      id: 'openrouter',
      name: 'OpenRouter',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'https://openrouter.ai/api/v1',
    ),
    AiEndpointQuickPreset(
      id: 'ollama',
      name: 'Ollama 本地局域网',
      protocol: AiApiProtocol.openAiCompatible,
      defaultBaseUrl: 'http://192.168.1.100:11434/v1',
    ),
  ];
}

/// 用户勾选导入的单个识图模型。
class AiImportedModel {
  final String id;
  final String displayName;
  final bool visionHint;
  final bool? visionVerified;
  final int? lastLatencyMs;

  const AiImportedModel({
    required this.id,
    required this.displayName,
    this.visionHint = true,
    this.visionVerified,
    this.lastLatencyMs,
  });

  AiImportedModel copyWith({
    String? id,
    String? displayName,
    bool? visionHint,
    bool? visionVerified,
    int? lastLatencyMs,
  }) =>
      AiImportedModel(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        visionHint: visionHint ?? this.visionHint,
        visionVerified: visionVerified ?? this.visionVerified,
        lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'visionHint': visionHint,
        'visionVerified': visionVerified,
        'lastLatencyMs': lastLatencyMs,
      };

  factory AiImportedModel.fromJson(Map<String, dynamic> json) =>
      AiImportedModel(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ??
            (json['id'] as String? ?? ''),
        visionHint: json['visionHint'] as bool? ?? true,
        visionVerified: json['visionVerified'] as bool?,
        lastLatencyMs: (json['lastLatencyMs'] as num?)?.toInt(),
      );
}

/// 单个 AI 服务商配置档案。
///
/// 出于安全约束：本对象中**绝不包含 API Key**，也不会在 JSON 中落盘密钥；
/// 密钥全部按 `ai_key_<id>` 独立托管在 Android Keystore 加密存储。
class AiProviderProfile {
  final String id;
  final String name;
  final AiApiProtocol protocol;
  final String baseUrl;
  final List<AiImportedModel> importedModels;

  const AiProviderProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.importedModels = const [],
  });

  static String normalizeBaseUrl(String raw) {
    var v = raw.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  AiProviderProfile copyWith({
    String? id,
    String? name,
    AiApiProtocol? protocol,
    String? baseUrl,
    List<AiImportedModel>? importedModels,
  }) =>
      AiProviderProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        protocol: protocol ?? this.protocol,
        baseUrl: baseUrl ?? this.baseUrl,
        importedModels: importedModels ?? this.importedModels,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'baseUrl': baseUrl,
        'importedModels': importedModels.map((e) => e.toJson()).toList(),
      };

  factory AiProviderProfile.fromJson(Map<String, dynamic> json) =>
      AiProviderProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Custom AI',
        protocol: AiApiProtocol.fromName(json['protocol'] as String?),
        baseUrl: json['baseUrl'] as String? ?? '',
        importedModels: (json['importedModels'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) =>
                AiImportedModel.fromJson(Map<String, dynamic>.from(m)))
            .where((e) => e.id.isNotEmpty)
            .toList(),
      );
}

/// 密钥安全读写接口，方便单元测试注入内存替身。
abstract class AiSecretVault {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

class NativeAiSecretVault implements AiSecretVault {
  const NativeAiSecretVault();

  @override
  Future<void> write(String key, String value) async {
    await CameraNativeBridge.secureWriteSecret(key, value);
  }

  @override
  Future<String?> read(String key) => CameraNativeBridge.secureReadSecret(key);

  @override
  Future<void> delete(String key) => CameraNativeBridge.secureDeleteSecret(key);
}

/// AI 引擎设置与多档案中心。
class AiSettingsStore extends ChangeNotifier {
  AiSettingsStore._();
  static final AiSettingsStore instance = AiSettingsStore._();

  @visibleForTesting
  static AiSettingsStore createForTesting({AiSecretVault? vault}) {
    final s = AiSettingsStore._();
    if (vault != null) s._vault = vault;
    return s;
  }

  AiSecretVault _vault = const NativeAiSecretVault();
  final Map<String, String> _keyCache = {};

  bool _initialized = false;
  Directory? _overrideDir;

  List<AiProviderProfile> _profiles = const [];
  String? _activeCoachProfileId;
  String? _activeCoachModelId;
  String? _activeGradeProfileId;
  String? _activeGradeModelId;
  bool _allowCellularBypassInAp = true;
  bool _includeExifTelemetry = true;

  List<AiProviderProfile> get profiles => List.unmodifiable(_profiles);
  String? get activeCoachProfileId => _activeCoachProfileId;
  String? get activeCoachModelId => _activeCoachModelId;
  String? get activeGradeProfileId => _activeGradeProfileId;
  String? get activeGradeModelId => _activeGradeModelId;
  bool get allowCellularBypassInAp => _allowCellularBypassInAp;
  bool get includeExifTelemetry => _includeExifTelemetry;

  static String _secretKeyFor(String profileId) => 'ai_api_key_$profileId';

  AiProviderProfile? profileById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final p in _profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 判断 Base URL 是否指向本地/局域网推理服务（如 Ollama，允许不填 API Key）。
  static bool isLocalBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    if (host.startsWith('10.') || host.startsWith('192.168.')) return true;
    final m = RegExp(r'^172\.(\d+)\.').firstMatch(host);
    if (m != null) {
      final second = int.tryParse(m.group(1)!) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }

  /// 判断解析出的目标服务商+模型是否缺失可用 API Key。
  bool isTargetMissingApiKey(
    ({AiProviderProfile profile, String modelId, String apiKey})? target,
  ) {
    if (target == null) return true;
    if (target.apiKey.trim().isNotEmpty) return false;
    return !isLocalBaseUrl(target.profile.baseUrl);
  }

  /// 是否已配置至少一个可用的 AI API Key（或本地带模型的局域网端点）。
  bool get hasConfiguredApiKey {
    for (final p in _profiles) {
      final key = (_keyCache[p.id] ?? '').trim();
      if (key.isNotEmpty) return true;
      if (isLocalBaseUrl(p.baseUrl) && p.importedModels.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// 当前已配置的取景助手服务商+模型。
  ({AiProviderProfile profile, String modelId, String apiKey})?
      resolveCoachTarget() => _resolveTarget(
            _activeCoachProfileId,
            _activeCoachModelId,
          );

  /// 当前已配置的 AI 调色服务商+模型。
  ({AiProviderProfile profile, String modelId, String apiKey})?
      resolveGradeTarget() => _resolveTarget(
            _activeGradeProfileId,
            _activeGradeModelId,
          );

  ({AiProviderProfile profile, String modelId, String apiKey})? _resolveTarget(
    String? profileId,
    String? modelId,
  ) {
    final profile = profileById(profileId);
    if (profile == null || modelId == null || modelId.isEmpty) return null;
    final key = _keyCache[profile.id] ?? '';
    return (profile: profile, modelId: modelId, apiKey: key);
  }

  String cachedApiKey(String profileId) => _keyCache[profileId] ?? '';

  /// 将完整 API Key 脱敏为 `sk-••••a9f2` 用于界面回显或日志输出。
  static String maskApiKey(String raw) {
    final k = raw.trim();
    if (k.isEmpty) return '';
    if (k.length <= 8) return '••••';
    return '${k.substring(0, 3)}••••${k.substring(k.length - 4)}';
  }

  Future<File> _configFile() async {
    final dir = _overrideDir ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/zync_ai_settings.json');
  }

  Future<void> ensureInitialized({Directory? overrideDirectory}) async {
    if (_initialized && overrideDirectory == null) return;
    if (overrideDirectory != null) _overrideDir = overrideDirectory;
    try {
      final file = await _configFile();
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          _profiles = (m['profiles'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map((e) =>
                  AiProviderProfile.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.id.isNotEmpty)
              .toList();
          _activeCoachProfileId = m['activeCoachProfileId'] as String?;
          _activeCoachModelId = m['activeCoachModelId'] as String?;
          _activeGradeProfileId = m['activeGradeProfileId'] as String?;
          _activeGradeModelId = m['activeGradeModelId'] as String?;
          _allowCellularBypassInAp =
              m['allowCellularBypassInAp'] as bool? ?? true;
          _includeExifTelemetry = m['includeExifTelemetry'] as bool? ?? true;
        }
      }
      for (final p in _profiles) {
        final key = await _vault.read(_secretKeyFor(p.id));
        if (key != null && key.isNotEmpty) {
          _keyCache[p.id] = key;
        }
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveConfig() async {
    try {
      final file = await _configFile();
      await file.writeAsString(
        jsonEncode({
          'profiles': _profiles.map((p) => p.toJson()).toList(),
          'activeCoachProfileId': _activeCoachProfileId,
          'activeCoachModelId': _activeCoachModelId,
          'activeGradeProfileId': _activeGradeProfileId,
          'activeGradeModelId': _activeGradeModelId,
          'allowCellularBypassInAp': _allowCellularBypassInAp,
          'includeExifTelemetry': _includeExifTelemetry,
        }),
        flush: true,
      );
    } catch (_) {}
  }

  Future<void> upsertProfile(
    AiProviderProfile profile, {
    String? apiKey,
  }) async {
    final normalized = profile.copyWith(
      baseUrl: AiProviderProfile.normalizeBaseUrl(profile.baseUrl),
    );
    final list = [..._profiles];
    final idx = list.indexWhere((e) => e.id == normalized.id);
    if (idx >= 0) {
      list[idx] = normalized;
    } else {
      list.add(normalized);
    }
    _profiles = list;

    if (apiKey != null) {
      final cleanKey = apiKey.trim();
      _keyCache[normalized.id] = cleanKey;
      if (cleanKey.isEmpty) {
        await _vault.delete(_secretKeyFor(normalized.id));
      } else {
        await _vault.write(_secretKeyFor(normalized.id), cleanKey);
      }
    }

    // 若尚未指定启用模型且本档案导入了模型，自动设为默认以开箱即用
    if (_activeCoachModelId == null && normalized.importedModels.isNotEmpty) {
      _activeCoachProfileId = normalized.id;
      _activeCoachModelId = normalized.importedModels.first.id;
    }
    if (_activeGradeModelId == null && normalized.importedModels.isNotEmpty) {
      _activeGradeProfileId = normalized.id;
      _activeGradeModelId = normalized.importedModels.first.id;
    }

    await _saveConfig();
    notifyListeners();
  }

  Future<void> deleteProfile(String profileId) async {
    _profiles = _profiles.where((e) => e.id != profileId).toList();
    _keyCache.remove(profileId);
    await _vault.delete(_secretKeyFor(profileId));
    if (_activeCoachProfileId == profileId) {
      _activeCoachProfileId = null;
      _activeCoachModelId = null;
    }
    if (_activeGradeProfileId == profileId) {
      _activeGradeProfileId = null;
      _activeGradeModelId = null;
    }
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setActiveCoach(String? profileId, String? modelId) async {
    _activeCoachProfileId = profileId;
    _activeCoachModelId = modelId;
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setActiveGrade(String? profileId, String? modelId) async {
    _activeGradeProfileId = profileId;
    _activeGradeModelId = modelId;
    await _saveConfig();
    notifyListeners();
  }

  Future<void> setNetworkPreferences({
    bool? allowCellularBypassInAp,
    bool? includeExifTelemetry,
  }) async {
    if (allowCellularBypassInAp != null) {
      _allowCellularBypassInAp = allowCellularBypassInAp;
    }
    if (includeExifTelemetry != null) {
      _includeExifTelemetry = includeExifTelemetry;
    }
    await _saveConfig();
    notifyListeners();
  }
}
