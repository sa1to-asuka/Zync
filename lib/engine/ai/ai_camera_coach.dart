import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../capture/camera_property.dart';
import '../capture/exposure_settings_controller.dart';
import '../liveview/live_view_analysis.dart';
import '../picture_control/builtin_np3_recipes.dart';
import '../picture_control/picture_control_store.dart';
import 'ai_provider_config.dart';
import 'ai_vision_client.dart';

/// 取景器 AI 构图参考线类型。
enum CompositionGuideType {
  ruleOfThirds,
  goldenSpiral,
  diagonal,
  symmetry,
  leadingLines,
  center;

  static CompositionGuideType fromWire(String? raw) => switch (raw) {
        'golden_spiral' || 'goldenSpiral' => CompositionGuideType.goldenSpiral,
        'diagonal' => CompositionGuideType.diagonal,
        'symmetry' => CompositionGuideType.symmetry,
        'leading_lines' || 'leadingLines' => CompositionGuideType.leadingLines,
        'center' => CompositionGuideType.center,
        _ => CompositionGuideType.ruleOfThirds,
      };
}

/// 实拍技巧分类（对应自定义 SVG 矢量图标）。
enum AiTipCategory {
  lighting,
  pose,
  timing,
  position,
  lens;

  static AiTipCategory fromWire(String? raw) => switch (raw?.toLowerCase()) {
        'lighting' || 'light' => AiTipCategory.lighting,
        'pose' || 'model' || 'portrait' => AiTipCategory.pose,
        'timing' || 'moment' || 'street' => AiTipCategory.timing,
        'lens' || 'focal' || 'zoom' => AiTipCategory.lens,
        _ => AiTipCategory.position,
      };
}

/// AI 输出的场景化实拍指导（如：人像侧逆光走位、街拍等待亮色行人）。
class AiShootingTip {
  final AiTipCategory category;
  final String title;
  final String detail;

  const AiShootingTip({
    required this.category,
    required this.title,
    required this.detail,
  });

  factory AiShootingTip.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String? ?? '').trim();
    final detail = (json['detail'] as String? ?? '').trim();
    return AiShootingTip(
      category: AiTipCategory.fromWire(json['category'] as String?),
      title: title.isNotEmpty ? title : detail,
      detail: detail.isNotEmpty ? detail : title,
    );
  }
}

/// AI 在杂乱取景画面中发现的「最值得拍」裁切框与横竖屏比例建议。
class AiCropRecommendation {
  /// 归一化裁切区域 [0..1]（相对当前整帧画面）。
  final Rect cropBox;

  /// `'portrait'` | `'landscape'` | `'square'`
  final String orientation;

  /// 例如 `'2:3'`, `'4:5'`, `'9:16'`, `'3:2'`, `'16:9'`, `'1:1'`
  final String aspectRatio;

  /// AI 提炼的核心拍摄主体描述
  final String subjectTitle;

  /// 说明为什么要这样裁切、舍弃了哪些边缘杂物
  final String framingReason;

  const AiCropRecommendation({
    required this.cropBox,
    required this.orientation,
    required this.aspectRatio,
    required this.subjectTitle,
    required this.framingReason,
  });

  bool get isPortrait => orientation == 'portrait';

  static AiCropRecommendation? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawBox = json['cropBox'];
    if (rawBox is! List || rawBox.length < 4) return null;
    final nums = rawBox.whereType<num>().map((e) => e.toDouble()).toList();
    if (nums.length < 4) return null;

    final left = nums[0].clamp(0.0, 0.85);
    final top = nums[1].clamp(0.0, 0.85);
    final width = nums[2].clamp(0.15, 1.0 - left);
    final height = nums[3].clamp(0.15, 1.0 - top);
    final rect = Rect.fromLTWH(left, top, width, height);

    var orientation = (json['orientation'] as String? ?? '').trim().toLowerCase();
    if (orientation != 'portrait' &&
        orientation != 'landscape' &&
        orientation != 'square') {
      if ((width - height).abs() < 0.05) {
        orientation = 'square';
      } else {
        orientation = height > width ? 'portrait' : 'landscape';
      }
    }

    var aspect = (json['aspectRatio'] as String? ?? '').trim();
    if (aspect.isEmpty) {
      aspect = switch (orientation) {
        'portrait' => '2:3',
        'square' => '1:1',
        _ => '3:2',
      };
    }

    return AiCropRecommendation(
      cropBox: rect,
      orientation: orientation,
      aspectRatio: aspect,
      subjectTitle: (json['subjectTitle'] as String? ?? '').trim(),
      framingReason: (json['framingReason'] as String? ?? '').trim(),
    );
  }
}

