part of '../watermark_screen.dart';

class _GradeDialItem {
  final String code;
  final String Function(AppLocalizations l10n) title;
  final IconData icon;
  final double min;
  final double max;
  final String unit;
  final Gradient? gradient;
  final double Function(PhotoEditAdjustments adj, ColorGrade pro) getValue;
  final PhotoEditAdjustments Function(PhotoEditAdjustments adj, double val)
      applyValue;

  const _GradeDialItem({
    required this.code,
    required this.title,
    required this.icon,
    this.min = -100,
    this.max = 100,
    this.unit = '',
    this.gradient,
    required this.getValue,
    required this.applyValue,
  });
}

extension _WatermarkScreenGradePanel on WatermarkScreenState {
  List<_GradeDialItem> _getGradeDialItems() => [
        // 基础色调
        _GradeDialItem(
          code: 'Exposure',
          title: (l) => l.toneExposure,
          icon: Icons.wb_sunny_outlined,
          getValue: (a, _) => a.exposure,
          applyValue: (a, v) => a.copyWith(exposure: v),
        ),
        _GradeDialItem(
          code: 'Contrast',
          title: (l) => l.adjContrast,
          icon: Icons.contrast,
          getValue: (a, _) => a.contrast,
          applyValue: (a, v) => a.copyWith(contrast: v),
        ),
        _GradeDialItem(
          code: 'Highlights',
          title: (l) => l.adjHighlights,
          icon: Icons.brightness_high_outlined,
          getValue: (a, _) => a.highlights,
          applyValue: (a, v) => a.copyWith(highlights: v),
        ),
        _GradeDialItem(
          code: 'Shadows',
          title: (l) => l.adjShadows,
          icon: Icons.brightness_low_outlined,
          getValue: (a, _) => a.shadows,
          applyValue: (a, v) => a.copyWith(shadows: v),
        ),
        _GradeDialItem(
          code: 'Whites',
          title: (l) => l.adjWhites,
          icon: Icons.crop_square_outlined,
          getValue: (a, _) => a.whites,
          applyValue: (a, v) => a.copyWith(whites: v),
        ),
        _GradeDialItem(
          code: 'Blacks',
          title: (l) => l.adjBlacks,
          icon: Icons.square,
          getValue: (a, _) => a.blacks,
          applyValue: (a, v) => a.copyWith(blacks: v),
        ),

        // 白平衡与色彩
        _GradeDialItem(
          code: 'Temp',
          title: (l) => l.adjTemperature,
          icon: Icons.thermostat_outlined,
          gradient: ZSwatch.wbTemperatureGradient,
          getValue: (a, _) => a.temperature,
          applyValue: (a, v) => a.copyWith(temperature: v),
        ),
        _GradeDialItem(
          code: 'Tint',
          title: (l) => l.adjTint,
          icon: Icons.palette_outlined,
          gradient: ZSwatch.wbTintGradient,
          getValue: (a, _) => a.tint,
          applyValue: (a, v) => a.copyWith(tint: v),
        ),
        _GradeDialItem(
          code: 'Vibrance',
          title: (l) => l.adjVibrance,
          icon: Icons.local_florist_outlined,
          getValue: (a, _) => a.vibrance,
          applyValue: (a, v) => a.copyWith(vibrance: v),
        ),
        _GradeDialItem(
          code: 'Saturation',
          title: (l) => l.adjSaturation,
          icon: Icons.color_lens_outlined,
          getValue: (a, _) => a.saturation,
          applyValue: (a, v) => a.copyWith(saturation: v),
        ),

        // 偏好质感
        _GradeDialItem(
          code: 'Clarity',
          title: (l) => l.adjClarity,
          icon: Icons.filter_center_focus_outlined,
          getValue: (a, _) => a.clarity,
          applyValue: (a, v) => a.copyWith(clarity: v),
        ),
        _GradeDialItem(
          code: 'Texture',
          title: (l) => l.adjTexture,
          icon: Icons.grain,
          getValue: (a, _) => a.texture,
          applyValue: (a, v) => a.copyWith(texture: v),
        ),
        _GradeDialItem(
          code: 'Dehaze',
          title: (l) => l.adjDehaze,
          icon: Icons.blur_off_outlined,
          getValue: (a, _) => a.dehaze,
          applyValue: (a, v) => a.copyWith(dehaze: v),
        ),

        // 颜色分级
        _GradeDialItem(
          code: 'Hi-Hue',
          title: (l) => l.adjHighlightHue,
          icon: Icons.light_mode_outlined,
          min: 0,
          max: 360,
          unit: '°',
          gradient: ZSwatch.hueRainbowGradient,
          getValue: (a, _) => a.highlightHue,
          applyValue: (a, v) => a.copyWith(highlightHue: v),
        ),
        _GradeDialItem(
          code: 'Hi-Sat',
          title: (l) => l.adjHighlightSat,
          icon: Icons.opacity_outlined,
          min: 0,
          max: 100,
          unit: '%',
          getValue: (a, _) => a.highlightSat,
          applyValue: (a, v) => a.copyWith(highlightSat: v),
        ),
        _GradeDialItem(
          code: 'Sh-Hue',
          title: (l) => l.adjShadowHue,
          icon: Icons.dark_mode_outlined,
          min: 0,
          max: 360,
          unit: '°',
          gradient: ZSwatch.hueRainbowGradient,
          getValue: (a, _) => a.shadowHue,
          applyValue: (a, v) => a.copyWith(shadowHue: v),
        ),
        _GradeDialItem(
          code: 'Sh-Sat',
          title: (l) => l.adjShadowSat,
          icon: Icons.opacity_outlined,
          min: 0,
          max: 100,
          unit: '%',
          getValue: (a, _) => a.shadowSat,
          applyValue: (a, v) => a.copyWith(shadowSat: v),
        ),

        // 镜头与效果
        _GradeDialItem(
          code: 'Vignette',
          title: (l) => l.adjLensVignette,
          icon: Icons.camera_outlined,
          getValue: (a, _) => a.vignette,
          applyValue: (a, v) => a.copyWith(vignette: v),
        ),
        _GradeDialItem(
          code: 'Grain',
          title: (l) => l.adjFilmGrain,
          icon: Icons.grain_outlined,
          min: 0,
          max: 100,
          unit: '%',
          getValue: (a, _) => a.grain,
          applyValue: (a, v) => a.copyWith(grain: v),
        ),
      ];

