// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Zync - 尼康 Z 系列传输与暗房工坊';

  @override
  String get navConnect => '连接';

  @override
  String get navGallery => '相机相册';

  @override
  String get navWatermark => '水印工坊';

  @override
  String get navSettings => '设置';

  @override
  String get exitConfirmHint => '再按一次返回退出 Zync';

  @override
  String get sidebarCollapse => '收起侧栏';

  @override
  String get sidebarExpand => '展开侧栏';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSave => '保存';

  @override
  String get commonDone => '完成';

  @override
  String get commonReset => '重置';

  @override
  String get commonDelete => '删除';

  @override
  String get commonApply => '应用';

  @override
  String get commonRetry => '重试';

  @override
  String get commonRemove => '移除';

  @override
  String get commonClear => '清空';

  @override
  String get commonMore => '更多';

  @override
  String get commonClose => '关闭';

  @override
  String get commonExit => '退出';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonExport => '导出';

  @override
  String get commonImport => '导入';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonRedo => '重做';

  @override
  String get commonOriginal => '原图';

  @override
  String get commonCompare => '对比';

  @override
  String get commonCustom => '自定义';

  @override
  String get commonDefault => '默认';

  @override
  String get commonNone => '无';

  @override
  String get commonAll => '全部';

  @override
  String get commonView => '查看';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonUnknownError => '未知错误';

  @override
  String get commonUnknownSize => '大小未知';

  @override
  String get commonSupported => '支持';

  @override
  String get commonUnsupported => '不支持';

  @override
  String get commonOn => '开';

  @override
  String get commonOff => '关';

  @override
  String get commonDisabled => '已关闭';

  @override
  String get commonSuccess => '成功';

  @override
  String get commonFailed => '失败';

  @override
  String get commonWarning => '异常';

  @override
  String get langSystem => '跟随系统';

  @override
  String get langSystemDesc => '自动跟随设备语言（不支持时回退英文）';

  @override
  String get langEn => 'English';

  @override
  String get langEnSub => '英文界面';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhSub => '简体中文界面';

  @override
  String get langJa => '日本語';

  @override
  String get langJaSub => '日文界面';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystemSub => '随手机系统自动切换';

  @override
  String get themeLightSub => '柔和浅灰暗房纸面与低饱和青绿点缀';

  @override
  String get themeDarkSub => '中性石墨灰专业暗房界面，适合专注审片与调色';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingBack => '上一步';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String onboardingStepOf(int current, int total) {
    return '第 $current / $total 步';
  }

  @override
  String get onboardingLangTitle => '选择应用语言';

  @override
  String get onboardingLangSubtitle => '点击即可实时切换界面语言，后续可随时在「设置」中修改。';

  @override
  String get onboardingThemeTitle => '选择暗房外观';

  @override
  String get onboardingThemeSubtitle => '采用中性石墨灰底与低饱和品牌青绿，避免界面色偏干扰照片审片。';

  @override
  String get onboardingThemePreviewTitle => '实时外观预览';

  @override
  String get onboardingThemePreviewSub =>
      'NIKON Z 8 · NIKKOR Z 50mm f/1.2 S · 1/500s f/1.8 ISO 100';

  @override
  String get onboardingConnTitle => '直连尼康相机工作流';

  @override
  String get onboardingConnSubtitle =>
      '无需云端账号与专有 SDK，直连浏览 RAW 与 JPEG，一站式完成传输、调色与水印导出。';

  @override
  String get onboardingConnWifiTitle => 'Wi-Fi PTP/IP 无线直连';

  @override
  String get onboardingConnWifiDesc => '加入相机发出的 Wi-Fi 热点，即可无线浏览相册、分块高速下载与边拍边传。';

  @override
  String get onboardingConnUsbTitle => 'USB OTG 有线高速连接';

  @override
  String get onboardingConnUsbDesc =>
      '使用 Type-C OTG 数据线（相机设为 MTP/PTP），稳定高速传输大体量 NEF RAW 与视频。';

  @override
  String get onboardingConnStudioTitle => '16-Bit RAW 调色、视频与水印工坊';

  @override
  String get onboardingConnStudioDesc =>
      '内置 LibRaw 16-bit 解码、视频 3D LUT 调色与 10 款 EXIF 画廊级水印边框。';

  @override
  String get connectDetecting => '<检测中...>';

  @override
  String get connectModeWifi => '相机热点';

  @override
  String get connectModeUsb => 'USB 有线';

  @override
  String get connectModeBle => '蓝牙实验';

  @override
  String get connectWifiWarnTitle => '当前 Wi-Fi 可能不是相机热点';

  @override
  String connectWifiWarnBody(String ssid) {
    return '当前网络：$ssid\n仍要尝试按 PTP/IP 连接吗？';
  }

  @override
  String get connectContinueAttempt => '继续尝试';

  @override
  String connectFailedToast(String error) {
    return '连接失败: $error';
  }

  @override
  String connectWifiFailedToast(String error) {
    return '连接失败: $error\n提示：请先在手机系统 Wi-Fi 中加入相机热点';
  }

  @override
  String get connectDisconnectedToast => '已断开与相机的连接并释放网络绑定';

  @override
  String connectUsbScanResult(int total, int ready) {
    return '检测到 $total 个 USB 相机，$ready 个可直接建立 PTP 会话';
  }

  @override
  String connectUsbScanFailed(String error) {
    return 'USB 设备扫描失败: $error';
  }

  @override
  String connectUsbModeSwitchHint(String name, String mode) {
    return '$name 当前为 $mode。请先在相机菜单中把 USB 连接方式切换为 MTP/PTP 后重新刷新。';
  }

  @override
  String get connectUsbUnsupportedDriver => '当前驱动不支持 USB 连接';

  @override
  String get connectUsbPermissionDenied => 'USB 授权被拒绝';

  @override
  String get connectUsbFailedTitle => 'USB 连接失败';

  @override
  String connectUsbFailedToast(String error) {
    return 'USB 连接失败: $error';
  }

  @override
  String get connectUsbTroubleHeader => '排查建议：';

  @override
  String get connectUsbTroubleStep1 => '1. 相机菜单里把 USB 模式设为 MTP/PTP（不是大容量存储）；';

  @override
  String get connectUsbTroubleStep2 =>
      '2. 换一根支持数据传输的 OTG 线，直连手机（不要经过 USB Hub）；';

  @override
  String get connectUsbTroubleStep3 => '3. 拔插一次数据线后重新刷新 USB 设备再连接。';

  @override
  String get connectBleStoppedToast => '已停止蓝牙扫描';

  @override
  String get connectBleStartFailedToast => '启动蓝牙扫描失败，请检查蓝牙开关与定位/近距离设备权限';

  @override
  String get connectBlePairSuccessToast => '蓝牙配对握手发起成功！';

  @override
  String connectBleFailedToast(String error) {
    return '蓝牙连接失败: $error';
  }

  @override
  String get connectMyCamera => '我的相机';

  @override
  String get connectDisconnectShort => '断开';

  @override
  String get connectHeroTitle => 'Zync · 尼康 Z 系列';

  @override
  String get connectHeroSubtitle => '尼康 Z 系列专业无线传输与水印套件';

  @override
  String connectStatusConnectedBanner(String mode, String endpoint) {
    return '已连接  $mode · $endpoint';
  }

  @override
  String get connectCameraBrand => '品牌';

  @override
  String get connectCameraModel => '型号';

  @override
  String get connectBrowsePhotos => '浏览相机照片';

  @override
  String get connectLensSectionTitle => '已连接镜头';

  @override
  String get connectLensIdentified => '已识别';

  @override
  String get connectLensUnread => '未读取';

  @override
  String get connectLensFocalRange => '焦距范围';

  @override
  String get connectLensCurrentFocal => '当前焦距';

  @override
  String get connectLensCurrentAperture => '当前光圈';

  @override
  String get connectDisconnectFull => '断开与相机的连接并释放网络';

  @override
  String get connectCurrentWifiLabel => '当前连接 Wi-Fi';

  @override
  String get connectRedetectWifiTooltip => '重新探测 Wi-Fi';

  @override
  String get connectWifiReadyHint => '已加入相机网络，点击下方按钮即可建立连接';

  @override
  String get connectWifiJoinHint => '请在手机系统 Wi-Fi 中加入相机释放的热点（例如 NIKON_...）';

  @override
  String get connectOpenSystemWifi => '打开手机系统 Wi-Fi 设置';

  @override
  String get connectConnectingButton => '连接中...';

  @override
  String get connectWifiButton => '连接相机 (Wi-Fi 直连)';

  @override
  String get connectBlePhoneOn => '手机蓝牙已开启';

  @override
  String get connectBlePhoneOff => '手机蓝牙已关闭';

  @override
  String get connectStateConnected => '已连接';

  @override
  String get connectStatePairing => '配对中';

  @override
  String get connectStateDisconnected => '未连接';

  @override
  String connectBlePairedDevice(String name) {
    return '当前配对: $name';
  }

  @override
  String get connectBleRemoteTitle => '无线遥控快门 (ML-L7)';

  @override
  String get connectBleHalfPress => '半按对焦';

  @override
  String get connectBleFullPress => '全按拍照';

  @override
  String get connectBleStopScan => '停止扫描';

  @override
  String get connectBleStartScan => '扫描附近蓝牙设备 (BLE)';

  @override
  String connectBleDiscoveredCount(int count) {
    return '已发现的相机设备 ($count)';
  }

  @override
  String connectBleDeviceMeta(String address, int rssi) {
    return 'MAC: $address | 信号: $rssi dBm';
  }

  @override
  String get connectBleSearching => '正在搜索附近的相机与蓝牙设备...';

  @override
  String get connectUsbSectionTitle => 'USB OTG 有线连接';

  @override
  String get connectUsbPrepTitle => '连接准备';

  @override
  String get connectUsbPrepSub => '使用 Type-C OTG 数据线直连相机与手机';

  @override
  String get connectUsbMenuTitle => '相机菜单设置';

  @override
  String get connectUsbMenuSub => '相机菜单 -> USB 模式 -> 设为 MTP/PTP';

  @override
  String get connectUsbHostStatus => 'USB 主机状态';

  @override
  String get connectUsbHostConnected => '有线已连通';

  @override
  String get connectUsbHostWaiting => '等待设备接入';

  @override
  String get connectUsbChecking => '正在检查 USB...';

  @override
  String get connectUsbRefresh => '刷新 USB 设备';

  @override
  String get connectUsbEmptyHint =>
      '未检测到 USB 相机。请确认 OTG 线已连接、相机已开机，并在相机菜单中启用 PTP 连接方式。';

  @override
  String get connectUsbPermissionGrantedSuffix => ' · 已授权';

  @override
  String get connectUsbPermissionNeededSuffix => ' · 需授权';

  @override
  String get statusCameraDisconnected => '相机未连接';

  @override
  String get statusSdCard => 'SD卡';

  @override
  String get statusTapToConnect => '点击连接';

  @override
  String get galleryTabCamera => '相机照片';

  @override
  String galleryTabExportedCount(int count) {
    return '历史导出 ($count)';
  }

  @override
  String get galleryTabExportedPhone => '历史导出 (手机相册)';

  @override
  String get galleryFilterAll => '全部';

  @override
  String get galleryFilterUnsynced => '未同步';

  @override
  String get galleryFilterSynced => '已同步';

  @override
  String get gallerySlotSelectTitle => '选择卡槽';

  @override
  String get gallerySlotAllMerged => '全部存储 (自动合并)';

  @override
  String get gallerySlot1 => '卡槽 1 (Slot 1)';

  @override
  String get gallerySlot2 => '卡槽 2 (Slot 2)';

  @override
  String get galleryCollageButton => '拼图';

  @override
  String get galleryTransferCenterTooltip => '传输中心';

  @override
  String get galleryRefreshCardTooltip => '刷新存储卡';

  @override
  String get galleryRefreshExportedTooltip => '刷新已导出相册';

  @override
  String get galleryShootAndTransferBanner => '边拍边传已开启：快门触发后静默同步原图';

  @override
  String get galleryEnumeratingStorage => '正在枚举相机存储卡文件列表 (0x1007)...';

  @override
  String get galleryEmptyCameraPhotos => '相机中未检测到照片或正在读取...';

  @override
  String galleryEmptyFilterPhotos(String filter) {
    return '当前筛选「$filter」下无照片';
  }

  @override
  String get galleryReadyFooterHint => '已就绪：可在底部导航「设置」中配置通信与缓存参数';

  @override
  String get galleryLocalMissingFallbackToast => '本地照片已删除或无法读取，将尝试从相机加载';

  @override
  String get galleryLoadingHighResTitle => '加载高清照片中';

  @override
  String galleryLoadingHighResBody(String size) {
    return '正在从相机传输原图（$size）以保证预览与水印画质...';
  }

  @override
  String galleryLoadFailedToast(String error) {
    return '加载相机照片失败: $error';
  }

  @override
  String galleryEnqueuedToast(int count) {
    return '已加入传输队列：$count 个文件';
  }

  @override
  String get galleryCollageNeed2To9 => '请先勾选 2–9 张照片再拼图';

  @override
  String get galleryCollageMax9 => '拼图最多支持 9 张照片';

  @override
  String get galleryCollageNeedJpeg => '拼图需要至少 2 张 JPEG 照片，RAW / 视频暂不支持';

  @override
  String get galleryCollageInsufficientCancelled => '可用素材不足 2 张，拼图已取消';

  @override
  String get galleryCollageEnterTitle => '进入拼图';

  @override
  String galleryCollageDownloadPrompt(
      int missing, String reusablePart, String skippedPart) {
    return '拼图功能需要先把素材下载到本地：待下载 $missing 张$reusablePart$skippedPart。下载完成后将自动进入拼图界面。';
  }

  @override
  String galleryCollageReusablePart(int count) {
    return '，已有 $count 张本地素材可直接复用';
  }

  @override
  String galleryCollageSkippedPart(int count) {
    return '，已跳过 $count 张 RAW / 视频';
  }

  @override
  String get galleryConfirmDownload => '确认下载';

  @override
  String get galleryExportFormatTitle => '选择导出格式';

  @override
  String galleryExportFormatPrompt(int count) {
    return '选中的 $count 张照片中包含 RAW + JPEG 双格式照片，请选择导出方式：';
  }

  @override
  String get galleryExportBothTitle => '导出全部 (RAW + JPEG)';

  @override
  String get galleryExportBothSub => '保留最高画质 RAW 底片及直出 JPEG 成片';

  @override
  String get galleryExportJpegOnlyTitle => '仅需 JPEG (推荐快速分享)';

  @override
  String get galleryExportJpegOnlySub => '仅传输直出成片，传输速度更快、省手机空间';

  @override
  String galleryExportBatchSuccessToast(int count) {
    return '已成功导出 $count 张照片至手机相册 (/DCIM/Zync)';
  }

  @override
  String get galleryExportingModalTitle => '正在导出照片到手机';

  @override
  String get galleryExportingSocketNotice => '通信通道独占中，已自动阻止其他操作以防止 Socket 冲突。';

  @override
  String galleryExportingSingleSize(String size) {
    return '单文件大小: $size';
  }

  @override
  String galleryExportingBatchProgress(int current, int total) {
    return '批次进度: 第 $current / $total 张';
  }

  @override
  String get galleryExportingSavePath => '保存路径: /DCIM/Zync (相册可见)';

  @override
  String get galleryCancelRemainingTasks => '取消剩余任务';

  @override
  String get galleryDeleteLocalOnlyTitle => '仅删除本地';

  @override
  String get galleryDeleteLocalOnlySub => '只删除手机中已下载的文件，相机会保留';

  @override
  String get galleryDeleteBothTitle => '本地 + 相机一起删除';

  @override
  String get galleryDeleteBothSub => '先删除相机文件，再删除本地副本';

  @override
  String galleryDeleteGroupsTitle(int count) {
    return '删除 $count 组媒体';
  }

  @override
  String get galleryDeleteGroupsPrompt => '请选择删除范围，RAW+JPG 将按整组处理。';

  @override
  String get galleryConfirmDeleteTitle => '确认删除';

  @override
  String galleryConfirmDeleteBothBody(int count) {
    return '将删除 $count 组媒体：相机存储卡 + 本地相册。';
  }

  @override
  String galleryConfirmDeleteLocalBody(int count) {
    return '将删除 $count 组媒体：仅本地相册，相机存储卡保留。';
  }

  @override
  String get galleryIrreversibleHint => '此操作不可恢复。';

  @override
  String get galleryDontAskAgain => '不再提示';

  @override
  String galleryDeletedGroupsToast(int count) {
    return '已处理 $count 组媒体';
  }

  @override
  String galleryDeletedGroupsPartialLocalFailToast(
      int handled, int failed, int localFailed) {
    return '已处理 $handled 组，$failed 组失败（其中 $localFailed 组相机已删除、本地删除失败）';
  }

  @override
  String galleryDeletedGroupsFailToast(int handled, int failed) {
    return '已处理 $handled 组，失败 $failed 组；失败项仍保持选中';
  }

  @override
  String gallerySelectionCameraSummary(int count, String size) {
    return '已选择 $count 组媒体 · 大小 $size';
  }

  @override
  String get galleryLongPressSelectHint => '请先长按照片进入多选，再勾选需要同步的照片';

  @override
  String get gallerySyncToPhoneButton => '同步到手机';

  @override
  String gallerySelectionLocalSummary(int count, String size) {
    return '已选择 $count 张 · $size';
  }

  @override
  String galleryDeletedLocalToast(int count) {
    return '已删除 $count 张本地照片';
  }

  @override
  String galleryDeletedLocalPartialToast(int ok, int failed) {
    return '已删除 $ok 张，$failed 张失败；失败项仍保持选中';
  }

  @override
  String get galleryScanningExported => '正在扫描本地已导出照片...';

  @override
  String get galleryEmptyExportedTitle => '本地暂无已导出的照片';

  @override
  String get galleryEmptyExportedSubtitle =>
      '当您连接相机并导出照片，或在水印工坊制作并保存图片后，\n无需连接相机，均可在此随时查看、加水印与分享！';

  @override
  String get galleryRefreshPhoneAlbum => '刷新手机相册目录';

  @override
  String galleryExportedHeaderCount(int count) {
    return '手机 Zync 相册 · 共 $count 张已导出';
  }

  @override
  String get galleryBadgeExported => '已导出';

  @override
  String get galleryBadgePartial => '部分同步';

  @override
  String get galleryBadgeOverwrite => '覆盖';

  @override
  String get galleryBadgeSaveAs => '另存';

  @override
  String get galleryRawDecodeFailedToast => 'RAW 解码失败，请确认文件是 NEF/NRW';

  @override
  String get galleryStreamingVideoToast => '正在流式下载视频到本地编辑缓存…';

  @override
  String get galleryVideoDownloadFailedToast => '视频下载失败，请检查 USB 连接后重试';

  @override
  String get galleryPhotoInfoTitle => '照片详情';

  @override
  String get galleryPreviewLoadingOriginal => '低清预览·原图加载中…';

  @override
  String get galleryLoadingOriginalShort => '原图加载中…';

  @override
  String get galleryCaptureParamsTitle => '拍摄参数';

  @override
  String get galleryExifShutter => '快门';

  @override
  String get galleryExifAperture => '光圈';

  @override
  String get galleryExifFocal => '焦距';

  @override
  String get galleryExifCamera => '相机';

  @override
  String get galleryExifLens => '镜头';

  @override
  String get galleryActionWatermarkGrade => '加水印 / 调色';

  @override
  String get galleryActionProRawGrade => 'RAW 调色';

  @override
  String get galleryNoPhotos => '暂无照片';

  @override
  String get galleryActionGradeShort => '调色';

  @override
  String get galleryDeleteSingleTitle => '删除这张照片？';

  @override
  String galleryDeleteSingleBody(String name) {
    return '将从手机相册删除 $name，相机存储卡不受影响。此操作不可恢复。';
  }

  @override
  String get galleryDeleteFailedToast => '删除失败，请稍后重试';

  @override
  String galleryOpenEditorFailedToast(String error) {
    return '打开编辑器失败: $error';
  }

  @override
  String get galleryRawNoEmbeddedPreviewToast => '这张 RAW 没有可用的内嵌预览，无法进入调色';

  @override
  String galleryLocalUnreadableToast(String error) {
    return '本地照片无法读取: $error';
  }

  @override
  String get transferCenterTitle => '传输中心';

  @override
  String get transferEmptyTitle => '暂无传输任务';

  @override
  String get transferEmptySubtitle => '相机相册里长按多选后「同步到手机」，或开启边拍边传';

  @override
  String transferActiveCount(int count) {
    return '下载中 $count';
  }

  @override
  String transferQueuedCount(int count) {
    return '排队 $count';
  }

  @override
  String transferFailedCount(int count) {
    return '失败 $count';
  }

  @override
  String get transferPausedTag => '已暂停';

  @override
  String get transferResumeAll => '继续全部';

  @override
  String get transferPauseAll => '暂停全部';

  @override
  String get transferRetryFailed => '重试失败';

  @override
  String get transferClearCompleted => '清空已完成';

  @override
  String get transferStatusQueued => '排队中';

  @override
  String transferStatusDownloadingPct(int percent) {
    return '下载中 $percent%';
  }

  @override
  String get transferStatusCompleted => '已完成';

  @override
  String transferStatusFailedReason(String reason) {
    return '失败：$reason';
  }

  @override
  String get transferStatusCancelled => '已取消';

  @override
  String get editorTitle => '图像编辑';

  @override
  String editorSaveFailedToast(String error) {
    return '保存失败: $error';
  }

  @override
  String get editorSaveSheetTitle => '保存编辑结果';

  @override
  String get editorSaveSheetSub => '覆盖会替换原图；另存会生成一份新图片。';

  @override
  String get editorOverwriteTitle => '覆盖原图';

  @override
  String get editorOverwriteSub => '替换原有图片（失败时自动另存）';

  @override
  String get editorSaveAsNewTitle => '另存为新文件';

  @override
  String get editorSaveAsNewSub => '保留原图，生成 _edit 新文件';

  @override
  String get editorOverwriteAndSaveBothFailed => '覆盖失败，且另存也失败';

  @override
  String get editorSaveAsFailed => '另存失败';

  @override
  String get editorOverwriteFallbackToast => '覆盖未成功，原图已保留，编辑结果已另存';

  @override
  String get editorOverwrittenToast => '已覆盖原图';

  @override
  String get editorSavedAsNewToast => '已另存为新文件';

  @override
  String get editorPreparingPreview => '正在准备编辑预览…';

  @override
  String get editorNoPhotoSelected => '未选择照片';

  @override
  String get editorComparingHoldHint => '原图对比中 · 松开恢复';

  @override
  String get editorRotateLeft90 => '左转 90°';

  @override
  String get editorRotateRight90 => '右转 90°';

  @override
  String get editorResetAngle => '角度归零';

  @override
  String get editorFlipHorizontal => '水平翻转';

  @override
  String get editorFlipVertical => '垂直翻转';

  @override
  String get editorResetDistortion => '重置扭曲';

  @override
  String get editorToolRotate => '旋转';

  @override
  String get editorToolFlip => '翻转';

  @override
  String get editorToolPerspective => '透视';

  @override
  String get editorToolDistortion => '扭曲';

  @override
  String get editorToolFreeTransform => '自由变换';

  @override
  String get editorToolCrop => '裁切';

  @override
  String editorPerspectiveHorizontal(int value) {
    return '水平校正 $value';
  }

  @override
  String editorPerspectiveVertical(int value) {
    return '垂直校正 $value';
  }

  @override
  String get editorTransformScale => '缩放';

  @override
  String get editorTransformPanX => '水平平移';

  @override
  String get editorTransformPanY => '垂直平移';

  @override
  String get editorCropAspectRatio => '裁切比例';

  @override
  String get histogramTitle => '直方图';

  @override
  String get toneBlacks => '黑色色阶';

  @override
  String get toneShadows => '阴影';

  @override
  String get toneExposure => '曝光度';

  @override
  String get toneHighlights => '高光';

  @override
  String get toneWhites => '白色色阶';

  @override
  String get presetTitle => '调色预设';

  @override
  String get presetTabBuiltin => '内置';

  @override
  String get presetTabMine => '我的';

  @override
  String get presetScopeGlobal => '当前编辑：整体调色';

  @override
  String get presetScopeClip => '当前编辑：当前片段调色';

  @override
  String get presetSaveNew => '保存为新预设';

  @override
  String get presetSaveDialogTitle => '保存预设';

  @override
  String get presetSearchHint => '搜索预设';

  @override
  String get presetSavedToast => '预设已保存';

  @override
  String presetImportedToast(int count) {
    return '已导入 $count 个预设';
  }

  @override
  String get presetImportFailedToast => '预设文件读取失败';

  @override
  String get presetExportFailedToast => '导出失败';

  @override
  String get presetExportedToast => '预设已导出到 Zync/exports 目录';

  @override
  String get presetApplyAction => '套用';

  @override
  String get presetEmptyMatch => '没有匹配的预设';

  @override
  String get presetNoAdjustments => '未做调整';

  @override
  String get presetUnnamed => '未命名预设';

  @override
  String get videoReadMetaFailed => '无法读取视频元数据';

  @override
  String get videoUnsupportedCodec => '无法读取该视频，请确认编码受系统支持';

  @override
  String get videoGeneratingProxyToast => '正在生成 4 秒调色/LUT 预览代理…';

  @override
  String get videoProxyFailedToast => '调色预览生成失败，请检查编解码能力';

  @override
  String get videoProxyReadyToast => '已生成调色预览，可在预览右上角切换原片/调色';

  @override
  String get videoExportFailedToast => '视频导出失败，请检查机型编解码能力';

  @override
  String get videoExportSaveAlbumFailedToast => '导出完成，但写入相册失败';

  @override
  String get videoExportSuccessToast => '视频已导出到 DCIM/Zync';

  @override
  String get videoGeneratePreviewTooltip => '生成调色预览';

  @override
  String get videoRefreshGeneratePreview => '生成/刷新调色预览';

  @override
  String get videoExportVideoAction => '导出视频';

  @override
  String get videoGeneratingProxyOverlay => '正在生成视频预览代理…';

  @override
  String get videoSkipProxyUseOriginal => '跳过代理，直接使用原片';

  @override
  String get videoBadge4sProxy => '4 秒调色预览代理';

  @override
  String get videoBadgeOriginalPreview => '原片预览 · 导出应用调色/LUT';

  @override
  String get videoBadgePreviewStale => '预览已过期';

  @override
  String get videoToggleGradedPreview => '调色预览';

  @override
  String get videoToggleOriginalPreview => '原片';

  @override
  String get videoExitFullscreen => '退出全屏';

  @override
  String get videoEnterFullscreen => '全屏预览';

  @override
  String get videoTabTrim => '剪辑';

  @override
  String get videoTabGrade => '调色';

  @override
  String get videoTabAudio => '音频';

  @override
  String get videoTabScopes => '示波器';

  @override
  String get videoTimelineClipsHeader => '时间线片段';

  @override
  String get videoAddLocalClipTooltip => '添加本地视频片段';

  @override
  String videoClipIndexLabel(int index) {
    return '片段 $index';
  }

  @override
  String get videoMoveClipEarlier => '前移片段';

  @override
  String get videoMoveClipLater => '后移片段';

  @override
  String get videoTrimRangeLabel => '裁剪范围';

  @override
  String get videoSplitClipAction => '分割';

  @override
  String get videoDeleteClipAction => '删除片段';

  @override
  String videoChapterDefaultTitle(int index) {
    return '章节 $index';
  }

  @override
  String get videoAddChapterButton => '章节标记';

  @override
  String get videoChapterNavHeader => '章节导航';

  @override
  String get videoGlobalGradeTitle => '整体调色';

  @override
  String get videoGlobalGradeOnSub => '作用于时间线所有片段';

  @override
  String get videoGlobalGradeOffSub => '仅作用于当前片段';

  @override
  String get videoGlobalGradeHint => '整体调色会叠加在当前片段的单独调色之前；关键帧仍按片段记录。';

  @override
  String get videoKeyframeParamLabel => '关键帧参数';

  @override
  String get videoAddKeyframeButton => '打关键帧';

  @override
  String get videoKeyframeListHeader => '关键帧列表';

  @override
  String get videoPresetEntryTitle => '调色预设：保存 / 套用 / 导入导出';

  @override
  String get videoCopiedGlobalGradeToast => '已复制整体调色';

  @override
  String get videoCopiedClipGradeToast => '已复制当前片段调色';

  @override
  String get videoCopyGradeAction => '复制调色';

  @override
  String get videoPasteGradeAction => '粘贴调色';

  @override
  String get videoRefresh4sPreview => '刷新 4 秒调色预览';

  @override
  String get videoGenerate4sPreview => '生成 4 秒调色预览';

  @override
  String videoGlobalGradeStatusChip(String status) {
    return '整体调色：$status';
  }

  @override
  String get videoStatusEnabled => '已启用';

  @override
  String videoKeyframeCountChip(int count) {
    return '关键帧：$count 个';
  }

  @override
  String videoWheelHue(String wheel) {
    return '$wheel 色相';
  }

  @override
  String videoWheelSaturation(String wheel) {
    return '$wheel 饱和度';
  }

  @override
  String videoWheelLuma(String wheel) {
    return '$wheel 亮度';
  }

  @override
  String get videoCurveLinear => '线性';

  @override
  String get videoCurveEaseInOut => '缓入缓出';

  @override
  String get videoLutGlobalTitle => '整体 LUT 还原色彩';

  @override
  String get videoLutClipTitle => '当前片段 LUT 还原色彩';

  @override
  String get videoLutPathHint => '.cube / PNG LUT 文件路径';

  @override
  String get videoPickLutTooltip => '选择 LUT 文件';

  @override
  String get videoApplyLutAction => '应用 LUT';

  @override
  String get videoLutIntensityLabel => 'LUT 强度';

  @override
  String get videoColorUnlabeled => '未标注';

  @override
  String videoSourceColorLabel(String label) {
    return '源色彩：$label';
  }

  @override
  String videoHdrToneMapHint(String label) {
    return '检测到 HDR 源（$label）。导出按 SDR Rec.709 做色调映射；N-Log 需配合 LUT 还原。';
  }

  @override
  String get videoSdrSourceHint => 'SDR 源，直接使用当前调色与 LUT，不会额外做 HDR 映射。';

  @override
  String get videoAudioMute => '静音';

  @override
  String get videoAudioVolume => '音量';

  @override
  String get videoAudioFadeIn => '淡入（秒）';

  @override
  String get videoAudioFadeOut => '淡出（秒）';

  @override
  String get videoExportSettingsHeader => '导出设置';

  @override
  String videoHwHevcStatus(String status) {
    return '硬件 HEVC 解码：$status';
  }

  @override
  String get videoExport4k60Note => '4K/60 为尽力支持；若设备编码器不支持，导出会失败并保留原片。';

  @override
  String get videoNoHevc10BitWarning =>
      '未检测到 HEVC Main10 硬件解码；10-bit N-Log/HLG 可能无法预览，导出前请先试跑 4 秒预览。';

  @override
  String get videoCodecLabel => '编码格式';

  @override
  String get videoCodecH264 => 'H.264（兼容性最好）';

  @override
  String get videoCodecHevc => 'HEVC（体积更小）';

  @override
  String get videoCodecHevcUnsupported => 'HEVC（设备不支持）';

  @override
  String get videoResolutionLabel => '分辨率';

  @override
  String get videoFpsLabel => '帧率';

  @override
  String get videoBitrateLabel => '码率';

  @override
  String get videoBitrate20 => '标准 20 Mbps';

  @override
  String get videoBitrate40 => '高画质 40 Mbps';

  @override
  String get videoBitrate80 => '专业 80 Mbps';

  @override
  String videoExportingProgressHint(int percent) {
    return '正在导出 $percent%，请保持应用前台运行';
  }

  @override
  String get videoCancelExport => '取消导出';

  @override
  String get videoExportToDcimButton => '导出到 DCIM/Zync';

  @override
  String get scopeTitle => '视频示波器';

  @override
  String get scopeCaptureFrameTooltip => '抓取当前帧';

  @override
  String get scopeWaveform => '波形图';

  @override
  String get scopeVectorscope => '矢量示波器';

  @override
  String get scopeAnalyzing => '正在分析当前帧…';

  @override
  String get scopeEmptyHint => '点击右上角刷新抓取当前帧';

  @override
  String get scopeLumaHistogram => '亮度直方图';

  @override
  String get scopePeak => '峰值';

  @override
  String get scopeAverage => '平均';

  @override
  String get scopeBlackLevel => '黑位';

  @override
  String get scopeHighlightClip => '高光削波';

  @override
  String get scopeShadowClip => '暗部削波';

  @override
  String get wmStudioTitle => '水印工坊';

  @override
  String get wmPickFromAlbumTooltip => '从手机相册选图';

  @override
  String get wmStyleSettingsTooltip => '水印设置（样式 / 内容 / 文字 / Logo）';

  @override
  String get wmExportQualityTitle => '导出质量';

  @override
  String wmExportQualityMenuLabel(String label, int quality) {
    return '导出质量：$label（q$quality）';
  }

  @override
  String get exportQualityOriginal => '原图质量';

  @override
  String get exportQualityStandard => '标准';

  @override
  String get exportQualityCompact => '省空间';

  @override
  String get wmSaveHighResTooltip => '保存高清成片至相册';

  @override
  String get wmShowingOriginalBadge => '显示原片中';

  @override
  String get wmHoldToCompareHint => '按住对比原片';

  @override
  String get wmPickPhotoEmptyPrompt => '选择本地照片进行调色加水印';

  @override
  String get wmEditExifTag => '微调参数';

  @override
  String get wmTabWatermark => '添加水印';

  @override
  String get wmTabColorGrade => '调色预设';

  @override
  String get wmTabPhotoEdit => '图像编辑';

  @override
  String get wmPureGradeModeTitle => '当前处于【纯滤镜调色模式】';

  @override
  String get wmPureGradeModeSub => '画面不添加任何边框或水印文字，保持原图全画幅尺寸直出。';

  @override
  String get wmGoToGradeButton => '去调色';

  @override
  String get wmBorderColorShort => '边框颜色';

  @override
  String get wmTextColorShort => '字体颜色';

  @override
  String get wmDetailSettingsShort => '详细设置';

  @override
  String get wmGradeCatTone => '基础色调';

  @override
  String get wmGradeCatWb => '白平衡';

  @override
  String get wmGradeCatPresence => '偏好质感';

  @override
  String get wmGradeCatSplit => '颜色分级';

  @override
  String get wmGradeCatFilm => '胶片预设';

  @override
  String get wmGradeCatEffects => '镜头与效果';

  @override
  String get wmCurrentModeNoWatermark => '当前模式: 纯调色直出 (无水印)';

  @override
  String wmCurrentTemplateLabel(String name) {
    return '当前水印: $name';
  }

  @override
  String get wmEnableWatermarkSwitch => '开启水印';

  @override
  String get wmDisableWatermarkSwitch => '关闭水印 (仅调色)';

  @override
  String wmImportedExifToast(String title) {
    return '已成功导入本地照片，已自动提取拍摄参数（$title）';
  }

  @override
  String get wmDecodeImageFailed => '图片解码失败';

  @override
  String wmParseImageFailed(String error) {
    return '图片解析失败: $error';
  }

  @override
  String get wmSelectPhotoFirstHint => '请先点击右上角相册图标选择照片，或从相机相册导入';

  @override
  String get wmRawFullDecodeFailed => 'RAW 全尺寸解码失败';

  @override
  String get wmSaveAlbumFailed => '保存到系统相册失败';

  @override
  String wmSavedSuccessToast(int width, int height, String sizeMb) {
    return '已保存到系统相册 · $width×$height · ${sizeMb}MB';
  }

  @override
  String get wmViewInAlbumAction => '在相册查看';

  @override
  String wmExportFailedToast(String error) {
    return '导出失败: $error';
  }

  @override
  String get wmExifSheetTitle => '微调拍摄参数';

  @override
  String get wmExifSheetSub => '对无芯片手动镜头或无 EXIF 照片，可在此自由修改显示参数';

  @override
  String get wmExifCameraLabel => '相机机型';

  @override
  String get wmExifCameraHint => '如 Z 30, Z 8, Z fc';

  @override
  String get wmExifLensLabel => '镜头型号';

  @override
  String get wmExifLensHint => '如 NIKKOR Z 40mm f/2';

  @override
  String get wmExifApertureLabel => '光圈值';

  @override
  String get wmExifApertureHint => '如 f/1.8';

  @override
  String get wmExifShutterLabel => '快门速度';

  @override
  String get wmExifShutterHint => '如 1/250s';

  @override
  String get wmExifIsoLabel => '感光度';

  @override
  String get wmExifIsoHint => '如 ISO 100';

  @override
  String get wmExifFocalLabel => '焦距';

  @override
  String get wmExifFocalHint => '如 40mm';

  @override
  String get wmExifDateLabel => '拍摄时间';

  @override
  String get wmExifDateHint => '如 2026.10.06 14:32';

  @override
  String get wmExifApplyButton => '应用参数';

  @override
  String get wmSettingsSheetTitle => '水印设置';

  @override
  String get wmSettingsSheetSub => '颜色、字号、字距、行距与内容开关会自动保存；Logo 图片仅本次会话保留';

  @override
  String get wmLogoSectionTitle => 'Logo 贴图';

  @override
  String get wmLogoReadFailedToast => 'Logo 图片读取失败';

  @override
  String get wmLogoPickButton => '选择 Logo';

  @override
  String get wmLogoChangeButton => '更换 Logo';

  @override
  String get wmLogoSizeLabel => 'Logo 大小';

  @override
  String get wmLogoOpacityLabel => 'Logo 透明度';

  @override
  String get wmSizeSmall => '小';

  @override
  String get wmSizeMedium => '中';

  @override
  String get wmSizeLarge => '大';

  @override
  String get wmOpacityOpaque => '不透明';

  @override
  String get wmOpacitySemi => '半透明';

  @override
  String get wmOpacityLight => '淡';

  @override
  String get wmLogoPositionLabel => 'Logo 位置';

  @override
  String get adjExposure => '曝光';

  @override
  String get adjExposureDesc => '调整画面全局亮度 (-2EV ~ +2EV)';

  @override
  String get adjContrast => '对比度';

  @override
  String get adjContrastDesc => '增强或降低画面明暗反差';

  @override
  String get adjHighlights => '高光';

  @override
  String get adjHighlightsDesc => '压暗过曝高光或提升亮部层次';

  @override
  String get adjShadows => '阴影';

  @override
  String get adjShadowsDesc => '提亮暗部死黑或加深暗影深度';

  @override
  String get adjWhites => '白色色阶';

  @override
  String get adjWhitesDesc => '微调高光纯白剪切阈值';

  @override
  String get adjBlacks => '黑色色阶';

  @override
  String get adjBlacksDesc => '微调暗部纯黑剪切点';

  @override
  String get adjTemperature => '色温';

  @override
  String get adjTemperatureDesc => '向左偏冷蓝 (冷调天空/雪景)，向右偏暖黄 (日落/人像金黄)';

  @override
  String get adjTint => '色调';

  @override
  String get adjTintDesc => '向左校正偏绿，向右偏洋红品红补偿';

  @override
  String get adjClarity => '清晰度';

  @override
  String get adjClarityDesc => '调整中间调微反差，强化景物轮廓肌理';

  @override
  String get adjTexture => '纹理';

  @override
  String get adjTextureDesc => '强化或柔化中高频细节，为人像微磨皮或突出毛发轮廓';

  @override
  String get adjDehaze => '去朦胧';

  @override
  String get adjDehazeDesc => '消除逆光光雾漫反射，显著增加画面通透感';

  @override
  String get adjVibrance => '鲜艳度';

  @override
  String get adjVibranceDesc => '优先提升未饱和低彩度区域，智能保护人像肤色';

  @override
  String get adjSaturation => '饱和度';

  @override
  String get adjSaturationDesc => '全局色彩纯度，降至最低为纯黑白，最高为浓郁艳丽';

  @override
  String get adjSplitToningInfo =>
      '色彩分级 (Split Toning)：分别为画面高光亮部与阴影暗部注入特定色调，打造电影感与日式冷暖色彩分离。';

  @override
  String get adjHighlightHue => '高光色相';

  @override
  String get adjHighlightHueDesc =>
      '高光注入色相 (0°~360°)，暖金色约 35°~45°，青蓝约 195°~210°';

  @override
  String get adjHighlightSat => '高光饱和度';

  @override
  String get adjHighlightSatDesc => '高光色调注入浓度 (0%~100%)';

  @override
  String get adjShadowHue => '阴影色相';

  @override
  String get adjShadowHueDesc =>
      '阴影注入色相 (0°~360°)，冷青蓝约 200°~220°，复古品红约 300°~320°';

  @override
  String get adjShadowSat => '阴影饱和度';

  @override
  String get adjShadowSatDesc => '阴影色调注入浓度 (0%~100%)';

  @override
  String get adjMidtones => '中间调';

  @override
  String get adjSharpening => '锐化';

  @override
  String get adjNoiseReduction => '降噪';

  @override
  String get adjLensDistortion => '镜头畸变';

  @override
  String get adjLensVignette => '镜头暗角';

  @override
  String get adjLensVignetteDesc => '向右加深电影边缘黑暗角，向左添加高调纯白晕影';

  @override
  String get adjChromaticAberration => '色差校正';

  @override
  String get adjFilmGrain => '胶片颗粒';

  @override
  String get adjFilmGrainDesc => '模拟经典银盐胶片细密颗粒噪点，显著增加怀旧与故事感';

  @override
  String get adjToneCurve => '曲线';

  @override
  String get adjColorWheel => '色轮';

  @override
  String wmFilterAllCount(int count) {
    return '全部 ($count)';
  }

  @override
  String wmRecipeSummaryPrefix(String summary) {
    return '机内配方: $summary';
  }

  @override
  String get wmPresetIntensity => '预设浓度';

  @override
  String get wmProRawSectionEntry => '专业参数：LUT / 降噪 / 锐化 / 镜头校正';

  @override
  String wmLoadedFilterSlidersToast(String name) {
    return '已载入【$name】全套参数至调色滑块，可自由深度微调！';
  }

  @override
  String wmLoadFilterToSlidersButton(String name) {
    return '载入【$name】参数至滑块 (支持深度微调)';
  }

  @override
  String get wmProRawSheetTitle => '专业 RAW 参数';

  @override
  String get wmStyleFollowTemplate => '跟随模板';

  @override
  String get wmStylePureWhite => '纯白';

  @override
  String get wmStyleDeepBlack => '深黑';

  @override
  String get wmStyleCream => '米白';

  @override
  String get wmStyleNikonGold => '尼康金';

  @override
  String get wmStyleCyan => '青';

  @override
  String get wmStyleMagenta => '品红';

  @override
  String get wmStyleDarkGrey => '深灰';

  @override
  String get wmStyleCustomColorTitle => '自定义颜色';

  @override
  String get wmStyleColorsSection => '配色';

  @override
  String get wmStyleFrameBgLabel => '边框 / 底色';

  @override
  String get wmStyleTextColorLabel => '字体颜色';

  @override
  String get wmStyleAccentColorLabel => '强调色';

  @override
  String get wmStyleTypographySection => '字号与排版';

  @override
  String get wmStyleTitleScale => '标题字号';

  @override
  String get wmStyleMetaScale => '参数字号';

  @override
  String get wmStyleCustomTextScale => '自定义字号';

  @override
  String get wmStyleLetterSpacing => '字距';

  @override
  String get wmStyleLineSpacing => '行距';

  @override
  String get wmStyleLineThickness => '线条厚度';

  @override
  String get wmStyleMarginScale => '留白比例';

  @override
  String get wmStyleCornerRadius => '卡片圆角';

  @override
  String get wmStyleOpacity => '不透明度';

  @override
  String get wmStyleFontFamily => '字体';

  @override
  String get wmStyleFontDefault => '默认';

  @override
  String get wmStyleFontSerif => '衬线';

  @override
  String get wmStyleFontMono => '等宽';

  @override
  String get wmStyleFontCondensed => '窄体';

  @override
  String get wmStyleFontWeight => '字重';

  @override
  String get wmStyleWeightRegular => '常规';

  @override
  String get wmStyleWeightMedium => '中粗';

  @override
  String get wmStyleWeightBold => '粗体';

  @override
  String get wmStyleWeightBlack => '特粗';

  @override
  String get wmStyleContentSection => '内容';

  @override
  String get wmStyleShowModel => '机型';

  @override
  String get wmStyleShowLens => '镜头';

  @override
  String get wmStyleShowExposure => '拍摄参数';

  @override
  String get wmStyleShowDate => '拍摄日期';

  @override
  String get wmStyleShowDetails => '展示拍摄时间与细节';

  @override
  String get wmStyleCustomTextSection => '自定义文字';

  @override
  String get wmStyleCustomLine1Label => '自定义文字 1';

  @override
  String get wmStyleCustomLine1Hint => '例如 © 2026 你的名字';

  @override
  String get wmStyleCustomLine2Label => '自定义文字 2';

  @override
  String get wmStyleCustomLine2Hint => '例如 Nikon Z 30';

  @override
  String get wmStyleTextAlign => '文字对齐';

  @override
  String get wmStyleAlignLeft => '左对齐';

  @override
  String get wmStyleAlignCenter => '居中';

  @override
  String get wmStyleAlignRight => '右对齐';

  @override
  String get wmCornerTopLeft => '左上';

  @override
  String get wmCornerTopRight => '右上';

  @override
  String get wmCornerBottomLeft => '左下';

  @override
  String get wmCornerBottomRight => '右下';

  @override
  String get collageTitle => '拼图';

  @override
  String get collageInsufficientPhotos => '可用素材不足 2 张，无法拼图';

  @override
  String collageSkippedUnreadableToast(int count) {
    return '已跳过 $count 张无法读取的照片';
  }

  @override
  String get collageSaveSuccessTitle => '拼图已保存到系统相册';

  @override
  String get collageSaveSuccessBody => '已保存至系统相册 (Pictures/Zync)，可在手机自带相册即刻查看。';

  @override
  String get collagePreparingMaterials => '正在准备拼图素材...';

  @override
  String get collageWatermarkDragHint => '已应用水印模板，完整效果见「水印」页；此处直接拖动/捏合调整每张图片。';

  @override
  String get collageTabLayout => '布局';

  @override
  String get collageTabWatermark => '水印';

  @override
  String get collageNoWatermark => '无水印';

  @override
  String get collageMethodLabel => '拼接方式';

  @override
  String get collageAspectLabel => '比例';

  @override
  String get collageBorderLabel => '边框';

  @override
  String get collageOutputResolution => '输出分辨率';

  @override
  String get collageFileSize => '文件大小';

  @override
  String get collageSharedWatermarkSub => '与水印工坊共用同一套颜色、字号和排版设置';

  @override
  String get settingsTitle => '系统设置';

  @override
  String get settingsGroupPreferences => '偏好设置';

  @override
  String get settingsGroupSystem => '系统';

  @override
  String get settingsAppearanceTitle => '外观与显示';

  @override
  String get settingsAppearanceSub => '跟随系统、浅色或深色';

  @override
  String get settingsLanguageTitle => '应用语言';

  @override
  String get settingsLanguageSub => 'English · 简体中文 · 日本語';

  @override
  String get settingsCameraTitle => '相机连接';

  @override
  String get settingsCameraSub => 'IP、端口与网卡绑定';

  @override
  String get settingsWirelessTitle => '无线与传输';

  @override
  String get settingsWirelessSub => '保活与边拍边传';

  @override
  String get settingsKeepAliveOnShort => '保活开';

  @override
  String get settingsKeepAliveOffShort => '保活关';

  @override
  String get settingsBatteryTitle => '电池与传输保护';

  @override
  String get settingsBatterySub => '低电量暂停与恢复';

  @override
  String settingsThresholdValue(int threshold) {
    return '$threshold% 阈值';
  }

  @override
  String get settingsLogsTitle => '诊断与日志';

  @override
  String get settingsLogsSub => '协议握手与通信记录';

  @override
  String settingsLogsCountValue(int count) {
    return '$count 条记录';
  }

  @override
  String get settingsAboutTitle => '关于 Zync';

  @override
  String get settingsAboutSub => '版本、更新与开源许可';

  @override
  String get settingsReplayOnboardingTitle => '欢迎引导';

  @override
  String get settingsReplayOnboardingSub => '重新查看首次启动的语言、外观与连接引导';

  @override
  String get settingsAppearanceModeSection => '外观模式';

  @override
  String get settingsColorPreviewSection => '颜色预览';

  @override
  String get settingsColorPreviewTileTitle => '背景 / 卡片 / 强调色';

  @override
  String get settingsConfigIpTitle => '配置相机 IP 地址';

  @override
  String get settingsConfigIpSub => '尼康 Z 系列相机热点默认网关为 192.168.0.1';

  @override
  String get settingsIpAddressField => 'IP 地址';

  @override
  String get settingsConfigPortTitle => '配置 PTP/IP 端口';

  @override
  String get settingsConfigPortSub => '尼康 PTP/IP 硬件标准通信端口为 15740';

  @override
  String get settingsPortField => '端口号';

  @override
  String get settingsPtpNetworkSection => 'PTP/IP 网络';

  @override
  String get settingsDefaultCameraIp => '默认相机 IP 地址';

  @override
  String get settingsPtpPortTile => 'PTP/IP 通信端口';

  @override
  String get settingsRestoreDefaultIpTile => '尼康 Z 系列默认热点预设';

  @override
  String get settingsRestoredDefaultIpToast => '已恢复尼康 Z 系列默认相机热点地址';

  @override
  String get settingsAndroidNetworkSection => 'Android 网络';

  @override
  String get settingsAutoBindTitle => 'Android 进程网卡强绑定';

  @override
  String get settingsAutoBindSub => '连接相机热点时优先绑定 Wi-Fi 网卡';

  @override
  String get settingsKeepAliveSection => '连接保持';

  @override
  String get settingsKeepAliveToggleTitle => '后台保持相机 Wi-Fi 连接';

  @override
  String get settingsHeartbeatTitle => 'PTP/IP 心跳间隔';

  @override
  String get settingsHeartbeatValue => '15 秒 (防止相机自动休眠)';

  @override
  String get settingsShootTransferSection => '边拍边传';

  @override
  String get settingsDownloadRawTitle => '同步 RAW 格式';

  @override
  String get settingsDownloadRawSub => '同时下载 NEF / NRW 文件';

  @override
  String get settingsDeleteConfirmSection => '删除与确认';

  @override
  String get settingsConfirmDeleteTitle => '删除前再次确认';

  @override
  String get settingsConfirmDeleteSub => '关闭后，选定删除范围即执行不可恢复的删除';

  @override
  String get settingsPowerProtectionSection => '低电量传输保护';

  @override
  String get settingsPowerProtectionToggle => '启用低电量传输保护';

  @override
  String get settingsPowerThresholdTile => '电量暂停保护阈值';

  @override
  String get settingsHysteresisTitle => '迟滞恢复机制 (+5%)';

  @override
  String get settingsHysteresisValue => '电量回升至阈值 +5% 自动恢复';

  @override
  String get settingsActiveTransferRuleTitle => '正在传输任务';

  @override
  String get settingsActiveTransferRuleValue => '完成当前文件写入后再暂停 (不截断)';

  @override
  String get settingsLogsSection => '协议通信诊断';

  @override
  String get settingsViewLogsTile => '查看协议握手与通信日志';

  @override
  String get settingsClearLogsTile => '清空通信诊断日志';

  @override
  String get settingsClearedLogsToast => '已清空全部日志';

  @override
  String get settingsLogsViewerTitle => '底层协议通信与握手日志';

  @override
  String get settingsCopyAllLogsTooltip => '复制全部日志';

  @override
  String get settingsCopiedLogsToast => '已复制全部通信日志至剪贴板';

  @override
  String get settingsClearLogsTooltip => '清空日志';

  @override
  String get settingsLogsEmpty => '暂无通信日志';

  @override
  String get settingsVersionSection => '版本与更新';

  @override
  String get settingsAppVersionTile => '应用版本';

  @override
  String get settingsCheckUpdateTile => '检查新版本';

  @override
  String get settingsCheckUpdateValue => '在线检测 (GitHub)';

  @override
  String get settingsTechSection => '技术信息';

  @override
  String get settingsDriverArchTile => '驱动架构';

  @override
  String get settingsUiSystemTile => 'UI 体系';

  @override
  String get settingsUiSystemValue => 'Zync Pro Darkroom 专业暗房设计系统';

  @override
  String get settingsProjectSection => '项目与许可';

  @override
  String get settingsRepoUrlTile => '项目地址';

  @override
  String get settingsOpenSourceCreditsTile => '开源致谢';

  @override
  String get settingsOpenSourceCreditsSub => '核心项目、协议参考与运行时依赖';

  @override
  String settingsCreditsCountValue(int count) {
    return '$count 项';
  }

  @override
  String get settingsLicenseDisclaimerTitle => '许可说明';

  @override
  String get settingsLicenseDisclaimerBody =>
      '各项目的版权与许可证归原作者所有。未声明许可证的项目仅作兼容性参考。';

  @override
  String get settingsCreditsCoreGroup => '核心项目与协议参考';

  @override
  String get settingsCreditsRuntimeGroup => '运行时与基础依赖';

  @override
  String get settingsAppLicenseTile => '应用许可证';

  @override
  String get settingsCannotOpenUrlToast => '无法打开项目地址';

  @override
  String get updateDefaultChangelog => '修复已知问题，优化使用体验。';

  @override
  String get updateCheckingToast => '正在检查新版本...';

  @override
  String get updateCheckFailedTitle => '检查更新失败';

  @override
  String get updateCheckFailedBody =>
      '无法连接到更新服务器，请检查网络连接后重试。\n\n您也可以前往 GitHub 查看最新发布。';

  @override
  String get updateUpToDateTitle => '已是最新版本';

  @override
  String updateUpToDateBody(String version, String source) {
    return '当前版本 v$version 已经是最新版本，无需更新！\n检测源: $source 发布';
  }

  @override
  String get updateCheckErrorTitle => '检查更新出错';

  @override
  String get updateOpenWebsite => '打开官网';

  @override
  String get updatePreparing => '准备中...';

  @override
  String get updateInstallerFailedToast => '调起安装器失败，请检查未知来源安装权限或选择浏览器下载';

  @override
  String get updateBrowserDownload => '浏览器下载';

  @override
  String updateSkippedVersionToast(String version) {
    return '已跳过版本 v$version，后续启动不再提醒';
  }

  @override
  String get updateNewVersionTitle => '发现新版本';

  @override
  String get updateSourceGithub => 'GitHub 发布';

  @override
  String get updateChangelogHeader => '更新内容';

  @override
  String updatePackageSizeLabel(String size) {
    return '安装包大小: $size';
  }

  @override
  String updateDownloadingPct(String percent) {
    return '正在下载: $percent%';
  }

  @override
  String get updateSkipThisVersion => '跳过该版';

  @override
  String get updateLater => '稍后';

  @override
  String get updateInstallNow => '立即安装';

  @override
  String get updateDownloadAndInstall => '下载并安装';

  @override
  String get updateOpenInBrowserTooltip => '在浏览器中打开下载';

  @override
  String get updateSha256MismatchError => '安装包 SHA-256 校验失败，已拒绝安装';

  @override
  String get hubTitle => '工作台';

  @override
  String get hubBentoQuickTransferTitle => '选片快传';

  @override
  String get hubBentoQuickTransferSub => '浏览相机存储卡照片并同步至手机';

  @override
  String get hubBentoWatermarkTitle => '水印暗房';

  @override
  String get hubBentoWatermarkSub => '画框模板与专业胶片调色';

  @override
  String get hubBentoCollageTitle => '拼图工坊';

  @override
  String get hubBentoCollageSub => '多张照片自由版式拼接';

  @override
  String get hubBentoTransfersTitle => '传输中心';

  @override
  String get hubBentoTransfersIdle => '队列空闲';

  @override
  String hubBentoTransfersActive(int count) {
    return '$count 项任务进行中';
  }

  @override
  String get hubRecentPhotosTitle => '最近影像';

  @override
  String get hubRecentPhotosEmpty => '暂无最近照片';

  @override
  String get hubShootAndTransferQuick => '边拍边传';

  @override
  String get hubHelpGuideTooltip => '连接排查与指南';

  @override
  String get hubGuideTitle => '相机连接指南';

  @override
  String get hubGuideWifiTitle => 'Wi-Fi 直连步骤';

  @override
  String get hubGuideWifiBody =>
      '1. 开启相机菜单中的「连接至智能设备」或「Wi-Fi 模式」\n2. 手机 Wi-Fi 列表中连接相机广播的热点（如 NIKON_...）\n3. 回到本 App 点击「立即连接」即可自动建立 PTP/IP 握手';

  @override
  String get hubGuideUsbTitle => 'USB OTG 直连步骤';

  @override
  String get hubGuideUsbBody =>
      '1. 使用 USB-C 数据线或 OTG 转接头连接手机与相机\n2. 将相机电源打开\n3. 手机弹出 USB 权限提示时勾选「始终允许」，点击「立即连接」';

  @override
  String get hubGuideClose => '知道了';

  @override
  String get connectOneTapUsb => '连接 USB 相机';

  @override
  String get connectSelectWifi => '选择相机 Wi-Fi';

  @override
  String get connectQuickConnect => '立即连接';

  @override
  String get connectUsbDetectedHeader => '已检测到 USB 相机设备';

  @override
  String get connectWifiDetectedHeader => '当前 Wi-Fi 网络';

  @override
  String get wmDockTemplate => '画框版式';

  @override
  String get wmDockFilter => '胶片滤镜';

  @override
  String get wmDockGrade => '参数精调';

  @override
  String get wmDockGeometry => '裁切几何';

  @override
  String get wmSubPalette => '配色边距';

  @override
  String get wmSubToggles => '开关文案';

  @override
  String get wmSubTypography => '字体字号';

  @override
  String get wmSubLogo => 'Logo 贴图';

  @override
  String get wmHistogramHudTooltip => '直方图 HUD';

  @override
  String get wmDialResetAll => '重置全部';

  @override
  String get wmDialTransferToGrade => '转入精调';

  @override
  String get wmDialSaveAsPreset => '存为预设';

  @override
  String get wmDialCategoryPreset => '★ 预设库';

  @override
  String get wmDialPresetCustomGroup => '我的预设';

  @override
  String get wmDialSavePresetPrompt => '输入预设名称';

  @override
  String wmDialSavePresetSuccess(String name) {
    return '已成功保存预设「$name」';
  }

  @override
  String get wmDialActiveLutButton => '选择 3D LUT 文件';

  @override
  String get wmDialNoLutChosen => '未加载 LUT 文件';

  @override
  String get wmExportMenuTitle => '导出画质';

  @override
  String get galleryTabCameraCard => '相机卡';

  @override
  String get galleryTabExportedPhoneShort => '已导出';

  @override
  String get galleryActionSelectAll => '全选';

  @override
  String get galleryActionDeselect => '取消全选';

  @override
  String get galleryExifDetailSheetTitle => '拍摄参数详情';

  @override
  String get galleryCollageDirectModeTitle => '选择拼图照片 (2-9张)';

  @override
  String get wmViewModeListTooltip => '一行一种列表（带滚动条）';

  @override
  String get wmViewModePagedTooltip => '自适应屏幕高度分页';

  @override
  String get wmTabletTuneAction => '微调';

  @override
  String get wmTabletSectionTemplates => '水印版式';

  @override
  String get wmTabletSectionStyle => '样式微调';

  @override
  String get wmTabletPagePrev => '上一页';

  @override
  String get wmTabletPageNext => '下一页';

  @override
  String wmTabletPageIndicator(Object current, Object total) {
    return '第 $current / $total 页';
  }

  @override
  String get wmTabletPureGradeHint => '当前为纯滤镜调色模式，未启用画框水印';

  @override
  String get wmTabletPureGradeAction => '选择水印版式';
}
