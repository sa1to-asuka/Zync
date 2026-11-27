import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../engine/ai/ai_provider_config.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';
import '../screens/settings_screen.dart';
import 'ai_svg_icons.dart';

/// 4 步 AI API Key 配置教程内容（复用于独立教程弹窗、AI 设置页与首次启动引导第 4 步）。
class AiApiKeyGuideContent extends StatelessWidget {
  final bool showHeader;

  const AiApiKeyGuideContent({
    super.key,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    final steps = <(String numLabel, String title, String desc)>[
      ('1', l10n.aiGuideStep1Title, l10n.aiGuideStep1Desc),
      ('2', l10n.aiGuideStep2Title, l10n.aiGuideStep2Desc),
      ('3', l10n.aiGuideStep3Title, l10n.aiGuideStep3Desc),
      ('4', l10n.aiGuideStep4Title, l10n.aiGuideStep4Desc),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(
            l10n.aiGuideModalSubtitle,
            style: zt.bodySmall.copyWith(color: zc.textSecondary, height: 1.45),
          ),
          const SizedBox(height: ZSpace.md),
        ],
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: ZSpace.sm),
          Container(
            padding: const EdgeInsets.all(ZSpace.sm + 2),
            decoration: BoxDecoration(
              color: zc.surfaceHigh,
              borderRadius: ZRadius.brMd,
              border: Border.all(color: zc.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: zc.accentContainer,
                    borderRadius: ZRadius.brSm,
                    border: Border.all(color: zc.accent.withAlpha(110)),
                  ),
                  child: Text(
                    steps[i].$1,
                    style: zt.caption.copyWith(
                      color: zc.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: ZSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        steps[i].$2,
                        style: zt.bodySmall.copyWith(
                          color: zc.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$3,
                        style: zt.caption.copyWith(
                          color: zc.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 弹出响应式 API Key 配置指南（3.0.1 启动推送或点击「配置教程」打开）。
Future<void> showAiApiKeyTutorialModal(
  BuildContext context, {
  bool markPromptSeen = false,
}) async {
  if (markPromptSeen) {
    AppSettings.instance.setAiGuidePromptVersion(
      AppSettings.currentAiGuideVersion,
    );
  }
  await AiSettingsStore.instance.ensureInitialized();
  if (!context.mounted) return;

  final zc = context.zc;
  final isWide = context.zb.isTwoPane || MediaQuery.sizeOf(context).width >= 640;

  if (isWide) {
    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => Dialog(
        backgroundColor: zc.surfaceElevated,
        insetPadding: const EdgeInsets.all(ZSpace.xl),
        shape: RoundedRectangleBorder(
          borderRadius: ZRadius.brLg,
          side: BorderSide(color: zc.outline, width: 0.8),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: MediaQuery.sizeOf(dlgCtx).height * 0.86,
          ),
          child: const _AiApiKeyGuideModalBody(isDialog: true),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: zc.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
    ),
    builder: (_) => const _AiApiKeyGuideModalBody(isDialog: false),
  );
}

class _AiApiKeyGuideModalBody extends StatelessWidget {
  final bool isDialog;

  const _AiApiKeyGuideModalBody({required this.isDialog});

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDialog)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: ZSpace.md),
              decoration: BoxDecoration(
                color: zc.outline,
                borderRadius: ZRadius.brPill,
              ),
            ),
          ),
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: zc.accentContainer,
                borderRadius: ZRadius.brSm,
              ),
              child: AiSvgIcon(
                AiSvgIconKind.sparkleAperture,
                size: 16,
                color: zc.accent,
              ),
            ),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Text(
                l10n.aiGuideModalTitle,
                style: zt.titleMedium.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isDialog)
              IconButton(
                icon: Icon(Icons.close_rounded, color: zc.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: ZSpace.md),
        const Flexible(
          child: SingleChildScrollView(
            child: AiApiKeyGuideContent(showHeader: true),
          ),
        ),
        const SizedBox(height: ZSpace.md),
        ListenableBuilder(
          listenable: AiSettingsStore.instance,
          builder: (ctx, _) {
            final configured = AiSettingsStore.instance.hasConfiguredApiKey;
            return Row(
              children: [
                Expanded(
                  child: ZButton(
                    label: l10n.aiGuideLaterBtn,
                    variant: ZButtonVariant.outlined,
                    onTap: () => Navigator.of(ctx).pop(),
                  ),
                ),
                const SizedBox(width: ZSpace.sm),
                Expanded(
                  flex: 2,
                  child: ZButton(
                    label: configured
                        ? l10n.aiGuideConfiguredBadge
                        : l10n.aiGuideConfigureNowBtn,
                    icon: configured
                        ? Icons.check_circle_outline_rounded
                        : Icons.vpn_key_outlined,
                    variant: ZButtonVariant.filled,
                    onTap: () {
                      final nav = Navigator.of(ctx);
                      nav.pop();
                      nav.push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AiSettingsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );

    if (isDialog) {
      return Padding(
        padding: const EdgeInsets.all(ZSpace.lg),
        child: body,
      );
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ZSpace.lg,
            ZSpace.sm,
            ZSpace.lg,
            ZSpace.lg,
          ),
          child: body,
        ),
      ),
    );
  }
}
