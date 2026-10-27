import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 首次启动 3 步欢迎引导（Q6）：
/// ① 选择语言（点击即时切换全界面语言）
/// ② 选择暗房外观（跟随系统 / 浅色 / 深色，实时预览）
/// ③ 直连尼康相机工作流简介（Wi-Fi / USB / 暗房工坊）
class OnboardingFlow extends StatefulWidget {
  final VoidCallback? onCompleted;

  const OnboardingFlow({
    super.key,
    this.onCompleted,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _totalSteps = 3;
  int _step = 0;
  bool _reverse = false;

  void _goToStep(int target) {
    if (target < 0 || target >= _totalSteps || target == _step) return;
    setState(() {
      _reverse = target < _step;
      _step = target;
    });
  }

  void _complete(AppSettings settings) {
    settings.setOnboardingCompleted(true);
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final isTwoPane = MediaQuery.sizeOf(context).width >= 760;
    final motionDuration = ZMotion.of(context, ZMotion.medium);

    final stepContent = PageTransitionSwitcher(
      duration: motionDuration,
      reverse: _reverse,
      transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
        if (motionDuration == Duration.zero) return child;
        return SharedAxisTransition(
          animation: primaryAnimation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          fillColor: ZSwatch.transparent,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<String>('onboarding_step_${_step}_${l10n.localeName}'),
        child: switch (_step) {
          0 => _LanguageStep(settings: settings),
          1 => _AppearanceStep(settings: settings),
          _ => const _WorkflowStep(),
        },
      ),
    );

    return Scaffold(
      backgroundColor: zc.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isTwoPane ? 920 : 560),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTwoPane ? ZSpace.xxl : ZSpace.xl,
                vertical: ZSpace.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶栏：品牌徽标 + 步骤计数 + 跳过按钮
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: ZRadius.brSm,
                          border: Border.all(color: zc.outline, width: 0.8),
                        ),
                        child: Image.asset(
                          'assets/icons/zync_logo.png',
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.camera_alt_outlined,
                            size: 20,
                            color: zc.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: ZSpace.sm),
                      Text(
                        'Zync',
                        style: zt.headline.copyWith(letterSpacing: 0.3),
                      ),
                      const SizedBox(width: ZSpace.sm),
                      ZTag(
                        text: l10n.onboardingStepOf(_step + 1, _totalSteps),
                      ),
                      const Spacer(),
                      if (_step < _totalSteps - 1)
                        ZButton(
                          key: const ValueKey<String>('onboarding_skip_btn'),
                          label: l10n.onboardingSkip,
                          variant: ZButtonVariant.ghost,
                          size: ZButtonSize.sm,
                          onTap: () => _complete(settings),
                        ),
                    ],
                  ),
                  const SizedBox(height: ZSpace.lg),
                  Expanded(
                    child: isTwoPane
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 5,
                                child: _StepHeaderPanel(step: _step),
                              ),
                              const SizedBox(width: ZSpace.xxl),
                              Expanded(
                                flex: 6,
                                child: SingleChildScrollView(child: stepContent),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StepHeaderPanel(step: _step),
                                const SizedBox(height: ZSpace.xl),
                                stepContent,
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: ZSpace.md),
                  // 底栏：步骤胶囊指示器 + 上一步 / 下一步
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < _totalSteps; i++)
                            AnimatedContainer(
                              duration: ZMotion.of(context, ZMotion.short),
                              curve: ZMotion.emphasized,
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _step ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _step
                                    ? zc.accent
                                    : zc.surfaceHighest,
                                borderRadius: ZRadius.brPill,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (_step > 0) ...[
                        ZButton(
                          key: const ValueKey<String>('onboarding_back_btn'),
                          label: l10n.onboardingBack,
                          variant: ZButtonVariant.outlined,
                          onTap: () => _goToStep(_step - 1),
                        ),
                        const SizedBox(width: ZSpace.sm),
                      ],
                      ZButton(
                        key: const ValueKey<String>('onboarding_next_btn'),
                        label: _step < _totalSteps - 1
                            ? l10n.onboardingNext
                            : l10n.onboardingStart,
                        icon: _step < _totalSteps - 1
                            ? null
                            : Icons.check_rounded,
                        trailingIcon: _step < _totalSteps - 1
                            ? Icons.arrow_forward_rounded
                            : null,
                        onTap: () {
                          if (_step < _totalSteps - 1) {
                            _goToStep(_step + 1);
                          } else {
                            _complete(settings);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeaderPanel extends StatelessWidget {
  final int step;

  const _StepHeaderPanel({required this.step});

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    final (IconData icon, String title, String subtitle) = switch (step) {
      0 => (
          Icons.translate_rounded,
          l10n.onboardingLangTitle,
          l10n.onboardingLangSubtitle,
        ),
      1 => (
          Icons.contrast_rounded,
          l10n.onboardingThemeTitle,
          l10n.onboardingThemeSubtitle,
        ),
      _ => (
          Icons.settings_input_antenna_rounded,
          l10n.onboardingConnTitle,
          l10n.onboardingConnSubtitle,
        ),
    };

    return AnimatedSwitcher(
      duration: ZMotion.of(context, ZMotion.short),
      child: Column(
        key: ValueKey<String>('header_${step}_${l10n.localeName}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: zc.accentContainer,
              borderRadius: ZRadius.brLg,
              border: Border.all(color: zc.accent.withAlpha(90), width: 0.8),
            ),
            child: Icon(icon, size: 24, color: zc.accent),
          ),
          const SizedBox(height: ZSpace.lg),
          Text(title, style: zt.display),
          const SizedBox(height: ZSpace.sm),
          Text(subtitle, style: zt.bodySmall),
        ],
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  final AppSettings settings;

  const _LanguageStep({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = <(AppLanguage, String, String, String)>[
      (AppLanguage.zh, '简体中文', l10n.langZhSub, 'ZH'),
      (AppLanguage.en, 'English', l10n.langEnSub, 'EN'),
      (AppLanguage.ja, '日本語', l10n.langJaSub, 'JA'),
      (AppLanguage.system, l10n.langSystem, l10n.langSystemDesc, 'AUTO'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (lang, title, sub, badge) in options) ...[
          _OptionCard(
            key: ValueKey<String>('onboarding_lang_${lang.name}'),
            title: title,
            subtitle: sub,
            badgeText: badge,
            selected: settings.language == lang,
            onTap: () => settings.setLanguage(lang),
          ),
          const SizedBox(height: ZSpace.sm),
        ],
      ],
    );
  }
}

class _AppearanceStep extends StatelessWidget {
  final AppSettings settings;

  const _AppearanceStep({required this.settings});

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    final modes = <(AppThemeMode, IconData, String, String)>[
      (
        AppThemeMode.system,
        Icons.brightness_auto_rounded,
        l10n.themeSystem,
        l10n.themeSystemSub,
      ),
      (
        AppThemeMode.dark,
        Icons.dark_mode_outlined,
        l10n.themeDark,
        l10n.themeDarkSub,
      ),
      (
        AppThemeMode.light,
        Icons.light_mode_outlined,
        l10n.themeLight,
        l10n.themeLightSub,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 实时暗房预览卡片
        ZCard(
          elevated: true,
          padding: const EdgeInsets.all(ZSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_outlined, size: 18, color: zc.accent),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Text(
                      l10n.onboardingThemePreviewTitle,
                      style: zt.label,
                    ),
                  ),
                  const ZTag(text: 'NEF 16-BIT'),
                ],
              ),
              const SizedBox(height: ZSpace.md),
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: ZSpace.md),
                decoration: BoxDecoration(
                  color: zc.canvas,
                  borderRadius: ZRadius.brMd,
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.landscape_outlined,
                      size: 28,
                      color: zc.accent,
                    ),
                    const SizedBox(width: ZSpace.md),
                    Expanded(
                      child: Text(
                        l10n.onboardingThemePreviewSub,
                        style: zt.numericSmall.copyWith(color: zc.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZSpace.md),
        for (final (mode, icon, title, sub) in modes) ...[
          _OptionCard(
            key: ValueKey<String>('onboarding_theme_${mode.name}'),
            icon: icon,
            title: title,
            subtitle: sub,
            selected: settings.themeMode == mode,
            onTap: () => settings.setThemeMode(mode),
          ),
          const SizedBox(height: ZSpace.sm),
        ],
      ],
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep();

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    final cards = <(IconData, String, String, String)>[
      (
        Icons.wifi_tethering_rounded,
        l10n.onboardingConnWifiTitle,
        l10n.onboardingConnWifiDesc,
        'PTP/IP',
      ),
      (
        Icons.usb_rounded,
        l10n.onboardingConnUsbTitle,
        l10n.onboardingConnUsbDesc,
        'USB OTG',
      ),
      (
        Icons.tune_rounded,
        l10n.onboardingConnStudioTitle,
        l10n.onboardingConnStudioDesc,
        'STUDIO',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (icon, title, desc, tag) in cards) ...[
          ZCard(
            padding: const EdgeInsets.all(ZSpace.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: zc.surfaceHigh,
                    borderRadius: ZRadius.brMd,
                    border: Border.all(color: zc.outline, width: 0.8),
                  ),
                  child: Icon(icon, size: 20, color: zc.accent),
                ),
                const SizedBox(width: ZSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title, style: zt.label),
                          ),
                          ZTag(text: tag),
                        ],
                      ),
                      const SizedBox(height: ZSpace.xs),
                      Text(desc, style: zt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpace.sm),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return ZCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.lg,
        vertical: ZSpace.md,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 22,
              color: selected ? zc.accent : zc.textSecondary,
            ),
            const SizedBox(width: ZSpace.md),
          ] else if (badgeText != null) ...[
            Container(
              width: 42,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? zc.accent : zc.surfaceHigh,
                borderRadius: ZRadius.brSm,
              ),
              child: Text(
                badgeText!,
                style: zt.caption.copyWith(
                  color: selected ? zc.onAccent : zc.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: ZSpace.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: zt.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: zc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: ZSpace.sm),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? zc.accent : zc.textTertiary,
          ),
        ],
      ),
    );
  }
}
