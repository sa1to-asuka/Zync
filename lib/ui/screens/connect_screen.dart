import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/settings/app_settings.dart';
import '../../core/utils/app_log_manager.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../engine/transfer/shoot_and_transfer.dart';
import '../../l10n/engine_l10n.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/nikon_ble_lss.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/bento_card.dart';
import 'connect/link_camera_screen.dart';
import 'gallery_screen.dart';

/// 主页快捷功能的一项，供平板横向卡片和手机 Bento 磁贴共用。
class _HubAction {
  const _HubAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
    this.progress,
    this.dimmed = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;
  final double? progress;
  final bool dimmed;
}

/// 摄影师工作台式主页 (Bento Studio Hub)：
/// - 顶部：智能自动探测相机舱（已连接实时仪表盘+边拍边传开关 / 未连接自动识别 USB/Wi-Fi 直连双按钮+连接指南）
/// - 中部：2×2 Bento 核心功能磁贴（选片快传、水印暗房、拼图工坊、传输中心）
/// - 底部：最近影像直览流（点图即修/即看）
class ConnectScreen extends StatefulWidget {
  final CameraDriver driver;
  final VoidCallback onConnected;

  /// 用户主动断开时通知外层，用于取消正在进行的自动重连。
  final VoidCallback? onDisconnect;
  final void Function({bool exportedTab, bool enterCollagePick})?
      onNavigateToGallery;
  final void Function({
    Uint8List? initialBytes,
    PhotoMetadata? meta,
    bool openFilter,
  })? onOpenWatermark;
  final VoidCallback? onOpenTransferCenter;

  /// 打开实时取景（手机端会全屏进入，平板端切到拍摄页）。
  final VoidCallback? onOpenCapture;

  /// 切到色彩优化页并直接拉起配方导入。
  final VoidCallback? onImportColor;
  final DownloadManager? downloadManager;
  final ShootAndTransferController? shootAndTransferController;

  const ConnectScreen({
    super.key,
    required this.driver,
    required this.onConnected,
    this.onDisconnect,
    this.onNavigateToGallery,
    this.onOpenWatermark,
    this.onOpenTransferCenter,
    this.onOpenCapture,
    this.onImportColor,
    this.downloadManager,
    this.shootAndTransferController,
  });

  @override
  State<ConnectScreen> createState() => ConnectScreenState();
}

