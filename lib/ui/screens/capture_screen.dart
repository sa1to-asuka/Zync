import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/ptp_opcodes.dart';
import '../../core/settings/app_settings.dart';
import '../../engine/capture/af_area_mapper.dart';
import '../../engine/capture/camera_property.dart';
import '../../engine/capture/capture_controller.dart';
import '../../engine/capture/exposure_capability.dart';
import '../../engine/capture/exposure_settings_controller.dart';
import '../../engine/capture/interval_shooting_controller.dart';
import '../../engine/capture/exposure_bracketing_controller.dart';
import '../../engine/capture/focus_stacking_controller.dart';
import '../../engine/capture/camera_hdr_controller.dart';
import '../../engine/capture/jpeg_scaler.dart';
import '../../engine/capture/sequence_compositor.dart';
import '../../engine/transfer/download_manager.dart';
import '../../engine/capture/movie_recording_controller.dart';
import '../../engine/liveview/live_view_controller.dart';
import '../../engine/liveview/live_view_frame_pipeline.dart';
import '../../engine/liveview/manual_focus_drive_controller.dart';
import '../../l10n/engine_l10n.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_driver.dart';
import '../../protocol/ptp_ip_client.dart' show PtpException;
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import 'capture/capture_controls.dart';
import 'capture/capture_interval_sheet.dart';
import 'capture/capture_overlays.dart';
import 'capture/capture_sequence_sheet.dart';
import 'capture/storage_folder_sheet.dart';

