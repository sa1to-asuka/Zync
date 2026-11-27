part of '../watermark_screen.dart';

extension _WatermarkScreenArtTextPanel on WatermarkScreenState {
  static const List<String> _exifTokenChips = <String>[
    '{model}',
    '{lens}',
    '{focal}',
    '{aperture}',
    '{shutter}',
    '{iso}',
    '{date}',
    '{gps}',
  ];

  static const List<int> _artColorPresets = <int>[
    0xFFFFFFFF,
    0xFF101216,
    0xFFFFD100,
    0xFFF5F1E8,
    0xFFC82829,
    0xFF37C6FF,
  ];

  WatermarkTextLayer? get _selectedArtLayer {
    final id = _selectedTextLayerId;
    if (id == null) return null;
    for (final l in _textLayers) {
      if (l.id == id) return l;
    }
    return null;
  }

  void _addNewArtTextLayer() {
    final id = 'txt_${DateTime.now().microsecondsSinceEpoch}';
    final isDarkCard = _selectedTemplate == WatermarkTemplate.none ||
        _cardDark ||
        _selectedTemplate.defaultCardDark;
    final layer = WatermarkTextLayer(
      id: id,
      text: 'Shot on {model} · {focal} {aperture}',
      nx: 0.5,
      ny: _selectedTemplate == WatermarkTemplate.none ? 0.86 : 0.90,
      fontId: 'playfair',
      colorValue: isDarkCard ? 0xFFFFFFFF : 0xFF14161A,
    );
    _updateState(() {
      _textLayers = [..._textLayers, layer];
      _selectedTextLayerId = id;
    });
    _editArtTextLayerDialog(layer);
  }

  void _updateArtTextLayer(WatermarkTextLayer updated) {
    _updateState(() {
      _textLayers = [
        for (final l in _textLayers)
          if (l.id == updated.id) updated else l,
      ];
    });
  }

  void _deleteArtTextLayer(String id) {
    _updateState(() {
      _textLayers = _textLayers.where((l) => l.id != id).toList();
      if (_selectedTextLayerId == id) {
        _selectedTextLayerId =
            _textLayers.isNotEmpty ? _textLayers.last.id : null;
      }
    });
  }

