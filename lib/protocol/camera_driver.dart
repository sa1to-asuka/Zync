import 'dart:typed_data';

import '../core/utils/capture_date.dart';
import 'camera_io_coordinator.dart';

/// 相机连接状态枚举
enum CameraConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// 当前会话使用的传输方式，仅供界面显示与能力提示，不影响协议逻辑。
enum CameraTransportKind { wifi, usb }

/// 手动对焦方向。参数值直接对应 `0x9204` 的第一个参数。
enum MfDirection {
  near(1),
  far(2);

  const MfDirection(this.opCode);
  final int opCode;
}

/// 一次遥控快门的结果。
///
/// 关键在于把「相机接收了快门指令」与「照片确实落到卡上」区分开：
/// 超时不等于失败，快门可能已经释放，界面不能提示用户重拍。
sealed class CaptureOutcome {
  const CaptureOutcome();
}

/// 已经在对象列表里看到新文件。
class CaptureConfirmed extends CaptureOutcome {
  final CameraFileItem file;
  const CaptureConfirmed(this.file);
}

/// 快门指令被接受，但在超时时间内没有观察到新文件。
///
/// 常见于大文件写入、双卡切换或相机正在处理降噪。只能提示用户去相册确认，
/// **不能**自动重试，否则可能连拍两张。
class CaptureUnconfirmed extends CaptureOutcome {
  const CaptureUnconfirmed();
}

/// 相机明确拒绝了快门指令。
class CaptureRejected extends CaptureOutcome {
  final int responseCode;
  const CaptureRejected(this.responseCode);
}

/// 相机文件描述项
class CameraFileItem {
  final int handle;
  final int storageId;
  final int format;
  final int size;
  final String fileName;
  final String captureDate;

  /// 照片像素宽高 (来自 PTP ObjectInfo, 用于判断横拍/竖拍); 0 表示未知
  final int pixelWidth;
  final int pixelHeight;

  CameraFileItem({
    required this.handle,
    required this.storageId,
    required this.format,
    required this.size,
    required this.fileName,
    required this.captureDate,
    this.pixelWidth = 0,
    this.pixelHeight = 0,
  });

  /// 已知且为竖构图 (高 > 宽) 时为 true
  bool get isPortrait =>
      pixelWidth > 0 && pixelHeight > 0 && pixelHeight > pixelWidth;

  bool get isFolder => format == 0x3001;

  bool get isRaw =>
      fileName.toUpperCase().endsWith('.NEF') ||
      fileName.toUpperCase().endsWith('.NRW') ||
      format == 0xB101;

  bool get isVideo =>
      fileName.toUpperCase().endsWith('.MP4') ||
      fileName.toUpperCase().endsWith('.MOV');

  Map<String, dynamic> toJson() => {
        'handle': handle,
        'storageId': storageId,
        'format': format,
        'size': size,
        'fileName': fileName,
        'captureDate': captureDate,
        'pixelWidth': pixelWidth,
        'pixelHeight': pixelHeight,
      };

  factory CameraFileItem.fromJson(Map<String, dynamic> json) => CameraFileItem(
        handle: json['handle'] as int,
        storageId: json['storageId'] as int,
        format: json['format'] as int,
        size: json['size'] as int,
        fileName: json['fileName'] as String,
        captureDate: (json['captureDate'] as String?) ?? '',
        pixelWidth: (json['pixelWidth'] as num?)?.toInt() ?? 0,
        pixelHeight: (json['pixelHeight'] as num?)?.toInt() ?? 0,
      );

  /// 展示用拍摄时间（归一化为 YYYY.MM.DD HH:MM）。
  /// 原始 [captureDate] 保留给导出历史索引，避免既有记录失配。
  String get captureDateDisplay => formatCaptureDate(captureDate);

  String get sizeFormatted {
    if (size >= 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
  }
}

/// 抽象相机硬件驱动标准接口
abstract class CameraDriver {
  CameraConnectionState get state;
  bool get isConnected;
  String get cameraModel;
  int get batteryLevel; // 0 - 100
  bool get isSingleSlotCamera;
  List<int> get availableStorageIds;
  Stream<CameraConnectionState> get connectionStateStream;

  // ------------------------------------
  // 连接控制
  // ------------------------------------
  Future<void> connect(String host,
      {int port = 15740, void Function(String msg)? onLog});
  Future<void> disconnect();
  Future<List<int>> listStorageIds();

