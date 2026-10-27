import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/open_source_credits.dart';
import '../../core/settings/app_settings.dart';
import '../../core/utils/app_log_manager.dart';
import '../../engine/update/app_update_manager.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import '../onboarding/onboarding_flow.dart';
import '../widgets/adaptive_layout.dart';

enum _SettingsSectionId {
  appearance,
  language,
  camera,
  wireless,
  battery,
  logs,
  about,
}

/// 系统偏好与设置页面：窄屏采用一级分组列表 + 二级详情页，大屏平板自动切换为左右 Master-Detail 分栏。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  _SettingsSectionId _selectedSection = _SettingsSectionId.appearance;

  void _showIpEditDialog(BuildContext context) {
    final l10n = context.l10n;
    final zt = context.zt;
    final controller =
        TextEditingController(text: AppSettings.instance.cameraIp);
    showZDialog<void>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.settingsConfigIpTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsConfigIpSub, style: zt.bodySmall),
            const SizedBox(height: ZSpace.md),
            TextField(
              controller: controller,
              style: zt.numeric,
              decoration: InputDecoration(
                labelText: l10n.settingsIpAddressField,
              ),
            ),
          ],
        ),
        actions: [
          ZButton(
            label: l10n.commonCancel,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(ctx),
          ),
          ZButton(
            label: l10n.commonSave,
            onTap: () {
              final newIp = controller.text.trim();
              if (newIp.isNotEmpty) {
                AppSettings.instance.setCameraIp(newIp);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showPortEditDialog(BuildContext context) {
    final l10n = context.l10n;
    final zt = context.zt;
    final controller =
        TextEditingController(text: AppSettings.instance.cameraPort.toString());
    showZDialog<void>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.settingsConfigPortTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsConfigPortSub, style: zt.bodySmall),
            const SizedBox(height: ZSpace.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: zt.numeric,
              decoration: InputDecoration(
                labelText: l10n.settingsPortField,
              ),
            ),
          ],
        ),
        actions: [
          ZButton(
            label: l10n.commonCancel,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(ctx),
          ),
          ZButton(
            label: l10n.commonSave,
            onTap: () {
              final port = int.tryParse(controller.text.trim());
              if (port != null && port > 0) {
                AppSettings.instance.setCameraPort(port);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _openSection(_SettingsSectionId section, bool isTwoPane) {
    if (isTwoPane) {
      setState(() => _selectedSection = section);
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => _SettingsDetailScaffold(
          title: _sectionTitle(ctx, section),
          children: _buildSectionDetailChildren(ctx, section),
        ),
      ),
    );
  }

  void _replayOnboarding(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => OnboardingFlow(
          onCompleted: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  String _sectionTitle(BuildContext context, _SettingsSectionId section) {
    final l10n = context.l10n;
    return switch (section) {
      _SettingsSectionId.appearance => l10n.settingsAppearanceTitle,
      _SettingsSectionId.language => l10n.settingsLanguageTitle,
      _SettingsSectionId.camera => l10n.settingsCameraTitle,
      _SettingsSectionId.wireless => l10n.settingsWirelessTitle,
      _SettingsSectionId.battery => l10n.settingsBatteryTitle,
      _SettingsSectionId.logs => l10n.settingsLogsTitle,
      _SettingsSectionId.about => l10n.settingsAboutTitle,
    };
  }

  List<Widget> _buildSectionDetailChildren(
    BuildContext context,
    _SettingsSectionId section,
  ) {
    return switch (section) {
      _SettingsSectionId.appearance => [const _AppearanceDetailContent()],
      _SettingsSectionId.language => [const _LanguageDetailContent()],
      _SettingsSectionId.camera => [
          _CameraConnectionDetailContent(
            onEditIp: () => _showIpEditDialog(context),
            onEditPort: () => _showPortEditDialog(context),
          ),
        ],
      _SettingsSectionId.wireless => [const _WirelessDetailContent()],
      _SettingsSectionId.battery => [const _PowerProtectionDetailContent()],
      _SettingsSectionId.logs => [const _DiagnosticsDetailContent()],
      _SettingsSectionId.about => [
          _AboutDetailContent(
            onReplayOnboarding: () => _replayOnboarding(context),
          ),
        ],
    };
  }

  Widget _buildMasterList(
    BuildContext context,
    AppSettings settings, {
    required bool isTwoPane,
  }) {
    final l10n = context.l10n;
    final zc = context.zc;

    Color? activeIconColor(_SettingsSectionId id) =>
        isTwoPane && _selectedSection == id ? zc.accent : null;

    return ListView(
      children: [
        ZSection(
          title: l10n.settingsGroupPreferences,
          children: [
            ZTile(
              key: const ValueKey<String>('settings_tile_appearance'),
              leadingIcon: Icons.palette_outlined,
              leadingColor: activeIconColor(_SettingsSectionId.appearance),
              title: l10n.settingsAppearanceTitle,
              subtitle: l10n.settingsAppearanceSub,
              value: _themeLabel(context, settings.themeMode),
              isLink: true,
              onTap: () =>
                  _openSection(_SettingsSectionId.appearance, isTwoPane),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_language'),
              leadingIcon: Icons.translate_rounded,
              leadingColor: activeIconColor(_SettingsSectionId.language),
              title: l10n.settingsLanguageTitle,
              subtitle: l10n.settingsLanguageSub,
              value: _languageLabel(context, settings.language),
              isLink: true,
              onTap: () => _openSection(_SettingsSectionId.language, isTwoPane),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_camera'),
              leadingIcon: Icons.wifi_tethering_outlined,
              leadingColor: activeIconColor(_SettingsSectionId.camera),
              title: l10n.settingsCameraTitle,
              subtitle: l10n.settingsCameraSub,
              value: '${settings.cameraIp}:${settings.cameraPort}',
              isLink: true,
              onTap: () => _openSection(_SettingsSectionId.camera, isTwoPane),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_wireless'),
              leadingIcon: Icons.sync_alt_rounded,
              leadingColor: activeIconColor(_SettingsSectionId.wireless),
              title: l10n.settingsWirelessTitle,
              subtitle: l10n.settingsWirelessSub,
              value:
                  '${settings.autoKeepAlive ? l10n.settingsKeepAliveOnShort : l10n.settingsKeepAliveOffShort} · RAW ${settings.downloadRaw ? l10n.commonOn : l10n.commonOff}',
              isLink: true,
              onTap: () => _openSection(_SettingsSectionId.wireless, isTwoPane),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_battery'),
              leadingIcon: Icons.battery_saver_outlined,
              leadingColor: activeIconColor(_SettingsSectionId.battery),
              title: l10n.settingsBatteryTitle,
              subtitle: l10n.settingsBatterySub,
              value: settings.powerProtectionEnabled
                  ? l10n.settingsThresholdValue(settings.powerThreshold)
                  : l10n.commonDisabled,
              isLink: true,
              showDivider: false,
              onTap: () => _openSection(_SettingsSectionId.battery, isTwoPane),
            ),
          ],
        ),
        ZSection(
          title: l10n.settingsGroupSystem,
          children: [
            ZTile(
              key: const ValueKey<String>('settings_tile_logs'),
              leadingIcon: Icons.receipt_long_outlined,
              leadingColor: activeIconColor(_SettingsSectionId.logs),
              title: l10n.settingsLogsTitle,
              subtitle: l10n.settingsLogsSub,
              value: l10n.settingsLogsCountValue(
                  AppLogManager.instance.logs.length),
              isLink: true,
              onTap: () => _openSection(_SettingsSectionId.logs, isTwoPane),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_about'),
              leadingIcon: Icons.info_outline_rounded,
              leadingColor: activeIconColor(_SettingsSectionId.about),
              title: l10n.settingsAboutTitle,
              subtitle: l10n.settingsAboutSub,
              value: 'v${AppUpdateManager.currentVersion}',
              isLink: true,
              showDivider: false,
              onTap: () => _openSection(_SettingsSectionId.about, isTwoPane),
            ),
          ],
        ),
        const SizedBox(height: ZSpace.xxl),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isTwoPane = context.zb.isTwoPane;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final settings = AppSettings.instance;
        return Scaffold(
          backgroundColor: zc.bg,
          appBar: AppBar(title: Text(l10n.settingsTitle)),
          body: isTwoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 380,
                      child: _buildMasterList(
                        context,
                        settings,
                        isTwoPane: true,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 0.8,
                      color: zc.outline,
                    ),
                    Expanded(
                      child: AdaptiveContent(
                        child: ListView(
                          key: ValueKey<_SettingsSectionId>(_selectedSection),
                          children: [
                            ..._buildSectionDetailChildren(
                              context,
                              _selectedSection,
                            ),
                            const SizedBox(height: ZSpace.xxl),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : AdaptiveContent(
                  child: _buildMasterList(
                    context,
                    settings,
                    isTwoPane: false,
                  ),
                ),
        );
      },
    );
  }
}

const _themeModes = AppThemeMode.values;

String _themeLabel(BuildContext context, AppThemeMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };
}

String _themeDescription(BuildContext context, AppThemeMode mode) {
  final l10n = context.l10n;
  return switch (mode) {
    AppThemeMode.system => l10n.themeSystemSub,
    AppThemeMode.light => l10n.themeLightSub,
    AppThemeMode.dark => l10n.themeDarkSub,
  };
}

IconData _themeIcon(AppThemeMode mode) => switch (mode) {
      AppThemeMode.system => Icons.brightness_auto_outlined,
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
    };

String _languageLabel(BuildContext context, AppLanguage lang) {
  final l10n = context.l10n;
  return switch (lang) {
    AppLanguage.system => l10n.langSystem,
    AppLanguage.en => l10n.langEn,
    AppLanguage.zh => l10n.langZh,
    AppLanguage.ja => l10n.langJa,
  };
}

String _languageSubtitle(BuildContext context, AppLanguage lang) {
  final l10n = context.l10n;
  return switch (lang) {
    AppLanguage.system => l10n.langSystemDesc,
    AppLanguage.en => l10n.langEnSub,
    AppLanguage.zh => l10n.langZhSub,
    AppLanguage.ja => l10n.langJaSub,
  };
}

class _SettingsDetailScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsDetailScaffold({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(title: Text(title)),
      body: AdaptiveContent(
        child: ListView(
          children: [
            ...children,
            const SizedBox(height: ZSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _AppearanceDetailContent extends StatelessWidget {
  const _AppearanceDetailContent();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final zc = context.zc;
        final zt = context.zt;
        final l10n = context.l10n;
        final current = AppSettings.instance.themeMode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZSection(
              title: l10n.settingsAppearanceModeSection,
              children: [
                for (var i = 0; i < _themeModes.length; i++)
                  Builder(builder: (context) {
                    final mode = _themeModes[i];
                    final selected = mode == current;
                    return ZTile(
                      leadingIcon: _themeIcon(mode),
                      leadingColor: selected ? zc.accent : zc.textSecondary,
                      title: _themeLabel(context, mode),
                      subtitle: _themeDescription(context, mode),
                      showDivider: i < _themeModes.length - 1,
                      trailing: Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected ? zc.accent : zc.textTertiary,
                        size: 20,
                      ),
                      onTap: () => AppSettings.instance.setThemeMode(mode),
                    );
                  }),
              ],
            ),
            const SizedBox(height: ZSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpace.lg),
              child: Text(
                l10n.settingsColorPreviewSection,
                style: zt.overline,
              ),
            ),
            const SizedBox(height: ZSpace.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpace.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _PalettePreview(
                      title: l10n.themeLight,
                      palette: ZyncPalette.light,
                    ),
                  ),
                  const SizedBox(width: ZSpace.md),
                  Expanded(
                    child: _PalettePreview(
                      title: l10n.themeDark,
                      palette: ZyncPalette.dark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanguageDetailContent extends StatelessWidget {
  const _LanguageDetailContent();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final zc = context.zc;
        final l10n = context.l10n;
        final current = AppSettings.instance.language;
        const langs = AppLanguage.values;

        return ZSection(
          title: l10n.settingsLanguageTitle,
          children: [
            for (var i = 0; i < langs.length; i++)
              Builder(builder: (context) {
                final lang = langs[i];
                final selected = lang == current;
                return ZTile(
                  key: ValueKey<String>('settings_lang_${lang.name}'),
                  leadingIcon: Icons.language_rounded,
                  leadingColor: selected ? zc.accent : zc.textSecondary,
                  title: _languageLabel(context, lang),
                  subtitle: _languageSubtitle(context, lang),
                  showDivider: i < langs.length - 1,
                  trailing: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? zc.accent : zc.textTertiary,
                    size: 20,
                  ),
                  onTap: () => AppSettings.instance.setLanguage(lang),
                );
              }),
          ],
        );
      },
    );
  }
}

class _PalettePreview extends StatelessWidget {
  final String title;
  final ZyncPalette palette;

  const _PalettePreview({
    required this.title,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final zt = context.zt;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(ZSpace.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: ZRadius.brLg,
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: zt.title.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: ZSpace.sm),
          Row(
            children: [
              _Swatch(color: palette.bg, outlineColor: palette.outline),
              const SizedBox(width: ZSpace.xs + 2),
              _Swatch(color: palette.surface, outlineColor: palette.outline),
              const SizedBox(width: ZSpace.xs + 2),
              _Swatch(color: palette.accent, outlineColor: palette.outline),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          Text(
            l10n.settingsColorPreviewTileTitle,
            style: zt.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final Color outlineColor;

  const _Swatch({required this.color, required this.outlineColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 22,
        decoration: BoxDecoration(
          color: color,
          borderRadius: ZRadius.brXs,
          border: Border.all(color: outlineColor),
        ),
      ),
    );
  }
}

class _CameraConnectionDetailContent extends StatelessWidget {
  final VoidCallback onEditIp;
  final VoidCallback onEditPort;

  const _CameraConnectionDetailContent({
    required this.onEditIp,
    required this.onEditPort,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final settings = AppSettings.instance;
        return Column(
          children: [
            ZSection(
              title: l10n.settingsPtpNetworkSection,
              children: [
                ZTile(
                  title: l10n.settingsDefaultCameraIp,
                  value: settings.cameraIp,
                  isLink: true,
                  onTap: onEditIp,
                ),
                ZTile(
                  title: l10n.settingsPtpPortTile,
                  value: '${settings.cameraPort}',
                  isLink: true,
                  onTap: onEditPort,
                ),
                ZTile(
                  title: l10n.settingsRestoreDefaultIpTile,
                  value: '192.168.0.1:15740',
                  isLink: true,
                  showDivider: false,
                  onTap: () {
                    settings.setCameraIp('192.168.0.1');
                    settings.setCameraPort(15740);
                    showZToast(
                      context,
                      l10n.settingsRestoredDefaultIpToast,
                      tone: ZStatusTone.success,
                    );
                  },
                ),
              ],
            ),
            ZSection(
              title: l10n.settingsAndroidNetworkSection,
              children: [
                ZTile(
                  title: l10n.settingsAutoBindTitle,
                  subtitle: l10n.settingsAutoBindSub,
                  showDivider: false,
                  trailing: Switch(
                    value: settings.autoBindNetwork,
                    onChanged: settings.setAutoBindNetwork,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WirelessDetailContent extends StatelessWidget {
  const _WirelessDetailContent();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final settings = AppSettings.instance;
        return Column(
          children: [
            ZSection(
              title: l10n.settingsKeepAliveSection,
              children: [
                ZTile(
                  title: l10n.settingsKeepAliveToggleTitle,
                  trailing: Switch(
                    value: settings.autoKeepAlive,
                    onChanged: settings.setAutoKeepAlive,
                  ),
                ),
                ZTile(
                  title: l10n.settingsHeartbeatTitle,
                  value: l10n.settingsHeartbeatValue,
                  showDivider: false,
                ),
              ],
            ),
            ZSection(
              title: l10n.settingsShootTransferSection,
              children: [
                ZTile(
                  title: l10n.settingsDownloadRawTitle,
                  subtitle: l10n.settingsDownloadRawSub,
                  showDivider: false,
                  trailing: Switch(
                    value: settings.downloadRaw,
                    onChanged: settings.setDownloadRaw,
                  ),
                ),
              ],
            ),
            ZSection(
              title: l10n.settingsDeleteConfirmSection,
              children: [
                ZTile(
                  title: l10n.settingsConfirmDeleteTitle,
                  subtitle: l10n.settingsConfirmDeleteSub,
                  showDivider: false,
                  trailing: Switch(
                    value: settings.confirmDelete,
                    onChanged: settings.setConfirmDelete,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PowerProtectionDetailContent extends StatelessWidget {
  const _PowerProtectionDetailContent();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final settings = AppSettings.instance;
        return ZSection(
          title: l10n.settingsPowerProtectionSection,
          children: [
            ZTile(
              title: l10n.settingsPowerProtectionToggle,
              trailing: Switch(
                value: settings.powerProtectionEnabled,
                onChanged: settings.setPowerProtectionEnabled,
              ),
            ),
            ZTile(
              title: l10n.settingsPowerThresholdTile,
              value: '${settings.powerThreshold}%',
              isLink: true,
              onTap: () {
                const options = AppSettings.powerThresholdOptions;
                final index = options.indexOf(settings.powerThreshold);
                settings.setPowerThreshold(options[(index + 1) % options.length]);
              },
            ),
            ZTile(
              title: l10n.settingsHysteresisTitle,
              value: l10n.settingsHysteresisValue,
            ),
            ZTile(
              title: l10n.settingsActiveTransferRuleTitle,
              value: l10n.settingsActiveTransferRuleValue,
              showDivider: false,
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticsDetailContent extends StatelessWidget {
  const _DiagnosticsDetailContent();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        return ZSection(
          title: l10n.settingsLogsSection,
          children: [
            ZTile(
              title: l10n.settingsViewLogsTile,
              value: l10n.settingsLogsCountValue(
                  AppLogManager.instance.logs.length),
              isLink: true,
              onTap: () => _showLogsViewerSheet(context),
            ),
            ZTile(
              title: l10n.settingsClearLogsTile,
              value: l10n.commonClear,
              isLink: true,
              showDivider: false,
              onTap: () {
                AppLogManager.instance.clear();
                showZToast(context, l10n.settingsClearedLogsToast);
              },
            ),
          ],
        );
      },
    );
  }
}

class _AboutDetailContent extends StatelessWidget {
  final VoidCallback? onReplayOnboarding;

  const _AboutDetailContent({this.onReplayOnboarding});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        ZSection(
          title: l10n.settingsVersionSection,
          children: [
            ZTile(
              title: l10n.settingsAppVersionTile,
              value:
                  'v${AppUpdateManager.currentVersion} (Build ${AppUpdateManager.currentVersionCode})',
            ),
            ZTile(
              title: l10n.settingsCheckUpdateTile,
              value: l10n.settingsCheckUpdateValue,
              isLink: true,
              onTap: () => AppUpdateManager.checkManually(context),
            ),
            ZTile(
              key: const ValueKey<String>('settings_tile_onboarding'),
              title: l10n.settingsReplayOnboardingTitle,
              subtitle: l10n.settingsReplayOnboardingSub,
              isLink: true,
              showDivider: false,
              onTap: onReplayOnboarding,
            ),
          ],
        ),
        ZSection(
          title: l10n.settingsTechSection,
          children: [
            ZTile(
              title: l10n.settingsDriverArchTile,
              value: 'Wi-Fi PTP/IP + USB PTP (Dart/Kotlin)',
            ),
            ZTile(
              title: l10n.settingsUiSystemTile,
              value: l10n.settingsUiSystemValue,
              showDivider: false,
            ),
          ],
        ),
        ZSection(
          title: l10n.settingsProjectSection,
          children: [
            ZTile(
              title: l10n.settingsRepoUrlTile,
              value: 'github.com/sa1to-asuka/Zync',
              isLink: true,
              onTap: () => CameraNativeBridge.openUrlInBrowser(
                'https://github.com/sa1to-asuka/Zync',
              ),
            ),
            ZTile(
              title: l10n.settingsOpenSourceCreditsTile,
              subtitle: l10n.settingsOpenSourceCreditsSub,
              value: l10n.settingsCreditsCountValue(openSourceCredits.length),
              isLink: true,
              showDivider: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _OpenSourceCreditsDetail(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OpenSourceCreditsDetail extends StatelessWidget {
  const _OpenSourceCreditsDetail();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SettingsDetailScaffold(
      title: l10n.settingsOpenSourceCreditsTile,
      children: [
        ZSection(
          children: [
            ZTile(
              title: l10n.settingsLicenseDisclaimerTitle,
              subtitle: l10n.settingsLicenseDisclaimerBody,
              showDivider: false,
            ),
          ],
        ),
        ZSection(
          title: l10n.settingsCreditsCoreGroup,
          children: [
            for (var i = 0; i < openSourceProjectCredits.length; i++)
              _OpenSourceCreditTile(
                credit: openSourceProjectCredits[i],
                showDivider: i < openSourceProjectCredits.length - 1,
              ),
          ],
        ),
        ZSection(
          title: l10n.settingsCreditsRuntimeGroup,
          children: [
            for (var i = 0; i < openSourceRuntimeCredits.length; i++)
              _OpenSourceCreditTile(
                credit: openSourceRuntimeCredits[i],
                showDivider: i < openSourceRuntimeCredits.length - 1,
              ),
          ],
        ),
        ZSection(
          title: 'Zync',
          children: [
            ZTile(
              title: l10n.settingsAppLicenseTile,
              value: 'MIT License',
              showDivider: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _OpenSourceCreditTile extends StatelessWidget {
  final OpenSourceCredit credit;
  final bool showDivider;

  const _OpenSourceCreditTile({
    required this.credit,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    return InkWell(
      onTap: () async {
        final opened = await CameraNativeBridge.openUrlInBrowser(credit.url);
        if (!opened && context.mounted) {
          showZToast(
            context,
            l10n.settingsCannotOpenUrlToast,
            tone: ZStatusTone.danger,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.lg,
          vertical: ZSpace.md,
        ),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(
                    color: zc.outline,
                    width: 0.6,
                  ),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(credit.name, style: zt.title),
                ),
                const SizedBox(width: ZSpace.sm),
                ZTag(
                  text: credit.trLicense(context),
                  color: zc.accent,
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: ZSpace.xs),
            Text(
              credit.trDescription(context),
              style: zt.bodySmall,
            ),
            const SizedBox(height: ZSpace.xs),
            Text(
              credit.url,
              style: zt.caption.copyWith(color: zc.accent),
            ),
          ],
        ),
      ),
    );
  }
}

void _showLogsViewerSheet(BuildContext context) {
  final l10n = context.l10n;
  showZSheet<void>(
    context: context,
    title: l10n.settingsLogsViewerTitle,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final zc = sheetCtx.zc;
          final zt = sheetCtx.zt;
          final logs = AppLogManager.instance.logs;
          return SizedBox(
            height: MediaQuery.sizeOf(sheetCtx).height * 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZSpace.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ZIconButton(
                        icon: Icons.copy_rounded,
                        tooltip: l10n.settingsCopyAllLogsTooltip,
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(text: logs.join('\n')),
                          );
                          showZToast(
                            sheetCtx,
                            l10n.settingsCopiedLogsToast,
                            tone: ZStatusTone.success,
                          );
                        },
                      ),
                      const SizedBox(width: ZSpace.sm),
                      ZIconButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: l10n.settingsClearLogsTooltip,
                        color: zc.danger,
                        onTap: () {
                          AppLogManager.instance.clear();
                          setSheetState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ZSpace.sm),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(
                      ZSpace.lg,
                      0,
                      ZSpace.lg,
                      ZSpace.lg,
                    ),
                    padding: const EdgeInsets.all(ZSpace.md),
                    decoration: BoxDecoration(
                      color: zc.bg,
                      borderRadius: ZRadius.brMd,
                      border: Border.all(color: zc.outline, width: 0.8),
                    ),
                    child: logs.isEmpty
                        ? Center(
                            child: Text(
                              l10n.settingsLogsEmpty,
                              style: zt.bodySmall,
                            ),
                          )
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (c, i) {
                              final line = logs[i];
                              final color =
                                  line.contains('失败') || line.contains('异常')
                                      ? zc.danger
                                      : (line.contains('成功')
                                          ? zc.success
                                          : zc.textSecondary);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Text(
                                  line,
                                  style: zt.numericSmall.copyWith(
                                    color: color,
                                    height: 1.35,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
