import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants/network_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/capture/capture_controller.dart';
import '../../engine/capture/interval_shooting_controller.dart';
import '../../engine/capture/exposure_settings_controller.dart';
import '../../engine/capture/movie_recording_controller.dart';
import '../../engine/capture/bracket_ports.dart';
import '../../engine/capture/camera_hdr_controller.dart';
import '../../engine/capture/exposure_bracketing_controller.dart';
import '../../engine/capture/focus_stacking_controller.dart';
import '../../engine/liveview/live_view_analyzer.dart';
import '../../engine/liveview/live_view_analysis.dart';
import '../../engine/liveview/live_view_controller.dart';
import '../../engine/liveview/manual_focus_drive_controller.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/transfer/download_queue_store.dart';
import '../../engine/transfer/shoot_and_transfer.dart';
import '../../engine/update/app_update_manager.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../protocol/connection_recovery_controller.dart';
import '../../protocol/nikon_driver.dart';
import 'design/design.dart';
import 'screens/capture_screen.dart';
import 'screens/connect_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/picture_control_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_center_screen.dart';
import 'screens/watermark_screen.dart';
import 'widgets/adaptive_layout.dart';

/// 单个导航页签定义（底部悬浮胶囊栏、平板 Rail 与大屏可展开侧栏共用）。
class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// 是否出现在手机底部胶囊栏。平板 Rail 始终显示全部页签。
  final bool showInBottomBar;

  const _NavTab(this.icon, this.activeIcon, this.label,
      {this.showInBottomBar = true});
}

