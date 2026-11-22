import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/utils/app_log_manager.dart';
import '../../../core/utils/ip_address.dart';
import '../../../l10n/l10n.dart';
import '../../../protocol/camera_driver.dart';
import '../../../protocol/camera_native_bridge.dart';
import '../../../protocol/nikon_driver.dart';
import '../../../protocol/nikon_sta_pairing.dart';
import '../../../protocol/ptp_ip_client.dart';
import '../../design/design.dart';
import '../../widgets/adaptive_layout.dart';
import '../usb_diagnostics.dart';
import 'ip_octet_field.dart';

/// 三种连接方式：相机热点 / 局域网 STA / USB。
enum LinkMethod { hotspot, lan, usb }

/// 局域网 STA 的两种拓扑子模式：同一路由器 Wi-Fi / 手机个人热点。
enum StaSubMode { router, hotspot }

enum _LanPhase { idle, connecting, failed }

/// 独立连接页。
///
/// 相机热点与 USB 沿用原有逻辑；局域网模式对应尼康「连接到计算机」的 STA，
/// 相机加入热点/路由器后直接用 IP 走 PTP/IP，不需要配对码。
class LinkCameraScreen extends StatefulWidget {
  const LinkCameraScreen({
    super.key,
    required this.driver,
    required this.onConnected,
    this.onDisconnect,
  });

  final CameraDriver driver;
  final VoidCallback onConnected;

  /// 用户主动断开时通知外层，用于取消正在进行的自动重连。
  final VoidCallback? onDisconnect;

  @override
  State<LinkCameraScreen> createState() => _LinkCameraScreenState();
}

