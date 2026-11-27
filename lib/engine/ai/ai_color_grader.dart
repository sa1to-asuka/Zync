import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/utils/exif_helper.dart';
import '../filter/photo_filter.dart';
import '../spektrafilm/spektrafilm_models.dart';
import 'ai_provider_config.dart';
import 'ai_recipe_catalog.dart';
import 'ai_vision_client.dart';

/// 从 48×48 采样像素中提取的统计特征，帮助 AI 或离线引擎判断影调分布。
class ImageColorStats {
  final double avgLuma; // 0..1
  final double shadowFraction; // luma < 0.2 占比
  final double highlightFraction; // luma > 0.85 占比
  final double dynamicSpread; // P95 - P05 亮度跨度 0..1
  final double warmBias; // R - B 平均差 (-1..1)
  final double greenTint; // G - (R+B)/2 平均差 (-1..1)
  final double avgSaturation; // HSV 饱和度均值 0..1

  const ImageColorStats({
    required this.avgLuma,
    required this.shadowFraction,
    required this.highlightFraction,
    required this.dynamicSpread,
    required this.warmBias,
    required this.greenTint,
    required this.avgSaturation,
  });

  factory ImageColorStats.fromRgbSamples(
    List<int> r,
    List<int> g,
    List<int> b,
  ) {
    final n = math.min(r.length, math.min(g.length, b.length));
    if (n <= 0) {
      return const ImageColorStats(
        avgLuma: 0.5,
        shadowFraction: 0.15,
        highlightFraction: 0.1,
        dynamicSpread: 0.6,
        warmBias: 0,
        greenTint: 0,
        avgSaturation: 0.3,
      );
    }

    final lumas = List<double>.filled(n, 0);
    var sumLuma = 0.0;
    var shadows = 0;
    var highlights = 0;
    var sumWarm = 0.0;
    var sumTint = 0.0;
    var sumSat = 0.0;

    for (var i = 0; i < n; i++) {
      final rf = (r[i].clamp(0, 255)) / 255.0;
      final gf = (g[i].clamp(0, 255)) / 255.0;
      final bf = (b[i].clamp(0, 255)) / 255.0;
      final l = 0.2126 * rf + 0.7152 * gf + 0.0722 * bf;
      lumas[i] = l;
      sumLuma += l;
      if (l < 0.20) shadows++;
      if (l > 0.85) highlights++;
      sumWarm += (rf - bf);
      sumTint += (gf - (rf + bf) * 0.5);
      final maxC = math.max(rf, math.max(gf, bf));
      final minC = math.min(rf, math.min(gf, bf));
      if (maxC > 1e-4) {
        sumSat += (maxC - minC) / maxC;
      }
    }
    lumas.sort();
    final p05 = lumas[(n * 0.05).floor().clamp(0, n - 1)];
    final p95 = lumas[(n * 0.95).floor().clamp(0, n - 1)];

    return ImageColorStats(
      avgLuma: sumLuma / n,
      shadowFraction: shadows / n,
      highlightFraction: highlights / n,
      dynamicSpread: (p95 - p05).clamp(0.0, 1.0),
      warmBias: (sumWarm / n).clamp(-1.0, 1.0),
      greenTint: (sumTint / n).clamp(-1.0, 1.0),
      avgSaturation: (sumSat / n).clamp(0.0, 1.0),
    );
  }

  String toPromptLine() =>
      'avgLuma=${avgLuma.toStringAsFixed(2)}, '
      'shadows=${(shadowFraction * 100).round()}%, '
      'highlights=${(highlightFraction * 100).round()}%, '
      'spread=${dynamicSpread.toStringAsFixed(2)}, '
      'warmBias=${warmBias.toStringAsFixed(2)}, '
      'saturation=${(avgSaturation * 100).round()}%';
}

/// 单个 AI 调色方案变体：绑定 Zync 真实配方（滤镜/物理胶片/预设）并叠加针对本图的滑块微调。
class AiGradeVariant {
  final String id; // 'natural' | 'cinematic' | 'film' | custom
  final String name;
  final String rationale;
  final AiGradeRecipeKind kind;
  final String? recipeId;
  final String recipeDisplayName;
  final String recipeCategory;
  final double recipeIntensity;
  final PhotoEditAdjustments adjustments;

