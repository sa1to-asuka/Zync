import 'package:flutter/material.dart';
import '../../engine/transfer/download_manager.dart';
import '../../l10n/engine_l10n.dart';
import '../../l10n/l10n.dart';
import '../../protocol/connection_recovery_controller.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';

/// 传输中心：查看与管理所有下载 / 边拍边传任务。
///
/// 与 AppBar 的进度徽标、后台前台服务通知同源（都读同一个 DownloadManager）。
class TransferCenterScreen extends StatelessWidget {
  const TransferCenterScreen({
    super.key,
    required this.manager,
    this.recovery,
  });

  final DownloadManager manager;

  /// 断线自动重连状态；为 null 时不显示恢复横幅。
  final ConnectionRecoveryController? recovery;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation:
          Listenable.merge([manager, if (recovery != null) recovery!]),
      builder: (context, _) {
        final tasks = manager.tasks;
        return Scaffold(
          backgroundColor: zc.bg,
          appBar: AppBar(title: Text(l10n.transferCenterTitle)),
          body: AdaptiveContent(
            child: tasks.isEmpty
                ? ZEmptyState(
                    icon: Icons.swap_vert_circle_outlined,
                    title: l10n.transferEmptyTitle,
                    subtitle: l10n.transferEmptySubtitle,
                  )
                : Column(
                    children: [
                      _buildReconnectBanner(context),
                      _buildSummary(context),
                      Divider(height: 1, color: zc.outlineVariant),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ZSpace.lg,
                            vertical: ZSpace.md,
                          ),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: ZSpace.sm),
                          itemBuilder: (context, index) =>
                              _buildTaskTile(context, tasks[index]),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// 断线重连横幅：正在恢复 / 已恢复 / 放弃。
  Widget _buildReconnectBanner(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final device = recovery;
    if (device == null) return const SizedBox.shrink();

    final lang = L10n.current.localeName;
    final waiting = manager.waitingReconnectCount;

    final String? text;
    Color color;
    IconData icon;

    switch (device.phase) {
      case RecoveryPhase.waitingForNetwork:
      case RecoveryPhase.probing:
      case RecoveryPhase.reconnecting:
      case RecoveryPhase.restoringSession:
        text = EngineL10n.recoveryBanner(
          lang,
          EngineL10n.recoveryPhase(lang, device.phase.name),
          device.attempt,
        );
        color = zc.warning;
        icon = Icons.sync_rounded;
        break;
      case RecoveryPhase.connected:
        text = EngineL10n.recoverySucceeded(lang);
        color = zc.accent;
        icon = Icons.check_circle_outline;
        break;
      case RecoveryPhase.exhausted:
        text = EngineL10n.recoveryExhausted(lang, device.lastError);
        color = zc.danger;
        icon = Icons.error_outline;
        break;
      case RecoveryPhase.idle:
        if (waiting == 0) return const SizedBox.shrink();
        text = EngineL10n.transferWaitingReconnect(lang);
        color = zc.warning;
        icon = Icons.cloud_off_outlined;
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZSpace.lg,
        ZSpace.md,
        ZSpace.lg,
        0,
      ),
      child: ZCard(
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.sm + 2,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Text(
                text,
                style: zt.caption.copyWith(color: color),
              ),
            ),
            if (waiting > 0)
              ZTag(
                text: '$waiting',
                color: color,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final total = manager.totalCount;
    final done = manager.completedCount;
    final failed = manager.failedCount;
    final active = manager.activeCount;
    final queued = manager.queuedCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZSpace.lg,
        ZSpace.md,
        ZSpace.lg,
        ZSpace.md,
      ),
      child: ZCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: ZSpace.sm,
              runSpacing: ZSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$done / $total',
                  style: zt.numeric.copyWith(fontSize: 16),
                ),
                if (active > 0)
                  ZTag(
                    text: l10n.transferActiveCount(active),
                    color: zc.accent,
                  ),
                if (queued > 0)
                  ZTag(
                    text: l10n.transferQueuedCount(queued),
                    color: zc.textSecondary,
                  ),
                if (failed > 0)
                  ZTag(
                    text: l10n.transferFailedCount(failed),
                    color: zc.danger,
                  ),
                if (manager.isManualPaused)
                  ZTag(
                    text: l10n.transferPausedTag,
                    color: zc.warning,
                  ),
              ],
            ),
            const SizedBox(height: ZSpace.md),
            ClipRRect(
              borderRadius: ZRadius.brXs,
              child: TweenAnimationBuilder<double>(
                duration: ZMotion.of(context, ZMotion.short),
                curve: ZMotion.standard,
                tween: Tween<double>(begin: 0, end: manager.progress),
                builder: (context, animatedValue, _) =>
                    LinearProgressIndicator(
                  value: animatedValue,
                  minHeight: 6,
                  backgroundColor: zc.surfaceHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(zc.accent),
                ),
              ),
            ),
            if (manager.powerPauseReason.isNotEmpty) ...[
              const SizedBox(height: ZSpace.sm),
              Text(
                manager.powerPauseReason,
                style: zt.caption.copyWith(color: zc.warning),
              ),
            ],
            const SizedBox(height: ZSpace.md),
            Wrap(
              spacing: ZSpace.sm,
              runSpacing: ZSpace.sm,
              children: [
                ZButton(
                  label: manager.isManualPaused
                      ? l10n.transferResumeAll
                      : l10n.transferPauseAll,
                  icon: manager.isManualPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
                  variant: ZButtonVariant.outlined,
                  size: ZButtonSize.sm,
                  onTap: manager.toggleManualPause,
                ),
                ZButton(
                  label: l10n.transferRetryFailed,
                  icon: Icons.refresh_rounded,
                  variant: ZButtonVariant.outlined,
                  size: ZButtonSize.sm,
                  onTap: failed > 0 ? manager.retryAllFailed : null,
                ),
                ZButton(
                  label: l10n.transferClearCompleted,
                  icon: Icons.cleaning_services_outlined,
                  variant: ZButtonVariant.outlined,
                  size: ZButtonSize.sm,
                  onTap: done > 0 ? manager.clearCompleted : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  Widget _buildTaskTile(BuildContext context, DownloadTask task) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final file = task.fileItem;
    final lang = L10n.current.localeName;

    final statusText = switch (task.status) {
      DownloadTaskStatus.queued => l10n.transferStatusQueued,
      DownloadTaskStatus.downloading =>
        l10n.transferStatusDownloadingPct((task.progress * 100).round()),
      DownloadTaskStatus.completed => l10n.transferStatusCompleted,
      DownloadTaskStatus.failed =>
        l10n.transferStatusFailedReason(task.error ?? l10n.commonUnknownError),
      DownloadTaskStatus.canceled => l10n.transferStatusCancelled,
      DownloadTaskStatus.pausedWaitingReconnect =>
        EngineL10n.transferWaitingReconnect(lang),
    };

    final badge = file.isRaw
        ? 'RAW'
        : file.isVideo
            ? 'VIDEO'
            : 'JPG';

    return ZCard(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm + 2,
      ),
      child: Row(
        children: [
          ZTag(text: badge, color: zc.accent),
          const SizedBox(width: ZSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zt.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatBytes(task.downloadedBytes)} / ${_formatBytes(task.totalBytes)} · $statusText',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: zt.numericSmall.copyWith(
                    color: task.status == DownloadTaskStatus.failed
                        ? zc.danger
                        : zc.textSecondary,
                  ),
                ),
                if (task.status == DownloadTaskStatus.downloading) ...[
                  const SizedBox(height: ZSpace.xs + 2),
                  ClipRRect(
                    borderRadius: ZRadius.brXs,
                    child: TweenAnimationBuilder<double>(
                      duration: ZMotion.of(context, ZMotion.short),
                      curve: ZMotion.standard,
                      tween: Tween<double>(begin: 0, end: task.progress),
                      builder: (context, animatedValue, _) =>
                          LinearProgressIndicator(
                        value: animatedValue,
                        minHeight: 4,
                        backgroundColor: zc.surfaceHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(zc.accent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: ZSpace.sm),
          _buildTaskActions(context, task),
        ],
      ),
    );
  }

  Widget _buildTaskActions(BuildContext context, DownloadTask task) {
    final zc = context.zc;
    final l10n = context.l10n;
    switch (task.status) {
      case DownloadTaskStatus.queued:
        return ZButton(
          label: l10n.commonCancel,
          variant: ZButtonVariant.ghost,
          size: ZButtonSize.sm,
          onTap: () => manager.cancelTask(task),
        );
      case DownloadTaskStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZButton(
              label: l10n.commonRetry,
              variant: ZButtonVariant.tonal,
              size: ZButtonSize.sm,
              onTap: () => manager.retryTask(task),
            ),
            const SizedBox(width: ZSpace.xs),
            ZIconButton(
              icon: Icons.close,
              tooltip: l10n.commonRemove,
              size: 32,
              iconSize: 16,
              onTap: () => manager.removeTask(task),
            ),
          ],
        );
      case DownloadTaskStatus.completed:
      case DownloadTaskStatus.canceled:
        return ZIconButton(
          icon: Icons.close,
          tooltip: l10n.commonRemove,
          size: 32,
          iconSize: 16,
          onTap: () => manager.removeTask(task),
        );
      case DownloadTaskStatus.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: zc.accent,
          ),
        );
      case DownloadTaskStatus.pausedWaitingReconnect:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ZButton(
              label: l10n.commonRetry,
              variant: ZButtonVariant.tonal,
              size: ZButtonSize.sm,
              onTap: () => manager.retryTask(task),
            ),
            const SizedBox(width: ZSpace.xs),
            ZIconButton(
              icon: Icons.close,
              tooltip: l10n.commonCancel,
              size: 32,
              iconSize: 16,
              onTap: () => manager.cancelTask(task),
            ),
          ],
        );
    }
  }
}
