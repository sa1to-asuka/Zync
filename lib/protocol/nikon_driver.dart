import 'dart:async';
import 'dart:typed_data';
import '../core/constants/ptp_opcodes.dart';
import '../core/settings/app_settings.dart';
import '../core/utils/byte_buffer_ext.dart';
import 'camera_driver.dart';
import 'camera_native_bridge.dart';
import 'ptp_ip_client.dart';
import 'ptp_transport.dart';
import 'usb_ptp_transport.dart';
import 'ptp_packet.dart';

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
    if (upper.contains('Z 50') ||
        upper.contains('Z50') ||
        upper.contains('Z_50')) return 'NIKON Z 50';
    if (upper.contains('Z FC') ||
        upper.contains('ZFC') ||
        upper.contains('Z_FC')) return 'NIKON Z fc';
    if (upper.contains('Z 8') || upper.contains('Z8') || upper.contains('Z_8'))
      return 'NIKON Z 8';
    if (upper.contains('Z 9') || upper.contains('Z9') || upper.contains('Z_9'))
      return 'NIKON Z 9';
    if (upper.contains('Z 6_3') ||
        upper.contains('Z6III') ||
        upper.contains('Z 6III')) return 'NIKON Z 6III';
    if (upper.contains('Z 6_2') ||
        upper.contains('Z6II') ||
        upper.contains('Z 6II')) return 'NIKON Z 6II';
    if (upper.contains('Z 6') || upper.contains('Z6') || upper.contains('Z_6'))
      return 'NIKON Z 6';
    if (upper.contains('Z 7_2') ||
        upper.contains('Z7II') ||
        upper.contains('Z 7II')) return 'NIKON Z 7II';
    if (upper.contains('Z 7') || upper.contains('Z7') || upper.contains('Z_7'))
      return 'NIKON Z 7';
    if (upper.contains('D850')) return 'NIKON D850';
    if (upper.contains('D780')) return 'NIKON D780';
    if (upper.contains('D750')) return 'NIKON D750';
    if (upper.contains('D500')) return 'NIKON D500';
    return m.isEmpty ? 'Nikon Camera' : m;
  }
}

/// 尼康专属相机硬件协议驱动。
/// Nikon 扩展操作码与设备属性读取。
class NikonDriver implements CameraDriver {
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

  List<int> _detectedStorageIds = [];
  final Map<int, CameraFileItem> _objectInfoCache = {};
  final Map<int, Uint8List> _thumbCache = {};

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

  @override
  Future<void> connect(String host,
      {int port = 15740, void Function(String msg)? onLog}) {
    return _connectPtp(host, port: port, onLog: onLog);
  }

  Future<void> _connectPtp(
    String host, {
    required int port,
    void Function(String msg)? onLog,
  }) async {
    _logCallback = onLog;
    _state = CameraConnectionState.connecting;
    _stateController.add(_state);
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
        await CameraNativeBridge.bindCameraWifi(targetHost: host);
      } catch (_) {}

      client = PtpIpClient(
        host: host,
        port: port,
        onLog: onLog,
        clientGuid: AppSettings.instance.ptpClientGuidBytes,
      );
      _client = client;
      await client.connect();
      _state = CameraConnectionState.connected;
      _stateController.add(_state);

      // 监听相机推送事件 (ObjectAdded 0x4002) 用于边拍边传
      client.events.listen(_handleCameraEvent);

      // 查询设备信息以获取具体型号与支持能力集
      try {
        await _queryDeviceInfo();
      } catch (e) {
        onLog?.call('查询相机设备信息提示: $e');
      }

