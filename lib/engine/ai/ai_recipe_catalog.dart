import '../../l10n/l10n.dart';
import '../editor/builtin_grade_presets.dart';
import '../filter/photo_filter.dart';
import '../spektrafilm/spektrafilm_models.dart';
import '../spektrafilm/spektrafilm_native.dart';

/// 调色方案所对应的 Zync 内置配方来源类型。
enum AiGradeRecipeKind {
  filter,
  spektraFilm,
  builtinPreset,
  customAdjustments;

  static AiGradeRecipeKind fromWire(String? raw) => switch (raw) {
        'filter' => AiGradeRecipeKind.filter,
        'spektra' || 'spektraFilm' || 'spektra_film' =>
          AiGradeRecipeKind.spektraFilm,
        'preset' || 'builtinPreset' || 'builtin_preset' =>
          AiGradeRecipeKind.builtinPreset,
        _ => AiGradeRecipeKind.customAdjustments,
      };
}

/// 一条可被 AI 检索、校验并直接一键应用到画布的真实内置配方条目。
class AiCatalogEntry {
  final String id;
  final AiGradeRecipeKind kind;
  final String displayName;
  final String category;
  final String description;
  final String searchKeywords;
  final PhotoFilterType? filterType;
  final String? spektraStockId;
  final BuiltinGradePreset? builtinPreset;

  const AiCatalogEntry({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.category,
    required this.description,
    this.searchKeywords = '',
    this.filterType,
    this.spektraStockId,
    this.builtinPreset,
  });

  String toPromptLine() => '- $id | $displayName [$category]: $description';
}

/// 统一聚合并检索 Zync 三大内置调色库：
/// 1. 大师滤镜库 ([PhotoFilterType])
/// 2. SpektraFilm 物理银盐胶片 ([SpektraStockInfo])
/// 3. 内置专业预设 ([kBuiltinGradePresets])
class AiRecipeCatalog {
  final List<AiCatalogEntry> entries;
  final Map<String, AiCatalogEntry> _byId;

  AiRecipeCatalog._(this.entries)
      : _byId = {for (final e in entries) e.id: e};

  factory AiRecipeCatalog.buildAll({
    List<SpektraStockInfo>? spektraStocks,
    String localeCode = 'zh',
  }) {
    final lang = localeCode.toLowerCase();
    final items = <AiCatalogEntry>[];

    // 1. 大师滤镜
    for (final f in PhotoFilterType.values) {
      if (f == PhotoFilterType.original) continue;
      final filterLoc = EngineL10n.filterById(f.name, lang);
      final localizedLabel = filterLoc?.label ?? L10n.tr(f.label, lang);
      final localizedCat = L10n.tr(f.category1, lang);
      final localizedDesc = filterLoc?.desc ??
          L10n.tr(
            f.description.isNotEmpty ? f.description : f.recipeSummary,
            lang,
          );
      items.add(
        AiCatalogEntry(
          id: 'filter:${f.name}',
          kind: AiGradeRecipeKind.filter,
          displayName: localizedLabel,
          category: localizedCat,
          description: localizedDesc,
          searchKeywords:
              '${f.name} ${f.label} ${f.code} ${f.category1} ${f.category2} ${f.description} ${f.recipeSummary}'
                  .toLowerCase(),
          filterType: f,
        ),
      );
    }

    // 2. SpektraFilm 物理银盐胶片
    final stocks = spektraStocks ?? SpektrafilmNative.stocks;
    for (final s in stocks) {
      if (s.id.isEmpty) continue;
      final isMotion = s.use == 'motion';
      final (catText, descText) = switch (lang) {
        'ja' => (
            '光学フィルム (${s.vendor})',
            'ISO ${s.iso} · ${isMotion ? '映画用フィルム' : '写真用フィルム'} · 光学暗室シミュレーション',
          ),
        'en' => (
            'SpektraFilm (${s.vendor})',
            'ISO ${s.iso} · ${isMotion ? 'Motion Picture Film' : 'Still Film'} · Optical darkroom simulation',
          ),
        _ => (
            '光学胶片 (${s.vendor})',
            'ISO ${s.iso} · ${isMotion ? '电影负片' : '摄影负片'} · 物理暗房银盐模拟',
          ),
      };
      items.add(
        AiCatalogEntry(
          id: 'spektra:${s.id}',
          kind: AiGradeRecipeKind.spektraFilm,
          displayName: s.name,
          category: catText,
          description: descText,
          searchKeywords:
              '${s.id} ${s.name} ${s.vendor} ${s.use} film'.toLowerCase(),
          spektraStockId: s.id,
        ),
      );
    }

    // 3. 内置专业预设
    for (final p in kBuiltinGradePresets) {
      items.add(
        AiCatalogEntry(
          id: 'preset:${p.id}',
          kind: AiGradeRecipeKind.builtinPreset,
          displayName: L10n.tr(p.name, lang),
          category: L10n.tr(p.category, lang),
          description: L10n.tr(p.description, lang),
          searchKeywords:
              '${p.id} ${p.name} ${p.category} ${p.description}'.toLowerCase(),
          builtinPreset: p,
        ),
      );
    }

    return AiRecipeCatalog._(items);
  }

