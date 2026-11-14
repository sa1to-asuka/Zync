import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../l10n/l10n.dart';
import '../../design/design.dart';

/// 打开「保存文件夹」选择器。
///
/// 返回 true 表示用户确认了新目录并已写入设置。
Future<bool> showStorageFolderSheet(BuildContext context) async {
  final folder = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: ZSwatch.transparent,
    isScrollControlled: true,
    builder: (_) => const _StorageFolderSheet(),
  );
  if (folder == null || folder.isEmpty) return false;
  AppSettings.instance.setExportFolder(folder);
  return true;
}

class _StorageFolderSheet extends StatefulWidget {
  const _StorageFolderSheet();

  @override
  State<_StorageFolderSheet> createState() => _StorageFolderSheetState();
}

class _StorageFolderSheetState extends State<_StorageFolderSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: AppSettings.instance.exportFolder,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _normalized =>
      AppSettings.normalizeExportFolder(_controller.text);

  void _submit() {
    Navigator.of(context).pop(_normalized);
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final settings = AppSettings.instance;

    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(ZSpace.md),
            padding: const EdgeInsets.all(ZSpace.lg),
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: ZRadius.brLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.storageFolderTitle,
                    style: zt.title.copyWith(color: zc.textPrimary)),
                const SizedBox(height: ZSpace.sm),
                Text(
                  l10n.storageFolderPath(settings.exportFolder),
                  style: zt.numericSmall.copyWith(color: zc.textSecondary),
                ),
                const SizedBox(height: ZSpace.md),
                TextField(
                  controller: _controller,
                  autofocus: false,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: l10n.storageFolderHint,
                    prefixIcon: const Icon(Icons.folder_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: ZSpace.xs),
                Text(
                  l10n.storageFolderPath(_normalized),
                  style: zt.caption.copyWith(color: zc.accent),
                ),
                const SizedBox(height: ZSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.storageFolderRecent,
                      style: zt.label.copyWith(color: zc.textSecondary)),
                ),
                const SizedBox(height: ZSpace.xs),
                Wrap(
                  spacing: ZSpace.xs,
                  runSpacing: ZSpace.xs,
                  children: <Widget>[
                    for (final folder in settings.recentExportFolders)
                      GestureDetector(
                        onTap: () => setState(() {
                          _controller.text = folder;
                          _controller.selection =
                              TextSelection.collapsed(offset: folder.length);
                        }),
                        child: ZTag(
                          text: folder,
                          color: folder == _normalized
                              ? zc.accent
                              : zc.textSecondary,
                          isOutline: folder != _normalized,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: ZSpace.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: ZButton(
                        label: l10n.commonCancel,
                        variant: ZButtonVariant.outlined,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    Expanded(
                      child: ZButton(
                        label: _normalized == settings.exportFolder
                            ? l10n.storageFolderApply
                            : l10n.storageFolderCreate,
                        icon: Icons.check_rounded,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
