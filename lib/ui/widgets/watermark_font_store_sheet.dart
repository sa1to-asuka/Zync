import 'package:flutter/material.dart';

import '../../engine/watermark/watermark_font_manager.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';

/// 艺术字开源字体商店与本地字体导入弹窗。
///
/// 打开后可即时选用：
/// 1. 随 APK 内置的系统与超轻量英文 OFL-1.1 艺术字；
/// 2. 托管于 `sa1to-asuka/Zync` (`fonts-v1`) 的 SIL OFL-1.1 中文开源字体（按需下载）；
/// 3. 用户手机本地 `.ttf` / `.otf` 字体文件。
Future<String?> showWatermarkFontStoreSheet(
  BuildContext context, {
  required String currentFontId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.zc.surfaceHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.lg)),
    ),
    builder: (ctx) => _WatermarkFontStoreSheet(currentFontId: currentFontId),
  );
}

class _WatermarkFontStoreSheet extends StatefulWidget {
  final String currentFontId;

  const _WatermarkFontStoreSheet({required this.currentFontId});

  @override
  State<_WatermarkFontStoreSheet> createState() =>
      _WatermarkFontStoreSheetState();
}

class _WatermarkFontStoreSheetState extends State<_WatermarkFontStoreSheet> {
  final WatermarkFontManager _manager = WatermarkFontManager.instance;
  int _tab = 1; // 默认高亮云端中文字体或已安装列表

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onChanged);
    _initFonts();
  }

  @override
  void dispose() {
    _manager.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initFonts() async {
    await _manager.ensureInitialized();
    // 默认首屏：若已安装过云端字体则停留在“内置+已安装”，否则引导到“云端字体”
    if (mounted && _manager.cloudCatalog.isNotEmpty) {
      await _manager.refreshCloudManifest();
    }
  }

  Future<void> _download(WatermarkFontEntry entry) async {
    final l10n = context.l10n;
    try {
      await _manager.downloadFont(entry);
      if (mounted) {
        Navigator.of(context).pop(entry.id);
      }
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          l10n.wmFontDownloadFailed('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  Future<void> _importLocal() async {
    final l10n = context.l10n;
    final path = await CameraNativeBridge.pickFile();
    if (path == null || path.isEmpty) return;
    try {
      final entry = await _manager.importLocalFontFile(path);
      if (mounted) {
        showZToast(
          context,
          l10n.wmFontImportSuccess(entry.displayName),
          tone: ZStatusTone.success,
        );
        Navigator.of(context).pop(entry.id);
      }
    } catch (e) {
      if (mounted) {
        showZToast(
          context,
          l10n.wmFontDownloadFailed('$e'),
          tone: ZStatusTone.danger,
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final entries = switch (_tab) {
      0 => WatermarkFontManager.builtinEntries,
      1 => _manager.cloudCatalog,
      _ => _manager.importedEntries,
    };

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.76,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.wmFontStoreTitle, style: zt.headline),
                  ),
                  if (_tab == 1)
                    IconButton(
                      tooltip: l10n.wmFontRefreshManifest,
                      onPressed: _manager.manifestLoading
                          ? null
                          : () => _manager.refreshCloudManifest(),
                      icon: _manager.manifestLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: zc.accent,
                              ),
                            )
                          : const Icon(Icons.refresh, size: 20),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.wmFontTabBuiltin)),
                  ButtonSegment(value: 1, label: Text(l10n.wmFontTabCloud)),
                  ButtonSegment(value: 2, label: Text(l10n.wmFontTabLocal)),
                ],
                selected: {_tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
              const SizedBox(height: 10),
              if (_tab == 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l10n.wmFontOpenSourceNotice,
                    style: zt.caption.copyWith(color: zc.textTertiary),
                  ),
                ),
              if (_tab == 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton.icon(
                    onPressed: _importLocal,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: Text(l10n.wmFontImportLocal),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _buildFontCard(entries[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontCard(WatermarkFontEntry entry) {
    final zc = context.zc;
    final l10n = context.l10n;
    final installed = _manager.isInstalled(entry.id);
    final selected = widget.currentFontId == entry.id;
    final progress = _manager.progressOf(entry.id);

    return InkWell(
      borderRadius: ZRadius.brMd,
      onTap: installed ? () => Navigator.of(context).pop(entry.id) : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? zc.accentContainer : zc.surface,
          borderRadius: ZRadius.brMd,
          border: Border.all(
            color: selected ? zc.accent : zc.outline,
            width: selected ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.previewSample,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: installed ? entry.family : null,
                      fontSize: 17,
                      color: zc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.displayName} · ${entry.license}'
                    '${entry.sizeBytes > 0 ? ' · ${_formatSize(entry.sizeBytes)}' : ''}',
                    style: TextStyle(color: zc.textSecondary, fontSize: 11),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      color: zc.accent,
                      backgroundColor: zc.outlineVariant,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (progress != null)
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: zc.accent,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              )
            else if (installed) ...[
              if (entry.source == WatermarkFontSource.cloudStore ||
                  entry.source == WatermarkFontSource.localImport)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: zc.textTertiary),
                  onPressed: () => _manager.deleteFont(entry.id),
                ),
              ZTag(
                text: l10n.wmFontInstalled,
                color: selected ? zc.accent : zc.success,
                compact: true,
              ),
            ] else
              FilledButton(
                onPressed: () => _download(entry),
                child: Text(l10n.wmFontDownload),
              ),
          ],
        ),
      ),
    );
  }
}
