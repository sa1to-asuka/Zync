import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../engine/editor/pro_photo_models.dart';
import '../../engine/filter/photo_filter.dart';
import '../../engine/video/video_editor_bridge.dart';
import '../../engine/video/video_project.dart';
import '../../engine/video/video_project_store.dart';
import '../../engine/video/video_scopes.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/color_preset_sheet.dart';
import '../widgets/video_frame_strip.dart';
import '../widgets/video_scope_view.dart';
import '../widgets/video_timeline.dart';

class VideoEditorScreen extends StatefulWidget {
  final String path;
  final String fileName;

  const VideoEditorScreen({
    super.key,
    required this.path,
    required this.fileName,
  });

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _player;
  VideoPlayerController? _basePlayer;
  VideoPlayerController? _gradedPlayer;
  VideoAssetInfo? _asset;
  VideoProject? _project;
  VideoCapabilities? _capabilities;
  bool _loading = true;
  bool _exporting = false;
  bool _buildingGradedPreview = false;
  bool _showingGradedPreview = false;
  String? _gradedPlayerPath;
  StreamSubscription<double>? _progressSubscription;
  final List<VideoProject> _undoStack = [];
  final List<VideoProject> _redoStack = [];
  VideoProject? _gestureSnapshot;
  Completer<void>? _proxySkipCompleter;
  Timer? _saveDebounce;
  VideoFrameStrip? _frameStrip;
  bool _frameStripLoading = false;
  ColorGrade? _gradeClipboard;
  bool _gradedPreviewStale = false;
  bool _fullscreenPreview = false;
  VideoScopeData? _scopeData;
  bool _scopeLoading = false;
  double _exportProgress = 0;
  String? _error;
  int _tab = 0;
  bool _editingGlobalGrade = false;
  String _keyframeParameter = 'exposure';
  int _selectedClip = 0;
  final TextEditingController _lutController = TextEditingController();
  String _lutDraft = '';
  String? _lutClipId;

  @override
  void initState() {
    super.initState();
    _progressSubscription = VideoEditorBridge.progressStream.listen((value) {
      if (mounted) setState(() => _exportProgress = value);
    });
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final info = await VideoEditorBridge.importAsset(widget.path);
      final caps = await VideoEditorBridge.capabilities();
      if (!mounted) return;
      if (info == null) {
        setState(() {
          _loading = false;
          _error = context.l10n.videoReadMetaFailed;
        });
        return;
      }
      final saved = await VideoProjectStore.load(widget.path);
      final savedUsable = saved != null &&
          saved.clips.isNotEmpty &&
          saved.clips.every((clip) => File(clip.path).existsSync());
      final project = savedUsable
          ? saved
          : VideoProject(
              id: 'video_${DateTime.now().millisecondsSinceEpoch}',
              name: widget.fileName,
              createdAtMs: DateTime.now().millisecondsSinceEpoch,
              modifiedAtMs: DateTime.now().millisecondsSinceEpoch,
              exportSpec: caps.hardwareEncodeHevc
                  ? const VideoExportSpec()
                  : const VideoExportSpec(codec: VideoCodec.h264),
              clips: [
                VideoClip(
                  id: 'clip_0',
                  assetId: info.id,
                  path: info.path,
                  sourceInUs: 0,
                  sourceOutUs: info.durationUs,
                  assetDurationUs: info.durationUs,
                ),
              ],
            );
      _proxySkipCompleter = Completer<void>();
      final proxyFuture = VideoEditorBridge.createProxy(
        widget.path,
        targetHeight: info.height >= 2160 ? 1080 : 720,
      );
      final proxy = await Future.any<VideoProxyResult?>([
        proxyFuture,
        _proxySkipCompleter!.future.then((_) => null),
      ]);
      _proxySkipCompleter = null;
      final playbackPath =
          proxy?.path.isNotEmpty == true ? proxy!.path : widget.path;
      final player = VideoPlayerController.file(File(playbackPath));
      await player.initialize();
      await player.setLooping(true);
      if (!mounted) {
        player.dispose();
        return;
      }
      setState(() {
        _asset = info;
        _project = project;
        _capabilities = caps;
        _player = player;
        _basePlayer = player;
        _loading = false;
      });
      unawaited(VideoProjectStore.save(widget.path, project));
      unawaited(_loadFrameStrip());
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    final project = _project;
    if (project != null) {
      unawaited(VideoProjectStore.save(widget.path, project));
      unawaited(_loadFrameStrip());
    }
    _basePlayer?.dispose();
    if (!identical(_gradedPlayer, _basePlayer)) {
      _gradedPlayer?.dispose();
    }
    _progressSubscription?.cancel();
    VideoEditorBridge.cancel();
    _lutController.dispose();
    super.dispose();
  }

  VideoClip? get _clip {
    final project = _project;
    if (project == null || project.clips.isEmpty) return null;
    final index = _selectedClip.clamp(0, project.clips.length - 1);
    return project.clips[index];
  }

  ColorGrade get _currentGrade {
    final project = _project;
    final clip = _clip;
    if (_editingGlobalGrade) return project?.globalGrade ?? const ColorGrade();
    return clip?.grade ?? const ColorGrade();
  }

  void _updateCurrentGrade(ColorGrade grade) {
    final project = _project;
    if (project == null) return;
    if (_editingGlobalGrade) {
      _updateProject(project.copyWith(globalGrade: grade));
      return;
    }
    final clip = _clip;
    if (clip == null) return;
    _updateClip(clip.copyWith(grade: grade));
  }