  const AiGradeVariant({
    required this.id,
    required this.name,
    required this.rationale,
    this.kind = AiGradeRecipeKind.customAdjustments,
    this.recipeId,
    this.recipeDisplayName = '',
    this.recipeCategory = '',
    this.recipeIntensity = 0.85,
    required this.adjustments,
  });

  AiGradeVariant copyWith({
    String? id,
    String? name,
    String? rationale,
    AiGradeRecipeKind? kind,
    String? recipeId,
    String? recipeDisplayName,
    String? recipeCategory,
    double? recipeIntensity,
    PhotoEditAdjustments? adjustments,
  }) =>
      AiGradeVariant(
        id: id ?? this.id,
        name: name ?? this.name,
        rationale: rationale ?? this.rationale,
        kind: kind ?? this.kind,
        recipeId: recipeId ?? this.recipeId,
        recipeDisplayName: recipeDisplayName ?? this.recipeDisplayName,
        recipeCategory: recipeCategory ?? this.recipeCategory,
        recipeIntensity: recipeIntensity ?? this.recipeIntensity,
        adjustments: adjustments ?? this.adjustments,
      );

  factory AiGradeVariant.fromJson(
    Map<String, dynamic> json,
    int index, {
    AiRecipeCatalog? catalog,
  }) {
    final adjJson = (json['adjustments'] is Map<String, dynamic>)
        ? json['adjustments'] as Map<String, dynamic>
        : (json['adjustments'] is Map
            ? Map<String, dynamic>.from(json['adjustments'] as Map)
            : json);
    final defaultId = switch (index) {
      0 => 'natural',
      1 => 'cinematic',
      _ => 'film',
    };

    final rawRecipeId = (json['recipeId'] as String?)?.trim();
    final resolved =
        (rawRecipeId != null && rawRecipeId.isNotEmpty)
            ? catalog?.resolve(rawRecipeId)
            : null;
    final rawKind = AiGradeRecipeKind.fromWire(json['recipeKind'] as String?);
    final rawIntensity =
        ((json['recipeIntensity'] as num?)?.toDouble() ?? 0.85)
            .clamp(0.35, 1.0)
            .toDouble();

    return AiGradeVariant(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : defaultId,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : (resolved?.displayName.isNotEmpty == true
              ? resolved!.displayName
              : defaultId),
      rationale: (json['rationale'] as String?)?.trim() ?? '',
      kind: resolved?.kind ??
          (rawRecipeId != null && rawRecipeId.isNotEmpty
              ? rawKind
              : AiGradeRecipeKind.customAdjustments),
      recipeId: resolved?.id ??
          (rawRecipeId != null && rawRecipeId.isNotEmpty ? rawRecipeId : null),
      recipeDisplayName: resolved?.displayName ??
          (json['recipeName'] as String?)?.trim() ??
          '',
      recipeCategory: resolved?.category ?? '',
      recipeIntensity: rawIntensity,
      adjustments: AiColorGrader.clampSafeAdjustments(
        _adjustmentsFromJson(adjJson),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rationale': rationale,
        'recipeKind': kind.name,
        if (recipeId != null) 'recipeId': recipeId,
        if (recipeDisplayName.isNotEmpty) 'recipeName': recipeDisplayName,
        'recipeIntensity': recipeIntensity,
        'adjustments': _adjustmentsToJson(adjustments),
      };

  static PhotoEditAdjustments _adjustmentsFromJson(Map<String, dynamic> j) {
    double d(String k, [double fallback = 0.0]) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    return PhotoEditAdjustments(
      temperature: d('temperature'),
      tint: d('tint'),
      exposure: d('exposure'),
      contrast: d('contrast'),
      highlights: d('highlights'),
      shadows: d('shadows'),
      whites: d('whites'),
      blacks: d('blacks'),
      texture: d('texture'),
      clarity: d('clarity'),
      dehaze: d('dehaze'),
      vibrance: d('vibrance'),
      saturation: d('saturation'),
      highlightHue: d('highlightHue', 40.0),
      highlightSat: d('highlightSat'),
      shadowHue: d('shadowHue', 220.0),
      shadowSat: d('shadowSat'),
      vignette: d('vignette'),
      grain: d('grain'),
    );
  }

  static Map<String, dynamic> _adjustmentsToJson(PhotoEditAdjustments a) => {
        'temperature': a.temperature,
        'tint': a.tint,
        'exposure': a.exposure,
        'contrast': a.contrast,
        'highlights': a.highlights,
        'shadows': a.shadows,
        'whites': a.whites,
        'blacks': a.blacks,
        'texture': a.texture,
        'clarity': a.clarity,
        'dehaze': a.dehaze,
        'vibrance': a.vibrance,
        'saturation': a.saturation,
        'highlightHue': a.highlightHue,
        'highlightSat': a.highlightSat,
        'shadowHue': a.shadowHue,
        'shadowSat': a.shadowSat,
        'vignette': a.vignette,
        'grain': a.grain,
      };
}

/// 一套完整的 AI 识图调色响应，含画面诊断与 3 套匹配真实配方库的推荐方案。
class AiColorGradeBundle {
  final String diagnosis;
  final List<AiGradeVariant> variants;
  final bool isOfflineFallback;

  const AiColorGradeBundle({
    required this.diagnosis,
    required this.variants,
    this.isOfflineFallback = false,
  });

  factory AiColorGradeBundle.fromJson(
    Map<String, dynamic> json, {
    AiRecipeCatalog? catalog,
    String styleHint = '',
    ImageColorStats? stats,
  }) {
    final rawList = json['variants'] as List<dynamic>? ?? const [];
    final variants = <AiGradeVariant>[];
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map) {
        var parsed = AiGradeVariant.fromJson(
          Map<String, dynamic>.from(item),
          i,
          catalog: catalog,
        );
        // 若传入了 recipeCatalog 且 AI 输出了一个不存在的 recipeId，则用同风格真实配方纠偏防幻觉。
        if (catalog != null &&
            parsed.recipeId != null &&
            catalog.resolve(parsed.recipeId) == null) {
          final fallback = catalog.matchByKeywords(
            styleHint: '$styleHint ${parsed.name} ${parsed.rationale}',
            avgLuma: stats?.avgLuma ?? 0.5,
            warmBias: stats?.warmBias ?? 0.0,
            limit: 1,
            excludeIds: {
              for (final existing in variants)
                if (existing.recipeId != null) existing.recipeId!,
            },
          );
          if (fallback.isNotEmpty) {
            final pick = fallback.first;
            parsed = parsed.copyWith(
              kind: pick.kind,
              recipeId: pick.id,
              recipeDisplayName: pick.displayName,
              recipeCategory: pick.category,
            );
          }
        }
        variants.add(parsed);
      }
    }
    return AiColorGradeBundle(
      diagnosis: (json['diagnosis'] as String?)?.trim() ?? '',
      variants: variants,
    );
  }
}

