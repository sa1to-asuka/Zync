import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../core/constants/ptp_opcodes.dart';
import '../core/settings/app_settings.dart';
import '../core/utils/app_log_manager.dart';
import '../core/utils/byte_buffer_ext.dart';
import '../core/utils/camera_error_mapper.dart';
import '../engine/capture/camera_folder_controller.dart';
import '../engine/capture/camera_hdr_controller.dart';
import '../engine/capture/movie_recording_controller.dart';
import '../engine/capture/ptp_device_prop_desc.dart';
import '../engine/picture_control/np3_codec.dart';
import 'camera_driver.dart';
import 'camera_io_coordinator.dart';
import 'camera_native_bridge.dart';
import 'nikon_sta_pairing.dart';
import 'ptp_ip_client.dart';
import 'ptp_transport.dart';
import 'usb_ptp_transport.dart';
import 'ptp_packet.dart';

/// 何时必须走 64 位分块读取。
///
/// `0x101B GetPartialObject` 的偏移量与长度都是 32 位无符号数，
/// 一旦请求区间跨过 4GiB 边界就会被截断，大视频会静默损坏。
bool requiresPartialObject64(int offset, int maxBytes) =>
    offset > 0xFFFFFFFF || (offset + maxBytes) > 0xFFFFFFFF;

/// 尼康 PTP 设备信息完整描述实体 (0x1001 GetDeviceInfo)
/// 数据集布局遵循 ISO 15740 / PIMA 15740。
class NikonDeviceInfo {
  final int standardVersion;
  final int vendorExtensionId;
  final int vendorExtensionVersion;
  final String vendorExtensionDesc;
  final int functionalMode;
  final List<int> operationsSupported;
  final List<int> eventsSupported;
  final List<int> devicePropertiesSupported;
  final List<int> captureFormats;
  final List<int> playbackFormats;
  final String manufacturer;
  final String model;
  final String deviceVersion;
  final String serialNumber;

  const NikonDeviceInfo({
    this.standardVersion = 100,
    this.vendorExtensionId = 0,
    this.vendorExtensionVersion = 0,
    this.vendorExtensionDesc = '',
    this.functionalMode = 0,
    this.operationsSupported = const [],
    this.eventsSupported = const [],
    this.devicePropertiesSupported = const [],
    this.captureFormats = const [],
    this.playbackFormats = const [],
    this.manufacturer = 'Nikon Corporation',
    this.model = 'Nikon Camera',
    this.deviceVersion = '',
    this.serialNumber = '',
  });

  /// 从 PTP 二进制数据流中反序列化 DeviceInfo 数据集
  static NikonDeviceInfo parse(Uint8List data) {
    if (data.length < 16) return const NikonDeviceInfo();

    try {
      final reader = PtpByteReader(data);
      final standardVersion = reader.readUint16();
      final vendorExtensionId = reader.readUint32();
      final vendorExtensionVersion = reader.readUint16();
      final vendorExtensionDesc = reader.readPtpString();
      final functionalMode = reader.readUint16();

      final operations = reader.readUint16Array();
      final events = reader.readUint16Array();
      final deviceProperties = reader.readUint16Array();
      final captureFormats = reader.readUint16Array();
      final playbackFormats = reader.readUint16Array();

      final manufacturer = reader.readPtpString();
      final model = reader.readPtpString();
      final deviceVersion = reader.readPtpString();
      final serialNumber = reader.readPtpString();

      if (model.trim().isNotEmpty && model.trim() != 'Nikon Camera') {
        return NikonDeviceInfo(
          standardVersion: standardVersion,
          vendorExtensionId: vendorExtensionId,
          vendorExtensionVersion: vendorExtensionVersion,
          vendorExtensionDesc: vendorExtensionDesc,
          functionalMode: functionalMode,
          operationsSupported: operations,
          eventsSupported: events,
          devicePropertiesSupported: deviceProperties,
          captureFormats: captureFormats,
          playbackFormats: playbackFormats,
          manufacturer:
              manufacturer.isNotEmpty ? manufacturer : 'Nikon Corporation',
          model: normalizeModelName(model),
          deviceVersion: deviceVersion.trim(),
          serialNumber: serialNumber.trim(),
        );
      }
    } catch (_) {
      // 容错: 若特定机型字符串偏移不同，进入备用扫描
    }

    // 备用启发式扫描: 遍历数据负载中合法的 PTP UTF-16LE 字符串
    String matchedModel = 'Nikon Camera';
    String matchedSerial = '';
    String matchedVersion = '';
    try {
      for (var i = 0; i < data.length - 4; i++) {
        final len = data[i];
        if (len >= 3 && len <= 32 && i + 1 + len * 2 <= data.length) {
          final chars = <int>[];
          var validUtf16 = true;
          for (var j = 0; j < len; j++) {
            final c = data[i + 1 + j * 2] | (data[i + 2 + j * 2] << 8);
            if (j == len - 1) {
              if (c != 0) validUtf16 = false; // 结尾必须是 0x0000
            } else if (c < 32 || c > 126) {
              validUtf16 = false;
              break;
            } else {
              chars.add(c);
            }
          }
          if (validUtf16 && chars.isNotEmpty) {
            final s = String.fromCharCodes(chars).trim();
            final lower = s.toLowerCase();
            if (lower.contains('corporation')) continue;

            // 匹配尼康型号 (例如: NIKON Z 30, NIKON Z 8, NIKON Z 6_2, NIKON Z fc, NIKON D850)
            if (matchedModel == 'Nikon Camera' &&
                RegExp(r'^(NIKON\s+[A-Za-z0-9_\-\s]+|NIKON_[A-Za-z0-9_]+|Z\s*[0-9]+[A-Za-z_]*|D[0-9]{3,4}[A-Za-z]*)$',
                        caseSensitive: false)
                    .hasMatch(s)) {
              matchedModel = normalizeModelName(s);
            } else if (matchedVersion.isEmpty &&
                RegExp(r'^[0-9]\.[0-9]{2}(\.[0-9]+)?$').hasMatch(s)) {
              matchedVersion = s;
            } else if (matchedSerial.isEmpty &&
                RegExp(r'^[0-9]{6,10}$').hasMatch(s)) {
              matchedSerial = s;
            }
          }
        }
      }
    } catch (_) {}

    // 备用 ASCII 连续字符串探测 (部分固件在 DeviceInfo 中写入 ASCII 码)
    if (matchedModel == 'Nikon Camera') {
      try {
        final asciiChars = <int>[];
        for (final b in data) {
          if (b >= 32 && b <= 126) {
            asciiChars.add(b);
          } else {
            asciiChars.add(32);
          }
        }
        final asciiStr = String.fromCharCodes(asciiChars);
        final match = RegExp(
                r'(NIKON\s+Z\s*[0-9]+[A-Za-z_]*|NIKON\s+Z\s*fc|NIKON\s+D[0-9]{3,4}[A-Za-z]*|Z\s*[0-9]+[A-Za-z_]*|Z\s*fc)',
                caseSensitive: false)
            .firstMatch(asciiStr);
        if (match != null) {
          matchedModel = normalizeModelName(match.group(0)!);
        }
      } catch (_) {}
    }

    return NikonDeviceInfo(
      model: normalizeModelName(matchedModel),
      serialNumber: matchedSerial,
      deviceVersion: matchedVersion,
    );
  }

  /// 尼康全系列型号归一化处理器
  static String normalizeModelName(String model) {
    final m = model.trim();
    final upper = m.toUpperCase();
    if (upper.contains('Z 30') ||
        upper.contains('Z30') ||
        upper.contains('Z_30')) return 'NIKON Z 30';
    if (upper.contains('Z 50_2') ||
        upper.contains('Z50_2') ||
        upper.contains('Z 50II') ||
        upper.contains('Z50II')) return 'NIKON Z50II';
    if (upper.contains('Z 50') ||
        upper.contains('Z50') ||
        upper.contains('Z_50')) return 'NIKON Z 50';
    if (upper.contains('Z FC') ||
        upper.contains('ZFC') ||
        upper.contains('Z_FC')) return 'NIKON Z fc';
    if (upper.contains('Z F') ||
        upper.contains('Z_F') ||
        RegExp(r'\bZF\b').hasMatch(upper)) return 'NIKON Z f';
    if (upper.contains('ZR') || upper.contains('Z R') || upper.contains('Z_R'))
      return 'NIKON ZR';
    if (upper.contains('Z 8') || upper.contains('Z8') || upper.contains('Z_8'))
      return 'NIKON Z 8';
    if (upper.contains('Z 9') || upper.contains('Z9') || upper.contains('Z_9'))
      return 'NIKON Z 9';
    if (upper.contains('Z 6_3') ||
        upper.contains('Z6_3') ||
        upper.contains('Z6III') ||
        upper.contains('Z 6III')) return 'NIKON Z 6III';
    if (upper.contains('Z 6_2') ||
        upper.contains('Z6_2') ||
        upper.contains('Z6II') ||
        upper.contains('Z 6II')) return 'NIKON Z 6II';
    if (upper.contains('Z 6') || upper.contains('Z6') || upper.contains('Z_6'))
      return 'NIKON Z 6';
    if (upper.contains('Z 7_2') ||
        upper.contains('Z7_2') ||
        upper.contains('Z7II') ||
        upper.contains('Z 7II')) return 'NIKON Z 7II';
    if (upper.contains('Z 7') || upper.contains('Z7') || upper.contains('Z_7'))
      return 'NIKON Z 7';
    if (upper.contains('Z 5_2') ||
        upper.contains('Z5_2') ||
        upper.contains('Z 5II') ||
        upper.contains('Z5II')) return 'NIKON Z5II';
    if (upper.contains('Z 5') || upper.contains('Z5') || upper.contains('Z_5'))
      return 'NIKON Z 5';
    if (upper.contains('D850')) return 'NIKON D850';
    if (upper.contains('D780')) return 'NIKON D780';
    if (upper.contains('D750')) return 'NIKON D750';
    if (upper.contains('D500')) return 'NIKON D500';
    return m.isEmpty ? 'Nikon Camera' : m;
  }
}

