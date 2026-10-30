import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Zync - Nikon Z Transfer & Darkroom Studio'**
  String get appTitle;

  /// No description provided for @navConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get navConnect;

  /// No description provided for @navGallery.
  ///
  /// In en, this message translates to:
  /// **'Camera Roll'**
  String get navGallery;

  /// No description provided for @navWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark Studio'**
  String get navWatermark;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @exitConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit Zync'**
  String get exitConfirmHint;

  /// No description provided for @sidebarCollapse.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get sidebarCollapse;

  /// No description provided for @sidebarExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get sidebarExpand;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonExit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get commonExit;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get commonRedo;

  /// No description provided for @commonOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get commonOriginal;

  /// No description provided for @commonCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get commonCompare;

  /// No description provided for @commonCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get commonCustom;

  /// No description provided for @commonDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get commonDefault;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get commonUnknownError;

  /// No description provided for @commonUnknownSize.
  ///
  /// In en, this message translates to:
  /// **'Unknown size'**
  String get commonUnknownSize;

  /// No description provided for @commonSupported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get commonSupported;

  /// No description provided for @commonUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported'**
  String get commonUnsupported;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonDisabled;

  /// No description provided for @commonSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get commonSuccess;

  /// No description provided for @commonFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get commonFailed;

  /// No description provided for @commonWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get commonWarning;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get langSystem;

  /// No description provided for @langSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow device language (fallback to English)'**
  String get langSystemDesc;

  /// No description provided for @langEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEn;

  /// No description provided for @langEnSub.
  ///
  /// In en, this message translates to:
  /// **'English interface'**
  String get langEnSub;

  /// No description provided for @langZh.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get langZh;

  /// No description provided for @langZhSub.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get langZhSub;

  /// No description provided for @langJa.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get langJa;

  /// No description provided for @langJaSub.
  ///
  /// In en, this message translates to:
  /// **'Japanese interface'**
  String get langJaSub;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystemSub.
  ///
  /// In en, this message translates to:
  /// **'Switch automatically with device appearance'**
  String get themeSystemSub;

  /// No description provided for @themeLightSub.
  ///
  /// In en, this message translates to:
  /// **'Soft neutral paper surface with muted teal accent'**
  String get themeLightSub;

  /// No description provided for @themeDarkSub.
  ///
  /// In en, this message translates to:
  /// **'Neutral graphite darkroom surface for accurate color judgment'**
  String get themeDarkSub;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Enter Studio'**
  String get onboardingStart;

  /// No description provided for @onboardingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(int current, int total);

  /// No description provided for @onboardingLangTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Language'**
  String get onboardingLangTitle;

  /// No description provided for @onboardingLangSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a language to preview immediately. You can change this anytime in Settings.'**
  String get onboardingLangSubtitle;

  /// No description provided for @onboardingThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Darkroom Appearance'**
  String get onboardingThemeTitle;

  /// No description provided for @onboardingThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Crafted with a neutral graphite surface and muted teal accent so your photos stay true to color.'**
  String get onboardingThemeSubtitle;

  /// No description provided for @onboardingThemePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Live Darkroom Preview'**
  String get onboardingThemePreviewTitle;

  /// No description provided for @onboardingThemePreviewSub.
  ///
  /// In en, this message translates to:
  /// **'NIKON Z 8 · NIKKOR Z 50mm f/1.2 S · 1/500s f/1.8 ISO 100'**
  String get onboardingThemePreviewSub;

  /// No description provided for @onboardingConnTitle.
  ///
  /// In en, this message translates to:
  /// **'Direct Camera Workflow'**
  String get onboardingConnTitle;

  /// No description provided for @onboardingConnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect without cloud accounts or proprietary SDKs, browse RAW & JPEG, and finish in the studio.'**
  String get onboardingConnSubtitle;

  /// No description provided for @onboardingConnWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi PTP/IP Tethering'**
  String get onboardingConnWifiTitle;

  /// No description provided for @onboardingConnWifiDesc.
  ///
  /// In en, this message translates to:
  /// **'Join the camera Wi-Fi hotspot for wireless browsing, chunked downloads, and shoot-and-transfer.'**
  String get onboardingConnWifiDesc;

  /// No description provided for @onboardingConnUsbTitle.
  ///
  /// In en, this message translates to:
  /// **'USB OTG PTP Direct'**
  String get onboardingConnUsbTitle;

  /// No description provided for @onboardingConnUsbDesc.
  ///
  /// In en, this message translates to:
  /// **'Plug in a Type-C OTG cable in MTP/PTP mode for rock-solid wired transfer of large NEF & video files.'**
  String get onboardingConnUsbDesc;

  /// No description provided for @onboardingConnStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'16-Bit RAW, Video & Watermark Studio'**
  String get onboardingConnStudioTitle;

  /// No description provided for @onboardingConnStudioDesc.
  ///
  /// In en, this message translates to:
  /// **'Decode NEF RAW with LibRaw, grade video with 3D LUTs, and export EXIF gallery frames.'**
  String get onboardingConnStudioDesc;

  /// No description provided for @connectDetecting.
  ///
  /// In en, this message translates to:
  /// **'<Detecting...>'**
  String get connectDetecting;

  /// No description provided for @connectModeWifi.
  ///
  /// In en, this message translates to:
  /// **'Camera Wi-Fi'**
  String get connectModeWifi;

  /// No description provided for @connectModeUsb.
  ///
  /// In en, this message translates to:
  /// **'USB Wired'**
  String get connectModeUsb;

  /// No description provided for @connectModeBle.
  ///
  /// In en, this message translates to:
  /// **'BLE Lab'**
  String get connectModeBle;

  /// No description provided for @connectWifiWarnTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Wi-Fi may not be a camera hotspot'**
  String get connectWifiWarnTitle;

  /// No description provided for @connectWifiWarnBody.
  ///
  /// In en, this message translates to:
  /// **'Current network: {ssid}\nStill attempt a PTP/IP connection?'**
  String connectWifiWarnBody(String ssid);

  /// No description provided for @connectContinueAttempt.
  ///
  /// In en, this message translates to:
  /// **'Connect Anyway'**
  String get connectContinueAttempt;

  /// No description provided for @connectFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectFailedToast(String error);

  /// No description provided for @connectWifiFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}\nTip: Join the camera Wi-Fi hotspot in system settings first.'**
  String connectWifiFailedToast(String error);

  /// No description provided for @connectDisconnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from camera and released network binding'**
  String get connectDisconnectedToast;

  /// No description provided for @connectUsbScanResult.
  ///
  /// In en, this message translates to:
  /// **'Detected {total} USB camera(s), {ready} ready for PTP session'**
  String connectUsbScanResult(int total, int ready);

  /// No description provided for @connectUsbScanFailed.
  ///
  /// In en, this message translates to:
  /// **'USB scan failed: {error}'**
  String connectUsbScanFailed(String error);

  /// No description provided for @connectUsbModeSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'{name} is currently in {mode}. Switch USB mode to MTP/PTP in the camera menu and refresh.'**
  String connectUsbModeSwitchHint(String name, String mode);

  /// No description provided for @connectUsbUnsupportedDriver.
  ///
  /// In en, this message translates to:
  /// **'Current driver does not support USB connection'**
  String get connectUsbUnsupportedDriver;

  /// No description provided for @connectUsbPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'USB permission denied'**
  String get connectUsbPermissionDenied;

  /// No description provided for @connectUsbFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'USB Connection Failed'**
  String get connectUsbFailedTitle;

  /// No description provided for @connectUsbFailedToast.
  ///
  /// In en, this message translates to:
  /// **'USB connection failed: {error}'**
  String connectUsbFailedToast(String error);

  /// No description provided for @connectUsbTroubleHeader.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting:'**
  String get connectUsbTroubleHeader;

  /// No description provided for @connectUsbTroubleStep1.
  ///
  /// In en, this message translates to:
  /// **'1. Set USB mode to MTP/PTP in camera menu (not Mass Storage);'**
  String get connectUsbTroubleStep1;

  /// No description provided for @connectUsbTroubleStep2.
  ///
  /// In en, this message translates to:
  /// **'2. Use a data-capable OTG cable connected directly to your phone (avoid USB hubs);'**
  String get connectUsbTroubleStep2;

  /// No description provided for @connectUsbTroubleStep3.
  ///
  /// In en, this message translates to:
  /// **'3. Replug the cable, refresh USB devices, and try again.'**
  String get connectUsbTroubleStep3;

  /// No description provided for @connectBleStoppedToast.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth scan stopped'**
  String get connectBleStoppedToast;

  /// No description provided for @connectBleStartFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to start Bluetooth scan. Check Bluetooth & nearby device permissions.'**
  String get connectBleStartFailedToast;

  /// No description provided for @connectBlePairSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth pairing handshake initiated!'**
  String get connectBlePairSuccessToast;

  /// No description provided for @connectBleFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth connection failed: {error}'**
  String connectBleFailedToast(String error);

  /// No description provided for @connectMyCamera.
  ///
  /// In en, this message translates to:
  /// **'My Camera'**
  String get connectMyCamera;

  /// No description provided for @connectDisconnectShort.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get connectDisconnectShort;

  /// No description provided for @connectHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Zync · Nikon Z Series'**
  String get connectHeroTitle;

  /// No description provided for @connectHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pro Wireless Tethering, Transfer & Darkroom Studio for Nikon Z'**
  String get connectHeroSubtitle;

  /// No description provided for @connectStatusConnectedBanner.
  ///
  /// In en, this message translates to:
  /// **'Connected  {mode} · {endpoint}'**
  String connectStatusConnectedBanner(String mode, String endpoint);

  /// No description provided for @connectCameraBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get connectCameraBrand;

  /// No description provided for @connectCameraModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get connectCameraModel;

  /// No description provided for @connectBrowsePhotos.
  ///
  /// In en, this message translates to:
  /// **'Browse Camera Photos'**
  String get connectBrowsePhotos;

  /// No description provided for @connectLensSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Mounted Lens'**
  String get connectLensSectionTitle;

  /// No description provided for @connectLensIdentified.
  ///
  /// In en, this message translates to:
  /// **'Identified'**
  String get connectLensIdentified;

  /// No description provided for @connectLensUnread.
  ///
  /// In en, this message translates to:
  /// **'Not read'**
  String get connectLensUnread;

  /// No description provided for @connectLensFocalRange.
  ///
  /// In en, this message translates to:
  /// **'Focal Range'**
  String get connectLensFocalRange;

  /// No description provided for @connectLensCurrentFocal.
  ///
  /// In en, this message translates to:
  /// **'Focal Length'**
  String get connectLensCurrentFocal;

  /// No description provided for @connectLensCurrentAperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get connectLensCurrentAperture;

  /// No description provided for @connectDisconnectFull.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Camera & Release Network'**
  String get connectDisconnectFull;

  /// No description provided for @connectCurrentWifiLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Wi-Fi'**
  String get connectCurrentWifiLabel;

  /// No description provided for @connectRedetectWifiTooltip.
  ///
  /// In en, this message translates to:
  /// **'Re-detect Wi-Fi'**
  String get connectRedetectWifiTooltip;

  /// No description provided for @connectWifiReadyHint.
  ///
  /// In en, this message translates to:
  /// **'Connected to camera hotspot. Tap below to establish a PTP/IP session.'**
  String get connectWifiReadyHint;

  /// No description provided for @connectWifiJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Join the camera Wi-Fi hotspot in system settings first (e.g. NIKON_...)'**
  String get connectWifiJoinHint;

  /// No description provided for @connectOpenSystemWifi.
  ///
  /// In en, this message translates to:
  /// **'Open System Wi-Fi Settings'**
  String get connectOpenSystemWifi;

  /// No description provided for @connectConnectingButton.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connectConnectingButton;

  /// No description provided for @connectWifiButton.
  ///
  /// In en, this message translates to:
  /// **'Connect Camera (Wi-Fi Direct)'**
  String get connectWifiButton;

  /// No description provided for @connectBlePhoneOn.
  ///
  /// In en, this message translates to:
  /// **'Phone Bluetooth On'**
  String get connectBlePhoneOn;

  /// No description provided for @connectBlePhoneOff.
  ///
  /// In en, this message translates to:
  /// **'Phone Bluetooth Off'**
  String get connectBlePhoneOff;

  /// No description provided for @connectStateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connectStateConnected;

  /// No description provided for @connectStatePairing.
  ///
  /// In en, this message translates to:
  /// **'Pairing'**
  String get connectStatePairing;

  /// No description provided for @connectStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get connectStateDisconnected;

  /// No description provided for @connectBlePairedDevice.
  ///
  /// In en, this message translates to:
  /// **'Paired: {name}'**
  String connectBlePairedDevice(String name);

  /// No description provided for @connectBleRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Wireless Remote Shutter (ML-L7)'**
  String get connectBleRemoteTitle;

  /// No description provided for @connectBleHalfPress.
  ///
  /// In en, this message translates to:
  /// **'Half-Press AF'**
  String get connectBleHalfPress;

  /// No description provided for @connectBleFullPress.
  ///
  /// In en, this message translates to:
  /// **'Shutter Release'**
  String get connectBleFullPress;

  /// No description provided for @connectBleStopScan.
  ///
  /// In en, this message translates to:
  /// **'Stop Scanning'**
  String get connectBleStopScan;

  /// No description provided for @connectBleStartScan.
  ///
  /// In en, this message translates to:
  /// **'Scan Nearby BLE Devices'**
  String get connectBleStartScan;

  /// No description provided for @connectBleDiscoveredCount.
  ///
  /// In en, this message translates to:
  /// **'Discovered Cameras ({count})'**
  String connectBleDiscoveredCount(int count);

  /// No description provided for @connectBleDeviceMeta.
  ///
  /// In en, this message translates to:
  /// **'MAC: {address} | RSSI: {rssi} dBm'**
  String connectBleDeviceMeta(String address, int rssi);

  /// No description provided for @connectBleSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for nearby cameras and BLE devices...'**
  String get connectBleSearching;

  /// No description provided for @connectUsbSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'USB OTG Wired Connection'**
  String get connectUsbSectionTitle;

  /// No description provided for @connectUsbPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get connectUsbPrepTitle;

  /// No description provided for @connectUsbPrepSub.
  ///
  /// In en, this message translates to:
  /// **'Connect camera and phone directly with a Type-C OTG data cable'**
  String get connectUsbPrepSub;

  /// No description provided for @connectUsbMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera USB Mode'**
  String get connectUsbMenuTitle;

  /// No description provided for @connectUsbMenuSub.
  ///
  /// In en, this message translates to:
  /// **'Camera Menu -> USB Connection -> Set to MTP/PTP'**
  String get connectUsbMenuSub;

  /// No description provided for @connectUsbHostStatus.
  ///
  /// In en, this message translates to:
  /// **'USB Host Status'**
  String get connectUsbHostStatus;

  /// No description provided for @connectUsbHostConnected.
  ///
  /// In en, this message translates to:
  /// **'Wired Connected'**
  String get connectUsbHostConnected;

  /// No description provided for @connectUsbHostWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Device'**
  String get connectUsbHostWaiting;

  /// No description provided for @connectUsbChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking USB...'**
  String get connectUsbChecking;

  /// No description provided for @connectUsbRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh USB Devices'**
  String get connectUsbRefresh;

  /// No description provided for @connectUsbEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No USB camera detected. Ensure the OTG cable is connected, the camera is powered on, and PTP mode is enabled.'**
  String get connectUsbEmptyHint;

  /// No description provided for @connectUsbPermissionGrantedSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Authorized'**
  String get connectUsbPermissionGrantedSuffix;

  /// No description provided for @connectUsbPermissionNeededSuffix.
  ///
  /// In en, this message translates to:
  /// **' · Needs Permission'**
  String get connectUsbPermissionNeededSuffix;

  /// No description provided for @statusCameraDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Camera Disconnected'**
  String get statusCameraDisconnected;

  /// No description provided for @statusSdCard.
  ///
  /// In en, this message translates to:
  /// **'SD Card'**
  String get statusSdCard;

  /// No description provided for @statusTapToConnect.
  ///
  /// In en, this message translates to:
  /// **'Tap to Connect'**
  String get statusTapToConnect;

  /// No description provided for @galleryTabCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera Photos'**
  String get galleryTabCamera;

  /// No description provided for @galleryTabExportedCount.
  ///
  /// In en, this message translates to:
  /// **'Exported ({count})'**
  String galleryTabExportedCount(int count);

  /// No description provided for @galleryTabExportedPhone.
  ///
  /// In en, this message translates to:
  /// **'Exported (Phone Album)'**
  String get galleryTabExportedPhone;

  /// No description provided for @galleryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get galleryFilterAll;

  /// No description provided for @galleryFilterNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get galleryFilterNew;

  /// No description provided for @galleryFilterUnsynced.
  ///
  /// In en, this message translates to:
  /// **'Unsynced'**
  String get galleryFilterUnsynced;

  /// No description provided for @galleryFilterSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get galleryFilterSynced;

  /// No description provided for @galleryBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'NEW'**
  String get galleryBadgeNew;

  /// No description provided for @galleryBadgeViewed.
  ///
  /// In en, this message translates to:
  /// **'Viewed'**
  String get galleryBadgeViewed;

  /// No description provided for @galleryMarkAllViewed.
  ///
  /// In en, this message translates to:
  /// **'Mark All Viewed'**
  String get galleryMarkAllViewed;

  /// No description provided for @galleryMarkAllViewedDone.
  ///
  /// In en, this message translates to:
  /// **'All marked as viewed'**
  String get galleryMarkAllViewedDone;

  /// No description provided for @galleryAllViewedTip.
  ///
  /// In en, this message translates to:
  /// **'No unviewed new photos'**
  String get galleryAllViewedTip;

  /// No description provided for @galleryViewAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'View All Photos'**
  String get galleryViewAllPhotos;

  /// No description provided for @gallerySlotSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Card Slot'**
  String get gallerySlotSelectTitle;

  /// No description provided for @gallerySlotAllMerged.
  ///
  /// In en, this message translates to:
  /// **'All Storage (Merged)'**
  String get gallerySlotAllMerged;

  /// No description provided for @gallerySlot1.
  ///
  /// In en, this message translates to:
  /// **'Slot 1'**
  String get gallerySlot1;

  /// No description provided for @gallerySlot2.
  ///
  /// In en, this message translates to:
  /// **'Slot 2'**
  String get gallerySlot2;

  /// No description provided for @galleryCollageButton.
  ///
  /// In en, this message translates to:
  /// **'Collage'**
  String get galleryCollageButton;

  /// No description provided for @galleryTransferCenterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get galleryTransferCenterTooltip;

  /// No description provided for @galleryRefreshCardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Storage Card'**
  String get galleryRefreshCardTooltip;

  /// No description provided for @galleryRefreshExportedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Exported Album'**
  String get galleryRefreshExportedTooltip;

  /// No description provided for @galleryShootAndTransferBanner.
  ///
  /// In en, this message translates to:
  /// **'Shoot & Transfer active: originals sync automatically on shutter release'**
  String get galleryShootAndTransferBanner;

  /// No description provided for @galleryEnumeratingStorage.
  ///
  /// In en, this message translates to:
  /// **'Enumerating camera storage files (0x1007)...'**
  String get galleryEnumeratingStorage;

  /// No description provided for @galleryEmptyCameraPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos detected on camera or still reading...'**
  String get galleryEmptyCameraPhotos;

  /// No description provided for @galleryEmptyFilterPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos under filter \"{filter}\"'**
  String galleryEmptyFilterPhotos(String filter);

  /// No description provided for @galleryReadyFooterHint.
  ///
  /// In en, this message translates to:
  /// **'Ready: configure network and cache parameters in Settings'**
  String get galleryReadyFooterHint;

  /// No description provided for @galleryLocalMissingFallbackToast.
  ///
  /// In en, this message translates to:
  /// **'Local file missing or unreadable; loading from camera instead'**
  String get galleryLocalMissingFallbackToast;

  /// No description provided for @galleryLoadingHighResTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading High-Resolution Photo'**
  String get galleryLoadingHighResTitle;

  /// No description provided for @galleryLoadingHighResBody.
  ///
  /// In en, this message translates to:
  /// **'Transferring original ({size}) from camera for full-quality preview and watermark...'**
  String galleryLoadingHighResBody(String size);

  /// No description provided for @galleryLoadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to load camera photos: {error}'**
  String galleryLoadFailedToast(String error);

  /// No description provided for @galleryEnqueuedToast.
  ///
  /// In en, this message translates to:
  /// **'Added to transfer queue: {count} file(s)'**
  String galleryEnqueuedToast(int count);

  /// No description provided for @galleryCollageNeed2To9.
  ///
  /// In en, this message translates to:
  /// **'Select 2–9 photos before starting a collage'**
  String get galleryCollageNeed2To9;

  /// No description provided for @galleryCollageMax9.
  ///
  /// In en, this message translates to:
  /// **'Collage supports up to 9 photos'**
  String get galleryCollageMax9;

  /// No description provided for @galleryCollageNeedJpeg.
  ///
  /// In en, this message translates to:
  /// **'Collage requires at least 2 JPEG photos (RAW / video not supported)'**
  String get galleryCollageNeedJpeg;

  /// No description provided for @galleryCollageInsufficientCancelled.
  ///
  /// In en, this message translates to:
  /// **'Fewer than 2 usable photos; collage cancelled'**
  String get galleryCollageInsufficientCancelled;

  /// No description provided for @galleryCollageEnterTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter Collage'**
  String get galleryCollageEnterTitle;

  /// No description provided for @galleryCollageDownloadPrompt.
  ///
  /// In en, this message translates to:
  /// **'Collage requires downloading {missing} photo(s) first{reusablePart}{skippedPart}. Collage will open automatically once finished.'**
  String galleryCollageDownloadPrompt(
      int missing, String reusablePart, String skippedPart);

  /// No description provided for @galleryCollageReusablePart.
  ///
  /// In en, this message translates to:
  /// **', {count} already cached locally'**
  String galleryCollageReusablePart(int count);

  /// No description provided for @galleryCollageSkippedPart.
  ///
  /// In en, this message translates to:
  /// **', {count} RAW/video skipped'**
  String galleryCollageSkippedPart(int count);

  /// No description provided for @galleryConfirmDownload.
  ///
  /// In en, this message translates to:
  /// **'Download Now'**
  String get galleryConfirmDownload;

  /// No description provided for @galleryExportFormatTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Export Format'**
  String get galleryExportFormatTitle;

  /// No description provided for @galleryExportFormatPrompt.
  ///
  /// In en, this message translates to:
  /// **'The {count} selected photo(s) include RAW + JPEG pairs. How would you like to export?'**
  String galleryExportFormatPrompt(int count);

  /// No description provided for @galleryExportBothTitle.
  ///
  /// In en, this message translates to:
  /// **'Export All (RAW + JPEG)'**
  String get galleryExportBothTitle;

  /// No description provided for @galleryExportBothSub.
  ///
  /// In en, this message translates to:
  /// **'Keep full-quality RAW negatives along with camera JPEGs'**
  String get galleryExportBothSub;

  /// No description provided for @galleryExportJpegOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'JPEG Only (Fast Share)'**
  String get galleryExportJpegOnlyTitle;

  /// No description provided for @galleryExportJpegOnlySub.
  ///
  /// In en, this message translates to:
  /// **'Transfer camera JPEGs only for faster speed and smaller storage use'**
  String get galleryExportJpegOnlySub;

  /// No description provided for @galleryExportBatchSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} photo(s) to phone album (/DCIM/Zync)'**
  String galleryExportBatchSuccessToast(int count);

  /// No description provided for @galleryExportingModalTitle.
  ///
  /// In en, this message translates to:
  /// **'Exporting Photos to Phone'**
  String get galleryExportingModalTitle;

  /// No description provided for @galleryExportingSocketNotice.
  ///
  /// In en, this message translates to:
  /// **'Exclusive transfer channel active to prevent socket conflicts.'**
  String get galleryExportingSocketNotice;

  /// No description provided for @galleryExportingSingleSize.
  ///
  /// In en, this message translates to:
  /// **'File size: {size}'**
  String galleryExportingSingleSize(String size);

  /// No description provided for @galleryExportingBatchProgress.
  ///
  /// In en, this message translates to:
  /// **'Batch progress: {current} / {total}'**
  String galleryExportingBatchProgress(int current, int total);

  /// No description provided for @galleryExportingSavePath.
  ///
  /// In en, this message translates to:
  /// **'Save path: /DCIM/Zync (visible in system gallery)'**
  String get galleryExportingSavePath;

  /// No description provided for @galleryCancelRemainingTasks.
  ///
  /// In en, this message translates to:
  /// **'Cancel Remaining'**
  String get galleryCancelRemainingTasks;

  /// No description provided for @galleryDeleteLocalOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Only'**
  String get galleryDeleteLocalOnlyTitle;

  /// No description provided for @galleryDeleteLocalOnlySub.
  ///
  /// In en, this message translates to:
  /// **'Remove downloaded copies on phone; camera card stays untouched'**
  String get galleryDeleteLocalOnlySub;

  /// No description provided for @galleryDeleteBothTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local + Camera'**
  String get galleryDeleteBothTitle;

  /// No description provided for @galleryDeleteBothSub.
  ///
  /// In en, this message translates to:
  /// **'Delete from camera card first, then remove local copy'**
  String get galleryDeleteBothSub;

  /// No description provided for @galleryDeleteGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} Media Group(s)'**
  String galleryDeleteGroupsTitle(int count);

  /// No description provided for @galleryDeleteGroupsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Choose deletion scope. RAW+JPG pairs are handled together.'**
  String get galleryDeleteGroupsPrompt;

  /// No description provided for @galleryConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get galleryConfirmDeleteTitle;

  /// No description provided for @galleryConfirmDeleteBothBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} media group(s) from both camera card and local album.'**
  String galleryConfirmDeleteBothBody(int count);

  /// No description provided for @galleryConfirmDeleteLocalBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} media group(s) from local album only (camera card kept).'**
  String galleryConfirmDeleteLocalBody(int count);

  /// No description provided for @galleryIrreversibleHint.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get galleryIrreversibleHint;

  /// No description provided for @galleryDontAskAgain.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask again'**
  String get galleryDontAskAgain;

  /// No description provided for @galleryDeletedGroupsToast.
  ///
  /// In en, this message translates to:
  /// **'Processed {count} media group(s)'**
  String galleryDeletedGroupsToast(int count);

  /// No description provided for @galleryDeletedGroupsPartialLocalFailToast.
  ///
  /// In en, this message translates to:
  /// **'Processed {handled} group(s), {failed} failed ({localFailed} deleted on camera but failed locally)'**
  String galleryDeletedGroupsPartialLocalFailToast(
      int handled, int failed, int localFailed);

  /// No description provided for @galleryDeletedGroupsFailToast.
  ///
  /// In en, this message translates to:
  /// **'Processed {handled} group(s), {failed} failed; failed items remain selected'**
  String galleryDeletedGroupsFailToast(int handled, int failed);

  /// No description provided for @gallerySelectionCameraSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} group(s) selected · Size {size}'**
  String gallerySelectionCameraSummary(int count, String size);

  /// No description provided for @galleryLongPressSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a photo to enter multi-select, then choose photos to sync'**
  String get galleryLongPressSelectHint;

  /// No description provided for @gallerySyncToPhoneButton.
  ///
  /// In en, this message translates to:
  /// **'Sync to Phone'**
  String get gallerySyncToPhoneButton;

  /// No description provided for @gallerySelectionLocalSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} selected · {size}'**
  String gallerySelectionLocalSummary(int count, String size);

  /// No description provided for @galleryDeletedLocalToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} local photo(s)'**
  String galleryDeletedLocalToast(int count);

  /// No description provided for @galleryDeletedLocalPartialToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted {ok}, {failed} failed; failed items remain selected'**
  String galleryDeletedLocalPartialToast(int ok, int failed);

  /// No description provided for @galleryScanningExported.
  ///
  /// In en, this message translates to:
  /// **'Scanning local exported photos...'**
  String get galleryScanningExported;

  /// No description provided for @galleryEmptyExportedTitle.
  ///
  /// In en, this message translates to:
  /// **'No Exported Photos Yet'**
  String get galleryEmptyExportedTitle;

  /// No description provided for @galleryEmptyExportedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Photos transferred from your camera or exported in the Watermark Studio will appear here for offline viewing, grading, and sharing.'**
  String get galleryEmptyExportedSubtitle;

  /// No description provided for @galleryRefreshPhoneAlbum.
  ///
  /// In en, this message translates to:
  /// **'Refresh Phone Album'**
  String get galleryRefreshPhoneAlbum;

  /// No description provided for @galleryExportedHeaderCount.
  ///
  /// In en, this message translates to:
  /// **'Phone Zync Album · {count} exported'**
  String galleryExportedHeaderCount(int count);

  /// No description provided for @galleryBadgeExported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get galleryBadgeExported;

  /// No description provided for @galleryBadgePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get galleryBadgePartial;

  /// No description provided for @galleryBadgeOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get galleryBadgeOverwrite;

  /// No description provided for @galleryBadgeSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save Copy'**
  String get galleryBadgeSaveAs;

  /// No description provided for @galleryRawDecodeFailedToast.
  ///
  /// In en, this message translates to:
  /// **'RAW decode failed; please verify the file is NEF/NRW'**
  String get galleryRawDecodeFailedToast;

  /// No description provided for @galleryStreamingVideoToast.
  ///
  /// In en, this message translates to:
  /// **'Streaming video to local editing cache…'**
  String get galleryStreamingVideoToast;

  /// No description provided for @galleryVideoDownloadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Video download failed; check connection and retry'**
  String get galleryVideoDownloadFailedToast;

  /// No description provided for @galleryPhotoInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Info'**
  String get galleryPhotoInfoTitle;

  /// No description provided for @galleryPreviewLoadingOriginal.
  ///
  /// In en, this message translates to:
  /// **'Preview · Loading original…'**
  String get galleryPreviewLoadingOriginal;

  /// No description provided for @galleryLoadingOriginalShort.
  ///
  /// In en, this message translates to:
  /// **'Loading original…'**
  String get galleryLoadingOriginalShort;

  /// No description provided for @galleryCaptureParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Exposure & Gear'**
  String get galleryCaptureParamsTitle;

  /// No description provided for @galleryExifShutter.
  ///
  /// In en, this message translates to:
  /// **'Shutter'**
  String get galleryExifShutter;

  /// No description provided for @galleryExifAperture.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get galleryExifAperture;

  /// No description provided for @galleryExifFocal.
  ///
  /// In en, this message translates to:
  /// **'Focal Length'**
  String get galleryExifFocal;

  /// No description provided for @galleryExifCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get galleryExifCamera;

  /// No description provided for @galleryExifLens.
  ///
  /// In en, this message translates to:
  /// **'Lens'**
  String get galleryExifLens;

  /// No description provided for @galleryActionWatermarkGrade.
  ///
  /// In en, this message translates to:
  /// **'Watermark / Grade'**
  String get galleryActionWatermarkGrade;

  /// No description provided for @galleryActionProRawGrade.
  ///
  /// In en, this message translates to:
  /// **'RAW Grade'**
  String get galleryActionProRawGrade;

  /// No description provided for @galleryNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos'**
  String get galleryNoPhotos;

  /// No description provided for @galleryActionGradeShort.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get galleryActionGradeShort;

  /// No description provided for @galleryDeleteSingleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete This Photo?'**
  String get galleryDeleteSingleTitle;

  /// No description provided for @galleryDeleteSingleBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from phone album (camera card unaffected). This cannot be undone.'**
  String galleryDeleteSingleBody(String name);

  /// No description provided for @galleryDeleteFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Delete failed, please try again'**
  String get galleryDeleteFailedToast;

  /// No description provided for @galleryOpenEditorFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to open editor: {error}'**
  String galleryOpenEditorFailedToast(String error);

  /// No description provided for @galleryRawNoEmbeddedPreviewToast.
  ///
  /// In en, this message translates to:
  /// **'This RAW file has no embedded preview for color grading'**
  String get galleryRawNoEmbeddedPreviewToast;

  /// No description provided for @galleryLocalUnreadableToast.
  ///
  /// In en, this message translates to:
  /// **'Cannot read local photo: {error}'**
  String galleryLocalUnreadableToast(String error);

  /// No description provided for @transferCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transferCenterTitle;

  /// No description provided for @transferEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Transfer Tasks'**
  String get transferEmptyTitle;

  /// No description provided for @transferEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Long-press photos in Camera Roll to sync, or enable Shoot & Transfer'**
  String get transferEmptySubtitle;

  /// No description provided for @transferActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Downloading {count}'**
  String transferActiveCount(int count);

  /// No description provided for @transferQueuedCount.
  ///
  /// In en, this message translates to:
  /// **'Queued {count}'**
  String transferQueuedCount(int count);

  /// No description provided for @transferFailedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed {count}'**
  String transferFailedCount(int count);

  /// No description provided for @transferPausedTag.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get transferPausedTag;

  /// No description provided for @transferResumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume All'**
  String get transferResumeAll;

  /// No description provided for @transferPauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause All'**
  String get transferPauseAll;

  /// No description provided for @transferRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry Failed'**
  String get transferRetryFailed;

  /// No description provided for @transferClearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear Completed'**
  String get transferClearCompleted;

  /// No description provided for @transferStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get transferStatusQueued;

  /// No description provided for @transferStatusDownloadingPct.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String transferStatusDownloadingPct(int percent);

  /// No description provided for @transferStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get transferStatusCompleted;

  /// No description provided for @transferStatusFailedReason.
  ///
  /// In en, this message translates to:
  /// **'Failed: {reason}'**
  String transferStatusFailedReason(String reason);

  /// No description provided for @transferStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get transferStatusCancelled;

  /// No description provided for @editorTitle.
  ///
  /// In en, this message translates to:
  /// **'Photo Editor'**
  String get editorTitle;

  /// No description provided for @editorSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String editorSaveFailedToast(String error);

  /// No description provided for @editorSaveSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Edited Photo'**
  String get editorSaveSheetTitle;

  /// No description provided for @editorSaveSheetSub.
  ///
  /// In en, this message translates to:
  /// **'Overwriting replaces the original file; saving as new creates a separate copy.'**
  String get editorSaveSheetSub;

  /// No description provided for @editorOverwriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Overwrite Original'**
  String get editorOverwriteTitle;

  /// No description provided for @editorOverwriteSub.
  ///
  /// In en, this message translates to:
  /// **'Replace existing photo (automatically saves as copy if overwrite fails)'**
  String get editorOverwriteSub;

  /// No description provided for @editorSaveAsNewTitle.
  ///
  /// In en, this message translates to:
  /// **'Save as New File'**
  String get editorSaveAsNewTitle;

  /// No description provided for @editorSaveAsNewSub.
  ///
  /// In en, this message translates to:
  /// **'Keep original and create a new _edit file'**
  String get editorSaveAsNewSub;

  /// No description provided for @editorOverwriteAndSaveBothFailed.
  ///
  /// In en, this message translates to:
  /// **'Both overwrite and save-as-new failed'**
  String get editorOverwriteAndSaveBothFailed;

  /// No description provided for @editorSaveAsFailed.
  ///
  /// In en, this message translates to:
  /// **'Save as new failed'**
  String get editorSaveAsFailed;

  /// No description provided for @editorOverwriteFallbackToast.
  ///
  /// In en, this message translates to:
  /// **'Overwrite unsuccessful; original kept and result saved as new file'**
  String get editorOverwriteFallbackToast;

  /// No description provided for @editorOverwrittenToast.
  ///
  /// In en, this message translates to:
  /// **'Original overwritten'**
  String get editorOverwrittenToast;

  /// No description provided for @editorSavedAsNewToast.
  ///
  /// In en, this message translates to:
  /// **'Saved as new file'**
  String get editorSavedAsNewToast;

  /// No description provided for @editorPreparingPreview.
  ///
  /// In en, this message translates to:
  /// **'Preparing edit preview…'**
  String get editorPreparingPreview;

  /// No description provided for @editorNoPhotoSelected.
  ///
  /// In en, this message translates to:
  /// **'No photo selected'**
  String get editorNoPhotoSelected;

  /// No description provided for @editorComparingHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Comparing original · Release to return'**
  String get editorComparingHoldHint;

  /// No description provided for @editorRotateLeft90.
  ///
  /// In en, this message translates to:
  /// **'Rotate Left 90°'**
  String get editorRotateLeft90;

  /// No description provided for @editorRotateRight90.
  ///
  /// In en, this message translates to:
  /// **'Rotate Right 90°'**
  String get editorRotateRight90;

  /// No description provided for @editorResetAngle.
  ///
  /// In en, this message translates to:
  /// **'Reset Angle'**
  String get editorResetAngle;

  /// No description provided for @editorFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Flip Horizontal'**
  String get editorFlipHorizontal;

  /// No description provided for @editorFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Flip Vertical'**
  String get editorFlipVertical;

  /// No description provided for @editorResetDistortion.
  ///
  /// In en, this message translates to:
  /// **'Reset Distortion'**
  String get editorResetDistortion;

  /// No description provided for @editorToolRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get editorToolRotate;

  /// No description provided for @editorToolFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get editorToolFlip;

  /// No description provided for @editorToolPerspective.
  ///
  /// In en, this message translates to:
  /// **'Perspective'**
  String get editorToolPerspective;

  /// No description provided for @editorToolDistortion.
  ///
  /// In en, this message translates to:
  /// **'Distortion'**
  String get editorToolDistortion;

  /// No description provided for @editorToolFreeTransform.
  ///
  /// In en, this message translates to:
  /// **'Transform'**
  String get editorToolFreeTransform;

  /// No description provided for @editorToolCrop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get editorToolCrop;

  /// No description provided for @editorPerspectiveHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal {value}'**
  String editorPerspectiveHorizontal(int value);

  /// No description provided for @editorPerspectiveVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical {value}'**
  String editorPerspectiveVertical(int value);

  /// No description provided for @editorTransformScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get editorTransformScale;

  /// No description provided for @editorTransformPanX.
  ///
  /// In en, this message translates to:
  /// **'Horizontal Pan'**
  String get editorTransformPanX;

  /// No description provided for @editorTransformPanY.
  ///
  /// In en, this message translates to:
  /// **'Vertical Pan'**
  String get editorTransformPanY;

  /// No description provided for @editorCropAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio'**
  String get editorCropAspectRatio;

  /// No description provided for @histogramTitle.
  ///
  /// In en, this message translates to:
  /// **'Histogram'**
  String get histogramTitle;

  /// No description provided for @toneBlacks.
  ///
  /// In en, this message translates to:
  /// **'Blacks'**
  String get toneBlacks;

  /// No description provided for @toneShadows.
  ///
  /// In en, this message translates to:
  /// **'Shadows'**
  String get toneShadows;

  /// No description provided for @toneExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get toneExposure;

  /// No description provided for @toneHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get toneHighlights;

  /// No description provided for @toneWhites.
  ///
  /// In en, this message translates to:
  /// **'Whites'**
  String get toneWhites;

  /// No description provided for @presetTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Presets'**
  String get presetTitle;

  /// No description provided for @presetTabBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get presetTabBuiltin;

  /// No description provided for @presetTabMine.
  ///
  /// In en, this message translates to:
  /// **'My Presets'**
  String get presetTabMine;

  /// No description provided for @presetScopeGlobal.
  ///
  /// In en, this message translates to:
  /// **'Editing: Global Grade'**
  String get presetScopeGlobal;

  /// No description provided for @presetScopeClip.
  ///
  /// In en, this message translates to:
  /// **'Editing: Current Clip Grade'**
  String get presetScopeClip;

  /// No description provided for @presetSaveNew.
  ///
  /// In en, this message translates to:
  /// **'Save as New Preset'**
  String get presetSaveNew;

  /// No description provided for @presetSaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get presetSaveDialogTitle;

  /// No description provided for @presetSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search presets'**
  String get presetSearchHint;

  /// No description provided for @presetSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Preset saved'**
  String get presetSavedToast;

  /// No description provided for @presetImportedToast.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} preset(s)'**
  String presetImportedToast(int count);

  /// No description provided for @presetImportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to read preset file'**
  String get presetImportFailedToast;

  /// No description provided for @presetExportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get presetExportFailedToast;

  /// No description provided for @presetExportedToast.
  ///
  /// In en, this message translates to:
  /// **'Preset exported to Zync/exports'**
  String get presetExportedToast;

  /// No description provided for @presetApplyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get presetApplyAction;

  /// No description provided for @presetEmptyMatch.
  ///
  /// In en, this message translates to:
  /// **'No matching presets'**
  String get presetEmptyMatch;

  /// No description provided for @presetNoAdjustments.
  ///
  /// In en, this message translates to:
  /// **'No adjustments'**
  String get presetNoAdjustments;

  /// No description provided for @presetUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Untitled Preset'**
  String get presetUnnamed;

  /// No description provided for @videoReadMetaFailed.
  ///
  /// In en, this message translates to:
  /// **'Cannot read video metadata'**
  String get videoReadMetaFailed;

  /// No description provided for @videoUnsupportedCodec.
  ///
  /// In en, this message translates to:
  /// **'Cannot play this video; verify codec support on device'**
  String get videoUnsupportedCodec;

  /// No description provided for @videoGeneratingProxyToast.
  ///
  /// In en, this message translates to:
  /// **'Generating 4s grade/LUT preview proxy…'**
  String get videoGeneratingProxyToast;

  /// No description provided for @videoProxyFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate grade preview; check device codec support'**
  String get videoProxyFailedToast;

  /// No description provided for @videoProxyReadyToast.
  ///
  /// In en, this message translates to:
  /// **'Grade preview ready; toggle Original/Graded in top-right of preview'**
  String get videoProxyReadyToast;

  /// No description provided for @videoExportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Video export failed; check device encoder capabilities'**
  String get videoExportFailedToast;

  /// No description provided for @videoExportSaveAlbumFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Export finished, but saving to system gallery failed'**
  String get videoExportSaveAlbumFailedToast;

  /// No description provided for @videoExportSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Video exported to DCIM/Zync'**
  String get videoExportSuccessToast;

  /// No description provided for @videoGeneratePreviewTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate Grade Preview'**
  String get videoGeneratePreviewTooltip;

  /// No description provided for @videoRefreshGeneratePreview.
  ///
  /// In en, this message translates to:
  /// **'Generate / Refresh Preview'**
  String get videoRefreshGeneratePreview;

  /// No description provided for @videoExportVideoAction.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get videoExportVideoAction;

  /// No description provided for @videoGeneratingProxyOverlay.
  ///
  /// In en, this message translates to:
  /// **'Generating video preview proxy…'**
  String get videoGeneratingProxyOverlay;

  /// No description provided for @videoSkipProxyUseOriginal.
  ///
  /// In en, this message translates to:
  /// **'Skip proxy and use original video'**
  String get videoSkipProxyUseOriginal;

  /// No description provided for @videoBadge4sProxy.
  ///
  /// In en, this message translates to:
  /// **'4s Grade Proxy'**
  String get videoBadge4sProxy;

  /// No description provided for @videoBadgeOriginalPreview.
  ///
  /// In en, this message translates to:
  /// **'Original Preview · Grade/LUT applied on export'**
  String get videoBadgeOriginalPreview;

  /// No description provided for @videoBadgePreviewStale.
  ///
  /// In en, this message translates to:
  /// **'Preview Outdated'**
  String get videoBadgePreviewStale;

  /// No description provided for @videoToggleGradedPreview.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get videoToggleGradedPreview;

  /// No description provided for @videoToggleOriginalPreview.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get videoToggleOriginalPreview;

  /// No description provided for @videoExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit Fullscreen'**
  String get videoExitFullscreen;

  /// No description provided for @videoEnterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Preview'**
  String get videoEnterFullscreen;

  /// No description provided for @videoTabTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get videoTabTrim;

  /// No description provided for @videoTabGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get videoTabGrade;

  /// No description provided for @videoTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get videoTabAudio;

  /// No description provided for @videoTabScopes.
  ///
  /// In en, this message translates to:
  /// **'Scopes'**
  String get videoTabScopes;

  /// No description provided for @videoTimelineClipsHeader.
  ///
  /// In en, this message translates to:
  /// **'Timeline Clips'**
  String get videoTimelineClipsHeader;

  /// No description provided for @videoAddLocalClipTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add Local Video Clip'**
  String get videoAddLocalClipTooltip;

  /// No description provided for @videoClipIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'Clip {index}'**
  String videoClipIndexLabel(int index);

  /// No description provided for @videoMoveClipEarlier.
  ///
  /// In en, this message translates to:
  /// **'Move Clip Earlier'**
  String get videoMoveClipEarlier;

  /// No description provided for @videoMoveClipLater.
  ///
  /// In en, this message translates to:
  /// **'Move Clip Later'**
  String get videoMoveClipLater;

  /// No description provided for @videoTrimRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Trim Range'**
  String get videoTrimRangeLabel;

  /// No description provided for @videoSplitClipAction.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get videoSplitClipAction;

  /// No description provided for @videoDeleteClipAction.
  ///
  /// In en, this message translates to:
  /// **'Delete Clip'**
  String get videoDeleteClipAction;

  /// No description provided for @videoChapterDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Chapter {index}'**
  String videoChapterDefaultTitle(int index);

  /// No description provided for @videoAddChapterButton.
  ///
  /// In en, this message translates to:
  /// **'Add Chapter'**
  String get videoAddChapterButton;

  /// No description provided for @videoChapterNavHeader.
  ///
  /// In en, this message translates to:
  /// **'Chapter Navigation'**
  String get videoChapterNavHeader;

  /// No description provided for @videoGlobalGradeTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Grade'**
  String get videoGlobalGradeTitle;

  /// No description provided for @videoMoreParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'More adjustments'**
  String get videoMoreParamsTitle;

  /// No description provided for @videoUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Save changes?'**
  String get videoUnsavedTitle;

  /// No description provided for @videoUnsavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your trim and grade changes will be lost if you leave without saving.'**
  String get videoUnsavedMessage;

  /// No description provided for @videoDiscardChanges.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get videoDiscardChanges;

  /// No description provided for @videoGlobalGradeOnSub.
  ///
  /// In en, this message translates to:
  /// **'Applied across all timeline clips'**
  String get videoGlobalGradeOnSub;

  /// No description provided for @videoGlobalGradeOffSub.
  ///
  /// In en, this message translates to:
  /// **'Applied to current clip only'**
  String get videoGlobalGradeOffSub;

  /// No description provided for @videoGlobalGradeHint.
  ///
  /// In en, this message translates to:
  /// **'Global grade is applied before per-clip adjustments; keyframes remain per clip.'**
  String get videoGlobalGradeHint;

  /// No description provided for @videoKeyframeParamLabel.
  ///
  /// In en, this message translates to:
  /// **'Keyframe Parameter'**
  String get videoKeyframeParamLabel;

  /// No description provided for @videoAddKeyframeButton.
  ///
  /// In en, this message translates to:
  /// **'Add Keyframe'**
  String get videoAddKeyframeButton;

  /// No description provided for @videoKeyframeListHeader.
  ///
  /// In en, this message translates to:
  /// **'Keyframes'**
  String get videoKeyframeListHeader;

  /// No description provided for @videoPresetEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Presets: Save / Apply / Import & Export'**
  String get videoPresetEntryTitle;

  /// No description provided for @videoCopiedGlobalGradeToast.
  ///
  /// In en, this message translates to:
  /// **'Copied global grade'**
  String get videoCopiedGlobalGradeToast;

  /// No description provided for @videoCopiedClipGradeToast.
  ///
  /// In en, this message translates to:
  /// **'Copied current clip grade'**
  String get videoCopiedClipGradeToast;

  /// No description provided for @videoCopyGradeAction.
  ///
  /// In en, this message translates to:
  /// **'Copy Grade'**
  String get videoCopyGradeAction;

  /// No description provided for @videoPasteGradeAction.
  ///
  /// In en, this message translates to:
  /// **'Paste Grade'**
  String get videoPasteGradeAction;

  /// No description provided for @videoRefresh4sPreview.
  ///
  /// In en, this message translates to:
  /// **'Refresh 4s Preview'**
  String get videoRefresh4sPreview;

  /// No description provided for @videoGenerate4sPreview.
  ///
  /// In en, this message translates to:
  /// **'Generate 4s Preview'**
  String get videoGenerate4sPreview;

  /// No description provided for @videoGlobalGradeStatusChip.
  ///
  /// In en, this message translates to:
  /// **'Global Grade: {status}'**
  String videoGlobalGradeStatusChip(String status);

  /// No description provided for @videoStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get videoStatusEnabled;

  /// No description provided for @videoKeyframeCountChip.
  ///
  /// In en, this message translates to:
  /// **'Keyframes: {count}'**
  String videoKeyframeCountChip(int count);

  /// No description provided for @videoWheelHue.
  ///
  /// In en, this message translates to:
  /// **'{wheel} Hue'**
  String videoWheelHue(String wheel);

  /// No description provided for @videoWheelSaturation.
  ///
  /// In en, this message translates to:
  /// **'{wheel} Saturation'**
  String videoWheelSaturation(String wheel);

  /// No description provided for @videoWheelLuma.
  ///
  /// In en, this message translates to:
  /// **'{wheel} Luma'**
  String videoWheelLuma(String wheel);

  /// No description provided for @videoCurveLinear.
  ///
  /// In en, this message translates to:
  /// **'Linear'**
  String get videoCurveLinear;

  /// No description provided for @videoCurveEaseInOut.
  ///
  /// In en, this message translates to:
  /// **'Ease In/Out'**
  String get videoCurveEaseInOut;

  /// No description provided for @videoLutGlobalTitle.
  ///
  /// In en, this message translates to:
  /// **'Global 3D LUT'**
  String get videoLutGlobalTitle;

  /// No description provided for @videoLutClipTitle.
  ///
  /// In en, this message translates to:
  /// **'Current Clip 3D LUT'**
  String get videoLutClipTitle;

  /// No description provided for @videoLutPathHint.
  ///
  /// In en, this message translates to:
  /// **'.cube / PNG LUT file path'**
  String get videoLutPathHint;

  /// No description provided for @videoPickLutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Choose LUT File'**
  String get videoPickLutTooltip;

  /// No description provided for @videoApplyLutAction.
  ///
  /// In en, this message translates to:
  /// **'Apply LUT'**
  String get videoApplyLutAction;

  /// No description provided for @videoLutIntensityLabel.
  ///
  /// In en, this message translates to:
  /// **'LUT Intensity'**
  String get videoLutIntensityLabel;

  /// No description provided for @videoColorUnlabeled.
  ///
  /// In en, this message translates to:
  /// **'Unlabeled'**
  String get videoColorUnlabeled;

  /// No description provided for @videoSourceColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Source Color: {label}'**
  String videoSourceColorLabel(String label);

  /// No description provided for @videoHdrToneMapHint.
  ///
  /// In en, this message translates to:
  /// **'HDR source detected ({label}). Export tone-maps to SDR Rec.709; pair N-Log with a LUT.'**
  String videoHdrToneMapHint(String label);

  /// No description provided for @videoSdrSourceHint.
  ///
  /// In en, this message translates to:
  /// **'SDR source: uses current grade and LUT directly without extra HDR tone mapping.'**
  String get videoSdrSourceHint;

  /// No description provided for @videoAudioMute.
  ///
  /// In en, this message translates to:
  /// **'Mute Audio'**
  String get videoAudioMute;

  /// No description provided for @videoAudioVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get videoAudioVolume;

  /// No description provided for @videoAudioFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade In (s)'**
  String get videoAudioFadeIn;

  /// No description provided for @videoAudioFadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade Out (s)'**
  String get videoAudioFadeOut;

  /// No description provided for @videoExportSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Export Settings'**
  String get videoExportSettingsHeader;

  /// No description provided for @videoHwHevcStatus.
  ///
  /// In en, this message translates to:
  /// **'Hardware HEVC Decode: {status}'**
  String videoHwHevcStatus(String status);

  /// No description provided for @videoExport4k60Note.
  ///
  /// In en, this message translates to:
  /// **'4K/60 is best-effort; if unsupported by the device encoder, export fails safely and keeps the original.'**
  String get videoExport4k60Note;

  /// No description provided for @videoNoHevc10BitWarning.
  ///
  /// In en, this message translates to:
  /// **'No HEVC Main10 hardware decoder detected; 10-bit N-Log/HLG may not preview. Test a 4s preview before exporting.'**
  String get videoNoHevc10BitWarning;

  /// No description provided for @videoCodecLabel.
  ///
  /// In en, this message translates to:
  /// **'Codec'**
  String get videoCodecLabel;

  /// No description provided for @videoCodecH264.
  ///
  /// In en, this message translates to:
  /// **'H.264 (Best Compatibility)'**
  String get videoCodecH264;

  /// No description provided for @videoCodecHevc.
  ///
  /// In en, this message translates to:
  /// **'HEVC (Smaller File)'**
  String get videoCodecHevc;

  /// No description provided for @videoCodecHevcUnsupported.
  ///
  /// In en, this message translates to:
  /// **'HEVC (Unsupported)'**
  String get videoCodecHevcUnsupported;

  /// No description provided for @videoResolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get videoResolutionLabel;

  /// No description provided for @videoFpsLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame Rate'**
  String get videoFpsLabel;

  /// No description provided for @videoBitrateLabel.
  ///
  /// In en, this message translates to:
  /// **'Bitrate'**
  String get videoBitrateLabel;

  /// No description provided for @videoBitrate20.
  ///
  /// In en, this message translates to:
  /// **'Standard 20 Mbps'**
  String get videoBitrate20;

  /// No description provided for @videoBitrate40.
  ///
  /// In en, this message translates to:
  /// **'High 40 Mbps'**
  String get videoBitrate40;

  /// No description provided for @videoBitrate80.
  ///
  /// In en, this message translates to:
  /// **'Pro 80 Mbps'**
  String get videoBitrate80;

  /// No description provided for @videoExportingProgressHint.
  ///
  /// In en, this message translates to:
  /// **'Exporting {percent}% · Keep Zync in the foreground'**
  String videoExportingProgressHint(int percent);

  /// No description provided for @videoCancelExport.
  ///
  /// In en, this message translates to:
  /// **'Cancel Export'**
  String get videoCancelExport;

  /// No description provided for @videoExportToDcimButton.
  ///
  /// In en, this message translates to:
  /// **'Export to DCIM/Zync'**
  String get videoExportToDcimButton;

  /// No description provided for @scopeTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Scopes'**
  String get scopeTitle;

  /// No description provided for @scopeCaptureFrameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Capture Current Frame'**
  String get scopeCaptureFrameTooltip;

  /// No description provided for @scopeWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get scopeWaveform;

  /// No description provided for @scopeVectorscope.
  ///
  /// In en, this message translates to:
  /// **'Vectorscope'**
  String get scopeVectorscope;

  /// No description provided for @scopeAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing current frame…'**
  String get scopeAnalyzing;

  /// No description provided for @scopeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap refresh in top-right to capture current frame'**
  String get scopeEmptyHint;

  /// No description provided for @scopeLumaHistogram.
  ///
  /// In en, this message translates to:
  /// **'Luma Histogram'**
  String get scopeLumaHistogram;

  /// No description provided for @scopePeak.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get scopePeak;

  /// No description provided for @scopeAverage.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get scopeAverage;

  /// No description provided for @scopeBlackLevel.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get scopeBlackLevel;

  /// No description provided for @scopeHighlightClip.
  ///
  /// In en, this message translates to:
  /// **'Highlight Clip'**
  String get scopeHighlightClip;

  /// No description provided for @scopeShadowClip.
  ///
  /// In en, this message translates to:
  /// **'Shadow Clip'**
  String get scopeShadowClip;

  /// No description provided for @wmStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark Studio'**
  String get wmStudioTitle;

  /// No description provided for @wmPickFromAlbumTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick from Phone Album'**
  String get wmPickFromAlbumTooltip;

  /// No description provided for @wmStyleSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Watermark Settings (Style / Content / Text / Logo)'**
  String get wmStyleSettingsTooltip;

  /// No description provided for @wmExportQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Quality'**
  String get wmExportQualityTitle;

  /// No description provided for @wmExportQualityMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Export Quality: {label} (q{quality})'**
  String wmExportQualityMenuLabel(String label, int quality);

  /// No description provided for @exportQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original Quality'**
  String get exportQualityOriginal;

  /// No description provided for @exportQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get exportQualityStandard;

  /// No description provided for @exportQualityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact Size'**
  String get exportQualityCompact;

  /// No description provided for @wmSaveHighResTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save High-Res Photo to Album'**
  String get wmSaveHighResTooltip;

  /// No description provided for @wmShowingOriginalBadge.
  ///
  /// In en, this message translates to:
  /// **'Showing Original'**
  String get wmShowingOriginalBadge;

  /// No description provided for @wmHoldToCompareHint.
  ///
  /// In en, this message translates to:
  /// **'Hold to Compare'**
  String get wmHoldToCompareHint;

  /// No description provided for @wmPickPhotoEmptyPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select a local photo to grade and add a watermark'**
  String get wmPickPhotoEmptyPrompt;

  /// No description provided for @wmEditExifTag.
  ///
  /// In en, this message translates to:
  /// **'Edit EXIF'**
  String get wmEditExifTag;

  /// No description provided for @wmTabWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get wmTabWatermark;

  /// No description provided for @wmTabColorGrade.
  ///
  /// In en, this message translates to:
  /// **'Color Grade'**
  String get wmTabColorGrade;

  /// No description provided for @wmTabPhotoEdit.
  ///
  /// In en, this message translates to:
  /// **'Crop & Transform'**
  String get wmTabPhotoEdit;

  /// No description provided for @wmPureGradeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Color Grade Only Mode (No Watermark)'**
  String get wmPureGradeModeTitle;

  /// No description provided for @wmPureGradeModeSub.
  ///
  /// In en, this message translates to:
  /// **'No border or text overlay will be added; exports at original full resolution.'**
  String get wmPureGradeModeSub;

  /// No description provided for @wmGoToGradeButton.
  ///
  /// In en, this message translates to:
  /// **'Adjust Color'**
  String get wmGoToGradeButton;

  /// No description provided for @wmBorderColorShort.
  ///
  /// In en, this message translates to:
  /// **'Frame Color'**
  String get wmBorderColorShort;

  /// No description provided for @wmTextColorShort.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get wmTextColorShort;

  /// No description provided for @wmDetailSettingsShort.
  ///
  /// In en, this message translates to:
  /// **'More Settings'**
  String get wmDetailSettingsShort;

  /// No description provided for @wmGradeCatTone.
  ///
  /// In en, this message translates to:
  /// **'Basic Tone'**
  String get wmGradeCatTone;

  /// No description provided for @wmGradeCatWb.
  ///
  /// In en, this message translates to:
  /// **'White Balance'**
  String get wmGradeCatWb;

  /// No description provided for @wmGradeCatPresence.
  ///
  /// In en, this message translates to:
  /// **'Presence'**
  String get wmGradeCatPresence;

  /// No description provided for @wmGradeCatSplit.
  ///
  /// In en, this message translates to:
  /// **'Split Toning'**
  String get wmGradeCatSplit;

  /// No description provided for @wmGradeCatFilm.
  ///
  /// In en, this message translates to:
  /// **'Film Presets'**
  String get wmGradeCatFilm;

  /// No description provided for @wmGradeCatEffects.
  ///
  /// In en, this message translates to:
  /// **'Lens & Effects'**
  String get wmGradeCatEffects;

  /// No description provided for @wmCurrentModeNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'Current Mode: Color Grade Only (No Watermark)'**
  String get wmCurrentModeNoWatermark;

  /// No description provided for @wmCurrentTemplateLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Watermark: {name}'**
  String wmCurrentTemplateLabel(String name);

  /// No description provided for @wmEnableWatermarkSwitch.
  ///
  /// In en, this message translates to:
  /// **'Enable Watermark'**
  String get wmEnableWatermarkSwitch;

  /// No description provided for @wmDisableWatermarkSwitch.
  ///
  /// In en, this message translates to:
  /// **'Disable Watermark (Grade Only)'**
  String get wmDisableWatermarkSwitch;

  /// No description provided for @wmImportedExifToast.
  ///
  /// In en, this message translates to:
  /// **'Imported photo and extracted EXIF ({title})'**
  String wmImportedExifToast(String title);

  /// No description provided for @wmDecodeImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Image decode failed'**
  String get wmDecodeImageFailed;

  /// No description provided for @wmParseImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Image parse failed: {error}'**
  String wmParseImageFailed(String error);

  /// No description provided for @wmSelectPhotoFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Select a photo from top-right album icon or import from Camera Roll first'**
  String get wmSelectPhotoFirstHint;

  /// No description provided for @wmRawFullDecodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Full-size RAW decode failed'**
  String get wmRawFullDecodeFailed;

  /// No description provided for @wmSaveAlbumFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save to system album'**
  String get wmSaveAlbumFailed;

  /// No description provided for @wmSavedSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Saved to album · {width}×{height} · {sizeMb}MB'**
  String wmSavedSuccessToast(int width, int height, String sizeMb);

  /// No description provided for @wmViewInAlbumAction.
  ///
  /// In en, this message translates to:
  /// **'View in Album'**
  String get wmViewInAlbumAction;

  /// No description provided for @wmExportFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String wmExportFailedToast(String error);

  /// No description provided for @wmExifSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fine-Tune EXIF Parameters'**
  String get wmExifSheetTitle;

  /// No description provided for @wmExifSheetSub.
  ///
  /// In en, this message translates to:
  /// **'Customize displayed EXIF fields for manual lenses or photos without metadata'**
  String get wmExifSheetSub;

  /// No description provided for @wmExifCameraLabel.
  ///
  /// In en, this message translates to:
  /// **'Camera Model'**
  String get wmExifCameraLabel;

  /// No description provided for @wmExifCameraHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Z 30, Z 8, Z fc'**
  String get wmExifCameraHint;

  /// No description provided for @wmExifLensLabel.
  ///
  /// In en, this message translates to:
  /// **'Lens Model'**
  String get wmExifLensLabel;

  /// No description provided for @wmExifLensHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. NIKKOR Z 40mm f/2'**
  String get wmExifLensHint;

  /// No description provided for @wmExifApertureLabel.
  ///
  /// In en, this message translates to:
  /// **'Aperture'**
  String get wmExifApertureLabel;

  /// No description provided for @wmExifApertureHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. f/1.8'**
  String get wmExifApertureHint;

  /// No description provided for @wmExifShutterLabel.
  ///
  /// In en, this message translates to:
  /// **'Shutter Speed'**
  String get wmExifShutterLabel;

  /// No description provided for @wmExifShutterHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1/250s'**
  String get wmExifShutterHint;

  /// No description provided for @wmExifIsoLabel.
  ///
  /// In en, this message translates to:
  /// **'ISO Sensitivity'**
  String get wmExifIsoLabel;

  /// No description provided for @wmExifIsoHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ISO 100'**
  String get wmExifIsoHint;

  /// No description provided for @wmExifFocalLabel.
  ///
  /// In en, this message translates to:
  /// **'Focal Length'**
  String get wmExifFocalLabel;

  /// No description provided for @wmExifFocalHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 40mm'**
  String get wmExifFocalHint;

  /// No description provided for @wmExifDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Capture Time'**
  String get wmExifDateLabel;

  /// No description provided for @wmExifDateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2026.10.06 14:32'**
  String get wmExifDateHint;

  /// No description provided for @wmExifApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply Parameters'**
  String get wmExifApplyButton;

  /// No description provided for @wmSettingsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark Settings'**
  String get wmSettingsSheetTitle;

  /// No description provided for @wmSettingsSheetSub.
  ///
  /// In en, this message translates to:
  /// **'Colors, font sizes, spacing, and toggles are saved automatically; custom Logo is kept for this session.'**
  String get wmSettingsSheetSub;

  /// No description provided for @wmLogoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Logo Overlay'**
  String get wmLogoSectionTitle;

  /// No description provided for @wmLogoReadFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to read Logo image'**
  String get wmLogoReadFailedToast;

  /// No description provided for @wmLogoPickButton.
  ///
  /// In en, this message translates to:
  /// **'Select Logo'**
  String get wmLogoPickButton;

  /// No description provided for @wmLogoChangeButton.
  ///
  /// In en, this message translates to:
  /// **'Change Logo'**
  String get wmLogoChangeButton;

  /// No description provided for @wmLogoSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo Size'**
  String get wmLogoSizeLabel;

  /// No description provided for @wmLogoOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo Opacity'**
  String get wmLogoOpacityLabel;

  /// No description provided for @wmSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get wmSizeSmall;

  /// No description provided for @wmSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get wmSizeMedium;

  /// No description provided for @wmSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get wmSizeLarge;

  /// No description provided for @wmOpacityOpaque.
  ///
  /// In en, this message translates to:
  /// **'100%'**
  String get wmOpacityOpaque;

  /// No description provided for @wmOpacitySemi.
  ///
  /// In en, this message translates to:
  /// **'65%'**
  String get wmOpacitySemi;

  /// No description provided for @wmOpacityLight.
  ///
  /// In en, this message translates to:
  /// **'35%'**
  String get wmOpacityLight;

  /// No description provided for @wmLogoPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo Position'**
  String get wmLogoPositionLabel;

  /// No description provided for @adjExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure'**
  String get adjExposure;

  /// No description provided for @adjExposureDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust overall image brightness (-2EV to +2EV)'**
  String get adjExposureDesc;

  /// No description provided for @adjContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get adjContrast;

  /// No description provided for @adjContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Increase or soften tonal separation between light and dark'**
  String get adjContrastDesc;

  /// No description provided for @adjHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get adjHighlights;

  /// No description provided for @adjHighlightsDesc.
  ///
  /// In en, this message translates to:
  /// **'Recover bright highlight detail or boost luminous areas'**
  String get adjHighlightsDesc;

  /// No description provided for @adjShadows.
  ///
  /// In en, this message translates to:
  /// **'Shadows'**
  String get adjShadows;

  /// No description provided for @adjShadowsDesc.
  ///
  /// In en, this message translates to:
  /// **'Lift dark shadow detail or deepen shadow contrast'**
  String get adjShadowsDesc;

  /// No description provided for @adjWhites.
  ///
  /// In en, this message translates to:
  /// **'Whites'**
  String get adjWhites;

  /// No description provided for @adjWhitesDesc.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune the white clipping point'**
  String get adjWhitesDesc;

  /// No description provided for @adjBlacks.
  ///
  /// In en, this message translates to:
  /// **'Blacks'**
  String get adjBlacks;

  /// No description provided for @adjBlacksDesc.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune the pure black floor'**
  String get adjBlacksDesc;

  /// No description provided for @adjTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get adjTemperature;

  /// No description provided for @adjTemperatureDesc.
  ///
  /// In en, this message translates to:
  /// **'Cooler blue to the left, warmer golden amber to the right'**
  String get adjTemperatureDesc;

  /// No description provided for @adjTint.
  ///
  /// In en, this message translates to:
  /// **'Tint'**
  String get adjTint;

  /// No description provided for @adjTintDesc.
  ///
  /// In en, this message translates to:
  /// **'Compensate green cast to the left or magenta to the right'**
  String get adjTintDesc;

  /// No description provided for @adjClarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get adjClarity;

  /// No description provided for @adjClarityDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjust midtone micro-contrast to emphasize structure'**
  String get adjClarityDesc;

  /// No description provided for @adjTexture.
  ///
  /// In en, this message translates to:
  /// **'Texture'**
  String get adjTexture;

  /// No description provided for @adjTextureDesc.
  ///
  /// In en, this message translates to:
  /// **'Smooth skin to the left or accentuate fine surface detail to the right'**
  String get adjTextureDesc;

  /// No description provided for @adjDehaze.
  ///
  /// In en, this message translates to:
  /// **'Dehaze'**
  String get adjDehaze;

  /// No description provided for @adjDehazeDesc.
  ///
  /// In en, this message translates to:
  /// **'Cut through atmospheric haze or add dreamy mist'**
  String get adjDehazeDesc;

  /// No description provided for @adjVibrance.
  ///
  /// In en, this message translates to:
  /// **'Vibrance'**
  String get adjVibrance;

  /// No description provided for @adjVibranceDesc.
  ///
  /// In en, this message translates to:
  /// **'Boost muted colors while protecting skin tones'**
  String get adjVibranceDesc;

  /// No description provided for @adjSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get adjSaturation;

  /// No description provided for @adjSaturationDesc.
  ///
  /// In en, this message translates to:
  /// **'Global color intensity (-100 monochrome to +100 vivid)'**
  String get adjSaturationDesc;

  /// No description provided for @adjSplitToningInfo.
  ///
  /// In en, this message translates to:
  /// **'Split Toning: tint highlights and shadows independently for cinematic warm/cool separation.'**
  String get adjSplitToningInfo;

  /// No description provided for @adjHighlightHue.
  ///
  /// In en, this message translates to:
  /// **'Highlight Hue'**
  String get adjHighlightHue;

  /// No description provided for @adjHighlightHueDesc.
  ///
  /// In en, this message translates to:
  /// **'Highlight tint hue (0°–360°), warm gold ~35°–45°, cyan ~195°–210°'**
  String get adjHighlightHueDesc;

  /// No description provided for @adjHighlightSat.
  ///
  /// In en, this message translates to:
  /// **'Highlight Saturation'**
  String get adjHighlightSat;

  /// No description provided for @adjHighlightSatDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength of highlight color tint (0%–100%)'**
  String get adjHighlightSatDesc;

  /// No description provided for @adjShadowHue.
  ///
  /// In en, this message translates to:
  /// **'Shadow Hue'**
  String get adjShadowHue;

  /// No description provided for @adjShadowHueDesc.
  ///
  /// In en, this message translates to:
  /// **'Shadow tint hue (0°–360°), cool teal ~200°–220°, vintage magenta ~300°–320°'**
  String get adjShadowHueDesc;

  /// No description provided for @adjShadowSat.
  ///
  /// In en, this message translates to:
  /// **'Shadow Saturation'**
  String get adjShadowSat;

  /// No description provided for @adjShadowSatDesc.
  ///
  /// In en, this message translates to:
  /// **'Strength of shadow color tint (0%–100%)'**
  String get adjShadowSatDesc;

  /// No description provided for @adjMidtones.
  ///
  /// In en, this message translates to:
  /// **'Midtones'**
  String get adjMidtones;

  /// No description provided for @adjSharpening.
  ///
  /// In en, this message translates to:
  /// **'Sharpening'**
  String get adjSharpening;

  /// No description provided for @adjNoiseReduction.
  ///
  /// In en, this message translates to:
  /// **'Noise Reduction'**
  String get adjNoiseReduction;

  /// No description provided for @adjLensDistortion.
  ///
  /// In en, this message translates to:
  /// **'Lens Distortion'**
  String get adjLensDistortion;

  /// No description provided for @adjLensVignette.
  ///
  /// In en, this message translates to:
  /// **'Lens Vignette'**
  String get adjLensVignette;

  /// No description provided for @adjLensVignetteDesc.
  ///
  /// In en, this message translates to:
  /// **'Darken corners to the right for cinema vignette, or lighten to the left'**
  String get adjLensVignetteDesc;

  /// No description provided for @adjChromaticAberration.
  ///
  /// In en, this message translates to:
  /// **'Chromatic Aberration'**
  String get adjChromaticAberration;

  /// No description provided for @adjFilmGrain.
  ///
  /// In en, this message translates to:
  /// **'Film Grain'**
  String get adjFilmGrain;

  /// No description provided for @adjFilmGrainDesc.
  ///
  /// In en, this message translates to:
  /// **'Simulate organic silver-halide film grain texture'**
  String get adjFilmGrainDesc;

  /// No description provided for @adjToneCurve.
  ///
  /// In en, this message translates to:
  /// **'Curve'**
  String get adjToneCurve;

  /// No description provided for @adjColorWheel.
  ///
  /// In en, this message translates to:
  /// **'Wheels'**
  String get adjColorWheel;

  /// No description provided for @wmFilterAllCount.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String wmFilterAllCount(int count);

  /// No description provided for @wmRecipeSummaryPrefix.
  ///
  /// In en, this message translates to:
  /// **'Camera Recipe: {summary}'**
  String wmRecipeSummaryPrefix(String summary);

  /// No description provided for @wmPresetIntensity.
  ///
  /// In en, this message translates to:
  /// **'Preset Intensity'**
  String get wmPresetIntensity;

  /// No description provided for @wmProRawSectionEntry.
  ///
  /// In en, this message translates to:
  /// **'Pro Parameters: LUT / Denoise / Sharpen / Lens Correction'**
  String get wmProRawSectionEntry;

  /// No description provided for @wmLoadedFilterSlidersToast.
  ///
  /// In en, this message translates to:
  /// **'Loaded [{name}] parameters into sliders for fine-tuning'**
  String wmLoadedFilterSlidersToast(String name);

  /// No description provided for @wmLoadFilterToSlidersButton.
  ///
  /// In en, this message translates to:
  /// **'Load [{name}] into Sliders (Fine-Tune)'**
  String wmLoadFilterToSlidersButton(String name);

  /// No description provided for @wmProRawSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro RAW & Lens Parameters'**
  String get wmProRawSheetTitle;

  /// No description provided for @wmStyleFollowTemplate.
  ///
  /// In en, this message translates to:
  /// **'Follow Template'**
  String get wmStyleFollowTemplate;

  /// No description provided for @wmStylePureWhite.
  ///
  /// In en, this message translates to:
  /// **'Pure White'**
  String get wmStylePureWhite;

  /// No description provided for @wmStyleDeepBlack.
  ///
  /// In en, this message translates to:
  /// **'Deep Black'**
  String get wmStyleDeepBlack;

  /// No description provided for @wmStyleCream.
  ///
  /// In en, this message translates to:
  /// **'Warm Cream'**
  String get wmStyleCream;

  /// No description provided for @wmStyleNikonGold.
  ///
  /// In en, this message translates to:
  /// **'Amber Gold'**
  String get wmStyleNikonGold;

  /// No description provided for @wmStyleCyan.
  ///
  /// In en, this message translates to:
  /// **'Teal Cyan'**
  String get wmStyleCyan;

  /// No description provided for @wmStyleMagenta.
  ///
  /// In en, this message translates to:
  /// **'Magenta'**
  String get wmStyleMagenta;

  /// No description provided for @wmStyleDarkGrey.
  ///
  /// In en, this message translates to:
  /// **'Graphite Grey'**
  String get wmStyleDarkGrey;

  /// No description provided for @wmStyleCustomColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Color'**
  String get wmStyleCustomColorTitle;

  /// No description provided for @wmStyleColorsSection.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get wmStyleColorsSection;

  /// No description provided for @wmStyleFrameBgLabel.
  ///
  /// In en, this message translates to:
  /// **'Frame / Background'**
  String get wmStyleFrameBgLabel;

  /// No description provided for @wmStyleTextColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Text Color'**
  String get wmStyleTextColorLabel;

  /// No description provided for @wmStyleAccentColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get wmStyleAccentColorLabel;

  /// No description provided for @wmStyleTypographySection.
  ///
  /// In en, this message translates to:
  /// **'Typography & Layout'**
  String get wmStyleTypographySection;

  /// No description provided for @wmStyleTitleScale.
  ///
  /// In en, this message translates to:
  /// **'Title Size'**
  String get wmStyleTitleScale;

  /// No description provided for @wmStyleMetaScale.
  ///
  /// In en, this message translates to:
  /// **'EXIF Size'**
  String get wmStyleMetaScale;

  /// No description provided for @wmStyleCustomTextScale.
  ///
  /// In en, this message translates to:
  /// **'Custom Text Size'**
  String get wmStyleCustomTextScale;

  /// No description provided for @wmStyleLetterSpacing.
  ///
  /// In en, this message translates to:
  /// **'Letter Spacing'**
  String get wmStyleLetterSpacing;

  /// No description provided for @wmStyleLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line Spacing'**
  String get wmStyleLineSpacing;

  /// No description provided for @wmStyleLineThickness.
  ///
  /// In en, this message translates to:
  /// **'Divider Weight'**
  String get wmStyleLineThickness;

  /// No description provided for @wmStyleMarginScale.
  ///
  /// In en, this message translates to:
  /// **'Margin Ratio'**
  String get wmStyleMarginScale;

  /// No description provided for @wmStyleCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Card Corner Radius'**
  String get wmStyleCornerRadius;

  /// No description provided for @wmStyleOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get wmStyleOpacity;

  /// No description provided for @wmStyleFontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font Style'**
  String get wmStyleFontFamily;

  /// No description provided for @wmStyleFontDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get wmStyleFontDefault;

  /// No description provided for @wmStyleFontSerif.
  ///
  /// In en, this message translates to:
  /// **'Serif'**
  String get wmStyleFontSerif;

  /// No description provided for @wmStyleFontMono.
  ///
  /// In en, this message translates to:
  /// **'Monospace'**
  String get wmStyleFontMono;

  /// No description provided for @wmStyleFontCondensed.
  ///
  /// In en, this message translates to:
  /// **'Condensed'**
  String get wmStyleFontCondensed;

  /// No description provided for @wmStyleFontWeight.
  ///
  /// In en, this message translates to:
  /// **'Font Weight'**
  String get wmStyleFontWeight;

  /// No description provided for @wmStyleWeightRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get wmStyleWeightRegular;

  /// No description provided for @wmStyleWeightMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get wmStyleWeightMedium;

  /// No description provided for @wmStyleWeightBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get wmStyleWeightBold;

  /// No description provided for @wmStyleWeightBlack.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get wmStyleWeightBlack;

  /// No description provided for @wmStyleContentSection.
  ///
  /// In en, this message translates to:
  /// **'Displayed Info'**
  String get wmStyleContentSection;

  /// No description provided for @wmStyleShowModel.
  ///
  /// In en, this message translates to:
  /// **'Camera Model'**
  String get wmStyleShowModel;

  /// No description provided for @wmStyleShowLens.
  ///
  /// In en, this message translates to:
  /// **'Lens Model'**
  String get wmStyleShowLens;

  /// No description provided for @wmStyleShowExposure.
  ///
  /// In en, this message translates to:
  /// **'Exposure Settings'**
  String get wmStyleShowExposure;

  /// No description provided for @wmStyleShowDate.
  ///
  /// In en, this message translates to:
  /// **'Capture Date'**
  String get wmStyleShowDate;

  /// No description provided for @wmStyleShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Show Time & Full Details'**
  String get wmStyleShowDetails;

  /// No description provided for @wmStyleCustomTextSection.
  ///
  /// In en, this message translates to:
  /// **'Custom Text'**
  String get wmStyleCustomTextSection;

  /// No description provided for @wmStyleCustomLine1Label.
  ///
  /// In en, this message translates to:
  /// **'Custom Line 1'**
  String get wmStyleCustomLine1Label;

  /// No description provided for @wmStyleCustomLine1Hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. © 2026 Your Name'**
  String get wmStyleCustomLine1Hint;

  /// No description provided for @wmStyleCustomLine2Label.
  ///
  /// In en, this message translates to:
  /// **'Custom Line 2'**
  String get wmStyleCustomLine2Label;

  /// No description provided for @wmStyleCustomLine2Hint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nikon Z 30'**
  String get wmStyleCustomLine2Hint;

  /// No description provided for @wmStyleTextAlign.
  ///
  /// In en, this message translates to:
  /// **'Text Alignment'**
  String get wmStyleTextAlign;

  /// No description provided for @wmStyleAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get wmStyleAlignLeft;

  /// No description provided for @wmStyleAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get wmStyleAlignCenter;

  /// No description provided for @wmStyleAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get wmStyleAlignRight;

  /// No description provided for @wmCornerTopLeft.
  ///
  /// In en, this message translates to:
  /// **'Top Left'**
  String get wmCornerTopLeft;

  /// No description provided for @wmCornerTopRight.
  ///
  /// In en, this message translates to:
  /// **'Top Right'**
  String get wmCornerTopRight;

  /// No description provided for @wmCornerBottomLeft.
  ///
  /// In en, this message translates to:
  /// **'Bottom Left'**
  String get wmCornerBottomLeft;

  /// No description provided for @wmCornerBottomRight.
  ///
  /// In en, this message translates to:
  /// **'Bottom Right'**
  String get wmCornerBottomRight;

  /// No description provided for @collageTitle.
  ///
  /// In en, this message translates to:
  /// **'Collage'**
  String get collageTitle;

  /// No description provided for @collageInsufficientPhotos.
  ///
  /// In en, this message translates to:
  /// **'Fewer than 2 usable photos for collage'**
  String get collageInsufficientPhotos;

  /// No description provided for @collageSkippedUnreadableToast.
  ///
  /// In en, this message translates to:
  /// **'Skipped {count} unreadable photo(s)'**
  String collageSkippedUnreadableToast(int count);

  /// No description provided for @collageSaveSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Collage Saved to System Album'**
  String get collageSaveSuccessTitle;

  /// No description provided for @collageSaveSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Saved to Pictures/Zync and ready to view in your phone gallery.'**
  String get collageSaveSuccessBody;

  /// No description provided for @collagePreparingMaterials.
  ///
  /// In en, this message translates to:
  /// **'Preparing collage photos...'**
  String get collagePreparingMaterials;

  /// No description provided for @collageWatermarkDragHint.
  ///
  /// In en, this message translates to:
  /// **'Watermark template applied. Drag or pinch each cell directly to reframe.'**
  String get collageWatermarkDragHint;

  /// No description provided for @collageTabLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get collageTabLayout;

  /// No description provided for @collageTabWatermark.
  ///
  /// In en, this message translates to:
  /// **'Watermark'**
  String get collageTabWatermark;

  /// No description provided for @collageNoWatermark.
  ///
  /// In en, this message translates to:
  /// **'No Watermark'**
  String get collageNoWatermark;

  /// No description provided for @collageMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Grid Style'**
  String get collageMethodLabel;

  /// No description provided for @collageAspectLabel.
  ///
  /// In en, this message translates to:
  /// **'Aspect'**
  String get collageAspectLabel;

  /// No description provided for @collageBorderLabel.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get collageBorderLabel;

  /// No description provided for @collageOutputResolution.
  ///
  /// In en, this message translates to:
  /// **'Output Resolution'**
  String get collageOutputResolution;

  /// No description provided for @collageFileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get collageFileSize;

  /// No description provided for @collageSharedWatermarkSub.
  ///
  /// In en, this message translates to:
  /// **'Shares color, typography, and layout settings with Watermark Studio'**
  String get collageSharedWatermarkSub;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGroupPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsGroupPreferences;

  /// No description provided for @settingsGroupSystem.
  ///
  /// In en, this message translates to:
  /// **'System & About'**
  String get settingsGroupSystem;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Display'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceSub.
  ///
  /// In en, this message translates to:
  /// **'System, Light, or Darkroom mode'**
  String get settingsAppearanceSub;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'English · 简体中文 · 日本語'**
  String get settingsLanguageSub;

  /// No description provided for @settingsCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Connection'**
  String get settingsCameraTitle;

  /// No description provided for @settingsCameraSub.
  ///
  /// In en, this message translates to:
  /// **'Default IP, port, and Wi-Fi NIC binding'**
  String get settingsCameraSub;

  /// No description provided for @settingsWirelessTitle.
  ///
  /// In en, this message translates to:
  /// **'Wireless & Transfer'**
  String get settingsWirelessTitle;

  /// No description provided for @settingsWirelessSub.
  ///
  /// In en, this message translates to:
  /// **'Keep-alive, RAW sync, and export quality'**
  String get settingsWirelessSub;

  /// No description provided for @settingsKeepAliveOnShort.
  ///
  /// In en, this message translates to:
  /// **'Keep-alive On'**
  String get settingsKeepAliveOnShort;

  /// No description provided for @settingsKeepAliveOffShort.
  ///
  /// In en, this message translates to:
  /// **'Keep-alive Off'**
  String get settingsKeepAliveOffShort;

  /// No description provided for @settingsBatteryTitle.
  ///
  /// In en, this message translates to:
  /// **'Battery & Transfer Protection'**
  String get settingsBatteryTitle;

  /// No description provided for @settingsBatterySub.
  ///
  /// In en, this message translates to:
  /// **'Low-battery pause and hysteresis resume'**
  String get settingsBatterySub;

  /// No description provided for @settingsThresholdValue.
  ///
  /// In en, this message translates to:
  /// **'{threshold}% threshold'**
  String settingsThresholdValue(int threshold);

  /// No description provided for @settingsLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics & Logs'**
  String get settingsLogsTitle;

  /// No description provided for @settingsLogsSub.
  ///
  /// In en, this message translates to:
  /// **'PTP handshake and transport diagnostics'**
  String get settingsLogsSub;

  /// No description provided for @settingsLogsCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String settingsLogsCountValue(int count);

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Zync'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSub.
  ///
  /// In en, this message translates to:
  /// **'Version, updates, and open-source licenses'**
  String get settingsAboutSub;

  /// No description provided for @settingsReplayOnboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Guide'**
  String get settingsReplayOnboardingTitle;

  /// No description provided for @settingsReplayOnboardingSub.
  ///
  /// In en, this message translates to:
  /// **'Re-open the 3-step setup guide for language, appearance, and connection'**
  String get settingsReplayOnboardingSub;

  /// No description provided for @settingsAppearanceModeSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance Mode'**
  String get settingsAppearanceModeSection;

  /// No description provided for @settingsColorPreviewSection.
  ///
  /// In en, this message translates to:
  /// **'Palette Preview'**
  String get settingsColorPreviewSection;

  /// No description provided for @settingsColorPreviewTileTitle.
  ///
  /// In en, this message translates to:
  /// **'Background / Surface / Accent'**
  String get settingsColorPreviewTileTitle;

  /// No description provided for @settingsConfigIpTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure Camera IP Address'**
  String get settingsConfigIpTitle;

  /// No description provided for @settingsConfigIpSub.
  ///
  /// In en, this message translates to:
  /// **'Default Nikon Z hotspot gateway is 192.168.0.1'**
  String get settingsConfigIpSub;

  /// No description provided for @settingsIpAddressField.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get settingsIpAddressField;

  /// No description provided for @settingsConfigPortTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure PTP/IP Port'**
  String get settingsConfigPortTitle;

  /// No description provided for @settingsConfigPortSub.
  ///
  /// In en, this message translates to:
  /// **'Standard Nikon PTP/IP hardware port is 15740'**
  String get settingsConfigPortSub;

  /// No description provided for @settingsPortField.
  ///
  /// In en, this message translates to:
  /// **'Port Number'**
  String get settingsPortField;

  /// No description provided for @settingsPtpNetworkSection.
  ///
  /// In en, this message translates to:
  /// **'PTP/IP Network'**
  String get settingsPtpNetworkSection;

  /// No description provided for @settingsDefaultCameraIp.
  ///
  /// In en, this message translates to:
  /// **'Default Camera IP Address'**
  String get settingsDefaultCameraIp;

  /// No description provided for @settingsPtpPortTile.
  ///
  /// In en, this message translates to:
  /// **'PTP/IP Port'**
  String get settingsPtpPortTile;

  /// No description provided for @settingsRestoreDefaultIpTile.
  ///
  /// In en, this message translates to:
  /// **'Restore Nikon Z Default Hotspot Preset'**
  String get settingsRestoreDefaultIpTile;

  /// No description provided for @settingsRestoredDefaultIpToast.
  ///
  /// In en, this message translates to:
  /// **'Restored default Nikon Z hotspot IP and port'**
  String get settingsRestoredDefaultIpToast;

  /// No description provided for @settingsAndroidNetworkSection.
  ///
  /// In en, this message translates to:
  /// **'Android Networking'**
  String get settingsAndroidNetworkSection;

  /// No description provided for @settingsAutoBindTitle.
  ///
  /// In en, this message translates to:
  /// **'Force Wi-Fi NIC Binding'**
  String get settingsAutoBindTitle;

  /// No description provided for @settingsAutoBindSub.
  ///
  /// In en, this message translates to:
  /// **'Route traffic through camera Wi-Fi even when mobile data is active'**
  String get settingsAutoBindSub;

  /// No description provided for @settingsKeepAliveSection.
  ///
  /// In en, this message translates to:
  /// **'Session Keep-Alive'**
  String get settingsKeepAliveSection;

  /// No description provided for @settingsKeepAliveToggleTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep Camera Wi-Fi Alive in Background'**
  String get settingsKeepAliveToggleTitle;

  /// No description provided for @settingsHeartbeatTitle.
  ///
  /// In en, this message translates to:
  /// **'PTP/IP Heartbeat Interval'**
  String get settingsHeartbeatTitle;

  /// No description provided for @settingsHeartbeatValue.
  ///
  /// In en, this message translates to:
  /// **'15s (Prevents camera sleep)'**
  String get settingsHeartbeatValue;

  /// No description provided for @settingsShootTransferSection.
  ///
  /// In en, this message translates to:
  /// **'Shoot & Transfer'**
  String get settingsShootTransferSection;

  /// No description provided for @settingsDownloadRawTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync RAW Files'**
  String get settingsDownloadRawTitle;

  /// No description provided for @settingsDownloadRawSub.
  ///
  /// In en, this message translates to:
  /// **'Also download NEF / NRW files'**
  String get settingsDownloadRawSub;

  /// No description provided for @settingsDeleteConfirmSection.
  ///
  /// In en, this message translates to:
  /// **'Deletion & Confirmation'**
  String get settingsDeleteConfirmSection;

  /// No description provided for @settingsConfirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Before Deleting'**
  String get settingsConfirmDeleteTitle;

  /// No description provided for @settingsConfirmDeleteSub.
  ///
  /// In en, this message translates to:
  /// **'When off, selecting a deletion scope executes immediately'**
  String get settingsConfirmDeleteSub;

  /// No description provided for @settingsPowerProtectionSection.
  ///
  /// In en, this message translates to:
  /// **'Low-Battery Transfer Protection'**
  String get settingsPowerProtectionSection;

  /// No description provided for @settingsPowerProtectionToggle.
  ///
  /// In en, this message translates to:
  /// **'Enable Low-Battery Protection'**
  String get settingsPowerProtectionToggle;

  /// No description provided for @settingsPowerThresholdTile.
  ///
  /// In en, this message translates to:
  /// **'Pause Threshold'**
  String get settingsPowerThresholdTile;

  /// No description provided for @settingsHysteresisTitle.
  ///
  /// In en, this message translates to:
  /// **'Hysteresis Resume (+5%)'**
  String get settingsHysteresisTitle;

  /// No description provided for @settingsHysteresisValue.
  ///
  /// In en, this message translates to:
  /// **'Resumes automatically at threshold +5%'**
  String get settingsHysteresisValue;

  /// No description provided for @settingsActiveTransferRuleTitle.
  ///
  /// In en, this message translates to:
  /// **'In-Flight File Handling'**
  String get settingsActiveTransferRuleTitle;

  /// No description provided for @settingsActiveTransferRuleValue.
  ///
  /// In en, this message translates to:
  /// **'Finishes current file before pausing (no truncation)'**
  String get settingsActiveTransferRuleValue;

  /// No description provided for @settingsLogsSection.
  ///
  /// In en, this message translates to:
  /// **'Protocol Diagnostics'**
  String get settingsLogsSection;

  /// No description provided for @settingsViewLogsTile.
  ///
  /// In en, this message translates to:
  /// **'View Handshake & Protocol Logs'**
  String get settingsViewLogsTile;

  /// No description provided for @settingsClearLogsTile.
  ///
  /// In en, this message translates to:
  /// **'Clear Diagnostic Logs'**
  String get settingsClearLogsTile;

  /// No description provided for @settingsClearedLogsToast.
  ///
  /// In en, this message translates to:
  /// **'All diagnostic logs cleared'**
  String get settingsClearedLogsToast;

  /// No description provided for @settingsLogsViewerTitle.
  ///
  /// In en, this message translates to:
  /// **'Protocol & Handshake Logs'**
  String get settingsLogsViewerTitle;

  /// No description provided for @settingsCopyAllLogsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy All Logs'**
  String get settingsCopyAllLogsTooltip;

  /// No description provided for @settingsCopiedLogsToast.
  ///
  /// In en, this message translates to:
  /// **'Copied all logs to clipboard'**
  String get settingsCopiedLogsToast;

  /// No description provided for @settingsClearLogsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear Logs'**
  String get settingsClearLogsTooltip;

  /// No description provided for @settingsLogsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic logs yet'**
  String get settingsLogsEmpty;

  /// No description provided for @settingsVersionSection.
  ///
  /// In en, this message translates to:
  /// **'Version & Updates'**
  String get settingsVersionSection;

  /// No description provided for @settingsAppVersionTile.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get settingsAppVersionTile;

  /// No description provided for @settingsCheckUpdateTile.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get settingsCheckUpdateTile;

  /// No description provided for @settingsCheckUpdateValue.
  ///
  /// In en, this message translates to:
  /// **'Online Check (GitHub)'**
  String get settingsCheckUpdateValue;

  /// No description provided for @settingsTechSection.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get settingsTechSection;

  /// No description provided for @settingsDriverArchTile.
  ///
  /// In en, this message translates to:
  /// **'Driver Stack'**
  String get settingsDriverArchTile;

  /// No description provided for @settingsUiSystemTile.
  ///
  /// In en, this message translates to:
  /// **'Design System'**
  String get settingsUiSystemTile;

  /// No description provided for @settingsUiSystemValue.
  ///
  /// In en, this message translates to:
  /// **'Zync Pro Darkroom Design System'**
  String get settingsUiSystemValue;

  /// No description provided for @settingsProjectSection.
  ///
  /// In en, this message translates to:
  /// **'Project & Licenses'**
  String get settingsProjectSection;

  /// No description provided for @settingsRepoUrlTile.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get settingsRepoUrlTile;

  /// No description provided for @settingsOpenSourceCreditsTile.
  ///
  /// In en, this message translates to:
  /// **'Open-Source Credits'**
  String get settingsOpenSourceCreditsTile;

  /// No description provided for @settingsOpenSourceCreditsSub.
  ///
  /// In en, this message translates to:
  /// **'Core references, protocol research, and runtime packages'**
  String get settingsOpenSourceCreditsSub;

  /// No description provided for @settingsCreditsCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String settingsCreditsCountValue(int count);

  /// No description provided for @settingsLicenseDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'License Notice'**
  String get settingsLicenseDisclaimerTitle;

  /// No description provided for @settingsLicenseDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Copyrights and licenses belong to their respective authors. Unlicensed projects are referenced solely for protocol interoperability.'**
  String get settingsLicenseDisclaimerBody;

  /// No description provided for @settingsCreditsCoreGroup.
  ///
  /// In en, this message translates to:
  /// **'Core Projects & Protocol References'**
  String get settingsCreditsCoreGroup;

  /// No description provided for @settingsCreditsRuntimeGroup.
  ///
  /// In en, this message translates to:
  /// **'Runtime & Foundation Libraries'**
  String get settingsCreditsRuntimeGroup;

  /// No description provided for @settingsAppLicenseTile.
  ///
  /// In en, this message translates to:
  /// **'Application License'**
  String get settingsAppLicenseTile;

  /// No description provided for @settingsCannotOpenUrlToast.
  ///
  /// In en, this message translates to:
  /// **'Unable to open repository URL'**
  String get settingsCannotOpenUrlToast;

  /// No description provided for @updateDefaultChangelog.
  ///
  /// In en, this message translates to:
  /// **'Bug fixes and stability improvements.'**
  String get updateDefaultChangelog;

  /// No description provided for @updateCheckingToast.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateCheckingToast;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Check Failed'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateCheckFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the update server. Check your internet connection or visit GitHub Releases.'**
  String get updateCheckFailedBody;

  /// No description provided for @updateUpToDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Up to Date'**
  String get updateUpToDateTitle;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In en, this message translates to:
  /// **'Zync v{version} is already the latest release.\nSource: {source}'**
  String updateUpToDateBody(String version, String source);

  /// No description provided for @updateCheckErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Error'**
  String get updateCheckErrorTitle;

  /// No description provided for @updateOpenWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub'**
  String get updateOpenWebsite;

  /// No description provided for @updatePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get updatePreparing;

  /// No description provided for @updateInstallerFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not launch installer. Check install-unknown-apps permission or download via browser.'**
  String get updateInstallerFailedToast;

  /// No description provided for @updateBrowserDownload.
  ///
  /// In en, this message translates to:
  /// **'Browser Download'**
  String get updateBrowserDownload;

  /// No description provided for @updateSkippedVersionToast.
  ///
  /// In en, this message translates to:
  /// **'Skipped v{version}; will not prompt again on startup'**
  String updateSkippedVersionToast(String version);

  /// No description provided for @updateNewVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'New Version Available'**
  String get updateNewVersionTitle;

  /// No description provided for @updateSourceGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub Release'**
  String get updateSourceGithub;

  /// No description provided for @updateChangelogHeader.
  ///
  /// In en, this message translates to:
  /// **'What\'s New'**
  String get updateChangelogHeader;

  /// No description provided for @updatePackageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Package size: {size}'**
  String updatePackageSizeLabel(String size);

  /// No description provided for @updateDownloadingPct.
  ///
  /// In en, this message translates to:
  /// **'Downloading: {percent}%'**
  String updateDownloadingPct(String percent);

  /// No description provided for @updateSkipThisVersion.
  ///
  /// In en, this message translates to:
  /// **'Skip Version'**
  String get updateSkipThisVersion;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateInstallNow.
  ///
  /// In en, this message translates to:
  /// **'Install Now'**
  String get updateInstallNow;

  /// No description provided for @updateDownloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download & Install'**
  String get updateDownloadAndInstall;

  /// No description provided for @updateOpenInBrowserTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download in Browser'**
  String get updateOpenInBrowserTooltip;

  /// No description provided for @updateSha256MismatchError.
  ///
  /// In en, this message translates to:
  /// **'APK SHA-256 verification failed; installation aborted'**
  String get updateSha256MismatchError;

  /// No description provided for @hubTitle.
  ///
  /// In en, this message translates to:
  /// **'Studio Hub'**
  String get hubTitle;

  /// No description provided for @hubBentoQuickTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Transfer'**
  String get hubBentoQuickTransferTitle;

  /// No description provided for @hubBentoQuickTransferSub.
  ///
  /// In en, this message translates to:
  /// **'Browse and sync camera photos to phone'**
  String get hubBentoQuickTransferSub;

  /// No description provided for @hubBentoWatermarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Watermark Studio'**
  String get hubBentoWatermarkTitle;

  /// No description provided for @hubBentoWatermarkSub.
  ///
  /// In en, this message translates to:
  /// **'Frames, photocard & film color grading'**
  String get hubBentoWatermarkSub;

  /// No description provided for @hubBentoCollageTitle.
  ///
  /// In en, this message translates to:
  /// **'Collage Studio'**
  String get hubBentoCollageTitle;

  /// No description provided for @hubBentoCollageSub.
  ///
  /// In en, this message translates to:
  /// **'Multi-photo layout storytelling'**
  String get hubBentoCollageSub;

  /// No description provided for @hubBentoTransfersTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get hubBentoTransfersTitle;

  /// No description provided for @hubBentoTransfersIdle.
  ///
  /// In en, this message translates to:
  /// **'Queue idle'**
  String get hubBentoTransfersIdle;

  /// No description provided for @hubBentoTransfersActive.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks in progress'**
  String hubBentoTransfersActive(int count);

  /// No description provided for @hubRecentPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Photos'**
  String get hubRecentPhotosTitle;

  /// No description provided for @hubRecentPhotosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recent photos'**
  String get hubRecentPhotosEmpty;

  /// No description provided for @hubShootAndTransferQuick.
  ///
  /// In en, this message translates to:
  /// **'Auto-Transfer'**
  String get hubShootAndTransferQuick;

  /// No description provided for @hubHelpGuideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connection guide'**
  String get hubHelpGuideTooltip;

  /// No description provided for @hubGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Connection Guide'**
  String get hubGuideTitle;

  /// No description provided for @hubGuideWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi Direct Connection'**
  String get hubGuideWifiTitle;

  /// No description provided for @hubGuideWifiBody.
  ///
  /// In en, this message translates to:
  /// **'1. Turn on \"Connect to smart device\" or Wi-Fi mode in camera menu\n2. Join camera hotspot in phone Wi-Fi settings (e.g., NIKON_...)\n3. Return here and tap \"Connect Now\" to establish PTP/IP session'**
  String get hubGuideWifiBody;

  /// No description provided for @hubGuideUsbTitle.
  ///
  /// In en, this message translates to:
  /// **'USB OTG Connection'**
  String get hubGuideUsbTitle;

  /// No description provided for @hubGuideUsbBody.
  ///
  /// In en, this message translates to:
  /// **'1. Connect phone and camera via USB-C or OTG adapter\n2. Power on the camera\n3. Grant USB permission when prompted and tap \"Connect Now\"'**
  String get hubGuideUsbBody;

  /// No description provided for @hubGuideClose.
  ///
  /// In en, this message translates to:
  /// **'Got It'**
  String get hubGuideClose;

  /// No description provided for @connectOneTapUsb.
  ///
  /// In en, this message translates to:
  /// **'Connect USB Camera'**
  String get connectOneTapUsb;

  /// No description provided for @connectSelectWifi.
  ///
  /// In en, this message translates to:
  /// **'Select Wi-Fi'**
  String get connectSelectWifi;

  /// No description provided for @connectQuickConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Now'**
  String get connectQuickConnect;

  /// No description provided for @connectUsbDetectedHeader.
  ///
  /// In en, this message translates to:
  /// **'USB Camera Detected'**
  String get connectUsbDetectedHeader;

  /// No description provided for @connectWifiDetectedHeader.
  ///
  /// In en, this message translates to:
  /// **'Current Wi-Fi Network'**
  String get connectWifiDetectedHeader;

  /// No description provided for @wmDockTemplate.
  ///
  /// In en, this message translates to:
  /// **'Frame Style'**
  String get wmDockTemplate;

  /// No description provided for @wmDockFilter.
  ///
  /// In en, this message translates to:
  /// **'Film Preset'**
  String get wmDockFilter;

  /// No description provided for @wmDockGrade.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get wmDockGrade;

  /// No description provided for @wmDockGeometry.
  ///
  /// In en, this message translates to:
  /// **'Geometry'**
  String get wmDockGeometry;

  /// No description provided for @wmSubPalette.
  ///
  /// In en, this message translates to:
  /// **'Colors & Margin'**
  String get wmSubPalette;

  /// No description provided for @wmSubToggles.
  ///
  /// In en, this message translates to:
  /// **'Display & Text'**
  String get wmSubToggles;

  /// No description provided for @wmSubTypography.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get wmSubTypography;

  /// No description provided for @wmSubLogo.
  ///
  /// In en, this message translates to:
  /// **'Brand Logo'**
  String get wmSubLogo;

  /// No description provided for @wmHistogramHudTooltip.
  ///
  /// In en, this message translates to:
  /// **'Histogram HUD'**
  String get wmHistogramHudTooltip;

  /// No description provided for @wmDialResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get wmDialResetAll;

  /// No description provided for @wmDialTransferToGrade.
  ///
  /// In en, this message translates to:
  /// **'To Adjustments'**
  String get wmDialTransferToGrade;

  /// No description provided for @wmDialSaveAsPreset.
  ///
  /// In en, this message translates to:
  /// **'Save Preset'**
  String get wmDialSaveAsPreset;

  /// No description provided for @wmDialCategoryPreset.
  ///
  /// In en, this message translates to:
  /// **'★ Presets'**
  String get wmDialCategoryPreset;

  /// No description provided for @wmDialPresetCustomGroup.
  ///
  /// In en, this message translates to:
  /// **'My Presets'**
  String get wmDialPresetCustomGroup;

  /// No description provided for @wmDialSavePresetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter preset name'**
  String get wmDialSavePresetPrompt;

  /// No description provided for @wmDialSavePresetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved preset \"{name}\"'**
  String wmDialSavePresetSuccess(String name);

  /// No description provided for @wmDialActiveLutButton.
  ///
  /// In en, this message translates to:
  /// **'Choose 3D LUT File'**
  String get wmDialActiveLutButton;

  /// No description provided for @wmDialNoLutChosen.
  ///
  /// In en, this message translates to:
  /// **'No LUT file loaded'**
  String get wmDialNoLutChosen;

  /// No description provided for @wmExportMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Quality'**
  String get wmExportMenuTitle;

  /// No description provided for @galleryTabCameraCard.
  ///
  /// In en, this message translates to:
  /// **'Camera Card'**
  String get galleryTabCameraCard;

  /// No description provided for @galleryTabExportedPhoneShort.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get galleryTabExportedPhoneShort;

  /// No description provided for @galleryActionSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get galleryActionSelectAll;

  /// No description provided for @galleryActionDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect'**
  String get galleryActionDeselect;

  /// No description provided for @galleryExifDetailSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'EXIF Details'**
  String get galleryExifDetailSheetTitle;

  /// No description provided for @galleryCollageDirectModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Photos for Collage (2-9)'**
  String get galleryCollageDirectModeTitle;

  /// No description provided for @wmViewModeListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Single-item list with scrollbar'**
  String get wmViewModeListTooltip;

  /// No description provided for @wmViewModePagedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Adaptive height paged view'**
  String get wmViewModePagedTooltip;

  /// No description provided for @wmTabletTuneAction.
  ///
  /// In en, this message translates to:
  /// **'Tune'**
  String get wmTabletTuneAction;

  /// No description provided for @wmTabletSectionTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get wmTabletSectionTemplates;

  /// No description provided for @wmTabletSectionStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get wmTabletSectionStyle;

  /// No description provided for @wmTabletPagePrev.
  ///
  /// In en, this message translates to:
  /// **'Prev'**
  String get wmTabletPagePrev;

  /// No description provided for @wmTabletPageNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get wmTabletPageNext;

  /// No description provided for @wmTabletPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String wmTabletPageIndicator(Object current, Object total);

  /// No description provided for @wmTabletPureGradeHint.
  ///
  /// In en, this message translates to:
  /// **'Currently in pure color grade mode without watermark frame'**
  String get wmTabletPureGradeHint;

  /// No description provided for @wmTabletPureGradeAction.
  ///
  /// In en, this message translates to:
  /// **'Choose Template'**
  String get wmTabletPureGradeAction;

  /// No description provided for @navPictureControl.
  ///
  /// In en, this message translates to:
  /// **'Color Recipes'**
  String get navPictureControl;

  /// No description provided for @pcStudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Picture Control'**
  String get pcStudioTitle;

  /// No description provided for @pcImportFilesAction.
  ///
  /// In en, this message translates to:
  /// **'Import NP3/ZIP'**
  String get pcImportFilesAction;

  /// No description provided for @pcBatchWriteAction.
  ///
  /// In en, this message translates to:
  /// **'Batch Write'**
  String get pcBatchWriteAction;

  /// No description provided for @pcRestoreBuiltinTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore Built-in Recipes'**
  String get pcRestoreBuiltinTooltip;

  /// No description provided for @pcTabLocalLibrary.
  ///
  /// In en, this message translates to:
  /// **'Local Library ({count})'**
  String pcTabLocalLibrary(Object count);

  /// No description provided for @pcTabCameraSlots.
  ///
  /// In en, this message translates to:
  /// **'Camera Slots C1–C9'**
  String get pcTabCameraSlots;

  /// No description provided for @pcStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Camera disconnected · Browse & manage local NP3/NCP recipes'**
  String get pcStatusDisconnected;

  /// No description provided for @pcStatusVerified.
  ///
  /// In en, this message translates to:
  /// **'{model} · Verified C1–C9 Direct Write (0x90CD)'**
  String pcStatusVerified(Object model);

  /// No description provided for @pcStatusExperimental.
  ///
  /// In en, this message translates to:
  /// **'{model} · Experimental C1–C9 Direct Write (0x90CD)'**
  String pcStatusExperimental(Object model);

  /// No description provided for @pcStatusUnsupported.
  ///
  /// In en, this message translates to:
  /// **'{model} · Camera does not advertise 0x90CD write support'**
  String pcStatusUnsupported(Object model);

  /// No description provided for @pcApproxPreviewBadge.
  ///
  /// In en, this message translates to:
  /// **'Approximate Preview'**
  String get pcApproxPreviewBadge;

  /// No description provided for @pcPickCustomSampleAction.
  ///
  /// In en, this message translates to:
  /// **'Custom Photo'**
  String get pcPickCustomSampleAction;

  /// No description provided for @pcResetSampleAction.
  ///
  /// In en, this message translates to:
  /// **'Built-in Samples'**
  String get pcResetSampleAction;

  /// No description provided for @pcFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get pcFilterAll;

  /// No description provided for @pcCurveTitle.
  ///
  /// In en, this message translates to:
  /// **'Tone Curve (257-pt 15-bit LUT)'**
  String get pcCurveTitle;

  /// No description provided for @pcCurveLinearHint.
  ///
  /// In en, this message translates to:
  /// **'Standard linear tone response (no custom curve block)'**
  String get pcCurveLinearHint;

  /// No description provided for @pcParamsTitle.
  ///
  /// In en, this message translates to:
  /// **'Picture Control Parameters'**
  String get pcParamsTitle;

  /// No description provided for @pcParamBase.
  ///
  /// In en, this message translates to:
  /// **'Base'**
  String get pcParamBase;

  /// No description provided for @pcParamSharpening.
  ///
  /// In en, this message translates to:
  /// **'Sharpening'**
  String get pcParamSharpening;

  /// No description provided for @pcParamMidSharpening.
  ///
  /// In en, this message translates to:
  /// **'Mid-Range Sharp'**
  String get pcParamMidSharpening;

  /// No description provided for @pcParamClarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get pcParamClarity;

  /// No description provided for @pcParamContrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get pcParamContrast;

  /// No description provided for @pcParamBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get pcParamBrightness;

  /// No description provided for @pcParamSaturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get pcParamSaturation;

  /// No description provided for @pcParamHue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get pcParamHue;

  /// No description provided for @pcParamMonoFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get pcParamMonoFilter;

  /// No description provided for @pcParamMonoToning.
  ///
  /// In en, this message translates to:
  /// **'Toning'**
  String get pcParamMonoToning;

  /// No description provided for @pcFcSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Flexible Color (0310) Tone & Color Blender'**
  String get pcFcSectionTitle;

  /// No description provided for @pcFcConvertHint.
  ///
  /// In en, this message translates to:
  /// **'Direct C1–C9 write requires Standard NP3 (0300) or NCP (0100). Convert this Flexible Color recipe to a Standard NP3 to write to camera.'**
  String get pcFcConvertHint;

  /// No description provided for @pcFcConvertButton.
  ///
  /// In en, this message translates to:
  /// **'Convert to Std NP3'**
  String get pcFcConvertButton;

  /// No description provided for @pcFcConvertedToast.
  ///
  /// In en, this message translates to:
  /// **'Created Standard NP3 \"{name}\" ready for C1–C9 write'**
  String pcFcConvertedToast(Object name);

  /// No description provided for @pcWriteToCameraButton.
  ///
  /// In en, this message translates to:
  /// **'Write to Camera C1–C9'**
  String get pcWriteToCameraButton;

  /// No description provided for @pcWriteDisabledFcTooltip.
  ///
  /// In en, this message translates to:
  /// **'Convert Flexible Color recipe to Standard NP3 first'**
  String get pcWriteDisabledFcTooltip;

  /// No description provided for @pcRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get pcRenameAction;

  /// No description provided for @pcShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share / Export'**
  String get pcShareAction;

  /// No description provided for @pcRenameDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename Recipe'**
  String get pcRenameDialogTitle;

  /// No description provided for @pcRenameCameraField.
  ///
  /// In en, this message translates to:
  /// **'In-Camera Name (ASCII, max 19 chars)'**
  String get pcRenameCameraField;

  /// No description provided for @pcRenameCameraHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored in binary tag 0x200 and displayed on camera C1–C9 menus'**
  String get pcRenameCameraHelper;

  /// No description provided for @pcRenameNoteField.
  ///
  /// In en, this message translates to:
  /// **'Local Display Note (shown in Zync only)'**
  String get pcRenameNoteField;

  /// No description provided for @pcRenameSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Renamed recipe to \"{name}\"'**
  String pcRenameSavedToast(Object name);

  /// No description provided for @pcDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Local Recipe'**
  String get pcDeleteConfirmTitle;

  /// No description provided for @pcDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" from your local library?'**
  String pcDeleteConfirmBody(Object name);

  /// No description provided for @pcImportReportToast.
  ///
  /// In en, this message translates to:
  /// **'Imported {imported} recipes ({duplicates} duplicates skipped, {invalid} invalid)'**
  String pcImportReportToast(
      Object duplicates, Object imported, Object invalid);

  /// No description provided for @pcRefreshSlotsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh Camera C1–C9 Slots'**
  String get pcRefreshSlotsTooltip;

  /// No description provided for @pcSlotEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Empty Slot · No custom Picture Control stored'**
  String get pcSlotEmptyLabel;

  /// No description provided for @pcSlotActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active (0xD200)'**
  String get pcSlotActiveBadge;

  /// No description provided for @pcSlotSetActiveButton.
  ///
  /// In en, this message translates to:
  /// **'Set Active'**
  String get pcSlotSetActiveButton;

  /// No description provided for @pcSlotActivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Switched active Picture Control to {slot}'**
  String pcSlotActivatedToast(Object slot);

  /// No description provided for @pcSlotActivateFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to switch active slot; ensure camera is in P/S/A/M mode'**
  String get pcSlotActivateFailedToast;

  /// No description provided for @pcSlotOverwriteButton.
  ///
  /// In en, this message translates to:
  /// **'Write Recipe'**
  String get pcSlotOverwriteButton;

  /// No description provided for @pcSlotBackupToLocalButton.
  ///
  /// In en, this message translates to:
  /// **'Backup to Phone'**
  String get pcSlotBackupToLocalButton;

  /// No description provided for @pcSlotBackupSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Backed up {slot} \"{name}\" to local .NP3 library'**
  String pcSlotBackupSuccessToast(Object name, Object slot);

  /// No description provided for @pcWriteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Write to Camera Slot C1–C9'**
  String get pcWriteDialogTitle;

  /// No description provided for @pcWriteDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose target custom Picture Control slot for \"{name}\" (overwrites selected slot):'**
  String pcWriteDialogSubtitle(Object name);

  /// No description provided for @pcWriteSetActiveCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Set as active Picture Control (0xD200) immediately after writing'**
  String get pcWriteSetActiveCheckbox;

  /// No description provided for @pcWriteConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Write & Verify'**
  String get pcWriteConfirmButton;

  /// No description provided for @pcWriteSuccessToast.
  ///
  /// In en, this message translates to:
  /// **'Wrote {slot} ({name}); camera slots refreshed to confirm'**
  String pcWriteSuccessToast(Object name, Object slot);

  /// No description provided for @pcWriteFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Write failed: {error} (Ensure camera is in P/S/A/M mode)'**
  String pcWriteFailedToast(Object error);

  /// No description provided for @pcWriteVerifyFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Could not find the recipe in {slot} after writing. Check the camera state and try again.'**
  String pcWriteVerifyFailedToast(Object slot);

  /// No description provided for @pcBatchDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Batch Write to C1–C9'**
  String get pcBatchDialogTitle;

  /// No description provided for @pcBatchDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign Standard NP3/NCP recipes to slots C1–C9 (unassigned slots remain unchanged):'**
  String get pcBatchDialogSubtitle;

  /// No description provided for @pcBatchSlotKeepUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Keep unchanged (skip)'**
  String get pcBatchSlotKeepUnchanged;

  /// No description provided for @pcBatchStartWriteButton.
  ///
  /// In en, this message translates to:
  /// **'Start Batch Write ({count})'**
  String pcBatchStartWriteButton(Object count);

  /// No description provided for @pcBatchSummaryToast.
  ///
  /// In en, this message translates to:
  /// **'Batch write complete: {success} succeeded, {failed} failed'**
  String pcBatchSummaryToast(Object failed, Object success);

  /// No description provided for @pcDisconnectedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera Not Connected'**
  String get pcDisconnectedEmptyTitle;

  /// No description provided for @pcDisconnectedEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Connect your Nikon camera via Wi-Fi or USB OTG (in P/S/A/M mode) to read, write, and activate custom Picture Control slots C1–C9.'**
  String get pcDisconnectedEmptySub;

  /// No description provided for @videoEnterEditor.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get videoEnterEditor;

  /// No description provided for @videoPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get videoPlay;

  /// No description provided for @videoPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get videoPause;

  /// No description provided for @videoLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get videoLoading;

  /// No description provided for @pcCategoryPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get pcCategoryPortrait;

  /// No description provided for @pcCategoryLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get pcCategoryLandscape;

  /// No description provided for @pcCategoryStreet.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get pcCategoryStreet;

  /// No description provided for @pcCategoryFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get pcCategoryFilm;

  /// No description provided for @pcCategoryCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get pcCategoryCinematic;

  /// No description provided for @pcCategoryAiry.
  ///
  /// In en, this message translates to:
  /// **'Airy Pastel'**
  String get pcCategoryAiry;

  /// No description provided for @pcCategoryNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get pcCategoryNight;

  /// No description provided for @pcCategoryMono.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get pcCategoryMono;

  /// No description provided for @pcApproxBadge.
  ///
  /// In en, this message translates to:
  /// **'Approx Fit'**
  String get pcApproxBadge;

  /// No description provided for @pcCompareSplitHint.
  ///
  /// In en, this message translates to:
  /// **'Drag divider to compare'**
  String get pcCompareSplitHint;

  /// No description provided for @pcCompareOriginalLabel.
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get pcCompareOriginalLabel;

  /// No description provided for @pcCompareEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Effect'**
  String get pcCompareEffectLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
