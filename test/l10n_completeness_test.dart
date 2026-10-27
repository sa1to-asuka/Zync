import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/collage/collage_layout.dart';
import 'package:zync/engine/editor/builtin_grade_presets.dart';
import 'package:zync/engine/filter/photo_filter.dart';
import 'package:zync/engine/watermark/watermark_template.dart';
import 'package:zync/l10n/l10n.dart';

Set<String> _extractPlaceholders(String value) {
  return RegExp(r'\{([a-zA-Z0-9_]+)\}')
      .allMatches(value)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  group('ARB 三语完整性与占位符一致性校验', () {
    late Map<String, dynamic> en;
    late Map<String, dynamic> zh;
    late Map<String, dynamic> ja;

    setUpAll(() {
      en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
          as Map<String, dynamic>;
      zh = jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync())
          as Map<String, dynamic>;
      ja = jsonDecode(File('lib/l10n/app_ja.arb').readAsStringSync())
          as Map<String, dynamic>;
    });

    test('en / zh / ja 三个 ARB 的有效词条 key 集合完全一致且无空串', () {
      final enKeys = en.keys.where((k) => !k.startsWith('@')).toSet();
      final zhKeys = zh.keys.where((k) => !k.startsWith('@')).toSet();
      final jaKeys = ja.keys.where((k) => !k.startsWith('@')).toSet();

      expect(zhKeys, equals(enKeys), reason: 'app_zh.arb 与 app_en.arb key 不一致');
      expect(jaKeys, equals(enKeys), reason: 'app_ja.arb 与 app_en.arb key 不一致');

      for (final key in enKeys) {
        expect((en[key] as String).trim(), isNotEmpty, reason: 'en.$key 为空');
        expect((zh[key] as String).trim(), isNotEmpty, reason: 'zh.$key 为空');
        expect((ja[key] as String).trim(), isNotEmpty, reason: 'ja.$key 为空');
      }
    });

    test('en / zh / ja 所有占位符名称完全匹配', () {
      final keys = en.keys.where((k) => !k.startsWith('@'));
      for (final key in keys) {
        final pEn = _extractPlaceholders(en[key] as String);
        final pZh = _extractPlaceholders(zh[key] as String);
        final pJa = _extractPlaceholders(ja[key] as String);
        expect(pZh, equals(pEn), reason: 'zh.$key 占位符与 en 不一致');
        expect(pJa, equals(pEn), reason: 'ja.$key 占位符与 en 不一致');
      }
    });
  });

  group('Engine 模型三语全覆盖校验', () {
    test('全部 87 款 PhotoFilterType 在 en/ja 下均有本地化名称与简介', () {
      for (final filter in PhotoFilterType.values) {
        final enPair = EngineL10n.filterById(filter.name, 'en');
        final jaPair = EngineL10n.filterById(filter.name, 'ja');
        expect(enPair, isNotNull, reason: '滤镜 ${filter.name} 缺少英文翻译');
        expect(jaPair, isNotNull, reason: '滤镜 ${filter.name} 缺少日文翻译');
        expect(enPair!.label.trim(), isNotEmpty);
        expect(jaPair!.label.trim(), isNotEmpty);
      }
    });

    test('全部内置调色预设、水印模板与拼图模板在 en/ja 下均已翻译', () {
      for (final p in kBuiltinGradePresets) {
        expect(EngineL10n.tr(p.name, 'en'), isNot(equals(p.name)),
            reason: '预设 ${p.id} 名称未翻译为英文');
        expect(EngineL10n.tr(p.description, 'en'),
            isNot(equals(p.description)),
            reason: '预设 ${p.id} 简介未翻译为英文');
      }
      for (final t in WatermarkTemplate.values) {
        expect(EngineL10n.tr(t.label, 'en'), isNot(equals(t.label)),
            reason: '水印模板 ${t.id} 未翻译为英文');
        expect(EngineL10n.tr(t.label, 'ja'), isNot(equals(t.label)),
            reason: '水印模板 ${t.id} 未翻译为日文');
      }
      for (final c in CollageTemplate.values) {
        expect(EngineL10n.tr(c.label, 'en'), isNotEmpty,
            reason: '拼图模板 ${c.id} 英文为空');
      }
    });
  });
}
