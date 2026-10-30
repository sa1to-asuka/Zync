import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../core/settings/app_settings.dart';
import '../../engine/picture_control/builtin_np3_recipes.dart';
import '../../engine/picture_control/np3_codec.dart';
import '../../engine/picture_control/picture_control_preview_renderer.dart';
import '../../engine/picture_control/picture_control_store.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/nikon_driver.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';

/// 左右对比滑动分割裁剪器。
class _SplitRectClipper extends CustomClipper<Rect> {
  final double splitRatio;
  const _SplitRectClipper(this.splitRatio);

  @override
  Rect getClip(Size size) {
    final splitX = size.width * splitRatio;
    return Rect.fromLTRB(splitX, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SplitRectClipper oldClipper) =>
      oldClipper.splitRatio != splitRatio;
}

/// 尼康「色彩优化」（Picture Control 配方管理与 C1–C9 机内直写）主界面。
///
/// - 手机窄屏 (`< 600dp`)：上方交互式左右拖拽对比预览与场景选择 + 下方 `[ 本地配方库 | 相机槽位 C1–C9 ]` 页签。
/// - 平板/大屏 (`>= 600dp`)：左侧交互式对比预览画布、场景切换条、257 点曲线与参数面板；右侧支持「一行一种滚动条列表」与「自适应高度分页」双模式配方/槽位管理面板。
class PictureControlScreen extends StatefulWidget {
  final NikonDriver driver;

  const PictureControlScreen({
    super.key,
    required this.driver,
  });

  @override
  State<PictureControlScreen> createState() => PictureControlScreenState();
}

class PictureControlScreenState extends State<PictureControlScreen>
    with SingleTickerProviderStateMixin {
  final PictureControlStore _store = PictureControlStore.instance;
  late final TabController _tabController;
  final ScrollController _libScrollController = ScrollController();
  final ScrollController _slotScrollController = ScrollController();
  final PageController _libPageController = PageController();

  String? _selectedItemId;
  PictureControlCategory _categoryFilter = PictureControlCategory.all;
  PictureControlBase? _baseFilter;
  String _selectedSceneId = 'portrait';
  String? _customSamplePath;
  double _splitRatio = 0.5;
  int _libCurrentPage = 0;

  // 采样图原图解码缓存与渲染后 JPEG 缓存（静态常驻内存，切页秒开）
  static final Map<String, img.Image> _decodedSceneCache = {};
  static final Map<String, Uint8List> _originalSceneJpgCache = {};
  static final Map<String, Uint8List> _renderedPreviewCache = {};
  bool _isRenderingPreview = false;

  // 相机 C1–C9 槽位状态
  List<CameraPictureControlSlot> _cameraSlots = const [];
  bool _isLoadingSlots = false;
  bool _isWritingSlot = false;
  Future<void>? _slotRefreshFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _store.addListener(_onStoreChanged);
    _initStoreAndSample();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _tabController.dispose();
    _libScrollController.dispose();
    _slotScrollController.dispose();
    _libPageController.dispose();
    super.dispose();
  }

  Future<void> _initStoreAndSample() async {
    await _store.ensureInitialized();
    if (!mounted) return;
    if (_store.items.isNotEmpty && _selectedItemId == null) {
      final first = _store.items.first;
      _selectedItemId = first.id;
    }
    setState(() {});
    _triggerRenderActivePreview();
    if (widget.driver.isConnected) {
      refreshCameraSlots();
    }
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final items = _store.items;
    if (items.isNotEmpty &&
        (_selectedItemId == null ||
            !items.any((e) => e.id == _selectedItemId))) {
      _selectedItemId = items.first.id;
    } else if (items.isEmpty) {
      _selectedItemId = null;
    }
    setState(() {});
    _triggerRenderActivePreview();
  }

  PictureControlLibraryItem? get _selectedItem {
    final items = _filteredItems;
    if (items.isEmpty) return null;
    if (_selectedItemId != null) {
      for (final item in items) {
        if (item.id == _selectedItemId) return item;
      }
    }
    return items.first;
  }

  List<PictureControlLibraryItem> get _filteredItems {
    var all = _store.items;
    if (_categoryFilter != PictureControlCategory.all) {
      all = all.where((e) => e.category == _categoryFilter).toList();
    }
    if (_baseFilter != null) {
      all = all.where((e) => e.recipe.base == _baseFilter).toList();
    }
    return all;
  }

  @visibleForTesting
  String get selectedSceneIdForTesting => _selectedSceneId;

  @visibleForTesting
  double get splitRatioForTesting => _splitRatio;

  /// 外部或连接成功后刷新相机 C1–C9 槽位。
  ///
  /// [force] 为 true 时会先等待进行中的刷新结束，再发起一次新的读取，
  /// 确保拿到写入之后的最新槽位状态。
  Future<void> refreshCameraSlots({bool force = false}) async {
    if (!widget.driver.isConnected) return;
    final inFlight = _slotRefreshFuture;
    if (inFlight != null) {
      await inFlight;
      if (!force) return;
      if (!mounted || !widget.driver.isConnected) return;
    }
    final future = _loadCameraSlots();
    _slotRefreshFuture = future;
    try {
      await future;
    } finally {
      if (identical(_slotRefreshFuture, future)) {
        _slotRefreshFuture = null;
      }
    }
  }