class _LinkCameraScreenState extends State<LinkCameraScreen>
    with WidgetsBindingObserver {
  LinkMethod _method = LinkMethod.hotspot;

  WifiNetworkInfo _wifiInfo = WifiNetworkInfo(
    connected: false,
    bound: false,
    ssid: '',
    gateway: '192.168.0.1',
    ip: '192.168.0.2',
  );

  List<UsbDeviceInfo> _usbDevices = const <UsbDeviceInfo>[];
  bool _isUsbScanning = false;
  UsbDeviceInfo? _usbConnecting;

  bool _isHotspotConnecting = false;
  bool _isLanConnecting = false;
  bool _isScanningLan = false;
  bool _hasScannedLan = false;
  bool _isDisconnecting = false;
  List<DiscoveredPtpCamera> _discovered = const <DiscoveredPtpCamera>[];

  _LanPhase _lanPhase = _LanPhase.idle;
  String? _lanError;
  String? _lanScanDiagMessage;
  StaSubMode _staSubMode = StaSubMode.router;
  bool _showGuidAdvanced = false;

  final GlobalKey<IpOctetFieldState> _ipFieldKey =
      GlobalKey<IpOctetFieldState>();
  String _lanIp = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = AppSettings.instance;
    _method = _methodFromSetting(settings.lastLinkMethod);
    _staSubMode = settings.staSubMode == 'hotspot'
        ? StaSubMode.hotspot
        : StaSubMode.router;
    _lanIp =
        normalizeIpv4(settings.staHostForSubMode(_staSubMode.name)) ?? '';
    _refreshWifiStatus();
    _refreshUsbDevices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshWifiStatus();
      _refreshUsbDevices();
    }
  }

  static LinkMethod _methodFromSetting(String value) => switch (value) {
        'lan' => LinkMethod.lan,
        'usb' => LinkMethod.usb,
        _ => LinkMethod.hotspot,
      };

  String get _lang => L10n.current.localeName;

  void _addLog(String message) {
    AppLogManager.instance.add(message);
  }

  Future<void> _refreshWifiStatus() async {
    final info = await CameraNativeBridge.getWifiInfo();
    if (mounted) setState(() => _wifiInfo = info);
  }

  Future<void> _refreshUsbDevices() async {
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
      _addLog('[usb] scan failed: $e');
    } finally {
      if (mounted) setState(() => _isUsbScanning = false);
    }
  }

  // ==========================================
  // 相机热点
  // ==========================================

  bool _looksLikeCameraWifi(WifiNetworkInfo info) {
    final ssid = info.ssid.toUpperCase();
    if (ssid.contains('NIKON')) return true;
    return info.gateway == '192.168.0.1' || info.gateway == '192.168.1.1';
  }

  String _displaySsid() {
    final raw = _wifiInfo.ssid.trim();
    if (raw.isEmpty || raw.startsWith('<')) {
      return context.l10n.connectDetecting;
    }
    return raw;
  }

  Future<void> _connectHotspot() async {
    if (_isHotspotConnecting || widget.driver.isConnected) return;
    final lang = _lang;

    if (_wifiInfo.connected && !_looksLikeCameraWifi(_wifiInfo)) {
      final proceed = await showZDialog<bool>(
        context: context,
        builder: (dialogContext) => ZDialog(
          title: EngineL10n.linkHotspotWarnTitle(lang),
          message: EngineL10n.linkHotspotWarnBody(_displaySsid(), lang),
          actions: [
            ZButton(
              label: context.l10n.commonCancel,
              variant: ZButtonVariant.ghost,
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            ZButton(
              label: EngineL10n.linkContinueAttempt(lang),
              onTap: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isHotspotConnecting = true);
    var targetIp = AppSettings.instance.cameraIp;
    if (_wifiInfo.connected &&
        _wifiInfo.gateway.isNotEmpty &&
        _wifiInfo.gateway != '0.0.0.0') {
      targetIp = _wifiInfo.gateway;
    }
    final targetPort = AppSettings.instance.cameraPort;

    try {
      await CameraNativeBridge.bindCameraWifi(targetHost: targetIp);
      await widget.driver.connect(
        targetIp,
        port: targetPort,
        onLog: _addLog,
      );
      AppSettings.instance.setLastLinkMethod('hotspot');
      widget.onConnected();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _addLog('[hotspot] connect failed: $e');
      if (mounted) {
        showZToast(
          context,
          context.l10n.connectWifiFailedToast('$e'),
          tone: ZStatusTone.danger,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) setState(() => _isHotspotConnecting = false);
    }
  }

  // ==========================================
  // 局域网 / STA
  // ==========================================

  String get _staRouteMode =>
      _staSubMode == StaSubMode.hotspot ? 'sta_hotspot' : 'sta_router';

  void _onStaSubModeChanged(StaSubMode mode) {
    if (_staSubMode == mode) return;
    final settings = AppSettings.instance;
    settings.setStaSubMode(mode.name);
    final savedIp = normalizeIpv4(settings.staHostForSubMode(mode.name)) ?? '';
    setState(() {
      _staSubMode = mode;
      _lanIp = savedIp;
      _lanError = null;
      _lanScanDiagMessage = null;
    });
    _ipFieldKey.currentState?.setIp(savedIp);
  }

  Future<void> _scanLan() async {
    if (_isScanningLan) return;
    setState(() {
      _isScanningLan = true;
      _hasScannedLan = true;
      _lanScanDiagMessage = null;
    });

    final settings = AppSettings.instance;
    final currentTyped = normalizeIpv4(_lanIp);
    final preferred = <String>[
      if (currentTyped != null && currentTyped.isNotEmpty) currentTyped,
      if (settings.staRouterHost.isNotEmpty) settings.staRouterHost,
      if (settings.staHotspotHost.isNotEmpty) settings.staHotspotHost,
      if (settings.staLanHost.isNotEmpty) settings.staLanHost,
    ];

    // Bonjour (_ptp._tcp 串行解析) 与原生多子网 15740 扫描并行：
    // 手机热点或开启 AP 隔离的路由器可能挡住多播，原生多子网扫描按网卡类型绑定路由兜底。
    final results = await Future.wait<dynamic>([
      CameraNativeBridge.discoverPtpCameras(),
      CameraNativeBridge.scanLanPtpHosts(
        preferredHosts: preferred,
        staSubMode: _staSubMode.name,
      ),
    ]);
    final mdns = results[0] as List<DiscoveredPtpCamera>;
    final scanRes = results[1] as LanScanResult;

    final merged = <String, DiscoveredPtpCamera>{};
    for (final camera in mdns) {
      merged[camera.host] = camera;
    }
    for (final host in scanRes.hosts) {
      if (merged.containsKey(host)) continue;
      // 仅对未出现在 Bonjour 中的扫描命中主机做一次轻量 Init_Command 机型探测
      final probedName = await probePtpCameraName(
        host,
        port: 15740,
        timeout: const Duration(milliseconds: 550),
        postConnectSettle: const Duration(milliseconds: 80),
        clientGuid: settings.ptpClientGuidBytes,
      );
      merged[host] = DiscoveredPtpCamera(
        name: (probedName != null && probedName.isNotEmpty)
            ? NikonDeviceInfo.normalizeModelName(probedName)
            : EngineL10n.linkLanPtpCamera(_lang),
        host: host,
        port: 15740,
        source: 'scan',
      );
    }
    final found = merged.values.toList()
      ..sort((a, b) => a.host.compareTo(b.host));

    String? diagMsg;
    if (found.isEmpty) {
      final reason = diagnoseStaScanMiss(
        staSubMode: _staSubMode.name,
        wifiConnected: scanRes.wifiConnected || _wifiInfo.connected,
        wifiSsid:
            scanRes.wifiSsid.isNotEmpty ? scanRes.wifiSsid : _wifiInfo.ssid,
        wifiGateway: scanRes.wifiGateway.isNotEmpty
            ? scanRes.wifiGateway
            : _wifiInfo.gateway,
        scannedSubnets: scanRes.scannedSubnets,
        hasHotspotInterface: scanRes.hasHotspotInterface,
        respondingPeerCount: scanRes.respondingPeerCount,
      );
      diagMsg = switch (reason) {
        StaScanMissReason.onCameraAccessPoint =>
          EngineL10n.linkStaDiagOnCameraAp(_lang),
        StaScanMissReason.noLocalNetwork =>
          EngineL10n.linkStaDiagNoNetwork(_staSubMode.name, _lang),
        StaScanMissReason.silentOrIsolatedNetwork =>
          EngineL10n.linkStaDiagSilentNetwork(_lang),
        StaScanMissReason.hostsVisibleNoPtp =>
          EngineL10n.linkStaDiagHostsNoPtp(_lang),
        StaScanMissReason.cameraNotFound =>
          EngineL10n.linkLanScanFailed(_lang),
      };
    }

    if (!mounted) return;
    setState(() {
      _discovered = found;
      _isScanningLan = false;
      _lanScanDiagMessage = diagMsg;
      if (found.length == 1 && (normalizeIpv4(_lanIp) == null)) {
        _lanIp = found.first.host;
        _ipFieldKey.currentState?.setIp(found.first.host);
      }
    });
    if (found.isEmpty && diagMsg != null) {
      showZToast(
        context,
        diagMsg,
        tone: ZStatusTone.warning,
      );
    }
  }

  Future<void> _connectLan() async {
    if (_isLanConnecting) return;
    final lang = _lang;
    final host = normalizeIpv4(_lanIp);
    if (host == null) {
      showZToast(
        context,
        EngineL10n.linkInvalidIp(lang),
        tone: ZStatusTone.danger,
      );
      return;
    }
    const port = 15740;
    final routeMode = _staRouteMode;

    // 相机停在「地址/掩码」画面时，必须先在机身上按 OK 才会进入配对/等待连接。
    // 一按 OK，IP 就从屏幕消失，所以每次建立连接前都先让用户确认这一步。
    final okPressed = await showZDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final zt = dialogContext.zt;
        return ZDialog(
          title: EngineL10n.linkStaPressOkTitle(lang),
          content: Text(
            EngineL10n.linkStaPressOkBody(host, lang),
            style: zt.bodySmall.copyWith(height: 1.5),
          ),
          actions: [
            ZButton(
              label: context.l10n.commonCancel,
              variant: ZButtonVariant.ghost,
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            ZButton(
              label: EngineL10n.linkStaPressOkContinue(lang),
              icon: Icons.check_circle_outline_rounded,
              onTap: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );
    if (okPressed != true || !mounted) return;

    final driver = widget.driver;
    setState(() {
      _isLanConnecting = true;
      _lanPhase = _LanPhase.connecting;
      _lanError = null;
    });
    if (driver is NikonDriver) driver.setRecoverySuppressed(true);

    try {
      await CameraNativeBridge.bindCameraWifi(
        targetHost: host,
        mode: routeMode,
      );
      if (driver is NikonDriver) {
        await driver.connect(
          host,
          port: port,
          onLog: _addLog,
          routeMode: routeMode,
        );
      } else {
        await driver.connect(host, port: port, onLog: _addLog);
      }

      // 检测是否处于 STA 首次无线配对的受限能力态（仅开放 0x952B / 0x935A）
      if (driver is NikonDriver && driver.isRestrictedPairingSession) {
        final pairedAndConnected =
            await _runStaPairingFlow(driver, host, port, routeMode);
        if (!pairedAndConnected) {
          return;
        }
      }

      _rememberLanTarget(host, port);
      widget.onConnected();
      if (mounted) Navigator.of(context).pop();
    } on PtpInitFailException catch (e) {
      _addLog('[lan] init fail (${e.reason}): $e');
      if (!mounted) return;
      if (e.reason == PtpInitFailReason.rejectedInitiator) {
        final guidPrefix =
            AppSettings.instance.ptpClientGuidHex.substring(0, 8).toUpperCase();
        final msg = EngineL10n.linkStaInitFailRejectedBody(guidPrefix, lang);
        setState(() {
          _lanPhase = _LanPhase.failed;
          _lanError = EngineL10n.linkStaInitFailRejectedTitle(lang);
          _showGuidAdvanced = true;
        });
        await _showInitFailRejectedDialog(guidPrefix);
        _addLog(msg);
      } else if (e.reason == PtpInitFailReason.busy) {
        final msg = EngineL10n.linkStaInitFailBusyMessage(lang);
        setState(() {
          _lanPhase = _LanPhase.failed;
          _lanError = msg;
        });
        showZToast(
          context,
          msg,
          tone: ZStatusTone.danger,
          duration: const Duration(seconds: 5),
        );
      } else {
        final msg = _friendlyLanError(e);
        setState(() {
          _lanPhase = _LanPhase.failed;
          _lanError = msg;
        });
        showZToast(
          context,
          msg,
          tone: ZStatusTone.danger,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      _addLog('[lan] connect failed: $e');
      final refused = '$e'.contains('Connection refused');
      final message = _friendlyLanError(e);
      if (!mounted) return;
      setState(() {
        _lanPhase = _LanPhase.failed;
        _lanError = message;
      });
      if (refused) {
        await _showPortClosedDialog(host);
      } else {
        showZToast(
          context,
          message,
          tone: ZStatusTone.danger,
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (driver is NikonDriver) driver.setRecoverySuppressed(false);
      if (mounted) setState(() => _isLanConnecting = false);
    }
  }

  /// 执行 STA 首次无线配对交互：
  /// 1. 轮询 `0x952B` 获取 4 位配对码；
  /// 2. 弹窗请用户与相机屏幕比对并点击「验证码一致，确认配对」；
  /// 3. 发送 `0x935A(0x2001)`；
  /// 4. 引导用户在相机屏幕按 OK 保存配置文件，随后关闭临时会话并冷却重连。
  Future<bool> _runStaPairingFlow(
    NikonDriver driver,
    String host,
    int port,
    String routeMode,
  ) async {
    final lang = _lang;
    _addLog('[lan-pair] STA pairing required, reading 0x952B challenge');
    if (mounted) {
      showZToast(
        context,
        EngineL10n.linkStaPairingFetching(lang),
        tone: ZStatusTone.accent,
        duration: const Duration(seconds: 2),
      );
    }

    NikonPairingChallenge challenge;
    try {
      challenge = await driver.requestStaPairingChallenge();
    } catch (e) {
      _addLog('[lan-pair] 0x952B failed: $e');
      await driver.disconnect();
      rethrow;
    }

    if (!mounted) {
      await driver.disconnect();
      return false;
    }

    final cameraTitle = driver.cameraModel.trim().isNotEmpty
        ? driver.cameraModel
        : host;

    final confirmed = await showZDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final zc = dialogContext.zc;
        final zt = dialogContext.zt;
        return ZDialog(
          title: EngineL10n.linkStaPairingDialogTitle(lang),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                EngineL10n.linkStaPairingDialogSubtitle(cameraTitle, lang),
                style: zt.bodySmall.copyWith(height: 1.45),
              ),
              const SizedBox(height: ZSpace.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: ZSpace.lg,
                  horizontal: ZSpace.md,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: zc.surfaceHigh,
                  borderRadius: ZRadius.brMd,
                  border: Border.all(color: zc.accent, width: 1.2),
                ),
                child: Text(
                  challenge.hasPin ? challenge.pin! : '----',
                  style: zt.display.copyWith(
                    fontSize: 34,
                    letterSpacing: 8,
                    color: zc.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!challenge.hasPin && challenge.rawBytes.isNotEmpty) ...[
                const SizedBox(height: ZSpace.sm),
                Text(
                  '${EngineL10n.linkStaPairingPinFallbackLabel(lang)}: ${challenge.rawHex}',
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
              ],
            ],
          ),
          actions: [
            ZButton(
              label: context.l10n.commonCancel,
              variant: ZButtonVariant.ghost,
              onTap: () => Navigator.pop(dialogContext, false),
            ),
            ZButton(
              label: EngineL10n.linkStaPairingConfirmBtn(lang),
              icon: Icons.verified_outlined,
              onTap: () => Navigator.pop(dialogContext, true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      _addLog('[lan-pair] user cancelled STA pairing confirm');
      await driver.disconnect();
      if (mounted) {
        setState(() => _lanPhase = _LanPhase.idle);
      }
      return false;
    }

    try {
      await driver.confirmStaPairing();
    } catch (e) {
      _addLog('[lan-pair] 0x935A submit failed: $e');
      await driver.disconnect();
      rethrow;
    }

    // 主动优雅关闭临时配对会话，让相机完成向导保存并释放单会话槽位
    await driver.disconnect();

    if (!mounted) return false;
    return _waitForPairedReconnect(driver, host, port, routeMode);
  }

  /// 配对确认提交后，相机还需要用户在机身上按 OK 保存配置。
  /// 首轮重连往往正好撞上保存过程（会话槽位未释放），所以这里自动多轮重试，
  /// 而不是让用户手动点一次「重连」再赌第二次能成功。
  Future<bool> _waitForPairedReconnect(
    NikonDriver driver,
    String host,
    int port,
    String routeMode,
  ) async {
    final lang = _lang;
    final attempt = ValueNotifier<int>(0);
    final cancelled = ValueNotifier<bool>(false);
    BuildContext? dialogContextRef;

    final dialogFuture = showZDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        dialogContextRef = dialogContext;
        final zc = dialogContext.zc;
        final zt = dialogContext.zt;
        return ValueListenableBuilder<int>(
          valueListenable: attempt,
          builder: (_, attemptNo, __) => ZDialog(
            title: EngineL10n.linkStaWaitingTitle(lang),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  EngineL10n.linkStaWaitingBody(lang),
                  style: zt.bodySmall.copyWith(height: 1.45),
                ),
                const SizedBox(height: ZSpace.md),
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: zc.accent,
                      ),
                    ),
                    const SizedBox(width: ZSpace.sm),
                    Expanded(
                      child: Text(
                        attemptNo == 0
                            ? EngineL10n.linkStaWaitingFirst(lang)
                            : EngineL10n.linkStaWaitingAttempt(attemptNo, lang),
                        style: zt.caption.copyWith(color: zc.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              ZButton(
                label: context.l10n.commonCancel,
                variant: ZButtonVariant.ghost,
                onTap: () {
                  cancelled.value = true;
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );

    var connected = false;
    const maxAttempts = 10;
    for (var i = 1; i <= maxAttempts; i++) {
      // 第一轮多等一会：相机要先用 OK 确认保存，再释放旧会话。
      await Future<void>.delayed(
        i == 1
            ? const Duration(milliseconds: 2200)
            : const Duration(milliseconds: 1600),
      );
      if (cancelled.value || !mounted) break;
      attempt.value = i;
      try {
        await CameraNativeBridge.bindCameraWifi(
          targetHost: host,
          mode: routeMode,
        );
        await driver.connect(
          host,
          port: port,
          onLog: _addLog,
          routeMode: routeMode,
        );
        if (cancelled.value) {
          await driver.disconnect();
          break;
        }
        if (!driver.isConnected) continue;
        if (!driver.isRestrictedPairingSession) {
          connected = true;
          break;
        }
        _addLog('[lan-pair] camera still pairing, retry $i');
        await driver.disconnect();
      } catch (e) {
        _addLog('[lan-pair] reconnect attempt $i failed: $e');
        try {
          await driver.disconnect();
        } catch (_) {}
      }
    }

    if (dialogContextRef != null && dialogContextRef!.mounted) {
      Navigator.of(dialogContextRef!).pop();
    }
    await dialogFuture;
    if (!mounted) return false;

    if (!connected) {
      final message = EngineL10n.linkStaWaitingTimeout(lang);
      setState(() {
        _lanPhase = _LanPhase.failed;
        _lanError = message;
      });
      showZToast(
        context,
        message,
        tone: ZStatusTone.danger,
        duration: const Duration(seconds: 6),
      );
      return false;
    }

    _addLog('[lan-pair] paired, reconnected with persisted GUID');
    return true;
  }

  Future<void> _showInitFailRejectedDialog(String guidPrefix) async {
    final openImport = await showZDialog<bool>(
      context: context,
      builder: (dialogContext) => ZDialog(
        title: EngineL10n.linkStaInitFailRejectedTitle(_lang),
        message: EngineL10n.linkStaInitFailRejectedBody(guidPrefix, _lang),
        actions: [
          ZButton(
            label: context.l10n.commonGotIt,
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(dialogContext, false),
          ),
          ZButton(
            label: EngineL10n.linkStaGuidImportBtn(_lang),
            icon: Icons.key_outlined,
            onTap: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (openImport == true && mounted) {
      await _showImportGuidDialog();
    }
  }

  Future<void> _copyCurrentGuid() async {
    final hex = AppSettings.instance.ptpClientGuidHex;
    await Clipboard.setData(ClipboardData(text: hex));
    if (!mounted) return;
    showZToast(
      context,
      EngineL10n.linkStaGuidCopiedToast(_lang),
      tone: ZStatusTone.success,
    );
  }

  Future<void> _showImportGuidDialog() async {
    final updated = await showZDialog<bool>(
      context: context,
      builder: (_) => _ImportGuidDialog(
        lang: _lang,
        cancelLabel: context.l10n.commonCancel,
        initialGuid: AppSettings.instance.ptpClientGuidHex,
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
      showZToast(
        context,
        EngineL10n.linkStaGuidImportSuccess(_lang),
        tone: ZStatusTone.success,
      );
    }
  }

  Future<void> _showPortClosedDialog(String host) async {
    final switchToHotspot = await showZDialog<bool>(
      context: context,
      builder: (dialogContext) => ZDialog(
        title: EngineL10n.linkPortClosedTitle(_lang),
        message: EngineL10n.linkPortClosedBody(host, _lang),
        actions: [
          ZButton(
            label: EngineL10n.linkStayLan(_lang),
            variant: ZButtonVariant.ghost,
            onTap: () => Navigator.pop(dialogContext, false),
          ),
          ZButton(
            label: EngineL10n.linkSwitchHotspot(_lang),
            onTap: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (switchToHotspot == true && mounted) {
      setState(() {
        _method = LinkMethod.hotspot;
        _lanPhase = _LanPhase.idle;
        _lanError = null;
      });
    }
  }

  String _friendlyLanError(Object error) {
    final text = '$error';
    if (text.contains('Connection refused')) {
      return EngineL10n.linkConnectRefused(_lang);
    }
    if (text.contains('Timeout') || text.contains('timed out')) {
      return EngineL10n.linkConnectTimeout(_lang);
    }
    return EngineL10n.linkConnectFailed(text, _lang);
  }

  void _rememberLanTarget(String host, int port) {
    final settings = AppSettings.instance;
    settings.setStaHostForSubMode(_staSubMode.name, host);
    settings.setStaLanPort(port);
    settings.setLastLinkMethod('lan');
  }

  // ==========================================
  // USB
  // ==========================================

  UsbDeviceInfo? get _detectedUsb {
    if (_usbDevices.isEmpty) return null;
    return _usbDevices.firstWhere(
      (device) => device.ptpReady,
      orElse: () => _usbDevices.first,
    );
  }

  Future<void> _connectUsb(UsbDeviceInfo device) async {
    if (_usbConnecting != null) return;
    final l10n = context.l10n;
    if (!device.ptpReady) {
      await _showUsbErrorDialog(
        EngineL10n.linkUsbModeSwitchHint(
          device.name,
          device.modeLabel,
          _lang,
        ),
      );
      return;
    }
    final driver = widget.driver;
    if (driver is! NikonDriver) return;

    setState(() => _usbConnecting = device);
    try {
      if (!device.hasPermission) {
        final granted =
            await CameraNativeBridge.requestUsbPermission(device.deviceName);
        if (!granted) throw StateError(EngineL10n.linkUsbPermissionDenied(_lang));
      }
      await driver.connectUsb(device.deviceName, onLog: _addLog);
      AppSettings.instance.setLastLinkMethod('usb');
      widget.onConnected();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _addLog('[usb] connect failed: $e');
      if (mounted) {
        await _showUsbErrorDialog(
          '$e\n\n${l10n.connectUsbTroubleHeader}\n'
          '${l10n.connectUsbTroubleStep1}\n'
          '${l10n.connectUsbTroubleStep2}\n'
          '${l10n.connectUsbTroubleStep3}',
        );
      }
    } finally {
      if (mounted) setState(() => _usbConnecting = null);
    }
  }

  Future<void> _showUsbErrorDialog(String reason) {
    return showZDialog<void>(
      context: context,
      builder: (dialogContext) => ZDialog(
        title: context.l10n.connectUsbFailedTitle,
        content: SingleChildScrollView(
          child: SelectableText(reason, style: context.zt.bodySmall),
        ),
        actions: [
          ZButton(
            label: context.l10n.commonGotIt,
            onTap: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnect() async {
    if (_isDisconnecting) return;
    widget.onDisconnect?.call();
    setState(() => _isDisconnecting = true);
    try {
      await widget.driver.disconnect();
      await CameraNativeBridge.unbindWifi();
      if (mounted) setState(() => _lanPhase = _LanPhase.idle);
    } finally {
      if (mounted) setState(() => _isDisconnecting = false);
    }
  }

  // ==========================================
  // Build
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final wideShell = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        // 宽屏的标题由渐变横幅承担，避免顶部重复出现两次「连接相机」。
        title: wideShell ? null : Text(EngineL10n.linkPageTitle(_lang)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            // 平板横屏：左侧选方式和面板，右侧整块教程，避免窄条居中。
            final isWide = viewport.maxWidth >= 900;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isWide ? ZSpace.xxl : ZSpace.lg,
                isWide ? ZSpace.xl : ZSpace.md,
                isWide ? ZSpace.xxl : ZSpace.lg,
                ZSpace.xxl,
              ),
              child: AdaptiveContent(
                maxWidth: isWide ? 1120 : 760,
                child: isWide
                    ? _buildWideBody(context)
                    : _buildCompactBody(context),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHero(context),
        const SizedBox(height: ZSpace.xl),
        if (widget.driver.isConnected) ...[
          _buildConnectedBanner(context),
          const SizedBox(height: ZSpace.lg),
        ],
        _buildSegmented(),
        const SizedBox(height: ZSpace.lg),
        _buildPanel(),
        const SizedBox(height: ZSpace.xxl),
        _buildTutorial(context),
        const SizedBox(height: ZSpace.lg),
        _buildTips(context),
      ],
    );
  }

  Widget _buildWideBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWideHero(context),
        const SizedBox(height: ZSpace.xl),
        if (widget.driver.isConnected) ...[
          _buildConnectedBanner(context),
          const SizedBox(height: ZSpace.lg),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSegmented(),
                  const SizedBox(height: ZSpace.lg),
                  _buildPanel(),
                  const SizedBox(height: ZSpace.lg),
                  _buildTips(context),
                ],
              ),
            ),
            const SizedBox(width: ZSpace.xxl),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTutorial(context),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmented() {
    return ZSegmented<LinkMethod>(
      segments: [
        ZSegment(
          value: LinkMethod.hotspot,
          label: EngineL10n.linkModeHotspot(_lang),
          icon: Icons.wifi_tethering_rounded,
        ),
        ZSegment(
          value: LinkMethod.lan,
          label: EngineL10n.linkModeLan(_lang),
          icon: Icons.router_outlined,
        ),
        ZSegment(
          value: LinkMethod.usb,
          label: EngineL10n.linkModeUsb(_lang),
          icon: Icons.usb_rounded,
        ),
      ],
      selected: _method,
      onChanged: (value) => setState(() => _method = value),
    );
  }

  Widget _buildPanel() {
    return AnimatedSwitcher(
      duration: ZMotion.of(context, ZMotion.medium),
      switchInCurve: ZMotion.emphasizedDecelerate,
      switchOutCurve: ZMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<LinkMethod>(_method),
        child: switch (_method) {
          LinkMethod.hotspot => _buildHotspotPanel(context),
          LinkMethod.lan => _buildLanPanel(context),
          LinkMethod.usb => _buildUsbPanel(context),
        },
      ),
    );
  }

  /// 平板横向页头：与主页相机横幅同一套渐变语言。
  Widget _buildWideHero(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Container(
      padding: const EdgeInsets.all(ZSpace.xl),
      decoration: BoxDecoration(
        color: zc.surface,
        borderRadius: ZRadius.brXl,
        border: Border.all(color: zc.accent.withAlpha(70), width: 0.8),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: zc.accent.withAlpha(16),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(8),
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
                    size: 26,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: ZSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EngineL10n.linkPageTitle(_lang),
                  style: zt.display,
                ),
                const SizedBox(height: ZSpace.xs),
                Text(
                  EngineL10n.linkPageSubtitle(_lang),
                  style: zt.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: zc.accent.withAlpha(16),
              ),
            ),
            Container(
              width: 62,
              height: 62,
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
                  size: 30,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZSpace.md),
        Text(
          EngineL10n.linkPageTitle(_lang),
          style: zt.display,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: ZSpace.xs),
        Text(
          EngineL10n.linkPageSubtitle(_lang),
          style: zt.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildConnectedBanner(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final isUsb =
        widget.driver.transportKind == CameraTransportKind.usb;
    return ZCard(
      selected: true,
      padding: const EdgeInsets.all(ZSpace.md),
      child: Row(
        children: [
          Icon(
            isUsb ? Icons.usb_rounded : Icons.wifi_rounded,
            color: zc.accent,
            size: 20,
          ),
          const SizedBox(width: ZSpace.sm),
          Expanded(
            child: Text(
              widget.driver.cameraModel,
              style: zt.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ZTag(
            text: EngineL10n.linkConnectedBadge(_lang),
            color: zc.success,
          ),
          const SizedBox(width: ZSpace.sm),
          ZButton(
            label: EngineL10n.linkDisconnect(_lang),
            variant: ZButtonVariant.ghost,
            size: ZButtonSize.sm,
            loading: _isDisconnecting,
            onTap: _isDisconnecting ? null : _disconnect,
          ),
        ],
      ),
    );
  }

  // ---- 相机热点面板 ----

  Widget _buildHotspotPanel(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final isCameraWifi =
        _wifiInfo.connected && _looksLikeCameraWifi(_wifiInfo);
    final busy = _isHotspotConnecting || widget.driver.isConnected;

    return ZCard(
      padding: const EdgeInsets.all(ZSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconTile(
                context,
                Icons.wifi_tethering_rounded,
                isCameraWifi ? zc.success : zc.textSecondary,
              ),
              const SizedBox(width: ZSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      EngineL10n.linkHotspotCurrentWifi(_lang),
                      style: zt.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displaySsid(),
                      style: zt.label.copyWith(
                        color: isCameraWifi ? zc.success : zc.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ZIconButton(
                icon: Icons.refresh_rounded,
                tooltip: context.l10n.connectRedetectWifiTooltip,
                onTap: _refreshWifiStatus,
              ),
            ],
          ),
          const SizedBox(height: ZSpace.sm),
          Text(
            isCameraWifi
                ? EngineL10n.linkHotspotDetected(_lang)
                : EngineL10n.linkHotspotNotCamera(_lang),
            style: zt.caption.copyWith(
              color: isCameraWifi ? zc.success : zc.warning,
            ),
          ),
          const SizedBox(height: ZSpace.lg),
          ZButton(
            label: _isHotspotConnecting
                ? EngineL10n.linkConnecting(_lang)
                : EngineL10n.linkHotspotConnect(_lang),
            icon: Icons.link_rounded,
            size: ZButtonSize.lg,
            expanded: true,
            loading: _isHotspotConnecting,
            onTap: busy ? null : _connectHotspot,
          ),
          const SizedBox(height: ZSpace.sm),
          ZButton(
            label: EngineL10n.linkHotspotOpenSettings(_lang),
            icon: Icons.settings_outlined,
            variant: ZButtonVariant.ghost,
            expanded: true,
            onTap: () => CameraNativeBridge.openWifiSettings(),
          ),
        ],
      ),
    );
  }

  // ---- 局域网面板 ----

  Widget _buildLanPanel(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final busy = _isLanConnecting;
    final guidHex = AppSettings.instance.ptpClientGuidHex.toUpperCase();
    final guidPreview = guidHex.length >= 12
        ? '${guidHex.substring(0, 8)}…${guidHex.substring(guidHex.length - 4)}'
        : guidHex;

    return ZCard(
      padding: const EdgeInsets.all(ZSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconTile(
                context,
                _staSubMode == StaSubMode.hotspot
                    ? Icons.cell_tower_rounded
                    : Icons.router_outlined,
                zc.accent,
              ),
              const SizedBox(width: ZSpace.md),
              Expanded(
                child: Text(
                  EngineL10n.linkLanIpLabel(_lang),
                  style: zt.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpace.md),
          ZSegmented<StaSubMode>(
            segments: [
              ZSegment(
                value: StaSubMode.router,
                label: EngineL10n.linkStaSubModeRouter(_lang),
                icon: Icons.router_outlined,
              ),
              ZSegment(
                value: StaSubMode.hotspot,
                label: EngineL10n.linkStaSubModeHotspot(_lang),
                icon: Icons.wifi_tethering_rounded,
              ),
            ],
            selected: _staSubMode,
            onChanged: _onStaSubModeChanged,
          ),
          const SizedBox(height: ZSpace.md),
          IpOctetField(
            key: _ipFieldKey,
            initialIp: _lanIp,
            onChanged: (value) => _lanIp = value,
          ),
          const SizedBox(height: ZSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: ZButton(
              label: _isScanningLan
                  ? EngineL10n.linkLanScanning(_lang)
                  : EngineL10n.linkLanScan(_lang),
              icon: Icons.search_rounded,
              variant: ZButtonVariant.tonal,
              size: ZButtonSize.sm,
              loading: _isScanningLan,
              onTap: _isScanningLan || _isLanConnecting ? null : _scanLan,
            ),
          ),
          const SizedBox(height: ZSpace.xs),
          Text(
            _staSubMode == StaSubMode.hotspot
                ? EngineL10n.linkStaHotspotHint(_lang)
                : EngineL10n.linkLanSameNetworkHint(_lang),
            style: zt.caption.copyWith(color: zc.textTertiary),
          ),
          if (_discovered.isNotEmpty) ...[
            const SizedBox(height: ZSpace.md),
            Text(
              EngineL10n.linkLanFound(_lang),
              style: zt.caption.copyWith(color: zc.textSecondary),
            ),
            const SizedBox(height: ZSpace.xs),
            for (final camera in _discovered)
              _buildDiscoveredRow(context, camera),
          ] else if (_hasScannedLan && !_isScanningLan) ...[
            const SizedBox(height: ZSpace.sm),
            Text(
              _lanScanDiagMessage ?? EngineL10n.linkLanNoFound(_lang),
              style: zt.caption.copyWith(color: zc.warning),
            ),
          ],
          const SizedBox(height: ZSpace.lg),
          ZButton(
            label: _isLanConnecting
                ? EngineL10n.linkConnecting(_lang)
                : EngineL10n.linkLanConnect(_lang),
            icon: Icons.lan_outlined,
            size: ZButtonSize.lg,
            expanded: true,
            loading: _isLanConnecting,
            onTap: busy || widget.driver.isConnected ? null : _connectLan,
          ),
          if (_lanPhase == _LanPhase.failed && _lanError != null) ...[
            const SizedBox(height: ZSpace.sm),
            Text(
              _lanError!,
              style: zt.caption.copyWith(color: zc.danger),
            ),
          ],
          const SizedBox(height: ZSpace.md),
          InkWell(
            borderRadius: ZRadius.brSm,
            onTap: () => setState(() => _showGuidAdvanced = !_showGuidAdvanced),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: ZSpace.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.vpn_key_outlined,
                    size: 14,
                    color: zc.textTertiary,
                  ),
                  const SizedBox(width: ZSpace.xs),
                  Expanded(
                    child: Text(
                      '${EngineL10n.linkStaGuidSectionTitle(_lang)} · $guidPreview',
                      style: zt.caption.copyWith(color: zc.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _showGuidAdvanced
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: zc.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          if (_showGuidAdvanced) ...[
            const SizedBox(height: ZSpace.xs),
            Container(
              padding: const EdgeInsets.all(ZSpace.md),
              decoration: BoxDecoration(
                color: zc.surfaceHigh,
                borderRadius: ZRadius.brSm,
                border: Border.all(color: zc.outline, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    EngineL10n.linkStaGuidSectionDesc(_lang),
                    style: zt.caption.copyWith(
                      color: zc.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: ZSpace.sm),
                  Row(
                    children: [
                      ZButton(
                        label: EngineL10n.linkStaGuidCopyBtn(_lang),
                        icon: Icons.copy_rounded,
                        variant: ZButtonVariant.tonal,
                        size: ZButtonSize.sm,
                        onTap: _copyCurrentGuid,
                      ),
                      const SizedBox(width: ZSpace.sm),
                      ZButton(
                        label: EngineL10n.linkStaGuidImportBtn(_lang),
                        icon: Icons.download_rounded,
                        variant: ZButtonVariant.ghost,
                        size: ZButtonSize.sm,
                        onTap: _showImportGuidDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoveredRow(
    BuildContext context,
    DiscoveredPtpCamera camera,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    return Padding(
      padding: const EdgeInsets.only(bottom: ZSpace.xs),
      child: ZCard(
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpace.md,
          vertical: ZSpace.sm,
        ),
        onTap: () {
          _lanIp = camera.host;
          _ipFieldKey.currentState?.setIp(camera.host);
          HapticFeedback.selectionClick();
        },
        child: Row(
          children: [
            Icon(Icons.camera_alt_outlined, size: 16, color: zc.accent),
            const SizedBox(width: ZSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    camera.displayName,
                    style: zt.bodySmall.copyWith(
                      color: zc.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${camera.host}:${camera.port}',
                    style: zt.caption.copyWith(color: zc.textTertiary),
                  ),
                ],
              ),
            ),
            ZTag(
              text: camera.pairing
                  ? EngineL10n.linkLanPairingBadge(_lang)
                  : EngineL10n.linkLanReadyBadge(_lang),
              color: camera.pairing ? zc.warning : zc.success,
            ),
          ],
        ),
      ),
    );
  }

  // ---- USB 面板 ----

  Widget _buildUsbPanel(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final device = _detectedUsb;
    final busy = _usbConnecting != null || widget.driver.isConnected;

    return ZCard(
      padding: const EdgeInsets.all(ZSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _iconTile(
                context,
                Icons.usb_rounded,
                device != null && device.ptpReady ? zc.accent : zc.textSecondary,
              ),
              const SizedBox(width: ZSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(EngineL10n.linkUsbTitle(_lang), style: zt.caption),
                    const SizedBox(height: 2),
                    Text(
                      device != null
                          ? '${device.name} (${device.modeLabel})'
                          : EngineL10n.linkUsbEmpty(_lang),
                      style: zt.label.copyWith(
                        color: device != null && device.ptpReady
                            ? zc.textPrimary
                            : zc.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ZIconButton(
                icon: Icons.refresh_rounded,
                tooltip: context.l10n.connectRedetectWifiTooltip,
                onTap: _refreshUsbDevices,
              ),
            ],
          ),
          if (device != null) ...[
            const SizedBox(height: ZSpace.xs),
            Text(
              EngineL10n.linkUsbDetected(_lang),
              style: zt.caption.copyWith(
                color: device.ptpReady ? zc.success : zc.warning,
              ),
            ),
          ] else ...[
            const SizedBox(height: ZSpace.sm),
            Text(
              EngineL10n.usbNoDeviceHint(_lang),
              style: zt.caption.copyWith(color: zc.textSecondary),
            ),
          ],
          const SizedBox(height: ZSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showUsbDiagnosticsDialog(context),
              child: Text(EngineL10n.linkUsbOpenDiagnostics(_lang)),
            ),
          ),
          const SizedBox(height: ZSpace.xs),
          ZButton(
            label: _usbConnecting != null
                ? EngineL10n.linkConnecting(_lang)
                : (_isUsbScanning
                    ? EngineL10n.linkUsbScanning(_lang)
                    : (device != null
                        ? EngineL10n.linkUsbConnect(_lang)
                        : EngineL10n.linkUsbRescan(_lang))),
            icon: device != null ? Icons.cable_rounded : Icons.refresh_rounded,
            size: ZButtonSize.lg,
            expanded: true,
            loading: _usbConnecting != null,
            onTap: busy
                ? null
                : (device != null
                    ? () => _connectUsb(device)
                    : _refreshUsbDevices),
          ),
        ],
      ),
    );
  }

  // ---- 教程与小贴士 ----

  Widget _buildTutorial(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final steps = switch (_method) {
      LinkMethod.hotspot => EngineL10n.linkHotspotSteps(_lang),
      LinkMethod.lan => _staSubMode == StaSubMode.hotspot
          ? EngineL10n.linkStaHotspotSteps(_lang)
          : EngineL10n.linkLanSteps(_lang),
      LinkMethod.usb => EngineL10n.linkUsbSteps(_lang),
    };
    final icon = switch (_method) {
      LinkMethod.hotspot => Icons.wifi_tethering_rounded,
      LinkMethod.lan => Icons.router_outlined,
      LinkMethod.usb => Icons.usb_rounded,
    };
    final title = switch (_method) {
      LinkMethod.hotspot => EngineL10n.linkModeHotspot(_lang),
      LinkMethod.lan => EngineL10n.linkModeLan(_lang),
      LinkMethod.usb => EngineL10n.linkModeUsb(_lang),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(EngineL10n.linkTutorialTitle(_lang), style: zt.title),
        const SizedBox(height: ZSpace.md),
        ZCard(
          padding: const EdgeInsets.all(ZSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _iconTile(context, icon, zc.accent),
                  const SizedBox(width: ZSpace.md),
                  Expanded(child: Text(title, style: zt.headline)),
                  if (_method == LinkMethod.hotspot)
                    ZTag(
                      text: EngineL10n.linkRecommended(_lang),
                      color: zc.accent,
                    ),
                ],
              ),
              const SizedBox(height: ZSpace.lg),
              _buildSteps(context, steps),
              if (_method == LinkMethod.lan) ...[
                const SizedBox(height: ZSpace.md),
                Container(
                  padding: const EdgeInsets.all(ZSpace.md),
                  decoration: BoxDecoration(
                    color: zc.accentContainer,
                    borderRadius: ZRadius.brSm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: zc.accent,
                      ),
                      const SizedBox(width: ZSpace.sm),
                      Expanded(
                        child: Text(
                          EngineL10n.linkTutorialNote(_lang),
                          style: zt.caption.copyWith(color: zc.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(
    BuildContext context,
    List<(String, String)> steps,
  ) {
    final zc = context.zc;
    final zt = context.zt;
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: zc.accentContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: zc.accent.withAlpha(120),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: zt.caption.copyWith(
                            color: zc.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: zc.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: ZSpace.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : ZSpace.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(steps[i].$1, style: zt.label),
                        const SizedBox(height: 2),
                        Text(
                          steps[i].$2,
                          style: zt.bodySmall.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTips(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final tips = [
      (Icons.router_outlined, EngineL10n.linkTipLan(_lang)),
      (Icons.wifi_tethering_rounded, EngineL10n.linkTipHotspot(_lang)),
      (Icons.usb_rounded, EngineL10n.linkTipUsb(_lang)),
    ];
    return ZCard(
      elevated: true,
      padding: const EdgeInsets.all(ZSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(EngineL10n.linkTipsTitle(_lang), style: zt.label),
          const SizedBox(height: ZSpace.md),
          for (final tip in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: ZSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tip.$1, size: 15, color: zc.textTertiary),
                  const SizedBox(width: ZSpace.sm),
                  Expanded(
                    child: Text(
                      tip.$2,
                      style: zt.caption.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- 小组件 ----

  Widget _iconTile(BuildContext context, IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: ZRadius.brSm,
        border: Border.all(color: color.withAlpha(90), width: 0.8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _ImportGuidDialog extends StatefulWidget {
  const _ImportGuidDialog({
    required this.lang,
    required this.cancelLabel,
    required this.initialGuid,
  });

  final String lang;
  final String cancelLabel;
  final String initialGuid;

  @override
  State<_ImportGuidDialog> createState() => _ImportGuidDialogState();
}

class _ImportGuidDialogState extends State<_ImportGuidDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialGuid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return ZDialog(
      title: EngineL10n.linkStaGuidImportDialogTitle(widget.lang),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            EngineL10n.linkStaGuidImportHint(widget.lang),
            style: zt.caption.copyWith(color: zc.textSecondary),
          ),
          const SizedBox(height: ZSpace.md),
          TextField(
            controller: _controller,
            autofocus: true,
            style: zt.bodySmall.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: '00112233445566778899aabbccddeeff',
              errorText: _errorText,
              filled: true,
              fillColor: zc.surfaceHigh,
              border: const OutlineInputBorder(
                borderRadius: ZRadius.brSm,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ZButton(
          label: widget.cancelLabel,
          variant: ZButtonVariant.ghost,
          onTap: () => Navigator.pop(context, false),
        ),
        ZButton(
          label: EngineL10n.linkStaGuidImportBtn(widget.lang),
          onTap: () {
            final ok = AppSettings.instance.setPtpClientGuid(_controller.text);
            if (!ok) {
              setState(() {
                _errorText = EngineL10n.linkStaGuidImportInvalid(widget.lang);
              });
              return;
            }
            Navigator.pop(context, true);
          },
        ),
      ],
    );
  }
}
