import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/constants/ptp_opcodes.dart';
import 'ptp_packet.dart';

/// 判断相机 `GetDeviceInfo (0x1001)` 返回的操作码列表是否处于 STA 首次配对受限态。
///
/// 实机（如 Nikon Z f / Z 6III / Z 50II / Z 30 新固件）在「连接到计算机 → 创建配置文件」
/// 等待配对界面时，虽允许建立 TCP 15740 与 `OpenSession`，但仅开放有限命令：
/// 包含 `0x952B`（读取配对挑战码）与 `0x935A`（确认配对），且不开放实时取景命令。
bool isRestrictedStaPairingProfile(List<int> operations) {
  if (operations.isEmpty) return false;
  final hasPairingOps = operations.contains(PtpOpCodes.nikonGetPairingInfo) &&
      operations.contains(PtpOpCodes.nikonConfirmPairing);
  if (!hasPairingOps) return false;
  final hasLiveViewOps = operations.contains(PtpOpCodes.nikonStartLiveView) ||
      operations.contains(PtpOpCodes.nikonGetLiveViewImage) ||
      operations.contains(PtpOpCodes.nikonGetLiveViewImageEx);
  return !hasLiveViewOps;
}

/// 尼康 STA 无线配对验证码（`0x952B` 返回载荷）解析结果。
class NikonPairingChallenge {
  final Uint8List rawBytes;
  final String? pin;
  final String? cameraName;

  const NikonPairingChallenge({
    required this.rawBytes,
    this.pin,
    this.cameraName,
  });

  /// 是否有已解码的 4 位数字验证码。
  bool get hasPin => pin != null && pin!.length == 4;

  /// 原始字节的十六进制摘要，供未知固件格式兜底核对或日志诊断。
  String get rawHex =>
      rawBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

  /// 从 `0x952B` 响应载荷中容错提取 4 位数字配对码。
  static NikonPairingChallenge parse(
    Uint8List data, {
    String? cameraName,
  }) {
    final raw = Uint8List.fromList(data);
    return NikonPairingChallenge(
      rawBytes: raw,
      pin: _extractPin(raw),
      cameraName: cameraName,
    );
  }
}

String? _extractPin(Uint8List data) {
  if (data.isEmpty) return null;
  return _pinFromTailByteDigits(data) ??
      _pinFromLengthPrefixedByteDigits(data) ??
      _pinFromAscii(data) ??
      _pinFromUtf16(data, Endian.little) ??
      _pinFromUtf16(data, Endian.big) ??
      _pinFromLengthPrefixedBcd(data) ??
      _pinFromLengthPrefixedNumber(data) ??
      _pinFromStandaloneNumber(data) ??
      _pinFromBcd(data);
}

String? _pinFromTailByteDigits(Uint8List data) {
  if (data.length < 4) return null;
  final tail = data.sublist(data.length - 4);
  if (tail.every((b) => b >= 0 && b <= 9)) {
    if (data.length > 4 && tail.every((b) => b == 0)) return null;
    return tail.join();
  }
  return null;
}

String? _pinFromLengthPrefixedByteDigits(Uint8List data) {
  for (final start in _lengthPrefixedStarts(data)) {
    if (start + 4 > data.length) continue;
    final digits = data.sublist(start, start + 4);
    if (digits.every((d) => d <= 9)) return digits.join();
  }
  return null;
}

String? _pinFromAscii(Uint8List data) {
  final chars = <int>[];
  for (final b in data) {
    chars.add((b >= 0x20 && b <= 0x7E) ? b : 0x20);
  }
  final text = String.fromCharCodes(chars);
  return RegExp(r'(?<!\d)(\d{4})(?!\d)').firstMatch(text)?.group(1);
}

String? _pinFromUtf16(Uint8List data, Endian endian) {
  if (data.length < 8) return null;
  for (var start = 0; start < 2; start++) {
    final buf = StringBuffer();
    for (var i = start; i + 1 < data.length; i += 2) {
      final unit = endian == Endian.little
          ? (data[i] | (data[i + 1] << 8))
          : ((data[i] << 8) | data[i + 1]);
      if (unit >= 0x30 && unit <= 0x39) {
        buf.writeCharCode(unit);
      } else {
        buf.write(' ');
      }
    }
    final match = RegExp(r'(?<!\d)(\d{4})(?!\d)').firstMatch(buf.toString());
    if (match != null) return match.group(1);
  }
  return null;
}

String? _pinFromLengthPrefixedBcd(Uint8List data) {
  for (final start in _lengthPrefixedStarts(data)) {
    final pin = _bcdAt(data, start);
    if (pin != null) return pin;
  }
  return null;
}

String? _pinFromLengthPrefixedNumber(Uint8List data) {
  for (final start in _lengthPrefixedStarts(data)) {
    final pin = _numberAt(data, start);
    if (pin != null) return pin;
  }
  return null;
}

String? _pinFromStandaloneNumber(Uint8List data) {
  if (data.length != 2 && data.length != 4) return null;
  return _numberAt(data, 0);
}

