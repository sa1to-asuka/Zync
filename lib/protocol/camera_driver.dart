import 'dart:typed_data';

/// 相机连接状态枚举
enum CameraConnectionState {
  disconnected,
  connecting,
  connected,
  error,
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
