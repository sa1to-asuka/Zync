import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../core/constants/ptp_opcodes.dart';
import 'camera_native_bridge.dart';
import 'ptp_ip_client.dart' show PtpException;
import 'ptp_packet.dart';
import 'ptp_transport.dart';

/// USB (PTP over OTG) 传输实现：把标准 PTP 容器经由平台通道转发给原生
/// `UsbPtpSession`（Android USB Host API + Bulk-Only 传输），与 Wi-Fi 的
/// [PtpIpClient] 共用同一套上层业务逻辑。
class UsbPtpTransport implements PtpTransport {
  final String deviceName;
  final void Function(String message)? onLog;

  static const EventChannel _usbEventChannel = EventChannel(
    'com.zync.app/usb_events',
  );

  UsbPtpTransport({required this.deviceName, this.onLog});

  String? _deviceId;
  bool _connected = false;
  StreamSubscription<dynamic>? _nativeEventSubscription;
  final StreamController<PtpPacket> _eventController =
      StreamController<PtpPacket>.broadcast();

  /// 原生 UsbPtpSession 不允许并发 bulk 请求；缩略图、属性查询与分块下载
  /// 必须串行进入同一条 USB 会话。
  Future<void> _pending = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  @override
  bool get isConnected => _connected && _deviceId != null;

  @override
  Stream<PtpPacket> get events => _eventController.stream;

  String? get deviceId => _deviceId;

  @override
  Future<void> connect() async {
    onLog?.call('USB: 请求设备访问权限...');
    final granted = await CameraNativeBridge.requestUsbPermission(deviceName);
    if (!granted) {
      throw StateError('USB 授权被拒绝或超时');
    }
    onLog?.call('USB: 认领接口并建立 PTP 会话 (OpenSession)...');
    final id = await CameraNativeBridge.usbOpenSession(deviceName);
    if (id == null || id.isEmpty) {
      throw StateError('USB PTP 会话建立失败');
    }
    _deviceId = id;
    _connected = true;
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = _usbEventChannel.receiveBroadcastStream().listen(
          _handleNativeEvent,
          onError: (Object error) => onLog?.call('USB 事件通道异常: $error'),
        );
    onLog?.call('USB PTP 会话已建立: $id');
  }

  @override
  Future<void> disconnect() async {
    final id = _deviceId;
    _connected = false;
    _deviceId = null;
    await _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
    if (id != null) {
      await CameraNativeBridge.usbCloseSession(id);
    }
    onLog?.call('USB PTP 会话已关闭');
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) return;
    final name = event['deviceName']?.toString() ?? '';
    if (name.isNotEmpty && name != deviceName) return;
    final raw = event['data'];
    if (raw is! Uint8List || raw.length < 12) return;
    final length = ByteData.sublistView(raw, 0, 4).getUint32(0, Endian.little);
    if (length < 12 || length > raw.length) return;
    final type = ByteData.sublistView(raw, 4, 6).getUint16(0, Endian.little);
    if (type != 4) return;
    final payload = Uint8List.fromList(raw.sublist(6, length));
    _eventController.add(PtpPacket(
      length: payload.length + 8,
      type: PtpOpCodes.ptpIpEvent,
      payload: payload,
    ));
  }

  /// 原生层用 `PlatformException(code: 'USB_*', message: '... 0xXXXX ...')`
  /// 回报 PTP 响应码。上层（驱动、控制器）统一按 [PtpException] 判断能力与重试，
  /// 所以在这里做一次归一化，否则 USB 下的「忙 / 不支持」永远识别不出来。
  Future<T> _translate<T>(int opCode, Future<T> Function() action) {
    return _serialize(() async {
      try {
        return await action();
      } on PlatformException catch (e) {
        final code = _responseCodeOf(e.message);
        if (code != null) {
          throw PtpException(opCode, code, e.message ?? e.code);
        }
        rethrow;
      }
    });
  }

  /// 文本里可能同时有操作码和响应码，优先取「响应码」后面的那个。
  static int? _responseCodeOf(String? message) {
    if (message == null || message.isEmpty) return null;
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

  String get _requireId {
    final id = _deviceId;
    if (id == null) throw StateError('USB 会话未建立');
    return id;
  }

  @override
  Future<void> executeOperation(int opCode, [List<int> params = const []]) {
    return _translate(
        opCode,
        () => CameraNativeBridge.usbExecuteOperation(
            _requireId, opCode, params));
  }

  @override
  Future<Uint8List> executeDataIn(int opCode, [List<int> params = const []]) {
    return _translate(
        opCode,
        () => CameraNativeBridge.usbExecuteDataIn(
            _requireId, opCode, params));
  }

  @override
  Future<void> executeDataOut(int opCode, Uint8List data,
      [List<int> params = const []]) {
    return _translate(
        opCode,
        () => CameraNativeBridge.usbExecuteDataOut(
            _requireId, opCode, data, params));
  }

  void dispose() {
    _eventController.close();
  }
}