/// Zync 主界面自适应导航壳：
/// - Compact (`< 600dp`): 底部悬浮胶囊导航栏 + 滑动高光指示器
/// - Medium / Expanded (`600–1199dp`): 左侧精简 `NavigationRail`
/// - Large (`>= 1200dp`): 可展开侧边栏（图标 + 标题 + 实时相机状态卡）
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const int _connectTabIndex = 0;
  static const int _captureTabIndex = 1;
  static const int _galleryTabIndex = 2;
  static const int _pictureControlTabIndex = 3;
  static const int _watermarkTabIndex = 4;
  static const int _settingsTabIndex = 5;

  /// 底栏位置 → screens 索引。拍摄台只在平板 Rail 里出现。
  static const List<int> _bottomToScreen = <int>[
    _connectTabIndex,
    _galleryTabIndex,
    _pictureControlTabIndex,
    _watermarkTabIndex,
    _settingsTabIndex,
  ];

  int _currentIndex = 0;
  bool? _manualSidebarExpanded;
  String? _liveViewSignature;

  late final NikonDriver _driver;
  late final DownloadManager _downloadManager;
  late final ConnectionRecoveryController _recoveryController;
  late final ShootAndTransferController _shootAndTransferController;
  late final LiveViewAnalyzer _liveViewAnalyzer;
  late final LiveViewController _liveViewController;
  late final ManualFocusDriveController _manualFocusController;
  late final CaptureController _captureController;
  late final ExposureSettingsController _exposureController;
  late final IntervalShootingController _intervalController;
  late final MovieRecordingController _movieController;
  late final ExposureBracketingController _bracketController;
  late final FocusStackingController _focusStackController;
  late final CameraHdrController _hdrController;
  late final AnimationController _tabFadeController;
  late final Animation<double> _tabFadeAnimation;
  late final Animation<double> _tabScaleAnimation;

  final GlobalKey<CaptureScreenState> _captureKey =
      GlobalKey<CaptureScreenState>();
  final GlobalKey<GalleryScreenState> _galleryKey =
      GlobalKey<GalleryScreenState>();
  final GlobalKey<PictureControlScreenState> _pictureControlKey =
      GlobalKey<PictureControlScreenState>();
  final GlobalKey<WatermarkScreenState> _watermarkKey =
      GlobalKey<WatermarkScreenState>();
  final GlobalKey<ConnectScreenState> _connectKey =
      GlobalKey<ConnectScreenState>();
  DateTime? _lastExitHintAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _driver = NikonDriver();
    _downloadManager = DownloadManager(driver: _driver);
    _recoveryController = ConnectionRecoveryController(
      reconnect: () => _driver.reconnect(),
      restoreSession: _restoreSessionAfterReconnect,
      probe: () => probeCameraPort(
        NetworkConfig.cameraIp,
        NetworkConfig.cameraPort,
      ),
    );
    _driver.onUnexpectedDisconnect = _handleUnexpectedDisconnect;
    unawaited(_attachDownloadQueueStore());
    _shootAndTransferController = ShootAndTransferController(
      driver: _driver,
      downloadManager: _downloadManager,
    );
    _liveViewAnalyzer = LiveViewAnalyzer(
      settings: _analysisSettingsFromApp(),
    );
    _liveViewController = LiveViewController(
      driver: _driver,
      analysis: _liveViewAnalyzer,
      frameInterval: AppSettings.instance.liveViewFrameInterval,
    );
    _manualFocusController = ManualFocusDriveController(
      driver: _driver,
      liveView: _liveViewController,
    );
    _captureController = CaptureController(
      driver: _driver,
      liveView: _liveViewController,
      // 必须经过 ShootAndTransferController：它负责「边拍边传开关」与 RAW 过滤。
      onCaptured: _shootAndTransferController.handleCaptured,
    );
    _exposureController = ExposureSettingsController(
      driver: _driver,
      liveView: _liveViewController,
    );
    _intervalController = IntervalShootingController(
      capture: () => _captureController.capture(),
    );
    _movieController = MovieRecordingController(driver: _driver);
    _bracketController = ExposureBracketingController(
      port: ExposureSettingsBracketPort(
        driver: _driver,
        exposure: _exposureController,
        captureController: _captureController,
      ),
    );
    _focusStackController = FocusStackingController(
      port: DriverFocusStackPort(
        driver: _driver,
        captureController: _captureController,
      ),
    );
    _hdrController = CameraHdrController(
      driver: _driver,
      capture: () => _captureController.capture(),
    );
    AppSettings.instance.addListener(_syncLiveViewSettings);

    _tabFadeController = AnimationController(
      vsync: this,
      duration: ZMotion.medium,
      value: 1.0,
    );
    _tabFadeAnimation = CurvedAnimation(
      parent: _tabFadeController,
      curve: ZMotion.emphasized,
    );
    _tabScaleAnimation = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(
        parent: _tabFadeController,
        curve: ZMotion.emphasized,
      ),
    );

    // 应用启动静默检测是否有远程新版本，以及是否从系统收到外部打开的 .NP3/.NCP/.ZIP 文件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateManager.checkOnStartup(context);
        _checkIncomingExternalFiles();
      }
    });
  }

  /// 队列持久化：把上次没传完的任务接回来，冷启动后自动续传。
  Future<void> _attachDownloadQueueStore() async {
    try {
      final base = await getApplicationSupportDirectory();
      await _downloadManager.attachStore(DownloadQueueStore(directory: base));
    } catch (e) {
      // 持久化不可用不应影响正常传输，退化为纯内存队列。
      debugPrint('download queue persistence unavailable: $e');
    }
  }

  void _handleUnexpectedDisconnect() {
    _downloadManager.pauseForReconnect();
    // 关掉自动重连时只挂起队列，把恢复时机交回用户（手动连接同样会续传）。
    if (!AppSettings.instance.autoReconnectEnabled) return;
    _recoveryController.notifyUnexpectedDisconnect();
  }

  /// 重连成功后把会话现场拉回来：重启取景 + 恢复续传队列。
  Future<void> _restoreSessionAfterReconnect() async {
    // 断线时取景一定已经停了。只有在拍摄页、且设置为自动开始时才自动重启，
    // 否则用户在相册页被重连拽回取景会很突兀。
    if (_currentIndex == _captureTabIndex &&
        AppSettings.instance.liveViewAutoStart) {
      try {
        await _liveViewController.start();
      } catch (_) {}
    }
    if (AppSettings.instance.resumeTransfersAfterReconnect) {
      await _downloadManager.resumeAfterReconnect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {    if (state == AppLifecycleState.resumed) {
      _checkIncomingExternalFiles();
      if (_currentIndex == _captureTabIndex) {
        _captureKey.currentState?.onTabVisible();
      }
    } else {
      // 退到后台时相机热点可能被系统断开，先主动退出取景。
      _captureKey.currentState?.onTabHidden();
    }
  }

  Future<void> _checkIncomingExternalFiles() async {
    final paths = await CameraNativeBridge.consumeIncomingFiles();
    if (!mounted || paths.isEmpty) return;
    _onTabSelected(_pictureControlTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pictureControlKey.currentState?.importExternalFiles(paths);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabFadeController.dispose();
    AppSettings.instance.removeListener(_syncLiveViewSettings);
    _intervalController.dispose();
    _movieController.dispose();
    _bracketController.dispose();
    _focusStackController.dispose();
    _manualFocusController.dispose();
    _liveViewController.dispose();
    _liveViewAnalyzer.dispose();
    _captureController.dispose();
    _exposureController.dispose();
    _shootAndTransferController.dispose();
    _recoveryController.cancel();
    _recoveryController.dispose();
    _driver.onUnexpectedDisconnect = null;
    _driver.dispose();
    super.dispose();
  }

  LiveViewAnalysisSettings _analysisSettingsFromApp() {
    final s = AppSettings.instance;
    return LiveViewAnalysisSettings(
      focusPeaking: s.liveViewFocusPeaking,
      peakThreshold: s.liveViewPeakingThreshold,
      peakColor: s.liveViewPeakingColor,
      zebra: s.liveViewZebra,
      zebraThreshold: s.liveViewZebraThreshold,
      histogram: s.liveViewHistogram,
    );
  }

  /// 设置页改了取景相关开关后，同步给分析器与取景循环。
  ///
  /// 只在**取景相关**设置真的变了才重建：AppSettings 是全局的，
  /// 水印滑条每动一下都会通知，无差别 setState 会把整个导航壳一起拖慢。
  void _syncLiveViewSettings() {
    if (!mounted) return;
    final settings = AppSettings.instance;
    final signature = _liveViewSettingsSignature(settings);
    if (signature == _liveViewSignature) return;
    _liveViewSignature = signature;
    _liveViewAnalyzer.updateSettings(_analysisSettingsFromApp());
    _liveViewController.updateFrameInterval(settings.liveViewFrameInterval);
    setState(() {});
  }

  String _liveViewSettingsSignature(AppSettings s) => [
        s.liveViewFpsCap,
        s.liveViewAutoStart,
        s.liveViewShowFps,
        s.liveViewKeepScreenOn,
        s.liveViewGridMode,
        s.liveViewGuideLines,
        s.liveViewFocusPeaking,
        s.liveViewPeakingColor,
        s.liveViewPeakingThreshold,
        s.liveViewZebra,
        s.liveViewZebraThreshold,
        s.liveViewHistogram,
        s.liveViewAfDrive,
        s.liveViewMfStep,
      ].join('|');

  List<_NavTab> _buildNavTabs(BuildContext context) {
    final l10n = context.l10n;
    return [
      _NavTab(Icons.wifi_tethering, Icons.wifi_tethering, l10n.navConnect),
      _NavTab(Icons.camera_outlined, Icons.camera, l10n.navCapture,
          showInBottomBar: false),
      _NavTab(
          Icons.photo_library_outlined, Icons.photo_library, l10n.navGallery),
      _NavTab(Icons.palette_outlined, Icons.palette, l10n.navPictureControl),
      _NavTab(Icons.branding_watermark_outlined, Icons.branding_watermark,
          l10n.navWatermark),
      _NavTab(Icons.tune_outlined, Icons.tune, l10n.navSettings),
    ];
  }

  /// 切换页签的共用逻辑（底部导航与左侧导航栏一致）。
  void _onTabSelected(int index) {
    if (index == _currentIndex) return;

    // 离开拍摄台时立即退出取景，否则相机会一直保持在取景模式。
    if (_currentIndex == _captureTabIndex) {
      _captureKey.currentState?.onTabHidden();
    }

    if (index == _galleryTabIndex && _driver.isConnected) {
      _galleryKey.currentState?.reloadFilesIfEmpty();
    } else if (index == _pictureControlTabIndex && _driver.isConnected) {
      _pictureControlKey.currentState?.refreshCameraSlots();
    } else if (index == _captureTabIndex) {
      _captureKey.currentState?.onTabVisible();
    }

    final duration = ZMotion.of(context, ZMotion.medium);
    setState(() => _currentIndex = index);
    if (duration == Duration.zero) {
      _tabFadeController.value = 1.0;
    } else {
      _tabFadeController.duration = duration;
      _tabFadeController.forward(from: 0.0);
    }
  }

  /// 系统返回（返回键 / 返回手势）的统一入口：手机底部导航与平板左侧导航栏行为一致。
  bool _handleSystemBack() {
    final consumedByTab = switch (_currentIndex) {
      _connectTabIndex => _connectKey.currentState?.handleSystemBack() ?? false,
      _captureTabIndex => _captureKey.currentState?.handleSystemBack() ?? false,
      _galleryTabIndex => _galleryKey.currentState?.handleSystemBack() ?? false,
      _ => false,
    };
    if (consumedByTab) return true;

    if (_currentIndex != 0) {
      _onTabSelected(0);
      return true;
    }

    final now = DateTime.now();
    final confirmed = _lastExitHintAt != null &&
        now.difference(_lastExitHintAt!) < const Duration(seconds: 2);
    _lastExitHintAt = now;
    if (confirmed) return false;

    showZToast(
      context,
      context.l10n.exitConfirmHint,
      duration: const Duration(seconds: 2),
    );
    return true;
  }

  Widget _withSystemBackGuard(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_handleSystemBack()) SystemNavigator.pop();
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final zb = context.zb;
    final l10n = context.l10n;
    final tabs = _buildNavTabs(context);

    final screens = [
      ConnectScreen(
        key: _connectKey,
        driver: _driver,
        downloadManager: _downloadManager,
        shootAndTransferController: _shootAndTransferController,
        onDisconnect: _recoveryController.cancel,
        onConnected: () {
          _recoveryController.acknowledge();
          // 用户可能关掉了自动重连、改为手动连接：队列同样要续上。
          unawaited(_downloadManager.resumeAfterReconnect());
          _galleryKey.currentState?.reloadFiles();
          _pictureControlKey.currentState?.refreshCameraSlots();
          if (mounted) setState(() {});
        },
        onNavigateToGallery: (
            {bool exportedTab = false, bool enterCollagePick = false}) {
          if (exportedTab) {
            _galleryKey.currentState?.switchToExportedTab();
          } else if (enterCollagePick) {
            _galleryKey.currentState?.enterCollageSelectionMode();
          } else {
            _galleryKey.currentState?.reloadFilesIfEmpty();
          }
          _onTabSelected(2);
        },
        onOpenWatermark: ({
          Uint8List? initialBytes,
          PhotoMetadata? meta,
          bool openFilter = false,
        }) {
          _onTabSelected(4);
          if (initialBytes != null && initialBytes.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _watermarkKey.currentState
                  ?.loadImageBytes(initialBytes, metadata: meta);
              if (openFilter) _watermarkKey.currentState?.showFilterTab();
            });
          }
        },
        onOpenTransferCenter: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransferCenterScreen(
                manager: _downloadManager,
                recovery: _recoveryController,
              ),
            ),
          );
        },
        onOpenCapture: () => _onTabSelected(_captureTabIndex),
        // 只负责跳转；导入动作由色彩优化页自己的「导入」按钮发起。
        onImportColor: () => _onTabSelected(_pictureControlTabIndex),
      ),
      CaptureScreen(
        key: _captureKey,
        driver: _driver,
        liveViewController: _liveViewController,
        captureController: _captureController,
        exposureController: _exposureController,
        manualFocusController: _manualFocusController,
        intervalController: _intervalController,
        movieController: _movieController,
        bracketController: _bracketController,
        focusStackController: _focusStackController,
        hdrController: _hdrController,
        downloadManager: _downloadManager,
        onNavigateToConnect: () => _onTabSelected(_connectTabIndex),
      ),
      GalleryScreen(
        key: _galleryKey,
        driver: _driver,
        downloadManager: _downloadManager,
        shootAndTransferController: _shootAndTransferController,
        onOpenWatermark: (file, cachedBytes,
            {bool openFilter = false, String? rawPath}) async {
          if (cachedBytes == null || cachedBytes.isEmpty) return;
          _onTabSelected(4);
          if (openFilter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _watermarkKey.currentState?.showFilterTab();
            });
          }

          void inject(Uint8List b) {
            final fallbackMeta = PhotoMetadata(
              cameraModel:
                  _driver.cameraModel.isNotEmpty ? _driver.cameraModel : 'Z 30',
              capturedDate:
                  file.captureDate.isNotEmpty ? file.captureDateDisplay : '',
            );
            if (_watermarkKey.currentState != null) {
              _watermarkKey.currentState!.loadImageBytes(
                b,
                metadata: fallbackMeta,
                rawPath: rawPath,
              );
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _watermarkKey.currentState?.loadImageBytes(
                  b,
                  metadata: fallbackMeta,
                  rawPath: rawPath,
                );
              });
            }
          }

          inject(cachedBytes);
        },
      ),
      PictureControlScreen(
        key: _pictureControlKey,
        driver: _driver,
      ),
      WatermarkScreen(key: _watermarkKey),
      const SettingsScreen(),
    ];

    final body = FadeTransition(
      opacity: _tabFadeAnimation,
      child: ScaleTransition(
        scale: _tabScaleAnimation,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < screens.length; i++)
              TickerMode(
                enabled: i == _currentIndex,
                child: screens[i],
              ),
          ],
        ),
      ),
    );

    // 宽屏（>= 600dp）：左侧 NavigationRail（>= 1200dp 默认展开为 248dp 侧边栏）
    if (isAdaptiveWide(context)) {
      final isExpanded = _manualSidebarExpanded ?? zb.hasExpandableSidebar;
      return _withSystemBackGuard(Scaffold(
        backgroundColor: zc.bg,
        body: Row(
          children: [
            NavigationRail(
              key: const ValueKey<String>('zync_nav_rail'),
              backgroundColor: zc.surface,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              extended: isExpanded,
              minWidth: 84,
              minExtendedWidth: 248,
              labelType: isExpanded
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: ZSpace.md,
                  horizontal: ZSpace.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: ZRadius.brSm,
                        border: Border.all(color: zc.outline, width: 0.8),
                      ),
                      child: Image.asset(
                        'assets/icons/zync_logo.png',
                        errorBuilder: (ctx, err, stack) => Icon(
                          Icons.camera_alt_outlined,
                          color: zc.accent,
                          size: 20,
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      const SizedBox(width: ZSpace.md),
                      Text(
                        'Zync',
                        style: zt.headline.copyWith(letterSpacing: 0.4),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: ZSpace.lg,
                      left: ZSpace.sm,
                      right: ZSpace.sm,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isExpanded) ...[
                          _SidebarCameraStatusCard(
                            driver: _driver,
                            onTap: () => _onTabSelected(0),
                          ),
                          const SizedBox(height: ZSpace.md),
                        ],
                        ZIconButton(
                          key: const ValueKey<String>(
                              'zync_sidebar_toggle_button'),
                          icon: isExpanded
                              ? Icons.keyboard_double_arrow_left_rounded
                              : Icons.keyboard_double_arrow_right_rounded,
                          tooltip: isExpanded
                              ? l10n.sidebarCollapse
                              : l10n.sidebarExpand,
                          onTap: () {
                            setState(() {
                              _manualSidebarExpanded = !isExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: [
                for (final tab in tabs)
                  NavigationRailDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.activeIcon),
                    label: Text(tab.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, thickness: 0.8, color: zc.outline),
            Expanded(child: body),
          ],
        ),
      ));
    }

    // 窄屏（< 600dp）：底部悬浮胶囊导航栏 + 滑动高光指示器
    // 拍摄页在手机上占满全屏：底栏整条隐藏，退出后再出现。
    final hideBottomBar = _currentIndex == _captureTabIndex;
    final bottomTabs =
        tabs.where((tab) => tab.showInBottomBar).toList(growable: false);
    final bottomIndex = _bottomToScreen.indexOf(_currentIndex);

    return _withSystemBackGuard(Scaffold(
      backgroundColor: zc.bg,
      body: body,
      bottomNavigationBar: hideBottomBar
          ? null
          : _FloatingPillBottomBar(
              currentIndex: bottomIndex < 0 ? 0 : bottomIndex,
              tabs: bottomTabs,
              onTap: (localIndex) =>
                  _onTabSelected(_bottomToScreen[localIndex]),
            ),
    ));
  }
}

class _FloatingPillBottomBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavTab> tabs;
  final ValueChanged<int> onTap;

  const _FloatingPillBottomBar({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final duration = ZMotion.of(context, ZMotion.medium);
    final count = tabs.length;
    final alignX = count > 1 ? -1.0 + (2.0 * currentIndex / (count - 1)) : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ZSpace.lg,
          ZSpace.xs,
          ZSpace.lg,
          ZSpace.sm,
        ),
        child: Container(
          key: const ValueKey<String>('zync_floating_pill_nav'),
          decoration: BoxDecoration(
            color: zc.surface,
            borderRadius: ZRadius.brPill,
            border: Border.all(color: zc.outlineStrong, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: zc.scrim.withAlpha(65),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: ZRadius.brPill,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 滑动胶囊高光指示器
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(ZSpace.xs),
                    child: AnimatedAlign(
                      duration: duration,
                      curve: ZMotion.emphasized,
                      alignment: Alignment(alignX, 0),
                      child: FractionallySizedBox(
                        widthFactor: 1.0 / count,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: zc.accentContainer.withAlpha(140),
                            borderRadius: ZRadius.brPill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                BottomNavigationBar(
                  currentIndex: currentIndex,
                  onTap: onTap,
                  backgroundColor: ZSwatch.transparent,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedItemColor: zc.accent,
                  unselectedItemColor: zc.textSecondary,
                  items: [
                    for (final tab in tabs)
                      BottomNavigationBarItem(
                        icon: Icon(tab.icon, size: 20),
                        activeIcon:
                            Icon(tab.activeIcon, size: 20, color: zc.accent),
                        label: tab.label,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarCameraStatusCard extends StatelessWidget {
  final NikonDriver driver;
  final VoidCallback onTap;

  const _SidebarCameraStatusCard({
    required this.driver,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final connected = driver.isConnected;
    final model = driver.cameraModel.isNotEmpty
        ? driver.cameraModel
        : l10n.statusCameraDisconnected;

    return ZCard(
      key: const ValueKey<String>('zync_sidebar_camera_card'),
      elevated: true,
      padding: const EdgeInsets.all(ZSpace.md),
      onTap: onTap,
      child: SizedBox(
        width: 212,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connected ? zc.success : zc.textTertiary,
                  ),
                ),
                const SizedBox(width: ZSpace.sm),
                Expanded(
                  child: Text(
                    connected
                        ? l10n.connectStateConnected
                        : l10n.connectStateDisconnected,
                    style: zt.caption.copyWith(
                      color: connected ? zc.success : zc.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (connected)
                  Text(
                    '${driver.batteryLevel}%',
                    style: zt.numericSmall,
                  ),
              ],
            ),
            const SizedBox(height: ZSpace.xs),
            Text(
              model,
              style: zt.title.copyWith(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
