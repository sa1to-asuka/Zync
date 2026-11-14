/// PTP 标准操作码与 Nikon 厂商扩展操作码表。
///
/// 标准 PTP 操作码与 Nikon 扩展操作码表。
/// 本文件只保留协议常量。
class PtpOpCodes {
  PtpOpCodes._();

  // ==========================================
  // 1. 标准 PTP / ISO 15740 操作码 (0x1000 - 0x101F)
  // ==========================================
  static const int getDeviceInfo = 0x1001; // 4097
  static const int openSession = 0x1002; // 4098
  static const int closeSession = 0x1003; // 4099
  static const int getStorageIDs = 0x1004; // 4100
  static const int getStorageInfo = 0x1005; // 4101
  static const int getNumObjects = 0x1006; // 4102
  static const int getObjectHandles = 0x1007; // 4103
  static const int getObjectInfo = 0x1008; // 4104
  static const int getObject = 0x1009; // 4105
  static const int getThumb = 0x100A; // 4106
  static const int deleteObject = 0x100B; // 4107
  static const int sendObjectInfo = 0x100C; // 4108
  static const int sendObject = 0x100D; // 4109
  static const int initiateCapture = 0x100E; // 4110
  static const int getDevicePropDesc = 0x1014; // 4116
  static const int getDevicePropValue = 0x1015; // 4117
  static const int setDevicePropValue = 0x1016; // 4118
  static const int resetDevicePropValue = 0x1017; // 4119
  static const int terminateOpenCapture = 0x1018; // 4120
  static const int getPartialObject = 0x101B; // 4123 (用于 4MB 分块流式拉取)

  // ==========================================
  // 2. Nikon 厂商专属私有操作码 (0x9000 - 0x94FF)
  // ==========================================
  static const int nikonGetLargeThumb = 0x90C4; // 37060 获取大尺寸预览缩略图 (640x480)
  static const int nikonDeviceReady = 0x90C8; // 37064 设备就绪探测
  static const int nikonAfDrive = 0x90C1; // 37057 触发自动对焦（无参数）
  static const int nikonStartLiveView = 0x9201; // 37377 进入实时取景
  static const int nikonEndLiveView = 0x9202; // 37378 退出实时取景
  static const int nikonGetLiveViewImage = 0x9203; // 37379 拉取一帧取景画面
  static const int nikonGetPicCtrlData = 0x90CC; // 37068 读取优化校准数据 [profileId, mode]
  static const int nikonSetPicCtrlData = 0x90CD; // 37069 写入自定义优化校准数据 [slotProfileId, 0]
  static const int nikonDeleteCustomPicCtrl = 0x90CE; // 37070 删除自定义优化校准 [slotProfileId]
  static const int nikonGetPicCtrlCapability = 0x90CF; // 37071 查询优化校准能力 [profileId]
  static const int nikonMfDrive = 0x9204; // 37380 手动对焦步进 [方向, 步数]
  static const int nikonChangeAfArea = 0x9205; // 37381 修改对焦区域坐标
  static const int nikonAfDriveCancel = 0x9206; // 37382 取消进行中的自动对焦
  static const int nikonCaptureToCard = 0x9207; // 37383 拍照并存入机身卡
  static const int nikonStartMovieRecInCard = 0x920A; // 37386 启动机内录像
  static const int nikonEndMovieRec = 0x920B; // 37387 结束机内录像
  static const int nikonEndSpotWhiteBalance = 0x9403; // 37891 结束点测白平衡
  static const int nikonGetEventEx = 0x941C; // 37916 扩展事件轮询
  static const int nikonGetObjectSize = 0x9421; // 37921 获取对象实际尺寸
  static const int nikonStartTracking = 0x9424; // 37924 启动对象对焦跟踪
  static const int nikonEndTracking = 0x9425; // 37925 结束对象对焦跟踪
  static const int nikonGetPartialObject64 = 0x9431; // 37937 64位大文件局部读取
  static const int nikonGetObjectMetadata = 0x9434; // 37940 获取镜头与日期私有元数据
  static const int nikonChangeAppMode = 0x9435; // 37941 切换应用控制模式
  static const int nikonGetDevicePropDescEx = 0x943A; // 37946 扩展属性描述查询
  static const int nikonGetDevicePropValueEx = 0x943B; // 37947 扩展属性值查询

  // ==========================================
  // 2b. Nikon 优化校准专属设备属性 (Device Properties)
  // ==========================================
  static const int nikonPropActivePicCtrlItem = 0xD200; // 当前激活的优化校准项 (1..8, 101..120, 201..209)
  static const int nikonPropChangePicCtrlItem = 0xD201; // 优化校准变更通知项
  static const int nikonPropCameraOrientation = 0xD10E; // 机身朝向 (0=水平, 1=顺时针 90°...)