/// AI 给出的抽象曝光调节建议。
class AiExposureSuggestion {
  final double? evDelta;
  final int? targetIso;
  final double? targetAperture;
  final double? targetShutterSec;
  final String reason;

  const AiExposureSuggestion({
    this.evDelta,
    this.targetIso,
    this.targetAperture,
    this.targetShutterSec,
    this.reason = '',
  });

  factory AiExposureSuggestion.fromJson(Map<String, dynamic> json) =>
      AiExposureSuggestion(
        evDelta: (json['evDelta'] as num?)?.toDouble(),
        targetIso: (json['targetIso'] as num?)?.round(),
        targetAperture: (json['targetAperture'] as num?)?.toDouble(),
        targetShutterSec: (json['targetShutterSec'] as num?)?.toDouble(),
        reason: json['reason'] as String? ?? '',
      );
}

/// 对齐到相机真实合法档位表后的待写回参数项。
class MatchedCameraWrite {
  final CameraParameter parameter;
  final int currentRaw;
  final int targetRaw;
  final String currentLabel;
  final String targetLabel;

  const MatchedCameraWrite({
    required this.parameter,
    required this.currentRaw,
    required this.targetRaw,
    required this.currentLabel,
    required this.targetLabel,
  });
}

/// 匹配自本地现有 NP3 配方库的推荐结果。
class AiNp3Match {
  final String recipeId;
  final int matchScore;
  final String reason;
  final PictureControlLibraryItem? resolvedItem;

  const AiNp3Match({
    required this.recipeId,
    required this.matchScore,
    required this.reason,
    this.resolvedItem,
  });
}

/// AI 取景构图、主体裁切发现、实战技巧、影调与机内优化校准综合分析结果。
class AiCameraCoachResult {
  final int compositionScore;
  final int exposureScore;
  final String sceneSummary;
  final CompositionGuideType guideType;
  final Rect? subjectBox;
  final Offset? targetPoint;
  final double? horizonTiltDeg;
  final String cameraMoveHint;
  final List<String> compositionTips;
  final AiCropRecommendation? cropRecommendation;
  final List<AiShootingTip> shootingTips;
  final String toneDiagnosis;
  final String colorMoodAdvice;
  final AiExposureSuggestion? exposureSuggestion;
  final List<AiNp3Match> np3Matches;
  final bool isOfflineFallback;

  const AiCameraCoachResult({
    required this.compositionScore,
    required this.exposureScore,
    required this.sceneSummary,
    this.guideType = CompositionGuideType.ruleOfThirds,
    this.subjectBox,
    this.targetPoint,
    this.horizonTiltDeg,
    this.cameraMoveHint = '',
    this.compositionTips = const [],
    this.cropRecommendation,
    this.shootingTips = const [],
    this.toneDiagnosis = '',
    this.colorMoodAdvice = '',
    this.exposureSuggestion,
    this.np3Matches = const [],
    this.isOfflineFallback = false,
  });

  /// 取景器/弹窗实际使用的最佳高亮区域（优先用精细裁切框，退回主体框）。
  Rect? get effectiveCropRect => cropRecommendation?.cropBox ?? subjectBox;

  AiCameraCoachResult copyWith({List<AiNp3Match>? np3Matches}) =>
      AiCameraCoachResult(
        compositionScore: compositionScore,
        exposureScore: exposureScore,
        sceneSummary: sceneSummary,
        guideType: guideType,
        subjectBox: subjectBox,
        targetPoint: targetPoint,
        horizonTiltDeg: horizonTiltDeg,
        cameraMoveHint: cameraMoveHint,
        compositionTips: compositionTips,
        cropRecommendation: cropRecommendation,
        shootingTips: shootingTips,
        toneDiagnosis: toneDiagnosis,
        colorMoodAdvice: colorMoodAdvice,
        exposureSuggestion: exposureSuggestion,
        np3Matches: np3Matches ?? this.np3Matches,
        isOfflineFallback: isOfflineFallback,
      );

