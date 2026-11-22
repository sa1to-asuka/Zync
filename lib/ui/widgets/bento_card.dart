import 'package:flutter/material.dart';

import '../design/design.dart';

/// 主页 Bento 网格里的功能磁贴。
class ZBentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final double? progress;
  final String? badgeText;
  final VoidCallback onTap;

  /// 不可用状态：降低不透明度，但仍然可点（点了给提示比完全点不动更好）。
  final bool dimmed;

  /// 副标题默认允许两行，避免英文长句被截断。
  final int subtitleMaxLines;

  const ZBentoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.progress,
    this.badgeText,
    required this.onTap,
    this.dimmed = false,
    this.subtitleMaxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: ZCard(
        elevated: true,
        onTap: onTap,
        padding: const EdgeInsets.all(ZSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(35),
                    borderRadius: ZRadius.brSm,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                if (badgeText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: ZRadius.brPill,
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        color: zc.onAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: zt.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                  maxLines: subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: ZRadius.brPill,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: zc.outline,
                      valueColor: AlwaysStoppedAnimation(accentColor),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
