import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../design/design.dart';

/// 前后对比按钮。
///
/// 支持点按锁定对比（再点解除），也支持按住临时对比（松开恢复）。
/// 照片编辑器与视频编辑器共用，保证交互一致。
class CompareButton extends StatelessWidget {
  /// 是否处于对比状态。
  final bool comparing;

  /// 点按切换锁定状态。
  final VoidCallback onPressed;

  /// 按住进入对比。
  final VoidCallback onLongPressStart;

  /// 松开退出对比。
  final VoidCallback onLongPressEnd;

  /// 长按被系统打断时退出对比。
  final VoidCallback onLongPressCancel;

  const CompareButton({
    super.key,
    required this.comparing,
    required this.onPressed,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onLongPressCancel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const dark = ZyncPalette.dark;
    return Material(
      color: dark.bg.withValues(alpha: comparing ? 0.88 : 0.64),
      borderRadius: BorderRadius.circular(ZRadius.pill),
      child: GestureDetector(
        onTap: onPressed,
        onLongPressStart: (_) => onLongPressStart(),
        onLongPressEnd: (_) => onLongPressEnd(),
        onLongPressCancel: onLongPressCancel,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                comparing ? Icons.visibility : Icons.compare,
                size: 15,
                color: dark.textPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                comparing ? l10n.commonOriginal : l10n.commonCompare,
                style: TextStyle(fontSize: 11, color: dark.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
