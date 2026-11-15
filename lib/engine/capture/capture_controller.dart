import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../protocol/camera_driver.dart';
import '../../protocol/ptp_ip_client.dart';
import '../liveview/live_view_controller.dart';

/// 遥控快门控制器。
///
/// 核心约束：**快门是否成功只能靠对象列表里是否出现新 handle 来确认**。
/// `0x100E` 的响应码只说明指令被接受，不说明照片落盘。超时时必须返回
/// [CaptureUnconfirmed] 而不是失败——重试可能连拍两张。
class CaptureController extends ChangeNotifier {
  CaptureController({
    required CameraDriver driver,
    required LiveViewController liveView,
    this.onCaptured,
    this.confirmTimeout = const Duration(seconds: 30),
    this.pollInterval = const Duration(milliseconds: 400),
    Future<void> Function(Duration)? sleep,
  })  : _driver = driver,
        _liveView = liveView,
        _sleep = sleep ?? Future<void>.delayed;

  final CameraDriver _driver;
  final LiveViewController _liveView;
  final Future<void> Function(Duration) _sleep;

  /// 新照片落盘后的回调（通常接到下载队列）。
  final void Function(CameraFileItem file)? onCaptured;

  final Duration confirmTimeout;
  final Duration pollInterval;

  bool _busy = false;
  bool get isBusy => _busy;

  /// 释放快门。
  ///
  /// 前置条件不满足（未连接、基线对象列表读不到）时直接抛异常，
  /// 此时快门**尚未**释放，调用方可以安全重试。
  Future<CaptureOutcome> capture({
    bool enqueue = true,
    bool preserveFocus = false,
  }) async {
    if (!_driver.isConnected) {
      throw StateError('相机未连接');
    }
    if (!_driver.supportsRemoteCapture) {
      return const CaptureRejected(0x2005);
    }
    if (_busy) {
      throw StateError('上一张照片仍在处理中');
    }

    _busy = true;
    notifyListeners();
    try {
      return await _liveView.runExclusive(
        () => _captureExclusive(enqueue, preserveFocus: preserveFocus),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<CaptureOutcome> _captureExclusive(
    bool enqueue, {
    required bool preserveFocus,
  }) async {
    // 基线必须在按快门之前取，否则无法区分新照片和旧照片。
    final before = (await _driver.listObjectHandles()).toSet();

    try {
      await _driver.initiateCapture(preserveFocus: preserveFocus);
    } on PtpException catch (e) {
      return CaptureRejected(e.responseCode);
    }

    final files = await _awaitNewObjects(before);
    if (files.isEmpty) return const CaptureUnconfirmed();

    if (enqueue) {
      for (final file in files) {
        if (!file.isFolder) {
          onCaptured?.call(file);
        }
      }
    }
    // RAW+JPEG 同拍会产生两个对象句柄，优先返回非 RAW (JPEG) 供序列合成与预览使用。
    final primary = files.firstWhere(
      (f) => !f.isFolder && !f.isRaw,
      orElse: () => files.last,
    );
    return CaptureConfirmed(primary);
  }

  /// 同时监听 `ObjectAdded` 事件与轮询对象列表，返回本次快门产生的所有新文件。
  ///
  /// 事件路径更快，但 USB 会话不保证每个固件都推送；轮询路径还能补齐 RAW+JPEG 的伴生文件。
  Future<List<CameraFileItem>> _awaitNewObjects(Set<int> before) async {
    final Map<int, CameraFileItem> found = <int, CameraFileItem>{};
    final subscription = _driver.onPhotoCaptured.listen((file) {
      if (!before.contains(file.handle) && !file.isFolder) {
        found[file.handle] = file;
      }
    });

    try {
      final deadline = DateTime.now().add(confirmTimeout);
      while (DateTime.now().isBefore(deadline)) {
        try {
          final handles = await _driver.listObjectHandles();
          final fresh = handles.where((h) => !before.contains(h)).toList();
          for (final h in fresh) {
            if (found.containsKey(h)) continue;
            final info = await _driver.getObjectInfo(h);
            if (info != null && !info.isFolder && info.size > 0) {
              found[h] = info;
            }
          }
        } catch (_) {
          // 相机写卡期间会短暂拒绝对象查询，继续等即可。
        }

        if (found.isNotEmpty) {
          return found.values.toList(growable: false);
        }

        await _sleep(pollInterval);
      }
      return found.values.toList(growable: false);
    } finally {
      await subscription.cancel();
    }
  }
}