  factory AiCameraCoachResult.fromJson(
    Map<String, dynamic> json, {
    required List<PictureControlLibraryItem> catalog,
    String sceneHint = '',
  }) {
    final cropRec = json['cropRecommendation'] is Map
        ? AiCropRecommendation.fromJson(
            Map<String, dynamic>.from(json['cropRecommendation'] as Map),
          )
        : null;

    Rect? box;
    final rawBox = json['subjectBox'];
    if (rawBox is List && rawBox.length >= 4) {
      final nums = rawBox.whereType<num>().map((e) => e.toDouble()).toList();
      if (nums.length >= 4) {
        final left = nums[0].clamp(0.0, 0.90);
        final top = nums[1].clamp(0.0, 0.90);
        box = Rect.fromLTWH(
          left,
          top,
          nums[2].clamp(0.10, 1.0 - left),
          nums[3].clamp(0.10, 1.0 - top),
        );
      }
    }
    box ??= cropRec?.cropBox;

    Offset? target;
    final rawPt = json['targetPoint'];
    if (rawPt is List && rawPt.length >= 2) {
      final nums = rawPt.whereType<num>().map((e) => e.toDouble()).toList();
      if (nums.length >= 2) {
        target = Offset(nums[0].clamp(0.05, 0.95), nums[1].clamp(0.05, 0.95));
      }
    }

    final parsedShootingTips = <AiShootingTip>[];
    for (final raw in (json['shootingTips'] as List<dynamic>? ?? const [])) {
      if (raw is Map) {
        final tip = AiShootingTip.fromJson(Map<String, dynamic>.from(raw));
        if (tip.title.isNotEmpty || tip.detail.isNotEmpty) {
          parsedShootingTips.add(tip);
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        parsedShootingTips.add(AiShootingTip(
          category: AiTipCategory.position,
          title: raw.trim(),
          detail: raw.trim(),
        ));
      }
    }

    var legacyTips = (json['compositionTips'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .take(4)
        .toList();
    if (legacyTips.isEmpty && parsedShootingTips.isNotEmpty) {
      legacyTips = parsedShootingTips
          .map((t) => t.detail)
          .where((e) => e.isNotEmpty)
          .take(4)
          .toList();
    }

    final rawExp = json['exposureSuggestion'];
    final expSug = rawExp is Map
        ? AiExposureSuggestion.fromJson(Map<String, dynamic>.from(rawExp))
        : null;

    final rawMatches = json['np3Matches'] as List<dynamic>? ?? const [];
    final validatedNp3 = AiNp3Matcher.validateAndResolve(
      rawMatches,
      catalog: catalog,
      sceneHint: '$sceneHint ${json['sceneSummary'] ?? ''} ${cropRec?.subjectTitle ?? ''}',
    );

    return AiCameraCoachResult(
      compositionScore:
          ((json['compositionScore'] as num?)?.round() ?? 75).clamp(0, 100),
      exposureScore:
          ((json['exposureScore'] as num?)?.round() ?? 75).clamp(0, 100),
      sceneSummary: (json['sceneSummary'] as String? ?? '').trim(),
      guideType: CompositionGuideType.fromWire(json['guideType'] as String?),
      subjectBox: box,
      targetPoint: target,
      horizonTiltDeg: (json['horizonTiltDeg'] as num?)?.toDouble(),
      cameraMoveHint: (json['cameraMoveHint'] as String? ?? '').trim(),
      compositionTips: legacyTips,
      cropRecommendation: cropRec,
      shootingTips: parsedShootingTips.take(4).toList(growable: false),
      toneDiagnosis: (json['toneDiagnosis'] as String? ?? '').trim(),
      colorMoodAdvice: (json['colorMoodAdvice'] as String? ?? '').trim(),
      exposureSuggestion: expSug,
      np3Matches: validatedNp3,
    );
  }
}

/// 将 VLM 输出的抽象曝光建议精准对齐到当前机身 [ExposureSettingsController]
/// 实际支持且当前档位可写的最近邻合法档位值。
class CameraParamMatcher {
  CameraParamMatcher._();

  static List<MatchedCameraWrite> match(
    AiExposureSuggestion? suggestion,
    ExposureSettingsController exposure,
  ) {
    if (suggestion == null || !exposure.hasData) return const [];
    final writes = <MatchedCameraWrite>[];

    // 1. EV 曝光补偿
    if (suggestion.evDelta != null && suggestion.evDelta!.abs() >= 0.2) {
      final b = exposure.bindingOf(CameraParameter.exposureCompensation);
      if (b != null && b.writable && b.options.isNotEmpty) {
        final curEv = _decodeEv(b.currentValue);
        final targetEv = (curEv + suggestion.evDelta!).clamp(-5.0, 5.0);
        final bestRaw = _nearestOption(b.options, targetEv, _decodeEv);
        if (bestRaw != b.currentValue) {
          writes.add(MatchedCameraWrite(
            parameter: CameraParameter.exposureCompensation,
            currentRaw: b.currentValue,
            targetRaw: bestRaw,
            currentLabel: b.labelOf(b.currentValue),
            targetLabel: b.labelOf(bestRaw),
          ));
        }
      }
    }

    // 2. ISO
    if (suggestion.targetIso != null && suggestion.targetIso! > 0) {
      final b = exposure.bindingOf(CameraParameter.iso);
      if (b != null && b.writable && b.options.isNotEmpty) {
        final target = suggestion.targetIso!.toDouble();
        final bestRaw = _nearestOption(b.options, target, (v) => v.toDouble());
        if (bestRaw != b.currentValue) {
          writes.add(MatchedCameraWrite(
            parameter: CameraParameter.iso,
            currentRaw: b.currentValue,
            targetRaw: bestRaw,
            currentLabel: b.labelOf(b.currentValue),
            targetLabel: b.labelOf(bestRaw),
          ));
        }
      }
    }

    // 3. 光圈 F 值
    if (suggestion.targetAperture != null && suggestion.targetAperture! > 0) {
      final b = exposure.bindingOf(CameraParameter.aperture);
      if (b != null && b.writable && b.options.isNotEmpty) {
        final bestRaw = _nearestOption(
          b.options,
          suggestion.targetAperture!,
          (v) => v / 100.0,
        );
        if (bestRaw != b.currentValue) {
          writes.add(MatchedCameraWrite(
            parameter: CameraParameter.aperture,
            currentRaw: b.currentValue,
            targetRaw: bestRaw,
            currentLabel: b.labelOf(b.currentValue),
            targetLabel: b.labelOf(bestRaw),
          ));
        }
      }
    }

    // 4. 快门速度（秒）
    if (suggestion.targetShutterSec != null &&
        suggestion.targetShutterSec! > 0) {
      final b = exposure.bindingOf(CameraParameter.shutter);
      if (b != null && b.writable && b.options.isNotEmpty) {
        double decodeShutter(int raw) {
          if (b.propertyId == 0x500D) return raw / 10000.0;
          final num = (raw >> 16) & 0xFFFF;
          final den = raw & 0xFFFF;
          if (den == 0 || num >= 65500) return 9999.0;
          return num / den;
        }

        final bestRaw = _nearestOption(
          b.options,
          suggestion.targetShutterSec!,
          decodeShutter,
          useLog: true,
        );
        if (bestRaw != b.currentValue && bestRaw != 0xFFFFFFFF) {
          writes.add(MatchedCameraWrite(
            parameter: CameraParameter.shutter,
            currentRaw: b.currentValue,
            targetRaw: bestRaw,
            currentLabel: b.labelOf(b.currentValue),
            targetLabel: b.labelOf(bestRaw),
          ));
        }
      }
    }

    return writes;
  }

  static double _decodeEv(int raw) {
    final signed = (raw & 0xFFFF) >= 0x8000 ? (raw & 0xFFFF) - 0x10000 : raw;
    return signed / 1000.0;
  }

  static int _nearestOption(
    List<int> options,
    double target,
    double Function(int raw) decode, {
    bool useLog = false,
  }) {
    var best = options.first;
    var bestDist = double.infinity;
    for (final opt in options) {
      final v = decode(opt);
      final dist = useLog && v > 0 && target > 0
          ? (math.log(v) - math.log(target)).abs()
          : (v - target).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = opt;
      }
    }
    return best;
  }
}

/// 现有 NP3 优化校准库智能匹配器（严防大模型幻觉编造不存在 ID）。
class AiNp3Matcher {
  AiNp3Matcher._();

  /// 构建紧凑目录列表供 Prompt 注入（若配方库较大则按场景关键词优先筛选前 45 款）。
  static List<Map<String, String>> buildCatalogDigest(
    List<PictureControlLibraryItem> catalog, {
    String sceneHint = '',
    int maxItems = 45,
  }) {
    if (catalog.isEmpty) return const [];
    final scored = <(int score, PictureControlLibraryItem item)>[];
    final hintLower = sceneHint.toLowerCase();
    for (final item in catalog) {
      var s = 0;
      if (hintLower.isNotEmpty) {
        if (hintLower.contains(item.category.labelZh.toLowerCase()) ||
            hintLower.contains(item.category.name.toLowerCase())) {
          s += 5;
        }
        if (item.description.toLowerCase().contains(hintLower) ||
            item.displayTitle.toLowerCase().contains(hintLower) ||
            hintLower.contains(item.recommendedSceneId.toLowerCase())) {
          s += 4;
        }
      }
      if (!item.isFlexibleColor) s += 1;
      scored.add((s, item));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.take(maxItems).map((e) {
      final item = e.$2;
      return {
        'id': item.id,
        'title': item.displayTitle,
        'cat': item.category.labelZh,
        'desc': item.description,
      };
    }).toList(growable: false);
  }

  /// 校验 VLM 返回的 `np3Matches`，只保留 [catalog] 中真实存在的配方；
  /// 若模型未命中任何合法 ID，则按场景关键词回退推荐现有最佳配方。
  static List<AiNp3Match> validateAndResolve(
    List<dynamic> rawMatches, {
    required List<PictureControlLibraryItem> catalog,
    String sceneHint = '',
  }) {
    final byId = {for (final item in catalog) item.id: item};
    final out = <AiNp3Match>[];
    final seen = <String>{};

    for (final raw in rawMatches) {
      if (raw is! Map) continue;
      final id = (raw['recipeId'] as String? ?? '').trim();
      final item = byId[id];
      if (item == null || !seen.add(id)) continue;
      out.add(AiNp3Match(
        recipeId: id,
        matchScore: ((raw['matchScore'] as num?)?.round() ?? 85).clamp(1, 100),
        reason: (raw['reason'] as String? ?? item.description).trim(),
        resolvedItem: item,
      ));
    }

    if (out.isEmpty && catalog.isNotEmpty) {
      return fallbackMatch(catalog: catalog, sceneHint: sceneHint);
    }
    return out.take(3).toList(growable: false);
  }

  /// 基于关键词/分类的离线确定性 NP3 匹配兜底。
  static List<AiNp3Match> fallbackMatch({
    required List<PictureControlLibraryItem> catalog,
    String sceneHint = '',
  }) {
    if (catalog.isEmpty) return const [];
    final q = sceneHint.toLowerCase();
    final categoryScores = <PictureControlCategory, List<String>>{
      PictureControlCategory.portrait: ['人像', 'portrait', '肤色', '肖像', '女神'],
      PictureControlCategory.landscape: ['风光', '山水', 'landscape', '自然', '海'],
      PictureControlCategory.street: ['街拍', 'street', '纪实', '人文'],
      PictureControlCategory.vintage: ['复古', 'vintage', '胶片', 'film', '怀旧', '落日'],
      PictureControlCategory.cinema: ['电影', 'cinema', '青橙', '叙事', '24look'],
      PictureControlCategory.airy: ['日系', '清新', 'airy', '通透', '春日', '绿'],
      PictureControlCategory.night: ['夜景', 'night', '霓虹', '暗调', '路灯'],
      PictureControlCategory.mono: ['黑白', 'mono', 'bw', '黑白色调'],
    };

    PictureControlCategory? matchedCat;
    for (final entry in categoryScores.entries) {
      if (entry.value.any((kw) => q.contains(kw))) {
        matchedCat = entry.key;
        break;
      }
    }

    final ranked = [...catalog]..sort((a, b) {
        var sa = 0;
        var sb = 0;
        if (matchedCat != null) {
          if (a.category == matchedCat) sa += 10;
          if (b.category == matchedCat) sb += 10;
        }
        if (!a.isFlexibleColor) sa += 2;
        if (!b.isFlexibleColor) sb += 2;
        return sb.compareTo(sa);
      });

    return ranked.take(2).map((item) {
      return AiNp3Match(
        recipeId: item.id,
        matchScore: matchedCat != null && item.category == matchedCat ? 88 : 76,
        reason: item.description.isNotEmpty
            ? item.description
            : '${item.category.labelZh} · ${item.cameraName}',
        resolvedItem: item,
      );
    }).toList(growable: false);
  }
}

/// 实时取景 AI 构图裁切发现与实战摄影指导引擎。
class AiCameraCoach {
  AiCameraCoach({AiVisionClient? client})
      : _client = client ?? AiVisionClient();

  final AiVisionClient _client;

  static String _languageInstruction(String localeCode) => switch (localeCode) {
        'ja' => 'Japanese (日本語)',
        'en' => 'English',
        _ => 'Simplified Chinese (简体中文)',
      };

  Future<AiCameraCoachResult> analyzeLiveFrame({
    required AiProviderProfile profile,
    required String modelId,
    required String apiKey,
    required Uint8List frameJpeg,
    required String sceneIntent,
    required Map<String, String> exposureTelemetry,
    required List<PictureControlLibraryItem> np3Catalog,
    bool includeExifTelemetry = true,
    String localeCode = 'zh',
    int? frameWidth,
    int? frameHeight,
    bool preferCellular = false,
  }) async {
    final isZh = localeCode.toLowerCase().startsWith('zh');
    final digest = AiNp3Matcher.buildCatalogDigest(
      np3Catalog,
      sceneHint: sceneIntent,
    );
    final langName = _languageInstruction(localeCode);
    final sizeLine = (frameWidth != null && frameHeight != null)
        ? 'Live-view frame dimensions: ${frameWidth}x$frameHeight (normalized coords 0..1 from top-left)'
        : 'Normalized coords 0..1 from top-left';

    final systemPrompt = isZh
        ? '''你是尼康 Z 系列大师级摄影师与现场构图指导教练。
请从当前实时取景画面中找出**最值得拍摄的最佳局部构图位置**：
1. 判断横构图（landscape）、竖构图（portrait）或方画幅（square）哪种最出片，输出归一化推荐构图框 `cropRecommendation.cropBox` `[x, y, w, h]`，直接把杂乱边缘裁掉、框出核心主体与光影引导线。
2. 给出当下立即可执行的场景化实拍技巧 `shootingTips`（如人像请模特转向 45 度侧逆光、街拍等待亮色衣物路人走入三分点、风光压低/抬高机位或长焦压缩空间）。
3. 输出曝光调整建议与最匹配的 2~3 款 `.NP3` 机内优化校准配方。

严格输出规则：
- 只输出一个紧凑、合法的 JSON 对象（严禁输出 JSON 之外的解释文字，严禁包含任何 emoji 表情符号）。
- 所有可读文本字段（`sceneSummary`、`cropRecommendation.subjectTitle`、`cropRecommendation.framingReason`、`cameraMoveHint`、`shootingTips[].title`、`shootingTips[].detail`、`toneDiagnosis`、`colorMoodAdvice`、`exposureSuggestion.reason`、`np3Matches[].reason`）必须 **100% 使用简体中文输出**，严禁输出英文句子！
- `cropRecommendation.cropBox` 坐标必须满足：0 <= x < 0.85, 0 <= y < 0.85, 0.15 <= w <= 1-x, 0.15 <= h <= 1-y。

JSON Schema:
{"compositionScore":88,"exposureScore":85,"sceneSummary":"中文场景与光线一句话总结","guideType":"rule_of_thirds","cropRecommendation":{"cropBox":[0.2,0.12,0.5,0.75],"orientation":"portrait","aspectRatio":"2:3","subjectTitle":"中文核心主体短标题","framingReason":"中文说明为何框选此位置及裁掉了哪些杂乱背景"},"cameraMoveHint":"中文具体机位/变焦动作建议","shootingTips":[{"category":"lighting","title":"中文技巧短标题","detail":"中文具体实拍指导"}],"toneDiagnosis":"中文影调与动态范围诊断","colorMoodAdvice":"中文白平衡与色彩氛围建议","exposureSuggestion":{"evDelta":0.0,"targetIso":null,"targetAperture":null,"targetShutterSec":null,"reason":"中文曝光原因"},"np3Matches":[{"recipeId":"必须精确复制自np3Catalog的id","matchScore":90,"reason":"中文匹配理由"}]}'''
        : '''You are a master Nikon Z photographer, director of photography, and on-set shooting coach.
Analyze the cluttered or wide live-view frame and find the SINGLE MOST COMPELLING photograph hidden inside it:
1. Decide whether portrait or landscape (or square) works best, and output an accurate normalized `cropRecommendation.cropBox` `[x, y, w, h]` that cuts away messy distractions and isolates the strongest subject + leading lines + light.
2. Provide concrete, scene-specific `shootingTips` the photographer can act on RIGHT NOW.
3. Also output exposure adjustments and top 2-3 matching `.NP3` recipes from `np3Catalog`.

STRICT OUTPUT RULES:
- Return ONLY a single compact valid JSON object (no markdown outside JSON).
- All human-readable strings MUST be in $langName and MUST NOT contain emoji characters.
- `cropRecommendation.cropBox` coordinates MUST satisfy: 0 <= x < 0.85, 0 <= y < 0.85, 0.15 <= w <= 1-x, 0.15 <= h <= 1-y.

JSON Schema:
{"compositionScore":88,"exposureScore":85,"sceneSummary":"concise 1-sentence scene & light diagnosis","guideType":"rule_of_thirds","cropRecommendation":{"cropBox":[0.2,0.12,0.5,0.75],"orientation":"portrait","aspectRatio":"2:3","subjectTitle":"short subject title","framingReason":"why cutting out surroundings makes a better shot"},"cameraMoveHint":"1 concrete camera movement / zoom step","shootingTips":[{"category":"lighting","title":"short heading","detail":"specific actionable direction"}],"toneDiagnosis":"lighting & dynamic range diagnosis","colorMoodAdvice":"concise color/white-balance mood tip","exposureSuggestion":{"evDelta":0.0,"targetIso":null,"targetAperture":null,"targetShutterSec":null,"reason":"short exposure reason"},"np3Matches":[{"recipeId":"MUST be an exact id from np3Catalog","matchScore":90,"reason":"reason"}]}''';

    final buf = StringBuffer();
    buf.writeln(sizeLine);
    buf.writeln(isZh
        ? '拍摄意图：${sceneIntent.trim().isEmpty ? "自动识别画面最佳主体并给出推荐构图框与实拍指导（全部输出简体中文）" : sceneIntent.trim()}'
        : 'Photographer intent: ${sceneIntent.trim().isEmpty ? "Auto identify subject & recommend best frame" : sceneIntent.trim()}');
    if (includeExifTelemetry && exposureTelemetry.isNotEmpty) {
      buf.writeln('Camera telemetry: $exposureTelemetry');
    }
    if (digest.isNotEmpty) {
      buf.writeln('Available np3Catalog (pick ONLY exact ids for top 2-3 matches):');
      for (final item in digest) {
        buf.writeln('- id=${item['id']} | ${item['title']} [${item['cat']}]: ${item['desc']}');
      }
    }

    final res = await _client.analyzeImage(
      profile: profile,
      modelId: modelId,
      apiKey: apiKey,
      imageBytes: frameJpeg,
      systemPrompt: systemPrompt,
      userPrompt: buf.toString(),
      maxEdge: 960,
      jpegQuality: 82,
      maxTokens: 4096,
      temperature: 0.25,
      preferCellular: preferCellular,
    );

    final jsonMap = AiVisionClient.extractJsonObject(res.text);
    return AiCameraCoachResult.fromJson(
      jsonMap,
      catalog: np3Catalog,
      sceneHint: sceneIntent,
    );
  }

  /// 手动触发的本地离线构图与曝光启发式诊断（仅用户在无网/失败时主动点击，绝不静默冒充 AI）。
  static AiCameraCoachResult analyzeOfflineFallback(
    Uint8List frameJpeg, {
    required List<PictureControlLibraryItem> np3Catalog,
    String sceneIntent = '',
    String localeCode = 'zh',
  }) {
    final lang = localeCode.toLowerCase();
    final decoded = img.decodeJpg(frameJpeg);
    if (decoded == null) {
      const box = Rect.fromLTWH(0.18, 0.14, 0.64, 0.72);
      final (summary, subj, reason, moveHint, tipTitle, tipDetail, tone) =
          switch (lang) {
        'ja' => (
            'ローカル基本構図ガイド',
            '中央メイン領域',
            '周辺の情報量を整理し、中央の主要被写体を際立たせるトリミング枠です。',
            '水平を保ち、三分割交点付近に被写体を配置してください。',
            'フレーミングを引き締める',
            '半歩前に出るか少しズームして画面端の不要物を除外します。',
            'ハイライトの白飛びを抑えて撮影してください。',
          ),
        'en' => (
            'Local fallback baseline',
            'Center Frame',
            'Balanced inner crop isolating center region.',
            'Keep horizon level and place subject near thirds intersection.',
            'Tighten framing',
            'Step forward or zoom slightly to exclude edge clutter.',
            'Histogram fallback ready; avoid highlight clipping.',
          ),
        _ => (
            '本地离线基础构图参考',
            '画面核心区域',
            '收敛四周边缘干扰，聚焦中央主体与三分线构图区域。',
            '保持地平线水平，将主体置于三分法交点附近。',
            '收紧取景范围',
            '可向前半步或适度变焦，剔除画面边缘杂物。',
            '注意控制高光不过曝，保留暗部层次细节。',
          ),
      };
      return AiCameraCoachResult(
        compositionScore: 70,
        exposureScore: 70,
        sceneSummary: summary,
        cropRecommendation: AiCropRecommendation(
          cropBox: box,
          orientation: 'landscape',
          aspectRatio: '3:2',
          subjectTitle: subj,
          framingReason: reason,
        ),
        subjectBox: box,
        cameraMoveHint: moveHint,
        shootingTips: [
          AiShootingTip(
            category: AiTipCategory.position,
            title: tipTitle,
            detail: tipDetail,
          ),
        ],
        toneDiagnosis: tone,
        np3Matches: AiNp3Matcher.fallbackMatch(
          catalog: np3Catalog,
          sceneHint: sceneIntent,
        ),
        isOfflineFallback: true,
      );
    }

    final small = decoded.width > 240
        ? img.copyResize(decoded, width: 240)
        : decoded;
    final rgba = small.getBytes(order: img.ChannelOrder.rgba);
    final analysis = analyzeRgbaPixels(
      rgba,
      small.width,
      small.height,
      const LiveViewAnalysisSettings(histogram: true),
    );
    final totalPx = math.max(1, small.width * small.height);
    var sumLuma = 0;
    var clipHigh = 0;
    var crushLow = 0;
    for (var i = 0; i < 256; i++) {
      final c = analysis.histogram[i];
      sumLuma += i * c;
      if (i >= 245) clipHigh += c;
      if (i <= 12) crushLow += c;
    }
    final meanLuma = sumLuma / totalPx;
    final highPct = clipHigh * 100.0 / totalPx;
    final lowPct = crushLow * 100.0 / totalPx;

    final luma = computeLuma(rgba, small.width, small.height);
    final sobel = computeSobelMagnitude(luma, small.width, small.height);
    var wx = 0.0;
    var wy = 0.0;
    var wSum = 0.0;
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final mag = sobel[y * small.width + x];
        if (mag > 180) {
          wx += x * mag;
          wy += y * mag;
          wSum += mag;
        }
      }
    }
    final cx = wSum > 0 ? (wx / wSum / small.width).clamp(0.22, 0.78) : 0.5;
    final cy = wSum > 0 ? (wy / wSum / small.height).clamp(0.22, 0.78) : 0.5;

    const boxW = 0.52;
    const boxH = 0.64;
    final boxLeft = (cx - boxW * 0.5).clamp(0.06, 1.0 - boxW - 0.06);
    final boxTop = (cy - boxH * 0.5).clamp(0.06, 1.0 - boxH - 0.06);
    final cropBox = Rect.fromLTWH(boxLeft, boxTop, boxW, boxH);

    final targetX = cx < 0.5 ? 0.333 : 0.667;
    final targetY = cy < 0.5 ? 0.333 : 0.667;
    final evDelta = highPct > 8.0
        ? -0.7
        : (meanLuma < 65 ? 0.7 : (meanLuma > 185 ? -0.3 : 0.0));

    final (toneMsg, subjTitle, frameReason, tipHeading, moveMsg) =
        switch (lang) {
      'ja' => (
          highPct > 8.0
              ? 'ハイライト白飛び ${highPct.toStringAsFixed(1)}%、露出補正を少し下げてください。'
              : (lowPct > 25.0
                  ? '暗部シャドウ ${lowPct.toStringAsFixed(1)}%、ディテールを残す場合は露出をプラスへ。'
                  : '輝度バランス良好（平均 ${meanLuma.round()}/255）。'),
          '高コントラスト主題域',
          'エッジ密度の高い主要被写体周辺を切り出し、周辺ノイズを整理します。',
          '主題領域へのフレーミング集中',
          'ガイド枠の位置に合わせてズームまたはカメラ位置を微調整してください。',
        ),
      'en' => (
          highPct > 8.0
              ? 'Highlight clipping ${highPct.toStringAsFixed(1)}%, reduce EV slightly.'
              : (lowPct > 25.0
                  ? 'Deep shadows ${lowPct.toStringAsFixed(1)}%, lift exposure if keeping detail.'
                  : 'Balanced luma (${meanLuma.round()}/255).'),
          'High-Contrast Subject',
          'Estimated from Sobel edge density around primary subject.',
          'Isolate primary subject',
          'Align framing with the highlighted crop region.',
        ),
      _ => (
          highPct > 8.0
              ? '高光溢出约 ${highPct.toStringAsFixed(1)}%，建议适当压低曝光补偿保护亮部。'
              : (lowPct > 25.0
                  ? '暗部阴影占比 ${lowPct.toStringAsFixed(1)}%，如需保留暗部细节可微提曝光。'
                  : '画面整体亮度均衡（均值 ${meanLuma.round()}/255）。'),
          '核心纹理反差主体',
          '基于边缘梯度重心提取画面视觉焦点，裁除四周杂乱干扰。',
          '聚焦框内核心主体',
          '建议按高亮构图框微调机位或焦段，使主体保持在黄金视觉区。',
        ),
    };

    final expScore = (100 - highPct * 2.5 - (lowPct > 30 ? (lowPct - 30) : 0))
        .round()
        .clamp(45, 95);

    return AiCameraCoachResult(
      compositionScore: 76,
      exposureScore: expScore,
      sceneSummary: toneMsg,
      guideType: CompositionGuideType.ruleOfThirds,
      cropRecommendation: AiCropRecommendation(
        cropBox: cropBox,
        orientation: 'portrait',
        aspectRatio: '4:5',
        subjectTitle: subjTitle,
        framingReason: frameReason,
      ),
      subjectBox: cropBox,
      targetPoint: Offset(targetX, targetY),
      cameraMoveHint: moveMsg,
      compositionTips: [moveMsg, toneMsg],
      shootingTips: [
        AiShootingTip(
          category: AiTipCategory.position,
          title: tipHeading,
          detail: moveMsg,
        ),
      ],
      toneDiagnosis: toneMsg,
      exposureSuggestion: evDelta != 0.0
          ? AiExposureSuggestion(evDelta: evDelta, reason: toneMsg)
          : null,
      np3Matches: AiNp3Matcher.fallbackMatch(
        catalog: np3Catalog,
        sceneHint: sceneIntent,
      ),
      isOfflineFallback: true,
    );
  }
}