class ConnectScreenState extends State<ConnectScreen>
    with WidgetsBindingObserver {
  // Wi-Fi 状态
  WifiNetworkInfo _wifiInfo = WifiNetworkInfo(
    connected: false,
    bound: false,
    ssid: '',
    gateway: '192.168.0.1',
    ip: '192.168.0.2',
  );

  // USB 状态
  List<UsbDeviceInfo> _usbDevices = [];
  bool _isUsbScanning = false;

  // 相机实时参数（镜头焦段/当前焦距/当前光圈）
  CameraExposureParams _lensParams = const CameraExposureParams();

  // 历史导出管理器
  final ExportHistoryManager _historyManager = ExportHistoryManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historyManager.refresh();
    _historyManager.addListener(_onHistoryChanged);
    _refreshWifiStatus();
    _handleUsbRefresh();
    if (widget.driver.isConnected) _refreshLensInfo();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _historyManager.removeListener(_onHistoryChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWifiStatus();
      _handleUsbRefresh();
      _historyManager.refresh();
      if (widget.driver.isConnected) _refreshLensInfo();
    }
  }

  Future<void> _refreshLensInfo() async {
    if (!widget.driver.isConnected) return;
    try {
      final p = await widget.driver.fetchExposureParams();
      if (mounted) setState(() => _lensParams = p);
    } catch (_) {}
  }

  void _addLog(String msg) {
    AppLogManager.instance.add(msg);
  }

  // ==========================================
  // Wi-Fi 连接逻辑
  // ==========================================
  Future<void> _refreshWifiStatus() async {
    final info = await CameraNativeBridge.getWifiInfo();
    if (mounted) {
      setState(() {
        _wifiInfo = info;
      });
    }
  }

  Future<void> _openLinkCamera() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinkCameraScreen(
          driver: widget.driver,
          onConnected: widget.onConnected,
          onDisconnect: widget.onDisconnect,
        ),
      ),
    );
    if (mounted) {
      await _refreshWifiStatus();
      await _handleUsbRefresh();
      if (widget.driver.isConnected) await _refreshLensInfo();
    }
  }

  Future<void> _handleDisconnect() async {
    widget.onDisconnect?.call();
    await widget.driver.disconnect();
    await CameraNativeBridge.unbindWifi();
    _addLog('已断开与相机的连接并释放网络绑定');
    if (mounted) setState(() {});
  }

  bool _looksLikeCameraWifi(WifiNetworkInfo info) {
    final ssid = info.ssid.toUpperCase();
    if (ssid.contains('NIKON')) return true;
    return info.gateway == '192.168.0.1' || info.gateway == '192.168.1.1';
  }

  // ==========================================
  // USB 连接逻辑
  // ==========================================
  Future<void> _handleUsbRefresh() async {
    if (_isUsbScanning) return;
    setState(() => _isUsbScanning = true);
    try {
      final devices = await CameraNativeBridge.listUsbDevices();
      devices.sort((a, b) {
        if (a.isNikon != b.isNikon) return a.isNikon ? -1 : 1;
        if (a.ptpReady != b.ptpReady) return a.ptpReady ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      if (mounted) setState(() => _usbDevices = devices);
    } catch (e) {
      _addLog('USB 设备扫描失败: $e');
    } finally {
      if (mounted) setState(() => _isUsbScanning = false);
    }
  }

  /// 弹出图文连接指南抽屉（整合 Wi-Fi 与 USB 步骤）
  void _showConnectionGuideSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.zc.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.xl)),
      ),
      builder: (sheetCtx) {
        final zc = sheetCtx.zc;
        final zt = sheetCtx.zt;
        final l10n = sheetCtx.l10n;
        final sheetLang = L10n.current.localeName;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              ZSpace.xl,
              ZSpace.lg,
              ZSpace.xl,
              ZSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: zc.outlineStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: ZSpace.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.hubGuideTitle, style: zt.headline),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                ZSection(
                  title: EngineL10n.linkModeLan(sheetLang),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ZSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final step
                              in EngineL10n.linkLanSteps(sheetLang))
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: ZSpace.xs),
                              child: Text(
                                '${step.$1} · ${step.$2}',
                                style: zt.bodySmall.copyWith(height: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                ZSection(
                  title: EngineL10n.linkModeHotspot(sheetLang),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ZSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final step
                              in EngineL10n.linkHotspotSteps(sheetLang))
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: ZSpace.xs),
                              child: Text(
                                '${step.$1} · ${step.$2}',
                                style: zt.bodySmall.copyWith(height: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                ZSection(
                  title: EngineL10n.linkModeUsb(sheetLang),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ZSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final step in EngineL10n.linkUsbSteps(sheetLang))
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: ZSpace.xs),
                              child: Text(
                                '${step.$1} · ${step.$2}',
                                style: zt.bodySmall.copyWith(height: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.lg),
                ZButton(
                  label: EngineL10n.linkGoConnect(sheetLang),
                  icon: Icons.login_rounded,
                  expanded: true,
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _openLinkCamera();
                  },
                ),
                const SizedBox(height: ZSpace.sm),
                ZButton(
                  label: l10n.hubGuideClose,
                  variant: ZButtonVariant.ghost,
                  expanded: true,
                  onTap: () => Navigator.pop(sheetCtx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 系统返回消费（主页无需特殊返回处理，返回 false 走系统双击退出）
  bool handleSystemBack() => false;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final isConnected = widget.driver.isConnected;

    final cockpit = _buildSmartCameraCockpitCard(context, isConnected);

    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.hubTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: ZSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isConnected ? zc.accentMuted : zc.surfaceHigh,
                borderRadius: ZRadius.brPill,
                border: Border.all(
                  color: isConnected ? zc.accent : zc.outline,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? zc.success : zc.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isConnected
                        ? l10n.connectStateConnected
                        : l10n.connectStateDisconnected,
                    style: zt.caption.copyWith(
                      color: isConnected ? zc.accent : zc.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: l10n.hubHelpGuideTooltip,
            onPressed: _showConnectionGuideSheet,
          ),
          if (isConnected)
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.sm),
              child: ZButton(
                label: l10n.connectDisconnectShort,
                variant: ZButtonVariant.ghost,
                size: ZButtonSize.sm,
                onTap: _handleDisconnect,
              ),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, viewport) {
          // 平板横屏才切到左右仪表盘；600–900 的窗口保持单列，
          // 否则左固定列 + 右磁贴会被挤成两条窄缝。
          final isDashboard = viewport.maxWidth >= 900;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              isDashboard ? ZSpace.xl : ZSpace.lg,
              isDashboard ? ZSpace.xl : ZSpace.md,
              isDashboard ? ZSpace.xl : ZSpace.lg,
              ZSpace.xxl,
            ),
            child: AdaptiveContent(
              maxWidth: isDashboard ? 1200 : 760,
              child: isDashboard
                  ? _buildDashboardBody(context)
                  : _buildCompactBody(context, cockpit),
            ),
          );
        },
      ),
    );
  }

  /// 平板仪表盘：整宽相机横幅 → GPS → 3 列快捷卡 → 大图最近影像。
  Widget _buildDashboardBody(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWideCameraHero(context),
        const SizedBox(height: ZSpace.md),
        _buildGpsQuickBar(context),
        const SizedBox(height: ZSpace.xl),
        Row(
          children: [
            Text(
              EngineL10n.hubQuickActions(L10n.current.localeName),
              style: zt.title,
            ),
            const Spacer(),
            if (_historyManager.items.isNotEmpty)
              Text(
                '${_historyManager.items.length}',
                style: zt.caption.copyWith(color: zc.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: ZSpace.md),
        _buildWideActionGrid(context),
        const SizedBox(height: ZSpace.xl),
        _buildRecentPhotosStrip(context, thumbSize: 140),
      ],
    );
  }

  /// 手机 / 窄窗口：单列纵向流。
  Widget _buildCompactBody(BuildContext context, Widget cockpit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cockpit,
        const SizedBox(height: ZSpace.lg),
        _buildBentoActionGrid(context),
        const SizedBox(height: ZSpace.xl),
        _buildRecentPhotosStrip(context),
      ],
    );
  }

  /// 平板相机横幅：左侧身份与状态，右侧连接/边拍边传操作。
  Widget _buildWideCameraHero(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final lang = L10n.current.localeName;
    final isConnected = widget.driver.isConnected;
    final cameraName = widget.driver.cameraModel.isNotEmpty
        ? widget.driver.cameraModel
        : l10n.connectMyCamera;
    final isUsb = widget.driver.transportKind == CameraTransportKind.usb;
    final modeLabel = isUsb
        ? l10n.connectModeUsb
        : switch (AppSettings.instance.lastLinkMethod) {
            'lan' => EngineL10n.linkModeLan(lang),
            _ => l10n.connectModeWifi,
          };
    final hasLens = _lensParams.lensInfo != '--';
    final lensText = hasLens
        ? '${_lensParams.lensInfo} · ${_lensParams.focalLength} · '
            '${_lensParams.aperture}'
        : '';
    final autoTransfer =
        widget.shootAndTransferController?.isEnabled ?? false;

    return Container(
      padding: const EdgeInsets.all(ZSpace.xl),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brXl,
        border: Border.all(color: zc.accent.withAlpha(70), width: 0.8),
        boxShadow: zc.cardShadow,
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: zc.accent.withAlpha(16),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: ZRadius.brMd,
                  border: Border.all(color: zc.outline, width: 0.8),
                  boxShadow: zc.cardShadow,
                ),
                child: Image.asset(
                  'assets/icons/zync_logo.png',
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.camera_alt_outlined,
                    color: zc.accent,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: ZSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isConnected ? cameraName : l10n.connectMyCamera,
                        style: zt.display.copyWith(fontSize: 26),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    ZStatusPill(
                      text: isConnected
                          ? l10n.connectStateConnected
                          : l10n.connectStateDisconnected,
                      tone: isConnected
                          ? ZStatusTone.accent
                          : ZStatusTone.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.xs),
                Text(
                  isConnected
                      ? (lensText.isEmpty
                          ? modeLabel
                          : '$lensText · $modeLabel')
                      : l10n.connectHeroSubtitle,
                  style: zt.bodySmall.copyWith(color: zc.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: ZSpace.lg),
          if (!isConnected)
            ZButton(
              label: EngineL10n.linkGoConnect(lang),
              icon: Icons.login_rounded,
              size: ZButtonSize.lg,
              onTap: _openLinkCamera,
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync_alt_rounded,
                  size: 15,
                  color: autoTransfer ? zc.success : zc.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.hubShootAndTransferQuick,
                  style: zt.caption.copyWith(
                    fontWeight:
                        autoTransfer ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Switch(
                  value: autoTransfer,
                  activeThumbColor: zc.success,
                  activeTrackColor: zc.success.withAlpha(100),
                  onChanged: (val) {
                    setState(() {
                      widget.shootAndTransferController?.setEnabled(val);
                    });
                  },
                ),
                const SizedBox(width: ZSpace.sm),
                ZButton(
                  label: l10n.connectBrowsePhotos,
                  icon: Icons.photo_library_outlined,
                  variant: ZButtonVariant.tonal,
                  onTap: () => widget.onNavigateToGallery?.call(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 平板快捷功能：3 列横向卡片，信息密度比小方块磁贴更舒服。
  Widget _buildWideActionGrid(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.downloadManager ?? Listenable.merge(const []),
      builder: (ctx, _) {
        final actions = _hubActions(ctx);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: ZSpace.md,
            mainAxisSpacing: ZSpace.md,
            mainAxisExtent: 96,
          ),
          itemBuilder: (context, index) =>
              _buildWideActionCard(context, actions[index]),
        );
      },
    );
  }

  Widget _buildWideActionCard(BuildContext context, _HubAction action) {
    final zc = context.zc;
    final zt = context.zt;
    return Opacity(
      opacity: action.dimmed ? 0.55 : 1.0,
      child: ZCard(
        elevated: true,
        onTap: action.onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.accent.withAlpha(32),
                borderRadius: ZRadius.brSm,
              ),
              child: Icon(action.icon, color: action.accent, size: 21),
            ),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: zt.label.copyWith(fontSize: 14),
                        ),
                      ),
                      if (action.badge != null) ...[
                        const SizedBox(width: ZSpace.xs),
                        ZTag(
                          text: action.badge!,
                          color: action.accent,
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: zt.caption.copyWith(
                      color: zc.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  if (action.progress != null) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: ZRadius.brPill,
                      child: LinearProgressIndicator(
                        value: action.progress,
                        minHeight: 3,
                        backgroundColor: zc.outline,
                        valueColor: AlwaysStoppedAnimation(action.accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ZSpace.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: zc.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  List<_HubAction> _hubActions(BuildContext context) {
    final l10n = context.l10n;
    final zc = context.zc;
    final liveViewReady =
        widget.driver.isConnected && widget.driver.supportsLiveView;
    final dm = widget.downloadManager;
    final pending = dm?.pendingCount ?? 0;
    final active = pending > 0;

    return [
      _HubAction(
        title: l10n.hubBentoQuickTransferTitle,
        subtitle: l10n.hubBentoQuickTransferSub,
        icon: Icons.photo_library_outlined,
        accent: zc.accent,
        badge: widget.driver.isConnected ? 'LIVE' : null,
        onTap: () => widget.onNavigateToGallery?.call(),
      ),
      _HubAction(
        title: l10n.hubBentoWatermarkTitle,
        subtitle: l10n.hubBentoWatermarkSub,
        icon: Icons.branding_watermark_outlined,
        accent: ZSwatch.nikonGold,
        onTap: () => widget.onOpenWatermark?.call(),
      ),
      _HubAction(
        title: l10n.hubBentoCollageTitle,
        subtitle: l10n.hubBentoCollageSub,
        icon: Icons.auto_awesome_mosaic_outlined,
        accent: zc.info,
        onTap: () => widget.onNavigateToGallery?.call(enterCollagePick: true),
      ),
      _HubAction(
        title: l10n.hubBentoTransfersTitle,
        subtitle: active
            ? l10n.hubBentoTransfersActive(pending)
            : l10n.hubBentoTransfersIdle,
        icon: Icons.swap_vert_circle_outlined,
        accent: active ? zc.danger : zc.textSecondary,
        progress: active ? dm?.currentTask?.progress : null,
        badge: active ? '$pending' : null,
        onTap: () => widget.onOpenTransferCenter?.call(),
      ),
      _HubAction(
        title: l10n.hubBentoColorImportTitle,
        subtitle: l10n.hubBentoColorImportSub,
        icon: Icons.color_lens_outlined,
        accent: zc.accent,
        onTap: () => widget.onImportColor?.call(),
      ),
      _HubAction(
        title: l10n.hubBentoLiveViewTitle,
        subtitle: liveViewReady
            ? l10n.hubBentoLiveViewSub
            : l10n.hubBentoLiveViewOffline,
        icon: Icons.videocam_outlined,
        accent: liveViewReady ? zc.success : zc.textSecondary,
        badge: liveViewReady ? 'LIVE' : null,
        dimmed: !liveViewReady,
        onTap: () => widget.onOpenCapture?.call(),
      ),
    ];
  }

  // ==========================================
  // 1. 智能自动探测相机舱 (已连: 仪表盘 / 未连: 智能直连)
  // ==========================================
  Widget _buildSmartCameraCockpitCard(BuildContext context, bool isConnected) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;

    if (isConnected) {
      final cameraName = widget.driver.cameraModel.isNotEmpty
          ? widget.driver.cameraModel
          : 'NIKON Z';
      final isUsb =
          widget.driver.transportKind == CameraTransportKind.usb;
      final modeLabel = isUsb
          ? l10n.connectModeUsb
          : switch (AppSettings.instance.lastLinkMethod) {
              'lan' => EngineL10n.linkModeLan(L10n.current.localeName),
              _ => l10n.connectModeWifi,
            };
      final hasLens = _lensParams.lensInfo != '--';
      final lensText = hasLens ? _lensParams.lensInfo : '—';
      final autoTransfer =
          widget.shootAndTransferController?.isEnabled ?? false;

      return ZCard(
        elevated: true,
        padding: const EdgeInsets.all(ZSpace.lg),
        borderRadius: ZRadius.brXl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT CAMERA',
                        style: zt.overline.copyWith(
                          color: zc.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cameraName,
                        style: zt.display.copyWith(fontSize: 22),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: zc.accentMuted,
                    borderRadius: ZRadius.brPill,
                    border: Border.all(color: zc.accent, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
                        size: 14,
                        color: zc.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        modeLabel,
                        style: zt.caption.copyWith(
                          color: zc.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZSpace.md),
            // 镜头与参数速览
            Container(
              padding: const EdgeInsets.all(ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surfaceHigh,
                borderRadius: ZRadius.brMd,
                border: Border.all(color: zc.outline, width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 18, color: zc.textSecondary),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: hasLens
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  lensText,
                                  style: zt.caption.copyWith(
                                    color: zc.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('·',
                                  style: zt.caption
                                      .copyWith(color: zc.textSecondary)),
                              const SizedBox(width: 6),
                              Text(
                                _lensParams.focalLength,
                                style: zt.caption.copyWith(
                                  color: zc.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('·',
                                  style: zt.caption
                                      .copyWith(color: zc.textSecondary)),
                              const SizedBox(width: 6),
                              Text(
                                _lensParams.aperture,
                                style: zt.caption.copyWith(
                                  color: zc.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            '—',
                            style: zt.caption.copyWith(
                              color: zc.textSecondary,
                            ),
                          ),
                  ),
                  ZStatusPill(
                    text: hasLens
                        ? l10n.connectLensIdentified
                        : l10n.connectLensUnread,
                    tone: hasLens ? ZStatusTone.accent : ZStatusTone.neutral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpace.md),
            // 边拍边传与快速浏览
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.sync_alt_rounded,
                      size: 16,
                      color: autoTransfer ? zc.success : zc.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.hubShootAndTransferQuick,
                      style: zt.bodySmall.copyWith(
                        fontWeight:
                            autoTransfer ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: autoTransfer,
                      activeThumbColor: zc.success,
                      activeTrackColor: zc.success.withAlpha(100),
                      onChanged: (val) {
                        setState(() {
                          widget.shootAndTransferController?.setEnabled(val);
                        });
                      },
                    ),
                  ],
                ),
                ZButton(
                  label: l10n.connectBrowsePhotos,
                  icon: Icons.photo_library_outlined,
                  size: ZButtonSize.sm,
                  onTap: () => widget.onNavigateToGallery?.call(),
                ),
              ],
            ),
            const SizedBox(height: ZSpace.sm),
            _buildGpsQuickBar(context),
          ],
        ),
      );
    }

    // 未连接状态：智能双探测单卡
    final detectedUsb = _usbDevices.firstWhere(
      (d) => d.ptpReady,
      orElse: () => _usbDevices.isNotEmpty
          ? _usbDevices.first
          : UsbDeviceInfo(
              deviceName: '',
              vendorId: 0,
              productId: 0,
              name: '',
              vendorName: '',
              isNikon: false,
              ptpReady: false,
              hasPermission: false,
            ),
    );
    final hasUsbCamera = detectedUsb.deviceName.isNotEmpty;
    final isCameraWifi = _wifiInfo.connected && _looksLikeCameraWifi(_wifiInfo);

    return ZCard(
      elevated: true,
      padding: const EdgeInsets.all(ZSpace.lg),
      borderRadius: ZRadius.brXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: ZRadius.brMd,
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                child: Image.asset(
                  'assets/icons/zync_logo.png',
                  errorBuilder: (_, __, ___) => SvgPicture.asset(
                    'assets/icons/zync_logo.svg',
                    placeholderBuilder: (_) => Icon(
                      Icons.camera_alt_outlined,
                      color: zc.accent,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.connectMyCamera,
                      style: zt.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUsbCamera
                          ? l10n.connectUsbDetectedHeader
                          : (isCameraWifi
                              ? l10n.connectWifiReadyHint
                              : l10n.connectHeroSubtitle),
                      style: zt.caption.copyWith(
                        color: hasUsbCamera || isCameraWifi
                            ? zc.success
                            : zc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpace.lg),
          ZButton(
            label: EngineL10n.linkGoConnect(L10n.current.localeName),
            icon: Icons.login_rounded,
            size: ZButtonSize.lg,
            expanded: true,
            onTap: _openLinkCamera,
          ),
          const SizedBox(height: ZSpace.sm),
          Text(
            EngineL10n.linkPageSubtitle(L10n.current.localeName),
            style: zt.caption.copyWith(color: zc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZSpace.md),
          _buildGpsQuickBar(context),
        ],
      ),
    );
  }

  // ==========================================
  // 2. 2×2 Bento 核心功能直达磁贴网格
  // ==========================================
  Widget _buildBentoActionGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 平板右侧/整行 >=560 放 3 列；真实平板扣掉左侧导航后右栏约 600dp，
        // 阈值定在 640 会让磁贴掉回 2 列并被拉成大方块。
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        return AnimatedBuilder(
          animation:
              widget.downloadManager ?? Listenable.merge(const <Listenable>[]),
          builder: (ctx, _) {
            final actions = _hubActions(ctx);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: ZSpace.md,
              mainAxisSpacing: ZSpace.md,
              childAspectRatio: columns == 3 ? 1.55 : 1.35,
              children: [
                for (final action in actions)
                  ZBentoCard(
                    title: action.title,
                    subtitle: action.subtitle,
                    icon: action.icon,
                    accentColor: action.accent,
                    progress: action.progress,
                    badgeText: action.badge,
                    dimmed: action.dimmed,
                    onTap: action.onTap,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 3. 底部最近影像直览流 (最近已导出 / 快速送修)
  // ==========================================
  Widget _buildRecentPhotosStrip(
    BuildContext context, {
    double thumbSize = 104,
  }) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final items = _historyManager.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.hubRecentPhotosTitle, style: zt.title),
            if (items.isNotEmpty)
              TextButton(
                onPressed: () =>
                    widget.onNavigateToGallery?.call(exportedTab: true),
                child: Text(
                  l10n.commonView,
                  style: zt.bodySmall.copyWith(
                    color: zc.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: ZSpace.sm),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(ZSpace.xl),
            decoration: BoxDecoration(
              color: zc.surface,
              borderRadius: ZRadius.brLg,
              border: Border.all(color: zc.outline, width: 0.8),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_outlined, size: 20, color: zc.textTertiary),
                const SizedBox(width: ZSpace.sm),
                Text(
                  l10n.hubRecentPhotosEmpty,
                  style: zt.bodySmall.copyWith(color: zc.textTertiary),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: thumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: ZSpace.sm),
              itemBuilder: (context, idx) {
                final item = items[idx];
                return GestureDetector(
                  onTap: () async {
                    try {
                      final file =
                          await ExportHistoryManager().ensureLocalFile(item);
                      final bytes = await file.readAsBytes();
                      final meta = await ExifHelper.parseBytes(bytes);
                      widget.onOpenWatermark?.call(
                        initialBytes: bytes,
                        meta: meta,
                      );
                    } catch (_) {}
                  },
                  child: Container(
                    width: thumbSize,
                    decoration: BoxDecoration(
                      color: zc.surfaceHigh,
                      borderRadius: ZRadius.brMd,
                      border: Border.all(color: zc.outline, width: 0.8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExportedMediaImage(
                          item: item,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: zc.scrim,
                              borderRadius: ZRadius.brXs,
                            ),
                            child: Text(
                              item.formatBadge,
                              style: TextStyle(
                                color: ZyncPalette.dark.textPrimary,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGpsQuickBar(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final lat = NikonBleLss.sessionLatitude;
    final lon = NikonBleLss.sessionLongitude;
    final hasCoord = lat != null && lon != null;

    return InkWell(
      key: const ValueKey('connect-gps-bar'),
      borderRadius: ZRadius.brMd,
      onTap: _showGpsLocationSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.sm,
        ),
        decoration: BoxDecoration(
          color: zc.surfaceHigh,
          borderRadius: ZRadius.brMd,
          border: Border.all(
            color: hasCoord ? zc.accent.withAlpha(120) : zc.outline,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.explore_outlined,
              size: 16,
              color: hasCoord ? zc.accent : zc.textSecondary,
            ),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Text(
                hasCoord
                    ? '${EngineL10n.gpsShootingCoord(l10n.localeName)}: ${NikonBleLss.formatCoordinatesDms(lat, lon)}'
                    : EngineL10n.gpsQuickBarIdle(l10n.localeName),
                style: zt.caption.copyWith(
                  color: hasCoord ? zc.textPrimary : zc.textSecondary,
                  fontWeight: hasCoord ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: ZSpace.xs),
            Text(
              hasCoord
                  ? EngineL10n.gpsEditOrSync(l10n.localeName)
                  : EngineL10n.gpsSetCoords(l10n.localeName),
              style: zt.caption.copyWith(
                color: zc.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: zc.accent),
          ],
        ),
      ),
    );
  }

  void _showGpsLocationSheet() {
    final latController = TextEditingController(
      text: NikonBleLss.sessionLatitude?.toStringAsFixed(6) ?? '',
    );
    final lonController = TextEditingController(
      text: NikonBleLss.sessionLongitude?.toStringAsFixed(6) ?? '',
    );
    final altController = TextEditingController(
      text: NikonBleLss.sessionAltitude != null
          ? NikonBleLss.sessionAltitude!.round().toString()
          : '0',
    );
    List<BleDeviceInfo> bleDevices = [];
    var isScanningBle = false;
    var bleConnectedName = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.zc.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadius.xl)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final zc = ctx.zc;
            final zt = ctx.zt;
            final l10n = ctx.l10n;

            Future<void> refreshBleStatus() async {
              final status = await CameraNativeBridge.getBleStatus();
              if (ctx.mounted) {
                setSheetState(() {
                  bleConnectedName =
                      status['status'] == 'connected'
                          ? (status['deviceName'] as String? ?? 'Nikon BLE')
                          : '';
                });
              }
            }

            if (bleConnectedName.isEmpty && !isScanningBle && bleDevices.isEmpty) {
              refreshBleStatus();
            }

            Widget coordField(
              String label,
              TextEditingController controller,
              String hint,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: zt.caption.copyWith(color: zc.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: controller,
                    style: zt.bodySmall.copyWith(color: zc.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: zt.caption.copyWith(color: zc.textTertiary),
                      filled: true,
                      fillColor: zc.surfaceHigh,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZRadius.sm),
                        borderSide: BorderSide(color: zc.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZRadius.sm),
                        borderSide: BorderSide(color: zc.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(ZRadius.sm),
                        borderSide: BorderSide(color: zc.accent),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ZSpace.xl,
                  ZSpace.lg,
                  ZSpace.xl,
                  MediaQuery.of(ctx).viewInsets.bottom + ZSpace.xl,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            EngineL10n.gpsSheetTitle(l10n.localeName),
                            style: zt.title,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Text(
                        EngineL10n.gpsSheetDesc(l10n.localeName),
                        style: zt.caption.copyWith(
                          color: zc.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: ZSpace.md),
                      Row(
                        children: [
                          Expanded(
                            child: coordField(
                              EngineL10n.gpsLatitudeLabel(l10n.localeName),
                              latController,
                              '31.230416 / 31°13\'49"N',
                            ),
                          ),
                          const SizedBox(width: ZSpace.sm),
                          Expanded(
                            child: coordField(
                              EngineL10n.gpsLongitudeLabel(l10n.localeName),
                              lonController,
                              '121.473701 / 121°28\'25"E',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ZSpace.sm),
                      Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: coordField(
                              EngineL10n.gpsAltitudeLabel(l10n.localeName),
                              altController,
                              '15',
                            ),
                          ),
                          const SizedBox(width: ZSpace.md),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final loc =
                                      await ExifHelper.fetchPhoneLocation();
                                  if (loc != null) {
                                    latController.text =
                                        loc.latitude.toStringAsFixed(6);
                                    lonController.text =
                                        loc.longitude.toStringAsFixed(6);
                                    altController.text =
                                        loc.altitude.round().toString();
                                    setSheetState(() {});
                                  } else if (ctx.mounted) {
                                    showZToast(
                                      ctx,
                                      EngineL10n.gpsFetchFailedToast(
                                          l10n.localeName),
                                      tone: ZStatusTone.warning,
                                    );
                                  }
                                },
                                icon: Icon(
                                  Icons.my_location,
                                  size: 15,
                                  color: zc.accent,
                                ),
                                label: Text(
                                  EngineL10n.gpsFetchPhoneButton(
                                      l10n.localeName),
                                  style: zt.caption.copyWith(
                                    color: zc.accent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ZSpace.md),
                      // BLE 相机扫描/连接状态行
                      Container(
                        padding: const EdgeInsets.all(ZSpace.sm),
                        decoration: BoxDecoration(
                          color: zc.surfaceHigh,
                          borderRadius: ZRadius.brMd,
                          border: Border.all(color: zc.outline, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bluetooth_searching_rounded,
                                  size: 16,
                                  color: bleConnectedName.isNotEmpty
                                      ? zc.success
                                      : zc.accent,
                                ),
                                const SizedBox(width: ZSpace.xs),
                                Expanded(
                                  child: Text(
                                    bleConnectedName.isNotEmpty
                                        ? '${EngineL10n.gpsConnectedBleCamera(l10n.localeName)}: $bleConnectedName'
                                        : EngineL10n.gpsOptionalBleHint(
                                            l10n.localeName),
                                    style: zt.caption.copyWith(
                                      color: bleConnectedName.isNotEmpty
                                          ? zc.success
                                          : zc.textSecondary,
                                      fontWeight: bleConnectedName.isNotEmpty
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: isScanningBle
                                      ? null
                                      : () async {
                                          setSheetState(
                                              () => isScanningBle = true);
                                          await CameraNativeBridge
                                              .startBleScan();
                                          await Future<void>.delayed(
                                            const Duration(milliseconds: 1200),
                                          );
                                          final found = await CameraNativeBridge
                                              .getScannedBleDevices();
                                          await CameraNativeBridge
                                              .stopBleScan();
                                          if (ctx.mounted) {
                                            setSheetState(() {
                                              bleDevices = found;
                                              isScanningBle = false;
                                            });
                                          }
                                        },
                                  child: Text(
                                    isScanningBle
                                        ? EngineL10n.gpsScanningBle(
                                            l10n.localeName)
                                        : EngineL10n.gpsScanBle(
                                            l10n.localeName),
                                    style: zt.caption.copyWith(
                                      color: zc.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (bleDevices.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final d in bleDevices.take(4))
                                    ActionChip(
                                      label: Text(
                                        d.name,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      onPressed: () async {
                                        final res = await CameraNativeBridge
                                            .connectBleDevice(d.address);
                                        if (ctx.mounted &&
                                            res['status'] == 'connected') {
                                          setSheetState(() {
                                            bleConnectedName = d.name;
                                          });
                                        }
                                      },
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZSpace.lg),
                      Row(
                        children: [
                          if (NikonBleLss.sessionLatitude != null)
                            Padding(
                              padding: const EdgeInsets.only(right: ZSpace.sm),
                              child: OutlinedButton(
                                onPressed: () {
                                  NikonBleLss.sessionLatitude = null;
                                  NikonBleLss.sessionLongitude = null;
                                  NikonBleLss.sessionAltitude = null;
                                  if (mounted) setState(() {});
                                  Navigator.pop(ctx);
                                },
                                child: Text(l10n.commonReset),
                              ),
                            ),
                          Expanded(
                            child: ZButton(
                              label: EngineL10n.gpsSaveAndSyncButton(
                                  l10n.localeName),
                              icon: Icons.check_circle_outline,
                              expanded: true,
                              onTap: () async {
                                final lat = NikonBleLss.tryParseCoordinate(
                                  latController.text,
                                  isLatitude: true,
                                );
                                final lon = NikonBleLss.tryParseCoordinate(
                                  lonController.text,
                                  isLatitude: false,
                                );
                                final alt =
                                    double.tryParse(altController.text.trim()) ??
                                        0.0;
                                if (lat == null ||
                                    lon == null ||
                                    lat < -90 ||
                                    lat > 90 ||
                                    lon < -180 ||
                                    lon > 180) {
                                  showZToast(
                                    ctx,
                                    EngineL10n.gpsInvalidRangeToast(
                                        l10n.localeName),
                                    tone: ZStatusTone.warning,
                                  );
                                  return;
                                }
                                NikonBleLss.sessionLatitude = lat;
                                NikonBleLss.sessionLongitude = lon;
                                NikonBleLss.sessionAltitude = alt;

                                final geoPayload =
                                    NikonBleLss.buildLocationPayload(
                                  latitude: lat,
                                  longitude: lon,
                                  altitudeMeters: alt,
                                );
                                final timePayload =
                                    NikonBleLss.buildCurrentTimePayload();
                                final bleWritten = await CameraNativeBridge
                                    .sendBleLocationPayload(
                                  geoPayload,
                                  timePayload: timePayload,
                                );
                                _addLog('【拍摄经纬度】已设为 ${NikonBleLss.formatCoordinatesDms(lat, lon)} (${alt.round()}m)，41B 0x2007 负载已生成 (bleWritten=$bleWritten)');
                                if (mounted) setState(() {});
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  showZToast(
                                    context,
                                    bleWritten
                                        ? EngineL10n.gpsInjectedSuccessToast(
                                            l10n.localeName)
                                        : '${EngineL10n.gpsSavedSuccessPrefix(l10n.localeName)}: ${NikonBleLss.formatCoordinatesDms(lat, lon)}',
                                    tone: ZStatusTone.success,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

