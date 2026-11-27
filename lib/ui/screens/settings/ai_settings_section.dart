import 'package:flutter/material.dart';

import '../../../engine/ai/ai_model_discovery.dart';
import '../../../engine/ai/ai_provider_config.dart';
import '../../../engine/ai/ai_vision_client.dart';
import '../../../l10n/l10n.dart';
import '../../design/design.dart';
import '../../widgets/ai_api_key_guide.dart';
import '../../widgets/ai_svg_icons.dart';

/// AI 视觉引擎与 API Key 管理详情页：
/// 选择 OpenAI / Anthropic 兼容协议 → 填写 Base URL & API Key → 拉取或手动添加模型 →
/// 勾选导入 → 分别指派取景助手与 AI 调色模型。
class AiSettingsDetailContent extends StatefulWidget {
  const AiSettingsDetailContent({super.key});

  @override
  State<AiSettingsDetailContent> createState() =>
      _AiSettingsDetailContentState();
}

class _AiSettingsDetailContentState extends State<AiSettingsDetailContent> {
  final AiSettingsStore _store = AiSettingsStore.instance;
  final AiModelDiscovery _discovery = AiModelDiscovery();

  @override
  void initState() {
    super.initState();
    _store.ensureInitialized();
  }

  Future<void> _openProfileEditor([AiProviderProfile? existing]) async {
    final zc = context.zc;
    final screenW = MediaQuery.sizeOf(context).width;
    final isWide = context.zb.isTwoPane || screenW >= 640;

    if (isWide) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: zc.surfaceElevated,
          insetPadding: const EdgeInsets.all(ZSpace.xl),
          shape: RoundedRectangleBorder(
            borderRadius: ZRadius.brLg,
            side: BorderSide(color: zc.outline, width: 0.8),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
            ),
            child: _AiProfileEditorSheet(
              store: _store,
              discovery: _discovery,
              existing: existing,
              isDialog: true,
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: zc.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (ctx) => _AiProfileEditorSheet(
        store: _store,
        discovery: _discovery,
        existing: existing,
        isDialog: false,
      ),
    );
  }

