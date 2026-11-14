import 'package:flutter/material.dart';

import '../../../core/settings/app_settings.dart';
import '../../../engine/capture/camera_folder_controller.dart';
import '../../../l10n/engine_l10n.dart';
import '../../../l10n/l10n.dart';
import '../../design/design.dart';

/// 打开「保存位置」选择器。
///
/// 两个概念分开：
/// - **相机文件夹**：照片在机身存储卡里的目录。Nikon 的 `0xD15B` 多半只读，
///   所以先探测再决定是否放开输入。
/// - **手机文件夹**：下载/导出到手机相册时用的 `DCIM/` 子目录。
///
/// 返回 true 表示用户确认了新的手机文件夹。
Future<bool> showStorageFolderSheet(
  BuildContext context, {
  CameraFolderController? cameraFolder,
}) async {
  final folder = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: ZSwatch.transparent,
    isScrollControlled: true,
    builder: (_) => _StorageFolderSheet(cameraFolder: cameraFolder),
  );
  if (folder == null || folder.isEmpty) return false;
  AppSettings.instance.setExportFolder(folder);
  return true;
}

class _StorageFolderSheet extends StatefulWidget {
  const _StorageFolderSheet({this.cameraFolder});

  final CameraFolderController? cameraFolder;

  @override
  State<_StorageFolderSheet> createState() => _StorageFolderSheetState();
}

class _StorageFolderSheetState extends State<_StorageFolderSheet> {
  late final TextEditingController _external = TextEditingController(
    text: AppSettings.instance.exportFolder,
  );
  final TextEditingController _camera = TextEditingController();

  bool _probing = false;
  bool _applyingCamera = false;
  bool _cameraTouched = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final folder = widget.cameraFolder;
    if (folder == null) return;
    setState(() => _probing = true);
    await folder.refresh();
    await folder.probeWritable();
    if (!mounted) return;
    setState(() {
      _probing = false;
      _cameraTouched = true;
      final current = folder.currentFolder;
      if (current != null) _camera.text = '$current';
    });
  }

  @override
  void dispose() {
    _external.dispose();
    _camera.dispose();
    super.dispose();
  }

  String get _normalized =>
      AppSettings.normalizeExportFolder(_external.text);

  void _submit() {
    Navigator.of(context).pop(_normalized);
  }

  Future<void> _applyCameraFolder() async {
    final folder = widget.cameraFolder;
    if (folder == null) return;
    final value = int.tryParse(_camera.text.trim());
    if (value == null) return;

    final lang = L10n.current.localeName;
    setState(() => _applyingCamera = true);
    final ok = await folder.setFolder(value);
    if (!mounted) return;
    setState(() => _applyingCamera = false);
    showZToast(
      context,
      ok
          ? EngineL10n.cameraFolderApplied(lang, folder.currentFolder ?? value)
          : EngineL10n.cameraFolderFailed(lang),
      isError: !ok,
    );
    if (folder.currentFolder != null) _camera.text = '${folder.currentFolder}';
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final settings = AppSettings.instance;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(ZSpace.md),
        padding: const EdgeInsets.all(ZSpace.lg),
        decoration: BoxDecoration(
          color: zc.surface,
          borderRadius: ZRadius.brLg,
        ),
        child: SingleChildScrollView(
          child: AnimatedBuilder(
            animation: settings,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (widget.cameraFolder != null) ...[
                    _buildCameraSection(context),
                    const SizedBox(height: ZSpace.lg),
                    Divider(height: 1, color: zc.outlineVariant),
                    const SizedBox(height: ZSpace.lg),
                  ],
                  Text(l10n.storageFolderTitle,
                      style: zt.title.copyWith(color: zc.textPrimary)),
                  const SizedBox(height: ZSpace.sm),
                  Text(
                    l10n.storageFolderPath(settings.exportFolder),
                    style: zt.numericSmall.copyWith(color: zc.textSecondary),
                  ),
                  const SizedBox(height: ZSpace.md),
                  TextField(
                    controller: _external,
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
                            _external.text = folder;
                            _external.selection =
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCameraSection(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final lang = L10n.current.localeName;
    final folder = widget.cameraFolder!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(EngineL10n.cameraFolderTitle(lang),
            style: zt.title.copyWith(color: zc.textPrimary)),
        const SizedBox(height: ZSpace.xs),
        if (_probing)
          Text('…', style: zt.caption.copyWith(color: zc.textSecondary))
        else if (folder.currentFolder == null)
          Text(EngineL10n.cameraFolderUnreadable(lang),
              style: zt.caption.copyWith(color: zc.textSecondary))
        else
          Text(
            EngineL10n.cameraFolderCurrent(lang, folder.currentFolder!),
            style: zt.numericSmall.copyWith(color: zc.textSecondary),
          ),
        if (!_probing && _cameraTouched && folder.writable == false) ...[
          const SizedBox(height: ZSpace.xs),
          Text(
            EngineL10n.cameraFolderReadOnly(lang),
            style: zt.caption.copyWith(color: zc.warning),
          ),
        ],
        if (!_probing && folder.writable == true) ...[
          const SizedBox(height: ZSpace.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _camera,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: EngineL10n.cameraFolderHint(lang),
                    prefixIcon: const Icon(Icons.photo_library_outlined,
                        size: 18),
                  ),
                ),
              ),
              const SizedBox(width: ZSpace.sm),
              ZButton(
                label: context.l10n.storageFolderApply,
                variant: ZButtonVariant.outlined,
                size: ZButtonSize.sm,
                onTap: _applyingCamera ? null : _applyCameraFolder,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