  /// 按关键词（含连续中文词组双字切分）匹配排序，并按三库均衡配额裁剪输出紧凑 Prompt 目录（大幅加速推理）。
  List<AiCatalogEntry> selectForPrompt({
    String styleHint = '',
    int maxItems = 36,
  }) {
    if (entries.length <= maxItems) return entries;
    final query = styleHint.trim().toLowerCase();
    final tokens = query
        .split(RegExp(r'[\s,，、/]+'))
        .where((e) => e.isNotEmpty)
        .toList();
    final cjkBigrams = <String>[];
    for (final m in RegExp(r'[\u4e00-\u9fff]{2,}').allMatches(query)) {
      final run = m.group(0)!;
      for (var i = 0; i <= run.length - 2; i++) {
        cjkBigrams.add(run.substring(i, i + 2));
      }
    }

    int scoreEntry(AiCatalogEntry entry) {
      var s = 0;
      final nameLower = entry.displayName.toLowerCase();
      for (final t in tokens) {
        if (entry.searchKeywords.contains(t) || nameLower.contains(t)) {
          s += 12;
        }
      }
      for (final bg in cjkBigrams) {
        if (entry.searchKeywords.contains(bg) || nameLower.contains(bg)) {
          s += 6;
        }
      }
      return s;
    }

    final filters = entries
        .where((e) => e.kind == AiGradeRecipeKind.filter)
        .toList()
      ..sort((a, b) => scoreEntry(b).compareTo(scoreEntry(a)));
    final spektra = entries
        .where((e) => e.kind == AiGradeRecipeKind.spektraFilm)
        .toList()
      ..sort((a, b) => scoreEntry(b).compareTo(scoreEntry(a)));
    final presets = entries
        .where((e) => e.kind == AiGradeRecipeKind.builtinPreset)
        .toList()
      ..sort((a, b) => scoreEntry(b).compareTo(scoreEntry(a)));

    final selected = <AiCatalogEntry>[];
    final seen = <String>{};

    void addSlice(List<AiCatalogEntry> pool, int quota) {
      for (final item in pool.take(quota)) {
        if (selected.length >= maxItems) break;
        if (seen.add(item.id)) selected.add(item);
      }
    }

    // 均衡保证滤镜、物理胶片与内置预设三类均有代表进入 Prompt，同时优先命中关键词项
    final spektraQuota = maxItems >= 12 ? 8 : (maxItems ~/ 4).clamp(1, 8);
    final presetQuota = maxItems >= 12 ? 6 : (maxItems ~/ 6).clamp(1, 6);
    final filterQuota = (maxItems - spektraQuota - presetQuota).clamp(1, maxItems);

    addSlice(filters, filterQuota);
    addSlice(spektra, spektraQuota);
    addSlice(presets, presetQuota);

    if (selected.length < maxItems) {
      final remaining = [...filters, ...spektra, ...presets];
      for (final item in remaining) {
        if (selected.length >= maxItems) break;
        if (seen.add(item.id)) selected.add(item);
      }
    }
    return selected;
  }