String? _pinFromBcd(Uint8List data) {
  for (var i = 0; i + 1 < data.length; i++) {
    final pin = _bcdAt(data, i);
    if (pin != null) return pin;
  }
  return null;
}

List<int> _lengthPrefixedStarts(Uint8List data) {
  final starts = <int>[];
  final bd = ByteData.sublistView(data);
  if (data.length > 4 && bd.getUint32(0, Endian.little) == 4) {
    starts.add(4);
  } else if (data.length > 2 && bd.getUint16(0, Endian.little) == 4) {
    starts.add(2);
  }
  return starts;
}

String? _bcdAt(Uint8List data, int start) {
  if (start + 1 >= data.length) return null;
  final a = data[start];
  final b = data[start + 1];
  if (a == 0 && b == 0) return null;
  final digits = <int>[a >> 4, a & 0x0F, b >> 4, b & 0x0F];
  if (!digits.every((d) => d <= 9)) return null;
  return digits.join();
}

String? _numberAt(Uint8List data, int start) {
  final bd = ByteData.sublistView(data);
  if (start + 2 <= data.length) {
    final v16 = bd.getUint16(start, Endian.little);
    if (v16 >= 1000 && v16 <= 9999) {
      return v16.toString().padLeft(4, '0');
    }
  }
  if (start + 4 <= data.length) {
    final v32 = bd.getUint32(start, Endian.little);
    if (v32 >= 1000 && v32 <= 9999) {
      return v32.toString().padLeft(4, '0');
    }
  }
  return null;
}

/// STA 局域网自动查找未命中时的类型化原因。
enum StaScanMissReason {
  onCameraAccessPoint,
  noLocalNetwork,
  hostsVisibleNoPtp,
  silentOrIsolatedNetwork,
  cameraNotFound,
}

/// 根据当前网络环境与扫描快照给出最精准的未命中原因。
StaScanMissReason diagnoseStaScanMiss({
  required String staSubMode,
  required bool wifiConnected,
  required String wifiSsid,
  required String wifiGateway,
  required List<String> scannedSubnets,
  required bool hasHotspotInterface,
  required int respondingPeerCount,
}) {
  final ssidUpper = wifiSsid.trim().toUpperCase();
  final looksLikeCameraAp = wifiConnected &&
      (ssidUpper.startsWith('NIKON') ||
          ssidUpper.contains('NIKON_') ||
          wifiGateway == '192.168.0.1');
  if (looksLikeCameraAp && staSubMode == 'router') {
    return StaScanMissReason.onCameraAccessPoint;
  }

  if (scannedSubnets.isEmpty) {
    return StaScanMissReason.noLocalNetwork;
  }
  if (staSubMode == 'router' && !wifiConnected && !hasHotspotInterface) {
    return StaScanMissReason.noLocalNetwork;
  }
  if (staSubMode == 'hotspot' && !hasHotspotInterface && !wifiConnected) {
    return StaScanMissReason.noLocalNetwork;
  }

  if (respondingPeerCount > 0) {
    return StaScanMissReason.hostsVisibleNoPtp;
  }

  if (staSubMode == 'router' && wifiConnected && respondingPeerCount == 0) {
    return StaScanMissReason.silentOrIsolatedNetwork;
  }

  return StaScanMissReason.cameraNotFound;
}

/// 向已确认开放 15740 端口的主机发送一次轻量 `Init_Command_Request` 读取相机展示名，
/// 读取后立即关闭连接（不绑定事件通道，不开启 PTP 会话）。
Future<String?> probePtpCameraName(
  String host, {
  int port = 15740,
  Duration timeout = const Duration(milliseconds: 900),
  Duration postConnectSettle = const Duration(milliseconds: 120),
  Uint8List? clientGuid,
  String clientName = 'Zync',
}) async {
  Socket? socket;
  final completer = Completer<String?>();
  final buffer = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? sub;

  try {
    socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    if (postConnectSettle > Duration.zero) {
      await Future<void>.delayed(postConnectSettle);
    }

    sub = socket.listen(
      (chunk) {
        buffer.add(chunk);
        final bytes = buffer.toBytes();
        final packet = PtpPacket.parse(bytes);
        if (packet == null) return;
        if (packet.type == PtpOpCodes.ptpIpInitCommandAck) {
          try {
            final ack = PtpIpInitAck.parse(packet);
            final name = ack.cameraName.trim();
            if (!completer.isCompleted) {
              completer.complete(name.isNotEmpty ? name : null);
            }
          } catch (_) {
            if (!completer.isCompleted) completer.complete(null);
          }
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete(null);
      },
      cancelOnError: true,
    );

    final req = PtpPacket.buildInitCommandRequest(
      clientName: clientName,
      guid: clientGuid,
    );
    socket.add(req.toBytes());

    return await completer.future.timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  } finally {
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      socket?.destroy();
    } catch (_) {}
  }
}
