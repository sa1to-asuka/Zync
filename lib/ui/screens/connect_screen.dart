import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/network_config.dart';
import '../../core/utils/app_log_manager.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/transfer/export_history_manager.dart';
import '../../engine/transfer/shoot_and_transfer.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/nikon_ble_lss.dart';
import '../../protocol/nikon_driver.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import 'gallery_screen.dart';

enum _ConnectionTransport { wifi, usb }

/// 摄影师工作台式主页 (Bento Studio Hub)：
/// - 顶部：智能自动探测相机舱（已连接实时仪表盘+边拍边传开关 / 未连接自动识别 USB/Wi-Fi 直连双按钮+连接指南）
/// - 中部：2×2 Bento 核心功能磁贴（选片快传、水印暗房、拼图工坊、传输中心）
/// - 底部：最近影像直览流（点图即修/即看）
class ConnectScreen extends StatefulWidget {
  final CameraDriver driver;
  final VoidCallback onConnected;
  final void Function({bool exportedTab, bool enterCollagePick})?
      onNavigateToGallery;
  final void Function({
    Uint8List? initialBytes,
    PhotoMetadata? meta,
    bool openFilter,
  })? onOpenWatermark;
  final VoidCallback? onOpenTransferCenter;
  final DownloadManager? downloadManager;
  final ShootAndTransferController? shootAndTransferController;

