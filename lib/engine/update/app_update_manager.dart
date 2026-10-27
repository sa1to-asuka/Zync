import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../../ui/design/design.dart';
import '../../ui/widgets/markdown_text.dart';

/// 远程版本发布信息模型
class AppReleaseInfo {
  final String tagName;
  final String versionName;
  final String title;
  final String changelog;
  final String downloadUrl;
  final String releasePageUrl;
  final String sourceName;
  final int? fileSize;
  final DateTime? publishedAt;

  AppReleaseInfo({
    required this.tagName,
    required this.versionName,
    required this.title,
    required this.changelog,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.sourceName,
    this.fileSize,
    this.publishedAt,
  });

  factory AppReleaseInfo.fromGitHubJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] as String? ?? '').trim();
    final cleanVer = tag.replaceFirst(RegExp(r'^[vV]'), '');
    final name = (json['name'] as String? ?? 'v$cleanVer').trim();
    final body =
        (json['body'] as String? ?? L10n.tr('修复已知问题，优化使用体验。')).trim();

    String apkUrl = '';
    int? size;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final a in assets) {
      if (a is Map<String, dynamic>) {
        final aName = (a['name'] as String? ?? '').toLowerCase();
        if (aName.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String? ?? '';
          size = (a['size'] as num?)?.toInt();
          break;
        }
      }
    }

    if (apkUrl.isEmpty) {
      apkUrl =
          'https://github.com/sa1to-asuka/Zync/releases/download/$tag/Zync-release-$cleanVer.apk';
    }

    return AppReleaseInfo(
      tagName: tag,
      versionName: cleanVer,
      title: name,
      changelog: body,
      downloadUrl: apkUrl,
      releasePageUrl: 'https://github.com/sa1to-asuka/Zync/releases',
      sourceName: 'GitHub',
      fileSize: size,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
}

/// Zync 自动版本检查与应用内安装管理器
class AppUpdateManager {
  AppUpdateManager._();

  static String currentVersion = '2.1.0';
  static int currentVersionCode = 3;

  static const String githubApiUrl =
      'https://api.github.com/repos/sa1to-asuka/Zync/releases/latest';
  static const String githubWebUrl =
      'https://github.com/sa1to-asuka/Zync/releases';

  /// 语义化版本号比对：判断 remoteVersion 是否严格大于 currentVersion
  /// 例如：'1.2.0' > '1.1.0' (true), '1.1.0' > '1.1.0' (false), '1.0.0' > '1.1.0' (false)
  static bool isNewerVersion(String remoteVersion, String currentVersion) {
    final cleanRemote = remoteVersion.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final cleanCurrent =
        currentVersion.trim().replaceFirst(RegExp(r'^[vV]'), '');

    final rParts =
        cleanRemote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts =
        cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (rParts.length < 3) {
      rParts.add(0);
    }
    while (cParts.length < 3) {
      cParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (rParts[i] > cParts[i]) return true;
      if (rParts[i] < cParts[i]) return false;
    }
    return false;
  }

  // ==================== 跳过版本持久化 ====================