/// Zync AI 智能识图调色引擎：把照片 + 用户风格要求 + Zync 全量内置配方库发给视觉大模型，
/// 严选最匹配的三款配方并针对本图输出曝光/白平衡微调参数。
class AiColorGrader {
  AiColorGrader({AiVisionClient? client}) : _client = client ?? AiVisionClient();

  final AiVisionClient _client;

  /// 对参数施加安全护栏，防止 AI 幻觉输出导致画面崩坏或死白/死黑。
  static PhotoEditAdjustments clampSafeAdjustments(PhotoEditAdjustments a) {
    double c(double v, double lo, double hi) => v.clamp(lo, hi).toDouble();
    double hue(double h) {
      var v = h % 360.0;
      if (v < 0) v += 360.0;
      return v;
    }

    return PhotoEditAdjustments(
      temperature: c(a.temperature, -55, 55),
      tint: c(a.tint, -40, 40),
      exposure: c(a.exposure, -55, 55),
      contrast: c(a.contrast, -45, 55),
      highlights: c(a.highlights, -75, 55),
      shadows: c(a.shadows, -45, 75),
      whites: c(a.whites, -55, 55),
      blacks: c(a.blacks, -55, 55),
      texture: c(a.texture, -40, 50),
      clarity: c(a.clarity, -40, 50),
      dehaze: c(a.dehaze, -35, 50),
      vibrance: c(a.vibrance, -45, 60),
      saturation: c(a.saturation, -55, 45),
      highlightHue: hue(a.highlightHue),
      highlightSat: c(a.highlightSat, 0, 55),
      shadowHue: hue(a.shadowHue),
      shadowSat: c(a.shadowSat, 0, 55),
      vignette: c(a.vignette, -40, 55),
      grain: c(a.grain, 0, 45),
    );
  }

