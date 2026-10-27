import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';

export '../../l10n/l10n.dart' show AppLanguage;

/// 轻量级应用设置（path_provider + JSON 持久化，不引入新依赖）。
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const String defaultCameraIp = '192.168.0.1';
  static const int defaultCameraPort = 15740;
  static const bool defaultAutoBindNetwork = true;
  static const bool defaultAutoKeepAlive = true;
  static const bool defaultDownloadRaw = false;
  static const bool defaultPowerProtectionEnabled = true;
  static const int defaultPowerThreshold = 15;
  static const AppThemeMode defaultThemeMode = AppThemeMode.system;
  static const AppLanguage defaultLanguage = AppLanguage.system;
  static const bool defaultOnboardingCompleted = false;
  static const bool defaultConfirmDelete = true;

  /// 水印导出 JPEG 质量：95 原图质量 / 92 标准 / 85 省空间
  static const int defaultExportQuality = 92;

  // 水印标量设置默认值（模板选择与 Logo 图片不持久化）。
  static const int defaultWatermarkAccentColorValue = 0xFFFFD100;
  static const double defaultWatermarkScale = 1.0;
  static const double defaultWatermarkLogoScale = 0.16;
  static const double defaultWatermarkLogoOpacity = 1.0;
  static const String defaultWatermarkFontChoice = 'default';
  static const String defaultWatermarkLogoCorner = 'bottomRight';
  static const String defaultWatermarkTextAlign = 'left';
  static const Object watermarkUnset = Object();

  static const List<int> powerThresholdOptions = [10, 15, 20, 30];
  static const List<int> exportQualityOptions = [95, 92, 85];

  /// 导出质量档位的多语言名称（设置页与水印工坊共用同一份文案）。
  static String exportQualityLabel(int quality, [AppLocalizations? l10n]) {
    final l = l10n ?? L10n.current;
    return switch (quality) {
      95 => l.exportQualityOriginal,
      85 => l.exportQualityCompact,
      _ => l.exportQualityStandard,
    };
  }

  String cameraIp = defaultCameraIp;
  int cameraPort = defaultCameraPort;
  bool autoBindNetwork = defaultAutoBindNetwork;
  bool autoKeepAlive = defaultAutoKeepAlive;
  bool downloadRaw = defaultDownloadRaw;
  bool powerProtectionEnabled = defaultPowerProtectionEnabled;
  int powerThreshold = defaultPowerThreshold;
  AppThemeMode themeMode = defaultThemeMode;
  AppLanguage language = defaultLanguage;
  bool onboardingCompleted = defaultOnboardingCompleted;
  bool confirmDelete = defaultConfirmDelete;
  int exportQuality = defaultExportQuality;
  String ptpClientGuid = '';

  int? watermarkCardColorValue;
  int? watermarkTextColorValue;
  int watermarkAccentColorValue = defaultWatermarkAccentColorValue;
  double watermarkTitleTextScale = defaultWatermarkScale;
  double watermarkMetaTextScale = defaultWatermarkScale;
  double watermarkCustomTextScale = defaultWatermarkScale;
  double watermarkLetterSpacingScale = defaultWatermarkScale;
  double watermarkLineSpacingScale = defaultWatermarkScale;
  int watermarkFontWeightIndex = 0;
  double watermarkBorderThicknessScale = defaultWatermarkScale;
  double watermarkSpacingScale = defaultWatermarkScale;
  double watermarkCornerRadiusFactor = defaultWatermarkScale;
  double watermarkOpacity = defaultWatermarkScale;
  String watermarkFontChoice = defaultWatermarkFontChoice;
  bool watermarkShowModel = true;
  bool watermarkShowLens = true;
  bool watermarkShowExposure = true;
  bool watermarkShowDate = true;
  bool watermarkShowDetails = true;
  bool watermarkShowBrandLogo = true;
  bool watermarkShowGps = true;
  String watermarkCustomLine1 = '';
  String watermarkCustomLine2 = '';
  double watermarkLogoScale = defaultWatermarkLogoScale;
  double watermarkLogoOpacity = defaultWatermarkLogoOpacity;
  String watermarkLogoCorner = defaultWatermarkLogoCorner;
  String watermarkTextAlign = defaultWatermarkTextAlign;
  bool tabletWatermarkViewPaged = false;
  bool tabletFilterViewPaged = false;

  File? _file;
  bool _suppressSave = false;

  Future<File> _prefFile() async {
    final cached = _file;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/zync_settings.json');
  }

  Future<void> load() async {
    _suppressSave = true;
    try {
      final file = await _prefFile();
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      final m = Map<String, dynamic>.from(raw);
      cameraIp = _readString(m, 'cameraIp', defaultCameraIp);
      cameraPort = _readInt(m, 'cameraPort', defaultCameraPort);
      autoBindNetwork = _readBool(m, 'autoBindNetwork', defaultAutoBindNetwork);
      autoKeepAlive = _readBool(m, 'autoKeepAlive', defaultAutoKeepAlive);
      downloadRaw = _readBool(m, 'downloadRaw', defaultDownloadRaw);
      powerProtectionEnabled =
          _readBool(m, 'powerProtectionEnabled', defaultPowerProtectionEnabled);
      powerThreshold = _normalizeThreshold(
          _readInt(m, 'powerThreshold', defaultPowerThreshold));
      themeMode = parseThemeMode(m['themeMode']);
      language = AppLanguage.parse(m['language']);
      onboardingCompleted =
          _readBool(m, 'onboardingCompleted', defaultOnboardingCompleted);
      confirmDelete = _readBool(m, 'confirmDelete', defaultConfirmDelete);
      exportQuality = _normalizeExportQuality(
          _readInt(m, 'exportQuality', defaultExportQuality));
      ptpClientGuid = _readString(m, 'ptpClientGuid', '');
      watermarkCardColorValue = _readNullableInt(m, 'watermarkCardColorValue');
      watermarkTextColorValue = _readNullableInt(m, 'watermarkTextColorValue');
      watermarkAccentColorValue = _normalizeColor(_readInt(
          m, 'watermarkAccentColorValue', defaultWatermarkAccentColorValue));
      watermarkTitleTextScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkTitleTextScale', defaultWatermarkScale),
          0.7,
          1.5);
      watermarkMetaTextScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkMetaTextScale', defaultWatermarkScale),
          0.7,
          1.5);
      watermarkCustomTextScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkCustomTextScale', defaultWatermarkScale),
          0.7,
          1.5);
      watermarkLetterSpacingScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkLetterSpacingScale', defaultWatermarkScale),
          0.5,
          1.5);
      watermarkLineSpacingScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkLineSpacingScale', defaultWatermarkScale),
          0.8,
          1.4);
      watermarkFontWeightIndex = _normalizeWatermarkIndex(
          _readInt(m, 'watermarkFontWeightIndex', 0), 5);
      watermarkBorderThicknessScale = _normalizeWatermarkRange(
          _readDouble(
              m, 'watermarkBorderThicknessScale', defaultWatermarkScale),
          0.5,
          2.0);
      watermarkSpacingScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkSpacingScale', defaultWatermarkScale),
          0.8,
          1.4);
      watermarkCornerRadiusFactor = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkCornerRadiusFactor', defaultWatermarkScale),
          0.0,
          2.0);
      watermarkOpacity = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkOpacity', defaultWatermarkScale), 0.5, 1.0);
      watermarkFontChoice =
          _readString(m, 'watermarkFontChoice', defaultWatermarkFontChoice);
      watermarkShowModel = _readBool(m, 'watermarkShowModel', true);
      watermarkShowLens = _readBool(m, 'watermarkShowLens', true);
      watermarkShowExposure = _readBool(m, 'watermarkShowExposure', true);
      watermarkShowDate = _readBool(m, 'watermarkShowDate', true);
      watermarkShowDetails = _readBool(m, 'watermarkShowDetails', true);
      watermarkShowBrandLogo = _readBool(m, 'watermarkShowBrandLogo', true);
      watermarkShowGps = _readBool(m, 'watermarkShowGps', true);
      watermarkCustomLine1 = _readString(m, 'watermarkCustomLine1', '');
      watermarkCustomLine2 = _readString(m, 'watermarkCustomLine2', '');
      watermarkLogoScale = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkLogoScale', defaultWatermarkLogoScale),
          0.05,
          0.40);
      watermarkLogoOpacity = _normalizeWatermarkRange(
          _readDouble(m, 'watermarkLogoOpacity', defaultWatermarkLogoOpacity),
          0.1,
          1.0);
      watermarkLogoCorner =
          _readString(m, 'watermarkLogoCorner', defaultWatermarkLogoCorner);
      watermarkTextAlign =
          _readString(m, 'watermarkTextAlign', defaultWatermarkTextAlign);
      tabletWatermarkViewPaged =
          _readBool(m, 'tabletWatermarkViewPaged', false);
      tabletFilterViewPaged =
          _readBool(m, 'tabletFilterViewPaged', false);
    } catch (_) {
      // 配置文件损坏：保持默认值
    } finally {
      _suppressSave = false;
    }
  }

  Future<void> save() async {
    try {
      final file = await _prefFile();
      await file.writeAsString(jsonEncode({
        'cameraIp': cameraIp,
        'cameraPort': cameraPort,
        'autoBindNetwork': autoBindNetwork,
        'autoKeepAlive': autoKeepAlive,
        'downloadRaw': downloadRaw,
        'powerProtectionEnabled': powerProtectionEnabled,
        'powerThreshold': powerThreshold,
        'themeMode': themeMode.name,
        'language': language.name,
        'onboardingCompleted': onboardingCompleted,
        'confirmDelete': confirmDelete,
        'exportQuality': exportQuality,
        'ptpClientGuid': ptpClientGuid,
        'watermarkCardColorValue': watermarkCardColorValue,
        'watermarkTextColorValue': watermarkTextColorValue,
        'watermarkAccentColorValue': watermarkAccentColorValue,
        'watermarkTitleTextScale': watermarkTitleTextScale,
        'watermarkMetaTextScale': watermarkMetaTextScale,
        'watermarkCustomTextScale': watermarkCustomTextScale,
        'watermarkLetterSpacingScale': watermarkLetterSpacingScale,
        'watermarkLineSpacingScale': watermarkLineSpacingScale,
        'watermarkFontWeightIndex': watermarkFontWeightIndex,
        'watermarkBorderThicknessScale': watermarkBorderThicknessScale,
        'watermarkSpacingScale': watermarkSpacingScale,
        'watermarkCornerRadiusFactor': watermarkCornerRadiusFactor,
        'watermarkOpacity': watermarkOpacity,
        'watermarkFontChoice': watermarkFontChoice,
        'watermarkShowModel': watermarkShowModel,
        'watermarkShowLens': watermarkShowLens,
        'watermarkShowExposure': watermarkShowExposure,
        'watermarkShowDate': watermarkShowDate,
        'watermarkShowDetails': watermarkShowDetails,
        'watermarkShowBrandLogo': watermarkShowBrandLogo,
        'watermarkShowGps': watermarkShowGps,
        'watermarkCustomLine1': watermarkCustomLine1,
        'watermarkCustomLine2': watermarkCustomLine2,
        'watermarkLogoScale': watermarkLogoScale,
        'watermarkLogoOpacity': watermarkLogoOpacity,
        'watermarkLogoCorner': watermarkLogoCorner,
        'watermarkTextAlign': watermarkTextAlign,
        'tabletWatermarkViewPaged': tabletWatermarkViewPaged,
        'tabletFilterViewPaged': tabletFilterViewPaged,
      }));
    } catch (_) {
      // 落盘失败不中断用户操作
    }
  }

  void _scheduleSave() {
    if (_suppressSave) return;
    save();
  }

  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  void setCameraIp(String value) {
    final v = value.trim();
    if (v.isEmpty || v == cameraIp) return;
    cameraIp = v;
    notifyListeners();
    _scheduleSave();
  }

  void setCameraPort(int value) {
    if (value <= 0 || value > 65535 || value == cameraPort) return;
    cameraPort = value;
    notifyListeners();
    _scheduleSave();
  }

  void setAutoBindNetwork(bool value) {
    if (value == autoBindNetwork) return;
    autoBindNetwork = value;
    notifyListeners();
    _scheduleSave();
  }

  void setAutoKeepAlive(bool value) {
    if (value == autoKeepAlive) return;
    autoKeepAlive = value;
    notifyListeners();
    _scheduleSave();
  }

  void setDownloadRaw(bool value) {
    if (value == downloadRaw) return;
    downloadRaw = value;
    notifyListeners();
    _scheduleSave();
  }

  void setPowerProtectionEnabled(bool value) {
    if (value == powerProtectionEnabled) return;
    powerProtectionEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  void setPowerThreshold(int value) {
    final v = _normalizeThreshold(value);
    if (v == powerThreshold) return;
    powerThreshold = v;
    notifyListeners();
    _scheduleSave();
  }

  void setExportQuality(int value) {
    final v = _normalizeExportQuality(value);
    if (v == exportQuality) return;
    exportQuality = v;
    notifyListeners();
    _scheduleSave();
  }

  void setConfirmDelete(bool value) {
    if (value == confirmDelete) return;
    confirmDelete = value;
    notifyListeners();
    _scheduleSave();
  }

  /// 水印工坊与拼图页共用的标量设置更新入口；未传入的字段保持原值。
  void updateWatermarkStyle({
    Object? cardColorValue = watermarkUnset,
    Object? textColorValue = watermarkUnset,
    Object? accentColorValue = watermarkUnset,
    Object? titleTextScale = watermarkUnset,
    Object? metaTextScale = watermarkUnset,
    Object? customTextScale = watermarkUnset,
    Object? letterSpacingScale = watermarkUnset,
    Object? lineSpacingScale = watermarkUnset,
    Object? fontWeightIndex = watermarkUnset,
    Object? borderThicknessScale = watermarkUnset,
    Object? spacingScale = watermarkUnset,
    Object? cornerRadiusFactor = watermarkUnset,
    Object? opacity = watermarkUnset,
    Object? fontChoice = watermarkUnset,
    Object? showModel = watermarkUnset,
    Object? showLens = watermarkUnset,
    Object? showExposure = watermarkUnset,
    Object? showDate = watermarkUnset,
    Object? showDetails = watermarkUnset,
    Object? showBrandLogo = watermarkUnset,
    Object? showGps = watermarkUnset,
    Object? customLine1 = watermarkUnset,
    Object? customLine2 = watermarkUnset,
    Object? logoScale = watermarkUnset,
    Object? logoOpacity = watermarkUnset,
    Object? logoCorner = watermarkUnset,
    Object? textAlign = watermarkUnset,
  }) {
    if (!identical(cardColorValue, watermarkUnset)) {
      watermarkCardColorValue = cardColorValue as int?;
    }
    if (!identical(textColorValue, watermarkUnset)) {
      watermarkTextColorValue = textColorValue as int?;
    }
    if (!identical(accentColorValue, watermarkUnset)) {
      watermarkAccentColorValue = _normalizeColor(accentColorValue as int);
    }
    if (!identical(titleTextScale, watermarkUnset)) {
      watermarkTitleTextScale = _normalizeWatermarkRange(
          (titleTextScale as num).toDouble(), 0.7, 1.5);
    }
    if (!identical(metaTextScale, watermarkUnset)) {
      watermarkMetaTextScale =
          _normalizeWatermarkRange((metaTextScale as num).toDouble(), 0.7, 1.5);
    }
    if (!identical(customTextScale, watermarkUnset)) {
      watermarkCustomTextScale = _normalizeWatermarkRange(
          (customTextScale as num).toDouble(), 0.7, 1.5);
    }
    if (!identical(letterSpacingScale, watermarkUnset)) {
      watermarkLetterSpacingScale = _normalizeWatermarkRange(
          (letterSpacingScale as num).toDouble(), 0.5, 1.5);
    }
    if (!identical(lineSpacingScale, watermarkUnset)) {
      watermarkLineSpacingScale = _normalizeWatermarkRange(
          (lineSpacingScale as num).toDouble(), 0.8, 1.4);
    }
    if (!identical(fontWeightIndex, watermarkUnset)) {
      watermarkFontWeightIndex =
          _normalizeWatermarkIndex(fontWeightIndex as int, 5);
    }
    if (!identical(borderThicknessScale, watermarkUnset)) {
      watermarkBorderThicknessScale = _normalizeWatermarkRange(
          (borderThicknessScale as num).toDouble(), 0.5, 2.0);
    }
    if (!identical(spacingScale, watermarkUnset)) {
      watermarkSpacingScale =
          _normalizeWatermarkRange((spacingScale as num).toDouble(), 0.8, 1.4);
    }
    if (!identical(cornerRadiusFactor, watermarkUnset)) {
      watermarkCornerRadiusFactor = _normalizeWatermarkRange(
          (cornerRadiusFactor as num).toDouble(), 0.0, 2.0);
    }
    if (!identical(opacity, watermarkUnset)) {
      watermarkOpacity =
          _normalizeWatermarkRange((opacity as num).toDouble(), 0.5, 1.0);
    }
    if (!identical(fontChoice, watermarkUnset)) {
      watermarkFontChoice = fontChoice as String;
    }
    if (!identical(showModel, watermarkUnset)) {
      watermarkShowModel = showModel as bool;
    }
    if (!identical(showLens, watermarkUnset)) {
      watermarkShowLens = showLens as bool;
    }
    if (!identical(showExposure, watermarkUnset)) {
      watermarkShowExposure = showExposure as bool;
    }
    if (!identical(showDate, watermarkUnset)) {
      watermarkShowDate = showDate as bool;
    }
    if (!identical(showDetails, watermarkUnset)) {
      watermarkShowDetails = showDetails as bool;
    }
    if (!identical(showBrandLogo, watermarkUnset)) {
      watermarkShowBrandLogo = showBrandLogo as bool;
    }
    if (!identical(showGps, watermarkUnset)) {
      watermarkShowGps = showGps as bool;
    }
    if (!identical(customLine1, watermarkUnset)) {
      watermarkCustomLine1 = customLine1 as String;
    }
    if (!identical(customLine2, watermarkUnset)) {
      watermarkCustomLine2 = customLine2 as String;
    }
    if (!identical(logoScale, watermarkUnset)) {
      watermarkLogoScale =
          _normalizeWatermarkRange((logoScale as num).toDouble(), 0.05, 0.40);
    }
    if (!identical(logoOpacity, watermarkUnset)) {
      watermarkLogoOpacity =
          _normalizeWatermarkRange((logoOpacity as num).toDouble(), 0.1, 1.0);
    }
    if (!identical(logoCorner, watermarkUnset)) {
      watermarkLogoCorner = logoCorner as String;
    }
    if (!identical(textAlign, watermarkUnset)) {
      watermarkTextAlign = textAlign as String;
    }
    notifyListeners();
    _scheduleSave();
  }

  void setTabletWatermarkViewPaged(bool value) {
    if (value == tabletWatermarkViewPaged) return;
    tabletWatermarkViewPaged = value;
    notifyListeners();
    _scheduleSave();
  }

  void setTabletFilterViewPaged(bool value) {
    if (value == tabletFilterViewPaged) return;
    tabletFilterViewPaged = value;
    notifyListeners();
    _scheduleSave();
  }

  /// 稳定 PTP/IP 客户端 GUID：相机用它记住已配对手机，避免每次连接都被当成新设备。
  Uint8List get ptpClientGuidBytes {
    final decoded = _decodeGuid(ptpClientGuid);
    if (decoded != null) return decoded;
    final bytes = Uint8List(16);
    final random = Random.secure();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    ptpClientGuid = _encodeGuid(bytes);
    _scheduleSave();
    return bytes;
  }

  void setThemeMode(AppThemeMode value) {
    if (value == themeMode) return;
    themeMode = value;
    notifyListeners();
    _scheduleSave();
  }

  void setLanguage(AppLanguage value) {
    if (value == language) return;
    language = value;
    if (value != AppLanguage.system) {
      L10n.syncWithLocale(Locale(value.code));
    }
    notifyListeners();
    _scheduleSave();
  }

  void setOnboardingCompleted(bool value) {
    if (value == onboardingCompleted) return;
    onboardingCompleted = value;
    notifyListeners();
    _scheduleSave();
  }

  @visibleForTesting
  void resetForTest() {
    cameraIp = defaultCameraIp;
    cameraPort = defaultCameraPort;
    autoBindNetwork = defaultAutoBindNetwork;
    autoKeepAlive = defaultAutoKeepAlive;
    downloadRaw = defaultDownloadRaw;
    powerProtectionEnabled = defaultPowerProtectionEnabled;
    powerThreshold = defaultPowerThreshold;
    themeMode = defaultThemeMode;
    language = defaultLanguage;
    onboardingCompleted = defaultOnboardingCompleted;
    L10n.syncWithLocale(const Locale('zh'));
    confirmDelete = defaultConfirmDelete;
    exportQuality = defaultExportQuality;
    ptpClientGuid = '';
    watermarkCardColorValue = null;
    watermarkTextColorValue = null;
    watermarkAccentColorValue = defaultWatermarkAccentColorValue;
    watermarkTitleTextScale = defaultWatermarkScale;
    watermarkMetaTextScale = defaultWatermarkScale;
    watermarkCustomTextScale = defaultWatermarkScale;
    watermarkLetterSpacingScale = defaultWatermarkScale;
    watermarkLineSpacingScale = defaultWatermarkScale;
    watermarkFontWeightIndex = 0;
    watermarkBorderThicknessScale = defaultWatermarkScale;
    watermarkSpacingScale = defaultWatermarkScale;
    watermarkCornerRadiusFactor = defaultWatermarkScale;
    watermarkOpacity = defaultWatermarkScale;
    watermarkFontChoice = defaultWatermarkFontChoice;
    watermarkShowModel = true;
    watermarkShowLens = true;
    watermarkShowExposure = true;
    watermarkShowDate = true;
    watermarkShowDetails = true;
    watermarkShowBrandLogo = true;
    watermarkShowGps = true;
    watermarkCustomLine1 = '';
    watermarkCustomLine2 = '';
    watermarkLogoScale = defaultWatermarkLogoScale;
    watermarkLogoOpacity = defaultWatermarkLogoOpacity;
    watermarkLogoCorner = defaultWatermarkLogoCorner;
    watermarkTextAlign = defaultWatermarkTextAlign;
    _file = null;
  }

  @visibleForTesting
  static AppThemeMode parseThemeMode(Object? value) =>
      AppThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => defaultThemeMode,
      );

  static int _normalizeThreshold(int v) =>
      powerThresholdOptions.contains(v) ? v : defaultPowerThreshold;

  static int _normalizeExportQuality(int v) =>
      exportQualityOptions.contains(v) ? v : defaultExportQuality;

  static String _readString(
      Map<String, dynamic> m, String key, String fallback) {
    final v = m[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return fallback;
  }

  static int _readInt(Map<String, dynamic> m, String key, int fallback) =>
      (m[key] as num?)?.toInt() ?? fallback;

  static int? _readNullableInt(Map<String, dynamic> m, String key) =>
      (m[key] as num?)?.toInt();

  static double _readDouble(
          Map<String, dynamic> m, String key, double fallback) =>
      (m[key] as num?)?.toDouble() ?? fallback;

  static bool _readBool(Map<String, dynamic> m, String key, bool fallback) =>
      m[key] as bool? ?? fallback;

  static int _normalizeColor(int value) => value & 0xFFFFFFFF;

  static int _normalizeWatermarkIndex(int value, int length) =>
      value >= 0 && value < length ? value : 0;

  static double _normalizeWatermarkRange(double value, double min, double max) {
    if (!value.isFinite) return defaultWatermarkScale;
    return value.clamp(min, max).toDouble();
  }

  static String _encodeGuid(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List? _decodeGuid(String value) {
    final hex = value.trim();
    if (hex.length != 32) return null;
    final out = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }
}

/// 外观模式：跟随系统、浅色、深色。
enum AppThemeMode { system, light, dark }
