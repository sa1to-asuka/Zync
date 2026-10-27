import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'video_project.dart';

/// 按源视频路径 + 文件大小 + 修改时间生成稳定键，自动保存视频工程。
class VideoProjectStore {
  static Future<String> _projectKey(String sourcePath) async {
    final file = File(sourcePath);
    final stat = await file.stat();
    final raw =
        '${file.absolute.path}|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static Future<File> _projectFile(String sourcePath) async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/video_projects');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/${await _projectKey(sourcePath)}.json');
  }

  static Future<VideoProject?> load(String sourcePath) async {
    try {
      final file = await _projectFile(sourcePath);
      if (!await file.exists()) return null;
      final source = await file.readAsString();
      if (source.trim().isEmpty) return null;
      return VideoProject.fromJsonString(source);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String sourcePath, VideoProject project) async {
    try {
      final file = await _projectFile(sourcePath);
      await file.writeAsString(project.toJsonString(), flush: true);
    } catch (_) {
      // 自动保存失败不能影响编辑和导出。
    }
  }

  static Future<void> clear(String sourcePath) async {
    try {
      final file = await _projectFile(sourcePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
