import 'package:flutter/material.dart';

import '../../engine/ai/ai_vision_client.dart';
import '../../l10n/l10n.dart';
import '../design/design.dart';
import '../screens/settings_screen.dart';
import 'ai_svg_icons.dart';

/// 将 [AiErrorCategory] 或异常映射为清晰的用户可读排查建议（绝不静默伪造本地结果）。
String localizedAiErrorHint(AppLocalizations l10n, Object error) {
  if (error is AiHttpException) {
    return switch (error.category) {
      AiErrorCategory.network => l10n.aiErrNetworkHint,
      AiErrorCategory.auth => l10n.aiErrAuthHint,
      AiErrorCategory.endpointNotFound => l10n.aiErrEndpointHint,
      AiErrorCategory.unsupportedVision => l10n.aiErrVisionHint,
      AiErrorCategory.rateLimit => l10n.aiErrRateLimitHint,
      AiErrorCategory.parseError => l10n.aiErrParseHint,
      AiErrorCategory.serverError => l10n.aiErrServerHint,
    };
  }
  if (error is FormatException) return l10n.aiErrParseHint;
  return l10n.aiErrNetworkHint;
}

/// 统一 AI 异常 / 未配置状态诊断卡片：
/// 明确说明未连上真实 AI 的原因与排查建议，提供重试、前往设置和手动本地估算入口。
class AiDiagnosticCard extends StatelessWidget {
  final String title;
  final String hint;
  final String? technicalDetail;
  final VoidCallback? onRetry;
  final VoidCallback? onUseOffline;
  final VoidCallback? onShowGuide;
  final VoidCallback? onBeforeOpenSettings;
  final bool isError;

  const AiDiagnosticCard({
    super.key,
    required this.title,
    required this.hint,
    this.technicalDetail,
    this.onRetry,
    this.onUseOffline,
    this.onShowGuide,
    this.onBeforeOpenSettings,
    this.isError = true,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final tone = isError ? zc.danger : zc.warning;

    return Container(
      padding: const EdgeInsets.all(ZSpace.md),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brMd,
        border: Border.all(color: tone.withAlpha(140), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AiSvgIcon(
                isError
                    ? AiSvgIconKind.warningAlert
                    : AiSvgIconKind.sparkleAperture,
                size: 18,
                color: tone,
              ),
              const SizedBox(width: ZSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: zt.titleSmall.copyWith(color: zc.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpace.xs + 2),
          Text(
            hint,
            style: zt.bodySmall.copyWith(color: zc.textSecondary, height: 1.4),
          ),
          if (technicalDetail != null && technicalDetail!.trim().isNotEmpty) ...[
            const SizedBox(height: ZSpace.xs + 2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpace.sm,
                vertical: ZSpace.xs + 2,
              ),
              decoration: BoxDecoration(
                color: zc.surface,
                borderRadius: ZRadius.brSm,
                border: Border.all(color: zc.outlineVariant, width: 0.7),
              ),
              child: Text(
                technicalDetail!.trim(),
                style: zt.mono.copyWith(color: tone, fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: ZSpace.md),
          Wrap(
            spacing: ZSpace.sm,
            runSpacing: ZSpace.xs + 2,
            children: [
              if (onRetry != null)
                ZButton(
                  label: l10n.aiRetryBtn,
                  icon: Icons.refresh_rounded,
                  variant: ZButtonVariant.filled,
                  size: ZButtonSize.sm,
                  onTap: onRetry,
                ),
              ZButton(
                label: l10n.aiOpenSettingsBtn,
                icon: Icons.settings_outlined,
                variant: onRetry == null
                    ? ZButtonVariant.filled
                    : ZButtonVariant.tonal,
                size: ZButtonSize.sm,
                onTap: () {
                  onBeforeOpenSettings?.call();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AiSettingsPage(),
                    ),
                  );
                },
              ),
              if (onShowGuide != null)
                ZButton(
                  label: l10n.aiViewTutorialBtn,
                  icon: Icons.menu_book_outlined,
                  variant: ZButtonVariant.tonal,
                  size: ZButtonSize.sm,
                  onTap: onShowGuide,
                ),
              if (onUseOffline != null)
                ZButton(
                  label: l10n.aiUseOfflineBaselineBtn,
                  variant: ZButtonVariant.outlined,
                  size: ZButtonSize.sm,
                  onTap: onUseOffline,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