      // 查询电池电量 (0x5001 BatteryLevel)
      try {
        await _queryBatteryLevel();
      } catch (_) {}
    } catch (e) {
      try {
        await client?.disconnect();
      } catch (_) {}
      _state = CameraConnectionState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  /// 通过 USB (PTP over OTG) 连接相机。首期支持连接、浏览存储卡与分块下载。
  Future<void> connectUsb(String deviceName,
      {void Function(String msg)? onLog}) async {
    final transport = UsbPtpTransport(deviceName: deviceName, onLog: onLog);
    try {
      await connectTransport(transport, onLog: onLog);
    } catch (e) {
      await transport.disconnect();
      transport.dispose();
      rethrow;
    }
  }

  /// 使用给定传输层（如 USB）建立连接，复用与 Wi-Fi 完全相同的上层逻辑。
  Future<void> connectTransport(PtpTransport transport,
      {void Function(String msg)? onLog}) async {
    _logCallback = onLog;
    _state = CameraConnectionState.connecting;
    _stateController.add(_state);
    try {
      _client = transport;
      await _client!.connect();
      _state = CameraConnectionState.connected;
      _stateController.add(_state);
      _client!.events.listen(_handleCameraEvent);

      try {
        await _queryDeviceInfo();
      } catch (e) {
        onLog?.call('查询相机设备信息提示: $e');
      }
      try {
        await _queryBatteryLevel();
      } catch (_) {}
    } catch (e) {
      _state = CameraConnectionState.error;
      _stateController.add(_state);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    await _client?.disconnect();
    _client = null;
    _state = CameraConnectionState.disconnected;
    // dispose 场景下控制器可能已关闭，避免向已关闭的 StreamController 发送事件
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
    _objectInfoCache.clear();
    _thumbCache.clear();
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
        return _detectedStorageIds;
      }
    } catch (_) {}
    if (_detectedStorageIds.isEmpty) {
      _detectedStorageIds = [0x00010001];
    }
    return _detectedStorageIds;
  }

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async {
    if (!isConnected) return [];

    // 获取所有可用卡槽
    List<int> storages = [];
    if (storageId != null) {
      storages = [storageId];
    } else {
      storages = await listStorageIds();
    }

    if (storages.isEmpty) {
      // 探测默认卡槽与通配卡槽 (Slot 1, Slot 2, 全卡槽)
      storages = [0x00010001, 0x00020001, 0xFFFFFFFF];
    }

    final allFileHandles = <int>{};

    for (final sId in storages) {
      try {
        final found = await _scanStorageFiles(sId);
        if (found.isNotEmpty) {
          allFileHandles.addAll(found);
          _logCallback?.call(
              '卡槽 0x${sId.toRadixString(16)} 成功检索到 ${found.length} 个媒体文件');
        }
      } catch (_) {}
    }

    // 若按卡槽未找到且未指定卡槽，尝试全卡槽通配扫描
    if (allFileHandles.isEmpty && storageId == null) {
      try {
        final found = await _scanStorageFiles(0xFFFFFFFF);
        allFileHandles.addAll(found);
      } catch (_) {}
    }

    return allFileHandles.toList();
  }

  /// 扫描指定存储卷下的所有文件 (支持扁平递归与 DCIM/延时摄影目录树递归双引擎)
  Future<List<int>> _scanStorageFiles(int storageId) async {
    final allHandles = <int>[];

    // 引擎 1: 标准 PTP 全局通配句柄查询 (Parent = 0xFFFFFFFF 查询存储卡内所有文件及目录)
    try {
      final handleData = await _client!.executeDataIn(
        PtpOpCodes.getObjectHandles,
        [storageId, 0, 0xFFFFFFFF],
      );
      final handles = _parseUint32Array(handleData);
      if (handles.length > 2) {
        // 0xFFFFFFFF 在 PTP 协议中代表存储卡内全部对象（包含星空延时新文件夹中的照片）
        allHandles.addAll(handles);
        _logCallback?.call('PTP 0xFFFFFFFF 全局扁平化检索到 ${handles.length} 个对象句柄');
        return allHandles;
      }
    } catch (e) {
      _logCallback?.call('0xFFFFFFFF 全局查询异常，进入目录树扫描: $e');
    }

    // 引擎 2: 标准 PTP 目录树遍历（覆盖根目录、DCIM 及子文件夹）
    try {
      // 1. 获取根目录对象 (Parent = 0)
      final rootData = await _client!.executeDataIn(
        PtpOpCodes.getObjectHandles,
        [storageId, 0, 0],
      );
      final rootHandles = _parseUint32Array(rootData);
      final folderQueue = <int>[];

      for (final h in rootHandles) {
        final info = await getObjectInfo(h);
        if (info == null) continue;
        if (info.isFolder || info.fileName.toUpperCase() == 'DCIM') {
          folderQueue.add(h);
        } else {
          allHandles.add(h);
        }
      }

      // 2. 遍历扫描所有相册目录（重点包含星空延时 101NCZ_3, 102NCZ_3 等子文件夹）
      while (folderQueue.isNotEmpty) {
        final currentFolder = folderQueue.removeAt(0);
        try {
          final childData = await _client!.executeDataIn(
            PtpOpCodes.getObjectHandles,
            [storageId, 0, currentFolder],
          );
          final childHandles = _parseUint32Array(childData);

          for (final ch in childHandles) {
            final cInfo = await getObjectInfo(ch);
            if (cInfo == null) continue;
            if (cInfo.isFolder) {
              // 发现子文件夹（例如 DCIM 下的 100NCZ_3, 101NCZ_3 延时拍摄文件夹）
              folderQueue.add(ch);
            } else {
              allHandles.add(ch);
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return allHandles;
  }

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async {
    if (!isConnected) return null;
    if (_objectInfoCache.containsKey(handle)) {
      return _objectInfoCache[handle];
    }

    try {
      // 0x1008: GetObjectInfo
      final data =
          await _client!.executeDataIn(PtpOpCodes.getObjectInfo, [handle]);
      if (data.length < 52) return null;

      final bd = ByteData.sublistView(data);
      final storageId = bd.getUint32(0, Endian.little);
      final format = bd.getUint16(4, Endian.little);
      final size = bd.getUint32(8, Endian.little);
      // 标准 PTP ObjectInfo 布局: 偏移 26/30 为 ImagePixWidth / ImagePixHeight
      // (偏移 52 的文件名解析与规范 SequenceNumber 布局一致, 可交叉验证)
      // 用于在不下载原图的情况下判断照片是横拍还是竖拍
      final pixWidth = bd.getUint32(26, Endian.little);
      final pixHeight = bd.getUint32(30, Endian.little);

      // 解析偏移 52 处的文件名
      final reader = PtpByteReader(data.sublist(52));
      final fileName = reader.readPtpString();
      final captureDate = reader.readPtpString();

      final item = CameraFileItem(
        handle: handle,
        storageId: storageId,
        format: format,
        size: size,
        fileName: fileName.isEmpty ? 'DSC_$handle.JPG' : fileName,
        captureDate: captureDate,
        pixelWidth: pixWidth,
        pixelHeight: pixHeight,
      );
      _objectInfoCache[handle] = item;
      return item;
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

    // 1. 优先尝试标准 0x100A GetThumb（最多重试 2 次以应对无线偶发丢包或相机忙）
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final raw = await _client!.executeDataIn(PtpOpCodes.getThumb, [handle]);
        final valid = extractValidJpegSlice(raw);
        if (valid != null && valid.isNotEmpty) {
          _thumbCache[handle] = valid;
          return valid;
        }
      } catch (_) {}
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
    }

    // 2. 回退尝试 Nikon 扩展 0x90C4 GetLargeThumb (640x480 预览图)
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
    } catch (_) {}

    // 3. 终极兜底：读取文件头部 256KB 提取内嵌完整 JPEG 缩略图 (兼容特殊 NEF/JPG)
    try {
      final headerBytes = await downloadPartialObject(handle, 0, 256 * 1024);
      final valid = extractValidJpegSlice(headerBytes);
      if (valid != null && valid.isNotEmpty) {
        _thumbCache[handle] = valid;
        return valid;
      }
    } catch (_) {}

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
      if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
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

  @override
  Future<Uint8List> downloadPartialObject(
      int handle, int offset, int maxBytes) async {
    if (!isConnected) return Uint8List(0);
    // 0x101B: GetPartialObject (Handle, Offset, MaxBytes)
    return await _client!
        .executeDataIn(PtpOpCodes.getPartialObject, [handle, offset, maxBytes]);
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

      // GetPartialObject 遇到超时/设备忙时重试。
      while (retries < 3) {
        try {
          chunk =
              await downloadPartialObject(handle, currentOffset, requestBytes);
          if (chunk.isNotEmpty) break;
        } catch (_) {}
        retries++;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (chunk.isEmpty) {
        throw StateError('GetPartialObject 在偏移 $currentOffset 处连续返回空数据块');
      }

      builder.add(chunk);
      currentOffset += chunk.length;
      onProgress?.call(currentOffset, totalSize);
    }

    final bytes = builder.toBytes();
    if (bytes.length != totalSize) {
      throw StateError('对象 $handle 下载不完整：${bytes.length} / $totalSize 字节');
    }
    return bytes;
  }

  // ==========================================
  // 事件处理与私有辅助函数
  // ==========================================

  void _handleCameraEvent(PtpPacket eventPacket) async {
    // PTP/IP Event 负载：eventCode(2) + transactionId(4) + param1(4)...
    if (eventPacket.payload.length >= 10) {
      final eventCode = eventPacket.getUint16(0);
      if (eventCode == 0x4002) {
        final newHandle = eventPacket.getUint32(6);
        final fileInfo = await getObjectInfo(newHandle);
        if (fileInfo != null) {
          _photoCapturedController.add(fileInfo);
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
      _logCallback?.call(
          '【相机识别成功】型号: $_cameraModel, 固件: ${_deviceInfo.deviceVersion}, 序列号: ${_deviceInfo.serialNumber}');
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
  }
}
