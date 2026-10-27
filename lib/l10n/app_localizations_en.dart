// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Zync - Nikon Z Transfer & Darkroom Studio';

  @override
  String get navConnect => 'Connect';

  @override
  String get navGallery => 'Camera Roll';

  @override
  String get navWatermark => 'Watermark Studio';

  @override
  String get navSettings => 'Settings';

  @override
  String get exitConfirmHint => 'Press back again to exit Zync';

  @override
  String get sidebarCollapse => 'Collapse sidebar';

  @override
  String get sidebarExpand => 'Expand sidebar';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonMore => 'More';

  @override
  String get commonClose => 'Close';

  @override
  String get commonExit => 'Exit';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonExport => 'Export';

  @override
  String get commonImport => 'Import';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRedo => 'Redo';

  @override
  String get commonOriginal => 'Original';

  @override
  String get commonCompare => 'Compare';

  @override
  String get commonCustom => 'Custom';

  @override
  String get commonDefault => 'Default';

  @override
  String get commonNone => 'None';

  @override
  String get commonAll => 'All';

  @override
  String get commonView => 'View';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonUnknownError => 'Unknown error';

  @override
  String get commonUnknownSize => 'Unknown size';

  @override
  String get commonSupported => 'Supported';

  @override
  String get commonUnsupported => 'Unsupported';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonDisabled => 'Off';

  @override
  String get commonSuccess => 'Success';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonWarning => 'Warning';

  @override
  String get langSystem => 'System default';

  @override
  String get langSystemDesc => 'Follow device language (fallback to English)';

  @override
  String get langEn => 'English';

  @override
  String get langEnSub => 'English interface';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhSub => 'Simplified Chinese';

  @override
  String get langJa => '日本語';

  @override
  String get langJaSub => 'Japanese interface';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystemSub => 'Switch automatically with device appearance';

  @override
  String get themeLightSub =>
      'Soft neutral paper surface with muted teal accent';

  @override
  String get themeDarkSub =>
      'Neutral graphite darkroom surface for accurate color judgment';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingStart => 'Enter Studio';

  @override
  String onboardingStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingLangTitle => 'Choose Your Language';

  @override
  String get onboardingLangSubtitle =>
      'Tap a language to preview immediately. You can change this anytime in Settings.';

  @override
  String get onboardingThemeTitle => 'Darkroom Appearance';

  @override
  String get onboardingThemeSubtitle =>
      'Crafted with a neutral graphite surface and muted teal accent so your photos stay true to color.';

  @override
  String get onboardingThemePreviewTitle => 'Live Darkroom Preview';

  @override
  String get onboardingThemePreviewSub =>
      'NIKON Z 8 · NIKKOR Z 50mm f/1.2 S · 1/500s f/1.8 ISO 100';

  @override
  String get onboardingConnTitle => 'Direct Camera Workflow';

  @override
  String get onboardingConnSubtitle =>
      'Connect without cloud accounts or proprietary SDKs, browse RAW & JPEG, and finish in the studio.';

  @override
  String get onboardingConnWifiTitle => 'Wi-Fi PTP/IP Tethering';

  @override
  String get onboardingConnWifiDesc =>
      'Join the camera Wi-Fi hotspot for wireless browsing, chunked downloads, and shoot-and-transfer.';

  @override
  String get onboardingConnUsbTitle => 'USB OTG PTP Direct';

  @override
  String get onboardingConnUsbDesc =>
      'Plug in a Type-C OTG cable in MTP/PTP mode for rock-solid wired transfer of large NEF & video files.';

  @override
  String get onboardingConnStudioTitle =>
      '16-Bit RAW, Video & Watermark Studio';

  @override
  String get onboardingConnStudioDesc =>
      'Decode NEF RAW with LibRaw, grade video with 3D LUTs, and export EXIF gallery frames.';

  @override
  String get connectDetecting => '<Detecting...>';

  @override
  String get connectModeWifi => 'Camera Wi-Fi';

  @override
  String get connectModeUsb => 'USB Wired';

  @override
  String get connectModeBle => 'BLE Lab';

  @override
  String get connectWifiWarnTitle =>
      'Current Wi-Fi may not be a camera hotspot';

  @override
  String connectWifiWarnBody(String ssid) {
    return 'Current network: $ssid\nStill attempt a PTP/IP connection?';
  }

  @override
  String get connectContinueAttempt => 'Connect Anyway';

  @override
  String connectFailedToast(String error) {
    return 'Connection failed: $error';
  }

  @override
  String connectWifiFailedToast(String error) {
    return 'Connection failed: $error\nTip: Join the camera Wi-Fi hotspot in system settings first.';
  }

  @override
  String get connectDisconnectedToast =>
      'Disconnected from camera and released network binding';

  @override
  String connectUsbScanResult(int total, int ready) {
    return 'Detected $total USB camera(s), $ready ready for PTP session';
  }

  @override
  String connectUsbScanFailed(String error) {
    return 'USB scan failed: $error';
  }

  @override
  String connectUsbModeSwitchHint(String name, String mode) {
    return '$name is currently in $mode. Switch USB mode to MTP/PTP in the camera menu and refresh.';
  }

  @override
  String get connectUsbUnsupportedDriver =>
      'Current driver does not support USB connection';

  @override
  String get connectUsbPermissionDenied => 'USB permission denied';

  @override
  String get connectUsbFailedTitle => 'USB Connection Failed';

  @override
  String connectUsbFailedToast(String error) {
    return 'USB connection failed: $error';
  }

  @override
  String get connectUsbTroubleHeader => 'Troubleshooting:';

  @override
  String get connectUsbTroubleStep1 =>
      '1. Set USB mode to MTP/PTP in camera menu (not Mass Storage);';

  @override
  String get connectUsbTroubleStep2 =>
      '2. Use a data-capable OTG cable connected directly to your phone (avoid USB hubs);';

  @override
  String get connectUsbTroubleStep3 =>
      '3. Replug the cable, refresh USB devices, and try again.';

  @override
  String get connectBleStoppedToast => 'Bluetooth scan stopped';

  @override
  String get connectBleStartFailedToast =>
      'Failed to start Bluetooth scan. Check Bluetooth & nearby device permissions.';

  @override
  String get connectBlePairSuccessToast =>
      'Bluetooth pairing handshake initiated!';

  @override
  String connectBleFailedToast(String error) {
    return 'Bluetooth connection failed: $error';
  }

  @override
  String get connectMyCamera => 'My Camera';

  @override
  String get connectDisconnectShort => 'Disconnect';

  @override
  String get connectHeroTitle => 'Zync · Nikon Z Series';

  @override
  String get connectHeroSubtitle =>
      'Pro Wireless Tethering, Transfer & Darkroom Studio for Nikon Z';

  @override
  String connectStatusConnectedBanner(String mode, String endpoint) {
    return 'Connected  $mode · $endpoint';
  }

  @override
  String get connectCameraBrand => 'Brand';

  @override
  String get connectCameraModel => 'Model';

  @override
  String get connectBrowsePhotos => 'Browse Camera Photos';

  @override
  String get connectLensSectionTitle => 'Mounted Lens';

  @override
  String get connectLensIdentified => 'Identified';

  @override
  String get connectLensUnread => 'Not read';

  @override
  String get connectLensFocalRange => 'Focal Range';

  @override
  String get connectLensCurrentFocal => 'Focal Length';

  @override
  String get connectLensCurrentAperture => 'Aperture';

  @override
  String get connectDisconnectFull => 'Disconnect Camera & Release Network';

  @override
  String get connectCurrentWifiLabel => 'Current Wi-Fi';

  @override
  String get connectRedetectWifiTooltip => 'Re-detect Wi-Fi';

  @override
  String get connectWifiReadyHint =>
      'Connected to camera hotspot. Tap below to establish a PTP/IP session.';

  @override
  String get connectWifiJoinHint =>
      'Join the camera Wi-Fi hotspot in system settings first (e.g. NIKON_...)';

  @override
  String get connectOpenSystemWifi => 'Open System Wi-Fi Settings';

  @override
  String get connectConnectingButton => 'Connecting...';

  @override
  String get connectWifiButton => 'Connect Camera (Wi-Fi Direct)';

  @override
  String get connectBlePhoneOn => 'Phone Bluetooth On';

  @override
  String get connectBlePhoneOff => 'Phone Bluetooth Off';

  @override
  String get connectStateConnected => 'Connected';

  @override
  String get connectStatePairing => 'Pairing';

  @override
  String get connectStateDisconnected => 'Disconnected';

  @override
  String connectBlePairedDevice(String name) {
    return 'Paired: $name';
  }

  @override
  String get connectBleRemoteTitle => 'Wireless Remote Shutter (ML-L7)';

  @override
  String get connectBleHalfPress => 'Half-Press AF';

  @override
  String get connectBleFullPress => 'Shutter Release';

  @override
  String get connectBleStopScan => 'Stop Scanning';

  @override
  String get connectBleStartScan => 'Scan Nearby BLE Devices';

  @override
  String connectBleDiscoveredCount(int count) {
    return 'Discovered Cameras ($count)';
  }

  @override
  String connectBleDeviceMeta(String address, int rssi) {
    return 'MAC: $address | RSSI: $rssi dBm';
  }

  @override
  String get connectBleSearching =>
      'Searching for nearby cameras and BLE devices...';

  @override
  String get connectUsbSectionTitle => 'USB OTG Wired Connection';

  @override
  String get connectUsbPrepTitle => 'Preparation';

  @override
  String get connectUsbPrepSub =>
      'Connect camera and phone directly with a Type-C OTG data cable';

  @override
  String get connectUsbMenuTitle => 'Camera USB Mode';

  @override
  String get connectUsbMenuSub =>
      'Camera Menu -> USB Connection -> Set to MTP/PTP';

  @override
  String get connectUsbHostStatus => 'USB Host Status';

  @override
  String get connectUsbHostConnected => 'Wired Connected';

  @override
  String get connectUsbHostWaiting => 'Waiting for Device';

  @override
  String get connectUsbChecking => 'Checking USB...';

  @override
  String get connectUsbRefresh => 'Refresh USB Devices';

  @override
  String get connectUsbEmptyHint =>
      'No USB camera detected. Ensure the OTG cable is connected, the camera is powered on, and PTP mode is enabled.';

  @override
  String get connectUsbPermissionGrantedSuffix => ' · Authorized';

  @override
  String get connectUsbPermissionNeededSuffix => ' · Needs Permission';

  @override
  String get statusCameraDisconnected => 'Camera Disconnected';

  @override
  String get statusSdCard => 'SD Card';

  @override
  String get statusTapToConnect => 'Tap to Connect';

  @override
  String get galleryTabCamera => 'Camera Photos';

  @override
  String galleryTabExportedCount(int count) {
    return 'Exported ($count)';
  }

  @override
  String get galleryTabExportedPhone => 'Exported (Phone Album)';

  @override
  String get galleryFilterAll => 'All';

  @override
  String get galleryFilterUnsynced => 'Unsynced';

  @override
  String get galleryFilterSynced => 'Synced';

  @override
  String get gallerySlotSelectTitle => 'Select Card Slot';

  @override
  String get gallerySlotAllMerged => 'All Storage (Merged)';

  @override
  String get gallerySlot1 => 'Slot 1';

  @override
  String get gallerySlot2 => 'Slot 2';

  @override
  String get galleryCollageButton => 'Collage';

  @override
  String get galleryTransferCenterTooltip => 'Transfers';

  @override
  String get galleryRefreshCardTooltip => 'Refresh Storage Card';

  @override
  String get galleryRefreshExportedTooltip => 'Refresh Exported Album';

  @override
  String get galleryShootAndTransferBanner =>
      'Shoot & Transfer active: originals sync automatically on shutter release';

  @override
  String get galleryEnumeratingStorage =>
      'Enumerating camera storage files (0x1007)...';

  @override
  String get galleryEmptyCameraPhotos =>
      'No photos detected on camera or still reading...';

  @override
  String galleryEmptyFilterPhotos(String filter) {
    return 'No photos under filter \"$filter\"';
  }

  @override
  String get galleryReadyFooterHint =>
      'Ready: configure network and cache parameters in Settings';

  @override
  String get galleryLocalMissingFallbackToast =>
      'Local file missing or unreadable; loading from camera instead';

  @override
  String get galleryLoadingHighResTitle => 'Loading High-Resolution Photo';

  @override
  String galleryLoadingHighResBody(String size) {
    return 'Transferring original ($size) from camera for full-quality preview and watermark...';
  }

  @override
  String galleryLoadFailedToast(String error) {
    return 'Failed to load camera photos: $error';
  }

  @override
  String galleryEnqueuedToast(int count) {
    return 'Added to transfer queue: $count file(s)';
  }

  @override
  String get galleryCollageNeed2To9 =>
      'Select 2–9 photos before starting a collage';

  @override
  String get galleryCollageMax9 => 'Collage supports up to 9 photos';

  @override
  String get galleryCollageNeedJpeg =>
      'Collage requires at least 2 JPEG photos (RAW / video not supported)';

  @override
  String get galleryCollageInsufficientCancelled =>
      'Fewer than 2 usable photos; collage cancelled';

  @override
  String get galleryCollageEnterTitle => 'Enter Collage';

  @override
  String galleryCollageDownloadPrompt(
      int missing, String reusablePart, String skippedPart) {
    return 'Collage requires downloading $missing photo(s) first$reusablePart$skippedPart. Collage will open automatically once finished.';
  }

  @override
  String galleryCollageReusablePart(int count) {
    return ', $count already cached locally';
  }

  @override
  String galleryCollageSkippedPart(int count) {
    return ', $count RAW/video skipped';
  }

  @override
  String get galleryConfirmDownload => 'Download Now';

  @override
  String get galleryExportFormatTitle => 'Choose Export Format';

  @override
  String galleryExportFormatPrompt(int count) {
    return 'The $count selected photo(s) include RAW + JPEG pairs. How would you like to export?';
  }

  @override
  String get galleryExportBothTitle => 'Export All (RAW + JPEG)';

  @override
  String get galleryExportBothSub =>
      'Keep full-quality RAW negatives along with camera JPEGs';

  @override
  String get galleryExportJpegOnlyTitle => 'JPEG Only (Fast Share)';

  @override
  String get galleryExportJpegOnlySub =>
      'Transfer camera JPEGs only for faster speed and smaller storage use';

  @override
  String galleryExportBatchSuccessToast(int count) {
    return 'Exported $count photo(s) to phone album (/DCIM/Zync)';
  }

  @override
  String get galleryExportingModalTitle => 'Exporting Photos to Phone';

  @override
  String get galleryExportingSocketNotice =>
      'Exclusive transfer channel active to prevent socket conflicts.';

  @override
  String galleryExportingSingleSize(String size) {
    return 'File size: $size';
  }

  @override
  String galleryExportingBatchProgress(int current, int total) {
    return 'Batch progress: $current / $total';
  }

  @override
  String get galleryExportingSavePath =>
      'Save path: /DCIM/Zync (visible in system gallery)';

  @override
  String get galleryCancelRemainingTasks => 'Cancel Remaining';

  @override
  String get galleryDeleteLocalOnlyTitle => 'Delete Local Only';

  @override
  String get galleryDeleteLocalOnlySub =>
      'Remove downloaded copies on phone; camera card stays untouched';

  @override
  String get galleryDeleteBothTitle => 'Delete Local + Camera';

  @override
  String get galleryDeleteBothSub =>
      'Delete from camera card first, then remove local copy';

  @override
  String galleryDeleteGroupsTitle(int count) {
    return 'Delete $count Media Group(s)';
  }

  @override
  String get galleryDeleteGroupsPrompt =>
      'Choose deletion scope. RAW+JPG pairs are handled together.';

  @override
  String get galleryConfirmDeleteTitle => 'Confirm Delete';

  @override
  String galleryConfirmDeleteBothBody(int count) {
    return 'Delete $count media group(s) from both camera card and local album.';
  }

  @override
  String galleryConfirmDeleteLocalBody(int count) {
    return 'Delete $count media group(s) from local album only (camera card kept).';
  }

  @override
  String get galleryIrreversibleHint => 'This action cannot be undone.';

  @override
  String get galleryDontAskAgain => 'Don\'t ask again';

  @override
  String galleryDeletedGroupsToast(int count) {
    return 'Processed $count media group(s)';
  }

  @override
  String galleryDeletedGroupsPartialLocalFailToast(
      int handled, int failed, int localFailed) {
    return 'Processed $handled group(s), $failed failed ($localFailed deleted on camera but failed locally)';
  }

  @override
  String galleryDeletedGroupsFailToast(int handled, int failed) {
    return 'Processed $handled group(s), $failed failed; failed items remain selected';
  }

  @override
  String gallerySelectionCameraSummary(int count, String size) {
    return '$count group(s) selected · Size $size';
  }

  @override
  String get galleryLongPressSelectHint =>
      'Long-press a photo to enter multi-select, then choose photos to sync';

  @override
  String get gallerySyncToPhoneButton => 'Sync to Phone';

  @override
  String gallerySelectionLocalSummary(int count, String size) {
    return '$count selected · $size';
  }

  @override
  String galleryDeletedLocalToast(int count) {
    return 'Deleted $count local photo(s)';
  }

  @override
  String galleryDeletedLocalPartialToast(int ok, int failed) {
    return 'Deleted $ok, $failed failed; failed items remain selected';
  }

  @override
  String get galleryScanningExported => 'Scanning local exported photos...';

  @override
  String get galleryEmptyExportedTitle => 'No Exported Photos Yet';

  @override
  String get galleryEmptyExportedSubtitle =>
      'Photos transferred from your camera or exported in the Watermark Studio will appear here for offline viewing, grading, and sharing.';

  @override
  String get galleryRefreshPhoneAlbum => 'Refresh Phone Album';

  @override
  String galleryExportedHeaderCount(int count) {
    return 'Phone Zync Album · $count exported';
  }

  @override
  String get galleryBadgeExported => 'Exported';

  @override
  String get galleryBadgePartial => 'Partial';

  @override
  String get galleryBadgeOverwrite => 'Overwrite';

  @override
  String get galleryBadgeSaveAs => 'Save Copy';

  @override
  String get galleryRawDecodeFailedToast =>
      'RAW decode failed; please verify the file is NEF/NRW';

  @override
  String get galleryStreamingVideoToast =>
      'Streaming video to local editing cache…';

  @override
  String get galleryVideoDownloadFailedToast =>
      'Video download failed; check connection and retry';

  @override
  String get galleryPhotoInfoTitle => 'Photo Info';

  @override
  String get galleryPreviewLoadingOriginal => 'Preview · Loading original…';

  @override
  String get galleryLoadingOriginalShort => 'Loading original…';

  @override
  String get galleryCaptureParamsTitle => 'Exposure & Gear';

  @override
  String get galleryExifShutter => 'Shutter';

  @override
  String get galleryExifAperture => 'Aperture';

  @override
  String get galleryExifFocal => 'Focal Length';

  @override
  String get galleryExifCamera => 'Camera';

  @override
  String get galleryExifLens => 'Lens';

  @override
  String get galleryActionWatermarkGrade => 'Watermark / Grade';

  @override
  String get galleryActionProRawGrade => 'RAW Grade';

  @override
  String get galleryNoPhotos => 'No photos';

  @override
  String get galleryActionGradeShort => 'Grade';

  @override
  String get galleryDeleteSingleTitle => 'Delete This Photo?';

  @override
  String galleryDeleteSingleBody(String name) {
    return 'Delete $name from phone album (camera card unaffected). This cannot be undone.';
  }

  @override
  String get galleryDeleteFailedToast => 'Delete failed, please try again';

  @override
  String galleryOpenEditorFailedToast(String error) {
    return 'Failed to open editor: $error';
  }

  @override
  String get galleryRawNoEmbeddedPreviewToast =>
      'This RAW file has no embedded preview for color grading';

  @override
  String galleryLocalUnreadableToast(String error) {
    return 'Cannot read local photo: $error';
  }

  @override
  String get transferCenterTitle => 'Transfers';

  @override
  String get transferEmptyTitle => 'No Transfer Tasks';

  @override
  String get transferEmptySubtitle =>
      'Long-press photos in Camera Roll to sync, or enable Shoot & Transfer';

  @override
  String transferActiveCount(int count) {
    return 'Downloading $count';
  }

  @override
  String transferQueuedCount(int count) {
    return 'Queued $count';
  }

  @override
  String transferFailedCount(int count) {
    return 'Failed $count';
  }

  @override
  String get transferPausedTag => 'Paused';

  @override
  String get transferResumeAll => 'Resume All';

  @override
  String get transferPauseAll => 'Pause All';

  @override
  String get transferRetryFailed => 'Retry Failed';

  @override
  String get transferClearCompleted => 'Clear Completed';

  @override
  String get transferStatusQueued => 'Queued';

  @override
  String transferStatusDownloadingPct(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get transferStatusCompleted => 'Completed';

  @override
  String transferStatusFailedReason(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get transferStatusCancelled => 'Cancelled';

  @override
  String get editorTitle => 'Photo Editor';

  @override
  String editorSaveFailedToast(String error) {
    return 'Save failed: $error';
  }

  @override
  String get editorSaveSheetTitle => 'Save Edited Photo';

  @override
  String get editorSaveSheetSub =>
      'Overwriting replaces the original file; saving as new creates a separate copy.';

  @override
  String get editorOverwriteTitle => 'Overwrite Original';

  @override
  String get editorOverwriteSub =>
      'Replace existing photo (automatically saves as copy if overwrite fails)';

  @override
  String get editorSaveAsNewTitle => 'Save as New File';

  @override
  String get editorSaveAsNewSub => 'Keep original and create a new _edit file';

  @override
  String get editorOverwriteAndSaveBothFailed =>
      'Both overwrite and save-as-new failed';

  @override
  String get editorSaveAsFailed => 'Save as new failed';

  @override
  String get editorOverwriteFallbackToast =>
      'Overwrite unsuccessful; original kept and result saved as new file';

  @override
  String get editorOverwrittenToast => 'Original overwritten';

  @override
  String get editorSavedAsNewToast => 'Saved as new file';

  @override
  String get editorPreparingPreview => 'Preparing edit preview…';

  @override
  String get editorNoPhotoSelected => 'No photo selected';

  @override
  String get editorComparingHoldHint =>
      'Comparing original · Release to return';

  @override
  String get editorRotateLeft90 => 'Rotate Left 90°';

  @override
  String get editorRotateRight90 => 'Rotate Right 90°';

  @override
  String get editorResetAngle => 'Reset Angle';

  @override
  String get editorFlipHorizontal => 'Flip Horizontal';

  @override
  String get editorFlipVertical => 'Flip Vertical';

  @override
  String get editorResetDistortion => 'Reset Distortion';

  @override
  String get editorToolRotate => 'Rotate';

  @override
  String get editorToolFlip => 'Flip';

  @override
  String get editorToolPerspective => 'Perspective';

  @override
  String get editorToolDistortion => 'Distortion';

  @override
  String get editorToolFreeTransform => 'Transform';

  @override
  String get editorToolCrop => 'Crop';

  @override
  String editorPerspectiveHorizontal(int value) {
    return 'Horizontal $value';
  }

  @override
  String editorPerspectiveVertical(int value) {
    return 'Vertical $value';
  }

  @override
  String get editorTransformScale => 'Scale';

  @override
  String get editorTransformPanX => 'Horizontal Pan';

  @override
  String get editorTransformPanY => 'Vertical Pan';

  @override
  String get editorCropAspectRatio => 'Aspect Ratio';

  @override
  String get histogramTitle => 'Histogram';

  @override
  String get toneBlacks => 'Blacks';

  @override
  String get toneShadows => 'Shadows';

  @override
  String get toneExposure => 'Exposure';

  @override
  String get toneHighlights => 'Highlights';

  @override
  String get toneWhites => 'Whites';

  @override
  String get presetTitle => 'Color Presets';

  @override
  String get presetTabBuiltin => 'Built-in';

  @override
  String get presetTabMine => 'My Presets';

  @override
  String get presetScopeGlobal => 'Editing: Global Grade';

  @override
  String get presetScopeClip => 'Editing: Current Clip Grade';

  @override
  String get presetSaveNew => 'Save as New Preset';

  @override
  String get presetSaveDialogTitle => 'Save Preset';

  @override
  String get presetSearchHint => 'Search presets';

  @override
  String get presetSavedToast => 'Preset saved';

  @override
  String presetImportedToast(int count) {
    return 'Imported $count preset(s)';
  }

  @override
  String get presetImportFailedToast => 'Failed to read preset file';

  @override
  String get presetExportFailedToast => 'Export failed';

  @override
  String get presetExportedToast => 'Preset exported to Zync/exports';

  @override
  String get presetApplyAction => 'Apply';

  @override
  String get presetEmptyMatch => 'No matching presets';

  @override
  String get presetNoAdjustments => 'No adjustments';

  @override
  String get presetUnnamed => 'Untitled Preset';

  @override
  String get videoReadMetaFailed => 'Cannot read video metadata';

  @override
  String get videoUnsupportedCodec =>
      'Cannot play this video; verify codec support on device';

  @override
  String get videoGeneratingProxyToast =>
      'Generating 4s grade/LUT preview proxy…';

  @override
  String get videoProxyFailedToast =>
      'Failed to generate grade preview; check device codec support';

  @override
  String get videoProxyReadyToast =>
      'Grade preview ready; toggle Original/Graded in top-right of preview';

  @override
  String get videoExportFailedToast =>
      'Video export failed; check device encoder capabilities';

  @override
  String get videoExportSaveAlbumFailedToast =>
      'Export finished, but saving to system gallery failed';

  @override
  String get videoExportSuccessToast => 'Video exported to DCIM/Zync';

  @override
  String get videoGeneratePreviewTooltip => 'Generate Grade Preview';

  @override
  String get videoRefreshGeneratePreview => 'Generate / Refresh Preview';

  @override
  String get videoExportVideoAction => 'Export Video';

  @override
  String get videoGeneratingProxyOverlay => 'Generating video preview proxy…';

  @override
  String get videoSkipProxyUseOriginal => 'Skip proxy and use original video';

  @override
  String get videoBadge4sProxy => '4s Grade Proxy';

  @override
  String get videoBadgeOriginalPreview =>
      'Original Preview · Grade/LUT applied on export';

  @override
  String get videoBadgePreviewStale => 'Preview Outdated';

  @override
  String get videoToggleGradedPreview => 'Graded';

  @override
  String get videoToggleOriginalPreview => 'Original';

  @override
  String get videoExitFullscreen => 'Exit Fullscreen';

  @override
  String get videoEnterFullscreen => 'Fullscreen Preview';

  @override
  String get videoTabTrim => 'Trim';

  @override
  String get videoTabGrade => 'Grade';

  @override
  String get videoTabAudio => 'Audio';

  @override
  String get videoTabScopes => 'Scopes';

  @override
  String get videoTimelineClipsHeader => 'Timeline Clips';

  @override
  String get videoAddLocalClipTooltip => 'Add Local Video Clip';

  @override
  String videoClipIndexLabel(int index) {
    return 'Clip $index';
  }

  @override
  String get videoMoveClipEarlier => 'Move Clip Earlier';

  @override
  String get videoMoveClipLater => 'Move Clip Later';

  @override
  String get videoTrimRangeLabel => 'Trim Range';

  @override
  String get videoSplitClipAction => 'Split';

  @override
  String get videoDeleteClipAction => 'Delete Clip';

  @override
  String videoChapterDefaultTitle(int index) {
    return 'Chapter $index';
  }

  @override
  String get videoAddChapterButton => 'Add Chapter';

  @override
  String get videoChapterNavHeader => 'Chapter Navigation';

  @override
  String get videoGlobalGradeTitle => 'Global Grade';

  @override
  String get videoGlobalGradeOnSub => 'Applied across all timeline clips';

  @override
  String get videoGlobalGradeOffSub => 'Applied to current clip only';

  @override
  String get videoGlobalGradeHint =>
      'Global grade is applied before per-clip adjustments; keyframes remain per clip.';

  @override
  String get videoKeyframeParamLabel => 'Keyframe Parameter';

  @override
  String get videoAddKeyframeButton => 'Add Keyframe';

  @override
  String get videoKeyframeListHeader => 'Keyframes';

  @override
  String get videoPresetEntryTitle =>
      'Color Presets: Save / Apply / Import & Export';

  @override
  String get videoCopiedGlobalGradeToast => 'Copied global grade';

  @override
  String get videoCopiedClipGradeToast => 'Copied current clip grade';

  @override
  String get videoCopyGradeAction => 'Copy Grade';

  @override
  String get videoPasteGradeAction => 'Paste Grade';

  @override
  String get videoRefresh4sPreview => 'Refresh 4s Preview';

  @override
  String get videoGenerate4sPreview => 'Generate 4s Preview';

  @override
  String videoGlobalGradeStatusChip(String status) {
    return 'Global Grade: $status';
  }

  @override
  String get videoStatusEnabled => 'Enabled';

  @override
  String videoKeyframeCountChip(int count) {
    return 'Keyframes: $count';
  }

  @override
  String videoWheelHue(String wheel) {
    return '$wheel Hue';
  }

  @override
  String videoWheelSaturation(String wheel) {
    return '$wheel Saturation';
  }

  @override
  String videoWheelLuma(String wheel) {
    return '$wheel Luma';
  }

  @override
  String get videoCurveLinear => 'Linear';

  @override
  String get videoCurveEaseInOut => 'Ease In/Out';

  @override
  String get videoLutGlobalTitle => 'Global 3D LUT';

  @override
  String get videoLutClipTitle => 'Current Clip 3D LUT';

  @override
  String get videoLutPathHint => '.cube / PNG LUT file path';

  @override
  String get videoPickLutTooltip => 'Choose LUT File';

  @override
  String get videoApplyLutAction => 'Apply LUT';

  @override
  String get videoLutIntensityLabel => 'LUT Intensity';

  @override
  String get videoColorUnlabeled => 'Unlabeled';

  @override
  String videoSourceColorLabel(String label) {
    return 'Source Color: $label';
  }

  @override
  String videoHdrToneMapHint(String label) {
    return 'HDR source detected ($label). Export tone-maps to SDR Rec.709; pair N-Log with a LUT.';
  }

  @override
  String get videoSdrSourceHint =>
      'SDR source: uses current grade and LUT directly without extra HDR tone mapping.';

  @override
  String get videoAudioMute => 'Mute Audio';

  @override
  String get videoAudioVolume => 'Volume';

  @override
  String get videoAudioFadeIn => 'Fade In (s)';

  @override
  String get videoAudioFadeOut => 'Fade Out (s)';

  @override
  String get videoExportSettingsHeader => 'Export Settings';

  @override
  String videoHwHevcStatus(String status) {
    return 'Hardware HEVC Decode: $status';
  }

  @override
  String get videoExport4k60Note =>
      '4K/60 is best-effort; if unsupported by the device encoder, export fails safely and keeps the original.';

  @override
  String get videoNoHevc10BitWarning =>
      'No HEVC Main10 hardware decoder detected; 10-bit N-Log/HLG may not preview. Test a 4s preview before exporting.';

  @override
  String get videoCodecLabel => 'Codec';

  @override
  String get videoCodecH264 => 'H.264 (Best Compatibility)';

  @override
  String get videoCodecHevc => 'HEVC (Smaller File)';

  @override
  String get videoCodecHevcUnsupported => 'HEVC (Unsupported)';

  @override
  String get videoResolutionLabel => 'Resolution';

  @override
  String get videoFpsLabel => 'Frame Rate';

  @override
  String get videoBitrateLabel => 'Bitrate';

  @override
  String get videoBitrate20 => 'Standard 20 Mbps';

  @override
  String get videoBitrate40 => 'High 40 Mbps';

  @override
  String get videoBitrate80 => 'Pro 80 Mbps';

  @override
  String videoExportingProgressHint(int percent) {
    return 'Exporting $percent% · Keep Zync in the foreground';
  }

  @override
  String get videoCancelExport => 'Cancel Export';

  @override
  String get videoExportToDcimButton => 'Export to DCIM/Zync';

  @override
  String get scopeTitle => 'Video Scopes';

  @override
  String get scopeCaptureFrameTooltip => 'Capture Current Frame';

  @override
  String get scopeWaveform => 'Waveform';

  @override
  String get scopeVectorscope => 'Vectorscope';

  @override
  String get scopeAnalyzing => 'Analyzing current frame…';

  @override
  String get scopeEmptyHint =>
      'Tap refresh in top-right to capture current frame';

  @override
  String get scopeLumaHistogram => 'Luma Histogram';

  @override
  String get scopePeak => 'Peak';

  @override
  String get scopeAverage => 'Avg';

  @override
  String get scopeBlackLevel => 'Black';

  @override
  String get scopeHighlightClip => 'Highlight Clip';

  @override
  String get scopeShadowClip => 'Shadow Clip';

  @override
  String get wmStudioTitle => 'Watermark Studio';

  @override
  String get wmPickFromAlbumTooltip => 'Pick from Phone Album';

  @override
  String get wmStyleSettingsTooltip =>
      'Watermark Settings (Style / Content / Text / Logo)';

  @override
  String get wmExportQualityTitle => 'Export Quality';

  @override
  String wmExportQualityMenuLabel(String label, int quality) {
    return 'Export Quality: $label (q$quality)';
  }

  @override
  String get exportQualityOriginal => 'Original Quality';

  @override
  String get exportQualityStandard => 'Standard';

  @override
  String get exportQualityCompact => 'Compact Size';

  @override
  String get wmSaveHighResTooltip => 'Save High-Res Photo to Album';

  @override
  String get wmShowingOriginalBadge => 'Showing Original';

  @override
  String get wmHoldToCompareHint => 'Hold to Compare';

  @override
  String get wmPickPhotoEmptyPrompt =>
      'Select a local photo to grade and add a watermark';

  @override
  String get wmEditExifTag => 'Edit EXIF';

  @override
  String get wmTabWatermark => 'Watermark';

  @override
  String get wmTabColorGrade => 'Color Grade';

  @override
  String get wmTabPhotoEdit => 'Crop & Transform';

  @override
  String get wmPureGradeModeTitle => 'Color Grade Only Mode (No Watermark)';

  @override
  String get wmPureGradeModeSub =>
      'No border or text overlay will be added; exports at original full resolution.';

  @override
  String get wmGoToGradeButton => 'Adjust Color';

  @override
  String get wmBorderColorShort => 'Frame Color';

  @override
  String get wmTextColorShort => 'Text Color';

  @override
  String get wmDetailSettingsShort => 'More Settings';

  @override
  String get wmGradeCatTone => 'Basic Tone';

  @override
  String get wmGradeCatWb => 'White Balance';

  @override
  String get wmGradeCatPresence => 'Presence';

  @override
  String get wmGradeCatSplit => 'Split Toning';

  @override
  String get wmGradeCatFilm => 'Film Presets';

  @override
  String get wmGradeCatEffects => 'Lens & Effects';

  @override
  String get wmCurrentModeNoWatermark =>
      'Current Mode: Color Grade Only (No Watermark)';

  @override
  String wmCurrentTemplateLabel(String name) {
    return 'Current Watermark: $name';
  }

  @override
  String get wmEnableWatermarkSwitch => 'Enable Watermark';

  @override
  String get wmDisableWatermarkSwitch => 'Disable Watermark (Grade Only)';

  @override
  String wmImportedExifToast(String title) {
    return 'Imported photo and extracted EXIF ($title)';
  }

  @override
  String get wmDecodeImageFailed => 'Image decode failed';

  @override
  String wmParseImageFailed(String error) {
    return 'Image parse failed: $error';
  }

  @override
  String get wmSelectPhotoFirstHint =>
      'Select a photo from top-right album icon or import from Camera Roll first';

  @override
  String get wmRawFullDecodeFailed => 'Full-size RAW decode failed';

  @override
  String get wmSaveAlbumFailed => 'Failed to save to system album';

  @override
  String wmSavedSuccessToast(int width, int height, String sizeMb) {
    return 'Saved to album · $width×$height · ${sizeMb}MB';
  }

  @override
  String get wmViewInAlbumAction => 'View in Album';

  @override
  String wmExportFailedToast(String error) {
    return 'Export failed: $error';
  }

  @override
  String get wmExifSheetTitle => 'Fine-Tune EXIF Parameters';

  @override
  String get wmExifSheetSub =>
      'Customize displayed EXIF fields for manual lenses or photos without metadata';

  @override
  String get wmExifCameraLabel => 'Camera Model';

  @override
  String get wmExifCameraHint => 'e.g. Z 30, Z 8, Z fc';

  @override
  String get wmExifLensLabel => 'Lens Model';

  @override
  String get wmExifLensHint => 'e.g. NIKKOR Z 40mm f/2';

  @override
  String get wmExifApertureLabel => 'Aperture';

  @override
  String get wmExifApertureHint => 'e.g. f/1.8';

  @override
  String get wmExifShutterLabel => 'Shutter Speed';

  @override
  String get wmExifShutterHint => 'e.g. 1/250s';

  @override
  String get wmExifIsoLabel => 'ISO Sensitivity';

  @override
  String get wmExifIsoHint => 'e.g. ISO 100';

  @override
  String get wmExifFocalLabel => 'Focal Length';

  @override
  String get wmExifFocalHint => 'e.g. 40mm';

  @override
  String get wmExifDateLabel => 'Capture Time';

  @override
  String get wmExifDateHint => 'e.g. 2026.10.06 14:32';

  @override
  String get wmExifApplyButton => 'Apply Parameters';

  @override
  String get wmSettingsSheetTitle => 'Watermark Settings';

  @override
  String get wmSettingsSheetSub =>
      'Colors, font sizes, spacing, and toggles are saved automatically; custom Logo is kept for this session.';

  @override
  String get wmLogoSectionTitle => 'Logo Overlay';

  @override
  String get wmLogoReadFailedToast => 'Failed to read Logo image';

  @override
  String get wmLogoPickButton => 'Select Logo';

  @override
  String get wmLogoChangeButton => 'Change Logo';

  @override
  String get wmLogoSizeLabel => 'Logo Size';

  @override
  String get wmLogoOpacityLabel => 'Logo Opacity';

  @override
  String get wmSizeSmall => 'S';

  @override
  String get wmSizeMedium => 'M';

  @override
  String get wmSizeLarge => 'L';

  @override
  String get wmOpacityOpaque => '100%';

  @override
  String get wmOpacitySemi => '65%';

  @override
  String get wmOpacityLight => '35%';

  @override
  String get wmLogoPositionLabel => 'Logo Position';

  @override
  String get adjExposure => 'Exposure';

  @override
  String get adjExposureDesc =>
      'Adjust overall image brightness (-2EV to +2EV)';

  @override
  String get adjContrast => 'Contrast';

  @override
  String get adjContrastDesc =>
      'Increase or soften tonal separation between light and dark';

  @override
  String get adjHighlights => 'Highlights';

  @override
  String get adjHighlightsDesc =>
      'Recover bright highlight detail or boost luminous areas';

  @override
  String get adjShadows => 'Shadows';

  @override
  String get adjShadowsDesc =>
      'Lift dark shadow detail or deepen shadow contrast';

  @override
  String get adjWhites => 'Whites';

  @override
  String get adjWhitesDesc => 'Fine-tune the white clipping point';

  @override
  String get adjBlacks => 'Blacks';

  @override
  String get adjBlacksDesc => 'Fine-tune the pure black floor';

  @override
  String get adjTemperature => 'Temperature';

  @override
  String get adjTemperatureDesc =>
      'Cooler blue to the left, warmer golden amber to the right';

  @override
  String get adjTint => 'Tint';

  @override
  String get adjTintDesc =>
      'Compensate green cast to the left or magenta to the right';

  @override
  String get adjClarity => 'Clarity';

  @override
  String get adjClarityDesc =>
      'Adjust midtone micro-contrast to emphasize structure';

  @override
  String get adjTexture => 'Texture';

  @override
  String get adjTextureDesc =>
      'Smooth skin to the left or accentuate fine surface detail to the right';

  @override
  String get adjDehaze => 'Dehaze';

  @override
  String get adjDehazeDesc => 'Cut through atmospheric haze or add dreamy mist';

  @override
  String get adjVibrance => 'Vibrance';

  @override
  String get adjVibranceDesc =>
      'Boost muted colors while protecting skin tones';

  @override
  String get adjSaturation => 'Saturation';

  @override
  String get adjSaturationDesc =>
      'Global color intensity (-100 monochrome to +100 vivid)';

  @override
  String get adjSplitToningInfo =>
      'Split Toning: tint highlights and shadows independently for cinematic warm/cool separation.';

  @override
  String get adjHighlightHue => 'Highlight Hue';

  @override
  String get adjHighlightHueDesc =>
      'Highlight tint hue (0°–360°), warm gold ~35°–45°, cyan ~195°–210°';

  @override
  String get adjHighlightSat => 'Highlight Saturation';

  @override
  String get adjHighlightSatDesc =>
      'Strength of highlight color tint (0%–100%)';

  @override
  String get adjShadowHue => 'Shadow Hue';

  @override
  String get adjShadowHueDesc =>
      'Shadow tint hue (0°–360°), cool teal ~200°–220°, vintage magenta ~300°–320°';

  @override
  String get adjShadowSat => 'Shadow Saturation';

  @override
  String get adjShadowSatDesc => 'Strength of shadow color tint (0%–100%)';

  @override
  String get adjMidtones => 'Midtones';

  @override
  String get adjSharpening => 'Sharpening';

  @override
  String get adjNoiseReduction => 'Noise Reduction';

  @override
  String get adjLensDistortion => 'Lens Distortion';

  @override
  String get adjLensVignette => 'Lens Vignette';

  @override
  String get adjLensVignetteDesc =>
      'Darken corners to the right for cinema vignette, or lighten to the left';

  @override
  String get adjChromaticAberration => 'Chromatic Aberration';

  @override
  String get adjFilmGrain => 'Film Grain';

  @override
  String get adjFilmGrainDesc =>
      'Simulate organic silver-halide film grain texture';

  @override
  String get adjToneCurve => 'Curve';

  @override
  String get adjColorWheel => 'Wheels';

  @override
  String wmFilterAllCount(int count) {
    return 'All ($count)';
  }

  @override
  String wmRecipeSummaryPrefix(String summary) {
    return 'Camera Recipe: $summary';
  }

  @override
  String get wmPresetIntensity => 'Preset Intensity';

  @override
  String get wmProRawSectionEntry =>
      'Pro Parameters: LUT / Denoise / Sharpen / Lens Correction';

  @override
  String wmLoadedFilterSlidersToast(String name) {
    return 'Loaded [$name] parameters into sliders for fine-tuning';
  }

  @override
  String wmLoadFilterToSlidersButton(String name) {
    return 'Load [$name] into Sliders (Fine-Tune)';
  }

  @override
  String get wmProRawSheetTitle => 'Pro RAW & Lens Parameters';

  @override
  String get wmStyleFollowTemplate => 'Follow Template';

  @override
  String get wmStylePureWhite => 'Pure White';

  @override
  String get wmStyleDeepBlack => 'Deep Black';

  @override
  String get wmStyleCream => 'Warm Cream';

  @override
  String get wmStyleNikonGold => 'Amber Gold';

  @override
  String get wmStyleCyan => 'Teal Cyan';

  @override
  String get wmStyleMagenta => 'Magenta';

  @override
  String get wmStyleDarkGrey => 'Graphite Grey';

  @override
  String get wmStyleCustomColorTitle => 'Custom Color';

  @override
  String get wmStyleColorsSection => 'Colors';

  @override
  String get wmStyleFrameBgLabel => 'Frame / Background';

  @override
  String get wmStyleTextColorLabel => 'Text Color';

  @override
  String get wmStyleAccentColorLabel => 'Accent Color';

  @override
  String get wmStyleTypographySection => 'Typography & Layout';

  @override
  String get wmStyleTitleScale => 'Title Size';

  @override
  String get wmStyleMetaScale => 'EXIF Size';

  @override
  String get wmStyleCustomTextScale => 'Custom Text Size';

  @override
  String get wmStyleLetterSpacing => 'Letter Spacing';

  @override
  String get wmStyleLineSpacing => 'Line Spacing';

  @override
  String get wmStyleLineThickness => 'Divider Weight';

  @override
  String get wmStyleMarginScale => 'Margin Ratio';

  @override
  String get wmStyleCornerRadius => 'Card Corner Radius';

  @override
  String get wmStyleOpacity => 'Opacity';

  @override
  String get wmStyleFontFamily => 'Font Style';

  @override
  String get wmStyleFontDefault => 'Default';

  @override
  String get wmStyleFontSerif => 'Serif';

  @override
  String get wmStyleFontMono => 'Monospace';

  @override
  String get wmStyleFontCondensed => 'Condensed';

  @override
  String get wmStyleFontWeight => 'Font Weight';

  @override
  String get wmStyleWeightRegular => 'Regular';

  @override
  String get wmStyleWeightMedium => 'Medium';

  @override
  String get wmStyleWeightBold => 'Bold';

  @override
  String get wmStyleWeightBlack => 'Heavy';

  @override
  String get wmStyleContentSection => 'Displayed Info';

  @override
  String get wmStyleShowModel => 'Camera Model';

  @override
  String get wmStyleShowLens => 'Lens Model';

  @override
  String get wmStyleShowExposure => 'Exposure Settings';

  @override
  String get wmStyleShowDate => 'Capture Date';

  @override
  String get wmStyleShowDetails => 'Show Time & Full Details';

  @override
  String get wmStyleCustomTextSection => 'Custom Text';

  @override
  String get wmStyleCustomLine1Label => 'Custom Line 1';

  @override
  String get wmStyleCustomLine1Hint => 'e.g. © 2026 Your Name';

  @override
  String get wmStyleCustomLine2Label => 'Custom Line 2';

  @override
  String get wmStyleCustomLine2Hint => 'e.g. Nikon Z 30';

  @override
  String get wmStyleTextAlign => 'Text Alignment';

  @override
  String get wmStyleAlignLeft => 'Left';

  @override
  String get wmStyleAlignCenter => 'Center';

  @override
  String get wmStyleAlignRight => 'Right';

  @override
  String get wmCornerTopLeft => 'Top Left';

  @override
  String get wmCornerTopRight => 'Top Right';

  @override
  String get wmCornerBottomLeft => 'Bottom Left';

  @override
  String get wmCornerBottomRight => 'Bottom Right';

  @override
  String get collageTitle => 'Collage';

  @override
  String get collageInsufficientPhotos =>
      'Fewer than 2 usable photos for collage';

  @override
  String collageSkippedUnreadableToast(int count) {
    return 'Skipped $count unreadable photo(s)';
  }

  @override
  String get collageSaveSuccessTitle => 'Collage Saved to System Album';

  @override
  String get collageSaveSuccessBody =>
      'Saved to Pictures/Zync and ready to view in your phone gallery.';

  @override
  String get collagePreparingMaterials => 'Preparing collage photos...';

  @override
  String get collageWatermarkDragHint =>
      'Watermark template applied. Drag or pinch each cell directly to reframe.';

  @override
  String get collageTabLayout => 'Layout';

  @override
  String get collageTabWatermark => 'Watermark';

  @override
  String get collageNoWatermark => 'No Watermark';

  @override
  String get collageMethodLabel => 'Grid Style';

  @override
  String get collageAspectLabel => 'Aspect';

  @override
  String get collageBorderLabel => 'Border';

  @override
  String get collageOutputResolution => 'Output Resolution';

  @override
  String get collageFileSize => 'File Size';

  @override
  String get collageSharedWatermarkSub =>
      'Shares color, typography, and layout settings with Watermark Studio';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupPreferences => 'Preferences';

  @override
  String get settingsGroupSystem => 'System & About';

  @override
  String get settingsAppearanceTitle => 'Appearance & Display';

  @override
  String get settingsAppearanceSub => 'System, Light, or Darkroom mode';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSub => 'English · 简体中文 · 日本語';

  @override
  String get settingsCameraTitle => 'Camera Connection';

  @override
  String get settingsCameraSub => 'Default IP, port, and Wi-Fi NIC binding';

  @override
  String get settingsWirelessTitle => 'Wireless & Transfer';

  @override
  String get settingsWirelessSub => 'Keep-alive, RAW sync, and export quality';

  @override
  String get settingsKeepAliveOnShort => 'Keep-alive On';

  @override
  String get settingsKeepAliveOffShort => 'Keep-alive Off';

  @override
  String get settingsBatteryTitle => 'Battery & Transfer Protection';

  @override
  String get settingsBatterySub => 'Low-battery pause and hysteresis resume';

  @override
  String settingsThresholdValue(int threshold) {
    return '$threshold% threshold';
  }

  @override
  String get settingsLogsTitle => 'Diagnostics & Logs';

  @override
  String get settingsLogsSub => 'PTP handshake and transport diagnostics';

  @override
  String settingsLogsCountValue(int count) {
    return '$count entries';
  }

  @override
  String get settingsAboutTitle => 'About Zync';

  @override
  String get settingsAboutSub => 'Version, updates, and open-source licenses';

  @override
  String get settingsReplayOnboardingTitle => 'Welcome Guide';

  @override
  String get settingsReplayOnboardingSub =>
      'Re-open the 3-step setup guide for language, appearance, and connection';

  @override
  String get settingsAppearanceModeSection => 'Appearance Mode';

  @override
  String get settingsColorPreviewSection => 'Palette Preview';

  @override
  String get settingsColorPreviewTileTitle => 'Background / Surface / Accent';

  @override
  String get settingsConfigIpTitle => 'Configure Camera IP Address';

  @override
  String get settingsConfigIpSub =>
      'Default Nikon Z hotspot gateway is 192.168.0.1';

  @override
  String get settingsIpAddressField => 'IP Address';

  @override
  String get settingsConfigPortTitle => 'Configure PTP/IP Port';

  @override
  String get settingsConfigPortSub =>
      'Standard Nikon PTP/IP hardware port is 15740';

  @override
  String get settingsPortField => 'Port Number';

  @override
  String get settingsPtpNetworkSection => 'PTP/IP Network';

  @override
  String get settingsDefaultCameraIp => 'Default Camera IP Address';

  @override
  String get settingsPtpPortTile => 'PTP/IP Port';

  @override
  String get settingsRestoreDefaultIpTile =>
      'Restore Nikon Z Default Hotspot Preset';

  @override
  String get settingsRestoredDefaultIpToast =>
      'Restored default Nikon Z hotspot IP and port';

  @override
  String get settingsAndroidNetworkSection => 'Android Networking';

  @override
  String get settingsAutoBindTitle => 'Force Wi-Fi NIC Binding';

  @override
  String get settingsAutoBindSub =>
      'Route traffic through camera Wi-Fi even when mobile data is active';

  @override
  String get settingsKeepAliveSection => 'Session Keep-Alive';

  @override
  String get settingsKeepAliveToggleTitle =>
      'Keep Camera Wi-Fi Alive in Background';

  @override
  String get settingsHeartbeatTitle => 'PTP/IP Heartbeat Interval';

  @override
  String get settingsHeartbeatValue => '15s (Prevents camera sleep)';

  @override
  String get settingsShootTransferSection => 'Shoot & Transfer';

  @override
  String get settingsDownloadRawTitle => 'Sync RAW Files';

  @override
  String get settingsDownloadRawSub => 'Also download NEF / NRW files';

  @override
  String get settingsDeleteConfirmSection => 'Deletion & Confirmation';

  @override
  String get settingsConfirmDeleteTitle => 'Confirm Before Deleting';

  @override
  String get settingsConfirmDeleteSub =>
      'When off, selecting a deletion scope executes immediately';

  @override
  String get settingsPowerProtectionSection =>
      'Low-Battery Transfer Protection';

  @override
  String get settingsPowerProtectionToggle => 'Enable Low-Battery Protection';

  @override
  String get settingsPowerThresholdTile => 'Pause Threshold';

  @override
  String get settingsHysteresisTitle => 'Hysteresis Resume (+5%)';

  @override
  String get settingsHysteresisValue =>
      'Resumes automatically at threshold +5%';

  @override
  String get settingsActiveTransferRuleTitle => 'In-Flight File Handling';

  @override
  String get settingsActiveTransferRuleValue =>
      'Finishes current file before pausing (no truncation)';

  @override
  String get settingsLogsSection => 'Protocol Diagnostics';

  @override
  String get settingsViewLogsTile => 'View Handshake & Protocol Logs';

  @override
  String get settingsClearLogsTile => 'Clear Diagnostic Logs';

  @override
  String get settingsClearedLogsToast => 'All diagnostic logs cleared';

  @override
  String get settingsLogsViewerTitle => 'Protocol & Handshake Logs';

  @override
  String get settingsCopyAllLogsTooltip => 'Copy All Logs';

  @override
  String get settingsCopiedLogsToast => 'Copied all logs to clipboard';

  @override
  String get settingsClearLogsTooltip => 'Clear Logs';

  @override
  String get settingsLogsEmpty => 'No diagnostic logs yet';

  @override
  String get settingsVersionSection => 'Version & Updates';

  @override
  String get settingsAppVersionTile => 'App Version';

  @override
  String get settingsCheckUpdateTile => 'Check for Updates';

  @override
  String get settingsCheckUpdateValue => 'Online Check (GitHub)';

  @override
  String get settingsTechSection => 'Architecture';

  @override
  String get settingsDriverArchTile => 'Driver Stack';

  @override
  String get settingsUiSystemTile => 'Design System';

  @override
  String get settingsUiSystemValue => 'Zync Pro Darkroom Design System';

  @override
  String get settingsProjectSection => 'Project & Licenses';

  @override
  String get settingsRepoUrlTile => 'Repository';

  @override
  String get settingsOpenSourceCreditsTile => 'Open-Source Credits';

  @override
  String get settingsOpenSourceCreditsSub =>
      'Core references, protocol research, and runtime packages';

  @override
  String settingsCreditsCountValue(int count) {
    return '$count items';
  }

  @override
  String get settingsLicenseDisclaimerTitle => 'License Notice';

  @override
  String get settingsLicenseDisclaimerBody =>
      'Copyrights and licenses belong to their respective authors. Unlicensed projects are referenced solely for protocol interoperability.';

  @override
  String get settingsCreditsCoreGroup => 'Core Projects & Protocol References';

  @override
  String get settingsCreditsRuntimeGroup => 'Runtime & Foundation Libraries';

  @override
  String get settingsAppLicenseTile => 'Application License';

  @override
  String get settingsCannotOpenUrlToast => 'Unable to open repository URL';

  @override
  String get updateDefaultChangelog => 'Bug fixes and stability improvements.';

  @override
  String get updateCheckingToast => 'Checking for updates...';

  @override
  String get updateCheckFailedTitle => 'Update Check Failed';

  @override
  String get updateCheckFailedBody =>
      'Unable to reach the update server. Check your internet connection or visit GitHub Releases.';

  @override
  String get updateUpToDateTitle => 'Up to Date';

  @override
  String updateUpToDateBody(String version, String source) {
    return 'Zync v$version is already the latest release.\nSource: $source';
  }

  @override
  String get updateCheckErrorTitle => 'Update Error';

  @override
  String get updateOpenWebsite => 'Open GitHub';

  @override
  String get updatePreparing => 'Preparing...';

  @override
  String get updateInstallerFailedToast =>
      'Could not launch installer. Check install-unknown-apps permission or download via browser.';

  @override
  String get updateBrowserDownload => 'Browser Download';

  @override
  String updateSkippedVersionToast(String version) {
    return 'Skipped v$version; will not prompt again on startup';
  }

  @override
  String get updateNewVersionTitle => 'New Version Available';

  @override
  String get updateSourceGithub => 'GitHub Release';

  @override
  String get updateChangelogHeader => 'What\'s New';

  @override
  String updatePackageSizeLabel(String size) {
    return 'Package size: $size';
  }

  @override
  String updateDownloadingPct(String percent) {
    return 'Downloading: $percent%';
  }

  @override
  String get updateSkipThisVersion => 'Skip Version';

  @override
  String get updateLater => 'Later';

  @override
  String get updateInstallNow => 'Install Now';

  @override
  String get updateDownloadAndInstall => 'Download & Install';

  @override
  String get updateOpenInBrowserTooltip => 'Download in Browser';

  @override
  String get updateSha256MismatchError =>
      'APK SHA-256 verification failed; installation aborted';

  @override
  String get hubTitle => 'Studio Hub';

  @override
  String get hubBentoQuickTransferTitle => 'Quick Transfer';

  @override
  String get hubBentoQuickTransferSub =>
      'Browse and sync camera photos to phone';

  @override
  String get hubBentoWatermarkTitle => 'Watermark Studio';

  @override
  String get hubBentoWatermarkSub => 'Frames, photocard & film color grading';

  @override
  String get hubBentoCollageTitle => 'Collage Studio';

  @override
  String get hubBentoCollageSub => 'Multi-photo layout storytelling';

  @override
  String get hubBentoTransfersTitle => 'Transfers';

  @override
  String get hubBentoTransfersIdle => 'Queue idle';

  @override
  String hubBentoTransfersActive(int count) {
    return '$count tasks in progress';
  }

  @override
  String get hubRecentPhotosTitle => 'Recent Photos';

  @override
  String get hubRecentPhotosEmpty => 'No recent photos';

  @override
  String get hubShootAndTransferQuick => 'Auto-Transfer';

  @override
  String get hubHelpGuideTooltip => 'Connection guide';

  @override
  String get hubGuideTitle => 'Camera Connection Guide';

  @override
  String get hubGuideWifiTitle => 'Wi-Fi Direct Connection';

  @override
  String get hubGuideWifiBody =>
      '1. Turn on \"Connect to smart device\" or Wi-Fi mode in camera menu\n2. Join camera hotspot in phone Wi-Fi settings (e.g., NIKON_...)\n3. Return here and tap \"Connect Now\" to establish PTP/IP session';

  @override
  String get hubGuideUsbTitle => 'USB OTG Connection';

  @override
  String get hubGuideUsbBody =>
      '1. Connect phone and camera via USB-C or OTG adapter\n2. Power on the camera\n3. Grant USB permission when prompted and tap \"Connect Now\"';

  @override
  String get hubGuideClose => 'Got It';

  @override
  String get connectOneTapUsb => 'Connect USB Camera';

  @override
  String get connectSelectWifi => 'Select Wi-Fi';

  @override
  String get connectQuickConnect => 'Connect Now';

  @override
  String get connectUsbDetectedHeader => 'USB Camera Detected';

  @override
  String get connectWifiDetectedHeader => 'Current Wi-Fi Network';

  @override
  String get wmDockTemplate => 'Frame Style';

  @override
  String get wmDockFilter => 'Film Preset';

  @override
  String get wmDockGrade => 'Adjustments';

  @override
  String get wmDockGeometry => 'Geometry';

  @override
  String get wmSubPalette => 'Colors & Margin';

  @override
  String get wmSubToggles => 'Display & Text';

  @override
  String get wmSubTypography => 'Typography';

  @override
  String get wmSubLogo => 'Brand Logo';

  @override
  String get wmHistogramHudTooltip => 'Histogram HUD';

  @override
  String get wmDialResetAll => 'Reset All';

  @override
  String get wmDialTransferToGrade => 'To Adjustments';

  @override
  String get wmDialSaveAsPreset => 'Save Preset';

  @override
  String get wmDialCategoryPreset => '★ Presets';

  @override
  String get wmDialPresetCustomGroup => 'My Presets';

  @override
  String get wmDialSavePresetPrompt => 'Enter preset name';

  @override
  String wmDialSavePresetSuccess(String name) {
    return 'Saved preset \"$name\"';
  }

  @override
  String get wmDialActiveLutButton => 'Choose 3D LUT File';

  @override
  String get wmDialNoLutChosen => 'No LUT file loaded';

  @override
  String get wmExportMenuTitle => 'Export Quality';

  @override
  String get galleryTabCameraCard => 'Camera Card';

  @override
  String get galleryTabExportedPhoneShort => 'Exported';

  @override
  String get galleryActionSelectAll => 'Select All';

  @override
  String get galleryActionDeselect => 'Deselect';

  @override
  String get galleryExifDetailSheetTitle => 'EXIF Details';

  @override
  String get galleryCollageDirectModeTitle => 'Select Photos for Collage (2-9)';

  @override
  String get wmViewModeListTooltip => 'Single-item list with scrollbar';

  @override
  String get wmViewModePagedTooltip => 'Adaptive height paged view';

  @override
  String get wmTabletTuneAction => 'Tune';

  @override
  String get wmTabletSectionTemplates => 'Templates';

  @override
  String get wmTabletSectionStyle => 'Style';

  @override
  String get wmTabletPagePrev => 'Prev';

  @override
  String get wmTabletPageNext => 'Next';

  @override
  String wmTabletPageIndicator(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get wmTabletPureGradeHint =>
      'Currently in pure color grade mode without watermark frame';

  @override
  String get wmTabletPureGradeAction => 'Choose Template';
}
