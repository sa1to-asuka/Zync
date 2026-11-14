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
  static const bool defaultShootAndTransferEnabled = false;
  static const bool defaultAutoReconnectEnabled = true;
  static const String defaultExportFolder = 'Zync';
  static const List<String> defaultRecentExportFolders = <String>[
    'Zync',
    'Zync/星空',
    'Zync/包围曝光',
    'Zync/焦点堆叠',
  ];
  static const bool defaultResumeTransfersAfterReconnect = true;
  static const bool defaultPowerProtectionEnabled = true;
  static const int defaultPowerThreshold = 15;
  static const AppThemeMode defaultThemeMode = AppThemeMode.system;
  static const AppLanguage defaultLanguage = AppLanguage.system;
  static const bool defaultOnboardingCompleted = false;
  static const bool defaultConfirmDelete = true;
  static const String defaultGalleryFilter = 'unviewed';

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

  // 实时取景默认值
  static const int defaultLiveViewFpsCap = 30;
  static const bool defaultLiveViewAutoStart = true;
  static const bool defaultLiveViewShowFps = true;
  static const bool defaultLiveViewKeepScreenOn = true;
  static const int defaultLiveViewGridMode = 1;
  static const bool defaultLiveViewGuideLines = false;
  static const bool defaultLiveViewFocusPeaking = false;
  static const int defaultLiveViewPeakingColor = 0xFFFF1744;
  static const int defaultLiveViewPeakingThreshold = 400;
  static const bool defaultLiveViewZebra = false;
  static const int defaultLiveViewZebraThreshold = 235;
  static const bool defaultLiveViewHistogram = false;
  static const bool defaultLiveViewAfDrive = true;
  static const int defaultLiveViewMfStep = 32;
  static const int defaultIntervalSeconds = 5;
  static const int defaultIntervalCount = 10;

  static const List<int> liveViewFpsOptions = [10, 15, 20, 30];
  static const List<int> liveViewPeakingThresholdOptions = [340, 400, 460];
  static const List<int> liveViewPeakingColorOptions = [
    0xFFFF1744,
    0xFFFFEA00,
    0xFF2979FF,
    0xFFFFFFFF,
  ];
  static const Object liveViewUnset = Object();

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
  bool shootAndTransferEnabled = defaultShootAndTransferEnabled;
  bool autoReconnectEnabled = defaultAutoReconnectEnabled;
  String exportFolder = defaultExportFolder;
  List<String> recentExportFolders =
      List<String>.of(defaultRecentExportFolders);
  bool resumeTransfersAfterReconnect = defaultResumeTransfersAfterReconnect;
  bool powerProtectionEnabled = defaultPowerProtectionEnabled;
  int powerThreshold = defaultPowerThreshold;
  AppThemeMode themeMode = defaultThemeMode;
  AppLanguage language = defaultLanguage;
  bool onboardingCompleted = defaultOnboardingCompleted;
  bool confirmDelete = defaultConfirmDelete;
  int exportQuality = defaultExportQuality;
  String ptpClientGuid = '';
  String galleryFilter = defaultGalleryFilter;

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

  // 实时取景
  int liveViewFpsCap = defaultLiveViewFpsCap;
  bool liveViewAutoStart = defaultLiveViewAutoStart;
  bool liveViewShowFps = defaultLiveViewShowFps;
  bool liveViewKeepScreenOn = defaultLiveViewKeepScreenOn;
  int liveViewGridMode = defaultLiveViewGridMode;
  bool liveViewGuideLines = defaultLiveViewGuideLines;
  bool liveViewFocusPeaking = defaultLiveViewFocusPeaking;
  int liveViewPeakingColor = defaultLiveViewPeakingColor;
  int liveViewPeakingThreshold = defaultLiveViewPeakingThreshold;
  bool liveViewZebra = defaultLiveViewZebra;
  int liveViewZebraThreshold = defaultLiveViewZebraThreshold;
  bool liveViewHistogram = defaultLiveViewHistogram;
  bool liveViewAfDrive = defaultLiveViewAfDrive;
  int liveViewMfStep = defaultLiveViewMfStep;
  int intervalDefaultSeconds = defaultIntervalSeconds;
  int intervalDefaultCount = defaultIntervalCount;

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
      shootAndTransferEnabled = _readBool(
          m, 'shootAndTransferEnabled', defaultShootAndTransferEnabled);
      autoReconnectEnabled = _readBool(
          m, 'autoReconnectEnabled', defaultAutoReconnectEnabled);
      final folder = m['exportFolder'];
      if (folder is String && folder.trim().isNotEmpty) {
        exportFolder = normalizeExportFolder(folder);
      }
      final recents = m['recentExportFolders'];
      if (recents is List) {
        final parsed = recents
            .whereType<String>()
            .map(normalizeExportFolder)
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList();
        if (parsed.isNotEmpty) recentExportFolders = parsed;
      }
      resumeTransfersAfterReconnect = _readBool(m,
          'resumeTransfersAfterReconnect', defaultResumeTransfersAfterReconnect);
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
      liveViewFpsCap = _normalizeChoice(_readInt(m, 'liveViewFpsCap',
          defaultLiveViewFpsCap), liveViewFpsOptions, defaultLiveViewFpsCap);
      liveViewAutoStart =
          _readBool(m, 'liveViewAutoStart', defaultLiveViewAutoStart);
      liveViewShowFps = _readBool(m, 'liveViewShowFps', defaultLiveViewShowFps);
      liveViewKeepScreenOn =
          _readBool(m, 'liveViewKeepScreenOn', defaultLiveViewKeepScreenOn);
      liveViewGridMode = _readInt(m, 'liveViewGridMode', defaultLiveViewGridMode)
          .clamp(0, 2);
      liveViewGuideLines =
          _readBool(m, 'liveViewGuideLines', defaultLiveViewGuideLines);
      liveViewFocusPeaking =
          _readBool(m, 'liveViewFocusPeaking', defaultLiveViewFocusPeaking);
      liveViewPeakingColor = _normalizeColor(
          _readInt(m, 'liveViewPeakingColor', defaultLiveViewPeakingColor));
      liveViewPeakingThreshold = _normalizeChoice(
          _readInt(m, 'liveViewPeakingThreshold',
              defaultLiveViewPeakingThreshold),
          liveViewPeakingThresholdOptions,
          defaultLiveViewPeakingThreshold);
      liveViewZebra = _readBool(m, 'liveViewZebra', defaultLiveViewZebra);
      liveViewZebraThreshold = _readInt(m, 'liveViewZebraThreshold',
              defaultLiveViewZebraThreshold)
          .clamp(200, 250);
      liveViewHistogram =
          _readBool(m, 'liveViewHistogram', defaultLiveViewHistogram);
      liveViewAfDrive = _readBool(m, 'liveViewAfDrive', defaultLiveViewAfDrive);
      liveViewMfStep =
          _readInt(m, 'liveViewMfStep', defaultLiveViewMfStep).clamp(1, 32767);
      intervalDefaultSeconds = _readInt(
              m, 'intervalDefaultSeconds', defaultIntervalSeconds)
          .clamp(2, 86400);
      intervalDefaultCount = _readInt(
              m, 'intervalDefaultCount', defaultIntervalCount)
          .clamp(1, 9999);
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
      galleryFilter =
          _readString(m, 'galleryFilter', defaultGalleryFilter);
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
        'shootAndTransferEnabled': shootAndTransferEnabled,
        'autoReconnectEnabled': autoReconnectEnabled,
        'exportFolder': exportFolder,
        'recentExportFolders': recentExportFolders,
        'resumeTransfersAfterReconnect': resumeTransfersAfterReconnect,
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
        'galleryFilter': galleryFilter,
        'liveViewFpsCap': liveViewFpsCap,
        'liveViewAutoStart': liveViewAutoStart,
        'liveViewShowFps': liveViewShowFps,
        'liveViewKeepScreenOn': liveViewKeepScreenOn,
        'liveViewGridMode': liveViewGridMode,
        'liveViewGuideLines': liveViewGuideLines,
        'liveViewFocusPeaking': liveViewFocusPeaking,
        'liveViewPeakingColor': liveViewPeakingColor,
        'liveViewPeakingThreshold': liveViewPeakingThreshold,
        'liveViewZebra': liveViewZebra,
        'liveViewZebraThreshold': liveViewZebraThreshold,
        'liveViewHistogram': liveViewHistogram,
        'liveViewAfDrive': liveViewAfDrive,
        'liveViewMfStep': liveViewMfStep,
        'intervalDefaultSeconds': intervalDefaultSeconds,
        'intervalDefaultCount': intervalDefaultCount,
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

  void setShootAndTransferEnabled(bool value) {
    if (value == shootAndTransferEnabled) return;
    shootAndTransferEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  /// 把用户输入的目录收敛成 `DCIM/` 下的安全相对路径。
  static String normalizeExportFolder(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '.' && e != '..')
        .map((e) => e.replaceAll(RegExp(r'[\\:*?"<>|]'), '_'))
        .take(3)
        .toList();
    if (cleaned.isEmpty) return defaultExportFolder;
    // 去掉可能重复的前缀 DCIM。
    if (cleaned.first.toUpperCase() == 'DCIM') cleaned.removeAt(0);
    if (cleaned.isEmpty) return defaultExportFolder;
    return cleaned.join('/');
  }

  void setExportFolder(String value) {
    final normalized = normalizeExportFolder(value);
    if (normalized == exportFolder) return;
    exportFolder = normalized;
    recentExportFolders = <String>[
      normalized,
      ...recentExportFolders.where((f) => f != normalized),
    ].take(8).toList();
    notifyListeners();
    _scheduleSave();
  }

  void setAutoReconnectEnabled(bool value) {
    if (value == autoReconnectEnabled) return;
    autoReconnectEnabled = value;
    notifyListeners();
    _scheduleSave();
  }

  void setResumeTransfersAfterReconnect(bool value) {
    if (value == resumeTransfersAfterReconnect) return;
    resumeTransfersAfterReconnect = value;
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

  void setGalleryFilter(String value) {
    final v = value.trim();
    if (v.isEmpty || v == galleryFilter) return;
    galleryFilter = v;
    notifyListeners();
    _scheduleSave();
  }

  /// 实时取景设置的批量更新入口（与 [updateWatermarkStyle] 同一套哨兵值写法）。
  void updateLiveView({
    Object? fpsCap = liveViewUnset,
    Object? autoStart = liveViewUnset,
    Object? showFps = liveViewUnset,
    Object? keepScreenOn = liveViewUnset,
    Object? gridMode = liveViewUnset,
    Object? guideLines = liveViewUnset,
    Object? focusPeaking = liveViewUnset,
    Object? peakingColor = liveViewUnset,
    Object? peakingThreshold = liveViewUnset,
    Object? zebra = liveViewUnset,
    Object? zebraThreshold = liveViewUnset,
    Object? histogram = liveViewUnset,
    Object? afDrive = liveViewUnset,
    Object? mfStep = liveViewUnset,
    Object? intervalSeconds = liveViewUnset,
    Object? intervalCount = liveViewUnset,
  }) {
    var changed = false;

    if (fpsCap != liveViewUnset) {
      final v = _normalizeChoice(fpsCap as int, liveViewFpsOptions,
          defaultLiveViewFpsCap);
      if (v != liveViewFpsCap) {
        liveViewFpsCap = v;
        changed = true;
      }
    }
    if (autoStart != liveViewUnset && autoStart != liveViewAutoStart) {
      liveViewAutoStart = autoStart as bool;
      changed = true;
    }
    if (showFps != liveViewUnset && showFps != liveViewShowFps) {
      liveViewShowFps = showFps as bool;
      changed = true;
    }
    if (keepScreenOn != liveViewUnset && keepScreenOn != liveViewKeepScreenOn) {
      liveViewKeepScreenOn = keepScreenOn as bool;
      changed = true;
    }
    if (guideLines != liveViewUnset && guideLines != liveViewGuideLines) {
      liveViewGuideLines = guideLines as bool;
      changed = true;
    }
    if (gridMode != liveViewUnset) {
      final v = (gridMode as int).clamp(0, 2);
      if (v != liveViewGridMode) {
        liveViewGridMode = v;
        changed = true;
      }
    }
    if (focusPeaking != liveViewUnset &&
        focusPeaking != liveViewFocusPeaking) {
      liveViewFocusPeaking = focusPeaking as bool;
      changed = true;
    }
    if (peakingColor != liveViewUnset) {
      final v = _normalizeColor(peakingColor as int);
      if (v != liveViewPeakingColor) {
        liveViewPeakingColor = v;
        changed = true;
      }
    }
    if (peakingThreshold != liveViewUnset) {
      final v = _normalizeChoice(peakingThreshold as int,
          liveViewPeakingThresholdOptions, defaultLiveViewPeakingThreshold);
      if (v != liveViewPeakingThreshold) {
        liveViewPeakingThreshold = v;
        changed = true;
      }
    }
    if (zebra != liveViewUnset && zebra != liveViewZebra) {
      liveViewZebra = zebra as bool;
      changed = true;
    }
    if (zebraThreshold != liveViewUnset) {
      final v = (zebraThreshold as int).clamp(200, 250);
      if (v != liveViewZebraThreshold) {
        liveViewZebraThreshold = v;
        changed = true;
      }
    }
    if (histogram != liveViewUnset && histogram != liveViewHistogram) {
      liveViewHistogram = histogram as bool;
      changed = true;
    }
    if (afDrive != liveViewUnset && afDrive != liveViewAfDrive) {
      liveViewAfDrive = afDrive as bool;
      changed = true;
    }
    if (mfStep != liveViewUnset) {
      final v = (mfStep as int).clamp(1, 32767);
      if (v != liveViewMfStep) {
        liveViewMfStep = v;
        changed = true;
      }
    }
    if (intervalSeconds != liveViewUnset) {
      final v = (intervalSeconds as int).clamp(2, 86400);
      if (v != intervalDefaultSeconds) {
        intervalDefaultSeconds = v;
        changed = true;
      }
    }
    if (intervalCount != liveViewUnset) {
      final v = (intervalCount as int).clamp(1, 9999);
      if (v != intervalDefaultCount) {
        intervalDefaultCount = v;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      _scheduleSave();
    }
  }

  /// 取景循环的最小帧间隔（由设置里的帧率上限换算）。
  Duration get liveViewFrameInterval =>
      Duration(milliseconds: (1000 / liveViewFpsCap).round());

  static int _normalizeChoice(int value, List<int> options, int fallback) =>
      options.contains(value) ? value : fallback;

  @visibleForTesting
  void resetForTest() {
    cameraIp = defaultCameraIp;
    cameraPort = defaultCameraPort;
    autoBindNetwork = defaultAutoBindNetwork;
    autoKeepAlive = defaultAutoKeepAlive;
    downloadRaw = defaultDownloadRaw;
    shootAndTransferEnabled = defaultShootAndTransferEnabled;
    autoReconnectEnabled = defaultAutoReconnectEnabled;
    exportFolder = defaultExportFolder;
    recentExportFolders = List<String>.of(defaultRecentExportFolders);
    resumeTransfersAfterReconnect = defaultResumeTransfersAfterReconnect;
    powerProtectionEnabled = defaultPowerProtectionEnabled;
    powerThreshold = defaultPowerThreshold;
    themeMode = defaultThemeMode;
    language = defaultLanguage;
    onboardingCompleted = defaultOnboardingCompleted;
    galleryFilter = defaultGalleryFilter;
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
    liveViewFpsCap = defaultLiveViewFpsCap;
    liveViewAutoStart = defaultLiveViewAutoStart;
    liveViewShowFps = defaultLiveViewShowFps;
    liveViewKeepScreenOn = defaultLiveViewKeepScreenOn;
    liveViewGridMode = defaultLiveViewGridMode;
    liveViewGuideLines = defaultLiveViewGuideLines;
    liveViewFocusPeaking = defaultLiveViewFocusPeaking;
    liveViewPeakingColor = defaultLiveViewPeakingColor;
    liveViewPeakingThreshold = defaultLiveViewPeakingThreshold;
    liveViewZebra = defaultLiveViewZebra;
    liveViewZebraThreshold = defaultLiveViewZebraThreshold;
    liveViewHistogram = defaultLiveViewHistogram;
    liveViewAfDrive = defaultLiveViewAfDrive;
    liveViewMfStep = defaultLiveViewMfStep;
    intervalDefaultSeconds = defaultIntervalSeconds;
    intervalDefaultCount = defaultIntervalCount;
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
