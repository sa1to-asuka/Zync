part of '../watermark_screen.dart';

/// 单个调色参数的定义。
class _GradeDialItem {
  final String code;
  final String Function(AppLocalizations l10n) title;
  final IconData icon;
  final double min;
  final double max;
  final double defaultValue;
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
    this.defaultValue = 0,
    this.unit = '',
    this.gradient,
    required this.getValue,
    required this.applyValue,
  });
}

/// 参数分组。
class _GradeGroupDef {
  final String code;
  final String title;
  final IconData icon;
  final List<String> codes;

  const _GradeGroupDef({
    required this.code,
    required this.title,
    required this.icon,
    required this.codes,
  });
}

extension _WatermarkScreenGradePanel on WatermarkScreenState {
  List<_GradeDialItem> _getGradeDialItems() => [
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
          icon: Icons.colorize_outlined,
          gradient: ZSwatch.wbTintGradient,
          getValue: (a, _) => a.tint,
          applyValue: (a, v) => a.copyWith(tint: v),
        ),
        _GradeDialItem(
          code: 'Vibrance',
          title: (l) => l.adjVibrance,
          icon: Icons.auto_awesome_outlined,
          getValue: (a, _) => a.vibrance,
          applyValue: (a, v) => a.copyWith(vibrance: v),
        ),
        _GradeDialItem(
          code: 'Saturation',
          title: (l) => l.adjSaturation,
          icon: Icons.water_drop_outlined,
          getValue: (a, _) => a.saturation,
          applyValue: (a, v) => a.copyWith(saturation: v),
        ),
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
        _GradeDialItem(
          code: 'Hi-Hue',
          title: (l) => l.adjHighlightHue,
          icon: Icons.light_mode_outlined,
          min: 0,
          max: 360,
          defaultValue: 40,
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
          defaultValue: 220,
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

  bool _isFilterCategory(String category) =>
      category != 'mine' && category != 'builtin';

  List<String> _presetCategories() => <String>[
        'mine',
        'builtin',
        ...PhotoFilterType.categories1,
      ];

  // ==================== 主面板 ====================

  Widget _buildPresetGradePanel({bool wide = false}) {
    final zc = context.zc;
    final showIntensity =
        _isFilterCategory(_filterCategory) &&
            _selectedFilter != PhotoFilterType.original;

    return Container(
      color: zc.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpace.md,
                ZSpace.sm,
                ZSpace.sm,
                ZSpace.xs,
              ),
              child: Row(
                children: [
                  Expanded(child: _buildCategoryChips()),
                  _buildViewModeToggle(),
                ],
              ),
            ),
            SizedBox(height: 144, child: _buildPresetBrowser(wide: true)),
          ],
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                wide ? ZSpace.md : ZSpace.lg,
                wide ? ZSpace.sm : ZSpace.md,
                wide ? ZSpace.md : ZSpace.lg,
                ZSpace.sm,
              ),
              children: [
                if (!wide) ...[
                  _buildCategoryChips(),
                  const SizedBox(height: ZSpace.sm),
                  SizedBox(height: 70, child: _buildPresetStrip()),
                ],
                if (showIntensity) _buildFilterIntensityBar(),
                if (_isFilmActive) _buildFilmBypassHint(),
                const SizedBox(height: ZSpace.sm),
                _buildAiGradeLaunchCard(),
                const SizedBox(height: ZSpace.sm),
                ..._buildGradeGroups(),
                const SizedBox(height: ZSpace.md),
              ],
            ),
          ),
          _buildPresetBottomBar(),
        ],
      ),
    );
  }

  // ==================== 分类与预设流 ====================

  Widget _buildCategoryChips() {
    final zc = context.zc;
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final cat in _presetCategories()) ...[
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.sm),
              child: Builder(builder: (context) {
                final selected = cat == _filterCategory;
                final label = switch (cat) {
                  'mine' => l10n.wmPresetMine,
                  'builtin' => l10n.wmPresetBuiltin,
                  _ => L10n.tr(cat, l10n.localeName),
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (value) {
                    if (!value) return;
                    _updateState(() => _filterCategory = cat);
                  },
                  selectedColor: zc.accent,
                  backgroundColor: zc.surface,
                  labelStyle: TextStyle(
                    color: selected ? zc.onAccent : zc.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: selected ? zc.accent : zc.outline,
                    width: ZStroke.hairline,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  showCheckmark: false,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewModeToggle() {
    final zc = context.zc;
    final paged = AppSettings.instance.tabletFilterViewPaged;
    return IconButton(
      tooltip: paged
          ? context.l10n.wmViewModeListTooltip
          : context.l10n.wmViewModePagedTooltip,
      icon: Icon(
        paged ? Icons.auto_stories_outlined : Icons.view_agenda_outlined,
        size: 18,
        color: zc.textTertiary,
      ),
      onPressed: () {
        AppSettings.instance.setTabletFilterViewPaged(!paged);
        _updateState(() {});
      },
    );
  }

  Widget _buildPresetBrowser({required bool wide}) {
    if (AppSettings.instance.tabletFilterViewPaged) {
      return _buildPagedPresetBrowser();
    }
    return Scrollbar(
      controller: _filterScrollController,
      child: ListView.separated(
        controller: _filterScrollController,
        padding: const EdgeInsets.symmetric(horizontal: ZSpace.md),
        itemCount: _presetCards().length,
        separatorBuilder: (_, __) => const SizedBox(height: ZSpace.xs),
        itemBuilder: (context, index) {
          final card = _presetCards()[index];
          return SizedBox(height: 56, child: card);
        },
      ),
    );
  }

  Widget _buildPagedPresetBrowser() {
    final cards = _presetCards();
    const perPage = 6;
    final pages = (cards.length / perPage).ceil().clamp(1, 999);
    return PageView.builder(
      controller: _filterPageController,
      itemCount: pages,
      itemBuilder: (context, page) {
        final start = page * perPage;
        final end = math.min(start + perPage, cards.length);
        return GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.25,
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.md,
            vertical: ZSpace.xs,
          ),
          mainAxisSpacing: ZSpace.xs,
          crossAxisSpacing: ZSpace.sm,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = start; i < end; i++) cards[i],
          ],
        );
      },
    );
  }

  Widget _buildPresetStrip() {
    final cards = _presetCards();
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(width: ZSpace.xs + 2),
      itemBuilder: (context, index) => SizedBox(
        width: 98,
        child: cards[index],
      ),
    );
  }

  List<Widget> _presetCards() {
    final cards = <Widget>[_buildCustomCard()];
    if (_filterCategory == 'mine') {
      for (final preset in _userPresets) {
        cards.add(_buildPresetCard(preset));
      }
      cards.add(_buildSavePresetCard());
    } else if (_filterCategory == 'builtin') {
      for (final preset in kBuiltinGradePresets) {
        cards.add(_buildPresetCard(preset.toPreset()));
      }
    } else {
      for (final filter in PhotoFilterType.getByCategories(_filterCategory)) {
        cards.add(_buildFilterCard(filter));
      }
    }
    return cards;
  }

  Widget _buildCustomCard() {
    final zc = context.zc;
    final selected = _currentPresetId == 'custom';
    return _presetShell(
      selected: selected,
      onTap: () => _updateState(() => _currentPresetId = 'custom'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 12, color: selected ? zc.accent : zc.textTertiary),
              const Spacer(),
              if (selected) Icon(Icons.check_circle, size: 11, color: zc.accent),
            ],
          ),
          const SizedBox(height: 1.5),
          Text(
            context.l10n.commonCustom,
            style: TextStyle(
              color: selected ? zc.accent : zc.textPrimary,
              fontSize: 11,
              height: 1.12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            context.l10n.wmPresetCustomActive,
            style: TextStyle(color: zc.textTertiary, fontSize: 8.5, height: 1.08),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSavePresetCard() {
    final zc = context.zc;
    return _presetShell(
      accent: true,
      onTap: _showSavePresetDialog,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_add_outlined, size: 13, color: zc.accent),
          const SizedBox(height: 2),
          Text(
            context.l10n.wmPresetSaveNew,
            style: TextStyle(
              color: zc.accent,
              fontSize: 11,
              height: 1.12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(ColorGradePreset preset) {
    final zc = context.zc;
    final selected = _currentPresetId == preset.id;
    final isUser = !isBuiltinPresetId(preset.id);
    return _presetShell(
      selected: selected,
      onTap: () => _applyGradePreset(preset),
      onLongPress: isUser ? () => _showPresetActions(preset) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isUser ? Icons.person_outline : Icons.auto_awesome,
                size: 12,
                color: selected ? zc.accent : zc.textTertiary,
              ),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle, size: 11, color: zc.accent),
            ],
          ),
          const SizedBox(height: 1.5),
          Text(
            preset.name,
            style: TextStyle(
              color: selected ? zc.accent : zc.textPrimary,
              fontSize: 11,
              height: 1.12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            preset.summary,
            style: TextStyle(
              color: selected ? zc.accent.withAlpha(210) : zc.textTertiary,
              fontSize: 8.5,
              height: 1.08,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(PhotoFilterType filter) {
    final zc = context.zc;
    final selected = filter == _selectedFilter;
    return _presetShell(
      selected: selected,
      onTap: () {
        _disableSpektrafilm(notify: true);
        _updateState(() {
          _selectedFilter = filter;
          _filterIntensity = 1.0;
          _currentPresetId = 'custom';
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final c in filter.previewColors.take(3))
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 2.5),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
              const Spacer(),
              if (selected)
                Icon(Icons.check_circle, size: 11, color: zc.accent),
            ],
          ),
          const SizedBox(height: 1.5),
          Text(
            filter.trLabel,
            style: TextStyle(
              color: selected ? zc.accent : zc.textPrimary,
              fontSize: 11,
              height: 1.12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            filter.recipeSummary,
            style: TextStyle(
              color: selected ? zc.accent.withAlpha(210) : zc.textTertiary,
              fontSize: 8.5,
              height: 1.08,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _presetShell({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool selected = false,
    bool accent = false,
  }) {
    final zc = context.zc;
    final card = InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: ZRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: selected ? zc.accent.withAlpha(35) : zc.surface,
          borderRadius: ZRadius.brSm,
          border: Border.all(
            color: selected
                ? zc.accent
                : (accent ? zc.accent.withAlpha(160) : zc.outline),
            width: selected ? ZStroke.emphasis : ZStroke.hairline,
          ),
        ),
        child: child,
      ),
    );
    return card;
  }

  Widget _buildFilterIntensityBar() {
    final zc = context.zc;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(top: ZSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brSm,
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
              min: 0,
              max: 1,
              divisions: 20,
              activeColor: zc.accent,
              inactiveColor: zc.outline,
              onChanged: (value) {
                _disableSpektrafilm(notify: true);
                _updateState(() {
                  _filterIntensity = value;
                  _currentPresetId = 'custom';
                });
              },
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
          const SizedBox(width: ZSpace.sm),
          TextButton(
            onPressed: () {
              _updateState(() {
                _adjustments = _selectedFilter.presetAdjustments;
                _proGrade = _proGrade.copyWith(base: _adjustments);
                _currentPresetId = 'custom';
              });
              showZToast(
                context,
                l10n.wmLoadedFilterSlidersToast(_selectedFilter.trLabel),
              );
            },
            child: Text(l10n.wmDialTransferToGrade),
          ),
        ],
      ),
    );
  }

  Widget _buildFilmBypassHint() {
    final zc = context.zc;
    return Container(
      margin: const EdgeInsets.only(top: ZSpace.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.accentContainer,
        borderRadius: ZRadius.brSm,
      ),
      child: Row(
        children: [
          Icon(Icons.movie_filter_outlined, size: 16, color: zc.accent),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Text(
              context.l10n.wmPresetFilmBypassHint,
              style: TextStyle(color: zc.textSecondary, fontSize: 11),
            ),
          ),
          TextButton(
            onPressed: () => _disableSpektrafilm(),
            child: Text(context.l10n.spektraDisable),
          ),
        ],
      ),
    );
  }

  // ==================== 纵向分组滑块 ====================

  List<Widget> _buildGradeGroups() {
    final l = context.l10n;
    final items = {for (final item in _getGradeDialItems()) item.code: item};
    final groups = <_GradeGroupDef>[
      _GradeGroupDef(
        code: 'tone',
        title: l.wmGradeCatTone,
        icon: Icons.tonality_outlined,
        codes: const [
          'Exposure',
          'Contrast',
          'Highlights',
          'Shadows',
          'Whites',
          'Blacks',
        ],
      ),
      _GradeGroupDef(
        code: 'wb',
        title: l.wmGradeCatWb,
        icon: Icons.thermostat_outlined,
        codes: const ['Temp', 'Tint', 'Vibrance', 'Saturation'],
      ),
      _GradeGroupDef(
        code: 'presence',
        title: l.wmGradeCatPresence,
        icon: Icons.texture_outlined,
        codes: const ['Clarity', 'Texture', 'Dehaze'],
      ),
      _GradeGroupDef(
        code: 'split',
        title: l.wmGradeCatSplit,
        icon: Icons.color_lens_outlined,
        codes: const ['Hi-Hue', 'Hi-Sat', 'Sh-Hue', 'Sh-Sat'],
      ),
      _GradeGroupDef(
        code: 'effects',
        title: l.wmGradeCatEffects,
        icon: Icons.camera_outlined,
        codes: const ['Vignette', 'Grain'],
      ),
      _GradeGroupDef(
        code: 'detail',
        title: l.wmGradeCatDetail,
        icon: Icons.auto_fix_high_outlined,
        codes: const [],
      ),
    ];

    return [
      for (final group in groups)
        group.code == 'detail'
            ? _buildDetailGroup(group)
            : _buildGradeGroup(group, [
                for (final code in group.codes) items[code]!,
              ]),
    ];
  }

  Widget _buildGradeGroup(_GradeGroupDef group, List<_GradeDialItem> items) {
    final zc = context.zc;
    final collapsed = _collapsedGradeGroups.contains(group.code);
    return Container(
      margin: const EdgeInsets.only(bottom: ZSpace.sm),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brMd,
        border: Border.all(color: zc.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _updateState(() {
                if (collapsed) {
                  _collapsedGradeGroups.remove(group.code);
                } else {
                  _collapsedGradeGroups.add(group.code);
                }
              });
            },
            borderRadius: ZRadius.brMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpace.md,
                vertical: ZSpace.sm,
              ),
              child: Row(
                children: [
                  Icon(group.icon, size: 15, color: zc.textSecondary),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Text(
                      group.title,
                      style: TextStyle(
                        color: zc.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length}',
                    style: TextStyle(color: zc.textTertiary, fontSize: 11),
                  ),
                  const SizedBox(width: ZSpace.xs),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: zc.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            Divider(height: 1, color: zc.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpace.md,
                ZSpace.xs,
                ZSpace.md,
                ZSpace.xs,
              ),
              child: Column(
                children: [
                  for (final item in items) _buildGradeSliderRow(item),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailGroup(_GradeGroupDef group) {
    final zc = context.zc;
    final l = context.l10n;
    final collapsed = _collapsedGradeGroups.contains(group.code);
    final isRaw = _rawSourcePath != null && _rawSourcePath!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: ZSpace.sm),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brMd,
        border: Border.all(color: zc.outline),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              _updateState(() {
                if (collapsed) {
                  _collapsedGradeGroups.remove(group.code);
                } else {
                  _collapsedGradeGroups.add(group.code);
                }
              });
            },
            borderRadius: ZRadius.brMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpace.md,
                vertical: ZSpace.sm,
              ),
              child: Row(
                children: [
                  Icon(group.icon, size: 15, color: zc.textSecondary),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Text(
                      group.title,
                      style: TextStyle(
                        color: zc.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isRaw)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: zc.accentContainer,
                        borderRadius: ZRadius.brXs,
                      ),
                      child: Text(
                        'RAW',
                        style: TextStyle(
                          color: zc.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: ZSpace.xs),
                  Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: zc.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            Divider(height: 1, color: zc.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZSpace.md,
                ZSpace.xs,
                ZSpace.md,
                ZSpace.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isRaw) ...[
                    ZSlider(
                      label: l.wmDetailSharpening,
                      value: _proGrade.sharpening.clamp(0, 100),
                      min: 0,
                      max: 100,
                      defaultValue: 0,
                      icon: Icons.auto_fix_high,
                      dense: true,
                      onChanged: (value) => _updateState(() {
                        _proGrade = _proGrade.copyWith(
                          sharpening: value,
                          base: _adjustments,
                        );
                        _currentPresetId = 'custom';
                      }),
                    ),
                    ZSlider(
                      label: l.wmDetailNoiseReduction,
                      value: _proGrade.noiseReduction.clamp(0, 100),
                      min: 0,
                      max: 100,
                      defaultValue: 0,
                      icon: Icons.blur_on,
                      dense: true,
                      onChanged: (value) => _updateState(() {
                        _proGrade = _proGrade.copyWith(
                          noiseReduction: value,
                          base: _adjustments,
                        );
                        _currentPresetId = 'custom';
                      }),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: ZSpace.xs),
                      child: Text(
                        l.wmGradeDetailRawOnly,
                        style: TextStyle(
                          color: zc.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  _buildLutCard(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeSliderRow(_GradeDialItem item) {
    final value = item.getValue(_adjustments, _proGrade);
    return ZSlider(
      label: item.title(context.l10n),
      value: value,
      min: item.min,
      max: item.max,
      defaultValue: item.defaultValue,
      divisions: (item.max - item.min).round().clamp(10, 360),
      valueText: item.unit.isEmpty
          ? null
          : '${value.round()}${item.unit}',
      icon: item.icon,
      trackGradient: item.gradient,
      dense: true,
      onChanged: (next) => _onGradeSliderChanged(item, next),
    );
  }

  void _onGradeSliderChanged(_GradeDialItem item, double value) {
    _presetAnimController.stop();
    _presetAnimFrom = null;
    _presetAnimTo = null;
    _disableSpektrafilm(notify: true);
    _updateState(() {
      _adjustments = item.applyValue(_adjustments, value);
      _proGrade = _proGrade.copyWith(base: _adjustments);
      _currentPresetId = 'custom';
    });
  }

  Widget _buildLutCard() {
    final zc = context.zc;
    final l = context.l10n;
    final lut = _proGrade.lut;
    final hasLut = lut.path.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(ZSpace.md),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: zc.accent),
              const SizedBox(width: ZSpace.sm),
              Expanded(
                child: Text(
                  '3D LUT (.cube)',
                  style: TextStyle(
                    color: zc.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasLut)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.close, size: 16, color: zc.textTertiary),
                  onPressed: () => _updateState(() {
                    _proGrade = _proGrade.copyWith(lut: const LutRef());
                  }),
                ),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasLut ? lut.name : l.wmDialNoLutChosen,
                  style: TextStyle(
                    color: hasLut ? zc.accent : zc.textTertiary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: ZSpace.sm),
              OutlinedButton.icon(
                onPressed: () async {
                  final path = await CameraNativeBridge.pickFile();
                  if (path == null || path.isEmpty || !mounted) return;
                  _updateState(() {
                    _proGrade = _proGrade.copyWith(
                      lut: LutRef(
                        id: path,
                        name: path.split(RegExp(r'[\\/]')).last,
                        path: path,
                        strength: 1.0,
                      ),
                    );
                    _currentPresetId = 'custom';
                  });
                },
                icon: const Icon(Icons.folder_open, size: 14),
                label: Text(l.wmDialActiveLutButton),
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
            const SizedBox(height: ZSpace.sm),
            Row(
              children: [
                Text(
                  l.wmPresetIntensity,
                  style: TextStyle(color: zc.textSecondary, fontSize: 11),
                ),
                Expanded(
                  child: Slider(
                    value: lut.strength,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    activeColor: zc.accent,
                    inactiveColor: zc.outline,
                    onChanged: (value) => _updateState(() {
                      _proGrade = _proGrade.copyWith(
                        lut: lut.copyWith(strength: value),
                      );
                    }),
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

  Widget _buildAiGradeLaunchCard() {
    final zc = context.zc;
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: AiSettingsStore.instance,
      builder: (context, _) {
        final target = AiSettingsStore.instance.resolveGradeTarget();
        final isConfigured =
            !AiSettingsStore.instance.isTargetMissingApiKey(target);
        final subText = isConfigured
            ? '${target!.profile.name} · ${target.modelId}'
            : l10n.aiGradeLaunchSetupSub;
        return Material(
          color: zc.accentContainer,
          borderRadius: ZRadius.brMd,
          child: InkWell(
            onTap: _openAiGradeSheet,
            borderRadius: ZRadius.brMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: ZSpace.md,
                vertical: ZSpace.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: ZRadius.brMd,
                border: Border.all(
                  color: isConfigured
                      ? zc.accent.withAlpha(110)
                      : zc.warning.withAlpha(130),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: zc.accent.withAlpha(24),
                      borderRadius: ZRadius.brSm,
                    ),
                    child: AiSvgIcon(
                      AiSvgIconKind.sparkleAperture,
                      color: zc.accent,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.aiGradeButton,
                          style: TextStyle(
                            color: zc.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subText,
                          style: TextStyle(
                            color: zc.textSecondary,
                            fontSize: 10.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!isConfigured) ...[
                    const SizedBox(width: ZSpace.xs),
                    ZTag(
                      text: l10n.aiApiKeyNotConfiguredShort,
                      compact: true,
                      color: zc.warning,
                      isOutline: true,
                    ),
                  ],
                  const SizedBox(width: ZSpace.xxs),
                  Icon(Icons.chevron_right_rounded, color: zc.accent, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyAiGradePayload(AiGradeApplyPayload payload) {
    final v = payload.variant;
    final catalog = AiRecipeCatalog.buildAll(spektraStocks: _spektraStocks);
    final entry = v.recipeId != null ? catalog.resolve(v.recipeId) : null;

    if (entry?.kind == AiGradeRecipeKind.spektraFilm &&
        entry?.spektraStockId != null &&
        !_spektraCatalogUnavailable &&
        _spektraStocks.any((s) => s.id == entry!.spektraStockId)) {
      final stockId = entry!.spektraStockId!;
      final stock = _spektraStocks.where((s) => s.id == stockId);
      var paperId = _spektrafilm.paperId;
      if (paperId != kSpektraDirectScanPaperId &&
          !_spektraPapers.any((p) => p.id == paperId)) {
        paperId = kSpektraDirectScanPaperId;
      }
      if (stock.isNotEmpty && stock.first.targetPrint.isNotEmpty) {
        final target = stock.first.targetPrint;
        if (_spektraPapers.any((p) => p.id == target)) {
          paperId = target;
        }
      }
      _setSpektrafilm(
        _spektrafilm
            .withStock(stockId, paperId: paperId)
            .copyWith(intensity: payload.effectiveRecipeIntensity),
      );
      _updateState(() {
        _adjustments = payload.scaledAdjustments;
        _selectedFilter = PhotoFilterType.original;
        _filterIntensity = 0.0;
        _currentPresetId = 'ai_${entry.id}';
      });
      return;
    }

    _disableSpektrafilm(notify: false);

    if (entry?.kind == AiGradeRecipeKind.filter && entry?.filterType != null) {
      _updateState(() {
        _selectedFilter = entry!.filterType!;
        _filterIntensity = payload.effectiveRecipeIntensity;
        _adjustments = payload.scaledAdjustments;
        _currentPresetId = 'ai_${entry.id}';
      });
      return;
    }

    if (entry?.kind == AiGradeRecipeKind.builtinPreset &&
        entry?.builtinPreset != null) {
      final presetBase = entry!.builtinPreset!.grade.base;
      _updateState(() {
        _proGrade = entry.builtinPreset!.grade;
        _selectedFilter = PhotoFilterType.original;
        _filterIntensity = 0.0;
        _adjustments = AiColorGrader.combineAdjustments(
          presetBase,
          payload.scaledAdjustments,
        );
        _currentPresetId = 'ai_${entry.id}';
      });
      return;
    }

    _updateState(() {
      _adjustments = payload.scaledAdjustments;
      _selectedFilter = PhotoFilterType.original;
      _filterIntensity = 1.0;
      _currentPresetId = 'custom';
    });
  }

  Future<Uint8List> _encodeFastAiPreviewJpeg(
    ui.Image source, {
    int maxEdge = 640,
    int quality = 74,
  }) async {
    final sw = source.width;
    final sh = source.height;
    final longest = math.max(sw, sh);
    final double scale = longest > maxEdge ? maxEdge / longest : 1.0;
    final targetW = math.max(1, (sw * scale).round());
    final targetH = math.max(1, (sh * scale).round());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, sw.toDouble(), sh.toDouble()),
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(targetW, targetH);
    picture.dispose();
    final byteData =
        await resized.toByteData(format: ui.ImageByteFormat.rawRgba);
    resized.dispose();
    if (byteData == null) return Uint8List(0);
    final rgbaCopy = Uint8List.fromList(byteData.buffer.asUint8List());
    return Isolate.run(() {
      final im = img.Image.fromBytes(
        width: targetW,
        height: targetH,
        bytes: rgbaCopy.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      return Uint8List.fromList(img.encodeJpg(im, quality: quality));
    });
  }

  Future<void> _openAiGradeSheet() async {
    final l10n = context.l10n;
    final image = _decodedImage;
    if (image == null) {
      showZToast(context, l10n.aiGradeNoImage, tone: ZStatusTone.warning);
      return;
    }

    if (_spektraStocks.isEmpty && !_spektraCatalogUnavailable) {
      await _loadSpektraCatalog().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    if (!mounted) return;

    final bytes = await _encodeFastAiPreviewJpeg(image);
    if (!mounted || bytes.isEmpty) return;

    final r = _sourceSampledR ?? _sampledR ?? const <int>[];
    final g = _sourceSampledG ?? _sampledG ?? const <int>[];
    final b = _sourceSampledB ?? _sampledB ?? const <int>[];
    final stats = ImageColorStats.fromRgbSamples(r, g, b);

    final appliedName = await showAiGradeModal(
      context: context,
      imageBytes: bytes,
      stats: stats,
      metadata: _metadata,
      spektraStocks: _spektraStocks,
      preResizedJpeg: true,
      onPreviewPayload: _applyAiGradePayload,
      onToggleCompareOriginal: (comparing) {
        _updateState(() => _isComparingOriginal = comparing);
      },
      onSavePreset: (payload, name) async {
        _applyAiGradePayload(payload);
        await _savePreset(name, null, false);
      },
    );

    if (mounted) {
      _updateState(() => _isComparingOriginal = false);
      if (appliedName != null && appliedName.isNotEmpty) {
        showZToast(
          context,
          l10n.aiGradeAppliedToast(appliedName),
          tone: ZStatusTone.success,
        );
      }
    }
  }

  // ==================== 底部操作条 ====================

  Widget _buildPresetBottomBar() {
    final zc = context.zc;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZSpace.md,
        ZSpace.sm,
        ZSpace.md,
        ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(top: BorderSide(color: zc.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () {
                _presetAnimController.stop();
                _presetAnimFrom = null;
                _presetAnimTo = null;
                _updateState(() {
                  _adjustments = const PhotoEditAdjustments();
                  _proGrade = const ColorGrade();
                  _selectedFilter = PhotoFilterType.original;
                  _filterIntensity = 1.0;
                  _currentPresetId = 'custom';
                });
              },
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(l.wmDialResetAll),
            ),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: _showSavePresetDialog,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(
                  l.wmPresetSaveNew,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 预设管理弹窗 ====================

  Future<void> _showSavePresetDialog() async {
    final l = context.l10n;
    final zc = context.zc;
    final controller = TextEditingController();
    final current = _userPresets.where((p) => p.id == _currentPresetId);
    final overwriteTarget = current.isEmpty ? null : current.first;
    var overwrite = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(l.presetSaveDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l.wmDialSavePresetPrompt,
                      isDense: true,
                    ),
                  ),
                  if (overwriteTarget != null) ...[
                    const SizedBox(height: ZSpace.sm),
                    CheckboxListTile(
                      value: overwrite,
                      onChanged: (value) {
                        setDialogState(() => overwrite = value ?? false);
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        l.wmPresetOverwrite,
                        style: TextStyle(color: zc.textSecondary, fontSize: 12),
                      ),
                      subtitle: Text(
                        overwriteTarget.name,
                        style: TextStyle(color: zc.textTertiary, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l.commonCancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) return;
                    Navigator.of(dialogContext).pop();
                    await _savePreset(name, overwriteTarget, overwrite);
                  },
                  child: Text(l.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _savePreset(
    String name,
    ColorGradePreset? target,
    bool overwrite,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ColorGradePreset preset;
    if (overwrite && target != null) {
      preset = target.copyWith(
        name: name,
        grade: _proGrade.copyWith(base: _adjustments),
        updatedAtMs: now,
      );
    } else {
      preset = ColorGradePreset(
        id: 'user_$now',
        name: name,
        grade: _proGrade.copyWith(base: _adjustments),
        createdAtMs: now,
        updatedAtMs: now,
      );
    }
    final presets = await ColorGradePresetStore.upsert(preset);
    if (!mounted) return;
    _updateState(() {
      _userPresets = presets;
      _currentPresetId = preset.id;
      _filterCategory = 'mine';
    });
    if (mounted) showZToast(context, context.l10n.wmDialSavePresetSuccess(name));
  }

  Future<void> _showPresetActions(ColorGradePreset preset) async {
    final l = context.l10n;
    final zc = context.zc;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: zc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  ZSpace.lg,
                  ZSpace.md,
                  ZSpace.lg,
                  ZSpace.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: zc.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: Text(l.wmPresetRename),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showRenamePresetDialog(preset);
                },
              ),
              ListTile(
                leading: const Icon(Icons.save_as_outlined),
                title: Text(l.wmPresetOverwrite),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final presets = await ColorGradePresetStore.upsert(
                    preset.copyWith(
                      grade: _proGrade.copyWith(base: _adjustments),
                      updatedAtMs: now,
                    ),
                  );
                  if (!mounted) return;
                  _updateState(() => _userPresets = presets);
                  if (mounted) {
                    showZToast(
                      context,
                      context.l10n.wmDialSavePresetSuccess(preset.name),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: zc.danger),
                title: Text(
                  l.commonDelete,
                  style: TextStyle(color: zc.danger),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDeletePreset(preset);
                },
              ),
              const SizedBox(height: ZSpace.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenamePresetDialog(ColorGradePreset preset) async {
    final l = context.l10n;
    final controller = TextEditingController(text: preset.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.wmPresetRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(isDense: true),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final presets = await ColorGradePresetStore.rename(preset.id, name);
    if (!mounted) return;
    _updateState(() => _userPresets = presets);
    if (mounted) showZToast(context, context.l10n.wmPresetRenamedToast(name));
  }

  Future<void> _confirmDeletePreset(ColorGradePreset preset) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.wmPresetDeleteTitle),
        content: Text(l.wmPresetDeleteConfirm(preset.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.zc.danger,
            ),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final presets = await ColorGradePresetStore.remove(preset.id);
    if (!mounted) return;
    _updateState(() => _userPresets = presets);
    if (mounted) showZToast(context, context.l10n.wmPresetDeletedToast);
  }
}