  Future<void> _editArtTextLayerDialog(WatermarkTextLayer layer) async {
    final l10n = context.l10n;
    final zc = context.zc;
    final ctrl = TextEditingController(text: layer.text);
    final result = await showZDialog<String>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.wmArtEditText,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(hintText: l10n.wmArtTextHint),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.wmArtExifTokens,
              style: TextStyle(color: zc.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tok in _exifTokenChips)
                  ActionChip(
                    label: Text(
                      tok,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    onPressed: () {
                      final cur = ctrl.text;
                      final sep = cur.isEmpty || cur.endsWith(' ') ? '' : ' ';
                      ctrl.text = '$cur$sep$tok';
                      ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: ctrl.text.length),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          ZButton(
            label: l10n.commonCancel,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(ctx),
          ),
          ZButton(
            label: l10n.commonApply,
            onTap: () => Navigator.pop(ctx, ctrl.text),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && mounted) {
      _updateArtTextLayer(layer.copyWith(text: result));
    }
  }

  Future<void> _saveCurrentWatermarkPreset() async {
    final l10n = context.l10n;
    final ctrl = TextEditingController();
    final name = await showZDialog<String>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.wmArtSavePreset,
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.wmArtPresetNameHint),
        ),
        actions: [
          ZButton(
            label: l10n.commonCancel,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(ctx),
          ),
          ZButton(
            label: l10n.commonSave,
            onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    final preset = WatermarkCustomPreset(
      id: 'wm_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      templateId: _selectedTemplate.id,
      cardColorValue: _cardColorOverride?.toARGB32(),
      textColorValue: _textColorOverride?.toARGB32(),
      accentColorValue: _accentColor.toARGB32(),
      textLayers: _textLayers,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    final next = await WatermarkPresetStore.upsert(preset);
    if (!mounted) return;
    _updateState(() => _customWatermarkPresets = next);
    showZToast(context, l10n.wmArtPresetSavedToast, tone: ZStatusTone.success);
  }

  void _applyCustomWatermarkPreset(WatermarkCustomPreset preset) {
    final t = preset.template;
    _updateState(() {
      _selectedTemplate = t;
      _cardColorOverride = preset.cardColorValue == null
          ? null
          : ZSwatch.fromArgb32(preset.cardColorValue!);
      _textColorOverride = preset.textColorValue == null
          ? null
          : ZSwatch.fromArgb32(preset.textColorValue!);
      _accentColor = ZSwatch.fromArgb32(preset.accentColorValue);
      _cardDark = t.defaultCardDark;
      _textDark = t.defaultTextDark;
      _textLayers = List.of(preset.textLayers);
      _selectedTextLayerId =
          _textLayers.isNotEmpty ? _textLayers.first.id : null;
    });
  }

  Widget _buildArtTextControlsPanel() {
    final zc = context.zc;
    final l10n = context.l10n;
    final selected = _selectedArtLayer;
    final fontManager = WatermarkFontManager.instance;
    final currentFontEntry =
        selected == null ? null : fontManager.findById(selected.fontId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部操作条：添加艺术字 / 保存自定义水印预设
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _addNewArtTextLayer,
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.wmArtAddText),
            ),
            OutlinedButton.icon(
              onPressed: _saveCurrentWatermarkPreset,
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: Text(l10n.wmArtSavePreset),
            ),
          ],
        ),
        if (_customWatermarkPresets.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l10n.wmArtMyPresets,
            style: TextStyle(color: zc.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in _customWatermarkPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(p.name, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _applyCustomWatermarkPreset(p),
                      onDeleted: () async {
                        final next = await WatermarkPresetStore.remove(p.id);
                        if (mounted) {
                          _updateState(() => _customWatermarkPresets = next);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (_textLayers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: BorderRadius.circular(ZRadius.sm),
              border: Border.all(color: zc.outline),
            ),
            child: Text(
              l10n.wmArtEmptyHint,
              style: TextStyle(color: zc.textSecondary, fontSize: 12),
            ),
          )
        else ...[
          // 图层切换胶囊
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in _textLayers)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        resolveWatermarkExifTokens(l.text, _metadata),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: l.id == _selectedTextLayerId,
                      onSelected: (_) =>
                          _updateState(() => _selectedTextLayerId = l.id),
                    ),
                  ),
              ],
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 10),
            // 字体选择（打开内置 + GitHub 云端字体商店 + 本地导入）+ 文案编辑 + 竖排开关
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editArtTextLayerDialog(selected),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(l10n.wmArtEditText),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showWatermarkFontStoreSheet(
                      context,
                      currentFontId: selected.fontId,
                    );
                    if (picked != null && mounted) {
                      _updateArtTextLayer(selected.copyWith(fontId: picked));
                    }
                  },
                  icon: const Icon(Icons.font_download_outlined, size: 15),
                  label: Text(
                    currentFontEntry?.displayName ?? l10n.wmArtFontTitle,
                  ),
                ),
                FilterChip(
                  label: Text(l10n.wmArtVerticalToggle),
                  selected: selected.vertical,
                  onSelected: (v) =>
                      _updateArtTextLayer(selected.copyWith(vertical: v)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 颜色选点
            Row(
              children: [
                for (final argb in _artColorPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _updateArtTextLayer(
                          selected.copyWith(colorValue: argb)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: ZSwatch.fromArgb32(argb),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected.colorValue == argb
                                ? zc.accent
                                : zc.outline,
                            width: selected.colorValue == argb ? 2.2 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  tooltip: l10n.commonCustom,
                  onPressed: () async {
                    final picked = await showWatermarkColorPicker(
                        context, selected.colorValue);
                    if (picked != null && mounted) {
                      _updateArtTextLayer(
                          selected.copyWith(colorValue: picked));
                    }
                  },
                  icon: const Icon(Icons.colorize),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 样式框 / 印章选择
            Text(
              l10n.wmArtBgStyle,
              style: TextStyle(color: zc.textSecondary, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in [
                  (OverlayBgStyle.none, l10n.wmArtBgNone),
                  (OverlayBgStyle.glassPill, l10n.wmArtBgPill),
                  (OverlayBgStyle.solidTag, l10n.wmArtBgTag),
                  (OverlayBgStyle.vermilionSealYang, l10n.wmArtBgSealYang),
                  (OverlayBgStyle.vermilionSealYin, l10n.wmArtBgSealYin),
                  (OverlayBgStyle.cinemaBar, l10n.wmArtBgCinema),
                ])
                  ChoiceChip(
                    label: Text(entry.$2, style: const TextStyle(fontSize: 11)),
                    selected: selected.bgStyle == entry.$1,
                    onSelected: (_) {
                      // 切换到朱红印章时顺手给出协调默认文字色
                      var nextColor = selected.colorValue;
                      if (entry.$1 == OverlayBgStyle.vermilionSealYang) {
                        nextColor = 0xFFC82829;
                      } else if (entry.$1 == OverlayBgStyle.vermilionSealYin) {
                        nextColor = 0xFFFFFFFF;
                      }
                      _updateArtTextLayer(selected.copyWith(
                        bgStyle: entry.$1,
                        colorValue: nextColor,
                      ));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _artSlider(
              l10n.wmArtOpacityLabel,
              selected.opacity,
              0.1,
              1.0,
              (v) => _updateArtTextLayer(selected.copyWith(opacity: v)),
            ),
            _artSlider(
              l10n.wmArtStrokeLabel,
              selected.strokeWidth,
              0.0,
              6.0,
              (v) => _updateArtTextLayer(selected.copyWith(
                strokeWidth: v,
                strokeColorValue:
                    selected.strokeColorValue ?? 0xFF000000,
              )),
            ),
            _artSlider(
              l10n.wmArtShadowLabel,
              selected.shadowBlur,
              0.0,
              20.0,
              (v) => _updateArtTextLayer(selected.copyWith(shadowBlur: v)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _artSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final zc = context.zc;
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: TextStyle(color: zc.textSecondary, fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: zc.accent,
            inactiveColor: zc.outline,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