  /// 第 ② 栏「胶片滤镜」：单层分类横滑标签（含预设库）+ 横向胶片卡带 + 浓度滑块与转入精调
  Widget _buildFilmFilterPanel({bool wide = false}) {
    final zc = context.zc;
    final l10n = context.l10n;

    final categories = <String>[
      'preset',
      'all',
      ...PhotoFilterType.categories1,
    ];

    final isPresetCat = _filterCategory == 'preset';
    final isAllCat = _filterCategory == 'all';

    final List<PhotoFilterType> displayedFilters;
    if (isPresetCat) {
      displayedFilters = const [];
    } else if (isAllCat) {
      displayedFilters = PhotoFilterType.values;
    } else {
      displayedFilters = PhotoFilterType.getByCategories(_filterCategory);
    }

    if (wide) {
      return _buildTabletFilmFilterPanel(
        categories: categories,
        isPresetCat: isPresetCat,
        isAllCat: isAllCat,
        displayedFilters: displayedFilters,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      children: [
        // 1. 顶部单行分类栏
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in categories) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Builder(builder: (context) {
                    final isSelected = cat == _filterCategory;
                    final String label;
                    if (cat == 'preset') {
                      label = l10n.wmDialCategoryPreset;
                    } else if (cat == 'all') {
                      label = l10n.wmFilterAllCount(PhotoFilterType.values.length);
                    } else {
                      label = L10n.tr(cat, l10n.localeName);
                    }
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          _updateState(() => _filterCategory = cat);
                        }
                      },
                      selectedColor: zc.accent,
                      backgroundColor: zc.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? zc.onAccent : zc.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? zc.accent : zc.outline,
                        width: ZStroke.hairline,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      showCheckmark: false,
                    );
                  }),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. 中部横向胶片卡片带
        SizedBox(
          height: 100,
          child: isPresetCat
              ? _buildPresetHorizontalStrip()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: displayedFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = displayedFilters[index];
                    return SizedBox(
                      width: 130,
                      child: _buildFilmCard(filter),
                    );
                  },
                ),
        ),

        const SizedBox(height: 10),

        // 3. 底部常驻控制条：滤镜浓度滑块与转入精调
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(color: zc.outline),
          ),
          child: Row(
            children: [
              Text(
                l10n.wmPresetIntensity,
                style: TextStyle(color: zc.textSecondary, fontSize: 11),
              ),
              Expanded(
                child: Slider(
                  value: _filterIntensity,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: zc.accent,
                  inactiveColor: zc.outline,
                  label: '${(_filterIntensity * 100).round()}%',
                  onChanged:
                      _selectedFilter == PhotoFilterType.original && !isPresetCat
                          ? null
                          : (val) =>
                              _updateState(() => _filterIntensity = val),
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(_filterIntensity * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: zc.accent,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 20, color: zc.outline),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  _updateState(() {
                    if (_selectedFilter != PhotoFilterType.original) {
                      _adjustments = _selectedFilter.presetAdjustments;
                    }
                    _tabController.animateTo(2);
                  });
                  showZToast(
                    context,
                    l10n.wmLoadedFilterSlidersToast(_selectedFilter.trLabel),
                  );
                },
                icon: const Icon(Icons.tune, size: 14),
                label: Text(l10n.wmDialTransferToGrade),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: zc.accent,
                  side: BorderSide(color: zc.accent, width: ZStroke.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 平板模式滤镜与预设选择面板：支持「单列一行一种（带滚动条）」与「自适应高度分页」
  Widget _buildTabletFilmFilterPanel({
    required List<String> categories,
    required bool isPresetCat,
    required bool isAllCat,
    required List<PhotoFilterType> displayedFilters,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isPaged = AppSettings.instance.tabletFilterViewPaged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 顶部分类栏（Chip 列表）
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in categories) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Builder(builder: (context) {
                      final isSelected = cat == _filterCategory;
                      final String label;
                      if (cat == 'preset') {
                        label = l10n.wmDialCategoryPreset;
                      } else if (cat == 'all') {
                        label = l10n.wmFilterAllCount(PhotoFilterType.values.length);
                      } else {
                        label = L10n.tr(cat, l10n.localeName);
                      }
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            _updateState(() {
                              _filterCategory = cat;
                              _filterCurrentPage = 0;
                            });
                          }
                        },
                        selectedColor: zc.accent,
                        backgroundColor: zc.surface,
                        labelStyle: TextStyle(
                          color: isSelected ? zc.onAccent : zc.textSecondary,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? zc.accent : zc.outline,
                          width: ZStroke.hairline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 1),
                        showCheckmark: false,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 2. 模式切换工具栏：[ 一行一种列表 / 自适应屏幕高度分页 ]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isPresetCat
                      ? l10n.wmDialCategoryPreset
                      : (isAllCat
                          ? l10n.wmFilterAllCount(displayedFilters.length)
                          : '${L10n.tr(_filterCategory, l10n.localeName)} (${displayedFilters.length})'),
                  style: TextStyle(
                    color: zc.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildTabletViewModePill(
                isPaged: isPaged,
                onToggle: (val) {
                  _updateState(() {
                    AppSettings.instance.setTabletFilterViewPaged(val);
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        // 3. 中间滤镜/预设选择区（一行一种列表 或 自适应屏幕高度分页）
        Expanded(
          child: isPresetCat
              ? (isPaged
                  ? _buildTabletPresetPagedView()
                  : _buildTabletPresetVerticalList())
              : (isPaged
                  ? _buildTabletFilmPagedView(displayedFilters)
                  : _buildTabletFilmVerticalList(displayedFilters)),
        ),

        // 4. 底部常驻控制条：滤镜浓度滑块与转入精调
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: zc.surface,
            border: Border(
                top: BorderSide(color: zc.outline, width: ZStroke.hairline)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    l10n.wmPresetIntensity,
                    style: TextStyle(color: zc.textSecondary, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: _filterIntensity,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: zc.accent,
                      inactiveColor: zc.outline,
                      label: '${(_filterIntensity * 100).round()}%',
                      onChanged: _selectedFilter == PhotoFilterType.original &&
                              !isPresetCat
                          ? null
                          : (val) =>
                              _updateState(() => _filterIntensity = val),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${(_filterIntensity * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: zc.accent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () {
                  _updateState(() {
                    if (_selectedFilter != PhotoFilterType.original) {
                      _adjustments = _selectedFilter.presetAdjustments;
                    }
                    _tabController.animateTo(2);
                  });
                  showZToast(
                    context,
                    l10n.wmLoadedFilterSlidersToast(_selectedFilter.trLabel),
                  );
                },
                icon: const Icon(Icons.tune, size: 13),
                label: Text(l10n.wmDialTransferToGrade),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: zc.accent,
                  side: BorderSide(color: zc.accent, width: ZStroke.hairline),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 平板模式滤镜单列列表（一行放一种，带可见滚动条）
  Widget _buildTabletFilmVerticalList(List<PhotoFilterType> displayedFilters) {
    return Scrollbar(
      controller: _filterScrollController,
      thumbVisibility: true,
      interactive: true,
      child: ListView.separated(
        controller: _filterScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: displayedFilters.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (context, index) {
          final filter = displayedFilters[index];
          return _buildTabletFilmListRow(filter);
        },
      ),
    );
  }

  Widget _buildTabletFilmListRow(PhotoFilterType filter) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isSelected = filter == _selectedFilter;

    return Material(
      color: ZSwatch.transparent,
      child: InkWell(
        onTap: () => _updateState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(ZRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? zc.accent.withAlpha(28) : zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Row(
            children: [
              // 经典签名三色圆点 + 胶片代码药丸
              Container(
                width: 48,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: BoxDecoration(
                  color: zc.bg,
                  borderRadius: BorderRadius.circular(ZRadius.xs),
                  border: Border.all(color: zc.outline.withAlpha(80)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: filter.previewColors
                          .take(3)
                          .map((c) => Container(
                                width: 7,
                                height: 7,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      filter.code,
                      style: TextStyle(
                        color: zc.textSecondary,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 中间滤镜名称与风格描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            filter.trLabel,
                            style: TextStyle(
                              color: isSelected ? zc.accent : zc.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (filter.category2.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: zc.surfaceHigh,
                              borderRadius:
                                  BorderRadius.circular(ZRadius.pill),
                            ),
                            child: Text(
                              L10n.tr(filter.category2, l10n.localeName),
                              style: TextStyle(
                                color: zc.textTertiary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      filter.recipeSummary.isNotEmpty
                          ? filter.recipeSummary
                          : filter.description,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 10,
                        height: 1.15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 右侧选中状态指示
              if (isSelected)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: zc.accent.withAlpha(35),
                        borderRadius: BorderRadius.circular(ZRadius.pill),
                      ),
                      child: Text(
                        '${(_filterIntensity * 100).round()}%',
                        style: TextStyle(
                          color: zc.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 18, color: zc.accent),
                  ],
                )
              else
                Icon(Icons.radio_button_unchecked,
                    size: 18, color: zc.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  /// 平板模式预设单列列表（一行放一种，带可见滚动条）
  Widget _buildTabletPresetVerticalList() {
    final zc = context.zc;
    final l10n = context.l10n;
    final builtins = kBuiltinGradePresets;

    return FutureBuilder<List<ColorGradePreset>>(
      future: ColorGradePresetStore.load(),
      builder: (context, snapshot) {
        final userPresets = snapshot.data ?? const [];
        final totalCount = 1 + userPresets.length + builtins.length;

        return Scrollbar(
          controller: _filterScrollController,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: _filterScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: totalCount,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              // 第 0 行：存为新预设行
              if (index == 0) {
                return Material(
                  color: ZSwatch.transparent,
                  child: InkWell(
                    onTap: _showSavePresetDialog,
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: zc.accent.withAlpha(18),
                        borderRadius: BorderRadius.circular(ZRadius.sm),
                        border: Border.all(
                            color: zc.accent.withAlpha(70),
                            width: ZStroke.hairline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bookmark_add_outlined,
                              size: 16, color: zc.accent),
                          const SizedBox(width: 8),
                          Text(
                            l10n.wmDialSaveAsPreset,
                            style: TextStyle(
                              color: zc.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final userIndex = index - 1;
              final isUser = userIndex < userPresets.length;
              final ColorGrade grade;
              final String name;
              final String categoryLabel;

              if (isUser) {
                final p = userPresets[userIndex];
                name = p.name;
                grade = p.grade;
                categoryLabel = l10n.wmDialPresetCustomGroup;
              } else {
                final b = builtins[userIndex - userPresets.length];
                name = b.trName;
                grade = b.grade;
                categoryLabel = b.trCategory;
              }

              return Material(
                color: ZSwatch.transparent,
                child: InkWell(
                  onTap: () {
                    _updateState(() {
                      _adjustments = grade.base;
                      _proGrade = grade;
                      _selectedFilter = PhotoFilterType.original;
                      _filterIntensity = 1.0;
                    });
                    showZToast(context, '$name · $categoryLabel');
                  },
                  borderRadius: BorderRadius.circular(ZRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: zc.surface,
                      borderRadius: BorderRadius.circular(ZRadius.sm),
                      border: Border.all(color: zc.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUser
                              ? Icons.person_outline
                              : Icons.auto_awesome_outlined,
                          size: 18,
                          color: zc.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: zc.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                categoryLabel,
                                style: TextStyle(
                                  color: zc.textTertiary,
                                  fontSize: 9.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isUser)
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.close,
                                size: 14, color: zc.textTertiary),
                            onPressed: () async {
                              final p = userPresets[userIndex];
                              await ColorGradePresetStore.remove(p.id);
                              _updateState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 平板模式滤镜自适应屏幕高度分页
  Widget _buildTabletFilmPagedView(List<PhotoFilterType> displayedFilters) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight - 44;
        const cardH = 80.0;
        const spacing = 8.0;
        final rows = math.max(2, (availH / (cardH + spacing)).floor());
        const cols = 2;
        final itemsPerPage = rows * cols;
        final totalItems = displayedFilters.length;
        final totalPages = math.max(1, (totalItems / itemsPerPage).ceil());
        final currentPage = _filterCurrentPage.clamp(0, totalPages - 1);

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _filterPageController,
                onPageChanged: (p) =>
                    _updateState(() => _filterCurrentPage = p),
                itemCount: totalPages,
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * itemsPerPage;
                  final end = math.min(start + itemsPerPage, totalItems);
                  final pageItems = displayedFilters.sublist(start, end);

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio:
                            (constraints.maxWidth - 20 - spacing) /
                                cols /
                                cardH,
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, i) {
                        final filter = pageItems[i];
                        return _buildFilmCard(filter);
                      },
                    ),
                  );
                },
              ),
            ),
            _buildTabletPaginationBar(
              currentPage: currentPage,
              totalPages: totalPages,
              onPrev: currentPage > 0
                  ? () => _filterPageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
              onNext: currentPage < totalPages - 1
                  ? () => _filterPageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }

  /// 平板模式预设自适应屏幕高度分页
  Widget _buildTabletPresetPagedView() {
    final zc = context.zc;
    final l10n = context.l10n;
    final builtins = kBuiltinGradePresets;

    return FutureBuilder<List<ColorGradePreset>>(
      future: ColorGradePresetStore.load(),
      builder: (context, snapshot) {
        final userPresets = snapshot.data ?? const [];
        final totalCount = 1 + userPresets.length + builtins.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final availH = constraints.maxHeight - 44;
            const cardH = 80.0;
            const spacing = 8.0;
            final rows = math.max(2, (availH / (cardH + spacing)).floor());
            const cols = 2;
            final itemsPerPage = rows * cols;
            final totalPages = math.max(1, (totalCount / itemsPerPage).ceil());
            final currentPage = _filterCurrentPage.clamp(0, totalPages - 1);

            return Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _filterPageController,
                    onPageChanged: (p) =>
                        _updateState(() => _filterCurrentPage = p),
                    itemCount: totalPages,
                    itemBuilder: (context, pageIndex) {
                      final start = pageIndex * itemsPerPage;
                      final end = math.min(start + itemsPerPage, totalCount);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio:
                                (constraints.maxWidth - 20 - spacing) /
                                    cols /
                                    cardH,
                          ),
                          itemCount: end - start,
                          itemBuilder: (context, i) {
                            final index = start + i;
                            if (index == 0) {
                              return Material(
                                color: ZSwatch.transparent,
                                child: InkWell(
                                  onTap: _showSavePresetDialog,
                                  borderRadius:
                                      BorderRadius.circular(ZRadius.sm),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: zc.accent.withAlpha(20),
                                      borderRadius:
                                          BorderRadius.circular(ZRadius.sm),
                                      border: Border.all(
                                          color: zc.accent,
                                          width: ZStroke.hairline),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.bookmark_add_outlined,
                                            size: 22, color: zc.accent),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.wmDialSaveAsPreset,
                                          style: TextStyle(
                                            color: zc.accent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final userIndex = index - 1;
                            if (userIndex < userPresets.length) {
                              final preset = userPresets[userIndex];
                              return Material(
                                color: ZSwatch.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _updateState(() {
                                      _proGrade = preset.grade;
                                      _adjustments = preset.grade.base;
                                    });
                                    showZToast(context,
                                        '${preset.name} · ${preset.summary}');
                                  },
                                  borderRadius:
                                      BorderRadius.circular(ZRadius.sm),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: zc.surface,
                                      borderRadius:
                                          BorderRadius.circular(ZRadius.sm),
                                      border: Border.all(color: zc.outline),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(Icons.person_outline,
                                                size: 14, color: zc.accent),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Icon(Icons.close,
                                                  size: 13,
                                                  color: zc.textTertiary),
                                              onPressed: () async {
                                                await ColorGradePresetStore
                                                    .remove(preset.id);
                                                _updateState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                        Text(
                                          preset.name,
                                          style: TextStyle(
                                            color: zc.textPrimary,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          preset.summary,
                                          style: TextStyle(
                                            color: zc.textTertiary,
                                            fontSize: 9,
                                            fontFamily: 'monospace',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            final builtinIndex =
                                userIndex - userPresets.length;
                            final builtin = builtins[builtinIndex];
                            return Material(
                              color: ZSwatch.transparent,
                              child: InkWell(
                                onTap: () {
                                  _updateState(() {
                                    _proGrade = builtin.grade;
                                    _adjustments = builtin.grade.base;
                                  });
                                  showZToast(context,
                                      '${builtin.trName} · ${builtin.trDescription}');
                                },
                                borderRadius:
                                      BorderRadius.circular(ZRadius.sm),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: zc.surface,
                                    borderRadius:
                                        BorderRadius.circular(ZRadius.sm),
                                    border: Border.all(color: zc.outline),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Icon(Icons.auto_awesome_outlined,
                                          size: 14, color: zc.accent),
                                      Text(
                                        builtin.trName,
                                        style: TextStyle(
                                          color: zc.textPrimary,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        builtin.trDescription,
                                        style: TextStyle(
                                          color: zc.textTertiary,
                                          fontSize: 9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                _buildTabletPaginationBar(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrev: currentPage > 0
                      ? () => _filterPageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          )
                      : null,
                  onNext: currentPage < totalPages - 1
                      ? () => _filterPageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          )
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 预设横向胶片带
  Widget _buildPresetHorizontalStrip() {
    final zc = context.zc;
    final l10n = context.l10n;
    final builtins = kBuiltinGradePresets;

    return FutureBuilder<List<ColorGradePreset>>(
      future: ColorGradePresetStore.load(),
      builder: (context, snapshot) {
        final userPresets = snapshot.data ?? const [];
        final totalCount = 1 + userPresets.length + builtins.length;

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: totalCount,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // 第 0 张：存为预设卡片
            if (index == 0) {
              return InkWell(
                onTap: _showSavePresetDialog,
                borderRadius: BorderRadius.circular(ZRadius.sm),
                child: Container(
                  width: 120,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: zc.accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    border: Border.all(
                      color: zc.accent,
                      width: ZStroke.hairline,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_add_outlined,
                          size: 22, color: zc.accent),
                      const SizedBox(height: 6),
                      Text(
                        l10n.wmDialSaveAsPreset,
                        style: TextStyle(
                          color: zc.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // 用户保存的自定义预设
            final userIndex = index - 1;
            if (userIndex < userPresets.length) {
              final preset = userPresets[userIndex];
              return InkWell(
                onTap: () {
                  _updateState(() {
                    _proGrade = preset.grade;
                    _adjustments = preset.grade.base;
                  });
                  showZToast(context, '${preset.name} · ${preset.summary}');
                },
                borderRadius: BorderRadius.circular(ZRadius.sm),
                child: Container(
                  width: 125,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: zc.surface,
                    borderRadius: BorderRadius.circular(ZRadius.sm),
                    border: Border.all(color: zc.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.person_outline,
                              size: 14, color: zc.accent),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(Icons.close,
                                size: 14, color: zc.textTertiary),
                            onPressed: () async {
                              await ColorGradePresetStore.remove(preset.id);
                              _updateState(() {});
                            },
                          ),
                        ],
                      ),
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: zc.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        preset.summary,
                        style: TextStyle(
                          color: zc.textTertiary,
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }

            // 内置调色预设
            final builtinIndex = userIndex - userPresets.length;
            final builtin = builtins[builtinIndex];
            return InkWell(
              onTap: () {
                _updateState(() {
                  _proGrade = builtin.grade;
                  _adjustments = builtin.grade.base;
                });
                showZToast(
                  context,
                  '${builtin.trName} · ${builtin.trDescription}',
                );
              },
              borderRadius: BorderRadius.circular(ZRadius.sm),
              child: Container(
                width: 125,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: zc.surface,
                  borderRadius: BorderRadius.circular(ZRadius.sm),
                  border: Border.all(color: zc.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 13, color: zc.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            builtin.trCategory,
                            style: TextStyle(
                              color: zc.textTertiary,
                              fontSize: 9.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      builtin.trName,
                      style: TextStyle(
                        color: zc.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      builtin.trDescription,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 9.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 预设卡片组件
  Widget _buildFilmCard(PhotoFilterType filter) {
    final zc = context.zc;
    final isSelected = filter == _selectedFilter;
    return Material(
      color: ZSwatch.transparent,
      child: InkWell(
        onTap: () => _updateState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(ZRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? zc.accent.withAlpha(35) : zc.surface,
            borderRadius: BorderRadius.circular(ZRadius.sm),
            border: Border.all(
              color: isSelected ? zc.accent : zc.outline,
              width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Row(
                    children: filter.previewColors
                        .take(3)
                        .map((c) => Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      filter.code,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, size: 12, color: zc.accent),
                ],
              ),
              Text(
                filter.trLabel,
                style: TextStyle(
                  color: isSelected ? zc.accent : zc.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                filter.recipeSummary,
                style: TextStyle(
                  color: isSelected
                      ? zc.accent.withAlpha(210)
                      : zc.textTertiary,
                  fontSize: 8.5,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存自定义调色预设弹窗
  Future<void> _showSavePresetDialog() async {
    final l10n = context.l10n;
    final zc = context.zc;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: zc.surfaceHigh,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadius.md)),
        title: Text(
          l10n.wmDialSaveAsPreset,
          style: TextStyle(
              color: zc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: zc.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: l10n.wmDialSavePresetPrompt,
            hintStyle: TextStyle(color: zc.textTertiary, fontSize: 12),
            filled: true,
            fillColor: zc.surface,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ZRadius.sm),
              borderSide: BorderSide(color: zc.outline),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final t = controller.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final preset = ColorGradePreset(
      id: 'user_$now',
      name: name,
      grade: _proGrade.copyWith(base: _adjustments),
      createdAtMs: now,
      updatedAtMs: now,
    );
    await ColorGradePresetStore.upsert(preset);
    if (mounted) {
      _updateState(() {});
      showZToast(
        context,
        l10n.wmDialSavePresetSuccess(name),
        tone: ZStatusTone.success,
      );
    }
  }

  /// 第 ③ 栏「参数精调」：横向参数拨盘带 + 单根高精度主滑块 + 内联 RAW/3D LUT
  Widget _buildParameterGradePanel() {
    final l10n = context.l10n;
    final dialItems = _getGradeDialItems();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // 1. 顶部快速分组锚点条 + 重置全部按钮
        _buildGradeQuickGroups(l10n),

        const SizedBox(height: 8),

        // 2. 中部核心区：当前参数单主滑块控制卡片
        _buildActiveParameterSlider(l10n, dialItems),

        const SizedBox(height: 10),

        // 3. 底部横向参数拨盘带
        _buildParameterDialStrip(l10n, dialItems),
      ],
    );
  }

  /// 快速分组锚点条
  Widget _buildGradeQuickGroups(AppLocalizations l10n) {
    final zc = context.zc;

    final groups = [
      (l10n.wmGradeCatTone, 'Exposure'),
      (l10n.wmGradeCatWb, 'Temp'),
      (l10n.wmGradeCatPresence, 'Clarity'),
      (l10n.wmGradeCatSplit, 'Hi-Hue'),
      (l10n.wmGradeCatEffects, 'Vignette'),
      ('3D LUT', 'LUT'),
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _updateState(() => _activeParamCode = g.$2),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _activeParamCode == g.$2
                              ? zc.accent.withAlpha(40)
                              : zc.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _activeParamCode == g.$2
                                ? zc.accent
                                : zc.outline,
                            width: ZStroke.hairline,
                          ),
                        ),
                        child: Text(
                          g.$1,
                          style: TextStyle(
                            color: _activeParamCode == g.$2
                                ? zc.accent
                                : zc.textSecondary,
                            fontSize: 11,
                            fontWeight: _activeParamCode == g.$2
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: () {
            _updateState(() {
              _adjustments = const PhotoEditAdjustments();
              _proGrade = const ColorGrade();
            });
            showZToast(context, l10n.commonReset);
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.restart_alt, size: 14, color: zc.textTertiary),
                const SizedBox(width: 2),
                Text(
                  l10n.wmDialResetAll,
                  style: TextStyle(color: zc.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 单高精度主滑块控制区
  Widget _buildActiveParameterSlider(
      AppLocalizations l10n, List<_GradeDialItem> dialItems) {
    final zc = context.zc;

    if (_activeParamCode == 'LUT') {
      final lut = _proGrade.lut;
      final hasLut = lut.path.isNotEmpty;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: BorderRadius.circular(ZRadius.sm),
          border: Border.all(color: zc.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: zc.accent),
                const SizedBox(width: 8),
                Text(
                  '3D LUT (.cube)',
                  style: TextStyle(
                    color: zc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (hasLut)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close, size: 16, color: zc.textTertiary),
                    onPressed: () {
                      _updateState(() {
                        _proGrade = _proGrade.copyWith(lut: const LutRef());
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasLut ? lut.name : l10n.wmDialNoLutChosen,
                    style: TextStyle(
                      color: hasLut ? zc.accent : zc.textTertiary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final path = await CameraNativeBridge.pickFile();
                    if (path != null && path.isNotEmpty) {
                      _updateState(() {
                        _proGrade = _proGrade.copyWith(
                          lut: LutRef(
                            id: path,
                            name: path.split(RegExp(r'[\\/]')).last,
                            path: path,
                            strength: 1.0,
                          ),
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.folder_open, size: 14),
                  label: Text(l10n.wmDialActiveLutButton),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: zc.accent,
                    side: BorderSide(color: zc.accent, width: ZStroke.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ZRadius.pill),
                    ),
                  ),
                ),
              ],
            ),
            if (hasLut) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    l10n.wmPresetIntensity,
                    style: TextStyle(color: zc.textSecondary, fontSize: 11),
                  ),
                  Expanded(
                    child: Slider(
                      value: lut.strength,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: zc.accent,
                      inactiveColor: zc.outline,
                      label: '${(lut.strength * 100).round()}%',
                      onChanged: (val) {
                        _updateState(() {
                          _proGrade = _proGrade.copyWith(
                            lut: lut.copyWith(strength: val),
                          );
                        });
                      },
                    ),
                  ),
                  Text(
                    '${(lut.strength * 100).round()}%',
                    style: TextStyle(
                      color: zc.accent,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    final item = dialItems.firstWhere(
      (e) => e.code == _activeParamCode,
      orElse: () => dialItems.first,
    );

    final val = item.getValue(_adjustments, _proGrade);
    final displayVal = val.round();
    final String valueText;
    if (item.min >= 0) {
      valueText = '$displayVal${item.unit}';
    } else {
      valueText = displayVal > 0
          ? '+$displayVal${item.unit}'
          : '$displayVal${item.unit}';
    }
    final isModified = val.abs() > 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: BorderRadius.circular(ZRadius.sm),
        border: Border.all(
          color: isModified ? zc.accent.withAlpha(90) : zc.outline,
          width: isModified ? 1.0 : ZStroke.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                item.icon,
                size: 15,
                color: isModified ? zc.accent : zc.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${item.title(l10n)} (${item.code})',
                  style: TextStyle(
                    color: isModified ? zc.accent : zc.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // 微调 [-] 按钮
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.remove_circle_outline,
                    size: 17, color: zc.textTertiary),
                onPressed: () {
                  final step = item.min >= 0 ? 5.0 : 2.0;
                  final nextVal = (val - step).clamp(item.min, item.max);
                  _updateState(() {
                    _adjustments = item.applyValue(_adjustments, nextVal);
                  });
                },
              ),
              const SizedBox(width: 4),
              // 单击归零数值胶囊
              InkWell(
                onTap: () {
                  _updateState(() {
                    _adjustments = item.applyValue(_adjustments, 0.0);
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isModified ? zc.accent.withAlpha(35) : zc.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    valueText,
                    style: TextStyle(
                      color: isModified ? zc.accent : zc.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 微调 [+] 按钮
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.add_circle_outline,
                    size: 17, color: zc.textTertiary),
                onPressed: () {
                  final step = item.min >= 0 ? 5.0 : 2.0;
                  final nextVal = (val + step).clamp(item.min, item.max);
                  _updateState(() {
                    _adjustments = item.applyValue(_adjustments, nextVal);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              if (item.gradient != null)
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: item.gradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: item.gradient != null ? 3.0 : 4.0,
                  activeTrackColor:
                      item.gradient != null ? ZSwatch.transparent : zc.accent,
                  inactiveTrackColor:
                      item.gradient != null ? ZSwatch.transparent : zc.outline,
                  thumbColor: zc.accent,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                ),
                child: Slider(
                  value: val.clamp(item.min, item.max),
                  min: item.min,
                  max: item.max,
                  divisions:
                      (item.max - item.min).round().clamp(10, 360).toInt(),
                  onChanged: (newVal) {
                    _updateState(() {
                      _adjustments = item.applyValue(_adjustments, newVal);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 底部横向参数拨盘带
  Widget _buildParameterDialStrip(
      AppLocalizations l10n, List<_GradeDialItem> dialItems) {
    final zc = context.zc;
    final totalCount = dialItems.length + 1; // 加上 3D LUT

    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalCount,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index == dialItems.length) {
            // 3D LUT 图标拨盘
            final isSelected = _activeParamCode == 'LUT';
            final hasLut = _proGrade.lut.path.isNotEmpty;
            return InkWell(
              onTap: () => _updateState(() => _activeParamCode = 'LUT'),
              borderRadius: BorderRadius.circular(ZRadius.sm),
              child: Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected ? zc.accent.withAlpha(35) : zc.surface,
                  borderRadius: BorderRadius.circular(ZRadius.sm),
                  border: Border.all(
                    color: isSelected ? zc.accent : zc.outline,
                    width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: isSelected
                          ? zc.accent
                          : (hasLut ? zc.accent : zc.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '3D LUT',
                      style: TextStyle(
                        color: isSelected ? zc.accent : zc.textSecondary,
                        fontSize: 9.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasLut) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: zc.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'ON',
                            style: TextStyle(
                              color: zc.accent,
                              fontSize: 8,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final item = dialItems[index];
          final isSelected = item.code == _activeParamCode;
          final val = item.getValue(_adjustments, _proGrade);
          final isModified = val.abs() > 0.5;

          final displayVal = val.round();
          final String badgeText;
          if (item.min >= 0) {
            badgeText = '$displayVal${item.unit}';
          } else {
            badgeText = displayVal > 0 ? '+$displayVal' : '$displayVal';
          }

          return InkWell(
            onTap: () => _updateState(() => _activeParamCode = item.code),
            borderRadius: BorderRadius.circular(ZRadius.sm),
            child: Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? zc.accent.withAlpha(35) : zc.surface,
                borderRadius: BorderRadius.circular(ZRadius.sm),
                border: Border.all(
                  color: isSelected ? zc.accent : zc.outline,
                  width: isSelected ? ZStroke.emphasis : ZStroke.hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: isSelected
                        ? zc.accent
                        : (isModified ? zc.accent : zc.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title(l10n),
                    style: TextStyle(
                      color: isSelected ? zc.accent : zc.textSecondary,
                      fontSize: 9.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isModified) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: zc.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: zc.accent,
                            fontSize: 8,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