  /// 把内置预设基础参数与 AI 微调滑块合并并施加安全钳制。
  static PhotoEditAdjustments combineAdjustments(
    PhotoEditAdjustments base,
    PhotoEditAdjustments tweak,
  ) {
    return clampSafeAdjustments(
      PhotoEditAdjustments(
        temperature: base.temperature + tweak.temperature,
        tint: base.tint + tweak.tint,
        exposure: base.exposure + tweak.exposure,
        contrast: base.contrast + tweak.contrast,
        highlights: base.highlights + tweak.highlights,
        shadows: base.shadows + tweak.shadows,
        whites: base.whites + tweak.whites,
        blacks: base.blacks + tweak.blacks,
        texture: base.texture + tweak.texture,
        clarity: base.clarity + tweak.clarity,
        dehaze: base.dehaze + tweak.dehaze,
        vibrance: base.vibrance + tweak.vibrance,
        saturation: base.saturation + tweak.saturation,
        highlightHue: tweak.highlightSat > base.highlightSat
            ? tweak.highlightHue
            : base.highlightHue,
        highlightSat: math.max(base.highlightSat, tweak.highlightSat),
        shadowHue:
            tweak.shadowSat > base.shadowSat ? tweak.shadowHue : base.shadowHue,
        shadowSat: math.max(base.shadowSat, tweak.shadowSat),
        vignette: base.vignette + tweak.vignette,
        grain: math.max(base.grain, tweak.grain),
      ),
    );
  }

  /// 按 0.0–1.5 的强度系数缩放调节量，保留高光/阴影色相角。
  static PhotoEditAdjustments scaleAdjustments(
    PhotoEditAdjustments base,
    double intensity,
  ) {
    final k = intensity.clamp(0.0, 1.5);
    return clampSafeAdjustments(
      PhotoEditAdjustments(
        temperature: base.temperature * k,
        tint: base.tint * k,
        exposure: base.exposure * k,
        contrast: base.contrast * k,
        highlights: base.highlights * k,
        shadows: base.shadows * k,
        whites: base.whites * k,
        blacks: base.blacks * k,
        texture: base.texture * k,
        clarity: base.clarity * k,
        dehaze: base.dehaze * k,
        vibrance: base.vibrance * k,
        saturation: base.saturation * k,
        highlightHue: base.highlightHue,
        highlightSat: base.highlightSat * k,
        shadowHue: base.shadowHue,
        shadowSat: base.shadowSat * k,
        vignette: base.vignette * k,
        grain: base.grain * k,
      ),
    );
  }

  static String _languageInstruction(String localeCode) => switch (localeCode) {
        'ja' => 'Japanese (日本語)',
        'en' => 'English',
        _ => 'Simplified Chinese (简体中文)',
      };