/// 拍摄台：实时取景 + 遥控快门 + 参数读写 + 对焦与叠加辅助。
///
/// 取景画面通过 `ValueNotifier` 直接驱动 `CustomPainter`，逐帧数据从不进入
/// widget state；这里只有用户手势会触发 `setState`。
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.driver,
    required this.liveViewController,
    required this.captureController,
    required this.exposureController,
    required this.manualFocusController,
    required this.intervalController,
    required this.movieController,
    required this.bracketController,
    required this.focusStackController,
    required this.hdrController,
    required this.downloadManager,
    required this.onNavigateToConnect,
  });

  final CameraDriver driver;
  final LiveViewController liveViewController;
  final CaptureController captureController;
  final ExposureSettingsController exposureController;
  final ManualFocusDriveController manualFocusController;
  final IntervalShootingController intervalController;
  final MovieRecordingController movieController;
  final ExposureBracketingController bracketController;
  final FocusStackingController focusStackController;
  final CameraHdrController hdrController;
  final DownloadManager downloadManager;
  final VoidCallback onNavigateToConnect;

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen> {
  StreamSubscription<CameraConnectionState>? _connectionSub;
  Timer? _orientationTimer;
  Timer? _modeTimer;
  Timer? _movieModeTimer;
  Timer? _focusTimer;

  bool _connected = false;
  bool _autoStarted = false;
  int _orientation = 0;
  Offset? _focusPoint;
  CameraParameter? _expandedParameter;
  bool? _lastCameraRecording;

  @override
  void initState() {
    super.initState();
    _connected = widget.driver.isConnected;
    _connectionSub = widget.driver.connectionStateStream.listen((state) {
      final connected = state == CameraConnectionState.connected;
      if (_connected == connected) return;
      setState(() => _connected = connected);
      if (connected) {
        widget.exposureController.refresh(force: true);
        widget.movieController.refresh();
        _startOrientationPolling();
      } else {
        widget.exposureController.clear();
        widget.intervalController.stop();
        widget.bracketController.stop();
        widget.focusStackController.stop();
        widget.manualFocusController.cancel();
        widget.liveViewController.stop();
        _stopModePolling();
        _stopOrientationPolling();
        _autoStarted = false;
      }
    });
    if (_connected) _startOrientationPolling();
    widget.movieController.attach();
    widget.liveViewController.addListener(_syncMovieRecordingFlag);
  }

  /// 取景帧头是机身侧录像状态的唯一可靠来源：
  /// 在机身上按红色录像键时，App 也会在几帧内切到录制态。
  void _syncMovieRecordingFlag() {
    final flag = widget.liveViewController.cameraRecording;
    if (flag == _lastCameraRecording) return;
    _lastCameraRecording = flag;
    widget.movieController.syncRecordingFlag(flag);
  }

  @override
  void dispose() {
    widget.liveViewController.removeListener(_syncMovieRecordingFlag);
    widget.movieController.detach();
    _connectionSub?.cancel();
    _orientationTimer?.cancel();
    _modeTimer?.cancel();
    _movieModeTimer?.cancel();
    _focusTimer?.cancel();
    CameraNativeBridge.setKeepScreenOn(false);
    super.dispose();
  }

  /// 由导航壳在切换到本页时调用。
  void onTabVisible() {
    if (!_connected) return;
    // 录像模式由机身拨杆决定，与是否支持取景无关，先起来。
    _startMovieModePolling();
    if (!widget.driver.supportsLiveView) return;
    widget.exposureController.refresh();
    _startModePolling();
    if (_autoStarted) return;
    if (!AppSettings.instance.liveViewAutoStart) return;
    _autoStarted = true;
    _startLiveView();
  }

  /// 由导航壳在离开本页或退到后台时调用。
  Future<void> onTabHidden() async {
    _autoStarted = false;
    _stopModePolling();
    await widget.manualFocusController.cancel();
    await widget.liveViewController.stop();
    await CameraNativeBridge.setKeepScreenOn(false);
  }

  /// 本页没有需要拦截的返回层级。
  bool handleSystemBack() => false;

  void _startLiveView() {
    widget.liveViewController.start();
    if (AppSettings.instance.liveViewKeepScreenOn) {
      CameraNativeBridge.setKeepScreenOn(true);
    }
  }

  Future<void> _toggleLiveView() async {
    if (widget.liveViewController.isActive) {
      await widget.liveViewController.stop();
      await CameraNativeBridge.setKeepScreenOn(false);
    } else {
      _autoStarted = true;
      _startLiveView();
    }
  }

  /// 机身拨盘随时可能被转动，必须持续回读，否则界面会一直显示进页面时的档位。
  ///
  /// 只轮询 `0x500E`（1 个事务）；模式变了再做一次整表刷新，
  /// 因为档位变了之后各参数的可写性与可选值都会变。
  void _startModePolling() {
    _modeTimer?.cancel();
    _modeTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) async {
      if (!_connected || !mounted) return;
      final changed = await widget.exposureController.refreshMode();
      if (!mounted) return;
      if (changed) {
        // 档位变了：可写性和档位表都会变，立刻整表刷新。
        await widget.exposureController.refresh(force: true);
      } else {
        // 否则按 3 秒窗口自动节流；变焦后光圈/快门档位表就是这样跟上来的。
        await widget.exposureController.refresh();
      }
    });
    _startMovieModePolling();
  }

  /// 机身拨杆随时可能被拨动，`0xD1A6` 必须持续回读，否则界面会一直停在进页面时的模式。
  void _startMovieModePolling() {
    _movieModeTimer?.cancel();
    _movieModeTimer =
        Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_connected || !mounted) return;
      // 启停与封盘期间不插队，避免和 0x920A/0x920B 抢同一个通道。
      if (widget.movieController.phase != MovieRecordingPhase.idle) return;
      await widget.movieController.refresh();
    });
  }

  void _stopModePolling() {
    _modeTimer?.cancel();
    _modeTimer = null;
    _movieModeTimer?.cancel();
    _movieModeTimer = null;
  }

  void _startOrientationPolling() {
    _orientationTimer?.cancel();
    // 机身朝向变化很慢，2 秒轮询一次足够。
    _orientationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshOrientation();
    });
  }

  void _stopOrientationPolling() {
    _orientationTimer?.cancel();
    _orientationTimer = null;
  }

  Future<void> _refreshOrientation() async {
    try {
      final data = await widget.driver
          .fetchDevicePropValue(PtpOpCodes.nikonPropCameraOrientation);
      if (data.isEmpty) return;
      final raw = data.length >= 4
          ? ByteData.sublistView(data).getUint32(0, Endian.little)
          : data[0];
      final degrees = CameraValueLabels.rotationDegrees(raw);
      if (mounted && degrees != _orientation) {
        setState(() => _orientation = degrees);
      }
    } catch (_) {
      // 部分固件没有这个属性；保持 0 度即可。
    }
  }

  // ---------------------------------------------------------------- 拍摄

  Future<void> _shoot() async {
    if (widget.captureController.isBusy) return;
    final l10n = context.l10n;
    await widget.manualFocusController.release();
    try {
      final outcome = await widget.captureController.capture();
      if (!mounted) return;
      switch (outcome) {
        case CaptureConfirmed(:final file):
          _toast(l10n.captureSuccess(file.fileName), tone: ZStatusTone.success);
        case CaptureUnconfirmed():
          await showZDialog<void>(
            context: context,
            builder: (ctx) => ZDialog(
              title: l10n.captureUnconfirmedTitle,
              message: l10n.captureUnconfirmedBody(
                  widget.captureController.confirmTimeout.inSeconds),
              confirmLabel: l10n.commonGotIt,
              onConfirm: () => Navigator.of(ctx).pop(),
            ),
          );
        case CaptureRejected(:final responseCode):
          _toast(_rejectMessage(l10n, responseCode), isError: true);
      }
    } catch (_) {
      if (mounted) _toast(l10n.captureFailed, isError: true);
    }
  }

  String _rejectMessage(AppLocalizations l10n, int responseCode) {
    return switch (responseCode) {
      0x2019 => l10n.captureRejectedBusy,
      0x200F => l10n.captureRejectedAccess,
      0x2005 || 0x2006 => l10n.captureRejectedUnsupported,
      _ => l10n.captureFailed,
    };
  }

  // ---------------------------------------------------------------- 对焦

  Future<void> _autoFocus() async {
    final l10n = context.l10n;
    if (!widget.driver.supportsAfDrive ||
        !AppSettings.instance.liveViewAfDrive) {
      return;
    }
    try {
      final code = await widget.liveViewController.autoFocus();
      if (!mounted) return;
      switch (code) {
        case 0x2001:
          _toast(l10n.captureAfDone, tone: ZStatusTone.success);
        case 0xA002:
          _toast(l10n.captureAfNotFocus, isError: true);
        case 0x2019:
          _toast(l10n.captureRejectedBusy);
        case 0x2005 || 0x2006:
          // 这台机器不提供 0x90C1/0x90C8：对焦点已经移动了，静默即可，
          // 不要报「无法移动对焦点」——那会让用户以为点按失败。
          break;
      }
    } on PtpException catch (e) {
      if (e.responseCode == 0x2005 || e.responseCode == 0x2006) return;
      if (mounted) _toast(l10n.captureAfFailed, isError: true);
    } catch (_) {
      if (mounted) _toast(l10n.captureAfFailed, isError: true);
    }
  }

  Future<void> _focusAt(Offset localPosition, Size viewSize) async {
    final frame = widget.liveViewController.frames.value;
    if (frame == null) return;

    final rect = fitContentRect(
      Size(frame.width.toDouble(), frame.height.toDouble()),
      viewSize,
    );
    if (rect.isEmpty) return;

    final nx = (localPosition.dx - rect.left) / rect.width;
    final ny = (localPosition.dy - rect.top) / rect.height;
    if (nx < 0 || nx > 1 || ny < 0 || ny > 1) return;

    final point = AfAreaMapper.fromNormalized(nx, ny);
    setState(() => _focusPoint = localPosition);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _focusPoint = null);
    });

    try {
      await widget.liveViewController.focusAt(point.x, point.y);
      if (AppSettings.instance.liveViewAfDrive) await _autoFocus();
    } catch (_) {
      if (mounted) _toast(context.l10n.captureAfFailed, isError: true);
    }
  }

  // ---------------------------------------------------------------- 参数

  Future<void> _applyParameter(CameraParameter parameter, int rawValue) async {
    final l10n = context.l10n;
    final binding = widget.exposureController.bindingOf(parameter);
    final outcome = await widget.exposureController.apply(parameter, rawValue);
    if (!mounted) return;
    switch (outcome) {
      case SettingsApplied(:final effectiveValue):
        _toast(
          l10n.captureSettingApplied(binding?.labelOf(effectiveValue) ?? ''),
          tone: ZStatusTone.success,
        );
      case SettingsRejected(:final reason, :final effectiveValue):
        switch (reason) {
          case SettingsRejectReason.dialNotInManual:
            _toast(l10n.captureSettingRejectedDial, isError: true);
          case SettingsRejectReason.readbackMismatch:
            final value = effectiveValue == null
                ? '--'
                : (binding?.labelOf(effectiveValue) ?? '--');
            _toast(l10n.captureSettingRejectedMismatch(value), isError: true);
          case SettingsRejectReason.busy:
            _toast(l10n.captureSettingRejectedBusy, isError: true);
          case SettingsRejectReason.notWritable:
            _toast(l10n.captureSettingRejectedNotWritable, isError: true);
          case SettingsRejectReason.unsupported:
            _toast(l10n.captureSettingRejectedUnsupported, isError: true);
          case SettingsRejectReason.unavailable:
            _toast(l10n.captureSettingRejectedUnavailable, isError: true);
          case SettingsRejectReason.deviceError:
            _toast(l10n.errGeneric, isError: true);
        }
    }
  }

  // ---------------------------------------------------------------- 间隔

  Future<void> _openIntervalSheet() async {
    final settings = AppSettings.instance;
    final config = await showIntervalConfigSheet(
      context,
      defaultSeconds: settings.intervalDefaultSeconds,
      defaultCount: settings.intervalDefaultCount,
    );
    if (config == null || !mounted) return;

    settings.updateLiveView(
      intervalSeconds: config.interval.inSeconds,
      intervalCount: config.shotCount == 0 ? 1 : config.shotCount,
    );
    await _runSequence(
      keepLiveView: config.keepLiveView,
      body: () => widget.intervalController.start(config),
    );
  }

  /// 序列拍摄的统一入口。
  ///
  /// 默认在序列期间**同时**关掉手机预览和相机的实时取景：每张照片本来就要
  /// 退出取景再拍，把取景留到最后只会让相机屏幕整段时间亮着耗电。
  /// 序列结束后，如果开始前预览是开着的，再帮用户拉回来。
  Future<void> _runSequence({
    required bool keepLiveView,
    required Future<void> Function() body,
  }) async {
    final live = widget.liveViewController;
    final wasActive = live.isActive;

    if (!keepLiveView) {
      live.setAutoRestartSuppressed(true);
      await live.forceClose();
      _toast(EngineL10n.liveViewClosedForSequence(L10n.current.localeName));
    }

    try {
      await body();
    } finally {
      live.setAutoRestartSuppressed(false);
      if (!keepLiveView) {
        // 序列结束后再兜一次：中途相机可能自己回到取景。
        await live.forceClose();
        if (wasActive && mounted) await live.start();
      }
    }
  }

  void _toast(String message, {bool isError = false, ZStatusTone? tone}) {
    if (!mounted) return;
    showZToast(context, message, isError: isError, tone: tone);
  }

  // ---------------------------------------------------------------- 序列工具

  /// 四类长时间任务共用相机的排他通道，同时跑会互相打断。
  bool get _sequenceBusy =>
      widget.intervalController.isActive ||
      widget.movieController.isRecording ||
      widget.bracketController.isActive ||
      widget.focusStackController.isActive;

  Future<void> _openBracketSheet() async {
    if (_sequenceBusy) {
      _toast(EngineL10n.taskBusyHint(L10n.current.localeName), isError: true);
      return;
    }
    final lang = L10n.current.localeName;

    final config = await showBracketConfigSheet(context);
    if (config == null || !mounted) return;

    var started = false;
    await _runSequence(
      keepLiveView: false,
      body: () async {
        started = await widget.bracketController.start(config);
      },
    );
    if (!mounted) return;
    if (!started) {
      if (widget.bracketController.state == BracketState.failed) {
        _toast(EngineL10n.bracketBuiltinConflict(lang), isError: true);
      } else {
        _toast(context.l10n.captureFailed, isError: true);
      }
      return;
    }
    if (widget.bracketController.restoreFailed) {
      _toast(EngineL10n.bracketRestoreWarning(lang), isError: true);
    } else {
      _toast(EngineL10n.bracketRestored(lang), tone: ZStatusTone.success);
    }
    await _offerComposite(
      mode: SequenceCompositeMode.exposureFusion,
      files: widget.bracketController.capturedFiles,
    );
  }

  Future<void> _openFocusStackSheet() async {
    if (_sequenceBusy) {
      _toast(EngineL10n.taskBusyHint(L10n.current.localeName), isError: true);
      return;
    }
    final config = await showFocusStackConfigSheet(context);
    if (config == null || !mounted) return;

    // 焦点堆叠必须保持实时取景：0x9204 MfDrive 只在取景状态下有效，
    // 所以这一项不能像间隔拍摄那样为了省电关掉预览。
    final live = widget.liveViewController;
    if (!live.isActive) {
      _autoStarted = true;
      _startLiveView();
      // 等第一帧落地再开始推对焦，否则第一条 MfDrive 会被相机拒绝。
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }

    final started = await widget.focusStackController.start(config);
    if (!mounted) return;
    if (!started) {
      _toast(context.l10n.captureFailed, isError: true);
      return;
    }
    await _offerComposite(
      mode: SequenceCompositeMode.focusStack,
      files: widget.focusStackController.capturedFiles,
    );
  }

  void _stopSequences() {
    widget.bracketController.stop();
    widget.focusStackController.stop();
  }

  // ---------------------------------------------------------------- 序列合成

  /// 序列拍完后询问是否在 App 内合成一张。
  ///
  /// 原片始终留在相机存储卡上，这里只是额外产出一张分享级的合成图；
  /// 用户不选就不做任何事。
  Future<void> _offerComposite({
    required SequenceCompositeMode mode,
    required List<CameraFileItem> files,
  }) async {
    if (files.length < 2 || !mounted) return;
    final lang = L10n.current.localeName;

    if (files.any((f) => f.isRaw)) {
      _toast(EngineL10n.compositeRawUnsupported(lang), isError: true);
      return;
    }

    final confirmed = await showZDialog<bool>(
      context: context,
      builder: (ctx) => ZDialog(
        title: EngineL10n.compositeOfferTitle(lang),
        message: EngineL10n.compositeOfferBody(lang, files.length),
        confirmLabel: EngineL10n.compositeConfirm(lang),
        cancelLabel: EngineL10n.compositeKeepOriginals(lang),
        onConfirm: () => Navigator.of(ctx).pop(true),
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _compositeAndSave(mode, files);
  }

  Future<void> _compositeAndSave(
    SequenceCompositeMode mode,
    List<CameraFileItem> files,
  ) async {
    final lang = L10n.current.localeName;
    _toast(EngineL10n.compositeWorking(lang));

    final frames = <img.Image>[];
    for (final file in files) {
      if (!mounted) return;
      final temp = await widget.downloadManager
          .downloadToTemp(file, suffix: '_seq');
      if (temp == null) continue;
      try {
        final image = await decodeScaledJpeg(
          await temp.readAsBytes(),
          maxEdge: SequenceCompositor.defaultMaxEdge,
        );
        if (image != null) frames.add(image);
      } finally {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }

    if (frames.length < 2) {
      if (mounted) _toast(EngineL10n.compositeFailed(lang), isError: true);
      return;
    }

    final result = SequenceCompositor.composeFrames(frames, mode: mode);
    if (!result.isSuccess) {
      if (mounted) _toast(EngineL10n.compositeFailed(lang), isError: true);
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}'
          '${now.second.toString().padLeft(2, '0')}';
      final name = 'SEQ_$stamp.jpg';
      final merged = File('${dir.path}/$name');
      await merged.writeAsBytes(result.bytes!, flush: true);

      final saved = await CameraNativeBridge.saveMediaToGallery(
        merged.path,
        name,
        subDir: AppSettings.instance.exportFolder,
      );
      try {
        await merged.delete();
      } catch (_) {}

      if (!mounted) return;
      if (saved == null || saved.isEmpty) {
        _toast(EngineL10n.compositeFailed(lang), isError: true);
      } else {
        _toast(EngineL10n.compositeSuccess(lang), tone: ZStatusTone.success);
      }
    } catch (_) {
      if (mounted) _toast(EngineL10n.compositeFailed(lang), isError: true);
    }
  }

  // ---------------------------------------------------------------- 机内 HDR

  Future<void> _openHdrSheet() async {
    if (_sequenceBusy) {
      _toast(EngineL10n.taskBusyHint(L10n.current.localeName), isError: true);
      return;
    }
    final lang = L10n.current.localeName;
    final dynamicEv = await _showHdrSheet(lang);
    if (dynamicEv == null || !mounted) return;

    var result = HdrResult.unsupported;
    await _runSequence(
      keepLiveView: false,
      body: () async {
        result = await widget.hdrController.shoot(highDynamic: dynamicEv);
      },
    );
    if (!mounted) return;
    switch (result) {
      case HdrResult.merged:
        _toast(EngineL10n.hdrSucceeded(lang), tone: ZStatusTone.success);
      case HdrResult.unsupported:
        _toast(EngineL10n.hdrUnsupported(lang), isError: true);
      case HdrResult.captureFailed:
        _toast(EngineL10n.hdrCaptureFailed(lang), isError: true);
    }
  }

  /// 选择 HDR 动态范围；返回 null 表示取消，0 表示自动。
  Future<int?> _showHdrSheet(String lang) {
    final zc = context.zc;
    final zt = context.zt;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: ZSwatch.transparent,
      builder: (ctx) => SafeArea(
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
              Text(EngineL10n.hdrTitle(lang),
                  style: zt.title.copyWith(color: zc.textPrimary)),
              const SizedBox(height: ZSpace.xs),
              Text(EngineL10n.hdrSubtitle(lang),
                  style: zt.caption.copyWith(color: zc.textSecondary)),
              const SizedBox(height: ZSpace.md),
              for (final ev in <int?>[null, 1, 2, 3])
                ZTile(
                  title: ev == null
                      ? EngineL10n.hdrEvAuto(lang)
                      : EngineL10n.hdrEv(ev),
                  leadingIcon: Icons.hdr_on_outlined,
                  isLink: true,
                  showDivider: ev != 3,
                  onTap: () => Navigator.of(ctx).pop(ev ?? 0),
                ),
              const SizedBox(height: ZSpace.xs),
              Text(EngineL10n.hdrKeepsOriginals(lang),
                  style: zt.caption.copyWith(color: zc.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickStorageFolder() async {
    final changed = await showStorageFolderSheet(context);
    if (!mounted || !changed) return;
    _toast(
      context.l10n.storageFolderPath(AppSettings.instance.exportFolder),
      tone: ZStatusTone.success,
    );
  }

  // ---------------------------------------------------------------- 视图

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;

    if (!_connected) {
      return Scaffold(
        backgroundColor: zc.bg,
        body: SafeArea(
          child: ZEmptyState(
            icon: Icons.camera_outlined,
            title: l10n.captureNotConnectedTitle,
            subtitle: l10n.captureNotConnectedBody,
            action: ZButton(
              label: l10n.captureGoConnect,
              icon: Icons.wifi_tethering,
              onTap: widget.onNavigateToConnect,
            ),
          ),
        ),
      );
    }

    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: zc.bg,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            widget.liveViewController,
            widget.exposureController,
            widget.captureController,
            widget.intervalController,
            widget.manualFocusController,
            widget.movieController,
            widget.bracketController,
            widget.focusStackController,
          ]),
          builder: (context, _) {
            return wide ? _buildWideLayout() : _buildPhoneLayout();
          },
        ),
      ),
    );
  }

  Widget _buildPhoneLayout() {
    return Column(
      children: <Widget>[
        _buildStatusBar(showClose: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZSpace.md),
            child: _buildViewfinder(),
          ),
        ),
        _buildPhoneDeck(),
      ],
    );
  }

  Widget _buildWideLayout() {
    final zc = context.zc;
    final width = MediaQuery.sizeOf(context).width;
    return Column(
      children: <Widget>[
        _buildStatusBar(showClose: false),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(ZSpace.md),
                  child: _buildViewfinder(),
                ),
              ),
              Container(
                width: (width * 0.34).clamp(300.0, 400.0),
                decoration: BoxDecoration(
                  color: zc.surface,
                  border: Border(
                    left: BorderSide(color: zc.outline, width: 0.8),
                  ),
                ),
                child: _buildTabletPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar({required bool showClose}) {
    final zc = context.zc;
    final zt = context.zt;
    final l10n = context.l10n;
    final isUsb = widget.driver.transportKind == CameraTransportKind.usb;
    final controller = widget.liveViewController;

    final stateLabel = switch (controller.state) {
      LiveViewState.running => l10n.captureLiveViewRunning,
      LiveViewState.starting => l10n.captureLiveViewStarting,
      LiveViewState.suspended => l10n.captureLiveViewSuspended,
      _ => l10n.captureLiveViewIdle,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ZSpace.md,
        vertical: ZSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          if (showClose)
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.xs),
              child: ZIconButton(
                icon: Icons.close,
                tooltip: l10n.captureClose,
                onTap: widget.onNavigateToConnect,
              ),
            ),
          Expanded(
            child: Text(
              widget.driver.cameraModel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: zt.label.copyWith(color: zc.textPrimary),
            ),
          ),
          if (controller.isRunning && AppSettings.instance.liveViewShowFps)
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.sm),
              child: Text(
                l10n.captureFps(controller.fps.toStringAsFixed(0)),
                style: zt.caption.copyWith(color: zc.textSecondary),
              ),
            ),
          if (_currentMode != null)
            Padding(
              padding: const EdgeInsets.only(right: ZSpace.sm),
              child: ZTag(
                text: modeLabel(_currentMode),
                compact: true,
                color: zc.accent,
              ),
            ),
          ZIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: l10n.storageFolderPath(AppSettings.instance.exportFolder),
            size: 32,
            iconSize: 18,
            onTap: _pickStorageFolder,
          ),
          const SizedBox(width: ZSpace.xs),
          ZTag(
            text: isUsb ? l10n.captureChannelUsb : l10n.captureChannelWifi,
            compact: true,
          ),
          const SizedBox(width: ZSpace.sm),
          ZTag(
            text: stateLabel,
            compact: true,
            color: controller.state == LiveViewState.failed
                ? zc.danger
                : zc.accent,
            isOutline: controller.state != LiveViewState.running,
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    final zc = context.zc;
    final liveView = widget.liveViewController;
    final analysis = liveView.analysis;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _focusAt(details.localPosition, size),
          child: ClipRRect(
            borderRadius: ZRadius.brMd,
            child: Container(
              color: ZSwatch.pureBlack,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _FramePainter(frames: liveView.frames),
                    ),
                  ),
                  if (analysis != null)
                    RepaintBoundary(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: LiveViewAnalysisPainter(
                            frames: liveView.frames,
                            overlay: analysis.overlay,
                          ),
                        ),
                      ),
                    ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: LiveViewGridPainter(
                        frames: liveView.frames,
                        mode: AppSettings.instance.liveViewGridMode,
                        quarterTurns: _orientation ~/ 90,
                        guides: AppSettings.instance.liveViewGuideLines,
                      ),
                    ),
                  ),
                  if (_focusPoint != null)
                    Positioned(
                      left: _focusPoint!.dx - 22,
                      top: _focusPoint!.dy - 22,
                      child: IgnorePointer(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.all(color: zc.accent, width: 2),
                            borderRadius: ZRadius.brSm,
                          ),
                        ),
                      ),
                    ),
                  if (widget.movieController.isRecording)
                    Positioned(
                      top: ZSpace.sm,
                      left: ZSpace.sm,
                      child: IgnorePointer(
                        child: CaptureRecordingBadge(
                          label: EngineL10n.movieRecording(
                              L10n.current.localeName),
                          elapsed: widget.movieController.elapsedLabel,
                          leftLevel: liveView.audioPeakLeft,
                          rightLevel: liveView.audioPeakRight,
                          finalizingLabel:
                              widget.movieController.phase ==
                                      MovieRecordingPhase.finalizing
                                  ? EngineL10n.movieFinalizingHint(
                                      L10n.current.localeName)
                                  : null,
                        ),
                      ),
                    ),
                  if (analysis != null &&
                      AppSettings.instance.liveViewHistogram)
                    Positioned(
                      top: ZSpace.sm,
                      right: ZSpace.sm,
                      child: IgnorePointer(
                        child: SizedBox(
                          width: 96,
                          height: 56,
                          child: CustomPaint(
                            painter: LiveViewHistogramPainter(
                              histogram: analysis.histogram,
                              zebraThreshold:
                                  AppSettings.instance.liveViewZebraThreshold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ValueListenableBuilder<LiveViewFrame?>(
                        valueListenable: liveView.frames,
                        builder: (context, frame, _) {
                          if (frame != null) return const SizedBox.shrink();
                          return _ViewfinderPlaceholder(controller: liveView);
                        },
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

  // ---------------------------------------------------------------- 手机控制区

  Widget _buildPhoneDeck() {
    final zc = context.zc;
    final l10n = context.l10n;
    final interval = widget.intervalController;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        ZSpace.md,
        ZSpace.sm,
        ZSpace.md,
        ZSpace.sm,
      ),
      decoration: BoxDecoration(
        color: zc.surface,
        border: Border(top: BorderSide(color: zc.outline, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!widget.driver.isVerifiedBody)
            Padding(
              padding: const EdgeInsets.only(bottom: ZSpace.xs),
              child: Text(
                l10n.captureUnverifiedBody,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.zt.caption.copyWith(color: zc.textSecondary),
              ),
            ),
          _buildModeRow(),
          if (widget.bracketController.isActive ||
              widget.focusStackController.isActive)
            _buildSequenceProgress(),
          if (interval.isActive)
            _intervalBar(interval, l10n)
          else ...<Widget>[
            _buildParameterChips(),
            AnimatedSize(
              duration: ZMotion.short,
              child: _expandedParameter == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: ZSpace.xs),
                      child: CaptureExposureSlider(
                        parameter: _expandedParameter!,
                        label: _parameterLabel(l10n, _expandedParameter!),
                        binding: widget.exposureController
                            .bindingOf(_expandedParameter!),
                        onApply: (value) =>
                            _applyParameter(_expandedParameter!, value),
                      ),
                    ),
            ),
          ],
          const SizedBox(height: ZSpace.sm),
          _buildFocusControls(compact: true),
        ],
      ),
    );
  }

  bool get _videoMode =>
      widget.movieController.mode == CameraCaptureMode.video;

  Widget _buildSequenceProgress() {
    final zc = context.zc;
    final zt = context.zt;
    final lang = L10n.current.localeName;
    final bracket = widget.bracketController;
    final focus = widget.focusStackController;
    final isBracket = bracket.isActive;
    final current = isBracket ? bracket.currentShot : focus.currentShot;
    final total = isBracket ? bracket.totalShots : focus.totalShots;

    return Row(
      children: <Widget>[
        Icon(
          isBracket ? Icons.exposure_outlined : Icons.blur_circular_outlined,
          size: 18,
          color: zc.accent,
        ),
        const SizedBox(width: ZSpace.sm),
        Expanded(
          child: Text(
            '${isBracket ? EngineL10n.bracketTitle(lang) : EngineL10n.focusStackTitle(lang)}'
            ' · ${EngineL10n.bracketRunning(current, total)}',
            style: zt.body.copyWith(color: zc.textPrimary),
          ),
        ),
        TextButton(
          onPressed: _stopSequences,
          child: Text(context.l10n.captureIntervalStop),
        ),
      ],
    );
  }

  Widget _buildModeRow() {
    final l10n = L10n.current.localeName;
    final busy = widget.intervalController.isActive ||
        widget.captureController.isBusy ||
        widget.movieController.phase != MovieRecordingPhase.idle;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CaptureModePill(
            videoMode: _videoMode,
            enabled: widget.driver.supportsRemoteCapture && !busy,
            photoLabel: EngineL10n.capturePhotoMode(l10n),
            videoLabel: EngineL10n.captureVideoMode(l10n),
            onChanged: _toggleMovieMode,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleMovieMode(bool toVideo) async {
    if (_videoMode == toVideo) return;
    final lang = L10n.current.localeName;
    final ok = await widget.movieController.switchMode(
      toVideo ? CameraCaptureMode.video : CameraCaptureMode.photo,
    );
    if (!mounted) return;
    if (!ok) {
      // Z 30 的实体拨杆决定模式，App 写不进去。提示要指向正确的那一档。
      _toast(
        toVideo
            ? EngineL10n.movieNeedPhysicalLever(lang)
            : EngineL10n.movieNeedPhysicalLeverToPhoto(lang),
        isError: true,
      );
      return;
    }
    if (toVideo) await widget.movieController.refresh();
  }

  Future<void> _toggleRecording() async {
    final movie = widget.movieController;
    final lang = L10n.current.localeName;

    if (movie.phase == MovieRecordingPhase.recording) {
      await movie.stopRecording();
      return;
    }
    if (movie.phase != MovieRecordingPhase.idle) return;

    final ok = await movie.startRecording();
    if (!mounted) return;
    if (ok) return;

    final prohibition = movie.prohibition;
    if (prohibition.needsPhysicalLever ||
        movie.mode == CameraCaptureMode.lockedByPhysicalLever) {
      _toast(EngineL10n.movieNeedPhysicalLever(lang), isError: true);
    } else if (prohibition.isBlocked) {
      final bit = prohibition.reasons.first;
      _toast(EngineL10n.movieProhibitionReason(lang, bit), isError: true);
    } else {
      _toast(context.l10n.captureFailed, isError: true);
    }
  }

  Widget _intervalBar(
      IntervalShootingController interval, AppLocalizations l10n) {
    final config = interval.config;
    return CaptureIntervalBar(
      progressText: config == null || config.shotCount == 0
          ? l10n.captureIntervalProgressUnlimited(interval.shotsAttempted)
          : l10n.captureIntervalProgress(
              interval.shotsAttempted, config.shotCount),
      nextText: interval.state == IntervalShootingState.waiting
          ? l10n.captureIntervalNextIn(_formatRemaining(interval.remaining))
          : null,
      paused: interval.state == IntervalShootingState.paused,
      onPauseResume: interval.state == IntervalShootingState.paused
          ? interval.resume
          : interval.pause,
      onStop: interval.stop,
      pauseLabel: l10n.captureIntervalPause,
      resumeLabel: l10n.captureIntervalResume,
      stopLabel: l10n.captureIntervalStop,
    );
  }

  Widget _buildParameterChips() {
    final l10n = context.l10n;

    return SizedBox(
      height: 34,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final parameter in CameraParameter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: ZSpace.sm),
                    child: _ParameterChipButton(
                      label: _parameterLabel(l10n, parameter),
                      value: _parameterValue(parameter),
                      locked: !isEditable(parameter, _currentMode),
                      selected: _expandedParameter == parameter,
                      onTap: parameter == CameraParameter.mode
                          ? null
                          : () {
                              setState(() {
                                _expandedParameter =
                                    _expandedParameter == parameter
                                        ? null
                                        : parameter;
                              });
                            },
                    ),
                  ),
              ],
            ),
          ),
          ZIconButton(
            icon: Icons.tune,
            tooltip: l10n.captureParamsTitle,
            onTap: _openOverlaySheet,
          ),
        ],
      ),
    );
  }

  Widget _buildFocusControls({required bool compact}) {
    final l10n = context.l10n;
    final manual = widget.manualFocusController;
    final liveView = widget.liveViewController;
    final movie = widget.movieController;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        ZIconButton(
          icon: liveView.isActive
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          tooltip: liveView.isActive
              ? l10n.captureLiveViewRunning
              : l10n.captureLiveViewIdle,
          onTap: _toggleLiveView,
        ),
        CaptureHoldButton(
          icon: Icons.arrow_back,
          semanticLabel: l10n.captureFocusNear,
          enabled: manual.canDrive && !_videoMode,
          onPress: () => manual.press(MfDirection.near),
          onRelease: manual.release,
        ),
        if (_videoMode)
          CaptureRecordButton(
            label: movie.isRecording
                ? EngineL10n.movieRecording(L10n.current.localeName)
                : EngineL10n.captureVideoMode(L10n.current.localeName),
            recording: movie.phase == MovieRecordingPhase.recording,
            busy: movie.phase == MovieRecordingPhase.starting ||
                movie.phase == MovieRecordingPhase.stopping ||
                movie.phase == MovieRecordingPhase.finalizing,
            onTap: _toggleRecording,
            size: compact ? 68 : 72,
          )
        else
          CaptureShutterButton(
            label: l10n.captureShutter,
            busy: widget.captureController.isBusy,
            onTap: _shoot,
            size: compact ? 68 : 72,
          ),
        CaptureHoldButton(
          icon: Icons.arrow_forward,
          semanticLabel: l10n.captureFocusFar,
          enabled: manual.canDrive && !_videoMode,
          onPress: () => manual.press(MfDirection.far),
          onRelease: manual.release,
        ),
        ZIconButton(
          icon: Icons.center_focus_strong,
          tooltip: l10n.captureFocus,
          onTap: _autoFocus,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- 平板侧栏

  Widget _buildTabletPanel() {
    final l10n = context.l10n;
    final zc = context.zc;
    final interval = widget.intervalController;
    final lockedHint = _lockedHint(l10n);

    return ListView(
      padding: const EdgeInsets.all(ZSpace.md),
      children: <Widget>[
        if (!widget.driver.isVerifiedBody)
          Padding(
            padding: const EdgeInsets.only(bottom: ZSpace.sm),
            child: Text(
              l10n.captureUnverifiedBody,
              style: context.zt.caption.copyWith(color: zc.textSecondary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: ZSpace.sm),
          child: Row(
            children: <Widget>[
              CaptureModePill(
                videoMode: _videoMode,
                enabled: widget.driver.supportsRemoteCapture &&
                    widget.movieController.phase == MovieRecordingPhase.idle &&
                    !widget.intervalController.isActive,
                photoLabel: EngineL10n.capturePhotoMode(L10n.current.localeName),
                videoLabel: EngineL10n.captureVideoMode(L10n.current.localeName),
                onChanged: _toggleMovieMode,
              ),
            ],
          ),
        ),
        ZSection(
          title: l10n.captureParamsTitle,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZSpace.md),
              child: Column(
                children: <Widget>[
                  for (final parameter in CameraParameter.values)
                    CaptureExposureSlider(
                      parameter: parameter,
                      label: _parameterLabel(l10n, parameter),
                      binding: widget.exposureController.bindingOf(parameter),
                      onApply: (value) => _applyParameter(parameter, value),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (lockedHint != null)
          Padding(
            padding: const EdgeInsets.only(top: ZSpace.sm, left: ZSpace.md),
            child: Text(
              lockedHint,
              style: context.zt.caption.copyWith(color: zc.warning),
            ),
          ),
        const SizedBox(height: ZSpace.md),
        _buildOverlayToggles(),
        const SizedBox(height: ZSpace.md),
        ZSection(
          title: l10n.captureIntervalTitle,
          children: <Widget>[
            if (interval.isActive)
              Padding(
                padding: const EdgeInsets.all(ZSpace.sm),
                child: _intervalBar(interval, l10n),
              )
            else
              ZTile(
                title: l10n.captureIntervalStart,
                subtitle: l10n.captureIntervalSeconds(
                    AppSettings.instance.intervalDefaultSeconds),
                leadingIcon: Icons.timer_outlined,
                isLink: true,
                onTap: _openIntervalSheet,
              ),
          ],
        ),
        const SizedBox(height: ZSpace.md),
        ZSection(
          title: EngineL10n.bracketTitle(L10n.current.localeName),
          children: <Widget>[
            if (widget.bracketController.isActive ||
                widget.focusStackController.isActive)
              Padding(
                padding: const EdgeInsets.all(ZSpace.sm),
                child: _buildSequenceProgress(),
              )
            else ...<Widget>[
              ZTile(
                title: EngineL10n.hdrTitle(L10n.current.localeName),
                subtitle: EngineL10n.hdrSubtitle(L10n.current.localeName),
                leadingIcon: Icons.hdr_on_outlined,
                isLink: true,
                onTap: _sequenceBusy ? null : _openHdrSheet,
              ),
              ZTile(
                title: EngineL10n.bracketTitle(L10n.current.localeName),
                subtitle: EngineL10n.bracketSubtitle(L10n.current.localeName),
                leadingIcon: Icons.exposure_outlined,
                isLink: true,
                onTap: _sequenceBusy ? null : _openBracketSheet,
              ),
              ZTile(
                title: EngineL10n.focusStackTitle(L10n.current.localeName),
                subtitle: EngineL10n.focusStackSubtitle(L10n.current.localeName),
                leadingIcon: Icons.blur_circular_outlined,
                isLink: true,
                onTap: _sequenceBusy ? null : _openFocusStackSheet,
              ),
            ],
          ],
        ),
        const SizedBox(height: ZSpace.lg),
        Center(child: _buildFocusControls(compact: false)),
        const SizedBox(height: ZSpace.md),
      ],
    );
  }

  Widget _buildOverlayToggles() {
    final l10n = context.l10n;
    final settings = AppSettings.instance;

    return Wrap(
      spacing: ZSpace.sm,
      runSpacing: ZSpace.sm,
      children: <Widget>[
        _OverlayToggle(
          icon: Icons.grid_on,
          label: switch (settings.liveViewGridMode) {
            0 => l10n.captureGridOff,
            1 => l10n.captureGridThirds,
            _ => l10n.captureGridNine,
          },
          active: settings.liveViewGridMode != 0,
          onTap: () => settings.updateLiveView(
            gridMode: (settings.liveViewGridMode + 1) % 3,
          ),
        ),
        _OverlayToggle(
          icon: Icons.straighten,
          label: l10n.captureGuideLines,
          active: settings.liveViewGuideLines,
          onTap: () => settings.updateLiveView(
            guideLines: !settings.liveViewGuideLines,
          ),
        ),
        _OverlayToggle(
          icon: Icons.blur_on,
          label: l10n.captureOverlayPeaking,
          active: settings.liveViewFocusPeaking,
          onTap: () => settings.updateLiveView(
            focusPeaking: !settings.liveViewFocusPeaking,
          ),
        ),
        _OverlayToggle(
          icon: Icons.gradient,
          label: l10n.captureOverlayZebra,
          active: settings.liveViewZebra,
          onTap: () => settings.updateLiveView(zebra: !settings.liveViewZebra),
        ),
        _OverlayToggle(
          icon: Icons.bar_chart,
          label: l10n.captureOverlayHistogram,
          active: settings.liveViewHistogram,
          onTap: () => settings.updateLiveView(
            histogram: !settings.liveViewHistogram,
          ),
        ),
      ],
    );
  }

  Future<void> _openOverlaySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZSwatch.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(ZSpace.md),
          padding: const EdgeInsets.all(ZSpace.lg),
          decoration: BoxDecoration(
            color: context.zc.surface,
            borderRadius: ZRadius.brLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildOverlayToggles(),
              const SizedBox(height: ZSpace.md),
              ZTile(
                title: context.l10n.captureIntervalTitle,
                leadingIcon: Icons.timer_outlined,
                isLink: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openIntervalSheet();
                },
              ),
              ZTile(
                title: EngineL10n.hdrTitle(L10n.current.localeName),
                leadingIcon: Icons.hdr_on_outlined,
                isLink: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openHdrSheet();
                },
              ),
              ZTile(
                title: EngineL10n.bracketTitle(L10n.current.localeName),
                leadingIcon: Icons.exposure_outlined,
                isLink: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openBracketSheet();
                },
              ),
              ZTile(
                title: EngineL10n.focusStackTitle(L10n.current.localeName),
                leadingIcon: Icons.blur_circular_outlined,
                isLink: true,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openFocusStackSheet();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 辅助

  int? get _currentMode =>
      widget.exposureController.bindingOf(CameraParameter.mode)?.currentValue;

  String _parameterValue(CameraParameter parameter) {
    final binding = widget.exposureController.bindingOf(parameter);
    if (binding == null) return '--';
    return binding.labelOf(binding.currentValue);
  }

  String _parameterLabel(AppLocalizations l10n, CameraParameter parameter) {
    return switch (parameter) {
      CameraParameter.mode => l10n.captureExposureMode,
      CameraParameter.aperture => l10n.captureAperture,
      CameraParameter.shutter => l10n.captureShutterSpeed,
      CameraParameter.iso => l10n.captureIso,
      CameraParameter.exposureCompensation => l10n.captureExposureComp,
    };
  }

  /// 哪些参数当前写不了，直接看相机给的 `writable`，不再按档位表猜。
  String? _lockedHint(AppLocalizations l10n) {
    final locked = <CameraParameter>[];
    for (final parameter in CameraParameter.values) {
      if (parameter == CameraParameter.mode) continue;
      final binding = widget.exposureController.bindingOf(parameter);
      if (binding != null && !binding.writable) locked.add(parameter);
    }
    if (locked.isEmpty) return null;

    final names = locked.map((p) => _parameterLabel(l10n, p)).join(' / ');
    final mode = _currentMode;
    final label = modeLabel(mode);
    // 机身在切换中途会回报未识别的档位码，此时不要拼出「— 档：…」这种句子。
    if (mode == null || label == CameraValueLabels.unknown) {
      return l10n.captureSettingRejectedNotWritable;
    }
    return l10n.captureModeLockedHint(label, names);
  }

  String _formatRemaining(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }
}

/// 取景帧绘制。
class _FramePainter extends CustomPainter {
  _FramePainter({required this.frames}) : super(repaint: frames);

  final ValueListenable<LiveViewFrame?> frames;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = frames.value;
    if (frame == null) return;
    final src = Rect.fromLTWH(
        0, 0, frame.width.toDouble(), frame.height.toDouble());
    canvas.drawImageRect(
      frame.image,
      src,
      fitContentRect(src.size, size),
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) =>
      oldDelegate.frames != frames;
}

class _ViewfinderPlaceholder extends StatelessWidget {
  const _ViewfinderPlaceholder({required this.controller});

  final LiveViewController controller;

  @override
  Widget build(BuildContext context) {
    final zt = context.zt;
    final l10n = context.l10n;

    final message = switch (controller.state) {
      LiveViewState.failed =>
        controller.failure == LiveViewFailure.unsupported
            ? l10n.captureLiveViewUnsupported
            : l10n.captureLiveViewLost,
      LiveViewState.starting => l10n.captureLiveViewStarting,
      LiveViewState.suspended => l10n.captureLiveViewSuspended,
      _ => l10n.captureLiveViewIdle,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZSpace.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: zt.body.copyWith(color: ZSwatch.white70),
        ),
      ),
    );
  }
}

class _ParameterChipButton extends StatelessWidget {
  const _ParameterChipButton({
    required this.label,
    required this.value,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool locked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: Material(
        color: ZSwatch.transparent,
        child: InkWell(
          borderRadius: ZRadius.brSm,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ZSpace.sm,
              vertical: ZSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: selected ? zc.accentContainer : zc.surfaceHigh,
              borderRadius: ZRadius.brSm,
              border: Border.all(
                color: selected ? zc.accent : zc.outline,
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: zt.caption.copyWith(color: zc.textSecondary),
                ),
                const SizedBox(width: ZSpace.xs),
                Text(
                  value,
                  style: zt.label.copyWith(color: zc.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayToggle extends StatelessWidget {
  const _OverlayToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;

    return Material(
      color: ZSwatch.transparent,
      child: InkWell(
        borderRadius: ZRadius.brPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpace.sm,
            vertical: ZSpace.xs,
          ),
          decoration: BoxDecoration(
            color: active ? zc.accentContainer : zc.surfaceHigh,
            borderRadius: ZRadius.brPill,
            border: Border.all(
              color: active ? zc.accent : zc.outline,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: active ? zc.accent : zc.textSecondary,
              ),
              const SizedBox(width: ZSpace.xs),
              Text(
                label,
                style: zt.caption.copyWith(
                  color: active ? zc.accent : zc.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
