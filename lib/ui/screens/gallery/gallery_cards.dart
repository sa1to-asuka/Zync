part of '../gallery_screen.dart';

extension _GalleryCards on GalleryScreenState {
  /// 传输入口（AppBar）：有未完成任务时显示数量徽标。
  Widget _buildTransferEntry() {
    return AnimatedBuilder(
      animation: widget.downloadManager,
      builder: (context, _) {
        final zc = context.zc;
        final dm = widget.downloadManager;
        final pending = dm.pendingCount;
        if (dm.totalCount == 0 || _isSelectionMode || _isLocalSelectionMode) {
          return const SizedBox.shrink();
        }
        return IconButton(
          tooltip: context.l10n.galleryTransferCenterTooltip,
          onPressed: _openTransferCenter,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                pending > 0
                    ? Icons.cloud_download_outlined
                    : Icons.swap_vert_circle_outlined,
              ),
              if (pending > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: zc.danger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pending',
                      style: TextStyle(
                        color: ZyncPalette.dark.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraInfoBar() {
    final zc = context.zc;
    final l10n = context.l10n;
    final cameraName = widget.driver.cameraModel.isNotEmpty
        ? widget.driver.cameraModel
        : 'Z 30';
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: BorderRadius.circular(ZRadius.lg),
        border: Border.all(color: zc.outline, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: BorderRadius.circular(ZRadius.md),
              border: Border.all(color: zc.outline, width: 0.8),
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              color: zc.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cameraName,
                  style: TextStyle(
                    color: zc.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${NetworkConfig.cameraIp}:${NetworkConfig.cameraPort} · PTP/IP',
                  style: TextStyle(color: zc.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              showZToast(context, l10n.galleryReadyFooterHint);
            },
            borderRadius: BorderRadius.circular(ZRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: zc.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.navSettings,
                    style: TextStyle(color: zc.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(BuildContext context, _GalleryFilter f) {
    final l10n = context.l10n;
    return switch (f) {
      _GalleryFilter.all => l10n.galleryFilterAll,
      _GalleryFilter.unviewed => l10n.galleryFilterNew,
      _GalleryFilter.unsynced => l10n.galleryFilterUnsynced,
      _GalleryFilter.synced => l10n.galleryFilterSynced,
      _GalleryFilter.jpg => 'JPG',
      _GalleryFilter.raw => 'RAW',
      _GalleryFilter.jpgRaw => 'JPG+RAW',
      _GalleryFilter.mp4 => 'MP4',
    };
  }

  Widget _buildFilterBar() {
    final zc = context.zc;
    const filters = _GalleryFilter.values;
    return Container(
      color: zc.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) {
                  final isSelected = _activeFilter == f;
                  final label = _filterLabel(context, f);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        _refresh(() {
                          _activeFilter = f;
                          AppSettings.instance.setGalleryFilter(f.name);
                        });
                      },
                      borderRadius: BorderRadius.circular(ZRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? zc.accentMuted : zc.surfaceHigh,
                          borderRadius: BorderRadius.circular(ZRadius.pill),
                          border: Border.all(
                            color: isSelected ? zc.accent : zc.outline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(Icons.check, size: 12, color: zc.accent),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color:
                                    isSelected ? zc.accent : zc.textSecondary,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: context.l10n.galleryMarkAllViewed,
            child: GestureDetector(
              onTap: () async {
                final l10n = context.l10n;
                await CameraViewedTracker.instance
                    .markAllViewed(_groups.map((g) => g.baseName));
                if (mounted) {
                  showZToast(
                    this.context,
                    l10n.galleryMarkAllViewedDone,
                    tone: ZStatusTone.success,
                  );
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                child: Icon(Icons.done_all, size: 16, color: zc.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _selectAll,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: zc.accent,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.select_all, size: 16, color: zc.onAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionDock() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zc = context.zc;
        final l10n = context.l10n;
        final wide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
        final selectedCount = _selectedBaseNames.length;
        final totalSizeText = _getSelectedTotalSize();
        final allSelected =
            _groups.isNotEmpty && selectedCount == _groups.length;

        final summary = Row(
          children: [
            if (_isSelectionMode)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(
                  allSelected
                      ? Icons.deselect_outlined
                      : Icons.select_all_rounded,
                  size: 18,
                  color: zc.accent,
                ),
                tooltip: allSelected
                    ? l10n.galleryActionDeselect
                    : l10n.galleryActionSelectAll,
                onPressed: _selectAll,
              ),
            Flexible(
              child: Text(
                l10n.gallerySelectionCameraSummary(
                  selectedCount,
                  totalSizeText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: zc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (selectedCount > 0) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: _handleDeleteSelected,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: zc.danger,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );

        final collageButton = (selectedCount > 0 || _isSelectionMode)
            ? OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: zc.accent,
                  side: BorderSide(color: zc.accent.withAlpha(120), width: 0.8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: selectedCount > 0 ? _handleCollageFromCamera : null,
                icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 14),
                label: Text(
                  l10n.galleryCollageButton,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            : null;

        final primaryButton = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: zc.accent,
            foregroundColor: zc.onAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: selectedCount > 0
              ? _handleExport
              : () {
                  if (!_isSelectionMode) {
                    _refresh(() => _isSelectionMode = true);
                  }
                  showZToast(context, l10n.galleryLongPressSelectHint);
                },
          child: Text(
            l10n.gallerySyncToPhoneButton,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        );

        final closeButton = (_isSelectionMode || selectedCount > 0)
            ? IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.close_rounded,
                    size: 18, color: zc.textSecondary),
                tooltip: l10n.commonCancel,
                onPressed: () {
                  _refresh(() {
                    _isSelectionMode = false;
                    _selectedBaseNames.clear();
                  });
                },
              )
            : null;

        final card = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: zc.surfaceHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: zc.outlineStrong, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: zc.scrim,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: wide
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: summary),
                        if (closeButton != null) closeButton,
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (collageButton != null) ...[
                      collageButton,
                      const SizedBox(height: 6),
                    ],
                    primaryButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: summary),
                    if (collageButton != null) ...[
                      const SizedBox(width: 6),
                      collageButton,
                    ],
                    const SizedBox(width: 6),
                    primaryButton,
                    if (closeButton != null) ...[
                      const SizedBox(width: 4),
                      closeButton,
                    ],
                  ],
                ),
        );

        if (!wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: card,
          );
        }
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: 260, child: card),
          ),
        );
      },
    );
  }

  /// 本地「已导出」多选操作岛：已选数量/大小 + 删除 + 拼图。
  Widget _buildLocalActionDock() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zc = context.zc;
        final l10n = context.l10n;
        final wide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
        final count = _selectedLocalFileNames.length;
        final allLocalCount = _historyManager.items.length;
        final allSelected = allLocalCount > 0 && count == allLocalCount;
        final totalBytes = _orderedSelectedLocalItems().fold<int>(
          0,
          (sum, e) => sum + e.size,
        );
        final String sizeText;
        if (totalBytes <= 0) {
          sizeText = l10n.commonUnknownSize;
        } else if (totalBytes >= 1024 * 1024 * 1024) {
          sizeText =
              '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
        } else if (totalBytes >= 1024 * 1024) {
          sizeText = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else {
          sizeText = '${(totalBytes / 1024).toStringAsFixed(0)} KB';
        }

        final summary = Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                allSelected
                    ? Icons.deselect_outlined
                    : Icons.select_all_rounded,
                size: 18,
                color: zc.accent,
              ),
              tooltip: allSelected
                  ? l10n.galleryActionDeselect
                  : l10n.galleryActionSelectAll,
              onPressed: _selectAllLocal,
            ),
            Flexible(
              child: Text(
                l10n.gallerySelectionLocalSummary(count, sizeText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: zc.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: _handleLocalDeleteSelected,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: zc.danger,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );

        final primaryButton = ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: zc.accent,
            foregroundColor: zc.onAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: count > 0 ? _handleCollageFromLocal : null,
          child: Text(
            l10n.galleryCollageButton,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
          ),
        );

        final closeButton = IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: Icon(Icons.close_rounded, size: 18, color: zc.textSecondary),
          tooltip: l10n.commonCancel,
          onPressed: () {
            _refresh(() {
              _isLocalSelectionMode = false;
              _selectedLocalFileNames.clear();
            });
          },
        );

        final card = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: zc.surfaceHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: zc.outlineStrong, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: zc.scrim,
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: wide
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: summary),
                        closeButton,
                      ],
                    ),
                    const SizedBox(height: 8),
                    primaryButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 6),
                    primaryButton,
                    const SizedBox(width: 4),
                    closeButton,
                  ],
                ),
        );

        if (!wide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: card,
          );
        }
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(width: 260, child: card),
          ),
        );
      },
    );
  }

  /// 历史导出 (本地相册已下载照片) 视图
  Widget _buildHistoryExportView() {
    final zc = context.zc;
    final l10n = context.l10n;
    if (_historyManager.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(zc.accent),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.galleryScanningExported,
              style: TextStyle(color: zc.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final items = _historyManager.items;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 52,
                color: zc.textTertiary,
              ),
              const SizedBox(height: 14),
              Text(
                l10n.galleryEmptyExportedTitle,
                style: TextStyle(
                  color: zc.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.galleryEmptyExportedSubtitle,
                style: TextStyle(
                  color: zc.textTertiary,
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ZButton(
                label: l10n.galleryRefreshPhoneAlbum,
                icon: Icons.refresh,
                onPressed: () => _historyManager.refresh(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 本地相册路径与统计条
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          color: zc.surface,
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 14, color: zc.accent),
              const SizedBox(width: 6),
              Text(
                l10n.galleryExportedHeaderCount(items.length),
                style: TextStyle(color: zc.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _historyManager.refresh(),
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 13, color: zc.accent),
                    const SizedBox(width: 2),
                    Text(
                      l10n.commonRefresh,
                      style: TextStyle(color: zc.accent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 网格列表
        Expanded(
          child: LayoutBuilder(
            builder: (context, gridConstraints) => Listener(
              key: _historyGridKey,
              onPointerMove: (e) => _updateDragSelect(e.position),
              onPointerUp: (_) => _endDragSelect(),
              onPointerCancel: (_) => _endDragSelect(),
              child: GridView.builder(
                key: const PageStorageKey<String>('exported_history_grid'),
                controller: _historyScrollController,
                padding: GalleryScreenState._historyGridPadding,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridCrossAxisCountFor(
                    gridConstraints.maxWidth,
                  ),
                  crossAxisSpacing: GalleryScreenState._gridSpacing,
                  mainAxisSpacing: GalleryScreenState._gridSpacing,
                  childAspectRatio: GalleryScreenState._historyCardAspect,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _buildExportedItemCard(item, index);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 本地已导出照片卡片
  Widget _buildExportedItemCard(ExportedMediaItem item, int index) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isSelected = _selectedLocalFileNames.contains(item.fileName);
    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_isLocalSelectionMode) {
            _openFullScreenLocalPreview(index);
            return;
          }
          HapticFeedback.selectionClick();
          _refresh(() {
            if (isSelected) {
              _selectedLocalFileNames.remove(item.fileName);
              if (_selectedLocalFileNames.isEmpty)
                _isLocalSelectionMode = false;
            } else {
              _selectedLocalFileNames.add(item.fileName);
            }
          });
        },
        onLongPressStart: (_) => _beginDragSelect(index),
        onLongPressEnd: (_) => _endDragSelect(),
        onLongPressCancel: _endDragSelect,
        child: Container(
          decoration: BoxDecoration(
            color: zc.surfaceHigh,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? 1.6 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                      child: Container(
                        color: zc.surfaceHigh,
                        child: ExportedMediaImage(
                          item: item,
                          fit: BoxFit.cover,
                          cacheWidth: 360,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 28,
                              color: zc.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 左上角绿色「已导出」角标
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 8, color: zc.success),
                            const SizedBox(width: 2),
                            Text(
                              l10n.galleryBadgeExported,
                              style: TextStyle(
                                color: zc.success,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 右上角格式角标
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          item.formatBadge,
                          style: TextStyle(
                            color: zc.textPrimary,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // 拼图多选勾选指示
                    if (_isLocalSelectionMode)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: isSelected
                              ? zc.accent
                              : ZyncPalette.dark.textSecondary,
                        ),
                      ),

                    // 编辑状态角标：覆盖 / 另存
                    if (item.isOverwritten || item.isSavedAsCopy)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: item.isOverwritten ? zc.info : zc.accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.isOverwritten
                                ? l10n.galleryBadgeOverwrite
                                : l10n.galleryBadgeSaveAs,
                            style: TextStyle(
                              color: zc.onAccent,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 底栏文件名与大小
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: zc.textPrimary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.sizeFormatted,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 8.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 单个相机同名照片卡片
  Widget _buildMediaGroupCard(
    CameraMediaGroup group,
    bool isSelected,
    int index,
    List<CameraMediaGroup> visibleGroups,
  ) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isExported = _historyManager.isExported(group.baseName);
    final isPartial = !isExported &&
        group.isRawAndJpeg &&
        (_historyManager.isExported('${group.baseName}.JPG') ||
            _historyManager.isExported('${group.baseName}.NEF'));
    final isViewed = CameraViewedTracker.instance.isViewed(group.baseName);

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelectGroup(group.baseName);
          } else if (group.isVideo) {
            CameraViewedTracker.instance.markViewed(group.baseName);
            _openVideoEditor(group);
          } else {
            // viewer initState 会按初始 group 标记已查看，这里不再提前标记。
            _openFullScreenPreview(visibleGroups, index);
          }
        },
        onLongPressStart: (_) => _beginDragSelect(index),
        onLongPressEnd: (_) => _endDragSelect(),
        onLongPressCancel: _endDragSelect,
        child: Container(
          key: ValueKey(group.baseName),
          decoration: BoxDecoration(
            color: zc.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? 2 : 0.8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 核心缩略图展示 (铺满 1:1 正方形卡片)
              _buildThumbnailImage(group.primaryItem),

              // 左上角格式胶囊 (JPG+RAW, JPG, RAW, MP4)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: zc.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    group.formatBadge,
                    style: TextStyle(
                      color: zc.textPrimary,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 右上角新照片提示角标：未多选且未查看未导出时呈现
              if (!_isSelectionMode && !isViewed && !isExported)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: zc.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.galleryBadgeNew,
                      style: TextStyle(
                        color: zc.onAccent,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 右上角圆形复选圈：仅多选模式下出现
              if (_isSelectionMode)
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleSelectGroup(group.baseName),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? zc.accent : zc.surfaceHigh,
                        border: Border.all(
                          color: isSelected ? zc.accent : zc.textSecondary,
                          width: 1.2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(Icons.check, size: 14, color: zc.onAccent)
                          : null,
                    ),
                  ),
                ),

              // 左下角同步状态微胶囊
              Positioned(
                bottom: 5,
                left: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: zc.surfaceHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isExported
                        ? l10n.galleryFilterSynced
                        : (isPartial
                            ? l10n.galleryBadgePartial
                            : l10n.galleryFilterUnsynced),
                    style: TextStyle(
                      color: isExported
                          ? zc.success
                          : isPartial
                              ? zc.warning
                              : zc.textSecondary,
                      fontSize: 8.5,
                      fontWeight: isExported || isPartial
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 相机缩略图。
  Widget _buildThumbnailImage(
    CameraFileItem file, {
    BoxFit fit = BoxFit.cover,
  }) {
    final zc = context.zc;
    final cacheKey = cameraCacheKey(file.storageId, file.handle);
    final cached = _thumbCache[cacheKey];
    final cacheW = fit == BoxFit.cover ? 360 : null;
    if (cached != null && cached.isNotEmpty) {
      return _buildCameraImage(cached, file, fit, cacheWidth: cacheW);
    }
    return FutureBuilder<Uint8List>(
      future: _resolveThumb(file),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data!.isNotEmpty) {
          return _buildCameraImage(
            snapshot.data!,
            file,
            fit,
            cacheWidth: cacheW,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(zc.accent),
              ),
            ),
          );
        }
        return _buildFallbackIcon(file);
      },
    );
  }

  /// 统一图片渲染入口。
  Widget _buildCameraImage(
    Uint8List bytes,
    CameraFileItem file,
    BoxFit fit, {
    int? cacheWidth,
  }) {
    // 相机 GetThumb 缩略图本身通常只有 160x120 或 320x240（约 5~40KB），
    // 若强制传入 cacheWidth: 360 会触发解码器反向插值放大并偶发步长花屏；
    // 仅当字节体积较大（如高清大图 > 120KB）时才启用解码降采样。
    final effectiveCacheWidth =
        (cacheWidth != null && bytes.length >= 120 * 1024) ? cacheWidth : null;
    return Image.memory(
      bytes,
      fit: fit,
      cacheWidth: effectiveCacheWidth,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        _evictCorruptedThumb(file);
        return _buildFallbackIcon(file);
      },
    );
  }

  Widget _buildFallbackIcon(CameraFileItem file) {
    final zc = context.zc;
    return Center(
      child: Icon(
        file.isVideo ? Icons.videocam : Icons.photo,
        size: 38,
        color: file.isRaw ? zc.accent : zc.textSecondary,
      ),
    );
  }
}