  /// 调用视觉大模型分析照片与直方图统计，从内置配方库严选 Top 3 真实配方并输出本图微调参数。
  Future<AiColorGradeBundle> gradePhoto({
    required AiProviderProfile profile,
    required String modelId,
    required String apiKey,
    required Uint8List imageBytes,
    ImageColorStats? stats,
    PhotoMetadata? metadata,
    String styleHint = '',
    bool includeExifTelemetry = true,
    String localeCode = 'zh',
    List<SpektraStockInfo>? spektraStocks,
    bool preferCellular = false,
    bool skipResize = false,
  }) async {
    final isZh = localeCode.toLowerCase().startsWith('zh');
    final catalog = AiRecipeCatalog.buildAll(
      spektraStocks: spektraStocks,
      localeCode: localeCode,
    );
    final promptRecipes = catalog.selectForPrompt(styleHint: styleHint);
    final telemetry =
        (includeExifTelemetry && metadata != null && metadata.hasValidExif)
            ? 'EXIF: ${metadata.cameraModel} ${metadata.lensModel} ${metadata.exposureSummary}'
            : 'EXIF: omitted';
    final statsLine = stats?.toPromptLine() ?? 'stats: unavailable';
    final langName = _languageInstruction(localeCode);

    final catalogBuf = StringBuffer();
    for (final item in promptRecipes) {
      catalogBuf.writeln(item.toPromptLine());
    }

    final systemPrompt = isZh
        ? '''你是 Zync（尼康 Z 暗房）的首席摄影调色师与胶片色彩总监。
请仔细分析照片的光线方向、主体色彩、天空/植被/肤色、高光暗部层次以及影调统计数据，并结合用户的调色意图，从下方提供的 Zync 内置配方库（`recipeId`）中严选最契合本张照片的 **3 款不同配方**，同时为每款配方叠加克制、自然的逐项微调参数 `adjustments`。

严格输出规则：
1. 只能输出一个紧凑、合法的纯 JSON 对象（严禁输出 Markdown 解释文字或任何表情符号）。
2. 所有可读文本字段（`diagnosis`、`variants[].name`、`variants[].rationale`）必须 **100% 使用自然专业的简体中文输出**，`variants[].name` 必须是 4~10 个汉字的中文方案名，严禁输出英文句子或英文方案名！
3. 每个 `recipeId` 必须原样精确复制自下方配方目录，且 3 个 `recipeId` 互不重复。
4. 在 `adjustments` 中**只输出需要改动的非 0 参数键**（数值为 0、无需调整的参数请直接省略不写，以保持 JSON 精简紧凑）。
5. 可选微调键范围：temperature(-55..55), tint(-40..40), exposure(-55..55), contrast(-45..55), highlights(-75..55), shadows(-45..75), whites(-55..55), blacks(-55..55), texture(-40..50), clarity(-40..50), dehaze(-35..50), vibrance(-45..60), saturation(-55..45), highlightHue(0..360), highlightSat(0..55), shadowHue(0..360), shadowSat(0..55), vignette(-40..55), grain(0..45)。

JSON 格式示例：
{"diagnosis":"中文画面光线与色彩诊断（1~2句）","variants":[{"id":"best_match","name":"中文方案名","recipeId":"filter:shinkaiAnime","recipeIntensity":0.85,"rationale":"中文一句话说明为何此配方与微调适合这张照片","adjustments":{"exposure":8,"highlights":-18,"shadows":14,"vibrance":10}},{"id":"atmospheric","name":"第二款中文名","recipeId":"第二款目录ID","recipeIntensity":0.8,"rationale":"中文理由","adjustments":{"temperature":6,"contrast":8}},{"id":"film_alt","name":"第三款中文名","recipeId":"第三款目录ID","recipeIntensity":0.85,"rationale":"中文理由","adjustments":{"shadows":12,"grain":10}}]}'''
        : '''You are a master photographic colorist and film look designer for Zync (Nikon Z darkroom).
Carefully inspect the uploaded photo together with its luminance/color statistics and the photographer's desired style.
Pick the TOP 3 distinct recipes from the provided Zync recipe catalog (`recipeId`) that best achieve the user's goal on THIS specific photo, AND output tasteful per-photo fine-tuning `adjustments` layered on top of each chosen recipe.

STRICT OUTPUT RULES:
1. Return ONLY a single compact valid JSON object (no commentary outside JSON, no emojis).
2. All human-readable text (`diagnosis`, `variants[].name`, `variants[].rationale`) MUST be written in $langName.
3. Each `recipeId` MUST be copied EXACTLY from the catalog list below, and the 3 `recipeId`s MUST be distinct.
4. Inside `adjustments`, ONLY include non-zero keys that you actually change (omit any `0` unchanged parameters so JSON stays compact).
5. Allowed adjustment keys & ranges: temperature(-55..55), tint(-40..40), exposure(-55..55), contrast(-45..55), highlights(-75..55), shadows(-45..75), whites(-55..55), blacks(-55..55), texture(-40..50), clarity(-40..50), dehaze(-35..50), vibrance(-45..60), saturation(-55..45), highlightHue(0..360), highlightSat(0..55), shadowHue(0..360), shadowSat(0..55), vignette(-40..55), grain(0..45).

JSON Schema:
{"diagnosis":"1-2 sentences in $langName","variants":[{"id":"best_match","name":"look name in $langName","recipeId":"EXACT id from catalog","recipeIntensity":0.85,"rationale":"1 concise sentence in $langName","adjustments":{"exposure":8,"highlights":-15}},{"id":"atmospheric","name":"2nd name","recipeId":"2nd id","recipeIntensity":0.8,"rationale":"...","adjustments":{}},{"id":"film_alt","name":"3rd name","recipeId":"3rd id","recipeIntensity":0.85,"rationale":"...","adjustments":{}}]}''';

    final userPrompt = isZh
        ? '''画面影调统计：$statsLine
$telemetry
用户期望风格：${styleHint.trim().isEmpty ? '根据画面光线与题材自动匹配最佳影调与色彩氛围' : styleHint.trim()}

Zync 内置调色配方目录（请从中任选 3 个最契合且互不重复的 recipeId，所有说明与名称必须用简体中文）：
$catalogBuf'''
        : '''Photo Stats: $statsLine
$telemetry
Photographer Desired Style: ${styleHint.trim().isEmpty ? 'Auto match the scene best aesthetic and balance' : styleHint.trim()}

Zync Built-in Recipe Catalog (choose 3 distinct recipeId values):
$catalogBuf''';

    final res = await _client.analyzeImage(
      profile: profile,
      modelId: modelId,
      apiKey: apiKey,
      imageBytes: imageBytes,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxEdge: 640,
      jpegQuality: 74,
      maxTokens: 4096,
      temperature: 0.25,
      skipResize: skipResize,
      preferCellular: preferCellular,
    );

    final jsonMap = AiVisionClient.extractJsonObject(res.text);
    final parsed = AiColorGradeBundle.fromJson(
      jsonMap,
      catalog: catalog,
      styleHint: styleHint,
      stats: stats,
    );
    if (parsed.variants.isEmpty) {
      throw const FormatException('AI color grader returned empty variants');
    }
    return parsed;
  }

