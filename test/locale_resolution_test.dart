import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/l10n/l10n.dart';

void main() {
  group('resolveZyncLocale 语言解析与回退策略 (Q11)', () {
    test('显式选择语言优先于系统语言', () {
      const sys = [Locale('zh', 'CN')];
      expect(resolveZyncLocale(AppLanguage.en, sys), const Locale('en'));
      expect(resolveZyncLocale(AppLanguage.ja, sys), const Locale('ja'));
      expect(resolveZyncLocale(AppLanguage.zh, sys), const Locale('zh'));
    });

    test('跟随系统时匹配 zh / ja / en', () {
      expect(
        resolveZyncLocale(AppLanguage.system, const [Locale('ja', 'JP')]),
        const Locale('ja'),
      );
      expect(
        resolveZyncLocale(AppLanguage.system, const [Locale('zh', 'CN')]),
        const Locale('zh'),
      );
      expect(
        resolveZyncLocale(AppLanguage.system, const [Locale('en', 'US')]),
        const Locale('en'),
      );
    });

    test('繁体中文系统 (zh_TW / zh_HK / zh_Hant) 映射到 zh', () {
      expect(
        resolveZyncLocale(AppLanguage.system, const [Locale('zh', 'TW')]),
        const Locale('zh'),
      );
      expect(
        resolveZyncLocale(AppLanguage.system, const [
          Locale.fromSubtags(
              languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK')
        ]),
        const Locale('zh'),
      );
    });

    test('系统语言不在支持列表时回退为英文 (en)', () {
      expect(
        resolveZyncLocale(
          AppLanguage.system,
          const [Locale('fr', 'FR'), Locale('de', 'DE')],
        ),
        const Locale('en'),
      );
      expect(
        resolveZyncLocale(AppLanguage.system, const []),
        const Locale('en'),
      );
    });
  });
}
