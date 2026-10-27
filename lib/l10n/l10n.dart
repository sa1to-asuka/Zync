import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localizations.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';
import 'engine_l10n.dart';

export 'app_localizations.dart';
export 'engine_l10n.dart';

/// 应用语言偏好选项（Q11：English / 简体中文 / 日本語 + 跟随系统）。
enum AppLanguage {
  system('system', 'System'),
  en('en', 'English'),
  zh('zh', '简体中文'),
  ja('ja', '日本語');

  final String code;
  final String nativeName;
  const AppLanguage(this.code, this.nativeName);

  static AppLanguage parse(Object? value) {
    if (value is String) {
      for (final item in AppLanguage.values) {
        if (item.name == value || item.code == value) return item;
      }
    }
    return AppLanguage.system;
  }
}

/// 将用户语言偏好与系统语言列表解析为最终生效的 [Locale]（Q11）。
///
/// 规则：
/// - 显式指定 `en` / `zh` / `ja` 时直接返回对应语言；
/// - `system` 时按顺序匹配系统语言列表；繁体中文 (`zh_TW` / `zh_HK` / `zh_Hant`) 统一映射到 `zh`；
/// - 系统语言不在三者之内时回退 `en`（English）。
Locale resolveZyncLocale(
  AppLanguage preference,
  List<Locale> systemLocales,
) {
  switch (preference) {
    case AppLanguage.en:
      return const Locale('en');
    case AppLanguage.zh:
      return const Locale('zh');
    case AppLanguage.ja:
      return const Locale('ja');
    case AppLanguage.system:
      for (final locale in systemLocales) {
        final code = locale.languageCode.toLowerCase();
        if (code == 'zh') return const Locale('zh');
        if (code == 'ja') return const Locale('ja');
        if (code == 'en') return const Locale('en');
      }
      return const Locale('en');
  }
}

/// 全局本地化访问桥（供无 `BuildContext` 的 Engine 层或裸 `MaterialApp` 单测使用）。
abstract final class L10n {
  static final AppLocalizations _en = AppLocalizationsEn();
  static final AppLocalizations _zh = AppLocalizationsZh();
  static final AppLocalizations _ja = AppLocalizationsJa();

  /// 默认回退为中文实例，保证未包裹 `localizationsDelegates` 的存量单测零改动通过；
  /// 在 `ZyncApp` 或 `pumpZyncApp` 构建时会实时同步为当前激活语言。
  static AppLocalizations current = _zh;

  static AppLocalizations forLocale(Locale locale) =>
      switch (locale.languageCode.toLowerCase()) {
        'en' => _en,
        'ja' => _ja,
        'zh' => _zh,
        _ => _en,
      };

  static void syncWithLocale(Locale locale) {
    current = forLocale(locale);
  }

  /// 按当前激活语言翻译 Engine 词条（滤镜、预设、水印模板、拼图版式、致谢等）。
  static String tr(String zhText, [String? localeCode]) {
    final code = (localeCode ?? current.localeName).toLowerCase();
    return EngineL10n.tr(zhText, code);
  }
}

/// `BuildContext` 本地化快捷扩展。
extension ZyncL10nContext on BuildContext {
  AppLocalizations get l10n {
    final bound = Localizations.of<AppLocalizations>(this, AppLocalizations);
    if (bound != null) return bound;
    return L10n.current;
  }

  String tr(String zhText) => EngineL10n.tr(zhText, l10n.localeName);
}

/// 同步当前生效语言到 Android 原生层（前台通知、USB 服务提示等）。
abstract final class NativeLocaleBridge {
  static const MethodChannel _channel =
      MethodChannel('com.zync.app/native_camera');
  static String? _lastSyncedCode;

  static void sync(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    if (_lastSyncedCode == code) return;
    _lastSyncedCode = code;
    _channel.invokeMethod<void>('setAppLocale', {'locale': code}).catchError(
      (_) {},
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _lastSyncedCode = null;
  }
}