  void _pushUndo(VideoProject? snapshot) {
    if (snapshot == null) return;
    _undoStack.add(snapshot);
    if (_undoStack.length > 30) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _snapshotProject() {
    final project = _project;
    if (project != null) _pushUndo(project);
  }

  void _beginSliderGesture() {
    _gestureSnapshot ??= _project;
  }

  void _endSliderGesture() {
    final snapshot = _gestureSnapshot;
    _gestureSnapshot = null;
    _pushUndo(snapshot);
  }

  void _undo() {
    final current = _project;
    if (current == null || _undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    setState(() => _project = previous);
  }

  void _redo() {
    final current = _project;
    if (current == null || _redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    setState(() => _project = next);
  }

  void _updateProject(VideoProject next, {bool affectsPreview = true}) {
    setState(() {
      _project =
          next.copyWith(modifiedAtMs: DateTime.now().millisecondsSinceEpoch);
      if (affectsPreview && _gradedPlayer != null) {
        _gradedPreviewStale = true;
      }
    });
    final project = _project;
    if (project != null) _scheduleProjectSave(project);
  }

  void _scheduleProjectSave(VideoProject project) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(VideoProjectStore.save(widget.path, project));
      unawaited(_loadFrameStrip());
    });
  }

  void _updateClip(VideoClip next) {
    final project = _project;
    if (project == null) return;
    final clips = [...project.clips];
    final index = clips.indexWhere((e) => e.id == next.id);
    if (index < 0) return;
    clips[index] = next;
    _updateProject(project.copyWith(clips: clips).normalizeTimeline());
  }

  Future<void> _loadFrameStrip({bool force = false}) async {
    final asset = _asset;
    final project = _project;
    if (asset == null || project == null) return;
    if (_frameStripLoading && !force) return;
    if (project.durationUs <= 0) return;
    if (force) {
      VideoFrameStrip.clearCache();
    }
    setState(() => _frameStripLoading = true);
    try {
      final strip = await VideoFrameStrip.load(
        asset.path,
        fromUs: 0,
        toUs: project.durationUs,
      );
      if (!mounted) return;
      setState(() {
        _frameStrip = (strip != null && strip.isEmpty) ? null : strip;
        _frameStripLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _frameStrip = null;
        _frameStripLoading = false;
      });
    }
  }

