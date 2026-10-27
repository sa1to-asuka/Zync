import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../design/design.dart';

/// 顶部专业相机状态指示栏 (Camera StatusBar)
class CameraStatusBar extends StatelessWidget {
  final CameraDriver driver;
  final int fps;

  const CameraStatusBar({
    super.key,
    required this.driver,
    this.fps = 0,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final isConnected = driver.isConnected;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.lg,
        vertical: ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(
          bottom: BorderSide(color: zc.outline, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? zc.success : zc.danger,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? zc.success : zc.danger).withAlpha(90),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: ZSpace.sm),
          Text(
            isConnected ? driver.cameraModel : l10n.statusCameraDisconnected,
            style: zt.title.copyWith(fontSize: 13),
          ),
          const Spacer(),
          if (isConnected) ...[
            if (fps > 0) ...[
              ZTag(
                text: '$fps FPS',
                color: zc.accent,
                compact: true,
              ),
              const SizedBox(width: ZSpace.sm),
            ],
            Icon(
              Icons.sd_card_outlined,
              size: 14,
              color: zc.textSecondary,
            ),
            const SizedBox(width: ZSpace.xs),
            Text(
              driver.isSingleSlotCamera ? l10n.statusSdCard : 'SLOT 1',
              style: zt.numericSmall,
            ),
            const SizedBox(width: ZSpace.md),
            Icon(
              Icons.battery_5_bar,
              size: 16,
              color: zc.success,
            ),
            Text(
              '${driver.batteryLevel}%',
              style: zt.numericSmall,
            ),
          ] else ...[
            Text(
              l10n.statusTapToConnect,
              style: zt.bodySmall.copyWith(
                color: zc.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