  /// 基于用户自然语言微调要求（如“天空再蓝透一点、高光别过曝”），在当前配方基础上迭代参数。
  Future<AiGradeVariant> refineVariant({
    required AiProviderProfile profile,
    required String modelId,
    required String apiKey,
    required Uint8List imageBytes,
    required AiGradeVariant currentVariant,
    required String instruction,
    ImageColorStats? stats,
    String localeCode = 'zh',
    List<SpektraStockInfo>? spektraStocks,
    bool preferCellular = false,
    bool skipResize = false,
  }) async {
    final isZh = localeCode.toLowerCase().startsWith('zh');
    final catalog = AiRecipeCatalog.buildAll(
      spektraStocks: spektraStocks,
      localeCode: localeCode,
    );
    final langName = _languageInstruction(localeCode);
    final userPrompt = isZh
        ? '''请根据用户的微调指令，在当前调色方案基础上精确调整参数。
当前方案：
{"id":"${currentVariant.id}","name":"${currentVariant.name}","recipeId":${currentVariant.recipeId == null ? 'null' : '"${currentVariant.recipeId}"'},"recipeIntensity":${currentVariant.recipeIntensity.toStringAsFixed(2)},"adjustments":${_encodeAdjustmentsLiteral(currentVariant.adjustments)}}
画面统计：${stats?.toPromptLine() ?? 'n/a'}
用户微调要求：${instruction.trim()}

请只输出紧凑合法的 JSON，`name` 与 `rationale` 必须使用简体中文，`adjustments` 中仅保留非 0 参数键：
{"id":"${currentVariant.id}","name":"更新后的中文方案名","recipeId":${currentVariant.recipeId == null ? 'null' : '"${currentVariant.recipeId}"'},"recipeIntensity":0.85,"rationale":"一句话中文说明本次微调变化","adjustments":{"exposure":0}}'''
        : '''Refine the current Zync color grading look according to the user's instruction.
Current look:
{"id":"${currentVariant.id}","name":"${currentVariant.name}","recipeId":${currentVariant.recipeId == null ? 'null' : '"${currentVariant.recipeId}"'},"recipeIntensity":${currentVariant.recipeIntensity.toStringAsFixed(2)},"adjustments":${_encodeAdjustmentsLiteral(currentVariant.adjustments)}}
Stats: ${stats?.toPromptLine() ?? 'n/a'}
User refinement instruction: ${instruction.trim()}

Return compact strictly valid JSON in $langName (omit 0-valued keys in `adjustments`):
{"id":"${currentVariant.id}","name":"updated concise name in $langName","recipeId":${currentVariant.recipeId == null ? 'null' : '"${currentVariant.recipeId}"'},"recipeIntensity":0.85,"rationale":"1 sentence in $langName describing what changed","adjustments":{"exposure":0}}''';

    final res = await _client.analyzeImage(
      profile: profile,
      modelId: modelId,
      apiKey: apiKey,
      imageBytes: imageBytes,
      systemPrompt: isZh
          ? '你是专业摄影调色师。严格按用户指令微调参数，仅输出紧凑 JSON 对象，所有名称与说明必须为简体中文。'
          : 'You are a master photo colorist. Modify the provided adjustments faithfully and output compact valid JSON only in $langName.',
      userPrompt: userPrompt,
      maxEdge: 512,
      jpegQuality: 72,
      maxTokens: 4096,
      skipResize: skipResize,
      preferCellular: preferCellular,
    );
    final jsonMap = AiVisionClient.extractJsonObject(res.text);
    final parsed = AiGradeVariant.fromJson(jsonMap, 0, catalog: catalog);
    // 若模型未显式回传 recipeId，则继承原方案的真实配方绑定，防止丢失已激活滤镜/胶片。
    if (parsed.recipeId == null && currentVariant.recipeId != null) {
      return parsed.copyWith(
        kind: currentVariant.kind,
        recipeId: currentVariant.recipeId,
        recipeDisplayName: currentVariant.recipeDisplayName,
        recipeCategory: currentVariant.recipeCategory,
      );
    }
    return parsed;
  }