  // ==========================================
  // 2c. 曝光相关设备属性 (拍摄台读写)
  // ==========================================
  static const int devicePropFNumber = 0x5007; // 光圈 (值 / 100)
  static const int devicePropExposureTime = 0x500D; // 标准快门速度 (100 µs)
  static const int devicePropExposureMode = 0x500E; // 曝光模式
  static const int devicePropExposureIndex = 0x500F; // 标准 ISO
  static const int devicePropExposureBias = 0x5010; // 曝光补偿 (1/1000 EV)
  static const int nikonPropShutterSpeed = 0xD100; // Nikon 快门速度 (分子/分母打包)
  static const int nikonPropIso = 0xD0B4; // Nikon ISO

  // ==========================================
  // 2d. 录像与包围曝光设备属性 (v2.6.0)
  // ==========================================
  static const int devicePropLiveViewSelector = 0xD1A6; // 0=拍照 1=录像
  static const int devicePropMovieRecProhibition = 0xD0A4; // 禁录原因位掩码
  static const int devicePropMovieScreenSize = 0xD0A0; // 分辨率与帧率
  static const int devicePropMovieFileType = 0xD0AF; // MOV / MP4
  static const int devicePropMovieShutterSpeed = 0xD1A8; // 视频快门
  static const int devicePropMovieFNumber = 0xD1A9; // 视频光圈
  static const int devicePropMovieIso = 0xD1AA; // 视频 ISO
  static const int devicePropMovieExposureBias = 0xD1AB; // 视频曝光补偿
  static const int devicePropMovieIsoAutoControl = 0xD0AD; // 视频自动 ISO 开关
  static const int devicePropEnableAeBracketing = 0xD0C0; // 机内包围曝光开关
  static const int devicePropAeBracketingStep = 0xD0C1; // 机内包围步长
  static const int devicePropAeBracketingPattern = 0xD0C2; // 机内包围张数/顺序

  // ==========================================
  // 2e. 相机事件码 (EventCode)
  // ==========================================
  static const int eventObjectAdded = 0x4002; // 新对象落盘
  static const int eventNikonMovieRecInterrupted = 0xC105; // 录像异常中断
  static const int eventNikonMovieRecComplete = 0xC108; // 录像封盘完成
  static const int eventNikonMovieRecStarted = 0xC10A; // 录像已开始

  // ==========================================
  // 3. PTP/IP 协议包类型编号 (PacketType)
  // ==========================================
  static const int ptpIpInitCommandRequest = 1;
  static const int ptpIpInitCommandAck = 2;
  static const int ptpIpInitEventRequest = 3;
  static const int ptpIpInitEventAck = 4;
  static const int ptpIpInitFail = 5;
  static const int ptpIpOperationRequest = 6;
  static const int ptpIpOperationResponse = 7;
  static const int ptpIpEvent = 8;
  static const int ptpIpStartDataPacket = 9;
  static const int ptpIpDataPacket = 10;
  static const int ptpIpCancelTransaction = 11;
  static const int ptpIpEndDataPacket = 12;
  static const int ptpIpProbeRequest = 13; // 相机探活要求，必须原样回 0x0E
  static const int ptpIpProbeResponse = 14;

  // ==========================================
  // 4. PTP 响应代码 (Response Codes)
  // ==========================================
  static const int responseOk = 0x2001; // 成功
  static const int responseGeneralError = 0x2002; // 通用错误
  static const int responseSessionNotOpen = 0x2003; // 会话未建立
  static const int responseInvalidTransactionId = 0x2004; // 事务ID无效
  static const int responseOperationNotSupported = 0x2005; // 操作不支持 (用于降级)
  static const int responseParameterNotSupported = 0x2006; // 参数不支持
  static const int responseDeviceBusy = 0x2019; // 相机正忙
  static const int responseSessionAlreadyOpen = 0x201E; // 会话已开启 (可复用)
  static const int responseStoreFull = 0x200C; // 存储卡已满
  static const int responseAccessDenied = 0x200F; // 拒绝访问/写入 (如相机未处于 P/S/A/M 档)
  static const int responseNotLiveView = 0xA00B; // 相机已不在实时取景模式

  // ==========================================
  // 5. Nikon 厂商响应码 (0xA0xx)
  // ==========================================
  static const int responseNikonOutOfFocus = 0xA002; // 自动对焦未合焦
  static const int responseNikonChangeModeFailed = 0xA003; // 切换相机模式失败
  static const int responseNikonModeNotAdjustFNumber = 0xA00A; // 当前模式不允许调整光圈
  static const int responseNikonMfDriveStepEnd = 0xA00C; // 手动对焦已到行程尽头
  static const int responseNikonMfDriveStepInsufficiency = 0xA00E; // 手动对焦步长不足
}