  const ConnectScreen({
    super.key,
    required this.driver,
    required this.onConnected,
    this.onNavigateToGallery,
    this.onOpenWatermark,
    this.onOpenTransferCenter,
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
  UsbDeviceInfo? _usbConnecting;
  _ConnectionTransport _transport = _ConnectionTransport.wifi;

  bool _isConnecting = false;

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

  Future<void> _handleWifiConnect() async {
    if (_isConnecting) return;
    final l10n = context.l10n;
    if (_wifiInfo.connected && !_looksLikeCameraWifi(_wifiInfo)) {
      final proceed = await showZDialog<bool>(
        context: context,
        builder: (dialogCtx) => ZDialog(
          title: l10n.connectWifiWarnTitle,
          message: l10n.connectWifiWarnBody(_displaySsid(l10n)),
          actions: [
            ZButton(
              label: l10n.commonCancel,
              variant: ZButtonVariant.ghost,
              onTap: () => Navigator.pop(dialogCtx, false),
            ),
            ZButton(
              label: l10n.connectContinueAttempt,
              onTap: () => Navigator.pop(dialogCtx, true),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }
    setState(() => _isConnecting = true);
    var targetIp = NetworkConfig.cameraIp;
    if (_wifiInfo.connected &&
        _wifiInfo.gateway.isNotEmpty &&
        _wifiInfo.gateway != '0.0.0.0') {
      targetIp = _wifiInfo.gateway;
    }
    final targetPort = NetworkConfig.cameraPort;

    _addLog('【步骤1】执行原生网络强绑定 (targetHost=$targetIp)...');
    try {
      if (NetworkConfig.autoBindNetwork) {
        final bindResult =
            await CameraNativeBridge.bindCameraWifi(targetHost: targetIp);
        setState(() => _wifiInfo = bindResult);
        _addLog('网络绑定状态: bound=${bindResult.bound}, SSID=${bindResult.ssid}');
      }

      _addLog('【步骤2】发起 PTP/IP 双通道握手: $targetIp:$targetPort');
      await widget.driver.connect(
        targetIp,
        port: targetPort,
        onLog: (msg) => _addLog(msg),
      );

      _transport = _ConnectionTransport.wifi;
      _addLog(
          '【成功】PTP/IP 握手与 OpenSession 成功！已连入相机: ${widget.driver.cameraModel}');
      if (mounted) setState(() {});
      widget.onConnected();
      await _refreshLensInfo();
    } catch (e) {
      _addLog('连接失败: $e');
      if (mounted) {
        showZToast(
          context,
          context.l10n.connectWifiFailedToast('$e'),
          tone: ZStatusTone.danger,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _handleDisconnect() async {
    await widget.driver.disconnect();
    await CameraNativeBridge.unbindWifi();
    _transport = _ConnectionTransport.wifi;
    _addLog('已断开与相机的连接并释放网络绑定');
    if (mounted) setState(() {});
  }

  bool _looksLikeCameraWifi(WifiNetworkInfo info) {
    final ssid = info.ssid.toUpperCase();
    if (ssid.contains('NIKON')) return true;
    return info.gateway == '192.168.0.1' || info.gateway == '192.168.1.1';
  }

  String _displaySsid(AppLocalizations l10n) {
    final raw = _wifiInfo.ssid.trim();
    if (raw.isEmpty || raw == '<检测中...>') {
      return l10n.connectDetecting;
    }
    return raw;
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

  Future<void> _handleUsbConnect(UsbDeviceInfo device) async {
    if (_usbConnecting != null) return;
    final l10n = context.l10n;
    if (!device.ptpReady) {
      await _showUsbErrorDialog(
        l10n.connectUsbModeSwitchHint(device.name, device.modeLabel),
      );
      return;
    }
    final driver = widget.driver;
    if (driver is! NikonDriver) {
      _addLog('当前驱动不支持 USB 连接');
      return;
    }
    setState(() => _usbConnecting = device);
    try {
      if (!device.hasPermission) {
        final granted =
            await CameraNativeBridge.requestUsbPermission(device.deviceName);
        if (!granted) throw StateError(l10n.connectUsbPermissionDenied);
      }
      await driver.connectUsb(device.deviceName, onLog: _addLog);
      _transport = _ConnectionTransport.usb;
      widget.onConnected();
      await _refreshLensInfo();
    } catch (e) {
      _addLog('USB 连接失败: $e');
      if (mounted) {
        await _showUsbErrorDialog('$e');
      }
    } finally {
      if (mounted) setState(() => _usbConnecting = null);
    }
  }

  Future<void> _showUsbErrorDialog(String reason) {
    final l10n = context.l10n;
    return showZDialog<void>(
      context: context,
      builder: (dialogContext) => ZDialog(
        title: l10n.connectUsbFailedTitle,
        content: SingleChildScrollView(
          child: SelectableText(
            '$reason\n\n'
            '${l10n.connectUsbTroubleHeader}\n'
            '${l10n.connectUsbTroubleStep1}\n'
            '${l10n.connectUsbTroubleStep2}\n'
            '${l10n.connectUsbTroubleStep3}',
            style: context.zt.bodySmall,
          ),
        ),
        actions: [
          ZButton(
            label: l10n.commonGotIt,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
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
        return SafeArea(
          child: Padding(
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
                  title: l10n.hubGuideWifiTitle,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ZSpace.md),
                      child: Text(
                        l10n.hubGuideWifiBody,
                        style: zt.bodySmall.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.md),
                ZSection(
                  title: l10n.hubGuideUsbTitle,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(ZSpace.md),
                      child: Text(
                        l10n.hubGuideUsbBody,
                        style: zt.bodySmall.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ZSpace.lg),
                ZButton(
                  label: l10n.hubGuideClose,
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
    final bento = _buildBentoActionGrid(context);
    final recents = _buildRecentPhotosStrip(context);

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
      body: AdaptiveContent(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= kAdaptiveRailBreakpoint;
            if (isWide) {
              // 宽屏/平板/横屏模式：左侧智能相机座舱，右侧 Bento 磁贴与最近影像流
              return SingleChildScrollView(
                padding: const EdgeInsets.all(ZSpace.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          cockpit,
                          const SizedBox(height: ZSpace.lg),
                          _buildConnectionTipCard(context),
                        ],
                      ),
                    ),
                    const SizedBox(width: ZSpace.xl),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          bento,
                          const SizedBox(height: ZSpace.xl),
                          recents,
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // 竖屏手机模式：单列纵向 Bento 流
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                ZSpace.lg,
                ZSpace.md,
                ZSpace.lg,
                ZSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  cockpit,
                  const SizedBox(height: ZSpace.lg),
                  bento,
                  const SizedBox(height: ZSpace.xl),
                  recents,
                ],
              ),
            );
          },
        ),
      ),
    );
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
      final isUsb = _transport == _ConnectionTransport.usb;
      final modeLabel = isUsb ? l10n.connectModeUsb : l10n.connectModeWifi;
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
              // 模式切换胶囊
              Container(
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: ZRadius.brPill,
                  border: Border.all(color: zc.outline, width: 0.8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: ZRadius.brPill,
                      onTap: () => setState(
                          () => _transport = _ConnectionTransport.wifi),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _transport == _ConnectionTransport.wifi
                              ? zc.accent
                              : ZSwatch.transparent,
                          borderRadius: ZRadius.brPill,
                        ),
                        child: Text(
                          l10n.connectModeWifi,
                          style: zt.caption.copyWith(
                            color: _transport == _ConnectionTransport.wifi
                                ? zc.onAccent
                                : zc.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: ZRadius.brPill,
                      onTap: () => setState(
                          () => _transport = _ConnectionTransport.usb),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _transport == _ConnectionTransport.usb
                              ? zc.accent
                              : ZSwatch.transparent,
                          borderRadius: ZRadius.brPill,
                        ),
                        child: Text(
                          'USB',
                          style: zt.caption.copyWith(
                            color: _transport == _ConnectionTransport.usb
                                ? zc.onAccent
                                : zc.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpace.lg),

          // 探测内容展示
          if (_transport == _ConnectionTransport.usb) ...[
            Container(
              padding: const EdgeInsets.all(ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surfaceHigh,
                borderRadius: ZRadius.brMd,
                border: Border.all(
                  color: hasUsbCamera ? zc.accent.withAlpha(120) : zc.outline,
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.usb_rounded, color: zc.accent, size: 20),
                      const SizedBox(width: ZSpace.sm),
                      Expanded(
                        child: Text(
                          l10n.connectUsbSectionTitle,
                          style: zt.bodySmall.copyWith(
                            color: zc.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ZIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: l10n.connectRedetectWifiTooltip,
                        onTap: _handleUsbRefresh,
                      ),
                    ],
                  ),
                  if (hasUsbCamera) ...[
                    const SizedBox(height: ZSpace.xs),
                    Text(
                      '${detectedUsb.name} (${detectedUsb.modeLabel})',
                      style: zt.caption.copyWith(color: zc.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: ZSpace.xs),
                    Text(
                      l10n.connectUsbPrepSub,
                      style: zt.caption.copyWith(color: zc.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ZSpace.md),
            ZButton(
              label: _usbConnecting != null
                  ? l10n.connectConnectingButton
                  : l10n.connectOneTapUsb,
              icon: Icons.cable_rounded,
              size: ZButtonSize.lg,
              expanded: true,
              loading: _usbConnecting != null,
              onTap: _usbConnecting != null
                  ? null
                  : (hasUsbCamera
                      ? () => _handleUsbConnect(detectedUsb)
                      : _handleUsbRefresh),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surfaceHigh,
                borderRadius: ZRadius.brMd,
                border: Border.all(
                  color: isCameraWifi ? zc.success.withAlpha(100) : zc.outline,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_tethering_rounded,
                    size: 18,
                    color: isCameraWifi ? zc.success : zc.textSecondary,
                  ),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.connectWifiDetectedHeader,
                          style: zt.caption,
                        ),
                        Text(
                          _displaySsid(l10n),
                          style: zt.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCameraWifi ? zc.success : zc.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ZIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: l10n.connectRedetectWifiTooltip,
                    onTap: _refreshWifiStatus,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZSpace.md),
            Row(
              children: [
                Expanded(
                  child: ZButton(
                    label: l10n.connectSelectWifi,
                    icon: Icons.settings_outlined,
                    variant: ZButtonVariant.outlined,
                    onTap: () => CameraNativeBridge.openWifiSettings(),
                  ),
                ),
                const SizedBox(width: ZSpace.md),
                Expanded(
                  child: ZButton(
                    label: _isConnecting
                        ? l10n.connectConnectingButton
                        : l10n.connectQuickConnect,
                    icon: Icons.link_rounded,
                    loading: _isConnecting,
                    onTap: _isConnecting ? null : _handleWifiConnect,
                  ),
                ),
              ],
            ),
          ],
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
    final l10n = context.l10n;
    final zc = context.zc;

    final cards = [
      _BentoCard(
        title: l10n.hubBentoQuickTransferTitle,
        subtitle: l10n.hubBentoQuickTransferSub,
        icon: Icons.photo_library_outlined,
        accentColor: zc.accent,
        badgeText: widget.driver.isConnected ? 'LIVE' : null,
        onTap: () => widget.onNavigateToGallery?.call(),
      ),
      _BentoCard(
        title: l10n.hubBentoWatermarkTitle,
        subtitle: l10n.hubBentoWatermarkSub,
        icon: Icons.branding_watermark_outlined,
        accentColor: ZSwatch.nikonGold,
        onTap: () => widget.onOpenWatermark?.call(),
      ),
      _BentoCard(
        title: l10n.hubBentoCollageTitle,
        subtitle: l10n.hubBentoCollageSub,
        icon: Icons.auto_awesome_mosaic_outlined,
        accentColor: zc.info,
        onTap: () => widget.onNavigateToGallery?.call(enterCollagePick: true),
      ),
      AnimatedBuilder(
        animation: widget.downloadManager ?? Listenable.merge([]),
        builder: (ctx, _) {
          final dm = widget.downloadManager;
          final pending = dm?.pendingCount ?? 0;
          final active = pending > 0;
          return _BentoCard(
            title: l10n.hubBentoTransfersTitle,
            subtitle: active
                ? l10n.hubBentoTransfersActive(pending)
                : l10n.hubBentoTransfersIdle,
            icon: Icons.swap_vert_circle_outlined,
            accentColor: active ? zc.danger : zc.textSecondary,
            progress: active ? dm?.currentTask?.progress : null,
            badgeText: active ? '$pending' : null,
            onTap: () => widget.onOpenTransferCenter?.call(),
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: ZSpace.md,
          mainAxisSpacing: ZSpace.md,
          childAspectRatio: 1.45,
          children: cards,
        );
      },
    );
  }

  // ==========================================
  // 3. 底部最近影像直览流 (最近已导出 / 快速送修)
  // ==========================================
  Widget _buildRecentPhotosStrip(BuildContext context) {
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
            height: 104,
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
                    width: 104,
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

  Widget _buildConnectionTipCard(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    return ZCard(
      padding: const EdgeInsets.all(ZSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: zc.accent),
              const SizedBox(width: ZSpace.sm),
              Text(l10n.hubGuideTitle, style: zt.labelLarge),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          Text(
            l10n.connectWifiJoinHint,
            style: zt.caption.copyWith(color: zc.textSecondary, height: 1.4),
          ),
        ],
      ),
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

class _BentoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final double? progress;
  final String? badgeText;
  final VoidCallback onTap;

  const _BentoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.progress,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return ZCard(
      elevated: true,
      onTap: onTap,
      padding: const EdgeInsets.all(ZSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(35),
                  borderRadius: ZRadius.brSm,
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: ZRadius.brPill,
                  ),
                  child: Text(
                    badgeText!,
                    style: TextStyle(
                      color: zc.onAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: zt.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: zt.caption.copyWith(color: zc.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (progress != null) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: ZRadius.brPill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    backgroundColor: zc.outline,
                    valueColor: AlwaysStoppedAnimation(accentColor),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