  /// 严格校验模型返回的 `recipeId`（同时容忍未带前缀的裸枚举/底片名）。
  AiCatalogEntry? resolve(String? rawId) {
    final cleaned = rawId?.trim() ?? '';
    if (cleaned.isEmpty) return null;
    final direct = _byId[cleaned];
    if (direct != null) return direct;

    final byFilter = _byId['filter:$cleaned'];
    if (byFilter != null) return byFilter;
    final bySpektra = _byId['spektra:$cleaned'];
    if (bySpektra != null) return bySpektra;
    final byPreset = _byId['preset:$cleaned'];
    if (byPreset != null) return byPreset;

    final lower = cleaned.toLowerCase();
    for (final e in entries) {
      if (e.id.toLowerCase() == lower ||
          e.displayName.toLowerCase() == lower) {
        return e;
      }
    }
    return null;
  }

  /// 关键词回退推荐 3 款不重复真实配方（供本地估算兜底或模型未命中 ID 时修复）。
  List<AiCatalogEntry> matchByKeywords({
    String styleHint = '',
    double avgLuma = 0.5,
    double warmBias = 0.0,
    int limit = 3,
    Set<String> excludeIds = const {},
  }) {
    final q = styleHint.toLowerCase();
    final keywordMap = <(List<String>, List<String>)>[
      (
        ['新海诚', '动漫', '二次元', 'shinkai', 'anime', '晴空', '云'],
        ['filter:shinkaiAnime', 'filter:clearSky', 'filter:japanesePure']
      ),
      (
        ['日系', '清新', '通透', '空气感', '滨田', 'japanese', 'airy', 'pastel'],
        ['filter:japanesePure', 'filter:fujiPro400H', 'filter:sonySH']
      ),
      (
        ['富士', 'fuji', 'cc', '正片', '负片', 'street', '街拍', '纪实'],
        [
          'filter:classicChrome',
          'filter:fujiClassicNegative',
          'filter:fujiRealaAce'
        ]
      ),
      (
        ['王家卫', '港风', '香港', '霓虹', '夜景', 'night', 'neon'],
        ['filter:cityNight', 'filter:cinematic', 'filter:fujiNatura1600']
      ),
      (
        ['电影', '青橙', 'cinema', 'cinematic', 'teal', 'orange'],
        ['filter:cinematic', 'filter:fujiEterna', 'preset:portrait_warm']
      ),
      (
        ['胶片', '复古', '柯达', 'kodak', 'vintage', 'film', '温暖', '暖调'],
        ['filter:kodakPortra160', 'filter:fujiNostalgicNeg', 'filter:sonyFL']
      ),
      (
        ['人像', '少女', '肤色', 'portrait', 'skin'],
        ['filter:fujiAstia', 'filter:fairSkin', 'preset:portrait_soft']
      ),
      (
        ['黑白', '单色', 'mono', 'bw', 'black', 'monochrome'],
        ['filter:leicaMonochrome', 'filter:fujiAcros', 'preset:portrait_mono']
      ),
      (
        ['风光', '山水', '树林', 'forest', 'landscape', '绿'],
        ['filter:fujiVelvia', 'filter:forestGreen', 'preset:landscape_vivid']
      ),
    ];

    final picked = <AiCatalogEntry>[];
    final seen = Set<String>.from(excludeIds);

    void tryAdd(String id) {
      if (picked.length >= limit || seen.contains(id)) return;
      final hit = resolve(id);
      if (hit != null) {
        picked.add(hit);
        seen.add(hit.id);
      }
    }

    for (final (triggers, ids) in keywordMap) {
      if (triggers.any((kw) => q.contains(kw))) {
        for (final id in ids) {
          tryAdd(id);
        }
      }
    }

    // 文本未命中特定流派时，按亮度与冷暖自动挑 3 款均衡方案
    if (picked.length < limit) {
      if (avgLuma < 0.35) {
        tryAdd('filter:cityNight');
        tryAdd('filter:fujiNatura1600');
      } else if (warmBias > 0.12) {
        tryAdd('filter:fujiPro400H');
        tryAdd('filter:fujiAstia');
      } else {
        tryAdd('filter:japanesePure');
        tryAdd('filter:classicChrome');
      }
      tryAdd('filter:fujiRealaAce');
      tryAdd('filter:cinematic');
      tryAdd('preset:bright');
      tryAdd('preset:neutral');
    }

    for (final entry in entries) {
      if (picked.length >= limit) break;
      if (seen.add(entry.id)) picked.add(entry);
    }

    return picked;
  }
}
