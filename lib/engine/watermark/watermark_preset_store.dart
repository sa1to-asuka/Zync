import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'watermark_overlay_layer.dart';
import 'watermark_template.dart';

/// 用户自定义水印版式 + 艺术字图层组合预设。
class WatermarkCustomPreset {
  final String id;
  final String name;
  final String templateId;
  final int? cardColorValue;
  final int? textColorValue;
  final int accentColorValue;
  final List<WatermarkTextLayer> textLayers;
  final int updatedAtMs;

  const WatermarkCustomPreset({
    required this.id,
    required this.name,
    this.templateId = 'none',
    this.cardColorValue,
    this.textColorValue,
    this.accentColorValue = 0xFFFFD100,
    this.textLayers = const [],
    this.updatedAtMs = 0,
  });

  WatermarkTemplate get template => WatermarkTemplate.fromId(templateId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateId': templateId,
        'cardColorValue': cardColorValue,
        'textColorValue': textColorValue,
        'accentColorValue': accentColorValue,
        'textLayers': textLayers.map((e) => e.toJson()).toList(),
        'updatedAtMs': updatedAtMs,
      };

  factory WatermarkCustomPreset.fromJson(Map<String, dynamic> json) =>
      WatermarkCustomPreset(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Custom Watermark',
        templateId: json['templateId'] as String? ?? 'none',
        cardColorValue: (json['cardColorValue'] as num?)?.toInt(),
        textColorValue: (json['textColorValue'] as num?)?.toInt(),
        accentColorValue:
            (json['accentColorValue'] as num?)?.toInt() ?? 0xFFFFD100,
        textLayers: (json['textLayers'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((e) =>
                WatermarkTextLayer.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      );
}

/// 自定义水印模板（含自由艺术字图层）本地存储。
class WatermarkPresetStore {
  static Future<File> _storeFile({Directory? overrideDirectory}) async {
    final root = overrideDirectory ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/watermark_presets');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/presets.json');
  }

  static Future<List<WatermarkCustomPreset>> load({
    Directory? overrideDirectory,
  }) async {
    try {
      final file = await _storeFile(overrideDirectory: overrideDirectory);
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      final list = <WatermarkCustomPreset>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            list.add(WatermarkCustomPreset.fromJson(
                Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      list.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(
    List<WatermarkCustomPreset> presets, {
    Directory? overrideDirectory,
  }) async {
    try {
      final file = await _storeFile(overrideDirectory: overrideDirectory);
      await file.writeAsString(
        jsonEncode(presets.map((e) => e.toJson()).toList()),
        flush: true,
      );
    } catch (_) {}
  }

  static Future<List<WatermarkCustomPreset>> upsert(
    WatermarkCustomPreset preset, {
    Directory? overrideDirectory,
  }) async {
    final current = [...await load(overrideDirectory: overrideDirectory)];
    final idx = current.indexWhere((e) => e.id == preset.id);
    if (idx >= 0) {
      current[idx] = preset;
    } else {
      current.insert(0, preset);
    }
    await save(current, overrideDirectory: overrideDirectory);
    return current;
  }

  static Future<List<WatermarkCustomPreset>> remove(
    String id, {
    Directory? overrideDirectory,
  }) async {
    final current = [...await load(overrideDirectory: overrideDirectory)];
    current.removeWhere((e) => e.id == id);
    await save(current, overrideDirectory: overrideDirectory);
    return current;
  }
}