  // ------------------------------------
  // 相机状态
  // ------------------------------------
  Future<CameraExposureParams> fetchExposureParams();

  // ------------------------------------
  // 媒体浏览与下载
  // ------------------------------------
  Future<List<int>> listObjectHandles([int? storageId]);
  Future<CameraFileItem?> getObjectInfo(int handle);
  Future<Uint8List> getThumbnail(int handle);
  Future<Uint8List> downloadPartialObject(int handle, int offset, int maxBytes);
  Future<Uint8List> downloadFullObject(int handle, int totalSize,
      {Function(int current, int total)? onProgress});

  /// 删除相机存储卡上的对象 (标准 PTP DeleteObject 0x100B)。
  /// Wi-Fi PTP/IP 与 USB PTP 共用同一实现，成功返回 true。
  Future<bool> deleteObject(int handle);

  // ------------------------------------
  // 新拍照事件流 (边拍边传)
  // ------------------------------------
  Stream<CameraFileItem> get onPhotoCaptured;

  // ------------------------------------
  // 实时取景与遥控拍摄 (拍摄台)
  // ------------------------------------

  /// 相机通道的准入控制，用于在独占操作前排空在途的取景事务。
  CameraIoCoordinator get io;

  CameraTransportKind get transportKind;

  bool get supportsLiveView;
  bool get supportsRemoteCapture;
  bool get supportsTapToFocus;
  bool get supportsExposureWrite;
  bool get supportsAfDrive;
  bool get supportsManualFocus;

  /// 是否为经过真机验证的机型（当前只有 Z 30）。
  bool get isVerifiedBody;

  /// 进入实时取景 (0x9201)。
  Future<void> startLiveView();

  /// 拉取一帧取景负载 (0x9203)。返回值包含厂商头部，需自行提取 JPEG。
  Future<Uint8List> fetchLiveViewFrame();

  /// 退出实时取景 (0x9202)。任何退出路径都应调用。
  /// 退出实时取景。[force] 为 true 时即使本端认为取景未开启也照发 0x9202，
  /// 用于修正「相机还在取景、App 状态已不同步」的情况。
  Future<void> endLiveView({bool force = false});

  /// 释放快门 (0x100E)。被相机拒绝时抛出 [PtpException]，
  /// 便于调用方区分「忙」与「不支持」。
  Future<void> initiateCapture();

  /// 移动对焦点 (0x9205)，坐标为机身对焦区域坐标系。
  Future<void> moveAfArea(int x, int y);

  /// 触发一次真正的自动对焦 (0x90C1)。
  Future<void> afDrive();

  /// 设备就绪探测 (0x90C8)，返回相机响应码：
  /// `0x2001` 空闲、`0xA002` 未合焦、`0x2019` 仍在忙。
  Future<int> deviceReady();

  /// 手动对焦步进 (0x9204)。必须在实时取景中调用。
  Future<void> mfDrive(MfDirection direction, int steps);

  /// 取消进行中的对焦 (0x9206)，失败时静默。
  Future<void> cancelFocusDrive();

  /// 读取设备属性描述 (0x1014)，返回原始数据集。
  Future<Uint8List> fetchDevicePropDesc(int propertyId);

  /// 读取设备属性当前值 (0x1015)。
  Future<Uint8List> fetchDevicePropValue(int propertyId);

  /// 写入设备属性 (0x1016)。是否真正生效必须由调用方回读确认。
  Future<void> writeDevicePropValue(int propertyId, Uint8List payload);
}

/// 相机实时曝光与镜头参数实体。
class CameraExposureParams {
  final String aperture; // e.g. "f/2.8"
  final String shutterSpeed; // e.g. "1/250s"
  final String iso; // e.g. "ISO 400"
  final String exposureComp; // e.g. "±0.0 EV" or "+0.3 EV"
  final String programMode; // e.g. "M", "A", "S", "P", "AUTO"
  final String focalLength; // e.g. "50mm"
  final String lensInfo; // e.g. "24-70mm"
  final int batteryLevel; // e.g. 85

  const CameraExposureParams({
    this.aperture = '--',
    this.shutterSpeed = '--',
    this.iso = '--',
    this.exposureComp = '--',
    this.programMode = '--',
    this.focalLength = '--',
    this.lensInfo = '--',
    this.batteryLevel = 100,
  });
}
