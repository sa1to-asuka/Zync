part of '../gallery_screen.dart';

extension _GalleryModals on GalleryScreenState {
  /// 导出格式选择底部模态框
  Widget _buildExportFormatSheet(BuildContext ctx, int groupCount) {
    final zc = ctx.zc;
    final zt = ctx.zt;
    final l10n = ctx.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: zc.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.galleryExportFormatTitle, style: zt.titleMedium),
            const SizedBox(height: 6),
            Text(
              l10n.galleryExportFormatPrompt(groupCount),
              style: zt.bodySmall.copyWith(color: zc.textSecondary),
            ),
            const SizedBox(height: 18),

            // 选项 1: 导出全部 (RAW + JPEG)
            InkWell(
              onTap: () => Navigator.pop(ctx, 'both'),
              borderRadius: BorderRadius.circular(ZRadius.md),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: BorderRadius.circular(ZRadius.md),
                  border: Border.all(
                    color: zc.accent.withAlpha(120),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.collections, color: zc.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.galleryExportBothTitle,
                            style: zt.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.galleryExportBothSub,
                            style: zt.bodySmall.copyWith(
                              color: zc.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: zc.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 选项 2: 仅需 JPEG
            InkWell(
              onTap: () => Navigator.pop(ctx, 'jpeg_only'),
              borderRadius: BorderRadius.circular(ZRadius.md),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: BorderRadius.circular(ZRadius.md),
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image, color: zc.success, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.galleryExportJpegOnlyTitle,
                            style: zt.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.galleryExportJpegOnlySub,
                            style: zt.bodySmall.copyWith(
                              color: zc.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: zc.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 阻塞式传输进度对话框 (避免用户并发冲突操作)
  void _showBlockingTransferDialog(
    List<CameraFileItem> files, {
    void Function(int completedCount)? onCompleted,
  }) {
    widget.downloadManager.enqueueAll(files);
    _backgroundPrefetchHold = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (dialogCtx, setDialogState) {
              return AnimatedBuilder(
                animation: widget.downloadManager,
                builder: (context, _) {
                  final zc = context.zc;
                  final zt = context.zt;
                  final l10n = context.l10n;
                  final dm = widget.downloadManager;
                  final task = dm.currentTask;

                  final fileHandles = files.map((f) => f.handle).toSet();
                  final completedInBatch = dm.tasks
                      .where(
                        (t) =>
                            fileHandles.contains(t.fileItem.handle) &&
                            t.status == DownloadTaskStatus.completed,
                      )
                      .length;
                  final failedInBatch = dm.tasks
                      .where(
                        (t) =>
                            fileHandles.contains(t.fileItem.handle) &&
                            t.status == DownloadTaskStatus.failed,
                      )
                      .length;
                  final isAllDone =
                      (completedInBatch + failedInBatch) >= files.length;

                  if (isAllDone) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (Navigator.canPop(dialogCtx)) {
                        Navigator.pop(dialogCtx);
                        if (completedInBatch > 0) {
                          final completedNames = dm.tasks
                              .where(
                                (t) =>
                                    fileHandles.contains(t.fileItem.handle) &&
                                    t.status == DownloadTaskStatus.completed,
                              )
                              .map((t) => t.fileItem.fileName.split('.').first);
                          CameraViewedTracker.instance
                              .markAllViewed(completedNames);
                        }
                        if (onCompleted != null) onCompleted(completedInBatch);
                        if (this.context.mounted) {
                          showZToast(
                            this.context,
                            this.context.l10n.galleryExportBatchSuccessToast(
                                  completedInBatch,
                                ),
                            tone: ZStatusTone.success,
                          );
                        }
                      }
                    });
                  }

                  final batchProgress = files.isNotEmpty
                      ? (completedInBatch / files.length).clamp(0.0, 1.0)
                      : 0.0;
                  final currentTaskProgress = task?.progress ?? 0.0;

                  return AlertDialog(
                    backgroundColor: zc.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZRadius.lg),
                      side: BorderSide(color: zc.outline, width: 0.8),
                    ),
                    title: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(zc.accent),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.galleryExportingModalTitle,
                            style: zt.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.galleryExportingSocketNotice,
                          style: zt.bodySmall.copyWith(color: zc.textSecondary),
                        ),
                        const SizedBox(height: 16),

                        // 当前文件与进度
                        if (task != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task.fileItem.fileName,
                                  style: zt.labelLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(currentTaskProgress * 100).toStringAsFixed(0)}%',
                                style: zt.mono.copyWith(color: zc.accent),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(ZRadius.xs),
                            child: LinearProgressIndicator(
                              value: currentTaskProgress,
                              backgroundColor: zc.outline,
                              valueColor: AlwaysStoppedAnimation(zc.accent),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.galleryExportingSingleSize(
                              task.fileItem.sizeFormatted,
                            ),
                            style: zt.caption.copyWith(color: zc.textTertiary),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // 总体批次进度
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.galleryExportingBatchProgress(
                                completedInBatch + 1,
                                files.length,
                              ),
                              style: zt.bodySmall,
                            ),
                            Text(
                              '${(batchProgress * 100).toStringAsFixed(0)}%',
                              style: zt.mono.copyWith(color: zc.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ZRadius.xs),
                          child: LinearProgressIndicator(
                            value: batchProgress,
                            backgroundColor: zc.outline,
                            valueColor: AlwaysStoppedAnimation(zc.success),
                            minHeight: 3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.galleryExportingSavePath,
                          style: zt.caption.copyWith(color: zc.textTertiary),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          dm.cancelAll();
                          Navigator.pop(dialogCtx);
                        },
                        child: Text(
                          l10n.galleryCancelRemainingTasks,
                          style: zt.labelLarge.copyWith(color: zc.danger),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      _backgroundPrefetchHold = false;
    });
  }

  Widget _buildDeleteScopeSheet(BuildContext ctx, int groupCount) {
    final zc = ctx.zc;
    final zt = ctx.zt;
    final l10n = ctx.l10n;
    final options = <(_DeleteScope, IconData, String, String)>[
      (
        _DeleteScope.localOnly,
        Icons.phone_android,
        l10n.galleryDeleteLocalOnlyTitle,
        l10n.galleryDeleteLocalOnlySub,
      ),
      (
        _DeleteScope.localAndCamera,
        Icons.sd_card,
        l10n.galleryDeleteBothTitle,
        l10n.galleryDeleteBothSub,
      ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: zc.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.galleryDeleteGroupsTitle(groupCount),
              style: zt.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.galleryDeleteGroupsPrompt,
              style: zt.bodySmall.copyWith(color: zc.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final (scope, icon, title, subtitle) in options)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(ZRadius.md),
                  onTap: () => Navigator.pop(ctx, scope),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: zc.surfaceHigh,
                      borderRadius: BorderRadius.circular(ZRadius.md),
                      border: Border.all(color: zc.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          color: scope == _DeleteScope.localAndCamera
                              ? zc.danger
                              : zc.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: zt.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: zt.bodySmall.copyWith(
                                  color: zc.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: zc.textTertiary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmDialog(
    BuildContext ctx,
    int groupCount,
    _DeleteScope scope,
  ) {
    var dontAskAgain = false;
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final zc = context.zc;
        final zt = context.zt;
        final l10n = context.l10n;
        return AlertDialog(
          backgroundColor: zc.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadius.lg),
            side: BorderSide(color: zc.outline, width: 0.8),
          ),
          title: Text(l10n.galleryConfirmDeleteTitle, style: zt.titleMedium),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scope == _DeleteScope.localAndCamera
                    ? l10n.galleryConfirmDeleteBothBody(groupCount)
                    : l10n.galleryConfirmDeleteLocalBody(groupCount),
                style: zt.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.galleryIrreversibleHint,
                style: zt.bodySmall.copyWith(
                  color: zc.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setDialogState(() => dontAskAgain = !dontAskAgain),
                child: Row(
                  children: [
                    Checkbox(
                      value: dontAskAgain,
                      onChanged: (v) =>
                          setDialogState(() => dontAskAgain = v ?? false),
                    ),
                    Expanded(
                      child: Text(
                        l10n.galleryDontAskAgain,
                        style: zt.bodySmall.copyWith(color: zc.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.commonNo),
            ),
            TextButton(
              onPressed: () {
                if (dontAskAgain) AppSettings.instance.setConfirmDelete(false);
                Navigator.pop(context, true);
              },
              child: Text(
                l10n.commonYes,
                style: TextStyle(color: zc.danger),
              ),
            ),
          ],
        );
      },
    );
  }
}