  Future<void> _loadCameraSlots() async {
    if (mounted) setState(() => _isLoadingSlots = true);
    try {
      final slots = await widget.driver.listPictureControlSlots();
      if (mounted) {
        setState(() {
          _cameraSlots = slots;
          _isLoadingSlots = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  /// 刷新后的槽位是否已经包含目标配方（按成像参数比较，忽略相机归一化）。
  bool _slotMatches(int slotNumber, PictureControlRecipe recipe) {
    final slot =
        _cameraSlots.where((s) => s.slotNumber == slotNumber).firstOrNull;
    if (slot == null || !slot.isPopulated || slot.recipe == null) return false;
    return Np3Codec.sameParameters(_comparableRecipe(recipe), slot.recipe!);
  }

  /// Flexible Color 写入机身时会转换为标准 NP3，比较前先做同样的归一化。
  PictureControlRecipe _comparableRecipe(PictureControlRecipe recipe) {
    if (!recipe.isFlexibleColor) return recipe;
    return Np3Codec.parse(
      Np3Codec.convertFlexibleToStandardNp3Bytes(recipe),
    );
  }

  /// 供 RootScaffold 在收到外部应用打开 .NP3/.NCP/.ZIP 时直接调用。
  Future<void> importExternalFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    final report = await _store.importFromPaths(paths);
    if (!mounted) return;
    if (report.addedItems.isNotEmpty) {
      final newest = report.addedItems.first;
      setState(() {
        _baseFilter = null;
        _selectedItemId = newest.id;
        _selectedSceneId = newest.recommendedSceneId;
      });
      _triggerRenderActivePreview();
    }
    showZToast(
      context,
      context.l10n.pcImportReportToast(
        report.importedCount,
        report.duplicateCount,
        report.invalidCount,
      ),
      tone:
          report.importedCount > 0 ? ZStatusTone.success : ZStatusTone.neutral,
    );
  }

  Future<void> _pickAndImportFiles() async {
    final paths = await CameraNativeBridge.pickMultipleFiles();
    if (paths.isEmpty) return;
    await importExternalFiles(paths);
  }

  Future<void> _pickCustomSampleImage() async {
    final path = await CameraNativeBridge.pickImageFromGallery();
    if (path == null || path.isEmpty || !mounted) return;
    setState(() {
      _customSamplePath = path;
    });
    _triggerRenderActivePreview();
  }

  Future<img.Image?> _loadBaseSampleImage() async {
    final cacheKey = _customSamplePath != null && _customSamplePath!.isNotEmpty
        ? 'file:$_customSamplePath'
        : 'asset:$_selectedSceneId';
    if (_decodedSceneCache.containsKey(cacheKey)) {
      return _decodedSceneCache[cacheKey];
    }

    try {
      Uint8List rawBytes;
      if (_customSamplePath != null && _customSamplePath!.isNotEmpty) {
        rawBytes = await File(_customSamplePath!).readAsBytes();
      } else {
        final scene = BuiltinNp3Catalog.sampleScenes.firstWhere(
          (s) => s.id == _selectedSceneId,
          orElse: () => BuiltinNp3Catalog.sampleScenes.first,
        );
        final loaded = await _store.loadSampleSceneBytes(scene);
        if (loaded != null && loaded.isNotEmpty) {
          rawBytes = loaded;
        } else {
          final bd = await rootBundle.load(scene.assetPath);
          rawBytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
        }
      }
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;
      // 保持高清分辨率（最高 1280px），保证手机屏幕对比预览清晰不模糊
      const maxDim = 1280;
      final resized = decoded.width > maxDim || decoded.height > maxDim
          ? (decoded.width >= decoded.height
              ? img.copyResize(decoded, width: maxDim)
              : img.copyResize(decoded, height: maxDim))
          : decoded;
      _decodedSceneCache[cacheKey] = resized;
      _originalSceneJpgCache[cacheKey] =
          Uint8List.fromList(img.encodeJpg(resized, quality: 92));
      return resized;
    } catch (_) {
      return null;
    }
  }

  Future<void> _triggerRenderActivePreview() async {
    final active = _selectedItem;
    if (active == null) return;
    final sceneKey = _customSamplePath != null && _customSamplePath!.isNotEmpty
        ? 'file:$_customSamplePath'
        : 'asset:$_selectedSceneId';
    final renderKey = '${active.id}|${active.cameraName}|$sceneKey';
    if (_renderedPreviewCache.containsKey(renderKey)) {
      if (mounted) setState(() {});
      return;
    }

    if (mounted) setState(() => _isRenderingPreview = true);
    final baseImg = await _loadBaseSampleImage();
    if (baseImg != null) {
      final rendered = PictureControlPreviewRenderer.renderPreviewJpg(
        baseImg,
        active.recipe,
        quality: 92,
      );
      _renderedPreviewCache[renderKey] = rendered;
    }
    if (mounted) setState(() => _isRenderingPreview = false);
  }

  String _activeRenderKey(PictureControlLibraryItem item) {
    final sceneKey = _customSamplePath != null && _customSamplePath!.isNotEmpty
        ? 'file:$_customSamplePath'
        : 'asset:$_selectedSceneId';
    return '${item.id}|${item.cameraName}|$sceneKey';
  }

  String _baseLocalizedName(BuildContext context, PictureControlBase base) {
    return L10n.tr(base.labelZh, context.l10n.localeName);
  }

  Future<void> _handleConvertFlexibleItem(
    PictureControlLibraryItem item,
  ) async {
    final created = await _store.convertFlexibleItemToStandard(item);
    if (!mounted || created == null) return;
    setState(() {
      _baseFilter = null;
      _selectedItemId = created.id;
    });
    _triggerRenderActivePreview();
    showZToast(
      context,
      context.l10n.pcFcConvertedToast(created.displayTitle),
      tone: ZStatusTone.success,
    );
  }

  void _showRenameDialog(PictureControlLibraryItem item) {
    final l10n = context.l10n;
    final zt = context.zt;
    final cameraCtrl = TextEditingController(text: item.cameraName);
    final noteCtrl = TextEditingController(text: item.noteName);

    showZDialog<void>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.pcRenameDialogTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: cameraCtrl,
              maxLength: 19,
              style: zt.numeric,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\x20-\x7E]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.pcRenameCameraField,
                helperText: l10n.pcRenameCameraHelper,
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: ZSpace.md),
            TextField(
              controller: noteCtrl,
              maxLength: 32,
              decoration: InputDecoration(
                labelText: l10n.pcRenameNoteField,
              ),
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
            label: l10n.commonSave,
            onTap: () async {
              Navigator.pop(ctx);
              final updated = await _store.renameItem(
                id: item.id,
                newCameraName: cameraCtrl.text,
                newNoteName: noteCtrl.text,
              );
              if (mounted && updated != null) {
                showZToast(
                  context,
                  l10n.pcRenameSavedToast(updated.displayTitle),
                  tone: ZStatusTone.success,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(PictureControlLibraryItem item) {
    final l10n = context.l10n;
    final zt = context.zt;
    showZDialog<void>(
      context: context,
      builder: (ctx) => ZDialog(
        title: l10n.pcDeleteConfirmTitle,
        content: Text(
          l10n.pcDeleteConfirmBody(item.displayTitle),
          style: zt.body,
        ),
        actions: [
          ZButton(
            label: l10n.commonCancel,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(ctx),
          ),
          ZButton(
            label: l10n.commonDelete,
            variant: ZButtonVariant.danger,
            onTap: () async {
              Navigator.pop(ctx);
              await _store.deleteItem(item.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareRecipeItem(PictureControlLibraryItem item) async {
    final file = await _store.exportFileForSharing(item);
    await CameraNativeBridge.shareFile(
      file.path,
      title: item.cameraName,
    );
  }

  void _showWriteToSlotDialog(
    PictureControlLibraryItem item, {
    int initialSlot = 1,
  }) {
    final l10n = context.l10n;
    final zc = context.zc;
    final zt = context.zt;

    if (!widget.driver.isConnected) {
      showZToast(
        context,
        l10n.pcDisconnectedEmptyTitle,
        tone: ZStatusTone.warning,
      );
      return;
    }

    var selectedSlot = initialSlot.clamp(1, 9);
    var setActiveAfterWrite = true;

    showZDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return ZDialog(
            title: l10n.pcWriteDialogTitle,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pcWriteDialogSubtitle(
                    '${item.displayTitle} [${item.cameraName}]',
                  ),
                  style: zt.bodySmall,
                ),
                const SizedBox(height: ZSpace.md),
                Wrap(
                  spacing: ZSpace.sm,
                  runSpacing: ZSpace.sm,
                  children: [
                    for (var s = 1; s <= 9; s++)
                      _buildSlotChoiceChip(
                        slotNumber: s,
                        selected: selectedSlot == s,
                        onTap: () => setDialogState(() => selectedSlot = s),
                      ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                InkWell(
                  borderRadius: ZRadius.brSm,
                  onTap: () => setDialogState(
                    () => setActiveAfterWrite = !setActiveAfterWrite,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Checkbox(
                          value: setActiveAfterWrite,
                          activeColor: zc.accent,
                          onChanged: (v) => setDialogState(
                            () => setActiveAfterWrite = v ?? true,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            l10n.pcWriteSetActiveCheckbox,
                            style: zt.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                label: l10n.pcWriteConfirmButton,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _executeSingleSlotWrite(
                    slotNumber: selectedSlot,
                    item: item,
                    setActive: setActiveAfterWrite,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSlotChoiceChip({
    required int slotNumber,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    CameraPictureControlSlot? existing;
    for (final s in _cameraSlots) {
      if (s.slotNumber == slotNumber) {
        existing = s;
        break;
      }
    }
    final subLabel =
        (existing != null && existing.isPopulated && existing.recipe != null)
            ? existing.recipe!.cameraName
            : '--';

    return InkWell(
      borderRadius: ZRadius.brSm,
      onTap: onTap,
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? zc.accentContainer : zc.surfaceHigh,
          borderRadius: ZRadius.brSm,
          border: Border.all(
            color: selected ? zc.accent : zc.outline,
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'C$slotNumber',
              style: zt.numeric.copyWith(
                color: selected ? zc.accent : zc.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              subLabel,
              style: zt.caption.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSingleSlotWrite({
    required int slotNumber,
    required PictureControlLibraryItem item,
    required bool setActive,
  }) async {
    if (_isWritingSlot) return;
    setState(() => _isWritingSlot = true);
    try {
      PictureControlWriteResult? result;
      Object? writeError;
      try {
        result = await widget.driver.writePictureControlSlot(
          slotNumber: slotNumber,
          recipe: item.recipe,
          setActive: setActive,
        );
      } catch (e) {
        writeError = e;
      }

      // 无论驱动校验结果如何，都以刷新后的相机槽位状态作为最终判定。
      var landed = result?.verified ?? false;
      await refreshCameraSlots(force: true);
      if (!landed) landed = _slotMatches(slotNumber, item.recipe);
      if (!landed) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await refreshCameraSlots(force: true);
        landed = _slotMatches(slotNumber, item.recipe);
      }
      if (!landed && widget.driver.isConnected) {
        try {
          landed = await widget.driver.verifyPictureControlSlot(
            slotNumber: slotNumber,
            recipe: item.recipe,
          );
        } catch (_) {
          landed = false;
        }
      }

      if (!mounted) return;
      if (landed) {
        showZToast(
          context,
          context.l10n.pcWriteSuccessToast('C$slotNumber', item.cameraName),
          tone: ZStatusTone.success,
        );
      } else {
        final detail = writeError == null
            ? context.l10n.pcWriteVerifyFailedToast('C$slotNumber')
            : '$writeError';
        showZToast(
          context,
          context.l10n.pcWriteFailedToast(detail),
          tone: ZStatusTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isWritingSlot = false);
    }
  }

  void _showPickRecipeForSlotDialog(int slotNumber) {
    final l10n = context.l10n;
    final zt = context.zt;
    final writableItems =
        _store.items.where((e) => e.recipe.canWriteToCamera).toList();
    if (writableItems.isEmpty) return;

    var chosen = writableItems.first;
    var setActive = true;

    showZDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return ZDialog(
            title: 'C$slotNumber · ${l10n.pcSlotOverwriteButton}',
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: chosen.id,
                    isExpanded: true,
                    items: [
                      for (final it in writableItems)
                        DropdownMenuItem(
                          value: it.id,
                          child: Text(
                            '${it.displayTitle} [${it.cameraName}]',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      final match =
                          writableItems.where((e) => e.id == val).firstOrNull;
                      if (match != null) {
                        setDialogState(() => chosen = match);
                      }
                    },
                  ),
                  const SizedBox(height: ZSpace.md),
                  Row(
                    children: [
                      Checkbox(
                        value: setActive,
                        onChanged: (v) =>
                            setDialogState(() => setActive = v ?? true),
                      ),
                      Expanded(
                        child: Text(
                          l10n.pcWriteSetActiveCheckbox,
                          style: zt.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ZButton(
                label: l10n.commonCancel,
                variant: ZButtonVariant.ghost,
                onTap: () => Navigator.pop(ctx),
              ),
              ZButton(
                label: l10n.pcWriteConfirmButton,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _executeSingleSlotWrite(
                    slotNumber: slotNumber,
                    item: chosen,
                    setActive: setActive,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBatchWriteDialog() {
    final l10n = context.l10n;
    final zt = context.zt;

    if (!widget.driver.isConnected) {
      showZToast(
        context,
        l10n.pcDisconnectedEmptyTitle,
        tone: ZStatusTone.warning,
      );
      return;
    }

    final writableItems =
        _store.items.where((e) => e.recipe.canWriteToCamera).toList();
    final assignments = <int, String?>{
      for (var s = 1; s <= 9; s++) s: null,
    };

    showZDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final assignedCount =
              assignments.values.where((v) => v != null).length;
          return ZDialog(
            title: l10n.pcBatchDialogTitle,
            content: SizedBox(
              width: 380,
              height: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.pcBatchDialogSubtitle, style: zt.bodySmall),
                  const SizedBox(height: ZSpace.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: 9,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ZSpace.xs),
                      itemBuilder: (_, idx) {
                        final slot = idx + 1;
                        return Row(
                          children: [
                            SizedBox(
                              width: 38,
                              child: Text(
                                'C$slot',
                                style: zt.numeric.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: assignments[slot],
                                isExpanded: true,
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      l10n.pcBatchSlotKeepUnchanged,
                                      style: zt.caption,
                                    ),
                                  ),
                                  for (final it in writableItems)
                                    DropdownMenuItem<String?>(
                                      value: it.id,
                                      child: Text(
                                        '${it.displayTitle} [${it.cameraName}]',
                                        overflow: TextOverflow.ellipsis,
                                        style: zt.bodySmall,
                                      ),
                                    ),
                                ],
                                onChanged: (v) => setDialogState(
                                  () => assignments[slot] = v,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ZButton(
                label: l10n.commonCancel,
                variant: ZButtonVariant.ghost,
                onTap: () => Navigator.pop(ctx),
              ),
              ZButton(
                label: l10n.pcBatchStartWriteButton(assignedCount),
                onTap: assignedCount == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _executeBatchWrite(assignments, writableItems);
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeBatchWrite(
    Map<int, String?> assignments,
    List<PictureControlLibraryItem> writableItems,
  ) async {
    if (_isWritingSlot) return;
    setState(() => _isWritingSlot = true);

    final planned = <int, PictureControlRecipe>{};
    final verified = <int, bool>{};
    for (final entry in assignments.entries) {
      final itemId = entry.value;
      if (itemId == null) continue;
      final item = writableItems.where((e) => e.id == itemId).firstOrNull;
      if (item == null) continue;
      planned[entry.key] = item.recipe;
      try {
        final result = await widget.driver.writePictureControlSlot(
          slotNumber: entry.key,
          recipe: item.recipe,
        );
        verified[entry.key] = result.verified;
      } catch (_) {
        verified[entry.key] = false;
        if (!widget.driver.isConnected) break;
      }
    }

    await refreshCameraSlots(force: true);

    var success = 0;
    var failed = 0;
    for (final entry in planned.entries) {
      final matched =
          verified[entry.key] == true || _slotMatches(entry.key, entry.value);
      if (matched) {
        success++;
      } else {
        failed++;
      }
    }

    if (mounted) {
      setState(() => _isWritingSlot = false);
      showZToast(
        context,
        context.l10n.pcBatchSummaryToast(success, failed),
        tone: failed == 0 ? ZStatusTone.success : ZStatusTone.warning,
      );
    }
  }

  Future<void> _backupCameraSlotToLocal(CameraPictureControlSlot slot) async {
    if (!slot.isPopulated || slot.recipe == null) return;
    final np3Bytes = widget.driver.exportSlotAsNp3Bytes(slot);
    final saved = await _store.importRawBytes(
      np3Bytes,
      noteName: '${slot.slotCode} · ${slot.recipe!.cameraName}',
    );
    if (mounted && saved != null) {
      showZToast(
        context,
        context.l10n.pcSlotBackupSuccessToast(
          slot.slotCode,
          slot.recipe!.cameraName,
        ),
        tone: ZStatusTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final isWide = isAdaptiveWide(context);

    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        title: Text(l10n.pcStudioTitle),
        actions: [
          IconButton(
            tooltip: l10n.pcRestoreBuiltinTooltip,
            icon: const Icon(Icons.restore_rounded),
            onPressed: () async {
              await _store.restoreBuiltInSeeds();
            },
          ),
          if (widget.driver.isConnected)
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.xs),
              child: ZButton(
                label: l10n.pcBatchWriteAction,
                icon: Icons.playlist_add_check_rounded,
                variant: ZButtonVariant.secondary,
                size: ZButtonSize.sm,
                onTap: _isWritingSlot ? null : _showBatchWriteDialog,
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: ZSpace.md),
            child: ZButton(
              key: const ValueKey<String>('pc_import_files_button'),
              label: l10n.pcImportFilesAction,
              icon: Icons.file_upload_outlined,
              size: ZButtonSize.sm,
              onTap: _pickAndImportFiles,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCompatibilityStatusBar(context),
          if (_isWritingSlot)
            LinearProgressIndicator(
              minHeight: 2,
              color: zc.accent,
              backgroundColor: zc.surfaceHigh,
            ),
          Expanded(
            child: isWide
                ? _buildWideLayout(context)
                : _buildNarrowLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityStatusBar(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    return StreamBuilder<CameraConnectionState>(
      stream: widget.driver.connectionStateStream,
      initialData: widget.driver.state,
      builder: (context, _) {
        final connected = widget.driver.isConnected;
        final model = widget.driver.cameraModel.isNotEmpty
            ? widget.driver.cameraModel
            : 'Nikon Z';
        final verified = widget.driver.isVerifiedPictureControlModel;
        final supported = widget.driver.supportsPictureControlWrite;

        final (Color dotColor, String statusText) = !connected
            ? (zc.textTertiary, l10n.pcStatusDisconnected)
            : !supported
                ? (zc.danger, l10n.pcStatusUnsupported(model))
                : verified
                    ? (zc.success, l10n.pcStatusVerified(model))
                    : (zc.warning, l10n.pcStatusExperimental(model));

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.lg,
            vertical: ZSpace.xs,
          ),
          decoration: BoxDecoration(
            color: zc.surface,
            border: Border(
              top: BorderSide(color: zc.outline, width: 0.6),
              bottom: BorderSide(color: zc.outline, width: 0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: ZSpace.sm),
              Expanded(
                child: Text(
                  statusText,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (connected)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.pcRefreshSlotsTooltip,
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: zc.textSecondary,
                  ),
                  onPressed: _isLoadingSlots ? null : refreshCameraSlots,
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================
  // 平板 / 宽屏左右双栏布局 (`>= 600dp`)
  // =========================================================
  Widget _buildWideLayout(BuildContext context) {
    final zc = context.zc;
    return LayoutBuilder(
      builder: (context, constraints) {
        final rightWidth = (constraints.maxWidth * 0.42).clamp(340.0, 480.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(ZSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreviewCanvasCard(context, height: 320),
                    const SizedBox(height: ZSpace.md),
                    _buildSceneSelectorStrip(context),
                    const SizedBox(height: ZSpace.md),
                    _buildCurveAndParamsCard(context),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 0.8, color: zc.outline),
            SizedBox(
              width: rightWidth,
              child: _buildRightTabbedManagementPanel(
                context,
                isTabletMode: true,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // 手机 / 窄屏上下布局 (`< 600dp`)
  // =========================================================
  Widget _buildNarrowLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ZSpace.md,
            ZSpace.sm,
            ZSpace.md,
            0,
          ),
          child: Column(
            children: [
              _buildPreviewCanvasCard(context, height: 196),
              const SizedBox(height: ZSpace.xs),
              _buildSceneSelectorStrip(context),
            ],
          ),
        ),
        const SizedBox(height: ZSpace.xs),
        Expanded(
          child: _buildRightTabbedManagementPanel(
            context,
            isTabletMode: false,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // 交互式左右可拖拽对比预览画布
  // =========================================================
  Widget _buildPreviewCanvasCard(
    BuildContext context, {
    required double height,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final active = _selectedItem;
    final currentScene = BuiltinNp3Catalog.sampleScenes.firstWhere(
      (s) => s.id == _selectedSceneId,
      orElse: () => BuiltinNp3Catalog.sampleScenes.first,
    );

    final sceneKey = _customSamplePath != null && _customSamplePath!.isNotEmpty
        ? 'file:$_customSamplePath'
        : 'asset:$_selectedSceneId';
    final origBytes = _originalSceneJpgCache[sceneKey];
    final renderedBytes =
        active != null ? _renderedPreviewCache[_activeRenderKey(active)] : null;

    Widget origLayer = origBytes != null
        ? Image.memory(
            origBytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            gaplessPlayback: true,
          )
        : (_customSamplePath != null && _customSamplePath!.isNotEmpty
            ? Image.file(
                File(_customSamplePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : Image.asset(
                currentScene.assetPath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ));

    Widget presetLayer;
    if (renderedBytes != null) {
      presetLayer = Image.memory(
        renderedBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      );
    } else if (active != null) {
      final matrix =
          PictureControlPreviewRenderer.buildQuickColorMatrix(active.recipe);
      presetLayer = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: origLayer,
      );
    } else {
      presetLayer = origLayer;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final splitX = (totalW * _splitRatio).clamp(0.0, totalW);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            setState(() {
              _splitRatio =
                  (details.localPosition.dx / totalW).clamp(0.02, 0.98);
            });
          },
          onTapDown: (details) {
            setState(() {
              _splitRatio =
                  (details.localPosition.dx / totalW).clamp(0.02, 0.98);
            });
          },
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: zc.canvas,
              borderRadius: ZRadius.brMd,
              border: Border.all(color: zc.outline, width: 0.8),
            ),
            child: ClipRRect(
              borderRadius: ZRadius.brMd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. 底层：完整原图
                  origLayer,

                  // 2. 顶层右半部：配方滤镜效果
                  ClipRect(
                    clipper: _SplitRectClipper(_splitRatio),
                    child: presetLayer,
                  ),

                  // 3. 分割线
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: splitX - 1.0,
                    width: 2.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: zc.canvas,
                        boxShadow: [
                          BoxShadow(
                            color: zc.textPrimary.withAlpha(70),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. 分割线上居中的拖动手柄
                  Positioned(
                    top: (height - 30) / 2,
                    left: splitX - 15.0,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: zc.canvas,
                        shape: BoxShape.circle,
                        border: Border.all(color: zc.outline, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: zc.textPrimary.withAlpha(50),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.compare_arrows_rounded,
                          size: 18,
                          color: zc.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // 5. 左上角：原图标签
                  Positioned(
                    top: ZSpace.sm,
                    left: ZSpace.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: zc.surface.withAlpha(210),
                        borderRadius: ZRadius.brPill,
                        border: Border.all(color: zc.outline, width: 0.6),
                      ),
                      child: Text(
                        l10n.pcCompareOriginalLabel,
                        style: zt.caption.copyWith(
                          color: zc.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  // 6. 右上角：效果标签与当前配方名
                  Positioned(
                    top: ZSpace.sm,
                    right: ZSpace.sm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: zc.surface.withAlpha(210),
                        borderRadius: ZRadius.brPill,
                        border: Border.all(color: zc.outline, width: 0.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: zc.accent),
                          const SizedBox(width: 4),
                          Text(
                            active != null
                                ? '${l10n.pcCompareEffectLabel} · ${active.displayTitle}'
                                : l10n.pcCompareEffectLabel,
                            style: zt.caption.copyWith(
                              color: zc.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 7. 渲染等待指示器
                  if (_isRenderingPreview)
                    Positioned(
                      bottom: ZSpace.sm,
                      right: ZSpace.sm,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: zc.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSceneSelectorStrip(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final lang = l10n.localeName;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final scene in BuiltinNp3Catalog.sampleScenes) ...[
            Builder(builder: (context) {
              final selected =
                  _customSamplePath == null && _selectedSceneId == scene.id;
              return Padding(
                padding: const EdgeInsets.only(right: ZSpace.xs),
                child: InkWell(
                  borderRadius: ZRadius.brPill,
                  onTap: () {
                    setState(() {
                      _customSamplePath = null;
                      _selectedSceneId = scene.id;
                    });
                    _triggerRenderActivePreview();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? zc.accentContainer : zc.surface,
                      borderRadius: ZRadius.brPill,
                      border: Border.all(
                        color: selected ? zc.accent : zc.outline,
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      L10n.tr(scene.labelZh, lang),
                      style: zt.caption.copyWith(
                        color: selected ? zc.accent : zc.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
          InkWell(
            borderRadius: ZRadius.brPill,
            onTap: _pickCustomSampleImage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _customSamplePath != null
                    ? zc.accentContainer
                    : zc.surfaceHigh,
                borderRadius: ZRadius.brPill,
                border: Border.all(
                  color: _customSamplePath != null ? zc.accent : zc.outline,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 13,
                    color: _customSamplePath != null
                        ? zc.accent
                        : zc.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.pcPickCustomSampleAction,
                    style: zt.caption.copyWith(
                      color: _customSamplePath != null
                          ? zc.accent
                          : zc.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 257点 15-bit 曲线可视化与参数仪表盘
  // =========================================================
  Widget _buildCurveAndParamsCard(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final active = _selectedItem;
    if (active == null) return const SizedBox.shrink();

    final recipe = active.recipe;
    final lut256 = PictureControlPreviewRenderer.buildToneLut256(recipe);

    return ZCard(
      padding: const EdgeInsets.all(ZSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题与双名称展示
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(active.displayTitle, style: zt.headline),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${active.cameraName} · ${_baseLocalizedName(context, recipe.base)} (${recipe.base.codeName})',
                      style: zt.numericSmall.copyWith(color: zc.textSecondary),
                    ),
                  ],
                ),
              ),
              ZTag(
                text: switch (recipe.format) {
                  PictureControlFormat.np3Standard => 'NP3 · 0300',
                  PictureControlFormat.ncpLegacy => 'NCP · 0100',
                  PictureControlFormat.np3FlexibleColor => 'FC-NP3 · 0310',
                },
                color: recipe.canWriteToCamera ? zc.success : zc.warning,
              ),
            ],
          ),
          if (active.description.isNotEmpty) ...[
            const SizedBox(height: ZSpace.xs),
            Text(
              active.description,
              style: zt.caption.copyWith(color: zc.textSecondary),
            ),
          ],
          const SizedBox(height: ZSpace.md),

          // Flexible Color (0310) 转换横幅
          if (!recipe.canWriteToCamera) ...[
            Container(
              padding: const EdgeInsets.all(ZSpace.sm),
              margin: const EdgeInsets.only(bottom: ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surfaceHigh,
                borderRadius: ZRadius.brSm,
                border: Border.all(color: zc.warning.withAlpha(120)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: zc.warning),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Text(
                      l10n.pcFcConvertHint,
                      style: zt.caption.copyWith(color: zc.textSecondary),
                    ),
                  ),
                  const SizedBox(width: ZSpace.sm),
                  ZButton(
                    label: l10n.pcFcConvertButton,
                    size: ZButtonSize.sm,
                    onTap: () => _handleConvertFlexibleItem(active),
                  ),
                ],
              ),
            ),
          ],

          // 曲线 + 核心参数并排展示
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：色调曲线绘制盒
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.pcCurveTitle, style: zt.label),
                  const SizedBox(height: ZSpace.xs),
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: zc.canvas,
                      borderRadius: ZRadius.brSm,
                      border: Border.all(color: zc.outline),
                    ),
                    child: CustomPaint(
                      painter: _PictureControlCurvePainter(
                        lut256: lut256,
                        controlPoints: recipe.curvePoints,
                        curveColor: zc.accent,
                        gridColor: zc.outline,
                        pointColor: zc.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: ZSpace.md),
              // 右侧：参数矩阵
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.pcParamsTitle, style: zt.label),
                    const SizedBox(height: ZSpace.xs),
                    Wrap(
                      spacing: ZSpace.xs,
                      runSpacing: ZSpace.xs,
                      children: [
                        _buildParamPill(
                          context,
                          l10n.pcParamBase,
                          recipe.base.codeName,
                        ),
                        _buildParamPill(
                          context,
                          l10n.pcParamSharpening,
                          PictureControlRecipe.formatStep(
                              recipe.sharpeningQuarters),
                        ),
                        _buildParamPill(
                          context,
                          l10n.pcParamMidSharpening,
                          PictureControlRecipe.formatStep(
                              recipe.midRangeSharpeningQuarters),
                        ),
                        _buildParamPill(
                          context,
                          l10n.pcParamClarity,
                          PictureControlRecipe.formatStep(
                              recipe.clarityQuarters),
                        ),
                        _buildParamPill(
                          context,
                          l10n.pcParamContrast,
                          recipe.hasCustomCurve
                              ? 'CURVE'
                              : PictureControlRecipe.formatStep(
                                  recipe.contrastQuarters),
                        ),
                        _buildParamPill(
                          context,
                          l10n.pcParamBrightness,
                          recipe.hasCustomCurve
                              ? 'CURVE'
                              : PictureControlRecipe.formatStep(
                                  recipe.brightnessQuarters),
                        ),
                        if (recipe.isMonochrome) ...[
                          _buildParamPill(
                            context,
                            l10n.pcParamMonoFilter,
                            'F:${recipe.monoFilter}',
                          ),
                          _buildParamPill(
                            context,
                            l10n.pcParamMonoToning,
                            'T:${recipe.monoToning}',
                          ),
                        ] else ...[
                          _buildParamPill(
                            context,
                            l10n.pcParamSaturation,
                            PictureControlRecipe.formatStep(
                                recipe.saturationQuarters),
                          ),
                          _buildParamPill(
                            context,
                            l10n.pcParamHue,
                            PictureControlRecipe.formatStep(recipe.hueQuarters),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamPill(BuildContext context, String label, String value) {
    final zc = context.zc;
    final zt = context.zt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: zt.caption.copyWith(color: zc.textSecondary)),
          Text(
            value,
            style: zt.numericSmall.copyWith(
              color: zc.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // 右侧/下方 `[ 本地配方库 | 相机槽位 C1–C9 ]` 管理面板
  // =========================================================
  Widget _buildRightTabbedManagementPanel(
    BuildContext context, {
    required bool isTabletMode,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;

    return Column(
      children: [
        Container(
          color: zc.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: zc.accent,
            labelColor: zc.accent,
            unselectedLabelColor: zc.textSecondary,
            tabs: [
              Tab(
                key: const ValueKey<String>('pc_tab_local_library'),
                text: l10n.pcTabLocalLibrary(_filteredItems.length),
              ),
              Tab(
                key: const ValueKey<String>('pc_tab_camera_slots'),
                text: l10n.pcTabCameraSlots,
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLocalLibraryTab(context, isTabletMode: isTabletMode),
              _buildCameraSlotsTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocalLibraryTab(
    BuildContext context, {
    required bool isTabletMode,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final items = _filteredItems;
    final isPaged = isTabletMode && AppSettings.instance.tabletFilterViewPaged;

    return Column(
      children: [
        // 顶部筛选栏 + 平板列表/分页切换器
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.md,
            vertical: ZSpace.xs,
          ),
          decoration: BoxDecoration(
            color: zc.surface,
            border: Border(bottom: BorderSide(color: zc.outline, width: 0.6)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildCategoryFilterChips(context),
              ),
              if (isTabletMode) ...[
                const SizedBox(width: ZSpace.xs),
                _buildTabletViewToggle(context, isPaged: isPaged),
              ],
            ],
          ),
        ),
        // 窄屏下显示当前选中配方的曲线与参数简要横条
        if (!isTabletMode && _selectedItem != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZSpace.md,
              ZSpace.xs,
              ZSpace.md,
              0,
            ),
            child: _buildCompactMobileParamBar(context, _selectedItem!),
          ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(l10n.commonNone, style: zt.bodySmall),
                )
              : isPaged
                  ? _buildPagedLibraryView(context, items)
                  : Scrollbar(
                      controller: _libScrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: _libScrollController,
                        padding: const EdgeInsets.all(ZSpace.md),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: ZSpace.sm),
                        itemBuilder: (ctx, idx) =>
                            _buildRecipeLibraryCard(ctx, items[idx]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCompactMobileParamBar(
    BuildContext context,
    PictureControlLibraryItem item,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final r = item.recipe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brSm,
        border: Border.all(color: zc.outline, width: 0.7),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: zc.canvas,
              borderRadius: ZRadius.brSm,
              border: Border.all(color: zc.outline),
            ),
            child: CustomPaint(
              painter: _PictureControlCurvePainter(
                lut256: PictureControlPreviewRenderer.buildToneLut256(r),
                controlPoints: r.curvePoints,
                curveColor: zc.accent,
                gridColor: zc.outline,
                pointColor: zc.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.displayTitle} [${item.cameraName}]',
                  style: zt.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_baseLocalizedName(context, r.base)} · '
                  '${l10n.pcParamSharpening} ${PictureControlRecipe.formatStep(r.sharpeningQuarters)} · '
                  '${l10n.pcParamClarity} ${PictureControlRecipe.formatStep(r.clarityQuarters)}',
                  style: zt.caption.copyWith(color: zc.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!r.canWriteToCamera)
            ZButton(
              label: l10n.pcFcConvertButton,
              size: ZButtonSize.sm,
              onTap: () => _handleConvertFlexibleItem(item),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChips(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    String getCategoryLabel(PictureControlCategory cat) => switch (cat) {
          PictureControlCategory.all => l10n.pcFilterAll,
          PictureControlCategory.portrait => l10n.pcCategoryPortrait,
          PictureControlCategory.landscape => l10n.pcCategoryLandscape,
          PictureControlCategory.street => l10n.pcCategoryStreet,
          PictureControlCategory.vintage => l10n.pcCategoryFilm,
          PictureControlCategory.cinema => l10n.pcCategoryCinematic,
          PictureControlCategory.airy => l10n.pcCategoryAiry,
          PictureControlCategory.night => l10n.pcCategoryNight,
          PictureControlCategory.mono => l10n.pcCategoryMono,
        };

    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final cat in PictureControlCategory.values) ...[
            Builder(builder: (ctx) {
              final selected = _categoryFilter == cat;
              final count = cat == PictureControlCategory.all
                  ? _store.items.length
                  : _store.items.where((e) => e.category == cat).length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  borderRadius: ZRadius.brPill,
                  onTap: () {
                    setState(() {
                      _categoryFilter = cat;
                      _libCurrentPage = 0;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? zc.accentContainer : zc.surfaceHigh,
                      borderRadius: ZRadius.brPill,
                      border: Border.all(
                        color: selected ? zc.accent : zc.outline,
                        width: 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${getCategoryLabel(cat)} ($count)',
                      style: zt.caption.copyWith(
                        color: selected ? zc.accent : zc.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletViewToggle(
    BuildContext context, {
    required bool isPaged,
  }) {
    final zc = context.zc;
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: zc.surfaceHigh,
        borderRadius: ZRadius.brPill,
        border: Border.all(color: zc.outline, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.wmViewModeListTooltip,
            child: InkWell(
              borderRadius: ZRadius.brPill,
              onTap: () {
                AppSettings.instance.setTabletFilterViewPaged(false);
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.view_agenda_outlined,
                  size: 15,
                  color: !isPaged ? zc.accent : zc.textSecondary,
                ),
              ),
            ),
          ),
          Tooltip(
            message: l10n.wmViewModePagedTooltip,
            child: InkWell(
              borderRadius: ZRadius.brPill,
              onTap: () {
                AppSettings.instance.setTabletFilterViewPaged(true);
                setState(() {});
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 15,
                  color: isPaged ? zc.accent : zc.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagedLibraryView(
    BuildContext context,
    List<PictureControlLibraryItem> items,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cardHeight = 114.0;
        const gap = 8.0;
        const bottomBarH = 40.0;
        final availH = math.max(120.0, constraints.maxHeight - bottomBarH - 16);
        final rowsPerPage = math.max(1, (availH / (cardHeight + gap)).floor());
        final pageCount = (items.length / rowsPerPage).ceil().clamp(1, 999);
        final safePage = _libCurrentPage.clamp(0, pageCount - 1);

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _libPageController,
                itemCount: pageCount,
                onPageChanged: (p) => setState(() => _libCurrentPage = p),
                itemBuilder: (ctx, pageIdx) {
                  final start = pageIdx * rowsPerPage;
                  final end = math.min(items.length, start + rowsPerPage);
                  final slice = items.sublist(start, end);
                  return Padding(
                    padding: const EdgeInsets.all(ZSpace.md),
                    child: Column(
                      children: [
                        for (var i = 0; i < slice.length; i++) ...[
                          if (i > 0) const SizedBox(height: gap),
                          _buildRecipeLibraryCard(ctx, slice[i]),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              height: bottomBarH,
              padding: const EdgeInsets.symmetric(horizontal: ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surface,
                border: Border(top: BorderSide(color: zc.outline, width: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.wmTabletPagePrev,
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    onPressed: safePage > 0
                        ? () => _libPageController.previousPage(
                              duration: ZMotion.fast,
                              curve: Curves.easeOut,
                            )
                        : null,
                  ),
                  Text(
                    l10n.wmTabletPageIndicator(safePage + 1, pageCount),
                    style: zt.numericSmall,
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.wmTabletPageNext,
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    onPressed: safePage < pageCount - 1
                        ? () => _libPageController.nextPage(
                              duration: ZMotion.fast,
                              curve: Curves.easeOut,
                            )
                        : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecipeLibraryCard(
    BuildContext context,
    PictureControlLibraryItem item,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final selected = _selectedItem?.id == item.id;
    final recipe = item.recipe;

    return Material(
      color: selected ? zc.surfaceHigh : zc.surface,
      borderRadius: ZRadius.brMd,
      child: InkWell(
        borderRadius: ZRadius.brMd,
        onTap: () {
          setState(() {
            _selectedItemId = item.id;
          });
          _triggerRenderActivePreview();
        },
        child: Container(
          padding: const EdgeInsets.all(ZSpace.md),
          decoration: BoxDecoration(
            borderRadius: ZRadius.brMd,
            border: Border.all(
              color: selected ? zc.accent : zc.outline,
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题与分类/基底标签行
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayTitle,
                          style: zt.title.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? zc.accent : zc.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.cameraName} · ${_baseLocalizedName(context, recipe.base)}'
                          '${recipe.hasCustomCurve ? " · CURVE" : ""}',
                          style: zt.numericSmall.copyWith(
                            color: zc.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: ZSpace.xs),
                  // 分类徽章
                  if (item.category != PictureControlCategory.all) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.outline, width: 0.6),
                      ),
                      child: Text(
                        item.category.labelZh,
                        style: zt.caption.copyWith(
                          fontSize: 10,
                          color: zc.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // FC 近似还原标识或标准基底标识
                  if (item.isFlexibleColor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: zc.accentContainer,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.accent, width: 0.6),
                      ),
                      child: Text(
                        l10n.pcApproxBadge,
                        style: zt.numericSmall.copyWith(
                          fontSize: 10,
                          color: zc.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.outline, width: 0.6),
                      ),
                      child: Text(
                        recipe.base.codeName,
                        style: zt.numericSmall.copyWith(
                          fontSize: 10,
                          color: zc.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: ZSpace.xs),
                Text(
                  item.description,
                  style: zt.caption.copyWith(
                    color: zc.textTertiary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: ZSpace.sm),
              // 底部统一操作按钮行：写入相机 C1–C9 + 重命名/分享/删除
              Row(
                children: [
                  Expanded(
                    child: ZButton(
                      label: l10n.pcWriteToCameraButton,
                      icon: Icons.upload_rounded,
                      size: ZButtonSize.sm,
                      onTap: () => _showWriteToSlotDialog(item),
                    ),
                  ),
                  const SizedBox(width: ZSpace.xs),
                  ZIconButton(
                    icon: Icons.drive_file_rename_outline_rounded,
                    tooltip: l10n.pcRenameAction,
                    onTap: () => _showRenameDialog(item),
                  ),
                  const SizedBox(width: 4),
                  ZIconButton(
                    icon: Icons.ios_share_rounded,
                    tooltip: l10n.pcShareAction,
                    onTap: () => _shareRecipeItem(item),
                  ),
                  const SizedBox(width: 4),
                  ZIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: l10n.commonDelete,
                    onTap: () => _showDeleteConfirmDialog(item),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // 相机 C1–C9 槽位管理页签
  // =========================================================
  Widget _buildCameraSlotsTab(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    if (!widget.driver.isConnected) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ZSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phonelink_off_rounded,
                size: 42,
                color: zc.textTertiary,
              ),
              const SizedBox(height: ZSpace.md),
              Text(l10n.pcDisconnectedEmptyTitle, style: zt.headline),
              const SizedBox(height: ZSpace.xs),
              Text(
                l10n.pcDisconnectedEmptySub,
                style: zt.bodySmall.copyWith(color: zc.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingSlots && _cameraSlots.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: zc.accent),
      );
    }

    final displaySlots = _cameraSlots.isNotEmpty
        ? _cameraSlots
        : [
            for (var s = 1; s <= 9; s++)
              CameraPictureControlSlot(
                slotNumber: s,
                profileId: 200 + s,
                isPopulated: false,
              ),
          ];

    return Scrollbar(
      controller: _slotScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _slotScrollController,
        padding: const EdgeInsets.all(ZSpace.md),
        itemCount: displaySlots.length,
        separatorBuilder: (_, __) => const SizedBox(height: ZSpace.sm),
        itemBuilder: (ctx, idx) => _buildCameraSlotCard(ctx, displaySlots[idx]),
      ),
    );
  }

  Widget _buildCameraSlotCard(
    BuildContext context,
    CameraPictureControlSlot slot,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final recipe = slot.recipe;

    return ZCard(
      padding: const EdgeInsets.all(ZSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: slot.isActive ? zc.accent : zc.surfaceHigh,
                  borderRadius: ZRadius.brSm,
                ),
                child: Text(
                  slot.slotCode,
                  style: zt.numeric.copyWith(
                    color: slot.isActive ? zc.onAccent : zc.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: ZSpace.sm),
              Expanded(
                child: slot.isPopulated && recipe != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.cameraName,
                            style: zt.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_baseLocalizedName(context, recipe.base)} (${recipe.base.codeName}) · '
                            '${l10n.pcParamSharpening} ${PictureControlRecipe.formatStep(recipe.sharpeningQuarters)}'
                            '${recipe.hasCustomCurve ? " · CURVE" : ""}',
                            style: zt.caption.copyWith(color: zc.textSecondary),
                          ),
                        ],
                      )
                    : Text(
                        l10n.pcSlotEmptyLabel,
                        style: zt.bodySmall.copyWith(color: zc.textTertiary),
                      ),
              ),
              if (slot.isActive)
                ZTag(
                  text: l10n.pcSlotActiveBadge,
                  color: zc.success,
                ),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          Wrap(
            spacing: ZSpace.xs,
            runSpacing: ZSpace.xs,
            children: [
              ZButton(
                label: l10n.pcSlotOverwriteButton,
                icon: Icons.upload_rounded,
                size: ZButtonSize.sm,
                onTap: _isWritingSlot
                    ? null
                    : () => _showPickRecipeForSlotDialog(slot.slotNumber),
              ),
              if (slot.isPopulated && !slot.isActive)
                ZButton(
                  label: l10n.pcSlotSetActiveButton,
                  icon: Icons.check_circle_outline_rounded,
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.sm,
                  onTap: () async {
                    final ok = await widget.driver
                        .setActivePictureControl(slot.profileId);
                    await refreshCameraSlots();
                    if (!context.mounted) return;
                    showZToast(
                      context,
                      ok
                          ? l10n.pcSlotActivatedToast(slot.slotCode)
                          : l10n.pcSlotActivateFailedToast,
                      tone: ok ? ZStatusTone.success : ZStatusTone.warning,
                    );
                  },
                ),
              if (slot.isPopulated && recipe != null)
                ZButton(
                  label: l10n.pcSlotBackupToLocalButton,
                  icon: Icons.download_rounded,
                  variant: ZButtonVariant.ghost,
                  size: ZButtonSize.sm,
                  onTap: () => _backupCameraSlotToLocal(slot),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 257 点色调曲线绘制画笔。
class _PictureControlCurvePainter extends CustomPainter {
  final Uint8List lut256;
  final List<PictureControlCurvePoint> controlPoints;
  final Color curveColor;
  final Color gridColor;
  final Color pointColor;

  const _PictureControlCurvePainter({
    required this.lut256,
    required this.controlPoints,
    required this.curveColor,
    required this.gridColor,
    required this.pointColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withAlpha(110)
      ..strokeWidth = 0.7;

    // 4x4 网格与对角基准线
    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4.0;
      final dy = size.height * i / 4.0;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gridPaint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      gridPaint..color = gridColor.withAlpha(160),
    );

    if (lut256.length < 256) return;

    final path = Path();
    for (var i = 0; i < 256; i++) {
      final x = (i / 255.0) * size.width;
      final y = size.height - (lut256[i] / 255.0) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final curvePaint = Paint()
      ..color = curveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, curvePaint);

    // 绘制控制点
    final dotPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;
    for (final pt in controlPoints) {
      final cx = (pt.x.clamp(0, 255) / 255.0) * size.width;
      final cy = size.height - (pt.y.clamp(0, 255) / 255.0) * size.height;
      canvas.drawCircle(Offset(cx, cy), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PictureControlCurvePainter oldDelegate) {
    return oldDelegate.lut256 != lut256 ||
        oldDelegate.curveColor != curveColor ||
        oldDelegate.controlPoints != controlPoints;
  }
}