  /// 手动触发的本地直方图启发式三套方案（仅用户明确点击「改用本地估算」时使用，绝不自动冒充 AI）。
  static AiColorGradeBundle analyzeOfflineFallback({
    required ImageColorStats stats,
    String styleHint = '',
    String localeCode = 'zh',
    List<SpektraStockInfo>? spektraStocks,
  }) {
    final lang = localeCode.toLowerCase();
    final catalog = AiRecipeCatalog.buildAll(
      spektraStocks: spektraStocks,
      localeCode: localeCode,
    );
    final picked = catalog.matchByKeywords(
      styleHint: styleHint,
      avgLuma: stats.avgLuma,
      warmBias: stats.warmBias,
      limit: 3,
    );

    final expDelta = ((0.50 - stats.avgLuma) * 35.0).clamp(-22.0, 22.0);
    final hlRecovery = stats.highlightFraction > 0.14 ? -34.0 : -12.0;
    final shLift = stats.shadowFraction > 0.22 ? 28.0 : 10.0;
    final tempFix = (-stats.warmBias * 24.0).clamp(-14.0, 14.0);
    final contrastBoost = stats.dynamicSpread < 0.45 ? 12.0 : 4.0;
    final satFix = stats.avgSaturation < 0.25 ? 10.0 : 2.0;

    AiCatalogEntry? entryAt(int idx) => idx < picked.length ? picked[idx] : null;
    final e0 = entryAt(0);
    final e1 = entryAt(1);
    final e2 = entryAt(2);

    final (
      defName0,
      defDesc0,
      defName1,
      defDesc1,
      defName2,
      defDesc2,
      diagnosisText
    ) = switch (lang) {
      'ja' => (
          'クリアナチュラル',
          '自動露出補正・ハイライト復元・ニュートラルなホワイトバランス。',
          'ティールシネマ',
          '暖かみのあるハイライトとクールなシャドウで映画的な奥行きを表現。',
          'ノスタルジックフィルム',
          '柔らかなシャドウフェードと温かみのある粒状感。',
          '平均輝度 ${(stats.avgLuma * 100).round()}%、シャドウ ${(stats.shadowFraction * 100).round()}%、ハイライト ${(stats.highlightFraction * 100).round()}%。',
        ),
      'en' => (
          'Clean Natural',
          'Auto exposure, highlight recovery and neutral white balance.',
          'Teal Cinema',
          'Warm highlights paired with cool shadows and deeper blacks.',
          'Nostalgic Film',
          'Gentle shadow fade, warm analog glow and subtle organic grain.',
          'Luma ${(stats.avgLuma * 100).round()}%, shadows ${(stats.shadowFraction * 100).round()}%, highlights ${(stats.highlightFraction * 100).round()}%.',
        ),
      _ => (
          '清透自然',
          '均衡曝光补偿、高光柔和拉回与中性通透白平衡。',
          '青橙电影',
          '暖调高光搭配冷青暗部，增强画面立体反差与叙事感。',
          '复古胶片',
          '柔和暗部空气感褪色、暖色胶片光晕与细腻银盐颗粒。',
          '画面平均亮度 ${(stats.avgLuma * 100).round()}%，暗部占比 ${(stats.shadowFraction * 100).round()}%，高光占比 ${(stats.highlightFraction * 100).round()}%${stats.warmBias > 0.08 ? '，整体色温偏暖' : (stats.warmBias < -0.08 ? '，整体色温偏冷' : '，色彩冷暖均衡')}。',
        ),
    };

    final natural = AiGradeVariant(
      id: 'natural',
      name: e0?.displayName ?? defName0,
      kind: e0?.kind ?? AiGradeRecipeKind.customAdjustments,
      recipeId: e0?.id,
      recipeDisplayName: e0?.displayName ?? '',
      recipeCategory: e0?.category ?? '',
      recipeIntensity: 0.85,
      rationale: styleHint.trim().isNotEmpty
          ? '${e0?.description ?? defDesc0}（${styleHint.trim()}）'
          : (e0?.description ?? defDesc0),
      adjustments: clampSafeAdjustments(
        PhotoEditAdjustments(
          temperature: tempFix,
          exposure: expDelta,
          contrast: contrastBoost,
          highlights: hlRecovery,
          shadows: shLift,
          whites: 4,
          blacks: -4,
          clarity: 6,
          vibrance: satFix + 6,
        ),
      ),
    );

    final cinematic = AiGradeVariant(
      id: 'cinematic',
      name: e1?.displayName ?? defName1,
      kind: e1?.kind ?? AiGradeRecipeKind.customAdjustments,
      recipeId: e1?.id,
      recipeDisplayName: e1?.displayName ?? '',
      recipeCategory: e1?.category ?? '',
      recipeIntensity: 0.82,
      rationale: e1?.description ?? defDesc1,
      adjustments: clampSafeAdjustments(
        PhotoEditAdjustments(
          temperature: tempFix * 0.5 + 3,
          exposure: expDelta * 0.85,
          contrast: contrastBoost + 8,
          highlights: hlRecovery - 6,
          shadows: shLift + 4,
          blacks: -10,
          clarity: 10,
          dehaze: 6,
          vibrance: 4,
        ),
      ),
    );

    final film = AiGradeVariant(
      id: 'film',
      name: e2?.displayName ?? defName2,
      kind: e2?.kind ?? AiGradeRecipeKind.customAdjustments,
      recipeId: e2?.id,
      recipeDisplayName: e2?.displayName ?? '',
      recipeCategory: e2?.category ?? '',
      recipeIntensity: 0.85,
      rationale: e2?.description ?? defDesc2,
      adjustments: clampSafeAdjustments(
        PhotoEditAdjustments(
          temperature: tempFix * 0.5 + 6,
          exposure: expDelta * 0.9,
          highlights: hlRecovery - 4,
          shadows: shLift + 12,
          blacks: 6,
          vibrance: 6,
          grain: 12,
        ),
      ),
    );

    return AiColorGradeBundle(
      diagnosis: diagnosisText,
      variants: [natural, cinematic, film],
      isOfflineFallback: true,
    );
  }

  static String _encodeAdjustmentsLiteral(PhotoEditAdjustments a) {
    final map = AiGradeVariant._adjustmentsToJson(a);
    final entries =
        map.entries.map((e) => '"${e.key}":${e.value.toStringAsFixed(1)}');
    return '{${entries.join(',')}}';
  }
}
