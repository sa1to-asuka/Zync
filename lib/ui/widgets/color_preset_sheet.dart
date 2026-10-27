import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/editor/builtin_grade_presets.dart';
import '../../engine/editor/color_grade_preset.dart';
import '../../engine/editor/pro_photo_models.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import 'grade_thumbnail.dart';

/// 调色预设面板。照片与视频共用，保证同一套预设跨媒体复用。
///
/// 内置预设始终在最前（只读，不可删除）；用户预设按更新时间倒序排列在后面。
class ColorPresetSheet extends StatefulWidget {
  final ColorGrade grade;
  final bool isGlobal;
  final ValueChanged<ColorGrade> onApply;

  /// 可选的照片采样像素，用于渲染预设缩略图。视频侧传 null 即可。
  final List<int>? sampledR;
  final List<int>? sampledG;
  final List<int>? sampledB;

  const ColorPresetSheet({
    super.key,
    required this.grade,
    required this.isGlobal,
    required this.onApply,
    this.sampledR,
    this.sampledG,
    this.sampledB,
  });

  static Future<void> show(
    BuildContext context, {
    required ColorGrade grade,
    required bool isGlobal,
    required ValueChanged<ColorGrade> onApply,
    List<int>? sampledR,
    List<int>? sampledG,
    List<int>? sampledB,
  }) {
    final zc = context.zc;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: zc.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
      ),
      builder: (ctx) => ColorPresetSheet(
        grade: grade,
        isGlobal: isGlobal,
        onApply: onApply,
        sampledR: sampledR,
        sampledG: sampledG,
        sampledB: sampledB,
      ),
    );
  }

  @override
  State<ColorPresetSheet> createState() => _ColorPresetSheetState();
}

class _ColorPresetSheetState extends State<ColorPresetSheet> {
  static const String _kMineCategory = 'mine';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<ColorGradePreset> _userPresets = const [];
  String _category = kBuiltinGradeCategories.first;
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final presets = await ColorGradePresetStore.load();
    if (!mounted) return;
    setState(() {
      _userPresets = presets;
      _loading = false;
    });
  }

  /// 当前分类下的内置预设，按搜索词过滤。
  List<BuiltinGradePreset> _visibleBuiltins() {
    if (_category == _kMineCategory) return const [];
    final query = _query.trim().toLowerCase();
    return builtinPresetsIn(_category).where((preset) {
      if (query.isEmpty) return true;
      return preset.name.toLowerCase().contains(query) ||
          preset.trName.toLowerCase().contains(query) ||
          preset.description.toLowerCase().contains(query) ||
          preset.trDescription.toLowerCase().contains(query) ||
          preset.category.toLowerCase().contains(query);
    }).toList();
  }

  /// 搜索命中的用户预设。
  List<ColorGradePreset> get _visibleUserPresets {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _userPresets;
    return _userPresets
        .where((e) =>
            e.name.toLowerCase().contains(query) ||
            e.summary.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final presets = await ColorGradePresetStore.upsert(
      ColorGradePreset(
        id: 'preset_$now',
        name: name,
        isGlobal: widget.isGlobal,
        grade: widget.grade,
        createdAtMs: now,
        updatedAtMs: now,
      ),
    );
    if (!mounted) return;
    _nameController.clear();
    setState(() {
      _userPresets = presets;
      _category = _kMineCategory;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.presetSavedToast)),
    );
  }

  Future<void> _import() async {
    final l10n = context.l10n;
    final path = await CameraNativeBridge.pickFile();
    if (path == null || path.isEmpty || !mounted) return;
    try {
      final text = await File(path).readAsString();
      final presets =
          ColorGradePresetStore.importJson(text, existing: _userPresets);
      await ColorGradePresetStore.save(presets);
      if (!mounted) return;
      setState(() {
        _userPresets = presets;
        _category = _kMineCategory;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.presetImportedToast(presets.length))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.presetImportFailedToast)),
      );
    }
  }

  Future<void> _export() async {
    final l10n = context.l10n;
    final text = ColorGradePresetStore.exportJson(_userPresets);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final path = await CameraNativeBridge.writeTextFile(text,
        fileName: 'zync_presets_$stamp.json');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          path == null ? l10n.presetExportFailedToast : l10n.presetExportedToast,
        ),
      ),
    );
  }

  String _categoryLabel(String category, AppLocalizations l10n) {
    if (category == _kMineCategory) return l10n.presetTabMine;
    return L10n.tr(category, l10n.localeName);
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final builtins = _visibleBuiltins();
    final users = _visibleUserPresets;
    final categories = <String>[...kBuiltinGradeCategories, _kMineCategory];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 14, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.presetTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: zc.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isGlobal ? l10n.presetScopeGlobal : l10n.presetScopeClip,
              style: TextStyle(fontSize: 11, color: zc.textSecondary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: l10n.presetSaveNew,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l10n.presetSaveDialogTitle,
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: l10n.presetSearchHint,
                prefixIcon: const Icon(Icons.search, size: 18),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            _categoryLabel(category, l10n),
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: _category == category,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.file_download_outlined, size: 15),
                  label: Text(
                    l10n.commonImport,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _userPresets.isEmpty ? null : _export,
                  icon: const Icon(Icons.ios_share, size: 15),
                  label: Text(
                    l10n.commonExport,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (builtins.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          l10n.presetTabBuiltin,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: zc.textSecondary,
                          ),
                        ),
                      ),
                      for (final preset in builtins)
                        ListTile(
                          dense: true,
                          leading: GradeThumbnail(
                            grade: preset.grade,
                            sampledR: widget.sampledR,
                            sampledG: widget.sampledG,
                            sampledB: widget.sampledB,
                          ),
                          title: Text(
                            preset.trName,
                            style: TextStyle(fontSize: 13, color: zc.textPrimary),
                          ),
                          subtitle: Text(
                            preset.trDescription,
                            style: TextStyle(fontSize: 10, color: zc.textSecondary),
                          ),
                          trailing: IconButton(
                            tooltip: l10n.presetApplyAction,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              widget.onApply(preset.grade);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check, size: 18),
                          ),
                        ),
                    ],
                    if (users.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          l10n.presetTabMine,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: zc.textSecondary,
                          ),
                        ),
                      ),
                      for (final preset in users)
                        ListTile(
                          dense: true,
                          leading: GradeThumbnail(
                            grade: preset.grade,
                            sampledR: widget.sampledR,
                            sampledG: widget.sampledG,
                            sampledB: widget.sampledB,
                          ),
                          title: Text(
                            preset.name,
                            style: TextStyle(fontSize: 13, color: zc.textPrimary),
                          ),
                          subtitle: Text(
                            preset.summary,
                            style: TextStyle(fontSize: 10, color: zc.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.presetApplyAction,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  widget.onApply(preset.grade);
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.check, size: 18),
                              ),
                              IconButton(
                                tooltip: l10n.commonDelete,
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final presets =
                                      await ColorGradePresetStore.remove(
                                          preset.id);
                                  if (!mounted) return;
                                  setState(() => _userPresets = presets);
                                },
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (builtins.isEmpty && users.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          l10n.presetEmptyMatch,
                          style: TextStyle(fontSize: 12, color: zc.textSecondary),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