  Future<void> _addClip() async {
    if (_loading || _exporting || _buildingGradedPreview) return;
    final path = await CameraNativeBridge.pickFile();
    if (path == null || path.isEmpty) return;
    final info = await VideoEditorBridge.importAsset(path);
    if (!mounted) return;
    if (info == null || info.durationUs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.videoUnsupportedCodec)),
      );
      return;
    }
    final project = _project;
    if (project == null) return;
    final clip = VideoClip(
      id: 'clip_${DateTime.now().microsecondsSinceEpoch}',
      assetId: info.id,
      path: info.path,
      sourceInUs: 0,
      sourceOutUs: info.durationUs,
      assetDurationUs: info.durationUs,
    );
    _snapshotProject();
    final next =
        project.copyWith(clips: [...project.clips, clip]).normalizeTimeline();
    _updateProject(next);
    setState(() => _selectedClip = next.clips.length - 1);
    unawaited(_loadFrameStrip(force: true));
  }

  void _moveClip(int delta) {
    final project = _project;
    if (project == null || project.clips.length < 2) return;
    final from = _selectedClip.clamp(0, project.clips.length - 1);
    final to = from + delta;
    if (to < 0 || to >= project.clips.length) return;
    _snapshotProject();
    final next = project.reorderClips(from, to);
    _updateProject(next);
    setState(() => _selectedClip = to);
    unawaited(_loadFrameStrip(force: true));
  }

  Future<void> _buildGradedPreview() async {
    final project = _project;
    if (project == null || _buildingGradedPreview) return;
    final l10n = context.l10n;
    _basePlayer?.pause();
    setState(() => _buildingGradedPreview = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(l10n.videoGeneratingProxyToast)),
          ],
        ),
      ),
    );
    final result =
        await VideoEditorBridge.renderPreview(project, clipId: _clip?.id);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (!mounted) return;
    if (result == null || result.path.isEmpty) {
      setState(() => _buildingGradedPreview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoProxyFailedToast)),
      );
      return;
    }
    final graded = VideoPlayerController.file(File(result.path));
    await graded.initialize();
    await graded.setLooping(true);
    if (!mounted) {
      graded.dispose();
      return;
    }
    setState(() {
      _gradedPlayer?.dispose();
      _gradedPlayer = graded;
      _gradedPlayerPath = result.path;
      _player = graded;
      _showingGradedPreview = true;
      _gradedPreviewStale = false;
      _buildingGradedPreview = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.videoProxyReadyToast)),
    );
  }

  void _toggleGradedPreview() {
    final graded = _gradedPlayer;
    final base = _basePlayer;
    if (graded == null || base == null) return;
    final nextShowingGraded = !_showingGradedPreview;
    final current = _player;
    final position = current?.value.position;
    current?.pause();
    final next = nextShowingGraded ? graded : base;
    if (position != null) next.seekTo(position);
    next.play();
    setState(() {
      _showingGradedPreview = nextShowingGraded;
      _player = next;
    });
  }

  Future<void> _export() async {
    final project = _project;
    if (project == null || project.clips.isEmpty) return;
    final l10n = context.l10n;
    setState(() {
      _exporting = true;
      _exportProgress = 0;
    });
    final result = await VideoEditorBridge.export(project);
    if (!mounted) return;
    if (result == null) {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.videoExportFailedToast)),
      );
      return;
    }
    final name = 'Zync_${DateTime.now().millisecondsSinceEpoch}.mp4';
    unawaited(VideoProjectStore.save(widget.path, project));
    final uri = await CameraNativeBridge.saveMediaToGallery(result.path, name);
    if (!mounted) return;
    setState(() => _exporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          uri == null || uri.isEmpty
              ? l10n.videoExportSaveAlbumFailedToast
              : l10n.videoExportSuccessToast,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    if (_fullscreenPreview) return _buildFullscreenPreview();
    return Scaffold(
      backgroundColor: zc.bg,
      appBar: AppBar(
        backgroundColor: zc.surface,
        title:
            Text(widget.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.commonUndo,
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: l10n.commonRedo,
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo),
          ),
          if (isAdaptiveWide(context)) ...[
            IconButton(
              tooltip: l10n.videoGeneratePreviewTooltip,
              onPressed: _loading || _buildingGradedPreview
                  ? null
                  : _buildGradedPreview,
              icon: _buildingGradedPreview
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
            ),
            IconButton(
              tooltip: l10n.commonExport,
              onPressed: _loading || _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.file_upload_outlined),
            ),
          ] else
            PopupMenuButton<String>(
              tooltip: l10n.commonMore,
              onSelected: (value) {
                if (value == 'preview') _buildGradedPreview();
                if (value == 'export') _export();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'preview',
                  enabled: !_loading && !_buildingGradedPreview,
                  child: Text(l10n.videoRefreshGeneratePreview),
                ),
                PopupMenuItem(
                  value: 'export',
                  enabled: !_loading && !_exporting,
                  child: Text(l10n.videoExportVideoAction),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: _loading
              ? _buildLoading(l10n)
              : _error != null
                  ? _buildError(zc)
                  : _buildEditorBody(),
        ),
      ),
    );
  }

  Widget _buildFullscreenPreview() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) {
          setState(() => _fullscreenPreview = false);
        }
      },
      child: Scaffold(
        backgroundColor: ZyncPalette.dark.bg,
        body: SafeArea(child: _buildPreview(fill: true)),
      ),
    );
  }

  Widget _buildEditorBody() {
    if (!isAdaptiveWide(context)) {
      return Column(
        children: [
          _buildPreview(),
          _buildScrubber(),
          _buildTimeline(),
          _buildTabs(),
          Expanded(child: _buildPanel()),
        ],
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _buildPreview(fill: true)),
              _buildScrubber(),
              _buildTimeline(),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: adaptiveSidePanelWidth(width),
          child: Column(
            children: [
              _buildTabs(),
              Expanded(child: _buildPanel()),
            ],
          ),
        ),
      ],
    );
  }

  void _skipProxy() {
    _proxySkipCompleter?.complete();
    _proxySkipCompleter = null;
    VideoEditorBridge.cancel();
  }

  Widget _buildLoading(AppLocalizations l10n) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(l10n.videoGeneratingProxyOverlay),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: _skipProxy,
              icon: const Icon(Icons.fast_forward, size: 16),
              label: Text(l10n.videoSkipProxyUseOriginal),
            ),
          ],
        ),
      );

  Widget _buildError(ZyncPalette zc) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: zc.danger)),
        ),
      );

  Widget _buildPreview({bool fill = false}) {
    final player = _player;
    final zc = context.zc;
    final l10n = context.l10n;
    const dark = ZyncPalette.dark;
    if (player == null || !player.value.isInitialized) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      color: _fullscreenPreview ? dark.bg : zc.canvas,
      constraints: fill
          ? const BoxConstraints()
          : BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height < 700 ? 220 : 300,
            ),
      child: AspectRatio(
        aspectRatio:
            player.value.aspectRatio == 0 ? 16 / 9 : player.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(player),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: dark.bg.withValues(alpha: 0.64),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _showingGradedPreview
                      ? l10n.videoBadge4sProxy
                      : l10n.videoBadgeOriginalPreview,
                  style: TextStyle(color: dark.textSecondary, fontSize: 10),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_gradedPlayer != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: dark.bg.withValues(alpha: 0.64),
                        foregroundColor: dark.textPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                      onPressed: _toggleGradedPreview,
                      icon: Icon(
                        _gradedPreviewStale
                            ? Icons.warning_amber
                            : (_showingGradedPreview
                                ? Icons.compare
                                : Icons.movie_filter_outlined),
                        size: 14,
                      ),
                      label: Text(
                        _gradedPreviewStale
                            ? l10n.videoBadgePreviewStale
                            : (_showingGradedPreview
                                ? l10n.videoToggleGradedPreview
                                : l10n.videoToggleOriginalPreview),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  IconButton(
                    tooltip: _fullscreenPreview
                        ? l10n.videoExitFullscreen
                        : l10n.videoEnterFullscreen,
                    style: IconButton.styleFrom(
                      backgroundColor: dark.bg.withValues(alpha: 0.64),
                      foregroundColor: dark.textPrimary,
                    ),
                    onPressed: () => setState(
                        () => _fullscreenPreview = !_fullscreenPreview),
                    icon: Icon(_fullscreenPreview
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  IconButton(
                    color: dark.textPrimary,
                    onPressed: () {
                      if (player.value.isPlaying) {
                        player.pause();
                      } else {
                        player.play();
                      }
                      setState(() {});
                    },
                    icon: Icon(player.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubber() {
    final player = _player;
    if (player == null || !player.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) {
        final durationMs = value.duration.inMilliseconds;
        final positionMs = value.position.inMilliseconds.clamp(0, durationMs);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Text(
                _formatDuration(positionMs),
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
              Expanded(
                child: Slider(
                  value: durationMs <= 0 ? 0 : positionMs.toDouble(),
                  max: durationMs <= 0 ? 1 : durationMs.toDouble(),
                  onChanged: (v) =>
                      player.seekTo(Duration(milliseconds: v.round())),
                ),
              ),
              Text(
                _formatDuration(durationMs),
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildTimeline() {
    final project = _project;
    final player = _player;
    if (project == null || project.clips.isEmpty || player == null) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: player,
      builder: (context, value, _) => Container(
        color: context.zc.surface,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        child: VideoTimeline(
          frameStrip: _frameStrip,
          height: MediaQuery.sizeOf(context).height < 700 ? 112 : 132,
          project: project,
          currentTimeUs: value.position.inMicroseconds,
          selectedClipIndex: _selectedClip,
          visibleDurationUs: _showingGradedPreview
              ? math.min(project.durationUs, 4000000)
              : project.durationUs,
          onSeek: (timeUs) {
            final target = timeUs.clamp(0, project.durationUs);
            player.seekTo(Duration(microseconds: target));
            final index = project.clips.indexWhere(
              (clip) =>
                  target >= clip.timelineStartUs && target < clip.timelineEndUs,
            );
            if (index >= 0 && index != _selectedClip) {
              setState(() => _selectedClip = index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final zc = context.zc;
    final l10n = context.l10n;
    final labels = [
      l10n.videoTabTrim,
      l10n.videoTabGrade,
      'LUT',
      l10n.videoTabAudio,
      l10n.videoTabScopes,
      l10n.commonExport,
    ];
    const icons = [
      Icons.content_cut,
      Icons.tune,
      Icons.filter_vintage,
      Icons.volume_up_outlined,
      Icons.monitor_heart_outlined,
      Icons.file_upload_outlined,
    ];
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(
                width: 72,
                child: InkWell(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tab == i
                              ? zc.accent
                              : ZSwatch.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[i],
                          size: 16,
                          color: _tab == i ? zc.accent : zc.textSecondary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: _tab == i ? zc.textPrimary : zc.textSecondary,
                            fontWeight:
                                _tab == i ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    switch (_tab) {
      case 0:
        return _buildTrimPanel();
      case 1:
        return _buildColorPanel();
      case 2:
        return _buildLutPanel();
      case 3:
        return _buildAudioPanel();
      case 4:
        return _buildScopePanel();
      default:
        return _buildExportPanel();
    }
  }

  Widget _buildTrimPanel() {
    final clip = _clip;
    final project = _project;
    final asset = _asset;
    if (clip == null || project == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final assetDuration = clip.assetDurationUs > 0
        ? clip.assetDurationUs
        : (asset?.durationUs ?? clip.sourceOutUs);
    final maxUs = assetDuration <= 0 ? clip.sourceOutUs : assetDuration;
    final start = clip.sourceInUs.clamp(0, maxUs).toDouble();
    final end = clip.sourceOutUs.clamp(0, maxUs).toDouble();
    final clipIndex = project.clips.indexWhere((e) => e.id == clip.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.videoTimelineClipsHeader,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: l10n.videoAddLocalClipTooltip,
                onPressed: _addClip,
                icon: const Icon(Icons.add_to_photos_outlined),
              ),
            ],
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: project.clips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                return ChoiceChip(
                  selected: index == _selectedClip,
                  label: Text(l10n.videoClipIndexLabel(index + 1)),
                  onSelected: (_) => setState(() => _selectedClip = index),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: l10n.videoMoveClipEarlier,
                onPressed: clipIndex > 0 ? () => _moveClip(-1) : null,
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                tooltip: l10n.videoMoveClipLater,
                onPressed:
                    clipIndex >= 0 && clipIndex < project.clips.length - 1
                        ? () => _moveClip(1)
                        : null,
                icon: const Icon(Icons.arrow_forward),
              ),
              const Spacer(),
              Text(
                '${(clip.durationUs / 1000000).toStringAsFixed(1)}s',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.videoTrimRangeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            values: RangeValues(start, end),
            min: 0,
            max: maxUs.toDouble().clamp(1, double.infinity),
            onChangeEnd: (_) => unawaited(_loadFrameStrip(force: true)),
            onChanged: (v) => _updateClip(clip.copyWith(
                sourceInUs: v.start.round(), sourceOutUs: v.end.round())),
          ),
          Text(
              '${(start / 1000000).toStringAsFixed(1)}s — ${(end / 1000000).toStringAsFixed(1)}s'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final split = ((start + end) / 2).round();
                  _snapshotProject();
                  _updateProject(_project!.splitClip(clip.id, split));
                  unawaited(_loadFrameStrip(force: true));
                },
                icon: const Icon(Icons.content_cut, size: 16),
                label: Text(l10n.videoSplitClipAction),
              ),
              OutlinedButton.icon(
                onPressed: project.clips.length <= 1
                    ? null
                    : () {
                        _snapshotProject();
                        _updateProject(project.removeClip(clip.id));
                        setState(() => _selectedClip = 0);
                        unawaited(_loadFrameStrip(force: true));
                      },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(l10n.videoDeleteClipAction),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final time = _player == null
                      ? 0
                      : (_player!.value.position.inMicroseconds);
                  _snapshotProject();
                  _updateProject(_project!.copyWith(
                    chapters: [
                      ..._project!.chapters,
                      ChapterMarker(
                        timeUs: time,
                        title: l10n.videoChapterDefaultTitle(
                            _project!.chapters.length + 1),
                      )
                    ],
                  ));
                },
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: Text(l10n.videoAddChapterButton),
              ),
            ],
          ),
          if (project.chapters.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.videoChapterNavHeader,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < project.chapters.length; i++)
                  InputChip(
                    label: Text(
                        '${project.chapters[i].title} · ${_formatDuration(project.chapters[i].timeUs ~/ 1000)}'),
                    onPressed: () => _player?.seekTo(
                        Duration(microseconds: project.chapters[i].timeUs)),
                    onDeleted: () {
                      _snapshotProject();
                      final chapters = [...project.chapters]..removeAt(i);
                      _updateProject(project.copyWith(chapters: chapters));
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorPanel() {
    final clip = _clip;
    final project = _project;
    if (clip == null || project == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final grade = _currentGrade;
    final base = grade.base;
    final isGlobal = _editingGlobalGrade;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.videoGlobalGradeTitle),
            subtitle: Text(
              isGlobal ? l10n.videoGlobalGradeOnSub : l10n.videoGlobalGradeOffSub,
            ),
            value: isGlobal,
            onChanged: (value) => setState(() => _editingGlobalGrade = value),
          ),
          _slider(
              l10n.adjExposure,
              base.exposure,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(exposure: v)))),
          _slider(
              l10n.adjContrast,
              base.contrast,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(contrast: v)))),
          _slider(
              l10n.adjSaturation,
              base.saturation,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(saturation: v)))),
          _slider(
              l10n.adjTemperature,
              base.temperature,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(temperature: v)))),
          _slider(
              l10n.adjTint,
              base.tint,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(tint: v)))),
          const Divider(height: 18),
          _slider(
              l10n.adjHighlights,
              base.highlights,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(highlights: v)))),
          _slider(
              l10n.adjShadows,
              base.shadows,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(shadows: v)))),
          _slider(
              l10n.adjWhites,
              base.whites,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(whites: v)))),
          _slider(
              l10n.adjBlacks,
              base.blacks,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(blacks: v)))),
          _slider(
              l10n.adjVibrance,
              base.vibrance,
              -100,
              100,
              (v) => _updateCurrentGrade(
                  grade.copyWith(base: base.copyWith(vibrance: v)))),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 6),
            title: Text(
              '${l10n.wmGradeCatSplit} / ${l10n.adjColorWheel}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            children: [
              _wheelGroup(
                  l10n.adjShadows,
                  grade.colorGrading.shadows,
                  (wheel) => grade.copyWith(
                      colorGrading:
                          grade.colorGrading.copyWith(shadows: wheel))),
              _wheelGroup(
                  l10n.adjMidtones,
                  grade.colorGrading.midtones,
                  (wheel) => grade.copyWith(
                      colorGrading:
                          grade.colorGrading.copyWith(midtones: wheel))),
              _wheelGroup(
                  l10n.adjHighlights,
                  grade.colorGrading.highlights,
                  (wheel) => grade.copyWith(
                      colorGrading:
                          grade.colorGrading.copyWith(highlights: wheel))),
            ],
          ),
          if (isGlobal) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.videoGlobalGradeHint,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _keyframeParameter,
                    decoration: InputDecoration(
                      labelText: l10n.videoKeyframeParamLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'exposure',
                        child: Text(l10n.adjExposure),
                      ),
                      DropdownMenuItem(
                        value: 'contrast',
                        child: Text(l10n.adjContrast),
                      ),
                      DropdownMenuItem(
                        value: 'saturation',
                        child: Text(l10n.adjSaturation),
                      ),
                      DropdownMenuItem(
                        value: 'temperature',
                        child: Text(l10n.adjTemperature),
                      ),
                      DropdownMenuItem(
                        value: 'tint',
                        child: Text(l10n.adjTint),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _keyframeParameter = v ?? 'exposure'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final time = _player == null
                        ? 0
                        : _player!.value.position.inMicroseconds;
                    final value = _valueForParameter(base, _keyframeParameter);
                    final key = Keyframe(
                        timeUs: time,
                        value: value,
                        interpolation: KeyframeInterpolation.easeInOut);
                    _snapshotProject();
                    _updateClip(clip.copyWith(
                        keyframes: _upsertKeyframe(
                            clip.keyframes, _keyframeParameter, key)));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.videoAddKeyframeButton),
                ),
              ],
            ),
            if (clip.keyframes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.videoKeyframeListHeader,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              for (final track in clip.keyframes)
                for (var i = 0; i < track.keys.length; i++)
                  _keyframeRow(clip, track, i),
            ],
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ColorPresetSheet.show(
                context,
                grade: grade,
                isGlobal: isGlobal,
                onApply: (applied) {
                  _snapshotProject();
                  _updateCurrentGrade(applied);
                },
              ),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: Text(
                l10n.videoPresetEntryTitle,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _gradeClipboard = grade;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isGlobal
                              ? l10n.videoCopiedGlobalGradeToast
                              : l10n.videoCopiedClipGradeToast,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 15),
                  label: Text(
                    l10n.videoCopyGradeAction,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gradeClipboard == null
                      ? null
                      : () {
                          _snapshotProject();
                          _updateCurrentGrade(_gradeClipboard!);
                        },
                  icon: const Icon(Icons.paste, size: 15),
                  label: Text(
                    l10n.videoPasteGradeAction,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    _snapshotProject();
                    _updateCurrentGrade(const ColorGrade());
                  },
                  icon: const Icon(Icons.restart_alt, size: 15),
                  label: Text(
                    l10n.commonReset,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _buildingGradedPreview ? null : _buildGradedPreview,
              icon: Icon(
                  _gradedPreviewStale ? Icons.refresh : Icons.auto_awesome,
                  size: 16),
              label: Text(
                _gradedPreviewStale
                    ? l10n.videoRefresh4sPreview
                    : l10n.videoGenerate4sPreview,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isGlobal
                  ? l10n.videoGlobalGradeStatusChip(
                      grade.isDefault ? l10n.commonDefault : l10n.videoStatusEnabled)
                  : l10n.videoKeyframeCountChip(
                      clip.keyframes.fold<int>(0, (sum, e) => sum + e.keys.length)),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheelGroup(String label, ColorWheelAdjustment wheel,
      ColorGrade Function(ColorWheelAdjustment) update) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        _slider(
            l10n.videoWheelHue(label),
            wheel.hue,
            -180,
            180,
            (v) => _updateCurrentGrade(update(wheel.copyWith(hue: v)))),
        _slider(
            l10n.videoWheelSaturation(label),
            wheel.saturation,
            -100,
            100,
            (v) => _updateCurrentGrade(update(wheel.copyWith(saturation: v)))),
        _slider(
            l10n.videoWheelLuma(label),
            wheel.luminance,
            -100,
            100,
            (v) => _updateCurrentGrade(update(wheel.copyWith(luminance: v)))),
      ],
    );
  }

  double _valueForParameter(PhotoEditAdjustments base, String parameter) =>
      switch (parameter) {
        'exposure' => base.exposure,
        'contrast' => base.contrast,
        'saturation' => base.saturation,
        'temperature' => base.temperature,
        'tint' => base.tint,
        _ => 0,
      };

  List<KeyframeTrack> _upsertKeyframe(
      List<KeyframeTrack> tracks, String parameter, Keyframe key) {
    final next = [...tracks];
    final index = next.indexWhere((e) => e.parameter == parameter);
    final keys = index < 0 ? <Keyframe>[] : [...next[index].keys];
    keys.removeWhere((e) => (e.timeUs - key.timeUs).abs() < 1000);
    keys.add(key);
    keys.sort((a, b) => a.timeUs.compareTo(b.timeUs));
    if (index < 0) {
      next.add(KeyframeTrack(parameter: parameter, keys: keys));
    } else {
      next[index] = next[index].copyWith(keys: keys);
    }
    return next;
  }

  Widget _keyframeRow(VideoClip clip, KeyframeTrack track, int keyIndex) {
    final l10n = context.l10n;
    final key = track.keys[keyIndex];
    final minUs = clip.sourceInUs.toDouble();
    final maxUs = math.max(minUs + 1, clip.sourceOutUs.toDouble());
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
      decoration: BoxDecoration(
        color: context.zc.surface,
        borderRadius: BorderRadius.circular(ZRadius.sm),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _player?.seekTo(Duration(
                      microseconds:
                          key.timeUs.clamp(minUs.toInt(), maxUs.toInt()))),
                  child: Text(
                    '${track.parameter} · ${_formatDuration(key.timeUs ~/ 1000)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  final tracks = [...clip.keyframes];
                  final trackIndex =
                      tracks.indexWhere((e) => e.parameter == track.parameter);
                  if (trackIndex < 0) return;
                  final keys = [...tracks[trackIndex].keys];
                  if (keyIndex < 0 || keyIndex >= keys.length) return;
                  final old = keys[keyIndex];
                  keys[keyIndex] = Keyframe(
                    timeUs: old.timeUs,
                    value: old.value,
                    interpolation:
                        old.interpolation == KeyframeInterpolation.linear
                            ? KeyframeInterpolation.easeInOut
                            : KeyframeInterpolation.linear,
                  );
                  tracks[trackIndex] = tracks[trackIndex].copyWith(keys: keys);
                  _snapshotProject();
                  _updateClip(clip.copyWith(keyframes: tracks));
                },
                child: Text(
                  key.interpolation == KeyframeInterpolation.linear
                      ? l10n.videoCurveLinear
                      : l10n.videoCurveEaseInOut,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final tracks = [...clip.keyframes];
                  final trackIndex =
                      tracks.indexWhere((e) => e.parameter == track.parameter);
                  if (trackIndex < 0) return;
                  final keys = [...tracks[trackIndex].keys];
                  if (keyIndex < 0 || keyIndex >= keys.length) return;
                  keys.removeAt(keyIndex);
                  if (keys.isEmpty) {
                    tracks.removeAt(trackIndex);
                  } else {
                    tracks[trackIndex] =
                        tracks[trackIndex].copyWith(keys: keys);
                  }
                  _snapshotProject();
                  _updateClip(clip.copyWith(keyframes: tracks));
                },
                icon: const Icon(Icons.delete_outline, size: 16),
              ),
            ],
          ),
          Slider(
            value: key.timeUs.toDouble().clamp(minUs, maxUs),
            min: minUs,
            max: maxUs,
            onChangeStart: (_) => _beginSliderGesture(),
            onChangeEnd: (_) => _endSliderGesture(),
            onChanged: (value) {
              final tracks = [...clip.keyframes];
              final trackIndex =
                  tracks.indexWhere((e) => e.parameter == track.parameter);
              if (trackIndex < 0) return;
              final keys = [...tracks[trackIndex].keys];
              if (keyIndex < 0 || keyIndex >= keys.length) return;
              final old = keys[keyIndex];
              keys[keyIndex] = Keyframe(
                timeUs: value.round(),
                value: old.value,
                interpolation: old.interpolation,
              );
              keys.sort((a, b) => a.timeUs.compareTo(b.timeUs));
              tracks[trackIndex] = tracks[trackIndex].copyWith(keys: keys);
              _updateClip(clip.copyWith(keyframes: tracks));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLutPanel() {
    final clip = _clip;
    final project = _project;
    if (clip == null || project == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final grade = _currentGrade;
    final isGlobal = _editingGlobalGrade;
    final cacheKey = isGlobal ? '__global__' : clip.id;
    if (_lutClipId != cacheKey) {
      _lutClipId = cacheKey;
      _lutDraft = grade.lut.path;
      _lutController.text = _lutDraft;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isGlobal ? l10n.videoLutGlobalTitle : l10n.videoLutClipTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lutController,
            decoration: InputDecoration(
              labelText: l10n.videoLutPathHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => _lutDraft = v.trim(),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              final path = await CameraNativeBridge.pickFile();
              if (path != null && path.isNotEmpty) {
                _lutDraft = path;
                _lutController.text = path;
              }
            },
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(l10n.videoPickLutTooltip),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final path = _lutDraft.trim();
                    _snapshotProject();
                    _updateCurrentGrade(grade.copyWith(
                        lut: LutRef(
                            id: path,
                            name: path.split(RegExp(r'[\\/]')).last,
                            path: path)));
                  },
                  child: Text(l10n.videoApplyLutAction),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  _lutDraft = '';
                  _lutController.clear();
                  _snapshotProject();
                  _updateCurrentGrade(grade.copyWith(lut: const LutRef()));
                },
                child: Text(l10n.commonClear),
              ),
            ],
          ),
          _slider(
              l10n.videoLutIntensityLabel,
              grade.lut.strength,
              0,
              1,
              (v) => _updateCurrentGrade(
                  grade.copyWith(lut: grade.lut.copyWith(strength: v)))),
          const SizedBox(height: 8),
          if (_asset != null) _buildSourceColorCard(),
        ],
      ),
    );
  }

  Widget _buildSourceColorCard() {
    final asset = _asset;
    if (asset == null) return const SizedBox.shrink();
    final zc = context.zc;
    final l10n = context.l10n;
    final transfer = asset.colorTransfer;
    final label = switch (transfer) {
      'hlg' => 'HLG',
      'pq' => 'PQ (ST 2084)',
      'linear' => 'Linear',
      'unspecified' => l10n.videoColorUnlabeled,
      _ => 'SDR',
    };
    final isHdrSource = asset.isHdr;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHdrSource ? zc.warning.withAlpha(28) : zc.surface,
        borderRadius: BorderRadius.circular(ZRadius.sm),
        border: Border.all(
          color: isHdrSource
              ? zc.warning.withAlpha(120)
              : ZSwatch.transparent,
          width: ZStroke.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isHdrSource ? Icons.high_quality : Icons.sd_outlined,
                size: 16,
                color: isHdrSource ? zc.warning : zc.accent,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.videoSourceColorLabel(label),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${asset.bitDepth}bit · ${asset.width}×${asset.height}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isHdrSource
                ? l10n.videoHdrToneMapHint(label)
                : l10n.videoSdrSourceHint,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshScopes() async {
    final asset = _asset;
    final player = _player;
    if (asset == null || player == null || _scopeLoading) return;
    setState(() => _scopeLoading = true);
    final path = (_showingGradedPreview && _gradedPlayerPath != null)
        ? _gradedPlayerPath!
        : asset.path;
    final timeUs = player.value.position.inMicroseconds;
    try {
      final bytes = await VideoEditorBridge.captureFrame(path, timeUs: timeUs);
      final data =
          bytes == null ? null : await VideoScopeAnalyzer.analyze(bytes);
      if (!mounted) return;
      setState(() {
        _scopeData = data;
        _scopeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scopeLoading = false);
    }
  }

  Widget _buildScopePanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: VideoScopeView(
        data: _scopeData,
        loading: _scopeLoading,
        onRefresh: _refreshScopes,
      ),
    );
  }

  Widget _buildAudioPanel() {
    final clip = _clip;
    if (clip == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final audio = clip.audio;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.videoAudioMute),
            value: audio.muted,
            onChanged: (v) {
              _snapshotProject();
              _updateClip(clip.copyWith(audio: audio.copyWith(muted: v)));
            },
          ),
          _slider(
              l10n.videoAudioVolume,
              audio.volume,
              0,
              1,
              (v) =>
                  _updateClip(clip.copyWith(audio: audio.copyWith(volume: v)))),
          _slider(
              l10n.videoAudioFadeIn,
              audio.fadeInUs / 1000000,
              0,
              5,
              (v) => _updateClip(clip.copyWith(
                  audio: audio.copyWith(fadeInUs: (v * 1000000).round())))),
          _slider(
              l10n.videoAudioFadeOut,
              audio.fadeOutUs / 1000000,
              0,
              5,
              (v) => _updateClip(clip.copyWith(
                  audio: audio.copyWith(fadeOutUs: (v * 1000000).round())))),
        ],
      ),
    );
  }

  Widget _buildExportPanel() {
    final project = _project;
    final caps = _capabilities;
    if (project == null) return const SizedBox.shrink();
    final zc = context.zc;
    final l10n = context.l10n;
    final spec = project.exportSpec;
    final hevcSupported = caps?.hardwareEncodeHevc ?? false;

    Widget dropdown<T>({
      required String label,
      required T value,
      required List<DropdownMenuItem<T>> items,
      required ValueChanged<T?> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DropdownButtonFormField<T>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: items,
          onChanged: onChanged,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.videoExportSettingsHeader,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${spec.codec == VideoCodec.hevc ? 'HEVC' : 'H.264'} · SDR Rec.709 · ${spec.width}×${spec.height} · ${spec.fps.round()}fps · ${(spec.bitrate / 1000000).round()}Mbps',
            style: TextStyle(color: zc.textSecondary, fontSize: 12),
          ),
          if (caps != null) ...[
            const SizedBox(height: 6),
            Text(
              '${l10n.videoHwHevcStatus(caps.hardwareDecodeHevc ? l10n.commonSupported : l10n.commonUnsupported)}   HEVC Main10: ${caps.hardwareDecodeHevcMain10 ? l10n.commonSupported : l10n.commonUnsupported}',
              style: const TextStyle(fontSize: 11),
            ),
            if (spec.height >= 2160 && spec.fps > 30) ...[
              const SizedBox(height: 4),
              Text(
                l10n.videoExport4k60Note,
                style: TextStyle(fontSize: 11, color: zc.warning),
              ),
            ],
            if (spec.codec == VideoCodec.hevc &&
                !caps.hardwareDecodeHevcMain10) ...[
              const SizedBox(height: 4),
              Text(
                l10n.videoNoHevc10BitWarning,
                style: TextStyle(fontSize: 11, color: zc.warning),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('1080p/30'),
                selected: spec.height <= 1080 && spec.fps <= 30,
                onSelected: (_) {
                  _snapshotProject();
                  _updateProject(project.copyWith(
                      exportSpec: spec
                          .copyWith1080p()
                          .copyWithFps(30)
                          .copyWithBitrate(20000000)));
                },
              ),
              ChoiceChip(
                label: const Text('4K/30'),
                selected: spec.height >= 2160 && spec.fps <= 30,
                onSelected: (_) {
                  _snapshotProject();
                  _updateProject(project.copyWith(
                      exportSpec: spec
                          .copyWith4K()
                          .copyWithFps(30)
                          .copyWithBitrate(40000000)));
                },
              ),
              ChoiceChip(
                label: const Text('4K/60'),
                selected: spec.height >= 2160 && spec.fps > 30,
                onSelected: (_) {
                  _snapshotProject();
                  _updateProject(project.copyWith(
                      exportSpec: spec
                          .copyWith4K()
                          .copyWithFps(60)
                          .copyWithBitrate(80000000)));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          dropdown<VideoCodec>(
            label: l10n.videoCodecLabel,
            value: spec.codec,
            items: [
              DropdownMenuItem(
                value: VideoCodec.h264,
                child: Text(l10n.videoCodecH264),
              ),
              DropdownMenuItem(
                value: VideoCodec.hevc,
                enabled: hevcSupported,
                child: Text(
                  hevcSupported
                      ? l10n.videoCodecHevc
                      : l10n.videoCodecHevcUnsupported,
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _snapshotProject();
              _updateProject(
                  project.copyWith(exportSpec: spec.copyWithCodec(value)));
            },
          ),
          dropdown<String>(
            label: l10n.videoResolutionLabel,
            value: spec.height >= 2160 ? '4k' : '1080p',
            items: const [
              DropdownMenuItem(value: '1080p', child: Text('1080p / Full HD')),
              DropdownMenuItem(value: '4k', child: Text('4K UHD')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _snapshotProject();
              _updateProject(project.copyWith(
                  exportSpec: value == '4k'
                      ? spec.copyWith4K()
                      : spec.copyWith1080p()));
            },
          ),
          dropdown<int>(
            label: l10n.videoFpsLabel,
            value: spec.fps.round(),
            items: const [
              DropdownMenuItem(value: 24, child: Text('24 fps')),
              DropdownMenuItem(value: 25, child: Text('25 fps')),
              DropdownMenuItem(value: 30, child: Text('30 fps')),
              DropdownMenuItem(value: 60, child: Text('60 fps')),
            ],
            onChanged: (value) {
              if (value == null) return;
              _snapshotProject();
              _updateProject(project.copyWith(
                  exportSpec: spec.copyWithFps(value.toDouble())));
            },
          ),
          dropdown<int>(
            label: l10n.videoBitrateLabel,
            value: spec.bitrate >= 80000000
                ? 80000000
                : spec.bitrate >= 40000000
                    ? 40000000
                    : 20000000,
            items: [
              DropdownMenuItem(
                value: 20000000,
                child: Text(l10n.videoBitrate20),
              ),
              DropdownMenuItem(
                value: 40000000,
                child: Text(l10n.videoBitrate40),
              ),
              DropdownMenuItem(
                value: 80000000,
                child: Text(l10n.videoBitrate80),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _snapshotProject();
              _updateProject(
                  project.copyWith(exportSpec: spec.copyWithBitrate(value)));
            },
          ),
          const SizedBox(height: 8),
          if (_exporting) ...[
            LinearProgressIndicator(
              value: _exportProgress == 0 ? null : _exportProgress,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.videoExportingProgressHint((_exportProgress * 100).round()),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await VideoEditorBridge.cancel();
                  if (mounted) setState(() => _exporting = false);
                },
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text(l10n.videoCancelExport),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _export,
                icon: const Icon(Icons.movie_creation_outlined),
                label: Text(l10n.videoExportToDcimButton),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              value.toStringAsFixed(max <= 1 ? 2 : 0),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChangeStart: (_) => _beginSliderGesture(),
          onChangeEnd: (_) => _endSliderGesture(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
