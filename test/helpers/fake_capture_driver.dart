import 'dart:async';
import 'dart:typed_data';

import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/camera_io_coordinator.dart';
import 'package:zync/protocol/ptp_ip_client.dart';

/// 可脚本化的假驱动，覆盖拍摄台用到的全部新接口。
class FakeCaptureDriver implements CameraDriver {
  FakeCaptureDriver({
    this.supportsLv = true,
    this.supportsCapture = true,
    this.supportsAf = true,
    this.supportsWrite = true,
    this.supportsMf = true,
    this.supportsAutoFocus = true,
    this.verifiedBody = true,
  });

  final bool supportsLv;
  final bool supportsCapture;
  final bool supportsAf;
  final bool supportsWrite;
  final bool supportsMf;
  final bool supportsAutoFocus;
  final bool verifiedBody;

  final List<String> calls = <String>[];
  final CameraIoCoordinator ioCoordinator = CameraIoCoordinator();
  final StreamController<CameraFileItem> _captured =
      StreamController<CameraFileItem>.broadcast();

  // ---- live view ----
  int liveFramesToServe = 1;
  Object? liveFrameError;
  int liveFrameRequests = 0;

  // ---- objects ----
  List<int> handles = <int>[];
  final Map<int, CameraFileItem> files = <int, CameraFileItem>{};
  int nextHandle = 100;

  /// initiateCapture 被调用时是否立即「拍出」一张新照片。
  bool producePhotoOnCapture = true;
  int? captureRejectCode;

  // ---- properties ----
  final Map<int, Uint8List> propDescs = <int, Uint8List>{};
  final Map<int, Uint8List> propValues = <int, Uint8List>{};
  int? writeRejectCode;

  /// 依次抛出的写入异常（可以是 PlatformException），用来模拟 USB 侧的偶发失败。
  final List<Object> writeFailures = <Object>[];

  /// 模拟机身不在 M 档：写入返回成功但相机静默忽略。
  bool ignoreWrites = false;

  int? lastWrittenProperty;
  Uint8List? lastWrittenPayload;

  final List<String> mfCalls = <String>[];
  int afDriveCalls = 0;
  int cancelFocusCalls = 0;
  int? mfRejectCode;
  int? afRejectCode;

  /// deviceReady 依次返回的响应码；用尽后返回 0x2001（空闲）。
  final List<int> deviceReadyCodes = <int>[];

  @override
  CameraIoCoordinator get io => ioCoordinator;

  @override
  CameraConnectionState state = CameraConnectionState.connected;

  @override
  bool get isConnected => state == CameraConnectionState.connected;

  @override
  String get cameraModel => 'NIKON Z 30';

  @override
  int get batteryLevel => 90;

  @override
  bool get isSingleSlotCamera => true;

  @override
  List<int> get availableStorageIds => const <int>[0x00010001];

  @override
  Stream<CameraConnectionState> get connectionStateStream =>
      const Stream<CameraConnectionState>.empty();

  @override
  Stream<CameraFileItem> get onPhotoCaptured => _captured.stream;

  @override
  CameraTransportKind get transportKind => CameraTransportKind.wifi;

  @override
  bool get supportsLiveView => supportsLv;

  @override
  bool get supportsRemoteCapture => supportsCapture;

  @override
  bool get supportsTapToFocus => supportsAf;

  @override
  bool get supportsAfDrive => supportsAutoFocus;

  @override
  bool get supportsManualFocus => supportsMf;

  @override
  bool get supportsExposureWrite => supportsWrite;

  @override
  bool get isVerifiedBody => verifiedBody;

  @override
  Future<void> connect(String host,
      {int port = 15740, void Function(String msg)? onLog}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<int>> listStorageIds() async => const <int>[0x00010001];

  @override
  Future<CameraExposureParams> fetchExposureParams() async =>
      const CameraExposureParams();

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async {
    calls.add('listHandles');
    return List<int>.from(handles);
  }

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async => files[handle];

  @override
  Future<Uint8List> getThumbnail(int handle) async => Uint8List(0);

  @override
  Future<Uint8List> downloadPartialObject(
          int handle, int offset, int maxBytes) async =>
      Uint8List(0);

  @override
  Future<Uint8List> downloadFullObject(int handle, int totalSize,
          {Function(int current, int total)? onProgress}) async =>
      Uint8List(0);

  @override
  Future<bool> deleteObject(int handle) async => true;

  @override
  Future<void> startLiveView() async {
    calls.add('startLiveView');
  }

  @override
  Future<Uint8List> fetchLiveViewFrame() async {
    calls.add('frame');
    liveFrameRequests++;
    final error = liveFrameError;
    if (error != null) throw error;
    if (liveFramesToServe <= 0) {
      throw PtpException(0x9203, 0xA00B);
    }
    liveFramesToServe--;
    return Uint8List(0);
  }

  @override
  Future<void> endLiveView({bool force = false}) async {
    calls.add('endLiveView');
  }

  @override
  Future<void> initiateCapture() async {
    calls.add('capture');
    final code = captureRejectCode;
    if (code != null) {
      throw PtpException(0x100E, code);
    }
    if (producePhotoOnCapture) {
      final handle = nextHandle++;
      final file = CameraFileItem(
        handle: handle,
        storageId: 0x00010001,
        format: 0x3801,
        size: 4096,
        fileName: 'DSC_${handle}.JPG',
        captureDate: '20261107T120000',
      );
      files[handle] = file;
      handles = <int>[...handles, handle];
    }
  }

  @override
  Future<void> moveAfArea(int x, int y) async {
    calls.add('af:$x,$y');
  }

  @override
  Future<void> afDrive() async {
    afDriveCalls++;
    final code = afRejectCode;
    if (code != null) throw PtpException(0x90C1, code);
  }

  @override
  Future<int> deviceReady() async {
    if (deviceReadyCodes.isNotEmpty) return deviceReadyCodes.removeAt(0);
    return 0x2001;
  }

  @override
  Future<void> mfDrive(MfDirection direction, int steps) async {
    mfCalls.add('${direction.opCode}:$steps');
    final code = mfRejectCode;
    if (code != null) throw PtpException(0x9204, code);
  }

  @override
  Future<void> cancelFocusDrive() async {
    cancelFocusCalls++;
  }

  @override
  Future<Uint8List> fetchDevicePropDesc(int propertyId) async {
    calls.add('desc:$propertyId');
    final value = propDescs[propertyId];
    if (value == null) {
      throw PtpException(0x1014, 0x2005);
    }
    return value;
  }

  @override
  Future<Uint8List> fetchDevicePropValue(int propertyId) async {
    calls.add('value:$propertyId');
    return propValues[propertyId] ?? Uint8List(0);
  }

  @override
  Future<void> writeDevicePropValue(int propertyId, Uint8List payload) async {
    calls.add('write:$propertyId');
    if (writeFailures.isNotEmpty) throw writeFailures.removeAt(0);
    final code = writeRejectCode;
    if (code != null) {
      throw PtpException(0x1016, code);
    }
    lastWrittenProperty = propertyId;
    lastWrittenPayload = payload;
    if (!ignoreWrites) {
      // 默认把写入值当作回读值，模拟相机接受设置。
      propValues[propertyId] = payload;
    }
  }

  void emitCaptured(CameraFileItem file) => _captured.add(file);

  void dispose() {
    _captured.close();
  }
}