  List<({AiProviderProfile profile, AiImportedModel model})>
      _allImportedModels() {
    final list = <({AiProviderProfile profile, AiImportedModel model})>[];
    for (final p in _store.profiles) {
      for (final m in p.importedModels) {
        list.add((profile: p, model: m));
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AnimatedBuilder(
      animation: _store,
      builder: (context, _) {
        final candidates = _allImportedModels();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZSection(
              title: l10n.aiActiveModelsSection,
              children: [
                _buildActiveModelSelector(
                  title: l10n.aiCoachModelLabel,
                  icon: Icons.center_focus_strong_outlined,
                  selectedProfileId: _store.activeCoachProfileId,
                  selectedModelId: _store.activeCoachModelId,
                  candidates: candidates,
                  onSelected: (pId, mId) => _store.setActiveCoach(pId, mId),
                ),
                _buildActiveModelSelector(
                  title: l10n.aiGradeModelLabel,
                  icon: Icons.auto_awesome_outlined,
                  selectedProfileId: _store.activeGradeProfileId,
                  selectedModelId: _store.activeGradeModelId,
                  candidates: candidates,
                  onSelected: (pId, mId) => _store.setActiveGrade(pId, mId),
                ),
              ],
            ),
            ZSection(
              title: l10n.aiProfilesSection,
              children: [
                for (final p in _store.profiles) _buildProfileTile(p),
                ZTile(
                  leadingIcon: Icons.add_circle_outline_rounded,
                  title: l10n.aiAddProfileButton,
                  isLink: true,
                  onTap: () => _openProfileEditor(),
                ),
                ZTile(
                  leadingIcon: Icons.menu_book_outlined,
                  title: l10n.aiViewTutorialBtn,
                  subtitle: l10n.aiGuideModalTitle,
                  isLink: true,
                  showDivider: false,
                  onTap: () => showAiApiKeyTutorialModal(context),
                ),
              ],
            ),
            ZSection(
              title: l10n.settingsWirelessTitle,
              footer: l10n.aiSecurityFootnote,
              children: [
                ZTile(
                  leadingIcon: Icons.cell_tower_outlined,
                  title: l10n.aiCellularBypassTitle,
                  subtitle: l10n.aiCellularBypassSub,
                  trailing: Switch(
                    value: _store.allowCellularBypassInAp,
                    onChanged: (v) =>
                        _store.setNetworkPreferences(allowCellularBypassInAp: v),
                  ),
                ),
                ZTile(
                  leadingIcon: Icons.tune_outlined,
                  title: l10n.aiIncludeTelemetryTitle,
                  subtitle: l10n.aiIncludeTelemetrySub,
                  trailing: Switch(
                    value: _store.includeExifTelemetry,
                    onChanged: (v) =>
                        _store.setNetworkPreferences(includeExifTelemetry: v),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveModelSelector({
    required String title,
    required IconData icon,
    required String? selectedProfileId,
    required String? selectedModelId,
    required List<({AiProviderProfile profile, AiImportedModel model})>
        candidates,
    required void Function(String profileId, String modelId) onSelected,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;
    final current = candidates
        .where((c) =>
            c.profile.id == selectedProfileId && c.model.id == selectedModelId)
        .firstOrNull;
    final valueText = current == null
        ? l10n.aiModelUnselected
        : '${current.profile.name} · ${current.model.displayName}';

    return PopupMenuButton<({String profileId, String modelId})>(
      enabled: candidates.isNotEmpty,
      color: zc.surfaceElevated,
      onSelected: (pair) => onSelected(pair.profileId, pair.modelId),
      itemBuilder: (_) => [
        for (final c in candidates)
          PopupMenuItem(
            value: (profileId: c.profile.id, modelId: c.model.id),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.model.displayName} (${c.profile.name})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (c.profile.id == selectedProfileId &&
                    c.model.id == selectedModelId)
                  Icon(Icons.check_rounded, size: 16, color: zc.accent),
              ],
            ),
          ),
      ],
      child: ZTile(
        leadingIcon: icon,
        title: title,
        subtitle: valueText,
        isLink: candidates.isNotEmpty,
      ),
    );
  }

  Widget _buildProfileTile(AiProviderProfile profile) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final masked = AiSettingsStore.maskApiKey(_store.cachedApiKey(profile.id));
    final protoLabel = profile.protocol == AiApiProtocol.openAiCompatible
        ? l10n.aiProtocolOpenAi
        : l10n.aiProtocolAnthropic;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZSpace.lg,
        ZSpace.md,
        ZSpace.sm,
        ZSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: zt.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$protoLabel · ${profile.baseUrl}'
                      '${masked.isNotEmpty ? ' · $masked' : ''}',
                      style: zt.caption.copyWith(color: zc.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: zc.textSecondary,
                ),
                tooltip: l10n.commonEdit,
                onPressed: () => _openProfileEditor(profile),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: zc.danger),
                tooltip: l10n.commonDelete,
                onPressed: () => _store.deleteProfile(profile.id),
              ),
            ],
          ),
          if (profile.importedModels.isNotEmpty) ...[
            const SizedBox(height: ZSpace.sm),
            Wrap(
              spacing: ZSpace.xs + 2,
              runSpacing: ZSpace.xs + 2,
              children: [
                for (final m in profile.importedModels)
                  _buildModelChip(profile, m),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelChip(AiProviderProfile profile, AiImportedModel m) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final isCoach = _store.activeCoachProfileId == profile.id &&
        _store.activeCoachModelId == m.id;
    final isGrade = _store.activeGradeProfileId == profile.id &&
        _store.activeGradeModelId == m.id;
    final isActive = isCoach || isGrade;

    return PopupMenuButton<String>(
      color: zc.surfaceElevated,
      onSelected: (act) {
        if (act == 'coach') {
          _store.setActiveCoach(profile.id, m.id);
        } else if (act == 'grade') {
          _store.setActiveGrade(profile.id, m.id);
        } else if (act == 'remove') {
          final left =
              profile.importedModels.where((e) => e.id != m.id).toList();
          _store.upsertProfile(profile.copyWith(importedModels: left));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'coach', child: Text(l10n.aiSetAsCoach)),
        PopupMenuItem(value: 'grade', child: Text(l10n.aiSetAsGrade)),
        PopupMenuItem(value: 'remove', child: Text(l10n.commonRemove)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? zc.accentContainer : zc.surfaceHigh,
          borderRadius: ZRadius.brSm,
          border: Border.all(
            color: isActive ? zc.accent : zc.outline,
            width: isActive ? 1.0 : 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCoach) ...[
              Icon(
                Icons.center_focus_strong_outlined,
                size: 13,
                color: zc.accent,
              ),
              const SizedBox(width: 4),
            ],
            if (isGrade) ...[
              Icon(Icons.auto_awesome_outlined, size: 13, color: zc.accent),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                m.displayName,
                style: zt.mono.copyWith(
                  fontSize: 12,
                  color: isActive ? zc.accent : zc.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.more_horiz_rounded,
              size: 15,
              color: zc.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiProfileEditorSheet extends StatefulWidget {
  final AiSettingsStore store;
  final AiModelDiscovery discovery;
  final AiProviderProfile? existing;
  final bool isDialog;

  const _AiProfileEditorSheet({
    required this.store,
    required this.discovery,
    this.existing,
    this.isDialog = false,
  });

  @override
  State<_AiProfileEditorSheet> createState() => _AiProfileEditorSheetState();
}

class _AiProfileEditorSheetState extends State<_AiProfileEditorSheet> {
  late AiApiProtocol _protocol;
  late TextEditingController _nameCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _keyCtrl;
  final TextEditingController _manualModelCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _obscureKey = true;
  bool _fetching = false;
  bool _nameInitialized = false;
  String? _fetchError;
  List<DiscoveredAiModel> _discovered = const [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _protocol = e?.protocol ?? AiApiProtocol.openAiCompatible;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _urlCtrl = TextEditingController(
      text: e?.baseUrl ?? 'https://api.openai.com/v1',
    );
    _keyCtrl = TextEditingController();
    if (e != null) {
      _nameInitialized = true;
      for (final m in e.importedModels) {
        _selectedIds.add(m.id);
      }
      _discovered = [
        for (final m in e.importedModels)
          DiscoveredAiModel(
            id: m.id,
            displayName: m.displayName,
            likelyVision: m.visionHint,
          ),
      ];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameInitialized) {
      _nameInitialized = true;
      _nameCtrl.text = _protocol == AiApiProtocol.openAiCompatible
          ? context.l10n.aiProtocolOpenAi
          : context.l10n.aiProtocolAnthropic;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _manualModelCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _effectiveKeyForFetch() {
    final typed = _keyCtrl.text.trim();
    if (typed.isNotEmpty) return typed;
    if (widget.existing != null) {
      return widget.store.cachedApiKey(widget.existing!.id);
    }
    return '';
  }

  Future<void> _fetchModels() async {
    setState(() {
      _fetching = true;
      _fetchError = null;
    });
    try {
      final list = await widget.discovery.fetchAvailableModels(
        protocol: _protocol,
        baseUrl: _urlCtrl.text,
        apiKey: _effectiveKeyForFetch(),
      );
      if (!mounted) return;
      final merged = <String, DiscoveredAiModel>{
        for (final d in list) d.id: d,
      };
      for (final old in _discovered) {
        if (_selectedIds.contains(old.id)) {
          merged.putIfAbsent(old.id, () => old);
        }
      }
      setState(() {
        _discovered = merged.values.toList();
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _fetchError = AiVisionClient.sanitizeForLog(
          '$e',
          secretKey: _effectiveKeyForFetch(),
        );
      });
    }
  }

  void _addManualModel() {
    final id = _manualModelCtrl.text.trim();
    if (id.isEmpty) return;
    _manualModelCtrl.clear();
    setState(() {
      if (!_discovered.any((e) => e.id == id)) {
        _discovered = [
          DiscoveredAiModel(
            id: id,
            displayName: id,
            likelyVision: true,
          ),
          ..._discovered,
        ];
      }
      _selectedIds.add(id);
    });
  }

  Future<void> _save() async {
    final id = widget.existing?.id ??
        'ai_${DateTime.now().millisecondsSinceEpoch}';
    final existingMap = {
      for (final m
          in widget.existing?.importedModels ?? const <AiImportedModel>[])
        m.id: m,
    };
    final discMap = {for (final d in _discovered) d.id: d};
    final imported = <AiImportedModel>[];
    for (final mid in _selectedIds) {
      final prev = existingMap[mid];
      final d = discMap[mid];
      imported.add(
        prev ??
            AiImportedModel(
              id: mid,
              displayName: d?.displayName ?? mid,
              visionHint: true,
            ),
      );
    }
    final fallbackName = _protocol == AiApiProtocol.openAiCompatible
        ? context.l10n.aiProtocolOpenAi
        : context.l10n.aiProtocolAnthropic;
    final profile = AiProviderProfile(
      id: id,
      name: _nameCtrl.text.trim().isEmpty
          ? fallbackName
          : _nameCtrl.text.trim(),
      protocol: _protocol,
      baseUrl: AiProviderProfile.normalizeBaseUrl(_urlCtrl.text),
      importedModels: imported,
    );
    final typedKey = _keyCtrl.text.trim();
    await widget.store.upsertProfile(
      profile,
      apiKey:
          (widget.existing == null || typedKey.isNotEmpty) ? typedKey : null,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildPresetChip(AiEndpointQuickPreset preset, String lang) {
    final zc = context.zc;
    final zt = context.zt;
    final label = preset.localizedName(lang);
    final isSelected =
        AiProviderProfile.normalizeBaseUrl(_urlCtrl.text) ==
                preset.defaultBaseUrl &&
            _protocol == preset.protocol;
    return ChoiceChip(
      label: Text(
        label,
        style: zt.caption.copyWith(
          color: isSelected ? zc.accent : zc.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: zc.accentContainer,
      backgroundColor: zc.surfaceHigh,
      side: BorderSide(
        color: isSelected ? zc.accent : zc.outline,
        width: 0.8,
      ),
      onSelected: (_) => setState(() {
        _protocol = preset.protocol;
        _nameCtrl.text = label;
        _urlCtrl.text = preset.defaultBaseUrl;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final existingMasked = widget.existing == null
        ? ''
        : AiSettingsStore.maskApiKey(
            widget.store.cachedApiKey(widget.existing!.id),
          );

    final query = _searchCtrl.text.trim().toLowerCase();
    final visibleModels = _discovered.where((m) {
      if (query.isNotEmpty && !m.id.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.existing == null
                    ? l10n.aiAddProfileButton
                    : widget.existing!.name,
                style: zt.headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: zc.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Divider(height: 1, color: zc.outlineVariant),
        const SizedBox(height: ZSpace.md),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.aiProtocolLabel,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
                const SizedBox(height: ZSpace.xs),
                Row(
                  children: [
                    Expanded(
                      child: _ProtocolSelectCard(
                        selected: _protocol == AiApiProtocol.openAiCompatible,
                        iconKind: AiSvgIconKind.openAiProtocol,
                        label: l10n.aiProtocolOpenAi,
                        onTap: () => setState(
                          () => _protocol = AiApiProtocol.openAiCompatible,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    Expanded(
                      child: _ProtocolSelectCard(
                        selected:
                            _protocol == AiApiProtocol.anthropicCompatible,
                        iconKind: AiSvgIconKind.anthropicProtocol,
                        label: l10n.aiProtocolAnthropic,
                        onTap: () => setState(
                          () => _protocol = AiApiProtocol.anthropicCompatible,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                Text(
                  l10n.aiQuickFillLabel,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
                const SizedBox(height: ZSpace.xs),
                if (widget.isDialog)
                  Wrap(
                    spacing: ZSpace.xs + 2,
                    runSpacing: ZSpace.xs + 2,
                    children: [
                      for (final preset in AiEndpointQuickPreset.presets)
                        _buildPresetChip(preset, lang),
                    ],
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final preset in AiEndpointQuickPreset.presets)
                          Padding(
                            padding: const EdgeInsets.only(right: ZSpace.xs + 2),
                            child: _buildPresetChip(preset, lang),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: ZSpace.md),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l10n.aiProfileNameLabel),
                ),
                const SizedBox(height: ZSpace.sm),
                TextField(
                  controller: _urlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: l10n.aiBaseUrlLabel),
                ),
                const SizedBox(height: ZSpace.sm),
                TextField(
                  controller: _keyCtrl,
                  obscureText: _obscureKey,
                  decoration: InputDecoration(
                    labelText: l10n.aiApiKeyLabel,
                    hintText: existingMasked.isNotEmpty
                        ? '${l10n.aiApiKeyLeaveEmptyHint} ($existingMasked)'
                        : 'sk-...',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureKey = !_obscureKey),
                    ),
                  ),
                ),
                const SizedBox(height: ZSpace.md),
                ZButton(
                  label: _fetching
                      ? l10n.aiFetchingModels
                      : l10n.aiFetchModelsButton,
                  icon: Icons.cloud_download_outlined,
                  variant: ZButtonVariant.tonal,
                  isBlock: true,
                  isLoading: _fetching,
                  onTap: _fetching ? null : _fetchModels,
                ),
                if (_fetchError != null) ...[
                  const SizedBox(height: ZSpace.xs),
                  Text(
                    _fetchError!,
                    style: zt.caption.copyWith(color: zc.danger),
                  ),
                ],
                const SizedBox(height: ZSpace.md),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.aiSearchModelHint,
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                  ),
                ),
                const SizedBox(height: ZSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualModelCtrl,
                        onSubmitted: (_) => _addManualModel(),
                        decoration: InputDecoration(
                          hintText: l10n.aiManualModelHint,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    ZButton(
                      label: l10n.aiManualAddButton,
                      variant: ZButtonVariant.outlined,
                      size: ZButtonSize.sm,
                      onTap: _addManualModel,
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.xs),
                for (final m in visibleModels)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _selectedIds.contains(m.id),
                    activeColor: zc.accent,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedIds.add(m.id);
                        } else {
                          _selectedIds.remove(m.id);
                        }
                      });
                    },
                    title: Text(
                      m.displayName,
                      style: zt.mono.copyWith(
                        fontSize: 12.5,
                        color: zc.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZSpace.md),
        ZButton(
          label:
              '${l10n.aiSaveProfileButton} · ${l10n.aiImportSelectedButton(_selectedIds.length)}',
          variant: ZButtonVariant.filled,
          isBlock: true,
          onTap: _save,
        ),
      ],
    );

    if (widget.isDialog) {
      return Padding(
        padding: const EdgeInsets.all(ZSpace.lg),
        child: body,
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            ZSpace.lg,
            ZSpace.md,
            ZSpace.lg,
            ZSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: body,
        ),
      ),
    );
  }
}

class _ProtocolSelectCard extends StatelessWidget {
  final bool selected;
  final AiSvgIconKind iconKind;
  final String label;
  final VoidCallback onTap;

  const _ProtocolSelectCard({
    required this.selected,
    required this.iconKind,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Material(
      color: selected ? zc.accentContainer : zc.surface,
      borderRadius: ZRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZRadius.brMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.md,
            vertical: ZSpace.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: ZRadius.brMd,
            border: Border.all(
              color: selected ? zc.accent : zc.outline,
              width: selected ? ZStroke.emphasis : ZStroke.hairline,
            ),
          ),
          child: Row(
            children: [
              AiSvgIcon(
                iconKind,
                size: 16,
                color: selected ? zc.accent : zc.textSecondary,
              ),
              const SizedBox(width: ZSpace.xs + 2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: zt.caption.copyWith(
                    color: selected ? zc.accent : zc.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: ZSpace.xs),
                Icon(Icons.check_circle_rounded, size: 15, color: zc.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
