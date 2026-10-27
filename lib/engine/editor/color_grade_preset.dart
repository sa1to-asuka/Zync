import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';
import 'pro_photo_models.dart';

/// 可保存 / 复用的调色预设。照片与视频共用同一份 [ColorGrade]，
/// 保证两边看到的效果完全一致。
class ColorGradePreset {
  static const int currentVersion = 1;

  final int version;
  final String id;
  final String name;

  /// true 表示整体调色（作用于全部片段），false 表示单片段调色。
  final bool isGlobal;

  /// true 表示整体预设，可一键套用到整条时间线。
  final bool isTimeline;

  final ColorGrade grade;
  final int createdAtMs;
  final int updatedAtMs;

  const ColorGradePreset({
    this.version = currentVersion,
    required this.id,
    required this.name,
    this.isGlobal = false,
    this.isTimeline = false,
    this.grade = const ColorGrade(),
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  /// 预设摘要，供列表快速展示（自动按当前激活语言本地化）。
  String get summary {
    final l = L10n.current;
    final parts = <String>[];
    final base = grade.base;
    void add(String label, double value) {
      if (value.abs() >= 0.5) {
        parts.add('$label ${value.round()}');
      }
    }

    add(l.adjExposure, base.exposure);
    add(l.adjContrast, base.contrast);
    add(l.adjSaturation, base.saturation);
    add(l.adjTemperature, base.temperature);
    add(l.adjSharpening, grade.sharpening);
    add(l.adjNoiseReduction, grade.noiseReduction);
    if (!grade.lut.isDefault) parts.add('LUT');
    if (!grade.toneCurve.isIdentity) parts.add(l.adjToneCurve);
    if (!grade.hsl.isDefault) parts.add('HSL');
    if (!grade.colorGrading.isDefault) parts.add(l.adjColorWheel);
    if (parts.isEmpty) return l.presetNoAdjustments;
    return parts.join(' · ');
  }

  ColorGradePreset copyWith({
    int? version,
    String? id,
    String? name,
    bool? isGlobal,
    bool? isTimeline,
    ColorGrade? grade,
    int? createdAtMs,
    int? updatedAtMs,
  }) =>
      ColorGradePreset(
        version: version ?? this.version,
        id: id ?? this.id,
        name: name ?? this.name,
        isGlobal: isGlobal ?? this.isGlobal,
        isTimeline: isTimeline ?? this.isTimeline,
        grade: grade ?? this.grade,
        createdAtMs: createdAtMs ?? this.createdAtMs,
        updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'id': id,
        'name': name,
        'isGlobal': isGlobal,
        'isTimeline': isTimeline,
        'grade': grade.toJson(),
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
      };

  String toJsonString() => jsonEncode(toJson());

  factory ColorGradePreset.fromJson(Map<String, dynamic> json) =>
      ColorGradePreset(
        version: (json['version'] as num?)?.toInt() ?? currentVersion,
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '未命名预设',
        isGlobal: json['isGlobal'] as bool? ?? false,
        isTimeline: json['isTimeline'] as bool? ?? false,
        grade: ColorGrade.fromJson(
            Map<String, dynamic>.from(json['grade'] as Map? ?? const {})),
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );

  static ColorGradePreset fromJsonString(String source) =>
      ColorGradePreset.fromJson(
          Map<String, dynamic>.from(jsonDecode(source) as Map));
}

/// 调色预设本地存储：应用私有目录 JSON，支持导入 / 导出分享。
class ColorGradePresetStore {
  static Future<File> _storeFile() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/color_presets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/presets.json');
  }

  static Future<List<ColorGradePreset>> load() async {
    try {
      final file = await _storeFile();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      final presets = <ColorGradePreset>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            presets.add(
                ColorGradePreset.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // 单条损坏不影响其它预设。
          }
        }
      }
      presets.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return presets;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<ColorGradePreset> presets) async {
    try {
      final file = await _storeFile();
      await file.writeAsString(
        jsonEncode(presets.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {
      // 预设持久化失败不应打断编辑。
    }
  }

  /// 追加或按 id 覆盖。
  static Future<List<ColorGradePreset>> upsert(ColorGradePreset preset) async {
    final presets = [...await load()];
    final index = presets.indexWhere((e) => e.id == preset.id);
    if (index >= 0) {
      presets[index] = preset;
    } else {
      presets.insert(0, preset);
    }
    await save(presets);
    return presets;
  }

  static Future<List<ColorGradePreset>> remove(String id) async {
    final presets = await load();
    presets.removeWhere((e) => e.id == id);
    await save(presets);
    return presets;
  }

  /// 导出为可分享的 JSON 文本（带版本号，便于跨设备导入）。
  static String exportJson(List<ColorGradePreset> presets) => jsonEncode({
        'app': 'Zync',
        'kind': 'color_grade_presets',
        'version': ColorGradePreset.currentVersion,
        'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
        'presets': presets.map((e) => e.toJson()).toList(),
      });

  /// 从导出的 JSON 文本导入，容错并去重。
  static List<ColorGradePreset> importJson(String source,
      {List<ColorGradePreset> existing = const []}) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      // 非法 JSON 直接返回现有预设，不打断导入流程。
      return existing;
    }
    final items = decoded is Map ? decoded['presets'] : decoded;
    if (items is! List) return existing;
    final result = [...existing];
    for (final item in items) {
      if (item is! Map) continue;
      try {
        final preset =
            ColorGradePreset.fromJson(Map<String, dynamic>.from(item));
        final index = result.indexWhere((e) => e.id == preset.id);
        // 导入的条目 updatedAtMs 更旧时不覆盖用户本地已修改的预设。
        if (index >= 0) {
          if (preset.updatedAtMs >= result[index].updatedAtMs) {
            result[index] = preset;
          }
        } else {
          result.add(preset);
        }
      } catch (_) {
        // 跳过损坏条目。
      }
    }
    result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return result;
  }
}