  static Future<File> _getPrefFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/zync_update_pref.json');
  }

  /// 获取用户选择跳过的版本号（如 '1.2.0'）
  static Future<String?> getSkippedVersion() async {
    try {
      final file = await _getPrefFile();
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      final data = jsonDecode(text) as Map<String, dynamic>;
      return data['skipped_version'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 记录跳过指定版本
  static Future<void> setSkippedVersion(String version) async {
    try {
      final file = await _getPrefFile();
      final data = {'skipped_version': version.trim()};
      await file.writeAsString(jsonEncode(data));
    } catch (_) {}
  }

  /// 清除跳过记录
  static Future<void> clearSkippedVersion() async {
    try {
      final file = await _getPrefFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  // ==================== 远程版本检测 ====================

  /// 检查 GitHub 上的最新发布。
  static Future<AppReleaseInfo?> fetchLatestRelease(
      {Duration timeout = const Duration(seconds: 7)}) async {
    try {
      return await _fetchFromUrl(
        githubApiUrl,
        (json) => AppReleaseInfo.fromGitHubJson(json),
        timeout,
      );
    } catch (e) {
      debugPrint('[AppUpdateManager] GitHub check failed: $e');
      return null;
    }
  }

  static Future<AppReleaseInfo?> _fetchFromUrl(
    String url,
    AppReleaseInfo Function(Map<String, dynamic>) parser,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.getUrl(Uri.parse(url)).timeout(timeout);
      req.headers.set('User-Agent', 'Zync-Android/1.0.0');
      req.headers.set('Accept', 'application/json');

      final resp = await req.close().timeout(timeout);
      if (resp.statusCode == 200) {
        final bodyStr = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(bodyStr);
        if (json is Map<String, dynamic>) {
          return parser(json);
        }
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// 尽力获取发布资产的 `.sha256` 校验值；获取失败返回 null（不阻断更新，但会提示未校验）。
  static Future<String?> fetchExpectedSha256(String downloadUrl,
      {Duration timeout = const Duration(seconds: 5)}) async {
    if (downloadUrl.isEmpty) return null;
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client
          .getUrl(Uri.parse('$downloadUrl.sha256'))
          .timeout(timeout);
      req.headers.set('User-Agent', 'Zync-Android/1.0.0');
      final resp = await req.close().timeout(timeout);
      if (resp.statusCode != 200) return null;
      final body = await resp.transform(utf8.decoder).join();
      final hash = parseSha256(body);
      return hash.isEmpty ? null : hash;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  // ==================== APK 下载引擎 ====================

  /// 计算本地文件的 SHA-256（十六进制小写）。
  static Future<String> computeSha256(String filePath) async {
    final digest = await sha256.bind(File(filePath).openRead()).first;
    return digest.toString();
  }

  /// 解析发布资产中的 `.sha256` 文本，支持
  /// "hash"、"hash  filename"、"hash *filename" 三种常见格式。
  static String parseSha256(String content) {
    final line = content.trim().split(RegExp(r'\r?\n')).firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    final match = RegExp(r'[A-Fa-f0-9]{64}').firstMatch(line);
    return match?.group(0)?.toLowerCase() ?? '';
  }

  /// 下载 APK 安装包并实时汇报进度。
  ///
  /// [expectedSha256] 非空时做完整性校验，不一致则返回 null 且不落盘。
  static Future<String?> downloadApk({
    required String downloadUrl,
    required String versionName,
    required void Function(
            int received, int total, double progress, String speedStr)
        onProgress,
    void Function(String error)? onError,
    CancelToken? cancelToken,
    String? expectedSha256,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/Zync-release-$versionName.apk';
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final uri = Uri.parse(downloadUrl);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set('User-Agent', 'Zync-Android/1.0.0');

      final response = await request.close();
      if (response.statusCode != 200 && response.statusCode != 206) {
        onError?.call('${L10n.tr('下载服务返回异常状态码')}: ${response.statusCode}');
        return null;
      }

      final totalBytes = response.contentLength;
      int receivedBytes = 0;
      final sink = file.openWrite();

      final startTime = DateTime.now();
      int lastReportTime = 0;

      await for (final chunk in response) {
        if (cancelToken?.isCancelled == true) {
          await sink.close();
          if (await file.exists()) await file.delete();
          onError?.call(L10n.tr('用户已取消下载'));
          return null;
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastReportTime > 200 || receivedBytes == totalBytes) {
          lastReportTime = nowMs;
          final elapsedSec =
              DateTime.now().difference(startTime).inMilliseconds / 1000.0;
          final speedBytesPerSec =
              elapsedSec > 0.1 ? (receivedBytes / elapsedSec) : 0.0;
          final speedStr = _formatSpeed(speedBytesPerSec);
          final progress = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          onProgress(receivedBytes, totalBytes, progress, speedStr);
        }
      }

      await sink.flush();
      await sink.close();

      // 完整性校验：不匹配即删除并拒绝安装
      if (expectedSha256 != null && expectedSha256.isNotEmpty) {
        final actual = await computeSha256(savePath);
        if (actual != expectedSha256.toLowerCase()) {
          if (await file.exists()) await file.delete();
          onError?.call(L10n.tr('安装包 SHA-256 校验失败，已拒绝安装'));
          return null;
        }
      }

      return savePath;
    } catch (e) {
      onError?.call('${L10n.tr('下载失败')}: $e');
      return null;
    } finally {
      client.close();
    }
  }

  static String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec > 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec > 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return L10n.tr('未知大小');
    if (bytes > 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  // ==================== 应用启动与设置页调用入口 ====================

  /// App 启动静默检测入口：仅在有更新且未跳过该版本时弹窗提示
  static Future<void> checkOnStartup(BuildContext context) async {
    try {
      final info =
          await fetchLatestRelease(timeout: const Duration(seconds: 6));
      if (info == null) return;

      // 比对版本
      if (!isNewerVersion(info.versionName, currentVersion)) {
        return; // 当前已是最新或更高版本
      }

      // 检查跳过记录
      final skipped = await getSkippedVersion();
      if (skipped != null && skipped == info.versionName) {
        debugPrint('[AppUpdateManager] 用户已跳过版本 v${info.versionName}，启动时不弹窗提醒');
        return;
      }

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            AppUpdateDialog(releaseInfo: info, isManualCheck: false),
      );
    } catch (e) {
      debugPrint('[AppUpdateManager] checkOnStartup exception: $e');
    }
  }

  /// 设置页手动检测入口：无视跳过标记，并在最新时显示 Toast/提示
  static Future<void> checkManually(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LoadingCheckDialog(),
    );

    try {
      final info =
          await fetchLatestRelease(timeout: const Duration(seconds: 8));
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭加载框

      final l10n = context.l10n;
      if (info == null) {
        _showNoticeDialog(
          context,
          title: l10n.updateCheckFailedTitle,
          message: l10n.updateCheckFailedBody,
          showBrowserButton: true,
          webUrl: githubWebUrl,
        );
        return;
      }

      if (isNewerVersion(info.versionName, currentVersion)) {
        // 发现新版本，弹出更新对话框
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) =>
              AppUpdateDialog(releaseInfo: info, isManualCheck: true),
        );
      } else {
        // 当前已是最新版本
        _showNoticeDialog(
          context,
          title: l10n.updateUpToDateTitle,
          message: l10n.updateUpToDateBody(currentVersion, info.sourceName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final l10n = context.l10n;
        _showNoticeDialog(
          context,
          title: l10n.updateCheckErrorTitle,
          message: '$e',
        );
      }
    }
  }

  static void _showNoticeDialog(
    BuildContext context, {
    required String title,
    required String message,
    bool showBrowserButton = false,
    String? webUrl,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final zc = context.zc;
        final l10n = context.l10n;
        return AlertDialog(
          backgroundColor: zc.surfaceMid,
          shape: const RoundedRectangleBorder(borderRadius: ZRadius.brLg),
          title: Text(
            title,
            style: TextStyle(
                color: zc.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            message,
            style: TextStyle(
                color: zc.textSecondary, fontSize: 14, height: 1.5),
          ),
          actions: [
            if (showBrowserButton && webUrl != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  CameraNativeBridge.openUrlInBrowser(webUrl);
                },
                child: Text(l10n.updateOpenWebsite,
                    style: TextStyle(color: zc.accent)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: zc.accent,
                foregroundColor: zc.onAccent,
                shape: const RoundedRectangleBorder(borderRadius: ZRadius.brSm),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonConfirm,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class CancelToken {
  bool isCancelled = false;
  void cancel() => isCancelled = true;
}

/// 检查更新加载中弹窗
class _LoadingCheckDialog extends StatelessWidget {
  const _LoadingCheckDialog();

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    return Dialog(
      backgroundColor: zc.surfaceMid,
      shape: const RoundedRectangleBorder(borderRadius: ZRadius.brLg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(zc.accent),
              ),
            ),
            const SizedBox(width: 18),
            Text(
              l10n.updateCheckingToast,
              style: TextStyle(color: zc.textPrimary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// Zync 专业版更新提示与应用内下载安装对话框
class AppUpdateDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;
  final bool isManualCheck;

  const AppUpdateDialog({
    super.key,
    required this.releaseInfo,
    this.isManualCheck = false,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _speedText = '';
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _downloadedApkPath;
  String? _errorMessage;
  CancelToken? _cancelToken;

  void _startDownload() async {
    final l10n = context.l10n;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _speedText = l10n.updatePreparing;
      _errorMessage = null;
      _cancelToken = CancelToken();
    });

    // 尽力获取发布校验值；拿不到则不阻断下载。
    final expectedSha256 = await AppUpdateManager.fetchExpectedSha256(
        widget.releaseInfo.downloadUrl);

    final path = await AppUpdateManager.downloadApk(
      downloadUrl: widget.releaseInfo.downloadUrl,
      versionName: widget.releaseInfo.versionName,
      cancelToken: _cancelToken,
      expectedSha256: expectedSha256,
      onProgress: (received, total, progress, speed) {
        if (!mounted) return;
        setState(() {
          _receivedBytes = received;
          _totalBytes = total;
          _downloadProgress = progress;
          _speedText = speed;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _errorMessage = err;
        });
      },
    );

    if (!mounted) return;
    if (path != null) {
      setState(() {
        _isDownloading = false;
        _downloadedApkPath = path;
      });

      // 下载完成，直接调起系统安装器
      _installDownloadedApk();
    }
  }

  void _cancelDownload() {
    _cancelToken?.cancel();
    setState(() {
      _isDownloading = false;
      _speedText = '';
    });
  }

  void _installDownloadedApk() async {
    if (_downloadedApkPath == null) return;
    final success = await CameraNativeBridge.installApk(_downloadedApkPath!);
    if (!success && mounted) {
      final zc = context.zc;
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.updateInstallerFailedToast),
          backgroundColor: zc.danger,
          action: SnackBarAction(
            label: l10n.updateBrowserDownload,
            textColor: zc.textPrimary,
            onPressed: () => CameraNativeBridge.openUrlInBrowser(
                widget.releaseInfo.downloadUrl),
          ),
        ),
      );
    }
  }

  void _skipThisVersion() async {
    await AppUpdateManager.setSkippedVersion(widget.releaseInfo.versionName);
    if (!mounted) return;
    final zc = context.zc;
    final l10n = context.l10n;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.updateSkippedVersionToast(
          widget.releaseInfo.versionName,
        )),
        backgroundColor: zc.surfaceMid,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final l10n = context.l10n;
    final info = widget.releaseInfo;
    return PopScope(
      canPop: !_isDownloading,
      child: Dialog(
        backgroundColor: ZSwatch.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: zc.surfaceMid,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: zc.outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: ZSwatch.pureBlack.withAlpha(
                    Theme.of(context).brightness == Brightness.light
                        ? 25
                        : 160),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头部色彩 Banner 与标题栏
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      zc.accent.withAlpha(18),
                      zc.surfaceMid,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [zc.accent, zc.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: zc.accent.withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.system_update_alt_rounded,
                        color: zc.onAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.updateNewVersionTitle,
                                style: TextStyle(
                                  color: zc.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: zc.surfaceHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.updateSourceGithub,
                                  style: TextStyle(
                                    color: zc.textPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: zc.surfaceMid,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: zc.outline),
                            ),
                            child: Text(
                              'v${AppUpdateManager.currentVersion}  →  v${info.versionName}',
                              style: TextStyle(
                                color: zc.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 版本更新说明内容区
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title.isNotEmpty
                          ? info.title
                          : 'Zync v${info.versionName}',
                      style: TextStyle(
                        color: zc.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.updateChangelogHeader,
                      style: TextStyle(
                        color: zc.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: zc.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: zc.outline),
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: info.changelog.isNotEmpty
                            ? MarkdownText(data: info.changelog)
                            : Text(
                                l10n.updateDefaultChangelog,
                                style: TextStyle(
                                  color: zc.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ),
                    if (info.fileSize != null && info.fileSize! > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.updatePackageSizeLabel(
                            AppUpdateManager.formatBytes(info.fileSize!)),
                        style: TextStyle(
                            color: zc.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              // 下载进度或异常展示区
              if (_isDownloading)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: zc.surfaceMid,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: zc.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.updateDownloadingPct(
                                  (_downloadProgress * 100).toStringAsFixed(1)),
                              style: TextStyle(
                                color: zc.accent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _speedText,
                              style: TextStyle(
                                color: zc.textTertiary,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _downloadProgress > 0
                                ? _downloadProgress
                                : null,
                            minHeight: 6,
                            backgroundColor: zc.outline,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(zc.accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _totalBytes > 0
                                  ? '${AppUpdateManager.formatBytes(_receivedBytes)} / ${AppUpdateManager.formatBytes(_totalBytes)}'
                                  : AppUpdateManager.formatBytes(
                                      _receivedBytes),
                              style: TextStyle(
                                  color: zc.textTertiary, fontSize: 11),
                            ),
                            InkWell(
                              onTap: _cancelDownload,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(
                                  l10n.commonCancel,
                                  style: TextStyle(
                                      color: zc.danger, fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              if (_errorMessage != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: zc.danger, fontSize: 12),
                  ),
                ),

              // 底部操作按钮栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    // 跳过此版本 (仅在启动自动检查且未在下载时展示)
                    if (!widget.isManualCheck && !_isDownloading)
                      TextButton(
                        onPressed: _skipThisVersion,
                        style: TextButton.styleFrom(
                          foregroundColor: zc.textTertiary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(l10n.updateSkipThisVersion,
                            style: const TextStyle(fontSize: 13)),
                      ),

                    // 稍后提醒 / 取消
                    if (!_isDownloading)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: zc.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(l10n.updateLater,
                            style: const TextStyle(fontSize: 13)),
                      ),

                    const Spacer(),

                    // 下载并安装 / 立即安装
                    if (!_isDownloading) ...[
                      if (_downloadedApkPath != null)
                        ElevatedButton.icon(
                          onPressed: _installDownloadedApk,
                          icon: const Icon(Icons.install_mobile_rounded,
                              size: 18),
                          label: Text(l10n.updateInstallNow,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: zc.accent,
                            foregroundColor: zc.onAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _startDownload,
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(l10n.updateDownloadAndInstall,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: zc.accent,
                            foregroundColor: zc.onAccent,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                          ),
                        ),
                    ],

                    // 备用浏览器下载图标
                    IconButton(
                      icon: Icon(Icons.open_in_browser,
                          color: zc.textSecondary, size: 20),
                      tooltip: l10n.updateOpenInBrowserTooltip,
                      onPressed: () {
                        CameraNativeBridge.openUrlInBrowser(info.downloadUrl);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
