import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/exif_helper.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/transfer/shoot_and_transfer.dart';
import '../../engine/update/app_update_manager.dart';
import '../../l10n/l10n.dart';
import '../../protocol/nikon_driver.dart';
import 'design/design.dart';
import 'screens/connect_screen.dart';
import 'screens/gallery_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_center_screen.dart';
import 'screens/watermark_screen.dart';
import 'widgets/adaptive_layout.dart';

/// 单个导航页签定义（底部悬浮胶囊栏、平板 Rail 与大屏可展开侧栏共用）。
class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavTab(this.icon, this.activeIcon, this.label);
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
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool? _manualSidebarExpanded;

  late final NikonDriver _driver;
  late final DownloadManager _downloadManager;
  late final ShootAndTransferController _shootAndTransferController;
  late final AnimationController _tabFadeController;
  late final Animation<double> _tabFadeAnimation;
  late final Animation<double> _tabScaleAnimation;

  final GlobalKey<GalleryScreenState> _galleryKey =
      GlobalKey<GalleryScreenState>();
  final GlobalKey<WatermarkScreenState> _watermarkKey =
      GlobalKey<WatermarkScreenState>();
  final GlobalKey<ConnectScreenState> _connectKey =
      GlobalKey<ConnectScreenState>();
  DateTime? _lastExitHintAt;

  @override
  void initState() {
    super.initState();
    _driver = NikonDriver();
    _downloadManager = DownloadManager(driver: _driver);
    _shootAndTransferController = ShootAndTransferController(
      driver: _driver,
      downloadManager: _downloadManager,
    );

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

    // 应用启动静默检测是否有远程新版本
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateManager.checkOnStartup(context);
      }
    });
  }

  @override
  void dispose() {
    _tabFadeController.dispose();
    _shootAndTransferController.dispose();
    _driver.dispose();
    super.dispose();
  }

  List<_NavTab> _buildNavTabs(BuildContext context) {
    final l10n = context.l10n;
    return [
      _NavTab(Icons.wifi_tethering, Icons.wifi_tethering, l10n.navConnect),
      _NavTab(
          Icons.photo_library_outlined, Icons.photo_library, l10n.navGallery),
      _NavTab(Icons.branding_watermark_outlined, Icons.branding_watermark,
          l10n.navWatermark),
      _NavTab(Icons.tune_outlined, Icons.tune, l10n.navSettings),
    ];
  }

  /// 切换页签的共用逻辑（底部导航与左侧导航栏一致）。
  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    if (index == 1 && _driver.isConnected) {
      _galleryKey.currentState?.reloadFilesIfEmpty();
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
      0 => _connectKey.currentState?.handleSystemBack() ?? false,
      1 => _galleryKey.currentState?.handleSystemBack() ?? false,
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(context.l10n.exitConfirmHint),
        duration: const Duration(seconds: 2),
      ));
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
        onConnected: () {
          _galleryKey.currentState?.reloadFiles();
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
          _onTabSelected(1);
        },
        onOpenWatermark: ({
          Uint8List? initialBytes,
          PhotoMetadata? meta,
          bool openFilter = false,
        }) {
          _onTabSelected(2);
          if (initialBytes != null && initialBytes.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _watermarkKey.currentState?.loadImageBytes(initialBytes, meta);
              if (openFilter) _watermarkKey.currentState?.showFilterTab();
            });
          }
        },
        onOpenTransferCenter: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransferCenterScreen(manager: _downloadManager),
            ),
          );
        },
      ),
      GalleryScreen(
        key: _galleryKey,
        driver: _driver,
        downloadManager: _downloadManager,
        shootAndTransferController: _shootAndTransferController,
        onOpenWatermark: (file, cachedBytes,
            {bool openFilter = false, String? rawPath}) async {
          if (cachedBytes == null || cachedBytes.isEmpty) return;
          _onTabSelected(2);
          if (openFilter) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _watermarkKey.currentState?.showFilterTab();
            });
          }

          void inject(Uint8List b) {
            final fallbackMeta = PhotoMetadata(
              cameraModel:
                  _driver.cameraModel.isNotEmpty ? _driver.cameraModel : 'Z 30',
              capturedDate: file.captureDate.isNotEmpty ? file.captureDate : '',
            );
            if (_watermarkKey.currentState != null) {
              _watermarkKey.currentState!.setRawSourcePath(rawPath);
              _watermarkKey.currentState!.loadImageBytes(b, fallbackMeta);
            } else {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _watermarkKey.currentState?.setRawSourcePath(rawPath);
                _watermarkKey.currentState?.loadImageBytes(b, fallbackMeta);
              });
            }
          }

          inject(cachedBytes);
        },
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
    return _withSystemBackGuard(Scaffold(
      backgroundColor: zc.bg,
      body: body,
      bottomNavigationBar: _FloatingPillBottomBar(
        currentIndex: _currentIndex,
        tabs: tabs,
        onTap: _onTabSelected,
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