/// 尼康专属相机硬件协议驱动。
/// Nikon 扩展操作码与设备属性读取。
class NikonDriver
    implements CameraDriver, MovieRecordingDriver, HdrDriver, CameraFolderDriver {
  PtpTransport? _client;
  CameraConnectionState _state = CameraConnectionState.disconnected;
  String _cameraModel = 'Nikon Camera';
  int _batteryLevel = 100;
  NikonDeviceInfo _deviceInfo = const NikonDeviceInfo();
  void Function(String msg)? _logCallback;

  final StreamController<CameraFileItem> _photoCapturedController =
      StreamController<CameraFileItem>.broadcast();
  final StreamController<CameraConnectionState> _stateController =
      StreamController<CameraConnectionState>.broadcast();

  /// 相机事件码广播（0x4002 / 0xC108 等），录像封盘确认要用。
  final StreamController<int> _eventCodeController =
      StreamController<int>.broadcast();

  /// 相机端删除对象事件（0x4003 ObjectRemoved）广播句柄，供相册即时同步移除。
  final StreamController<int> _objectRemovedController =
      StreamController<int>.broadcast();

  List<int> _detectedStorageIds = [];
  final Map<int, CameraFileItem> _objectInfoCache = {};
  final Map<int, Uint8List> _thumbCache = {};
  final Set<int> _knownFileHandles = <int>{};
  final Set<int> _knownFolderHandles = <int>{};
  final Map<int, ({int format, String ext})> _handlePrefixFormatCache =
      <int, ({int format, String ext})>{};
  int _consecutiveObjectInfoAccessDenied = 0;
  int _objectInfoFailLogCount = 0;
  int _mediaTransferLogCount = 0;
  bool _preferPartialObject64 = false;
  int _partialObject64ParamCount = 5;

  void _logMediaTransferFailure(String detail) {
    if (_mediaTransferLogCount >= 12) return;
    _mediaTransferLogCount++;
    _log('[media] $detail');
  }

  /// 清空当前会话的媒体元信息与缩略图缓存（手动刷新相册时使用，防止句柄复用返回旧图）。
  void clearMediaCaches() {
    _objectInfoCache.clear();
    _thumbCache.clear();
    _knownFileHandles.clear();
    _objectInfoFailLogCount = 0;
    _mediaTransferLogCount = 0;
    _consecutiveObjectInfoAccessDenied = 0;
  }

  void _log(String msg) {
    final cb = _logCallback;
    if (cb != null) {
      cb(msg);
    } else {
      AppLogManager.instance.add(msg);
    }
  }

  final CameraIoCoordinator _io = CameraIoCoordinator();
  CameraTransportKind _transportKind = CameraTransportKind.wifi;
  bool _liveViewActive = false;

  // ---- 自动重连与 STA 配对状态支持 ----
  /// 断开后再次发起 TCP PTP/IP Init 前的最小冷却时间，防止相机单会话槽位未释放而卡死。
  static const Duration reconnectSettleDuration = Duration(milliseconds: 1200);

  String? _lastWifiHost;
  int _lastWifiPort = 15740;
  String? _lastWifiRouteMode;
  String? _lastUsbDeviceName;
  bool _lastWasUsb = false;
  bool _isRestrictedPairingSession = false;
  DateTime? _lastDisconnectAt;
  StreamSubscription<PtpPacket>? _eventSub;

  /// 非用户主动断开（掉线 / USB 拔出 / 网络丢失）时回调一次。
  void Function()? onUnexpectedDisconnect;

  /// 用户是否正在主动断开；主动断开不触发重连。
  bool _userDisconnect = false;

  /// 配对等流程自己管理连接生命周期时，屏蔽自动重连控制器，
  /// 避免相机在配对中途关连接时上层同时发起重连。
  bool _recoverySuppressed = false;

  void setRecoverySuppressed(bool value) {
    _recoverySuppressed = value;
  }

  /// 当前会话是否处于 STA 首次配对的受限能力态（仅开放 0x952B / 0x935A，尚未开放取景与常规控制）。
  bool get isRestrictedPairingSession => _isRestrictedPairingSession;

  /// 设备信息查询完成信号。
  ///
  /// `connected` 状态会在 GetDeviceInfo 之前就发出，此时还不知道相机是否
  /// 处于受限配对态。依赖存储卡/属性的调用方应等待该 Future 再动手。
  Completer<void>? _sessionInfoCompleter;

  Future<void> get sessionInfoReady =>
      _sessionInfoCompleter?.future ?? Future<void>.value();

  void _beginSessionInfo() {
    _sessionInfoCompleter = Completer<void>();
  }

  void _completeSessionInfo() {
    final c = _sessionInfoCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// 当前 PTP/IP 会话的事件通道是否可用（部分机身事件通道被拒时降级为纯命令通道）。
  bool get eventsAvailable {
    final c = _client;
    if (c is PtpIpClient) return c.eventsAvailable;
    return isConnected;
  }

  /// 上次成功连接的 Wi-Fi 目标，自动重连探活要用真实地址。
  String? get lastWifiHost => _lastWifiHost;
  int get lastWifiPort => _lastWifiPort;
  String? get lastWifiRouteMode => _lastWifiRouteMode;

  /// 重连目标是否仍然存在。
  bool get canReconnect =>
      _lastWasUsb ? _lastUsbDeviceName != null : _lastWifiHost != null;

  /// 上次连接是否走 USB；重连探活只对 Wi-Fi 有意义。
  bool get lastConnectionWasUsb => _lastWasUsb;

  /// 用上次成功的连接目标重建会话。
  Future<void> reconnect({void Function(String msg)? onLog}) async {
    if (_lastWasUsb) {
      final name = _lastUsbDeviceName;
      if (name == null) throw StateError('没有可重连的 USB 设备');
      await connectUsb(name, onLog: onLog);
    } else {
      final host = _lastWifiHost;
      if (host == null) throw StateError('没有可重连的 Wi-Fi 目标');
      await connect(
        host,
        port: _lastWifiPort,
        onLog: onLog,
        routeMode: _lastWifiRouteMode,
      );
    }
  }

  /// 会话内已被相机明确拒绝 (0x2005) 的操作码，避免逐帧重复尝试。
  final Set<int> _unsupportedOps = <int>{};

  /// 是否已通过 0x9435 进入尼康 Application Mode（录像期间置 true，停止后退回 0）。
  bool _inMovieAppMode = false;

  /// STA 读卡时是否已尝试进入 Application Mode（每个会话只尝试一次）。
  bool _staAppModeEnabled = false;

  /// 重建取景会话期间的门闩，防止后台取景拉帧在 0x9202->0x9201 空窗期插入 0x9203。
  Future<void>? _liveViewCycleGate;

  /// 属性描述块缓存（用于判定属性字节宽度与枚举值）。
  final Map<int, PtpDevicePropDesc> _propDescCache = <int, PtpDevicePropDesc>{};

  @override
  CameraConnectionState get state => _state;

  @override
  Stream<CameraConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  bool get isConnected =>
      _state == CameraConnectionState.connected &&
      (_client?.isConnected ?? false);

  @override
  String get cameraModel => _cameraModel;

  @override
  int get batteryLevel => _batteryLevel;

  @override
  List<int> get availableStorageIds => List.unmodifiable(_detectedStorageIds);

  @override
  bool get isSingleSlotCamera {
    final m = _cameraModel.toUpperCase();
    if (m.contains('Z 30') ||
        m.contains('Z30') ||
        m.contains('Z 50') ||
        m.contains('Z50') ||
        m.contains('Z FC') ||
        m.contains('ZFC') ||
        m.contains('COOLPIX') ||
        m.contains('D3') ||
        m.contains('D5')) {
      return true;
    }
    if (_detectedStorageIds.isNotEmpty && _detectedStorageIds.length <= 1) {
      return true;
    }
    return false;
  }

  NikonDeviceInfo get deviceInfo => _deviceInfo;

  @override
  Stream<CameraFileItem> get onPhotoCaptured => _photoCapturedController.stream;

  /// 相机端删除照片事件流（发射被移除的 ObjectHandle）。
  Stream<int> get onObjectRemoved => _objectRemovedController.stream;

  @override
  Future<void> connect(
    String host, {
    int port = 15740,
    void Function(String msg)? onLog,
    String? routeMode,
    Duration postConnectSettle = const Duration(milliseconds: 300),
    bool allowEventChannelFallback = true,
  }) {
    return _connectPtp(
      host,
      port: port,
      onLog: onLog,
      routeMode: routeMode,
      postConnectSettle: postConnectSettle,
      allowEventChannelFallback: allowEventChannelFallback,
    );
  }

  Future<void> _connectPtp(
    String host, {
    required int port,
    void Function(String msg)? onLog,
    String? routeMode,
    Duration postConnectSettle = const Duration(milliseconds: 300),
    bool allowEventChannelFallback = true,
  }) async {
    if (onLog != null) _logCallback = onLog;
    _userDisconnect = false;
    _isRestrictedPairingSession = false;
    _staAppModeEnabled = false;
    _knownFileHandles.clear();
    _knownFolderHandles.clear();
    _handlePrefixFormatCache.clear();
    _consecutiveObjectInfoAccessDenied = 0;
    _objectInfoFailLogCount = 0;
    _mediaTransferLogCount = 0;
    _preferPartialObject64 = false;
    _partialObject64ParamCount = 5;
    _beginSessionInfo();
    _lastWifiHost = host;
    _lastWifiPort = port;
    _lastWifiRouteMode = routeMode;
    _lastWasUsb = false;
    _state = CameraConnectionState.connecting;
    _stateController.add(_state);

    // 若刚断开连接不久，等待相机释放单会话槽位（配对完成后重连尤为关键）。
    final lastDisc = _lastDisconnectAt;
    if (lastDisc != null && postConnectSettle > Duration.zero) {
      final elapsed = DateTime.now().difference(lastDisc);
      if (elapsed < reconnectSettleDuration) {
        final wait = reconnectSettleDuration - elapsed;
        onLog?.call('等待相机释放上一会话槽位 (${wait.inMilliseconds}ms) ...');
        await Future<void>.delayed(wait);
      }
    }

    PtpIpClient? client;
    try {
      // 优先从当前 Wi-Fi SSID 嗅探机型
      try {
        final wifi = await CameraNativeBridge.getWifiInfo();
        final ssidUpper = wifi.ssid.toUpperCase();
        if (ssidUpper.contains('Z_30') ||
            ssidUpper.contains('Z30') ||
            ssidUpper.contains('Z 30')) {
          _cameraModel = 'NIKON Z 30';
        } else if (ssidUpper.contains('Z_50') ||
            ssidUpper.contains('Z50') ||
            ssidUpper.contains('Z 50')) {
          _cameraModel = 'NIKON Z 50';
        } else if (ssidUpper.contains('Z_FC') || ssidUpper.contains('ZFC')) {
          _cameraModel = 'NIKON Z fc';
        } else if (ssidUpper.contains('Z_8') || ssidUpper.contains('Z8')) {
          _cameraModel = 'NIKON Z 8';
        } else if (ssidUpper.contains('Z_9') || ssidUpper.contains('Z9')) {
          _cameraModel = 'NIKON Z 9';
        } else if (ssidUpper.contains('D850')) {
          _cameraModel = 'NIKON D850';
        }
      } catch (_) {}

      try {
        await CameraNativeBridge.bindCameraWifi(
          targetHost: host,
          mode: routeMode,
        );
      } catch (_) {}

      client = PtpIpClient(
        host: host,
        port: port,
        onLog: onLog,
        clientGuid: AppSettings.instance.ptpClientGuidBytes,
        postConnectSettle: postConnectSettle,
        allowEventChannelFallback: allowEventChannelFallback,
      );
      _client = client;
      client.onUnexpectedDisconnect = _notifyUnexpectedDisconnect;
      await client.connect();
      if (client.cameraName.trim().isNotEmpty &&
          _cameraModel == 'Nikon Camera') {
        _cameraModel = NikonDeviceInfo.normalizeModelName(client.cameraName);
      }
      _state = CameraConnectionState.connected;
      _stateController.add(_state);

      // 监听相机推送事件 (ObjectAdded 0x4002) 用于边拍边传
      await _eventSub?.cancel();
      _eventSub = client.events.listen(_handleCameraEvent);

      // 查询设备信息以获取具体型号与支持能力集
      try {
        await _queryDeviceInfo();
      } catch (e) {
        onLog?.call('查询相机设备信息提示: $e');
      }
      _completeSessionInfo();

      // 受限配对会话期间不查询电量，避免向待配对机身发送未授权属性请求
      if (!_isRestrictedPairingSession) {
        try {
          await _queryBatteryLevel();
        } catch (_) {}
      }
    } catch (e) {
      try {
        await client?.disconnect();
      } catch (_) {}
      _completeSessionInfo();
      _lastDisconnectAt = DateTime.now();
      _state = CameraConnectionState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  /// 通过 USB (PTP over OTG) 连接相机。首期支持连接、浏览存储卡与分块下载。
  Future<void> connectUsb(String deviceName,
      {void Function(String msg)? onLog}) async {
    _userDisconnect = false;
    final transport = UsbPtpTransport(deviceName: deviceName, onLog: onLog);
    try {
      await connectTransport(transport,
          onLog: onLog, kind: CameraTransportKind.usb);
      _lastUsbDeviceName = deviceName;
      _lastWasUsb = true;
    } catch (e) {
      await transport.disconnect();
      transport.dispose();
      rethrow;
    }
  }

  /// 使用给定传输层建立连接，复用与 Wi-Fi 完全相同的上层逻辑。
  Future<void> connectTransport(PtpTransport transport,
      {void Function(String msg)? onLog,
      CameraTransportKind kind = CameraTransportKind.wifi}) async {
    if (onLog != null) _logCallback = onLog;
    _transportKind = kind;
    _isRestrictedPairingSession = false;
    _staAppModeEnabled = false;
    _knownFileHandles.clear();
    _knownFolderHandles.clear();
    _handlePrefixFormatCache.clear();
    _consecutiveObjectInfoAccessDenied = 0;
    _objectInfoFailLogCount = 0;
    _mediaTransferLogCount = 0;
    _preferPartialObject64 = false;
    _partialObject64ParamCount = 5;
    _beginSessionInfo();
    _state = CameraConnectionState.connecting;
    _stateController.add(_state);
    try {
      _client = transport;
      transport.onUnexpectedDisconnect = _notifyUnexpectedDisconnect;
      await _client!.connect();
      _state = CameraConnectionState.connected;
      _stateController.add(_state);
      await _eventSub?.cancel();
      _eventSub = _client!.events.listen(_handleCameraEvent);

      try {
        await _queryDeviceInfo();
      } catch (e) {
        onLog?.call('查询相机设备信息提示: $e');
      }
      _completeSessionInfo();
      if (!_isRestrictedPairingSession) {
        try {
          await _queryBatteryLevel();
        } catch (_) {}
      }
    } catch (e) {
      _completeSessionInfo();
      _state = CameraConnectionState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _userDisconnect = true;
    _completeSessionInfo();
    // 先退出 Application Mode 与取景，避免相机停留在取景模式或锁死存储卡访问。
    if (_inMovieAppMode) {
      try {
        await exitMovieApplicationMode();
      } catch (_) {}
    }
    try {
      await endLiveView();
    } catch (_) {}
    _io.reset();
    await _eventSub?.cancel();
    _eventSub = null;
    await _client?.disconnect();
    _client = null;
    _lastDisconnectAt = DateTime.now();
    _isRestrictedPairingSession = false;
    _state = CameraConnectionState.disconnected;
    // 注意：不重置 _lastWasUsb / _lastWifiHost，重连需要它们。
    _transportKind = CameraTransportKind.wifi;
    _unsupportedOps.clear();
    _inMovieAppMode = false;
    _staAppModeEnabled = false;
    _propDescCache.clear();
    // dispose 场景下控制器可能已关闭，避免向已关闭的 StreamController 发送事件
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
    _objectInfoCache.clear();
    _thumbCache.clear();
    _knownFileHandles.clear();
    _knownFolderHandles.clear();
    _handlePrefixFormatCache.clear();
    _consecutiveObjectInfoAccessDenied = 0;
    _objectInfoFailLogCount = 0;
    _mediaTransferLogCount = 0;
    _preferPartialObject64 = false;
    _partialObject64ParamCount = 5;
    _detectedStorageIds.clear();
    try {
      await CameraNativeBridge.unbindWifi();
    } catch (_) {}
  }

  // ==========================================
  // 相机状态与参数读取
  // ==========================================

  @override
  Future<CameraExposureParams> fetchExposureParams() async {
    if (!isConnected) return const CameraExposureParams();

    String aperture = '--';
    String shutterSpeed = '--';
    String iso = '--';
    String exposureComp = '--';
    String programMode = '--';
    String focalLength = '--';
    String lensInfo = '--';
    int bat = _batteryLevel;

    // 1. 光圈 F-Number (0x5007): 2 字节小端无符号，实际值 = value / 100
    try {
      final fData =
          await _client!.executeDataIn(PtpOpCodes.getDevicePropValue, [0x5007]);
      if (fData.length >= 2) {
        final val = ByteData.sublistView(fData).getUint16(0, Endian.little);
        if (val > 0 && val < 65000) {
          aperture = 'f/${(val / 100.0).toStringAsFixed(1)}';
        }
      }
    } catch (_) {}

    // 2. 快门速度 ShutterSpeed (0xD100 / 0x500D)
    // Nikon 0xD100：32 位整数，高 16 位为分子，低 16 位为分母。
    try {
      Uint8List ssData = Uint8List(0);
      try {
        ssData = await _client!
            .executeDataIn(PtpOpCodes.getDevicePropValue, [0xD100]);
      } catch (_) {
        try {
          ssData = await _client!
              .executeDataIn(PtpOpCodes.getDevicePropValue, [0x500D]);
        } catch (_) {}
      }
      if (ssData.length >= 4) {
        final rawVal = ByteData.sublistView(ssData).getUint32(0, Endian.little);
        final num = (rawVal >> 16) & 0xFFFF;
        final den = rawVal & 0xFFFF;
        if (num == 65535 && den == 65535) {
          shutterSpeed = 'BULB';
        } else if (num == 65535 && den == 65533) {
          shutterSpeed = 'TIME';
        } else if (num == 65535 && den == 65534) {
          shutterSpeed = 'FLASH';
        } else if (den == 1) {
          shutterSpeed = '$num"';
        } else if (den > 1) {
          if (num == 1) {
            shutterSpeed = '1/${den}s';
          } else if (num > 0 && den % num == 0) {
            shutterSpeed = '1/${(den / num).round()}s';
          } else {
            shutterSpeed = '$num/${den}s';
          }
        }
      }
    } catch (_) {}

    // 3. 感光度 ISO (0x500F / 0xD0B4)
    try {
      Uint8List isoData = Uint8List(0);
      try {
        isoData = await _client!
            .executeDataIn(PtpOpCodes.getDevicePropValue, [0x500F]);
      } catch (_) {
        try {
          isoData = await _client!
              .executeDataIn(PtpOpCodes.getDevicePropValue, [0xD0B4]);
        } catch (_) {}
      }
      if (isoData.length >= 4) {
        final isoVal =
            ByteData.sublistView(isoData).getUint32(0, Endian.little);
        if (isoVal > 0 && isoVal < 1000000) iso = 'ISO $isoVal';
      } else if (isoData.length >= 2) {
        final isoVal =
            ByteData.sublistView(isoData).getUint16(0, Endian.little);
        if (isoVal > 0) iso = 'ISO $isoVal';
      }
    } catch (_) {}

    // 4. 曝光补偿 ExposureCompensation (0x5010): 2 字节小端有符号，千分档 EV
    try {
      final evData =
          await _client!.executeDataIn(PtpOpCodes.getDevicePropValue, [0x5010]);
      if (evData.length >= 2) {
        final rawEv = ByteData.sublistView(evData).getInt16(0, Endian.little);
        final ev = rawEv / 1000.0;
        if (ev > 0) {
          exposureComp = '+${ev.toStringAsFixed(1)} EV';
        } else if (ev < 0) {
          exposureComp = '${ev.toStringAsFixed(1)} EV';
        } else {
          exposureComp = '±0.0 EV';
        }
      }
    } catch (_) {}

    // 5. 曝光模式 ProgramMode (0x500E)
    // 0x500E 取值：1=M, 2=P, 3=A, 4=S, 0x8010=AUTO。
    try {
      final modeData =
          await _client!.executeDataIn(PtpOpCodes.getDevicePropValue, [0x500E]);
      if (modeData.length >= 2) {
        final m = ByteData.sublistView(modeData).getUint16(0, Endian.little);
        if (m == 1) {
          programMode = 'M';
        } else if (m == 2) {
          programMode = 'P';
        } else if (m == 3) {
          programMode = 'A';
        } else if (m == 4) {
          programMode = 'S';
        } else if (m == 0x8010 || m == 0x8011) {
          programMode = 'AUTO';
        } else {
          programMode = 'MODE $m';
        }
      }
    } catch (_) {}

    // 6. 当前焦距 FocalLength (0x5008)
    try {
      final flData =
          await _client!.executeDataIn(PtpOpCodes.getDevicePropValue, [0x5008]);
      if (flData.length >= 4) {
        var fl = ByteData.sublistView(flData).getUint32(0, Endian.little);
        if (fl > 1000) fl = (fl / 100).round();
        if (fl > 0 && fl < 2000) focalLength = '${fl}mm';
      }
    } catch (_) {}

    // 7. 镜头型号/焦段探测 LensFocalMin (0xD0E3) & LensFocalMax (0xD0E4)
    try {
      int minF = 0;
      int maxF = 0;
      try {
        final minData = await _client!
            .executeDataIn(PtpOpCodes.getDevicePropValue, [0xD0E3]);
        if (minData.length >= 4) {
          minF = ByteData.sublistView(minData).getUint32(0, Endian.little);
          if (minF > 1000) minF = (minF / 100).round();
        }
      } catch (_) {}
      try {
        final maxData = await _client!
            .executeDataIn(PtpOpCodes.getDevicePropValue, [0xD0E4]);
        if (maxData.length >= 4) {
          maxF = ByteData.sublistView(maxData).getUint32(0, Endian.little);
          if (maxF > 1000) maxF = (maxF / 100).round();
        }
      } catch (_) {}

      if (minF > 0 && maxF > 0) {
        if (minF == maxF) {
          lensInfo = '$minF mm 定焦';
        } else {
          lensInfo = '$minF-${maxF}mm';
        }
      }
    } catch (_) {}

    return CameraExposureParams(
      aperture: aperture,
      shutterSpeed: shutterSpeed,
      iso: iso,
      exposureComp: exposureComp,
      programMode: programMode,
      focalLength: focalLength,
      lensInfo: lensInfo,
      batteryLevel: bat,
    );
  }

  // ==========================================
  // 媒体管理与 4MB 分块流式拉取
  // ==========================================

  @override
  Future<List<int>> listStorageIds() async {
    if (!isConnected) return _detectedStorageIds;
    try {
      final storageData =
          await _client!.executeDataIn(PtpOpCodes.getStorageIDs);
      final ids = _parseUint32Array(storageData);
      if (ids.isNotEmpty) {
        _detectedStorageIds = ids;
        _logCallback?.call(
            '【存储卷】GetStorageIDs 返回 ${ids.length} 个: ${ids.map((e) => '0x${e.toRadixString(16)}').join(', ')}');
        return _detectedStorageIds;
      }
      _logCallback?.call('【存储卷】GetStorageIDs 返回空列表');
    } catch (e) {
      _logCallback?.call('【存储卷】GetStorageIDs 失败: $e');
    }
    if (_detectedStorageIds.isEmpty) {
      _detectedStorageIds = [0x00010001];
    }
    return _detectedStorageIds;
  }

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async {
    if (!isConnected) {
      _log('[media] listObjectHandles skipped: not connected');
      return [];
    }

    // 取景进行中部分机型会以 0x2019 / 0x200F 拒绝存储遍历或 GetObjectInfo，先退出取景。
    if (_liveViewActive) {
      await endLiveView();
    }

    // 调用方明确指定卡槽时直接扫，不做猜测。
    if (storageId != null) {
      return _scanStorageFiles(storageId);
    }

    var baseIds = await listStorageIds();
    var candidates = _storageCandidates(baseIds);
    var sawAnyHandles = false;

    Future<List<int>?> probe() async {
      for (final candidate in candidates) {
        final handles = await _probeStorageCandidate(
          candidate,
          baseIds,
          onHandlesSeen: () => sawAnyHandles = true,
        );
        if (handles != null && handles.isNotEmpty) {
          return handles;
        }
      }
      return null;
    }

    var found = await probe();
    if (found != null) return found;

    // 刚完成配对的 STA 会话里，相机可能先应答握手、稍后才挂载存储卡。
    await Future<void>.delayed(const Duration(milliseconds: 600));
    baseIds = await listStorageIds();
    candidates = _storageCandidates(baseIds);
    found = await probe();
    if (found != null) return found;

    // 部分机身（Z 30 的「连接到计算机」模式）在进入 Application Mode 之前
    // 会返回存储卷但 0 个对象。NikonCameraControl 在 STA PC 模式下也是先发
    // 0x9435(1) 再读卡。若相机已经返回目录句柄（如空卡的 DCIM 根），则不必误触 0x9435。
    if (_isStaSession && !_staAppModeEnabled && !sawAnyHandles) {
      _log('[media] no objects in STA session, trying 0x9435(1) app mode');
      if (await _enableStaApplicationMode()) {
        baseIds = await listStorageIds();
        candidates = _storageCandidates(baseIds);
        found = await probe();
        if (found != null) return found;
      }
    }

    // 扁平查询不被支持时退回目录树遍历。
    for (final id in baseIds) {
      try {
        final scanned = await _scanStorageFiles(id);
        if (scanned.isNotEmpty) {
          _log('卡槽 0x${id.toRadixString(16)} 成功检索到 ${scanned.length} 个媒体文件');
          return scanned;
        }
      } catch (e) {
        _log('[media] storage 0x${id.toRadixString(16)} scan failed: $e');
      }
    }

    return [];
  }

  /// 探测单个存储卷候选 ID。
  ///
  /// 严格遵循 ISO 15740 §10.4.6：
  /// - `Parent = 0x00000000` (`PTP_GOH_ALL_ASSOCS`) 表示整卡全部对象扁平返回；
  /// - `Parent = 0xFFFFFFFF` (`PTP_GOH_ROOT_PARENT`) 仅返回根目录对象（部分旧固件也将其视为扁平）。
  /// 优先尝试 `0x00000000`，不足时再试 `0xFFFFFFFF`；若仅得到根关联句柄则递归展开目录树。
  Future<List<int>?> _probeStorageCandidate(
    int candidate,
    List<int> baseIds, {
    void Function()? onHandlesSeen,
  }) async {
    List<int>? rootSeeds;

    for (final parentParam in const <int>[0, 0xFFFFFFFF]) {
      try {
        final data = await _client!.executeDataIn(
          PtpOpCodes.getObjectHandles,
          [candidate, 0, parentParam],
        );
        final handles = _parseUint32Array(data);
        final parentLabel = parentParam == 0 ? '0x0' : '0xffffffff';
        _log(
            '[media] storage 0x${candidate.toRadixString(16)} (parent=$parentLabel) -> ${handles.length} handles'
            '${handles.isEmpty ? '' : ': ${handles.take(8).map((e) => '0x${e.toRadixString(16)}').join(', ')}'}');
        if (handles.isEmpty) continue;
        onHandlesSeen?.call();

        if (!baseIds.contains(candidate)) {
          _detectedStorageIds = [candidate];
          _log(
              '[media] using storage 0x${candidate.toRadixString(16)} instead of reported ids');
        }

        if (handles.length > 2) {
          // 少量句柄（如 DCIM / PRIVATE / MISC）可能全部是根文件夹，核对后再决定是否展开。
          if (handles.length <= 8 && await _looksLikeFolderOnlyBatch(handles)) {
            rootSeeds ??= handles;
            continue;
          }
          return handles;
        }
        rootSeeds ??= handles;
      } catch (e) {
        final parentLabel = parentParam == 0 ? '0x0' : '0xffffffff';
        _log(
            '[media] storage 0x${candidate.toRadixString(16)} (parent=$parentLabel) probe failed: $e');
      }
    }

    if (rootSeeds != null && rootSeeds.isNotEmpty) {
      final expanded = await _expandHandleTree(candidate, rootSeeds);
      _log(
          '[media] expanded ${rootSeeds.length} root handle(s) -> '
          '${expanded.length} files (storage 0x${candidate.toRadixString(16)})');
      if (expanded.isNotEmpty) return expanded;
    }
    return null;
  }

  /// 检查少量句柄是否全部为目录对象，避免把根文件夹列表直接当成照片返回。
  Future<bool> _looksLikeFolderOnlyBatch(List<int> handles) async {
    final nonZero =
        handles.where((h) => h != 0 && h != 0xFFFFFFFF).toList(growable: false);
    if (nonZero.isEmpty) return false;
    final allFolderCandidates = nonZero.every(_isNikonFolderHandleCandidate);
    var inspected = 0;
    for (final h in nonZero) {
      final info = await _getObjectInfoInternal(
        h,
        probeFolderViaHandles: allFolderCandidates,
        allowSizeFallbacks: false,
      );
      if (info == null) return false;
      inspected++;
      if (!info.isFolder && info.fileName.toUpperCase() != 'DCIM') {
        return false;
      }
    }
    return inspected > 0;
  }

  /// 从根句柄递归展开目录树，收集实际媒体文件句柄。
  ///
  /// 关键容错：
  /// 1. 若 `getObjectInfo` 返回 null 且以 `0x1007` 遍历返回 `0x201A (InvalidParentObject)`，
  ///    说明该句柄本身就是媒体文件而非文件夹，必须回收进 `files` 而不是丢弃；
  /// 2. 在 DCF 叶目录（depth >= 2，如 `DCIM/100NCZ_30/`）且条目较多时只探测首条句柄，
  ///    确认为文件后整批直接收录，避免对数百张照片逐一发 `0x1008`/`0x1007` 阻塞相册加载。
  Future<List<int>> _expandHandleTree(int storageId, List<int> seeds) async {
    final files = <int>[];
    final folders = <({int handle, int depth, int batchId, bool maybeFile})>[];
    final visited = <int>{};
    final invalidParentByBatch = <int, int>{};
    var batchSeq = 0;

    void recordFile(int h) {
      files.add(h);
      _knownFileHandles.add(h);
    }

    Future<void> classify(Iterable<int> handles, int depth) async {
      final fresh = <int>[];
      for (final h in handles) {
        if (h == 0 || h == 0xFFFFFFFF) continue;
        if (visited.add(h)) fresh.add(h);
      }
      if (fresh.isEmpty) return;

      // DCF 叶目录快速判定：depth >= 2 (DCIM/100xxxxx 内部) 且文件数 > 4 时，
      // 仅探测首条句柄，确认为文件后整批直接收录，交由相册流式按需拉取详情。
      if (depth >= 2 && fresh.length > 4) {
        final first = fresh.first;
        final firstInfo = await getObjectInfo(first);
        if (firstInfo != null &&
            !firstInfo.isFolder &&
            firstInfo.fileName.toUpperCase() != 'DCIM') {
          for (final h in fresh) {
            recordFile(h);
          }
          return;
        }
        if (firstInfo == null) {
          try {
            final probeData = await _client!.executeDataIn(
              PtpOpCodes.getObjectHandles,
              [storageId, 0, first],
            );
            // 首条真的是嵌套子目录：递归其子项，并继续正常分类同级剩余句柄。
            await classify(_parseUint32Array(probeData), depth + 1);
            await classify(fresh.skip(1), depth);
            return;
          } on PtpException catch (e) {
            if (e.responseCode == PtpOpCodes.responseInvalidParentObject) {
              for (final h in fresh) {
                recordFile(h);
              }
              _log(
                  '[media] leaf folder confirmed via 0x201a, collected ${fresh.length} file handle(s)');
              return;
            }
          } catch (_) {}
        }
      }

      final batchId = ++batchSeq;
      for (final h in fresh) {
        final info = await getObjectInfo(h);
        if (info == null) {
          // 信息暂不可读：标记 maybeFile 探测一次，若返回 0x201A 则回收为文件。
          folders.add((
            handle: h,
            depth: depth + 1,
            batchId: batchId,
            maybeFile: true,
          ));
        } else if (info.isFolder ||
            info.fileName.toUpperCase() == 'DCIM') {
          folders.add((
            handle: h,
            depth: depth + 1,
            batchId: batchId,
            maybeFile: false,
          ));
        } else {
          recordFile(h);
        }
      }
    }

    final realSeeds = seeds.where((h) => h != 0 && h != 0xFFFFFFFF).toList();
    if (realSeeds.isEmpty) {
      var seeded = false;
      for (final rootParam in const <int>[0xFFFFFFFF, 0]) {
        try {
          final rootData = await _client!.executeDataIn(
            PtpOpCodes.getObjectHandles,
            [storageId, 0, rootParam],
          );
          final rootHandles = _parseUint32Array(rootData);
          if (rootHandles.isNotEmpty) {
            await classify(rootHandles, 0);
            seeded = true;
            break;
          }
        } catch (e) {
          _log('[media] root enumeration (parent=0x${rootParam.toRadixString(16)}) failed: $e');
        }
      }
      if (!seeded) return files;
    } else {
      await classify(realSeeds, 0);
    }

    var guard = 0;
    while (folders.isNotEmpty && guard++ < 256) {
      final node = folders.removeAt(0);
      try {
        final data = await _client!.executeDataIn(
          PtpOpCodes.getObjectHandles,
          [storageId, 0, node.handle],
        );
        await classify(_parseUint32Array(data), node.depth);
      } on PtpException catch (e) {
        if (e.responseCode == PtpOpCodes.responseInvalidParentObject &&
            node.maybeFile) {
          recordFile(node.handle);
          final count = (invalidParentByBatch[node.batchId] ?? 0) + 1;
          invalidParentByBatch[node.batchId] = count;
          if (count >= 2) {
            // 同目录连续 2 条未知句柄均返回 0x201A，说明该目录其余待探测句柄都是媒体文件。
            var rescued = 0;
            folders.removeWhere((pending) {
              if (pending.batchId == node.batchId && pending.maybeFile) {
                recordFile(pending.handle);
                rescued++;
                return true;
              }
              return false;
            });
            _log(
                '[media] 0x201a confirmed non-folder handles; rescued ${rescued + count} file(s) in batch ${node.batchId}');
          }
        } else {
          _log(
              '[media] folder 0x${node.handle.toRadixString(16)} enumeration failed: $e');
        }
      } catch (e) {
        _log(
            '[media] folder 0x${node.handle.toRadixString(16)} enumeration failed: $e');
      }
    }

    return files;
  }

  /// 存储卷 ID 候选：相机报告值、+1、字节序交换及交换后 +1。
  /// 尼康在不同连接模式 / 固件下会报告与实际不一致的 ID。
  List<int> _storageCandidates(List<int> baseIds) {
    final candidates = <int>[];
    void consider(int id) {
      final v = id & 0xFFFFFFFF;
      if (v == 0) return;
      if (!candidates.contains(v)) candidates.add(v);
    }

    for (final id in baseIds) {
      consider(id);
      consider(id + 1);
      final swapped = _swapUint32(id);
      consider(swapped);
      consider(swapped + 1);
    }
    consider(0xFFFFFFFF);
    return candidates;
  }

  /// 32 位字节序翻转（尼康部分固件按网络序上报存储卷 ID）。
  static int _swapUint32(int value) {
    final v = value & 0xFFFFFFFF;
    return (((v & 0xFF) << 24) |
            ((v & 0xFF00) << 8) |
            ((v >> 8) & 0xFF00) |
            ((v >> 24) & 0xFF)) &
        0xFFFFFFFF;
  }

  bool get _isStaSession => (_lastWifiRouteMode ?? '').startsWith('sta');

  /// STA PC 模式进入尼康 Application Mode，让相机把存储卡挂到当前会话。
  Future<bool> _enableStaApplicationMode() async {
    final client = _client;
    if (client == null || !isConnected) return false;
    try {
      await client.executeOperation(PtpOpCodes.nikonChangeAppMode, const <int>[1]);
      _staAppModeEnabled = true;
      _inMovieAppMode = true;
      AppLogManager.instance.add('[media] STA app mode enabled (0x9435=1)');
      return true;
    } catch (e) {
      AppLogManager.instance.add('[media] 0x9435(1) rejected: $e');
    }
    try {
      await writeUintProperty(PtpOpCodes.nikonPropApplicationMode, 1);
      _staAppModeEnabled = true;
      _inMovieAppMode = true;
      AppLogManager.instance.add('[media] STA app mode enabled (0xD1F0=1)');
      return true;
    } catch (e) {
      AppLogManager.instance.add('[media] app mode property rejected: $e');
      return false;
    }
  }

  /// 扫描指定存储卷下的所有文件 (支持 ISO 15740 扁平查询与目录树递归双引擎)
  Future<List<int>> _scanStorageFiles(int storageId) async {
    // 引擎 1: 优先按 ISO 15740 尝试扁平查询 (0x0) 与根/兼容查询 (0xFFFFFFFF)
    final probed = await _probeStorageCandidate(storageId, [storageId]);
    if (probed != null && probed.isNotEmpty) {
      return probed;
    }

    // 引擎 2: 兜底显式展开根目录树
    return _expandHandleTree(storageId, const <int>[]);
  }

  void _logObjectInfoFailure(int handle, String detail) {
    if (_objectInfoFailLogCount >= 6) return;
    _objectInfoFailLogCount++;
    _log(
        '[media] getObjectInfo(0x${handle.toRadixString(16)}) $detail '
        '(staApp=$_staAppModeEnabled, lv=$_liveViewActive)');
  }

  int get _defaultStorageId =>
      _detectedStorageIds.isNotEmpty ? _detectedStorageIds.first : 0x00010001;

  static bool _isNikonFolderHandleCandidate(int handle) =>
      (handle & 0xFF000000) == 0x11000000 && (handle & 0x3FFF) == 0;

  CameraFileItem _synthesizedFolderItem(int handle) => CameraFileItem(
        handle: handle,
        storageId: _defaultStorageId,
        format: 0x3001,
        size: 0,
        fileName: 'FOLDER_${handle.toRadixString(16).toUpperCase()}',
        captureDate: '',
      );

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) =>
      _getObjectInfoInternal(handle);

  Future<CameraFileItem?> _getObjectInfoInternal(
    int handle, {
    bool probeFolderViaHandles = true,
    bool allowSizeFallbacks = true,
  }) async {
    if (!isConnected) return null;
    if (_objectInfoCache.containsKey(handle)) {
      return _objectInfoCache[handle];
    }
    if (_knownFolderHandles.contains(handle)) {
      final folder = _synthesizedFolderItem(handle);
      _objectInfoCache[handle] = folder;
      return folder;
    }

    // 1. 标准 PTP 0x1008 GetObjectInfo（连续被 0x200F 拒绝后短接跳过，避免全量扫卡耗尽命令口）
    final allowStandardInfo = _supports(PtpOpCodes.getObjectInfo) &&
        (_consecutiveObjectInfoAccessDenied < 3 || _liveViewActive);
    if (allowStandardInfo) {
      final standard = await _fetchObjectInfoStandard(handle);
      if (standard != null) {
        if (standard.isFolder) _knownFolderHandles.add(handle);
        _objectInfoCache[handle] = standard;
        return standard;
      }
    }

    // 2. 回退 MTP 0x9805 GetObjectPropList（部分固件在 PC 控制态下更偏好 MTP 属性表）
    if (_supports(PtpOpCodes.mtpGetObjectPropList)) {
      final viaList = await _fetchObjectInfoViaMtpPropList(handle);
      if (viaList != null) {
        if (viaList.isFolder) _knownFolderHandles.add(handle);
        _objectInfoCache[handle] = viaList;
        return viaList;
      }
    }

    // 3. 回退 MTP 0x9803 GetObjectPropValue 逐项读取核心元数据
    if (_supports(PtpOpCodes.mtpGetObjectPropValue)) {
      final viaProps = await _fetchObjectInfoViaMtpPropValue(handle);
      if (viaProps != null) {
        if (viaProps.isFolder) _knownFolderHandles.add(handle);
        _objectInfoCache[handle] = viaProps;
        return viaProps;
      }
    }

    // 3.5. 扁平遍历常含 DCIM/子目录句柄 (0x11xx4000 / 0x11xx0000)：用 0x1007 一次探明目录归属，
    //      避免把目录误判为照片或向目录发 0x9421 / 0x101B。
    if (probeFolderViaHandles &&
        !_knownFileHandles.contains(handle) &&
        _isNikonFolderHandleCandidate(handle) &&
        _supports(PtpOpCodes.getObjectHandles)) {
      try {
        await _client!.executeDataIn(
          PtpOpCodes.getObjectHandles,
          [_defaultStorageId, 0, handle],
        );
        _knownFolderHandles.add(handle);
        final folder = _synthesizedFolderItem(handle);
        _objectInfoCache[handle] = folder;
        return folder;
      } on PtpException catch (e) {
        if (e.responseCode == PtpOpCodes.responseInvalidParentObject) {
          _knownFileHandles.add(handle);
        }
      } catch (_) {}
    }

    // 4. Nikon 0x9421 GetObjectSize + 魔数嗅探合成条目（放行扁平枚举与 ObjectAdded 句柄）
    if (allowSizeFallbacks && _supports(PtpOpCodes.nikonGetObjectSize)) {
      final viaSize = await _fetchObjectInfoViaNikonSize(handle);
      if (viaSize != null) {
        _objectInfoCache[handle] = viaSize;
        return viaSize;
      }
    }

    // 5. 终极兜底：若 0x9421 亦被拒绝，用 0x101B GetPartialObject 探测魔数与文件大小
    if (allowSizeFallbacks && _supports(PtpOpCodes.getPartialObject)) {
      final viaPartial = await _fetchObjectInfoViaPartialProbe(handle);
      if (viaPartial != null) {
        _objectInfoCache[handle] = viaPartial;
        return viaPartial;
      }
    }

    return null;
  }

  Future<CameraFileItem?> _fetchObjectInfoStandard(int handle) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final data =
            await _client!.executeDataIn(PtpOpCodes.getObjectInfo, [handle]);
        if (data.length < 52) {
          _logObjectInfoFailure(handle, '0x1008 payload too short (${data.length}B)');
          return null;
        }

        _consecutiveObjectInfoAccessDenied = 0;
        final bd = ByteData.sublistView(data);
        final storageId = bd.getUint32(0, Endian.little);
        final format = bd.getUint16(4, Endian.little);
        final size = bd.getUint32(8, Endian.little);
        final pixWidth = bd.getUint32(26, Endian.little);
        final pixHeight = bd.getUint32(30, Endian.little);

        final reader = PtpByteReader(data.sublist(52));
        final fileName = reader.readPtpString();
        final captureDate = reader.readPtpString();

        return CameraFileItem(
          handle: handle,
          storageId: storageId,
          format: format,
          size: size,
          fileName: fileName.isEmpty
              ? 'DSC_${handle.toRadixString(16).toUpperCase()}.JPG'
              : fileName,
          captureDate: captureDate,
          pixelWidth: pixWidth,
          pixelHeight: pixHeight,
        );
      } on PtpException catch (e) {
        if (e.responseCode == PtpOpCodes.responseDeviceBusy && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          continue;
        }
        if (e.responseCode == PtpOpCodes.responseAccessDenied &&
            !_liveViewActive) {
          _consecutiveObjectInfoAccessDenied++;
        }
        _markUnsupported(PtpOpCodes.getObjectInfo, e);
        _logObjectInfoFailure(handle, '0x1008 rejected: $e');
        return null;
      } catch (e) {
        _logObjectInfoFailure(handle, '0x1008 error: $e');
        return null;
      }
    }
    return null;
  }

  Future<CameraFileItem?> _fetchObjectInfoViaMtpPropList(int handle) async {
    try {
      // MTP 1.1 GetObjectPropList: [handle, format=0(all), propCode=0xFFFFFFFF(all), group=0, depth=0]
      final data = await _client!.executeDataIn(
        PtpOpCodes.mtpGetObjectPropList,
        [handle, 0, 0xFFFFFFFF, 0, 0],
      );
      if (data.length < 4) return null;

      final reader = PtpByteReader(data);
      final count = reader.readUint32();
      if (count <= 0 || count > 2000) return null;

      int storageId =
          _detectedStorageIds.isNotEmpty ? _detectedStorageIds.first : 0x00010001;
      int format = 0;
      int size = 0;
      int pixWidth = 0;
      int pixHeight = 0;
      String fileName = '';
      String captureDate = '';
      var matched = false;

      for (var i = 0; i < count && reader.remaining >= 8; i++) {
        final objHandle = reader.readUint32();
        final propCode = reader.readUint16();
        final dataType = reader.readUint16();
        final isTarget = objHandle == handle;

        int? intVal;
        String? strVal;
        if (dataType == 0x0001 || dataType == 0x0002) {
          if (reader.remaining < 1) break;
          intVal = reader.readUint8();
        } else if (dataType == 0x0003 || dataType == 0x0004) {
          if (reader.remaining < 2) break;
          intVal = reader.readUint16();
        } else if (dataType == 0x0005 || dataType == 0x0006) {
          if (reader.remaining < 4) break;
          intVal = reader.readUint32();
        } else if (dataType == 0x0007 || dataType == 0x0008) {
          if (reader.remaining < 8) break;
          final low = reader.readUint32();
          final high = reader.readUint32();
          intVal = (high << 32) | low;
        } else if (dataType == 0x0009 || dataType == 0x000A) {
          if (reader.remaining < 16) break;
          reader.readBytes(16);
        } else if (dataType == 0xFFFF) {
          strVal = reader.readPtpString();
        } else if (dataType >= 0x4001 && dataType <= 0x400A) {
          if (reader.remaining < 4) break;
          final arrLen = reader.readUint32();
          final elemSize = switch (dataType & 0x00FF) {
            0x01 || 0x02 => 1,
            0x03 || 0x04 => 2,
            0x05 || 0x06 => 4,
            0x07 || 0x08 => 8,
            0x09 || 0x0A => 16,
            _ => 0,
          };
          if (elemSize == 0 || arrLen > 100000 || reader.remaining < arrLen * elemSize) {
            break;
          }
          reader.readBytes(arrLen * elemSize);
        } else {
          break;
        }

        if (!isTarget) continue;
        matched = true;
        switch (propCode) {
          case 0xDC01: // StorageID
            if (intVal != null) storageId = intVal;
          case 0xDC02: // ObjectFormat
            if (intVal != null) format = intVal;
          case 0xDC04: // ObjectSize (UINT64)
            if (intVal != null) size = intVal;
          case 0xDC07: // ObjectFileName
            if (strVal != null && strVal.isNotEmpty) fileName = strVal;
          case 0xDC08: // DateCreated
            if (strVal != null && strVal.isNotEmpty) captureDate = strVal;
          case 0xDC09: // DateModified
            if (captureDate.isEmpty && strVal != null && strVal.isNotEmpty) {
              captureDate = strVal;
            }
          case 0xDC87: // Width
            if (intVal != null) pixWidth = intVal;
          case 0xDC88: // Height
            if (intVal != null) pixHeight = intVal;
        }
      }

      if (!matched || (format == 0 && fileName.isEmpty && size == 0)) {
        return null;
      }
      return CameraFileItem(
        handle: handle,
        storageId: storageId,
        format: format == 0 ? 0x3801 : format,
        size: size,
        fileName: fileName.isEmpty
            ? 'DSC_${handle.toRadixString(16).toUpperCase()}.JPG'
            : fileName,
        captureDate: captureDate,
        pixelWidth: pixWidth,
        pixelHeight: pixHeight,
      );
    } on PtpException catch (e) {
      _markUnsupported(PtpOpCodes.mtpGetObjectPropList, e);
      _logObjectInfoFailure(handle, '0x9805 rejected: $e');
      return null;
    } catch (e) {
      _logObjectInfoFailure(handle, '0x9805 error: $e');
      return null;
    }
  }

  Future<CameraFileItem?> _fetchObjectInfoViaMtpPropValue(int handle) async {
    Future<Uint8List?> readProp(int propCode) async {
      try {
        return await _client!.executeDataIn(
          PtpOpCodes.mtpGetObjectPropValue,
          [handle, propCode],
        );
      } on PtpException catch (e) {
        _markUnsupported(PtpOpCodes.mtpGetObjectPropValue, e);
        return null;
      } catch (_) {
        return null;
      }
    }

    final formatData = await readProp(0xDC02);
    if (!_supports(PtpOpCodes.mtpGetObjectPropValue)) return null;
    final nameData = await readProp(0xDC07);
    final sizeData = await readProp(0xDC04);
    if (formatData == null && nameData == null && sizeData == null) {
      return null;
    }

    final format = (formatData != null && formatData.length >= 2)
        ? ByteData.sublistView(formatData).getUint16(0, Endian.little)
        : 0x3801;
    final fileName = (nameData != null && nameData.isNotEmpty)
        ? PtpByteReader(nameData).readPtpString()
        : '';
    var size = 0;
    if (sizeData != null && sizeData.length >= 8) {
      final bd = ByteData.sublistView(sizeData);
      final low = bd.getUint32(0, Endian.little);
      final high = bd.getUint32(4, Endian.little);
      size = (high << 32) | low;
    } else if (sizeData != null && sizeData.length >= 4) {
      size = ByteData.sublistView(sizeData).getUint32(0, Endian.little);
    }

    String captureDate = '';
    final dateData = await readProp(0xDC08) ?? await readProp(0xDC09);
    if (dateData != null && dateData.isNotEmpty) {
      captureDate = PtpByteReader(dateData).readPtpString();
    }

    final storageData = await readProp(0xDC01);
    final storageId = (storageData != null && storageData.length >= 4)
        ? ByteData.sublistView(storageData).getUint32(0, Endian.little)
        : (_detectedStorageIds.isNotEmpty
            ? _detectedStorageIds.first
            : 0x00010001);

    return CameraFileItem(
      handle: handle,
      storageId: storageId,
      format: format,
      size: size,
      fileName: fileName.isEmpty
          ? 'DSC_${handle.toRadixString(16).toUpperCase()}.JPG'
          : fileName,
      captureDate: captureDate,
    );
  }

  ({int format, String ext})? _sniffHeaderFormat(Uint8List head) {
    if (head.length >= 3 &&
        head[0] == 0xFF &&
        head[1] == 0xD8 &&
        head[2] == 0xFF) {
      return (format: 0x3801, ext: 'JPG');
    }
    if (head.length >= 4 &&
        ((head[0] == 0x49 &&
                head[1] == 0x49 &&
                head[2] == 0x2A &&
                head[3] == 0x00) ||
            (head[0] == 0x4D &&
                head[1] == 0x4D &&
                head[2] == 0x00 &&
                head[3] == 0x2A))) {
      return (format: 0xB101, ext: 'NEF');
    }
    if (head.length >= 12 &&
        head[4] == 0x66 &&
        head[5] == 0x74 &&
        head[6] == 0x79 &&
        head[7] == 0x70) {
      final brand = String.fromCharCodes(head.sublist(8, 12));
      if (brand == 'qt  ') return (format: 0x300D, ext: 'MOV');
      if (brand == 'heic' ||
          brand == 'heix' ||
          brand == 'mif1' ||
          brand == 'msf1') {
        return (format: 0x3812, ext: 'HIF');
      }
      return (format: 0xB982, ext: 'MP4');
    }
    return null;
  }

  Future<({int format, String ext})> _resolveSynthesizedFormat(int handle) async {
    final prefix = (handle >> 24) & 0xFF;
    final cached = _handlePrefixFormatCache[prefix];
    if (cached != null) return cached;

    if (_supports(PtpOpCodes.getPartialObject)) {
      try {
        final head = await downloadPartialObject(handle, 0, 32);
        final sniffed = _sniffHeaderFormat(head);
        if (sniffed != null) {
          if (prefix == 0x09 || prefix == 0x29) {
            _handlePrefixFormatCache[prefix] = sniffed;
          }
          return sniffed;
        }
      } catch (_) {}
    }

    return prefix == 0x29
        ? (format: 0xB101, ext: 'NEF')
        : (format: 0x3801, ext: 'JPG');
  }

  /// 为缺少 0x1008 文件名的合成条目生成稳健名：同组 RAW (`0x29xxxxxx`) 与 JPG (`0x09xxxxxx`)
  /// 剥离高 4 位的格式区分位后共享一致主干名，以便相册卡片自动合并展示 `JPG+RAW`。
  static String _synthesizedFileName(int handle, String ext) {
    if ((handle & 0x0F000000) == 0x09000000) {
      final stem = (handle & 0x00FFFFFF)
          .toRadixString(16)
          .toUpperCase()
          .padLeft(6, '0');
      return 'DSC_$stem.$ext';
    }
    return 'DSC_${handle.toRadixString(16).toUpperCase()}.$ext';
  }

  Future<CameraFileItem?> _fetchObjectInfoViaNikonSize(int handle) async {
    try {
      final data = await _client!.executeDataIn(
        PtpOpCodes.nikonGetObjectSize,
        [handle],
      );
      if (data.length < 4) return null;
      final bd = ByteData.sublistView(data);
      final size = data.length >= 8
          ? ((bd.getUint32(4, Endian.little) << 32) |
              bd.getUint32(0, Endian.little))
          : bd.getUint32(0, Endian.little);
      if (size <= 0) return null;
      _knownFileHandles.add(handle);
      final fmt = await _resolveSynthesizedFormat(handle);
      return CameraFileItem(
        handle: handle,
        storageId: _defaultStorageId,
        format: fmt.format,
        size: size,
        fileName: _synthesizedFileName(handle, fmt.ext),
        captureDate: '',
      );
    } on PtpException catch (e) {
      _markUnsupported(PtpOpCodes.nikonGetObjectSize, e);
      _logObjectInfoFailure(handle, '0x9421 rejected: $e');
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<CameraFileItem?> _fetchObjectInfoViaPartialProbe(int handle) async {
    try {
      final head = await downloadPartialObject(handle, 0, 64);
      final detected = _sniffHeaderFormat(head);
      if (detected == null) return null;

      var size = head.length;
      if (size >= 64) {
        Future<bool> hasByteAt(int offset) async {
          try {
            final b = await downloadPartialObject(handle, offset, 1);
            return b.isNotEmpty;
          } catch (_) {
            return false;
          }
        }

        const maxProbe = 1 << 30;
        var low = size - 1;
        var probe = 4096;
        while (probe <= maxProbe && await hasByteAt(probe)) {
          low = probe;
          if (probe == maxProbe) break;
          probe = math.min(probe * 2, maxProbe);
        }

        if (probe == maxProbe && low == maxProbe) {
          size = maxProbe + 1;
        } else {
          var high = probe;
          while (low + 1 < high) {
            final mid = low + ((high - low) >> 1);
            if (await hasByteAt(mid)) {
              low = mid;
            } else {
              high = mid;
            }
          }
          size = low + 1;
        }
      }

      if (size <= 0) return null;
      _knownFileHandles.add(handle);
      return CameraFileItem(
        handle: handle,
        storageId: _defaultStorageId,
        format: detected.format,
        size: size,
        fileName: _synthesizedFileName(handle, detected.ext),
        captureDate: '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> deleteObject(int handle) async {
    if (!isConnected) return false;
    try {
      // ISO 15740 PTP DeleteObject (0x100B): 参数 1 为 ObjectHandle，参数 2 为 ObjectFormatCode (0)
      await _client!.executeOperation(PtpOpCodes.deleteObject, [handle, 0]);
      _objectInfoCache.remove(handle);
      _thumbCache.remove(handle);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List> getThumbnail(int handle) async {
    if (!isConnected) return Uint8List(0);
    final cached = _thumbCache[handle];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    // 1. 优先尝试标准 0x100A GetThumb（仅在忙/偶发丢包时重试，明确拒绝时立即走后续兜底）
    if (_supports(PtpOpCodes.getThumb)) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final raw =
              await _client!.executeDataIn(PtpOpCodes.getThumb, [handle]);
          final valid = extractValidJpegSlice(raw);
          if (valid != null && valid.isNotEmpty) {
            _thumbCache[handle] = valid;
            return valid;
          }
          break;
        } on PtpException catch (e) {
          _markUnsupported(PtpOpCodes.getThumb, e);
          _logMediaTransferFailure(
            '0x100A thumb handle=0x${handle.toRadixString(16)} failed: 0x${e.responseCode.toRadixString(16)}',
          );
          if (e.responseCode != PtpOpCodes.responseDeviceBusy) {
            break;
          }
        } catch (e) {
          _logMediaTransferFailure(
            '0x100A thumb handle=0x${handle.toRadixString(16)} error: $e',
          );
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
      }
    }

    // 2. 回退尝试 Nikon 扩展 0x90C4 GetLargeThumb (640x480 预览图)
    if (_supports(PtpOpCodes.nikonGetLargeThumb)) {
      try {
        final largeRaw = await _client!.executeDataIn(
          PtpOpCodes.nikonGetLargeThumb,
          [handle],
        );
        final valid = extractValidJpegSlice(largeRaw);
        if (valid != null && valid.isNotEmpty) {
          _thumbCache[handle] = valid;
          return valid;
        }
      } on PtpException catch (e) {
        _markUnsupported(PtpOpCodes.nikonGetLargeThumb, e);
        _logMediaTransferFailure(
          '0x90C4 largeThumb handle=0x${handle.toRadixString(16)} failed: 0x${e.responseCode.toRadixString(16)}',
        );
      } catch (e) {
        _logMediaTransferFailure(
          '0x90C4 largeThumb handle=0x${handle.toRadixString(16)} error: $e',
        );
      }
    }

    // 3. 兜底：读取文件头部 256KB 提取内嵌完整 JPEG 缩略图 (内部含 0x101B -> 0x9431 自动回退)
    try {
      final headerBytes = await downloadPartialObject(handle, 0, 256 * 1024);
      final valid = extractValidJpegSlice(headerBytes);
      if (valid != null && valid.isNotEmpty) {
        _thumbCache[handle] = valid;
        return valid;
      }
    } on PtpException catch (e) {
      _logMediaTransferFailure(
        'partial thumb handle=0x${handle.toRadixString(16)} failed: 0x${e.responseCode.toRadixString(16)}',
      );
    } catch (e) {
      _logMediaTransferFailure(
        'partial thumb handle=0x${handle.toRadixString(16)} error: $e',
      );
    }

    // 4. 终极兜底：若机身仅允许标准 0x1009 GetObject 且非视频/非超大文件，整图拉取提取预览 JPEG
    if (_supports(PtpOpCodes.getObject)) {
      final info = _objectInfoCache[handle];
      final allowFullFallback = info == null ||
          (!info.isVideo && info.size > 0 && info.size <= 24 * 1024 * 1024);
      if (allowFullFallback) {
        try {
          final fullRaw =
              await _client!.executeDataIn(PtpOpCodes.getObject, [handle]);
          final valid = extractValidJpegSlice(fullRaw);
          if (valid != null && valid.isNotEmpty) {
            _thumbCache[handle] = valid;
            return valid;
          }
        } on PtpException catch (e) {
          _markUnsupported(PtpOpCodes.getObject, e);
          _logMediaTransferFailure(
            '0x1009 thumb handle=0x${handle.toRadixString(16)} failed: 0x${e.responseCode.toRadixString(16)}',
          );
        } catch (e) {
          _logMediaTransferFailure(
            '0x1009 thumb handle=0x${handle.toRadixString(16)} error: $e',
          );
        }
      }
    }

    return Uint8List(0);
  }

  /// 按 JPEG 段结构扫描并提取完整、未截断的 JPEG 切片。
  ///
  /// 必须同时包含 SOI (0xFFD8)、帧头 SOF (0xFFC0/C1/C2)、扫描头 SOS (0xFFDA)
  /// 以及对应的外层 EOI (0xFFD9)，防止半截损坏的缩略图被送入解码器或落盘缓存。
  static Uint8List? extractValidJpegSlice(Uint8List raw) {
    if (raw.length < 128) return null;
    Uint8List? bestCandidate;
    var i = 0;
    final limit = raw.length - 4;
    while (i < limit) {
      if (raw[i] == 0xFF && raw[i + 1] == 0xD8 && raw[i + 2] == 0xFF) {
        final end = _findCompleteJpegEnd(raw, i + 2);
        if (end > i + 128) {
          final sliceLen = end - i;
          if (bestCandidate == null || sliceLen > bestCandidate.length) {
            bestCandidate = (i == 0 && end == raw.length)
                ? raw
                : Uint8List.fromList(Uint8List.sublistView(raw, i, end));
          }
          i = end;
          continue;
        }
      }
      i++;
    }
    return bestCandidate;
  }

  /// 从 SOI (0xFFD8) 之后按 JPEG 段结构解析至外层 EOI (0xFFD9)。
  /// 若缺少 SOF/SOS 或熵编码段在到达 EOI 前被截断，返回 -1。
  static int _findCompleteJpegEnd(Uint8List b, int start) {
    var p = start;
    var hasSof = false;
    while (p + 1 < b.length) {
      if (b[p] != 0xFF) {
        p++;
        continue;
      }
      final marker = b[p + 1];
      if (marker == 0xFF) {
        p++; // 连续 0xFF 填充字节
        continue;
      }
      if (marker == 0x00) {
        p += 2;
        continue;
      }
      if (marker == 0xD9) {
        // 只有在见过帧头后直接结束才算有效（正常应在 SOS 分支内返回）
        return hasSof ? p + 2 : -1;
      }
      if (marker == 0xD8 ||
          (marker >= 0xD0 && marker <= 0xD7) ||
          marker == 0x01) {
        p += 2;
        continue;
      }
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        hasSof = true;
      }
      if (marker == 0xDA) {
        // 进入 SOS 扫描流：必须已经见过 SOF，且后续能找到外层 EOI (0xFFD9)
        if (!hasSof) return -1;
        if (p + 3 >= b.length) return -1;
        final sosHeaderLen = (b[p + 2] << 8) | b[p + 3];
        if (sosHeaderLen < 2 || p + 2 + sosHeaderLen >= b.length) return -1;
        p += 2 + sosHeaderLen;
        while (p + 1 < b.length) {
          if (b[p] == 0xFF) {
            final next = b[p + 1];
            if (next == 0xD9) return p + 2; // 找到完整外层 EOI
            if (next == 0xD8) return -1; // 遇到新 SOI 说明前一张图被截断
            if (next == 0x00 || (next >= 0xD0 && next <= 0xD7)) {
              p += 2;
              continue;
            }
            if (next == 0xFF) {
              p++;
              continue;
            }
          }
          p++;
        }
        return -1; // 扫描流直至末尾仍未出现 EOI，判定为截断损坏
      }
      if (p + 3 >= b.length) return -1;
      final segLen = (b[p + 2] << 8) | b[p + 3];
      if (segLen < 2 || p + 2 + segLen > b.length) return -1;
      p += 2 + segLen;
    }
    return -1;
  }

  Future<Uint8List> _executePartialObject64(
    int handle,
    int offset,
    int maxBytes,
  ) async {
    final offsetLow = offset & 0xFFFFFFFF;
    final offsetHigh = (offset >> 32) & 0xFFFFFFFF;
    final maxLow = maxBytes & 0xFFFFFFFF;
    final maxHigh = (maxBytes >> 32) & 0xFFFFFFFF;

    try {
      if (_partialObject64ParamCount == 5) {
        try {
          return await _client!.executeDataIn(
            PtpOpCodes.nikonGetPartialObject64,
            [handle, offsetLow, offsetHigh, maxLow, maxHigh],
          );
        } on PtpException catch (e) {
          if (e.responseCode == PtpOpCodes.responseParameterNotSupported) {
            _partialObject64ParamCount = 4;
            return await _client!.executeDataIn(
              PtpOpCodes.nikonGetPartialObject64,
              [handle, offsetLow, offsetHigh, maxLow],
            );
          }
          rethrow;
        }
      }
      return await _client!.executeDataIn(
        PtpOpCodes.nikonGetPartialObject64,
        [handle, offsetLow, offsetHigh, maxLow],
      );
    } on PtpException catch (e) {
      if (e.responseCode == PtpOpCodes.responseOperationNotSupported) {
        _markUnsupported(PtpOpCodes.nikonGetPartialObject64, e);
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadPartialObject(
      int handle, int offset, int maxBytes) async {
    if (!isConnected) return Uint8List(0);

    // 0x101B 的偏移量只有 32 位，超过 4GiB 的视频会在第 4GB 处被截断。
    // 这时改用 Nikon 的 0x9431 GetPartialObject64：偏移与长度均拆成高低 32 位（5 参数，必要时兼容 4 参数）。
    final needs64Bit = requiresPartialObject64(offset, maxBytes);
    if (needs64Bit) {
      if (_supports(PtpOpCodes.nikonGetPartialObject64)) {
        try {
          return await _executePartialObject64(handle, offset, maxBytes);
        } on PtpException catch (e) {
          _markUnsupported(PtpOpCodes.nikonGetPartialObject64, e);
          throw PtpException(
            PtpOpCodes.nikonGetPartialObject64,
            e.responseCode,
            '相机不支持 64 位分块读取 (0x9431)，无法续传超过 4GiB 的文件',
          );
        }
      }
      throw StateError('相机不支持 0x9431，超过 4GiB 的文件无法分段读取');
    }

    if (_preferPartialObject64 &&
        _supports(PtpOpCodes.nikonGetPartialObject64)) {
      return await _executePartialObject64(handle, offset, maxBytes);
    }

    // 0x101B: GetPartialObject (Handle, Offset, MaxBytes)；Z50II 等 STA 机身若拒绝则回退 0x9431
    try {
      return await _client!
          .executeDataIn(PtpOpCodes.getPartialObject, [handle, offset, maxBytes]);
    } on PtpException catch (e) {
      final canFallbackTo64 =
          e.responseCode == PtpOpCodes.responseAccessDenied ||
              e.responseCode == PtpOpCodes.responseOperationNotSupported ||
              e.responseCode == PtpOpCodes.responseParameterNotSupported;
      if (!canFallbackTo64) rethrow;
      _logMediaTransferFailure(
        '0x101B handle=0x${handle.toRadixString(16)} offset=$offset rejected: 0x${e.responseCode.toRadixString(16)}',
      );
      if (_supports(PtpOpCodes.nikonGetPartialObject64)) {
        try {
          final data = await _executePartialObject64(handle, offset, maxBytes);
          _preferPartialObject64 = true;
          return data;
        } on PtpException catch (e64) {
          _logMediaTransferFailure(
            '0x9431 fallback handle=0x${handle.toRadixString(16)} offset=$offset failed: 0x${e64.responseCode.toRadixString(16)}',
          );
          rethrow;
        }
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> downloadFullObject(
    int handle,
    int totalSize, {
    Function(int current, int total)? onProgress,
  }) async {
    const chunkSize = 512 * 1024; // 512KB 分块（兼顾 Wi-Fi 高吞吐与进度条平滑实时流动）
    final builder = BytesBuilder();
    var currentOffset = 0;

    while (currentOffset < totalSize) {
      final requestBytes = (totalSize - currentOffset > chunkSize)
          ? chunkSize
          : (totalSize - currentOffset);
      Uint8List chunk = Uint8List(0);
      int retries = 0;
      PtpException? fatalRejection;

      // GetPartialObject 遇到超时/设备忙时重试；明确协议拒绝时不再无效重试 3 次。
      while (retries < 3) {
        try {
          chunk =
              await downloadPartialObject(handle, currentOffset, requestBytes);
          if (chunk.isNotEmpty) break;
        } on PtpException catch (e) {
          if (e.responseCode == PtpOpCodes.responseAccessDenied ||
              e.responseCode == PtpOpCodes.responseOperationNotSupported ||
              e.responseCode == PtpOpCodes.responseParameterNotSupported) {
            fatalRejection = e;
            break;
          }
        } catch (_) {}
        retries++;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (chunk.isEmpty &&
          currentOffset == 0 &&
          _supports(PtpOpCodes.getObject)) {
        try {
          final full =
              await _client!.executeDataIn(PtpOpCodes.getObject, [handle]);
          if (full.isNotEmpty) {
            if (totalSize > 0 && full.length != totalSize) {
              throw CameraFailure(
                CameraFailureKind.incomplete,
                details: <String, Object?>{
                  'actual': full.length,
                  'total': totalSize,
                },
              );
            }
            onProgress?.call(full.length, totalSize > 0 ? totalSize : full.length);
            return full;
          }
        } on PtpException catch (e) {
          _markUnsupported(PtpOpCodes.getObject, e);
          _logMediaTransferFailure(
            '0x1009 full handle=0x${handle.toRadixString(16)} failed: 0x${e.responseCode.toRadixString(16)}',
          );
        } catch (e) {
          if (e is CameraFailure) rethrow;
          _logMediaTransferFailure(
            '0x1009 full handle=0x${handle.toRadixString(16)} error: $e',
          );
        }
      }

      if (chunk.isEmpty) {
        if (fatalRejection != null) {
          _logMediaTransferFailure(
            'downloadFullObject handle=0x${handle.toRadixString(16)} aborted at $currentOffset: 0x${fatalRejection.responseCode.toRadixString(16)}',
          );
        }
        throw CameraFailure(
          CameraFailureKind.emptyChunk,
          details: <String, Object?>{'offset': currentOffset},
        );
      }

      builder.add(chunk);
      currentOffset += chunk.length;
      onProgress?.call(currentOffset, totalSize);
    }

    final bytes = builder.toBytes();
    if (bytes.length != totalSize) {
      throw CameraFailure(
        CameraFailureKind.incomplete,
        details: <String, Object?>{'actual': bytes.length, 'total': totalSize},
      );
    }
    return bytes;
  }

  // ==========================================
  // 事件处理与私有辅助函数
  // ==========================================

  /// 底层传输报告被动掉线：更新状态并交给上层重连控制器。
  /// 用户主动 `disconnect()` 不会走到这里。
  void _notifyUnexpectedDisconnect() {
    if (_userDisconnect || _recoverySuppressed) return;
    if (_state == CameraConnectionState.disconnected) return;
    _state = CameraConnectionState.error;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
    onUnexpectedDisconnect?.call();
  }

  void _handleCameraEvent(PtpPacket eventPacket) async {
    // PTP/IP Event 负载：eventCode(2) + transactionId(4) + param1(4)...
    if (eventPacket.payload.length < 2) return;
    final eventCode = eventPacket.getUint16(0);
    if (!_eventCodeController.isClosed) {
      _eventCodeController.add(eventCode);
    }
    if (eventPacket.payload.length >= 10) {
      if (eventCode == PtpOpCodes.eventObjectAdded) {
        final newHandle = eventPacket.getUint32(6);
        final fileInfo = await getObjectInfo(newHandle);
        if (fileInfo != null) {
          _photoCapturedController.add(fileInfo);
        }
      } else if (eventCode == PtpOpCodes.eventObjectRemoved) {
        final removedHandle = eventPacket.getUint32(6);
        _objectInfoCache.remove(removedHandle);
        _thumbCache.remove(removedHandle);
        _knownFileHandles.remove(removedHandle);
        if (!_objectRemovedController.isClosed) {
          _objectRemovedController.add(removedHandle);
        }
      }
    }
  }

  Future<void> _queryDeviceInfo() async {
    final infoData = await _client!.executeDataIn(PtpOpCodes.getDeviceInfo);
    if (infoData.isNotEmpty) {
      _deviceInfo = NikonDeviceInfo.parse(infoData);
      if (_deviceInfo.model.isNotEmpty && _deviceInfo.model != 'Nikon Camera') {
        _cameraModel = _deviceInfo.model;
      }
      _isRestrictedPairingSession =
          isRestrictedStaPairingProfile(_deviceInfo.operationsSupported);
      _log(
          '【相机识别成功】型号: $_cameraModel, 固件: ${_deviceInfo.deviceVersion}, 序列号: ${_deviceInfo.serialNumber}, 受限配对态: $_isRestrictedPairingSession');
      final ops = _deviceInfo.operationsSupported;
      if (ops.isNotEmpty) {
        _log(
            '[media] ops(${ops.length}): '
            '1007=${ops.contains(PtpOpCodes.getObjectHandles)} '
            '1008=${ops.contains(PtpOpCodes.getObjectInfo)} '
            '1009=${ops.contains(PtpOpCodes.getObject)} '
            '100A=${ops.contains(PtpOpCodes.getThumb)} '
            '101B=${ops.contains(PtpOpCodes.getPartialObject)} '
            '9431=${ops.contains(PtpOpCodes.nikonGetPartialObject64)} '
            '9805=${ops.contains(PtpOpCodes.mtpGetObjectPropList)} '
            '9803=${ops.contains(PtpOpCodes.mtpGetObjectPropValue)} '
            '9421=${ops.contains(PtpOpCodes.nikonGetObjectSize)} '
            '9435=${ops.contains(PtpOpCodes.nikonChangeAppMode)}');
      }
    }

    if (_isRestrictedPairingSession) {
      _logCallback?.call(
          '【STA 待配对】相机当前仅公布受限配对操作集 (0x952B/0x935A)，跳过存储卡与扩展属性查询，等待配对确认');
      return;
    }

    // 备用机型探测: 若型号未能从 DeviceInfo 中解析出，尝试从厂商扩展属性 0xD1A2 读取
    if (_cameraModel == 'Nikon Camera') {
      try {
        final propData = await _client!
            .executeDataIn(PtpOpCodes.getDevicePropValue, [0xD1A2]);
        if (propData.length > 1) {
          final s = PtpByteReader(propData).readPtpString().trim();
          if (s.isNotEmpty) {
            _cameraModel = NikonDeviceInfo.normalizeModelName(s);
            _logCallback?.call('【从属性 0xD1A2 读取机型成功】: $_cameraModel');
          }
        }
      } catch (_) {}
    }

    // 查询物理卡槽并更新单/双卡槽配置
    try {
      await listStorageIds();
      _logCallback?.call(
          '【卡槽检索完成】识别到 ${_detectedStorageIds.length} 个存储卷，单卡槽机型判定: $isSingleSlotCamera');
    } catch (_) {}
  }

  /// 读取 STA 首次配对的 4 位验证码 (`0x952B`)。
  ///
  /// 部分机身刚进入配对向导时首次查询可能返回 `0x2019 DeviceBusy` 或空挑战，
  /// 此处最多轮询 [maxAttempts] 次，每次间隔 [pollInterval]。
  Future<NikonPairingChallenge> requestStaPairingChallenge({
    int maxAttempts = 10,
    Duration pollInterval = const Duration(milliseconds: 250),
  }) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接，无法获取配对码');
    }

    Object? lastError;
    NikonPairingChallenge? lastChallenge;
    final attempts = maxAttempts.clamp(1, 20);
    for (var i = 1; i <= attempts; i++) {
      try {
        final data = await client.executeDataIn(PtpOpCodes.nikonGetPairingInfo);
        final challenge = NikonPairingChallenge.parse(
          data,
          cameraName: _cameraModel,
        );
        lastChallenge = challenge;
        if (challenge.hasPin || (data.isNotEmpty && i == attempts)) {
          _logCallback?.call(
              '【STA 配对】第 $i 次读取 0x952B 成功，PIN=${challenge.pin ?? "未知(${challenge.rawHex})"}');
          return challenge;
        }
      } on PtpException catch (e) {
        lastError = e;
        if (e.responseCode != PtpOpCodes.responseDeviceBusy &&
            i >= attempts) {
          rethrow;
        }
      } catch (e) {
        lastError = e;
        if (i >= attempts) rethrow;
      }
      if (i < attempts && pollInterval > Duration.zero) {
        await Future<void>.delayed(pollInterval);
      }
    }

    if (lastChallenge != null) return lastChallenge;
    throw StateError('无法从相机获取配对验证码: ${lastError ?? "响应为空"}');
  }

  /// 提交 STA 首次配对确认 (`0x935A`, 参数 `0x2001`)。
  ///
  /// 成功后相机屏幕上会提示配对完成并保存该客户端 GUID 到当前配置文件。
  Future<void> confirmStaPairing() async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接，无法提交配对确认');
    }
    await client.executeOperation(
      PtpOpCodes.nikonConfirmPairing,
      [PtpOpCodes.responseOk],
    );
    _logCallback?.call('【STA 配对】已提交配对确认 (0x935A → 0x2001)');
  }

  Future<void> _queryBatteryLevel() async {
    try {
      // 0x5001: BatteryLevel (Device Property)
      final propData =
          await _client!.executeDataIn(PtpOpCodes.getDevicePropValue, [0x5001]);
      if (propData.isNotEmpty) {
        _batteryLevel = propData[0].clamp(0, 100);
      }
    } catch (_) {}
  }

  List<int> _parseUint32Array(Uint8List data) {
    if (data.length < 4) return [];
    final reader = PtpByteReader(data);
    final count = reader.readUint32();
    if (count <= 0 || count > 100000) return [];
    final list = <int>[];
    for (var i = 0; i < count; i++) {
      if (reader.remaining < 4) break;
      list.add(reader.readUint32());
    }
    return list;
  }

  void dispose() {
    disconnect();
    _photoCapturedController.close();
    _stateController.close();
    _eventCodeController.close();
    _objectRemovedController.close();
  }

  // ==========================================
  // 实时取景与遥控拍摄 (0x9201 / 0x9203 / 0x9202 / 0x100E / 0x9205)
  // ==========================================

  @override
  CameraIoCoordinator get io => _io;

  @override
  CameraTransportKind get transportKind => _transportKind;

  /// 能力判定：优先看 DeviceInfo 的操作码表。
  /// 若 DeviceInfo 走了启发式字符串回退、操作码表为空，则乐观允许尝试，
  /// 但把相机明确拒绝过的操作码记下来，避免逐帧重试。
  bool _supports(int opCode) {
    if (!isConnected) return false;
    if (_unsupportedOps.contains(opCode)) return false;
    final ops = _deviceInfo.operationsSupported;
    if (ops.isEmpty) return true;
    return ops.contains(opCode);
  }

  void _markUnsupported(int opCode, Object error) {
    if (error is! PtpException) return;
    if (error.responseCode == PtpOpCodes.responseOperationNotSupported ||
        error.responseCode == 0x2006) {
      _unsupportedOps.add(opCode);
    }
  }

  @override
  bool get supportsLiveView {
    if (_isRestrictedPairingSession) return false;
    return _supports(PtpOpCodes.nikonStartLiveView) &&
        (_supports(PtpOpCodes.nikonGetLiveViewImage) ||
            _supports(PtpOpCodes.nikonGetLiveViewImageEx));
  }

  @override
  bool get supportsRemoteCapture =>
      _supports(PtpOpCodes.initiateCapture) ||
      _supports(PtpOpCodes.nikonCaptureToCard);

  @override
  bool get supportsTapToFocus => _supports(PtpOpCodes.nikonChangeAfArea);

  @override
  bool get supportsAfDrive => _supports(PtpOpCodes.nikonAfDrive);

  @override
  bool get supportsManualFocus => _supports(PtpOpCodes.nikonMfDrive);

  @override
  bool get supportsExposureWrite => _supports(PtpOpCodes.setDevicePropValue);

  @override
  bool get isVerifiedBody =>
      _cameraModel.toUpperCase().replaceAll(' ', '').contains('Z30');

  /// 相机返回 `0x2019` 时短暂等待后重试；其余错误直接抛出。
  Future<void> _retryOnBusy(
    Future<void> Function() action, {
    int attempts = 3,
  }) async {
    var remaining = attempts;
    while (true) {
      try {
        await action();
        return;
      } on PtpException catch (e) {
        if (e.responseCode != PtpOpCodes.responseDeviceBusy || remaining <= 1) {
          rethrow;
        }
        remaining--;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  @override
  Future<void> startLiveView() async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    if (_liveViewActive) return;
    if (!supportsLiveView) {
      throw PtpException(PtpOpCodes.nikonStartLiveView,
          PtpOpCodes.responseOperationNotSupported, '当前相机不支持实时取景');
    }
    try {
      await _retryOnBusy(
          () => client.executeOperation(PtpOpCodes.nikonStartLiveView));
      _liveViewActive = true;
    } catch (e) {
      _markUnsupported(PtpOpCodes.nikonStartLiveView, e);
      rethrow;
    }
  }

  @override
  Future<Uint8List> fetchLiveViewFrame() async {
    final gate = _liveViewCycleGate;
    if (gate != null) {
      await gate;
    }
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    final preferEx = !_supports(PtpOpCodes.nikonGetLiveViewImage) &&
        _supports(PtpOpCodes.nikonGetLiveViewImageEx);
    if (preferEx) {
      return client.executeDataIn(PtpOpCodes.nikonGetLiveViewImageEx);
    }
    try {
      return await client.executeDataIn(PtpOpCodes.nikonGetLiveViewImage);
    } on PtpException catch (e) {
      final canFallbackEx = (e.responseCode ==
                  PtpOpCodes.responseOperationNotSupported ||
              e.responseCode == PtpOpCodes.responseNotLiveView) &&
          _supports(PtpOpCodes.nikonGetLiveViewImageEx);
      if (!canFallbackEx) rethrow;
      _unsupportedOps.add(PtpOpCodes.nikonGetLiveViewImage);
      _logCallback?.call(
          '【取景降级】0x9203 返回 0x${e.responseCode.toRadixString(16)}，自动切换至 0x9428 GetLiveViewImageEx');
      return client.executeDataIn(PtpOpCodes.nikonGetLiveViewImageEx);
    }
  }

  @override
  Future<void> endLiveView({bool force = false}) async {
    final client = _client;
    final wasActive = _liveViewActive;
    _liveViewActive = false;
    if (client == null || (!wasActive && !force)) return;
    try {
      await client.executeOperation(PtpOpCodes.nikonEndLiveView);
    } catch (_) {
      // 退出取景是尽力而为：相机可能已经自行退出或链路已断。
    }
  }

  @override
  Future<void> initiateCapture({bool preserveFocus = false}) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    // 焦点包围步进后需要保持当前 MF 焦点位置，优先使用 0x9207 [1, 0]（不重新触发 AF）。
    if (preserveFocus && _supports(PtpOpCodes.nikonCaptureToCard)) {
      try {
        await _retryOnBusy(
          () => client.executeOperation(
              PtpOpCodes.nikonCaptureToCard, const <int>[1, 0]),
          attempts: 2,
        );
        return;
      } on PtpException catch (e) {
        if (e.responseCode != PtpOpCodes.responseOperationNotSupported &&
            e.responseCode != 0x2006 &&
            e.responseCode != PtpOpCodes.responseNikonInvalidStatus) {
          rethrow;
        }
      }
    }
    try {
      await _retryOnBusy(
        () => client.executeOperation(
            PtpOpCodes.initiateCapture, const <int>[0, 0]),
        attempts: 2,
      );
      return;
    } on PtpException catch (e) {
      _markUnsupported(PtpOpCodes.initiateCapture, e);
      // 部分固件只接受尼康私有的「拍照并存入卡」。
      if (e.responseCode == PtpOpCodes.responseOperationNotSupported &&
          _supports(PtpOpCodes.nikonCaptureToCard)) {
        await _retryOnBusy(
          () => client.executeOperation(
              PtpOpCodes.nikonCaptureToCard, const <int>[0, 0]),
          attempts: 2,
        );
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> moveAfArea(int x, int y) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    try {
      await client.executeOperation(
          PtpOpCodes.nikonChangeAfArea, <int>[x, y]);
    } catch (e) {
      _markUnsupported(PtpOpCodes.nikonChangeAfArea, e);
      rethrow;
    }
  }

  @override
  Future<void> afDrive() async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    try {
      await client.executeOperation(PtpOpCodes.nikonAfDrive);
    } catch (e) {
      _markUnsupported(PtpOpCodes.nikonAfDrive, e);
      rethrow;
    }
  }

  @override
  Future<int> deviceReady() async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    try {
      await client.executeOperation(PtpOpCodes.nikonDeviceReady);
      return PtpOpCodes.responseOk;
    } on PtpException catch (e) {
      // 这里的「失败」本身就是结果：0xA002 未合焦、0x2019 仍在忙。
      return e.responseCode;
    }
  }

  @override
  Future<void> mfDrive(MfDirection direction, int steps) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    final clamped = steps.clamp(1, 32767);
    try {
      await client.executeOperation(
        PtpOpCodes.nikonMfDrive,
        <int>[direction.opCode, clamped],
      );
    } catch (e) {
      _markUnsupported(PtpOpCodes.nikonMfDrive, e);
      rethrow;
    }
  }

  @override
  Future<void> cancelFocusDrive() async {
    final client = _client;
    if (client == null || !isConnected) return;
    try {
      await client.executeOperation(PtpOpCodes.nikonAfDriveCancel);
    } catch (_) {
      // 部分固件不接受取消；小步进本身也会很快结束，忽略即可。
    }
  }

  // ==========================================
  // 录像控制 (0x920A / 0x920B / 0xD1A6 / 0xD0A4)
  // ==========================================

  @override
  bool get supportsMovieRecording =>
      _supports(PtpOpCodes.nikonStartMovieRecInCard) &&
      _supports(PtpOpCodes.nikonEndMovieRec);

  Future<void> _enterMovieApplicationMode() async {
    final client = _client;
    if (client == null || !isConnected) return;
    if (_supports(PtpOpCodes.nikonChangeAppMode)) {
      try {
        await client.executeOperation(
            PtpOpCodes.nikonChangeAppMode, const <int>[1]);
        _inMovieAppMode = true;
        AppLogManager.instance
            .add('[movie] entered application mode (0x9435=1)');
        return;
      } on PtpException catch (e) {
        _markUnsupported(PtpOpCodes.nikonChangeAppMode, e);
        AppLogManager.instance.add(
            '[movie] 0x9435(1) returned 0x${e.responseCode.toRadixString(16)}');
      } catch (e) {
        AppLogManager.instance.add('[movie] 0x9435(1) failed: $e');
      }
    }
    // 兜底：部分机型通过属性 0xD1F0 (ApplicationMode) 切换。
    try {
      await writeUintProperty(PtpOpCodes.nikonPropApplicationMode, 1);
      _inMovieAppMode = true;
      AppLogManager.instance.add('[movie] entered application mode (0xD1F0=1)');
    } catch (_) {}
  }

  @override
  Future<void> exitMovieApplicationMode() async {
    final client = _client;
    if (!_inMovieAppMode) return;
    _inMovieAppMode = false;
    if (client == null || !isConnected) return;
    if (_supports(PtpOpCodes.nikonChangeAppMode)) {
      try {
        await client.executeOperation(
            PtpOpCodes.nikonChangeAppMode, const <int>[0]);
        AppLogManager.instance
            .add('[movie] exited application mode (0x9435=0)');
        return;
      } catch (e) {
        AppLogManager.instance.add('[movie] 0x9435(0) failed: $e');
      }
    }
    try {
      await writeUintProperty(PtpOpCodes.nikonPropApplicationMode, 0);
    } catch (_) {}
  }

  /// 在已进入 Application Mode (0x9435=1) 的前提下重建视频取景会话并等待就绪。
  /// 参考 libgphoto2 `camera_nikon_movie_capture` (config.c L10346-10396)。
  Future<void> _cycleMovieLiveViewSession() async {
    final completer = Completer<void>();
    _liveViewCycleGate = completer.future;
    try {
      if (_liveViewActive) {
        try {
          await endLiveView(force: true);
        } catch (_) {}
      }
      await _enterMovieApplicationMode();
      try {
        await writeUintProperty(PtpOpCodes.nikonPropRecordingMedia, 1);
      } catch (_) {}
      await startLiveView();
      for (int i = 0; i < 8; i++) {
        final rc = await deviceReady();
        if (rc != PtpOpCodes.responseDeviceBusy) break;
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    } finally {
      _liveViewCycleGate = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _sendStartMovieRecOp(PtpTransport client) async {
    try {
      // 0x920A 在 libgphoto2 里是「无参数」操作码。
      await client.executeOperation(PtpOpCodes.nikonStartMovieRecInCard);
    } on PtpException catch (e) {
      // 少数机身反过来要求 [0, 0]，只在这种情况下再试一次。
      if (e.responseCode == 0x2006 || e.responseCode == 0x2005) {
        await client.executeOperation(
            PtpOpCodes.nikonStartMovieRecInCard, const <int>[0, 0]);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> startMovieRecording() async {
    final client = _client;
    if (client == null || !isConnected) throw StateError('相机未连接');
    bool cycledLiveView = false;
    try {
      // 1. 尼康 Z 系列通过 USB/PTP 启动录像前必须先进入 Application Mode (0x9435=1)，
      //    否则 0xD0A4 bit 14 (0x4000, Not in application mode) 置位且 0x920A 返回 0xA004。
      await _enterMovieApplicationMode();

      // 2. 若取景尚未开启，或 0xD0A4 bit 14 仍置位（说明旧取景是在非 Application Mode 下开启的），
      //    按 libgphoto2 流程重建一次视频取景并等待 0x90C8 DeviceReady。
      final prohibit = await readMovieRecProhibition();
      if (!_liveViewActive || (prohibit != null && (prohibit & 0x4000) != 0)) {
        cycledLiveView = true;
        await _cycleMovieLiveViewSession();
      }

      // 3. 发送 0x920A；若首次仍报 0xA004 且尚未重建过取景，则重建一次取景后再试。
      try {
        await _sendStartMovieRecOp(client);
      } on PtpException catch (e) {
        if (e.responseCode == PtpOpCodes.responseNikonInvalidStatus &&
            !cycledLiveView) {
          AppLogManager.instance.add(
              '[movie] 0x920A returned 0xA004, cycling LiveView under ApplicationMode(1)');
          await _cycleMovieLiveViewSession();
          await _sendStartMovieRecOp(client);
          return;
        }
        rethrow;
      }
    } on PtpException catch (e) {
      await exitMovieApplicationMode();
      _markUnsupported(PtpOpCodes.nikonStartMovieRecInCard, e);
      rethrow;
    } catch (e) {
      await exitMovieApplicationMode();
      _markUnsupported(PtpOpCodes.nikonStartMovieRecInCard, e);
      rethrow;
    }
  }

  @override
  Future<void> stopMovieRecording() async {
    final client = _client;
    if (client == null || !isConnected) throw StateError('相机未连接');
    try {
      await client.executeOperation(PtpOpCodes.nikonEndMovieRec);
    } catch (e) {
      _markUnsupported(PtpOpCodes.nikonEndMovieRec, e);
      rethrow;
    }
  }

  @override
  Future<int?> readLiveViewSelector() =>
      _readUintProperty(PtpOpCodes.devicePropLiveViewSelector);

  @override
  Future<int?> readMovieRecProhibition() =>
      _readUintProperty(PtpOpCodes.devicePropMovieRecProhibition);

  @override
  Future<void> setLiveViewSelector(int value) async {
    final bytes = Uint8List(1)..[0] = value & 0xFF;
    await writeDevicePropValue(PtpOpCodes.devicePropLiveViewSelector, bytes);
  }

  // ---- HdrDriver ----
  @override
  Future<PtpDevicePropDesc?> readPropertyDesc(int propertyId) async {
    if (!isConnected) return null;
    final cached = _propDescCache[propertyId];
    if (cached != null) return cached;
    try {
      final raw = await fetchDevicePropDesc(propertyId);
      final parsed = PtpDevicePropDesc.parse(raw);
      if (parsed != null) {
        _propDescCache[propertyId] = parsed;
      }
      return parsed;
    } catch (e) {
      AppLogManager.instance
          .add('[prop] desc 0x${propertyId.toRadixString(16)} failed: $e');
      return null;
    }
  }

  @override
  Future<int?> readUintProperty(int propertyId) =>
      _readUintProperty(propertyId);

  static bool _isKnownUint16Property(int propertyId) {
    switch (propertyId) {
      case PtpOpCodes.nikonPropHdrMode: // 0xD130 (UINT16 on Z 30)
      case PtpOpCodes.nikonPropHdrSmoothing: // 0xD132 (UINT16 on Z 30)
      case PtpOpCodes.nikonPropActiveFolder: // 0xD15B
      case PtpOpCodes.devicePropAeBracketingPattern: // 0xD0C2
      case PtpOpCodes.nikonPropActivePicCtrlItem: // 0xD200
      case PtpOpCodes.devicePropFNumber: // 0x5007
      case PtpOpCodes.devicePropExposureMode: // 0x500E
      case PtpOpCodes.devicePropExposureIndex: // 0x500F
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> writeUintProperty(int propertyId, int value) async {
    final desc = await readPropertyDesc(propertyId);
    if (desc != null) {
      await writeDevicePropValue(propertyId, desc.encodeValue(value));
      return;
    }
    if (_isKnownUint16Property(propertyId)) {
      final payload = Uint8List(2)
        ..buffer.asByteData().setUint16(0, value & 0xFFFF, Endian.little);
      await writeDevicePropValue(propertyId, payload);
      return;
    }
    await writeDevicePropValue(propertyId, Uint8List(1)..[0] = value & 0xFF);
  }

  // ---- CameraFolderDriver ----
  @override
  Future<int?> readActiveFolder() async {
    if (!isConnected) return null;
    try {
      final data = await fetchDevicePropValue(PtpOpCodes.nikonPropActiveFolder);
      if (data.length >= 2) {
        return ByteData.sublistView(data, 0, 2).getUint16(0, Endian.little);
      }
      return data.isEmpty ? null : data[0];
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeActiveFolder(int folderNumber) async {
    final payload = Uint8List(2)
      ..buffer.asByteData().setUint16(0, folderNumber & 0xFFFF, Endian.little);
    await writeDevicePropValue(PtpOpCodes.nikonPropActiveFolder, payload);
  }

  /// 属性宽度随机型不同：UINT8 返回 1 字节，UINT16 返回 2 字节，UINT32 返回 4 字节。
  Future<int?> _readUintProperty(int propertyId) async {
    if (!isConnected) return null;
    try {
      final data = await fetchDevicePropValue(propertyId);
      if (data.isEmpty) return null;
      if (data.length >= 4) {
        return ByteData.sublistView(data, 0, 4).getUint32(0, Endian.little);
      }
      if (data.length >= 2) {
        return ByteData.sublistView(data, 0, 2).getUint16(0, Endian.little);
      }
      return data[0];
    } catch (e) {
      AppLogManager.instance
          .add('[prop] read 0x${propertyId.toRadixString(16)} failed: $e');
      return null;
    }
  }

  @override
  Stream<int> get eventCodes => _eventCodeController.stream;

  @override
  Future<Uint8List> fetchDevicePropDesc(int propertyId) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    return client.executeDataIn(
        PtpOpCodes.getDevicePropDesc, <int>[propertyId]);
  }

  @override
  Future<Uint8List> fetchDevicePropValue(int propertyId) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    return client.executeDataIn(
        PtpOpCodes.getDevicePropValue, <int>[propertyId]);
  }

  @override
  Future<void> writeDevicePropValue(int propertyId, Uint8List payload) async {
    final client = _client;
    if (client == null || !isConnected) {
      throw StateError('相机未连接');
    }
    await client.executeDataOut(
        PtpOpCodes.setDevicePropValue, payload, <int>[propertyId]);
  }

  // ==========================================
  // 尼康优化校准 (Picture Control C1–C9, 0x90CC / 0x90CD / 0xD200)
  // ==========================================

  /// 当前连接的机身是否支持优化校准 C1–C9 读写 (0x90CC & 0x90CD)。
  bool get supportsPictureControlWrite {
    if (!isConnected) return false;
    final ops = _deviceInfo.operationsSupported;
    if (ops.isEmpty) {
      // 当 DeviceInfo 采用备用启发式字符串扫描而未解析出完整操作码表时，允许尝试
      return true;
    }
    return ops.contains(PtpOpCodes.nikonGetPicCtrlData) &&
        ops.contains(PtpOpCodes.nikonSetPicCtrlData);
  }

  /// 是否为经过完整实机验证的优化校准直写机型（Nikon Z 30）。
  bool get isVerifiedPictureControlModel {
    final m = _cameraModel.toUpperCase().replaceAll(' ', '');
    return m.contains('Z30');
  }

  /// 读取相机当前激活的优化校准 Profile ID (0xD200 ActivePicCtrlItem)。
  /// 返回值：1..8 为内置基底，101..120 为创意优化校准，201..209 对应自定义槽 C1..C9。
  Future<int?> getActivePictureControlProfileId() async {
    if (!isConnected || _client == null) return null;
    try {
      final data = await _client!.executeDataIn(
        PtpOpCodes.getDevicePropValue,
        [PtpOpCodes.nikonPropActivePicCtrlItem],
      );
      if (data.length >= 2) {
        return data[0] | (data[1] << 8);
      } else if (data.length == 1) {
        return data[0];
      }
    } catch (_) {}
    return null;
  }

  /// 将指定 Profile ID (如 201..209 对应 C1..C9) 设为相机当前激活的优化校准 (0xD200)。
  Future<bool> setActivePictureControl(int profileId) async {
    if (!isConnected || _client == null) return false;
    try {
      final payload = Uint8List.fromList([
        profileId & 0xFF,
        (profileId >> 8) & 0xFF,
      ]);
      await _client!.executeDataOut(
        PtpOpCodes.setDevicePropValue,
        payload,
        [PtpOpCodes.nikonPropActivePicCtrlItem],
      );
      final readback = await getActivePictureControlProfileId();
      return readback == null || readback == profileId;
    } catch (e) {
      _logCallback?.call('【设置当前优化校准 0xD200 失败】: $e');
      return false;
    }
  }

  /// 枚举相机 C1–C9 (Profile ID 201–209) 共 9 个自定义优化校准槽位状态。
  Future<List<CameraPictureControlSlot>> listPictureControlSlots() async {
    if (!isConnected || _client == null) {
      throw StateError('Camera is not connected.');
    }
    final activeProfileId = await getActivePictureControlProfileId();
    final slots = <CameraPictureControlSlot>[];

    for (var slot = 1; slot <= 9; slot++) {
      final profileId = 200 + slot;
      final isActive = activeProfileId == profileId;
      try {
        final raw = await _client!.executeDataIn(
          PtpOpCodes.nikonGetPicCtrlData,
          [profileId, 0],
        );
        if (raw.length == Np3Codec.wireShortLength ||
            raw.length == Np3Codec.wireFullLength) {
          final recipe = Np3Codec.fromWirePayload(raw);
          slots.add(CameraPictureControlSlot(
            slotNumber: slot,
            profileId: profileId,
            isPopulated: true,
            isActive: isActive,
            recipe: recipe,
            rawWireBytes: raw,
          ));
        } else {
          slots.add(CameraPictureControlSlot(
            slotNumber: slot,
            profileId: profileId,
            isPopulated: false,
            isActive: isActive,
          ));
        }
      } catch (_) {
        // 若空槽位返回 0x2005 / 0x2006 或未初始化，记为空槽位
        slots.add(CameraPictureControlSlot(
          slotNumber: slot,
          profileId: profileId,
          isPopulated: false,
          isActive: isActive,
        ));
      }
    }
    return slots;
  }

  /// 将配方写入相机自定义优化校准槽位 C1–C9 (Profile ID 201–209)，并读回校验。
  ///
  /// 相机可能对负载做归一化（36/614 字节、名称填充、原生标志位），因此读回校验
  /// 以 [Np3Codec.sameParameters] 的语义比较为准；校验不通过不抛异常，交由调用方
  /// 结合相机槽位实际状态决定提示。
  Future<PictureControlWriteResult> writePictureControlSlot({
    required int slotNumber,
    required PictureControlRecipe recipe,
    bool setActive = false,
  }) async {
    if (!isConnected || _client == null) {
      throw StateError('Camera is not connected.');
    }
    if (slotNumber < 1 || slotNumber > 9) {
      throw ArgumentError.value(slotNumber, 'slotNumber', 'Must be in 1..9');
    }
    // 若为 Flexible Color ("0310") 配方，在写入机身 C1–C9 槽位前于内存中自动拟合转换为标准 NP3
    var targetRecipe = recipe;
    if (targetRecipe.isFlexibleColor) {
      final stdBytes = Np3Codec.convertFlexibleToStandardNp3Bytes(targetRecipe);
      targetRecipe = Np3Codec.parse(stdBytes);
    }

    final profileId = 200 + slotNumber;

    // 1. 对非 Neutral 基底，先读取机身内置基底 (profile = base.wireId, mode = 0) 校验长度并获取原生标志位
    Uint8List? nativeBaseTemplate;
    if (targetRecipe.base != PictureControlBase.neutral) {
      try {
        final baseBytes = await _client!.executeDataIn(
          PtpOpCodes.nikonGetPicCtrlData,
          [targetRecipe.base.wireId, 0],
        );
        if (baseBytes.isNotEmpty &&
            baseBytes.length != Np3Codec.wireShortLength &&
            baseBytes.length != Np3Codec.wireFullLength) {
          throw StateError(
            'Unexpected camera Picture Control wire length (${baseBytes.length} bytes).',
          );
        }
        if (baseBytes.length >= Np3Codec.wireShortLength) {
          nativeBaseTemplate = baseBytes;
        }
      } catch (e) {
        if (e is StateError) rethrow;
        // 若内置基底读取被跳过，回退默认标志位
      }
    }

    // 2. 组装 36 或 614 字节线上负载
    final wirePayload = Np3Codec.toWirePayload(
      targetRecipe,
      nativeBaseTemplate: nativeBaseTemplate,
    );

    // 3. 发送 0x90CD SetPicCtrlData [profileId, 0]
    await _client!.executeDataOut(
      PtpOpCodes.nikonSetPicCtrlData,
      wirePayload,
      [profileId, 0],
    );

    // 4. 调用 0x90CC GetPicCtrlData [profileId, 0] 读回校验；不一致时短暂等待后再读一次
    var verified = await _tryVerifySlot(profileId, targetRecipe, wirePayload);
    if (!verified && isConnected && _client != null) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      verified = await _tryVerifySlot(profileId, targetRecipe, wirePayload);
    }

    _logCallback?.call(
      verified
          ? '【色彩优化写入成功】槽位 C$slotNumber ($profileId) <- ${recipe.cameraName} (读回校验通过)'
          : '【色彩优化写入校验未通过】槽位 C$slotNumber ($profileId) <- ${recipe.cameraName}',
    );

    // 5. 可选：将刚写入的槽位设为相机当前激活优化校准 (0xD200)
    var active = false;
    if (setActive) {
      active = await setActivePictureControl(profileId);
    }
    return PictureControlWriteResult(verified: verified, active: active);
  }

  /// 只读取指定槽位并与目标配方做语义比较，供写入后的兜底判定使用。
  Future<bool> verifyPictureControlSlot({
    required int slotNumber,
    required PictureControlRecipe recipe,
  }) async {
    if (!isConnected || _client == null) return false;
    if (slotNumber < 1 || slotNumber > 9) {
      throw ArgumentError.value(slotNumber, 'slotNumber', 'Must be in 1..9');
    }
    var target = recipe;
    if (target.isFlexibleColor) {
      final stdBytes = Np3Codec.convertFlexibleToStandardNp3Bytes(target);
      target = Np3Codec.parse(stdBytes);
    }
    return _tryVerifySlot(200 + slotNumber, target, null);
  }

  Future<bool> _tryVerifySlot(
    int profileId,
    PictureControlRecipe target,
    Uint8List? writtenPayload,
  ) async {
    if (_client == null) return false;
    try {
      final readback = await _client!.executeDataIn(
        PtpOpCodes.nikonGetPicCtrlData,
        [profileId, 0],
      );
      if (writtenPayload != null &&
          Np3Codec.verifyWireReadback(writtenPayload, readback)) {
        return true;
      }
      if (readback.length != Np3Codec.wireShortLength &&
          readback.length != Np3Codec.wireFullLength) {
        return false;
      }
      return Np3Codec.sameParameters(
          target, Np3Codec.fromWirePayload(readback));
    } catch (_) {
      return false;
    }
  }

  /// 将相机槽位 C1–C9 的线上数据直接导出为标准 .NP3 文件二进制。
  Uint8List exportSlotAsNp3Bytes(CameraPictureControlSlot slot) {
    if (!slot.isPopulated || slot.recipe == null) {
      throw StateError('Slot C${slot.slotNumber} is empty.');
    }
    return Np3Codec.encodeNp3File(slot.recipe!);
  }
}

/// 优化校准写入结果。
class PictureControlWriteResult {
  /// 0x90CD 已发出后，0x90CC 读回与目标配方语义一致。
  final bool verified;

  /// 请求了写入后激活，且相机确认成功。
  final bool active;

  const PictureControlWriteResult({
    required this.verified,
    this.active = false,
  });
}

/// 相机自定义优化校准槽位 (C1–C9, Profile ID 201–209) 实时状态实体。
class CameraPictureControlSlot {
  final int slotNumber; // 1..9
  final int profileId; // 201..209
  final bool isPopulated;
  final bool isActive;
  final PictureControlRecipe? recipe;
  final Uint8List? rawWireBytes;

  const CameraPictureControlSlot({
    required this.slotNumber,
    required this.profileId,
    required this.isPopulated,
    this.isActive = false,
    this.recipe,
    this.rawWireBytes,
  });

  String get slotCode => 'C$slotNumber';
}
