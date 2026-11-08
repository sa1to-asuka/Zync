import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../protocol/ptp_ip_client.dart';

/// 应用内部的结构化失败类型。
///
/// 传输层与拍摄台抛这个，而不是在抛出的地方拼好中文句子——
/// 这样英文/日文界面看到的是自己的语言，而不是中文异常文本。
class CameraFailure implements Exception {
  final CameraFailureKind kind;

  /// 相机返回的 PTP 响应码（如 0x2019 / 0x200F），没有则为 null。
  final int? responseCode;

  /// 与 [kind] 相关的附加信息：偏移量、文件名、实际/总字节数等。
  final Map<String, Object?> details;

  const CameraFailure(this.kind, {this.responseCode, this.details = const {}});

  @override
  String toString() =>
      'CameraFailure($kind, code: ${responseCode == null ? '-' : '0x${responseCode!.toRadixString(16)}'}, $details)';
}

enum CameraFailureKind {
  disconnected,
  transferInterrupted,
  emptyChunk,
  incomplete,
  saveFailed,
  deviceBusy,
  unsupported,
  accessDenied,
  timeout,
  generic,
}

/// 把各种异常翻译成用户能看懂的本地化文案。
abstract final class CameraErrorMapper {
  /// 从任意异常里抠出 PTP 响应码。
  ///
  /// USB 侧的错误是 `PlatformException`，响应码藏在 message 里的
  /// `0x....` 片段中（例如 `... 响应码 0xa00b`）。
  static int? responseCodeOf(Object error) {
    if (error is CameraFailure) return error.responseCode;
    if (error is PtpException) return error.responseCode;
    if (error is PlatformException) {
      return _codeFromText(error.message ?? '');
    }
    return null;
  }

  /// 从原生报错文本里取响应码。
  ///
  /// 文本里通常**同时**出现操作码和响应码，例如
  /// `PTP USB 操作 0x1016 失败，响应码 0x201c（Unknown）`。
  /// 只取第一个 `0x....` 会拿到操作码，导致「忙 / 不支持」全被误判成通用错误，
  /// 所以优先抓「响应码」后面的那个，取不到再退回最后一个 4 位 hex。
  static int? _codeFromText(String message) {
    final contextual = RegExp(
      r'(?:响应码|返回码|response\s*code|code)\s*[:：=]?\s*0x([0-9a-fA-F]{4})',
      caseSensitive: false,
    ).firstMatch(message);
    if (contextual != null) {
      return int.tryParse(contextual.group(1)!, radix: 16);
    }
    final matches =
        RegExp(r'0x([0-9a-fA-F]{4})').allMatches(message).toList();
    if (matches.isEmpty) return null;
    return int.tryParse(matches.last.group(1)!, radix: 16);
  }

  static bool isDeviceBusy(Object error) => responseCodeOf(error) == 0x2019;

  static bool isOperationUnsupported(Object error) {
    final code = responseCodeOf(error);
    return code == 0x2005 || code == 0x2006;
  }

  static bool isAccessDenied(Object error) => responseCodeOf(error) == 0x200F;

  /// 归一化成 [CameraFailureKind]。
  static CameraFailureKind kindOf(Object error) {
    if (error is CameraFailure) return error.kind;

    final code = responseCodeOf(error);
    switch (code) {
      case 0x2019:
        return CameraFailureKind.deviceBusy;
      case 0x2005:
      case 0x2006:
        return CameraFailureKind.unsupported;
      case 0x200F:
        return CameraFailureKind.accessDenied;
      case 0x2003:
        return CameraFailureKind.disconnected;
    }

    if (error is TimeoutException) return CameraFailureKind.timeout;
    if (error is SocketException) return CameraFailureKind.disconnected;
    return CameraFailureKind.generic;
  }

  /// 生成一句可直接展示给用户的本地化文案。
  static String describe(Object error, AppLocalizations l10n) {
    final kind = kindOf(error);
    final details = error is CameraFailure ? error.details : const {};

    switch (kind) {
      case CameraFailureKind.disconnected:
        return l10n.errDisconnected;
      case CameraFailureKind.transferInterrupted:
        return l10n.errTransferInterrupted;
      case CameraFailureKind.emptyChunk:
        return l10n.errTransferEmptyChunk(_int(details['offset']));
      case CameraFailureKind.incomplete:
        return l10n.errTransferIncomplete(
          _int(details['actual']),
          _int(details['total']),
        );
      case CameraFailureKind.saveFailed:
        return l10n.errSaveToGalleryFailed(
            details['fileName']?.toString() ?? '');
      case CameraFailureKind.deviceBusy:
        return l10n.errDeviceBusy;
      case CameraFailureKind.unsupported:
        return l10n.errOperationNotSupported;
      case CameraFailureKind.accessDenied:
        return l10n.errAccessDenied;
      case CameraFailureKind.timeout:
        return l10n.errTimeout;
      case CameraFailureKind.generic:
        return l10n.errGeneric;
    }
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
