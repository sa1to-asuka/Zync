// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Zync - ニコン Z シリーズ転送＆現像スタジオ';

  @override
  String get navConnect => '接続';

  @override
  String get navGallery => 'カメラロール';

  @override
  String get navWatermark => 'ウォーターマーク工房';

  @override
  String get navSettings => '設定';

  @override
  String get exitConfirmHint => 'もう一度戻るを押すと Zync を終了します';

  @override
  String get sidebarCollapse => 'サイドバーを折りたたむ';

  @override
  String get sidebarExpand => 'サイドバーを展開';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonConfirm => '確認';

  @override
  String get commonSave => '保存';

  @override
  String get commonDone => '完了';

  @override
  String get commonReset => 'リセット';

  @override
  String get commonDelete => '削除';

  @override
  String get commonApply => '適用';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonRemove => '削除';

  @override
  String get commonClear => 'クリア';

  @override
  String get commonMore => 'その他';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonExit => '終了';

  @override
  String get commonYes => 'はい';

  @override
  String get commonNo => 'いいえ';

  @override
  String get commonGotIt => '了解';

  @override
  String get commonExport => '書き出し';

  @override
  String get commonImport => '読み込み';

  @override
  String get commonEdit => '編集';

  @override
  String get commonUndo => '元に戻す';

  @override
  String get commonRedo => 'やり直し';

  @override
  String get commonOriginal => '元画像';

  @override
  String get commonCompare => '比較';

  @override
  String get commonCustom => 'カスタム';

  @override
  String get commonDefault => 'デフォルト';

  @override
  String get commonNone => 'なし';

  @override
  String get commonAll => 'すべて';

  @override
  String get commonView => '表示';

  @override
  String get commonRefresh => '更新';

  @override
  String get commonUnknownError => '不明なエラー';

  @override
  String get commonUnknownSize => 'サイズ不明';

  @override
  String get commonSupported => '対応';

  @override
  String get commonUnsupported => '非対応';

  @override
  String get commonOn => 'オン';

  @override
  String get commonOff => 'オフ';

  @override
  String get commonDisabled => 'オフ';

  @override
  String get commonSuccess => '成功';

  @override
  String get commonFailed => '失敗';

  @override
  String get commonWarning => '警告';

  @override
  String get langSystem => 'システム設定に従う';

  @override
  String get langSystemDesc => '端末の言語に合わせる（未対応時は英語）';

  @override
  String get langEn => 'English';

  @override
  String get langEnSub => '英語インターフェース';

  @override
  String get langZh => '简体中文';

  @override
  String get langZhSub => '簡体字中国語インターフェース';

  @override
  String get langJa => '日本語';

  @override
  String get langJaSub => '日本語インターフェース';

  @override
  String get themeSystem => 'システム設定に従う';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeSystemSub => '端末の外観モードに合わせて自動切替';

  @override
  String get themeLightSub => '柔らかなニュートラルライトと落ち着いたティールアクセント';

  @override
  String get themeDarkSub => '正確な色評価のためのニュートラルグラファイト暗室テーマ';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingBack => '戻る';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => 'スタジオを開く';

  @override
  String onboardingStepOf(int current, int total) {
    return 'ステップ $current / $total';
  }

  @override
  String get onboardingLangTitle => '表示言語を選択';

  @override
  String get onboardingLangSubtitle => 'タップするとすぐに切り替わります。後から「設定」でいつでも変更できます。';

  @override
  String get onboardingThemeTitle => '外観モードを選択';

  @override
  String get onboardingThemeSubtitle =>
      '写真の色彩を邪魔しないニュートラルなグラファイト基調と落ち着いたティールを採用しています。';

  @override
  String get onboardingThemePreviewTitle => 'ライブプレビュー';

  @override
  String get onboardingThemePreviewSub =>
      'NIKON Z 8 · NIKKOR Z 50mm f/1.2 S · 1/500s f/1.8 ISO 100';

  @override
  String get onboardingConnTitle => 'ニコンカメラ直結ワークフロー';

  @override
  String get onboardingConnSubtitle =>
      'アカウント登録不要でカメラに直結。RAW・JPEGの閲覧から転送、カラーグレーディング、透かし書き出しまで完結します。';

  @override
  String get onboardingConnWifiTitle => 'Wi-Fi PTP/IP ワイヤレス接続';

  @override
  String get onboardingConnWifiDesc =>
      'カメラのWi-Fiアクセスポイントに接続し、ワイヤレス閲覧・高速転送・撮影時自動転送を行えます。';

  @override
  String get onboardingConnUsbTitle => 'USB OTG 有線ダイレクト接続';

  @override
  String get onboardingConnUsbDesc =>
      'Type-C OTGケーブル（MTP/PTPモード）で大容量のNEF RAWや動画を安定して高速転送できます。';

  @override
  String get onboardingConnStudioTitle => '16-Bit RAW現像・動画・ウォーターマーク工房';

  @override
  String get onboardingConnStudioDesc =>
      'LibRawによる16-bit現像、3D LUT動画グレーディング、EXIFギャラリーフレーム書き出しに対応。';

  @override
  String get connectDetecting => '<検出中...>';

  @override
  String get connectModeWifi => 'カメラ Wi-Fi';

  @override
  String get connectModeUsb => 'USB 有線';

  @override
  String get connectModeBle => 'BLE 実験';

  @override
  String get connectWifiWarnTitle => '現在の Wi-Fi はカメラのアクセスポイントではない可能性があります';

  @override
  String connectWifiWarnBody(String ssid) {
    return '現在のネットワーク: $ssid\nこのまま PTP/IP 接続を試行しますか？';
  }

  @override
  String get connectContinueAttempt => '接続を試行';

  @override
  String connectFailedToast(String error) {
    return '接続に失敗しました: $error';
  }

  @override
  String connectWifiFailedToast(String error) {
    return '接続に失敗しました: $error\nヒント: 先に端末の Wi-Fi 設定でカメラのアクセスポイントに接続してください。';
  }

  @override
  String get connectDisconnectedToast => 'カメラとの接続を切断し、ネットワークバインドを解放しました';

  @override
  String connectUsbScanResult(int total, int ready) {
    return '$total 台の USB カメラを検出（$ready 台が PTP 接続可能）';
  }

  @override
  String connectUsbScanFailed(String error) {
    return 'USB デバイスのスキャンに失敗しました: $error';
  }

  @override
  String connectUsbModeSwitchHint(String name, String mode) {
    return '$name は現在 $mode です。カメラメニューで USB 接続モードを MTP/PTP に切り替えてから再読み込みしてください。';
  }

  @override
  String get connectUsbUnsupportedDriver => '現在のドライバーは USB 接続に対応していません';

  @override
  String get connectUsbPermissionDenied => 'USB アクセス権限が拒否されました';

  @override
  String get connectUsbFailedTitle => 'USB 接続に失敗しました';

  @override
  String connectUsbFailedToast(String error) {
    return 'USB 接続に失敗しました: $error';
  }

  @override
  String get connectUsbTroubleHeader => '確認事項：';

  @override
  String get connectUsbTroubleStep1 =>
      '1. カメラメニューで USB モードを MTP/PTP に設定してください（マスストレージ不可）；';

  @override
  String get connectUsbTroubleStep2 =>
      '2. データ転送対応の OTG ケーブルで端末に直結してください（USB ハブ非推奨）；';

  @override
  String get connectUsbTroubleStep3 => '3. ケーブルを抜き差ししてから USB デバイスを再読み込みしてください。';

  @override
  String get connectBleStoppedToast => 'Bluetooth スキャンを停止しました';

  @override
  String get connectBleStartFailedToast =>
      'Bluetooth スキャンを開始できません。Bluetooth と付近のデバイス権限を確認してください。';

  @override
  String get connectBlePairSuccessToast => 'Bluetooth ペアリングハンドシェイクを開始しました！';

  @override
  String connectBleFailedToast(String error) {
    return 'Bluetooth 接続に失敗しました: $error';
  }

  @override
  String get connectMyCamera => 'マイカメラ';

  @override
  String get connectDisconnectShort => '切断';

  @override
  String get connectHeroTitle => 'Zync · ニコン Z シリーズ';

  @override
  String get connectHeroSubtitle => 'ニコン Z シリーズ向けプロ用転送＆ダークルームスタジオ';

  @override
  String connectStatusConnectedBanner(String mode, String endpoint) {
    return '接続済み  $mode · $endpoint';
  }

  @override
  String get connectCameraBrand => 'ブランド';

  @override
  String get connectCameraModel => 'モデル';

  @override
  String get connectBrowsePhotos => 'カメラ内の写真を閲覧';

  @override
  String get connectLensSectionTitle => '装着レンズ';

  @override
  String get connectLensIdentified => '認識済み';

  @override
  String get connectLensUnread => '未取得';

  @override
  String get connectLensFocalRange => '焦点距離範囲';

  @override
  String get connectLensCurrentFocal => '現在の焦点距離';

  @override
  String get connectLensCurrentAperture => '現在の絞り値';

  @override
  String get connectDisconnectFull => 'カメラとの接続を切断してネットワークを解放';

  @override
  String get connectCurrentWifiLabel => '現在の Wi-Fi';

  @override
  String get connectRedetectWifiTooltip => 'Wi-Fi を再検出';

  @override
  String get connectWifiReadyHint => 'カメラのネットワークに接続済みです。下のボタンでセッションを開始します。';

  @override
  String get connectWifiJoinHint =>
      '端末の Wi-Fi 設定でカメラのアクセスポイント（例: NIKON_...）に接続してください';

  @override
  String get connectOpenSystemWifi => 'システムの Wi-Fi 設定を開く';

  @override
  String get connectConnectingButton => '接続中...';

  @override
  String get connectWifiButton => 'カメラに接続 (Wi-Fi ダイレクト)';

  @override
  String get connectBlePhoneOn => 'Bluetooth オン';

  @override
  String get connectBlePhoneOff => 'Bluetooth オフ';

  @override
  String get connectStateConnected => '接続済み';

  @override
  String get connectStatePairing => 'ペアリング中';

  @override
  String get connectStateDisconnected => '未接続';

  @override
  String connectBlePairedDevice(String name) {
    return 'ペアリング先: $name';
  }

  @override
  String get connectBleRemoteTitle => 'ワイヤレスリモートシャッター (ML-L7)';

  @override
  String get connectBleHalfPress => '半押し AF';

  @override
  String get connectBleFullPress => '全押し撮影';

  @override
  String get connectBleStopScan => 'スキャン停止';

  @override
  String get connectBleStartScan => '付近の BLE デバイスをスキャン';

  @override
  String connectBleDiscoveredCount(int count) {
    return '検出されたカメラ ($count)';
  }

  @override
  String connectBleDeviceMeta(String address, int rssi) {
    return 'MAC: $address | 信号強度: $rssi dBm';
  }

  @override
  String get connectBleSearching => '付近のカメラと BLE デバイスを検索中...';

  @override
  String get connectUsbSectionTitle => 'USB OTG 有線接続';

  @override
  String get connectUsbPrepTitle => '接続の準備';

  @override
  String get connectUsbPrepSub => 'Type-C OTG データケーブルでカメラと端末を直結';

  @override
  String get connectUsbMenuTitle => 'カメラメニュー設定';

  @override
  String get connectUsbMenuSub => 'カメラメニュー -> USB 接続 -> MTP/PTP に設定';

  @override
  String get connectUsbHostStatus => 'USB ホスト状態';

  @override
  String get connectUsbHostConnected => '有線接続済み';

  @override
  String get connectUsbHostWaiting => 'デバイス待機中';

  @override
  String get connectUsbChecking => 'USB を確認中...';

  @override
  String get connectUsbRefresh => 'USB デバイスを更新';

  @override
  String get connectUsbEmptyHint =>
      'USB カメラが検出されません。OTG ケーブルの接続、カメラの電源、PTP モード設定を確認してください。';

  @override
  String get connectUsbPermissionGrantedSuffix => ' · 許可済み';

  @override
  String get connectUsbPermissionNeededSuffix => ' · 権限が必要';

  @override
  String get statusCameraDisconnected => 'カメラ未接続';

  @override
  String get statusSdCard => 'SDカード';

  @override
  String get statusTapToConnect => 'タップして接続';

  @override
  String get galleryTabCamera => 'カメラ内の写真';

  @override
  String galleryTabExportedCount(int count) {
    return '書き出し履歴 ($count)';
  }

  @override
  String get galleryTabExportedPhone => '書き出し履歴 (端末アルバム)';

  @override
  String get galleryFilterAll => 'すべて';

  @override
  String get galleryFilterUnsynced => '未同期';

  @override
  String get galleryFilterSynced => '同期済み';

  @override
  String get gallerySlotSelectTitle => 'カードスロット選択';

  @override
  String get gallerySlotAllMerged => '全ストレージ (自動統合)';

  @override
  String get gallerySlot1 => 'スロット 1 (Slot 1)';

  @override
  String get gallerySlot2 => 'スロット 2 (Slot 2)';

  @override
  String get galleryCollageButton => 'コラージュ';

  @override
  String get galleryTransferCenterTooltip => '転送センター';

  @override
  String get galleryRefreshCardTooltip => 'カードを再読み込み';

  @override
  String get galleryRefreshExportedTooltip => '書き出しアルバムを更新';

  @override
  String get galleryShootAndTransferBanner => '撮影時自動転送オン：シャッターを切ると元画像を自動同期します';

  @override
  String get galleryEnumeratingStorage => 'カメラのストレージ一覧を取得中 (0x1007)...';

  @override
  String get galleryEmptyCameraPhotos => 'カメラ内に写真が見つからないか、読み込み中です...';

  @override
  String galleryEmptyFilterPhotos(String filter) {
    return 'フィルター「$filter」に一致する写真はありません';
  }

  @override
  String get galleryReadyFooterHint => '準備完了：「設定」から通信やキャッシュの詳細を調整できます';

  @override
  String get galleryLocalMissingFallbackToast =>
      'ローカルファイルが見つからないため、カメラから読み込みます';

  @override
  String get galleryLoadingHighResTitle => '高解像度写真を読み込み中';

  @override
  String galleryLoadingHighResBody(String size) {
    return 'プレビューと透かしの画質を保つため、カメラから元画像（$size）を転送しています...';
  }

  @override
  String galleryLoadFailedToast(String error) {
    return 'カメラ内の写真読み込みに失敗しました: $error';
  }

  @override
  String galleryEnqueuedToast(int count) {
    return '転送キューに $count 件のファイルを追加しました';
  }

  @override
  String get galleryCollageNeed2To9 => 'コラージュには 2〜9 枚の写真を選択してください';

  @override
  String get galleryCollageMax9 => 'コラージュは最大 9 枚まで対応しています';

  @override
  String get galleryCollageNeedJpeg =>
      'コラージュには少なくとも 2 枚の JPEG 写真が必要です（RAW / 動画は非対応）';

  @override
  String get galleryCollageInsufficientCancelled =>
      '使用可能な写真が 2 枚未満のため、コラージュを中止しました';

  @override
  String get galleryCollageEnterTitle => 'コラージュを開始';

  @override
  String galleryCollageDownloadPrompt(
      int missing, String reusablePart, String skippedPart) {
    return 'コラージュ用に $missing 枚の写真をダウンロードします$reusablePart$skippedPart。完了後に自動でコラージュ画面を開きます。';
  }

  @override
  String galleryCollageReusablePart(int count) {
    return '（ローカルの $count 枚を再利用）';
  }

  @override
  String galleryCollageSkippedPart(int count) {
    return '（RAW / 動画 $count 件をスキップ）';
  }

  @override
  String get galleryConfirmDownload => 'ダウンロード開始';

  @override
  String get galleryExportFormatTitle => '書き出し形式を選択';

  @override
  String galleryExportFormatPrompt(int count) {
    return '選択した $count 枚には RAW + JPEG ペアが含まれています。書き出し方法を選択してください：';
  }

  @override
  String get galleryExportBothTitle => 'すべて書き出す (RAW + JPEG)';

  @override
  String get galleryExportBothSub => '最高画質の RAW データと撮って出し JPEG の両方を保存します';

  @override
  String get galleryExportJpegOnlyTitle => 'JPEG のみ (高速シェア推奨)';

  @override
  String get galleryExportJpegOnlySub => '撮って出し JPEG のみを高速転送し、ストレージを節約します';

  @override
  String galleryExportBatchSuccessToast(int count) {
    return '$count 枚の写真を端末アルバム (/DCIM/Zync) に書き出しました';
  }

  @override
  String get galleryExportingModalTitle => '端末へ写真を書き出し中';

  @override
  String get galleryExportingSocketNotice => 'ソケット競合を防ぐため通信チャネルを占有中です。';

  @override
  String galleryExportingSingleSize(String size) {
    return 'ファイルサイズ: $size';
  }

  @override
  String galleryExportingBatchProgress(int current, int total) {
    return 'バッチ進捗: $current / $total 枚目';
  }

  @override
  String get galleryExportingSavePath => '保存先: /DCIM/Zync (システムギャラリーに表示)';

  @override
  String get galleryCancelRemainingTasks => '残りのタスクを中止';

  @override
  String get galleryDeleteLocalOnlyTitle => 'ローカルのみ削除';

  @override
  String get galleryDeleteLocalOnlySub => '端末内のダウンロード済みファイルのみ削除し、カメラ内は残します';

  @override
  String get galleryDeleteBothTitle => 'ローカルとカメラの両方を削除';

  @override
  String get galleryDeleteBothSub => '先にカメラ内のファイルを削除し、続いてローカルコピーを削除します';

  @override
  String galleryDeleteGroupsTitle(int count) {
    return '$count 組のメディアを削除';
  }

  @override
  String get galleryDeleteGroupsPrompt =>
      '削除範囲を選択してください。RAW+JPG ペアはまとめて処理されます。';

  @override
  String get galleryConfirmDeleteTitle => '削除の確認';

  @override
  String galleryConfirmDeleteBothBody(int count) {
    return '$count 組のメディアをカメラのカードとローカルアルバムの両方から削除します。';
  }

  @override
  String galleryConfirmDeleteLocalBody(int count) {
    return '$count 組のメディアをローカルアルバムからのみ削除します（カメラ内は保持）。';
  }

  @override
  String get galleryIrreversibleHint => 'この操作は元に戻せません。';

  @override
  String get galleryDontAskAgain => '次回から表示しない';

  @override
  String galleryDeletedGroupsToast(int count) {
    return '$count 組のメディアを処理しました';
  }

  @override
  String galleryDeletedGroupsPartialLocalFailToast(
      int handled, int failed, int localFailed) {
    return '$handled 組を処理、$failed 組が失敗（うち $localFailed 組はカメラ側削除済み・ローカル削除失敗）';
  }

  @override
  String galleryDeletedGroupsFailToast(int handled, int failed) {
    return '$handled 組を処理、$failed 組が失敗（失敗項目は選択状態を維持）';
  }

  @override
  String gallerySelectionCameraSummary(int count, String size) {
    return '$count 組を選択中 · サイズ $size';
  }

  @override
  String get galleryLongPressSelectHint => '写真を長押しして複数選択モードに入り、同期する写真を選択してください';

  @override
  String get gallerySyncToPhoneButton => '端末へ同期';

  @override
  String gallerySelectionLocalSummary(int count, String size) {
    return '$count 枚選択中 · $size';
  }

  @override
  String galleryDeletedLocalToast(int count) {
    return '$count 枚のローカル写真を削除しました';
  }

  @override
  String galleryDeletedLocalPartialToast(int ok, int failed) {
    return '$ok 枚削除、$failed 枚失敗（失敗項目は選択状態を維持）';
  }

  @override
  String get galleryScanningExported => 'ローカルの書き出し済み写真をスキャン中...';

  @override
  String get galleryEmptyExportedTitle => '書き出し済みの写真はまだありません';

  @override
  String get galleryEmptyExportedSubtitle =>
      'カメラから転送した写真やウォーターマーク工房で保存した写真は、カメラ未接続でもここでいつでも閲覧・編集・共有できます。';

  @override
  String get galleryRefreshPhoneAlbum => '端末アルバムを再読み込み';

  @override
  String galleryExportedHeaderCount(int count) {
    return '端末 Zync アルバム · 書き出し済み $count 枚';
  }

  @override
  String get galleryBadgeExported => '書出済';

  @override
  String get galleryBadgePartial => '一部同期';

  @override
  String get galleryBadgeOverwrite => '上書き';

  @override
  String get galleryBadgeSaveAs => '別名保存';

  @override
  String get galleryRawDecodeFailedToast =>
      'RAW デコードに失敗しました。NEF/NRW ファイルか確認してください';

  @override
  String get galleryStreamingVideoToast => '編集キャッシュへ動画をストリーミング取得中…';

  @override
  String get galleryVideoDownloadFailedToast =>
      '動画のダウンロードに失敗しました。接続を確認して再試行してください';

  @override
  String get galleryPhotoInfoTitle => '写真の詳細';

  @override
  String get galleryPreviewLoadingOriginal => 'プレビュー・元画像を読み込み中…';

  @override
  String get galleryLoadingOriginalShort => '元画像を読み込み中…';

  @override
  String get galleryCaptureParamsTitle => '撮影パラメータ';

  @override
  String get galleryExifShutter => 'シャッター';

  @override
  String get galleryExifAperture => '絞り';

  @override
  String get galleryExifFocal => '焦点距離';

  @override
  String get galleryExifCamera => 'カメラ';

  @override
  String get galleryExifLens => 'レンズ';

  @override
  String get galleryActionWatermarkGrade => '透かし / カラー調整';

  @override
  String get galleryActionProRawGrade => 'RAW 現像';

  @override
  String get galleryNoPhotos => '写真なし';

  @override
  String get galleryActionGradeShort => 'カラー';

  @override
  String get galleryDeleteSingleTitle => 'この写真を削除しますか？';

  @override
  String galleryDeleteSingleBody(String name) {
    return '端末アルバムから $name を削除します（カメラ内のカードには影響しません）。この操作は元に戻せません。';
  }

  @override
  String get galleryDeleteFailedToast => '削除に失敗しました。もう一度お試しください';

  @override
  String galleryOpenEditorFailedToast(String error) {
    return 'エディターを開けませんでした: $error';
  }

  @override
  String get galleryRawNoEmbeddedPreviewToast =>
      'この RAW ファイルには埋め込みプレビューがないため開けません';

  @override
  String galleryLocalUnreadableToast(String error) {
    return 'ローカル写真を読み込めません: $error';
  }

  @override
  String get transferCenterTitle => '転送センター';

  @override
  String get transferEmptyTitle => '転送タスクはありません';

  @override
  String get transferEmptySubtitle => 'カメラロールで写真を長押しして同期するか、撮影時自動転送をオンにしてください';

  @override
  String transferActiveCount(int count) {
    return '転送中 $count';
  }

  @override
  String transferQueuedCount(int count) {
    return '待機中 $count';
  }

  @override
  String transferFailedCount(int count) {
    return '失敗 $count';
  }

  @override
  String get transferPausedTag => '一時停止中';

  @override
  String get transferResumeAll => 'すべて再開';

  @override
  String get transferPauseAll => 'すべて一時停止';

  @override
  String get transferRetryFailed => '失敗を再試行';

  @override
  String get transferClearCompleted => '完了をクリア';

  @override
  String get transferStatusQueued => '待機中';

  @override
  String transferStatusDownloadingPct(int percent) {
    return 'ダウンロード中 $percent%';
  }

  @override
  String get transferStatusCompleted => '完了';

  @override
  String transferStatusFailedReason(String reason) {
    return '失敗：$reason';
  }

  @override
  String get transferStatusCancelled => 'キャンセル済み';

  @override
  String get editorTitle => '画像編集';

  @override
  String editorSaveFailedToast(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get editorSaveSheetTitle => '編集結果を保存';

  @override
  String get editorSaveSheetSub => '上書きは元ファイルを置き換え、別名保存は新しい画像を作成します。';

  @override
  String get editorOverwriteTitle => '元画像を上書き';

  @override
  String get editorOverwriteSub => '既存の画像を置き換えます（失敗時は自動的に別名保存）';

  @override
  String get editorSaveAsNewTitle => '新規ファイルとして保存';

  @override
  String get editorSaveAsNewSub => '元画像を残し、_edit 付きの新規ファイルを作成します';

  @override
  String get editorOverwriteAndSaveBothFailed => '上書きと別名保存の両方に失敗しました';

  @override
  String get editorSaveAsFailed => '別名保存に失敗しました';

  @override
  String get editorOverwriteFallbackToast =>
      '上書きできなかったため、元画像を保持し別ファイルとして保存しました';

  @override
  String get editorOverwrittenToast => '元画像を上書きしました';

  @override
  String get editorSavedAsNewToast => '新規ファイルとして保存しました';

  @override
  String get editorPreparingPreview => '編集プレビューを準備中…';

  @override
  String get editorNoPhotoSelected => '写真が選択されていません';

  @override
  String get editorComparingHoldHint => '元画像と比較中 · 離すと戻ります';

  @override
  String get editorRotateLeft90 => '左へ 90° 回転';

  @override
  String get editorRotateRight90 => '右へ 90° 回転';

  @override
  String get editorResetAngle => '角度をリセット';

  @override
  String get editorFlipHorizontal => '左右反転';

  @override
  String get editorFlipVertical => '上下反転';

  @override
  String get editorResetDistortion => '歪みをリセット';

  @override
  String get editorToolRotate => '回転';

  @override
  String get editorToolFlip => '反転';

  @override
  String get editorToolPerspective => 'パース';

  @override
  String get editorToolDistortion => '歪み補正';

  @override
  String get editorToolFreeTransform => '自由変形';

  @override
  String get editorToolCrop => '切り抜き';

  @override
  String editorPerspectiveHorizontal(int value) {
    return '水平補正 $value';
  }

  @override
  String editorPerspectiveVertical(int value) {
    return '垂直補正 $value';
  }

  @override
  String get editorTransformScale => '拡大率';

  @override
  String get editorTransformPanX => '水平移動';

  @override
  String get editorTransformPanY => '垂直移動';

  @override
  String get editorCropAspectRatio => 'アスペクト比';

  @override
  String get histogramTitle => 'ヒストグラム';

  @override
  String get toneBlacks => '黒レベル';

  @override
  String get toneShadows => 'シャドウ';

  @override
  String get toneExposure => '露光量';

  @override
  String get toneHighlights => 'ハイライト';

  @override
  String get toneWhites => '白レベル';

  @override
  String get presetTitle => 'カラープリセット';

  @override
  String get presetTabBuiltin => '内蔵';

  @override
  String get presetTabMine => 'マイプリセット';

  @override
  String get presetScopeGlobal => '編集中：全体カラー調整';

  @override
  String get presetScopeClip => '編集中：現在のクリップ調整';

  @override
  String get presetSaveNew => '新規プリセットとして保存';

  @override
  String get presetSaveDialogTitle => 'プリセットを保存';

  @override
  String get presetSearchHint => 'プリセットを検索';

  @override
  String get presetSavedToast => 'プリセットを保存しました';

  @override
  String presetImportedToast(int count) {
    return '$count 件のプリセットを読み込みました';
  }

  @override
  String get presetImportFailedToast => 'プリセットファイルの読み込みに失敗しました';

  @override
  String get presetExportFailedToast => '書き出しに失敗しました';

  @override
  String get presetExportedToast => 'プリセットを Zync/exports に書き出しました';

  @override
  String get presetApplyAction => '適用';

  @override
  String get presetEmptyMatch => '一致するプリセットがありません';

  @override
  String get presetNoAdjustments => '調整なし';

  @override
  String get presetUnnamed => '名称未設定プリセット';

  @override
  String get videoReadMetaFailed => '動画メタデータを読み込めません';

  @override
  String get videoUnsupportedCodec => 'この動画を読み込めません。端末がコーデックに対応しているか確認してください';

  @override
  String get videoGeneratingProxyToast => '4秒のカラー/LUTプレビュープロキシを生成中…';

  @override
  String get videoProxyFailedToast => 'プレビュー生成に失敗しました。コーデック性能を確認してください';

  @override
  String get videoProxyReadyToast => 'プレビューを生成しました。右上から元映像/調整済みを切り替えられます';

  @override
  String get videoExportFailedToast => '動画の書き出しに失敗しました。エンコーダー性能を確認してください';

  @override
  String get videoExportSaveAlbumFailedToast => '書き出しは完了しましたが、アルバムへの保存に失敗しました';

  @override
  String get videoExportSuccessToast => '動画を DCIM/Zync に書き出しました';

  @override
  String get videoGeneratePreviewTooltip => 'カラープレビューを生成';

  @override
  String get videoRefreshGeneratePreview => 'プレビューを生成/更新';

  @override
  String get videoExportVideoAction => '動画を書き出す';

  @override
  String get videoGeneratingProxyOverlay => 'プレビュープロキシを生成中…';

  @override
  String get videoSkipProxyUseOriginal => 'プロキシをスキップして元映像を使用';

  @override
  String get videoBadge4sProxy => '4秒カラープロキシ';

  @override
  String get videoBadgeOriginalPreview => '元映像プレビュー・書き出し時にカラー/LUTを適用';

  @override
  String get videoBadgePreviewStale => 'プレビュー期限切れ';

  @override
  String get videoToggleGradedPreview => '調整済み';

  @override
  String get videoToggleOriginalPreview => '元映像';

  @override
  String get videoExitFullscreen => '全画面を終了';

  @override
  String get videoEnterFullscreen => '全画面プレビュー';

  @override
  String get videoTabTrim => 'トリム';

  @override
  String get videoTabGrade => 'カラー';

  @override
  String get videoTabAudio => 'オーディオ';

  @override
  String get videoTabScopes => 'スコープ';

  @override
  String get videoTimelineClipsHeader => 'タイムラインクリップ';

  @override
  String get videoAddLocalClipTooltip => 'ローカル動画クリップを追加';

  @override
  String videoClipIndexLabel(int index) {
    return 'クリップ $index';
  }

  @override
  String get videoMoveClipEarlier => '前へ移動';

  @override
  String get videoMoveClipLater => '後ろへ移動';

  @override
  String get videoTrimRangeLabel => 'トリム範囲';

  @override
  String get videoSplitClipAction => '分割';

  @override
  String get videoDeleteClipAction => 'クリップを削除';

  @override
  String videoChapterDefaultTitle(int index) {
    return 'チャプター $index';
  }

  @override
  String get videoAddChapterButton => 'チャプター追加';

  @override
  String get videoChapterNavHeader => 'チャプターナビ';

  @override
  String get videoGlobalGradeTitle => '全体カラー調整';

  @override
  String get videoGlobalGradeOnSub => 'タイムライン上の全クリップに適用';

  @override
  String get videoGlobalGradeOffSub => '現在のクリップのみに適用';

  @override
  String get videoGlobalGradeHint =>
      '全体調整は各クリップの個別調整の前に適用されます。キーフレームはクリップごとに記録されます。';

  @override
  String get videoKeyframeParamLabel => 'キーフレーム項目';

  @override
  String get videoAddKeyframeButton => 'キーフレーム追加';

  @override
  String get videoKeyframeListHeader => 'キーフレーム一覧';

  @override
  String get videoPresetEntryTitle => 'カラープリセット：保存 / 適用 / 読み込み・書き出し';

  @override
  String get videoCopiedGlobalGradeToast => '全体カラー調整をコピーしました';

  @override
  String get videoCopiedClipGradeToast => '現在のクリップ調整をコピーしました';

  @override
  String get videoCopyGradeAction => 'カラーをコピー';

  @override
  String get videoPasteGradeAction => 'カラーを貼り付け';

  @override
  String get videoRefresh4sPreview => '4秒プレビューを更新';

  @override
  String get videoGenerate4sPreview => '4秒プレビューを生成';

  @override
  String videoGlobalGradeStatusChip(String status) {
    return '全体調整：$status';
  }

  @override
  String get videoStatusEnabled => '有効';

  @override
  String videoKeyframeCountChip(int count) {
    return 'キーフレーム：$count 個';
  }

  @override
  String videoWheelHue(String wheel) {
    return '$wheel 色相';
  }

  @override
  String videoWheelSaturation(String wheel) {
    return '$wheel 彩度';
  }

  @override
  String videoWheelLuma(String wheel) {
    return '$wheel 輝度';
  }

  @override
  String get videoCurveLinear => 'リニア';

  @override
  String get videoCurveEaseInOut => 'イーズイン/アウト';

  @override
  String get videoLutGlobalTitle => '全体 LUT カラー適用';

  @override
  String get videoLutClipTitle => '現在のクリップ LUT 適用';

  @override
  String get videoLutPathHint => '.cube / PNG LUT ファイルパス';

  @override
  String get videoPickLutTooltip => 'LUT ファイルを選択';

  @override
  String get videoApplyLutAction => 'LUT を適用';

  @override
  String get videoLutIntensityLabel => 'LUT 強度';

  @override
  String get videoColorUnlabeled => '未指定';

  @override
  String videoSourceColorLabel(String label) {
    return 'ソース色空間：$label';
  }

  @override
  String videoHdrToneMapHint(String label) {
    return 'HDR ソース（$label）を検出しました。書き出し時は SDR Rec.709 にトーンマップされます。N-Log は LUT と併用してください。';
  }

  @override
  String get videoSdrSourceHint =>
      'SDR ソース：追加の HDR マッピングなしで現在のカラー調整と LUT を適用します。';

  @override
  String get videoAudioMute => 'ミュート';

  @override
  String get videoAudioVolume => '音量';

  @override
  String get videoAudioFadeIn => 'フェードイン（秒）';

  @override
  String get videoAudioFadeOut => 'フェードアウト（秒）';

  @override
  String get videoExportSettingsHeader => '書き出し設定';

  @override
  String videoHwHevcStatus(String status) {
    return 'ハードウェア HEVC デコード：$status';
  }

  @override
  String get videoExport4k60Note =>
      '4K/60 はベストエフォート対応です。端末のエンコーダーが非対応の場合は元映像を保持します。';

  @override
  String get videoNoHevc10BitWarning =>
      'HEVC Main10 ハードウェアデコードが未検出です。書き出し前に 4 秒プレビューで確認してください。';

  @override
  String get videoCodecLabel => 'コーデック';

  @override
  String get videoCodecH264 => 'H.264（高互換）';

  @override
  String get videoCodecHevc => 'HEVC（高圧縮）';

  @override
  String get videoCodecHevcUnsupported => 'HEVC（端末非対応）';

  @override
  String get videoResolutionLabel => '解像度';

  @override
  String get videoFpsLabel => 'フレームレート';

  @override
  String get videoBitrateLabel => 'ビットレート';

  @override
  String get videoBitrate20 => '標準 20 Mbps';

  @override
  String get videoBitrate40 => '高画質 40 Mbps';

  @override
  String get videoBitrate80 => 'プロ 80 Mbps';

  @override
  String videoExportingProgressHint(int percent) {
    return '書き出し中 $percent% · アプリをフォアグラウンドに保ってください';
  }

  @override
  String get videoCancelExport => '書き出しを中止';

  @override
  String get videoExportToDcimButton => 'DCIM/Zync に書き出す';

  @override
  String get scopeTitle => 'ビデオスコープ';

  @override
  String get scopeCaptureFrameTooltip => '現在のフレームを取得';

  @override
  String get scopeWaveform => '波形モニター';

  @override
  String get scopeVectorscope => 'ベクトルスコープ';

  @override
  String get scopeAnalyzing => '現在のフレームを解析中…';

  @override
  String get scopeEmptyHint => '右上の更新ボタンで現在のフレームを取得します';

  @override
  String get scopeLumaHistogram => '輝度ヒストグラム';

  @override
  String get scopePeak => 'ピーク';

  @override
  String get scopeAverage => '平均';

  @override
  String get scopeBlackLevel => '黒レベル';

  @override
  String get scopeHighlightClip => 'ハイライトクリップ';

  @override
  String get scopeShadowClip => 'シャドウクリップ';

  @override
  String get wmStudioTitle => '透かし工房';

  @override
  String get wmPickFromAlbumTooltip => '端末アルバムから選択';

  @override
  String get wmStyleSettingsTooltip => '透かし設定（スタイル / 内容 / テキスト / ロゴ）';

  @override
  String get wmExportQualityTitle => '書き出し品質';

  @override
  String wmExportQualityMenuLabel(String label, int quality) {
    return '書き出し品質：$label（q$quality）';
  }

  @override
  String get exportQualityOriginal => '最高画質';

  @override
  String get exportQualityStandard => '標準';

  @override
  String get exportQualityCompact => '省容量';

  @override
  String get wmSaveHighResTooltip => '高解像度写真をアルバムに保存';

  @override
  String get wmShowingOriginalBadge => '元画像を表示中';

  @override
  String get wmHoldToCompareHint => '長押しで比較';

  @override
  String get wmPickPhotoEmptyPrompt => 'ローカル写真を選択してカラー調整・透かしを追加';

  @override
  String get wmEditExifTag => 'EXIF 編集';

  @override
  String get wmTabWatermark => '透かし';

  @override
  String get wmTabColorGrade => 'カラー調整';

  @override
  String get wmTabPhotoEdit => '切り抜き・変形';

  @override
  String get wmPureGradeModeTitle => '現在【カラー調整のみモード】です';

  @override
  String get wmPureGradeModeSub => 'フレームやテキストを追加せず、元画像の解像度のまま書き出します。';

  @override
  String get wmGoToGradeButton => 'カラー調整へ';

  @override
  String get wmBorderColorShort => 'フレーム色';

  @override
  String get wmTextColorShort => '文字色';

  @override
  String get wmDetailSettingsShort => '詳細設定';

  @override
  String get wmGradeCatTone => '基本トーン';

  @override
  String get wmGradeCatWb => 'ホワイトバランス';

  @override
  String get wmGradeCatPresence => 'ディテール・質感';

  @override
  String get wmGradeCatSplit => 'カラーグレーディング';

  @override
  String get wmGradeCatFilm => 'フィルムプリセット';

  @override
  String get wmGradeCatEffects => 'レンズ・効果';

  @override
  String get wmCurrentModeNoWatermark => '現在のモード: カラー調整のみ (透かしなし)';

  @override
  String wmCurrentTemplateLabel(String name) {
    return '現在の透かし: $name';
  }

  @override
  String get wmEnableWatermarkSwitch => '透かしを有効化';

  @override
  String get wmDisableWatermarkSwitch => '透かしをオフ (カラーのみ)';

  @override
  String wmImportedExifToast(String title) {
    return '写真を読み込み、EXIF パラメータ（$title）を自動抽出しました';
  }

  @override
  String get wmDecodeImageFailed => '画像のデコードに失敗しました';

  @override
  String wmParseImageFailed(String error) {
    return '画像の解析に失敗しました: $error';
  }

  @override
  String get wmSelectPhotoFirstHint =>
      '右上のアルバムアイコンから写真を選択するか、カメラロールから読み込んでください';

  @override
  String get wmRawFullDecodeFailed => 'フルサイズ RAW デコードに失敗しました';

  @override
  String get wmSaveAlbumFailed => 'システムアルバムへの保存に失敗しました';

  @override
  String wmSavedSuccessToast(int width, int height, String sizeMb) {
    return 'アルバムに保存しました · $width×$height · ${sizeMb}MB';
  }

  @override
  String get wmViewInAlbumAction => 'アルバムで表示';

  @override
  String wmExportFailedToast(String error) {
    return '書き出しに失敗しました: $error';
  }

  @override
  String get wmExifSheetTitle => '撮影パラメータの微調整';

  @override
  String get wmExifSheetSub => '非CPUレンズやEXIFなしの写真向けに、表示パラメータを自由に編集できます';

  @override
  String get wmExifCameraLabel => 'カメラモデル';

  @override
  String get wmExifCameraHint => '例: Z 30, Z 8, Z fc';

  @override
  String get wmExifLensLabel => 'レンズモデル';

  @override
  String get wmExifLensHint => '例: NIKKOR Z 40mm f/2';

  @override
  String get wmExifApertureLabel => '絞り値';

  @override
  String get wmExifApertureHint => '例: f/1.8';

  @override
  String get wmExifShutterLabel => 'シャッター速度';

  @override
  String get wmExifShutterHint => '例: 1/250s';

  @override
  String get wmExifIsoLabel => 'ISO 感度';

  @override
  String get wmExifIsoHint => '例: ISO 100';

  @override
  String get wmExifFocalLabel => '焦点距離';

  @override
  String get wmExifFocalHint => '例: 40mm';

  @override
  String get wmExifDateLabel => '撮影日時';

  @override
  String get wmExifDateHint => '例: 2026.10.06 14:32';

  @override
  String get wmExifApplyButton => 'パラメータを適用';

  @override
  String get wmSettingsSheetTitle => '透かし詳細設定';

  @override
  String get wmSettingsSheetSub =>
      '配色・文字サイズ・余白・表示項目は自動保存されます（ロゴ画像は現在のセッションのみ保持）';

  @override
  String get wmLogoSectionTitle => 'ロゴオーバーレイ';

  @override
  String get wmLogoReadFailedToast => 'ロゴ画像の読み込みに失敗しました';

  @override
  String get wmLogoPickButton => 'ロゴを選択';

  @override
  String get wmLogoChangeButton => 'ロゴを変更';

  @override
  String get wmLogoSizeLabel => 'ロゴサイズ';

  @override
  String get wmLogoOpacityLabel => 'ロゴ不透明度';

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
  String get wmOpacityLight => '薄め';

  @override
  String get wmLogoPositionLabel => 'ロゴ位置';

  @override
  String get adjExposure => '露光量';

  @override
  String get adjExposureDesc => '画面全体の明るさを調整 (-2EV 〜 +2EV)';

  @override
  String get adjContrast => 'コントラスト';

  @override
  String get adjContrastDesc => '明暗のメリハリを強める、または柔らかくする';

  @override
  String get adjHighlights => 'ハイライト';

  @override
  String get adjHighlightsDesc => '白飛びを抑えるか、明部の階調を引き上げる';

  @override
  String get adjShadows => 'シャドウ';

  @override
  String get adjShadowsDesc => '暗部のディテールを持ち上げるか、影を引き締める';

  @override
  String get adjWhites => '白レベル';

  @override
  String get adjWhitesDesc => 'ハイライトの白クリップポイントりを微調整';

  @override
  String get adjBlacks => '黒レベル';

  @override
  String get adjBlacksDesc => '暗部の黒締まりポイントを微調整';

  @override
  String get adjTemperature => '色温度';

  @override
  String get adjTemperatureDesc => '左で寒色ブルー、右で暖色アンバーにシフト';

  @override
  String get adjTint => '色かぶり補正';

  @override
  String get adjTintDesc => '左でグリーン寄り、右でマゼンタ寄りに補正';

  @override
  String get adjClarity => '明瞭度';

  @override
  String get adjClarityDesc => '中間調のマイクロコントラストを調整して立体感を強調';

  @override
  String get adjTexture => 'テクスチャ';

  @override
  String get adjTextureDesc => '左で肌を滑らかに、右で微細な表面ディテールを強調';

  @override
  String get adjDehaze => 'かすみの除去';

  @override
  String get adjDehazeDesc => '逆光や霧のかすみを除去し、抜けの良い画面に';

  @override
  String get adjVibrance => '自然な彩度';

  @override
  String get adjVibranceDesc => '肌色を保護しながら控えめな色域の彩度を自然に持ち上げる';

  @override
  String get adjSaturation => '彩度';

  @override
  String get adjSaturationDesc => '全体の色の濃さ（-100 でモノクロ、+100 で高彩度）';

  @override
  String get adjSplitToningInfo =>
      'スプリットトーニング：ハイライトとシャドウに個別の色味を加え、映画的な色分離を作ります。';

  @override
  String get adjHighlightHue => 'ハイライト色相';

  @override
  String get adjHighlightHueDesc => 'ハイライトの色相 (0°〜360°)、ウォームゴールドは35°〜45°付近';

  @override
  String get adjHighlightSat => 'ハイライト彩度';

  @override
  String get adjHighlightSatDesc => 'ハイライトへの色味の強さ (0%〜100%)';

  @override
  String get adjShadowHue => 'シャドウ色相';

  @override
  String get adjShadowHueDesc => 'シャドウの色相 (0°〜360°)、クールティールは200°〜220°付近';

  @override
  String get adjShadowSat => 'シャドウ彩度';

  @override
  String get adjShadowSatDesc => 'シャドウへの色味の強さ (0%〜100%)';

  @override
  String get adjMidtones => 'ミッドトーン';

  @override
  String get adjSharpening => 'シャープネス';

  @override
  String get adjNoiseReduction => 'ノイズ軽減';

  @override
  String get adjLensDistortion => 'レンズ歪み補正';

  @override
  String get adjLensVignette => '周辺光量補正';

  @override
  String get adjLensVignetteDesc => '右でシネマ風の周辺減光、左で明るいビネットを追加';

  @override
  String get adjChromaticAberration => '色収差補正';

  @override
  String get adjFilmGrain => 'フィルム粒子';

  @override
  String get adjFilmGrainDesc => '銀塩フィルム特有の有機的な粒状感をシミュレート';

  @override
  String get adjToneCurve => 'トーンカーブ';

  @override
  String get adjColorWheel => 'カラーホイール';

  @override
  String wmFilterAllCount(int count) {
    return 'すべて ($count)';
  }

  @override
  String wmRecipeSummaryPrefix(String summary) {
    return 'カメラレシピ: $summary';
  }

  @override
  String get wmPresetIntensity => 'プリセット強度';

  @override
  String get wmProRawSectionEntry => 'プロ調整：LUT / ノイズ軽減 / シャープネス / レンズ補正';

  @override
  String wmLoadedFilterSlidersToast(String name) {
    return '【$name】の全パラメータをスライダーに読み込みました';
  }

  @override
  String wmLoadFilterToSlidersButton(String name) {
    return '【$name】の値をスライダーに読み込む（微調整）';
  }

  @override
  String get wmProRawSheetTitle => 'プロ RAW・レンズ調整';

  @override
  String get wmStyleFollowTemplate => 'テンプレートに従う';

  @override
  String get wmStylePureWhite => 'ピュアホワイト';

  @override
  String get wmStyleDeepBlack => 'ディープブラック';

  @override
  String get wmStyleCream => 'ウォームクリーム';

  @override
  String get wmStyleNikonGold => 'アンバーゴールド';

  @override
  String get wmStyleCyan => 'ティールシアン';

  @override
  String get wmStyleMagenta => 'マゼンタ';

  @override
  String get wmStyleDarkGrey => 'グラファイトグレー';

  @override
  String get wmStyleCustomColorTitle => 'カスタムカラー';

  @override
  String get wmStyleColorsSection => 'カラー設定';

  @override
  String get wmStyleFrameBgLabel => 'フレーム / 背景色';

  @override
  String get wmStyleTextColorLabel => 'テキスト色';

  @override
  String get wmStyleAccentColorLabel => 'アクセント色';

  @override
  String get wmStyleTypographySection => 'タイポグラフィと余白';

  @override
  String get wmStyleTitleScale => 'タイトルサイズ';

  @override
  String get wmStyleMetaScale => 'パラメータサイズ';

  @override
  String get wmStyleCustomTextScale => 'カスタム文字サイズ';

  @override
  String get wmStyleLetterSpacing => '文字間隔';

  @override
  String get wmStyleLineSpacing => '行間';

  @override
  String get wmStyleLineThickness => 'ライン太さ';

  @override
  String get wmStyleMarginScale => '余白比率';

  @override
  String get wmStyleCornerRadius => 'カードの角丸';

  @override
  String get wmStyleOpacity => '不透明度';

  @override
  String get wmStyleFontFamily => 'フォント';

  @override
  String get wmStyleFontDefault => '標準';

  @override
  String get wmStyleFontSerif => 'セリフ';

  @override
  String get wmStyleFontMono => '等幅';

  @override
  String get wmStyleFontCondensed => 'コンデンス';

  @override
  String get wmStyleFontWeight => 'ウェイト';

  @override
  String get wmStyleWeightRegular => '標準';

  @override
  String get wmStyleWeightMedium => 'ミディアム';

  @override
  String get wmStyleWeightBold => 'ボールド';

  @override
  String get wmStyleWeightBlack => 'ヘビー';

  @override
  String get wmStyleContentSection => '表示コンテンツ';

  @override
  String get wmStyleShowModel => 'カメラモデル';

  @override
  String get wmStyleShowLens => 'レンズ名';

  @override
  String get wmStyleShowExposure => '露出パラメータ';

  @override
  String get wmStyleShowDate => '撮影日付';

  @override
  String get wmStyleShowDetails => '撮影時刻と詳細を表示';

  @override
  String get wmStyleCustomTextSection => 'カスタムテキスト';

  @override
  String get wmStyleCustomLine1Label => 'カスタムテキスト 1';

  @override
  String get wmStyleCustomLine1Hint => '例: © 2026 Your Name';

  @override
  String get wmStyleCustomLine2Label => 'カスタムテキスト 2';

  @override
  String get wmStyleCustomLine2Hint => '例: Nikon Z 30';

  @override
  String get wmStyleTextAlign => '文字揃え';

  @override
  String get wmStyleAlignLeft => '左揃え';

  @override
  String get wmStyleAlignCenter => '中央揃え';

  @override
  String get wmStyleAlignRight => '右揃え';

  @override
  String get wmCornerTopLeft => '左上';

  @override
  String get wmCornerTopRight => '右上';

  @override
  String get wmCornerBottomLeft => '左下';

  @override
  String get wmCornerBottomRight => '右下';

  @override
  String get collageTitle => 'コラージュ';

  @override
  String get collageInsufficientPhotos => '使用可能な写真が 2 枚未満のためコラージュできません';

  @override
  String collageSkippedUnreadableToast(int count) {
    return '読み込めない写真 $count 枚をスキップしました';
  }

  @override
  String get collageSaveSuccessTitle => 'コラージュをアルバムに保存しました';

  @override
  String get collageSaveSuccessBody => 'システムアルバム (Pictures/Zync) に保存されました。';

  @override
  String get collagePreparingMaterials => 'コラージュ素材を準備中...';

  @override
  String get collageWatermarkDragHint =>
      '透かしテンプレート適用中。各セルを直接ドラッグ・ピンチして構図を調整できます。';

  @override
  String get collageTabLayout => 'レイアウト';

  @override
  String get collageTabWatermark => '透かし';

  @override
  String get collageNoWatermark => '透かしなし';

  @override
  String get collageMethodLabel => 'レイアウト方式';

  @override
  String get collageAspectLabel => '比率';

  @override
  String get collageBorderLabel => '枠線';

  @override
  String get collageOutputResolution => '出力解像度';

  @override
  String get collageFileSize => 'ファイルサイズ';

  @override
  String get collageSharedWatermarkSub => 'ウォーターマーク工房と配色・文字サイズ・余白設定を共有します';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGroupPreferences => '環境設定';

  @override
  String get settingsGroupSystem => 'システムと情報';

  @override
  String get settingsAppearanceTitle => '外観と表示';

  @override
  String get settingsAppearanceSub => 'システム・ライト・ダークモード';

  @override
  String get settingsLanguageTitle => '表示言語';

  @override
  String get settingsLanguageSub => 'English · 简体中文 · 日本語';

  @override
  String get settingsCameraTitle => 'カメラ接続';

  @override
  String get settingsCameraSub => 'IP・ポート・ネットワークバインド';

  @override
  String get settingsWirelessTitle => 'ワイヤレスと転送';

  @override
  String get settingsWirelessSub => '接続維持・RAW同期・書き出し品質';

  @override
  String get settingsKeepAliveOnShort => '接続維持オン';

  @override
  String get settingsKeepAliveOffShort => '接続維持オフ';

  @override
  String get settingsBatteryTitle => 'バッテリーと転送保護';

  @override
  String get settingsBatterySub => '低バッテリー時の一時停止と自動再開';

  @override
  String settingsThresholdValue(int threshold) {
    return 'しきい値 $threshold%';
  }

  @override
  String get settingsLogsTitle => '診断と通信ログ';

  @override
  String get settingsLogsSub => 'プロトコルハンドシェイクと通信記録';

  @override
  String settingsLogsCountValue(int count) {
    return '$count 件の記録';
  }

  @override
  String get settingsAboutTitle => 'Zync について';

  @override
  String get settingsAboutSub => 'バージョン・更新・オープンソースライセンス';

  @override
  String get settingsReplayOnboardingTitle => 'ウェルカムガイド';

  @override
  String get settingsReplayOnboardingSub => '初回起動時の言語・外観・接続ガイドをもう一度表示します';

  @override
  String get settingsAppearanceModeSection => '外観モード';

  @override
  String get settingsColorPreviewSection => 'パレットプレビュー';

  @override
  String get settingsColorPreviewTileTitle => '背景 / サーフェス / アクセント';

  @override
  String get settingsConfigIpTitle => 'カメラ IP アドレスの設定';

  @override
  String get settingsConfigIpSub => 'ニコン Z シリーズの標準ゲートウェイは 192.168.0.1 です';

  @override
  String get settingsIpAddressField => 'IP アドレス';

  @override
  String get settingsConfigPortTitle => 'PTP/IP ポートの設定';

  @override
  String get settingsConfigPortSub => 'ニコン PTP/IP 標準通信ポートは 15740 です';

  @override
  String get settingsPortField => 'ポート番号';

  @override
  String get settingsPtpNetworkSection => 'PTP/IP ネットワーク';

  @override
  String get settingsDefaultCameraIp => '標準カメラ IP アドレス';

  @override
  String get settingsPtpPortTile => 'PTP/IP 通信ポート';

  @override
  String get settingsRestoreDefaultIpTile => 'ニコン Z 標準アクセスポイント設定に戻す';

  @override
  String get settingsRestoredDefaultIpToast => 'ニコン Z 標準の IP アドレスとポートに戻しました';

  @override
  String get settingsAndroidNetworkSection => 'Android ネットワーク';

  @override
  String get settingsAutoBindTitle => 'Wi-Fi ネットワーク強制バインド';

  @override
  String get settingsAutoBindSub => 'モバイルデータ有効時でもカメラの Wi-Fi を優先使用します';

  @override
  String get settingsKeepAliveSection => 'セッション維持';

  @override
  String get settingsKeepAliveToggleTitle => 'バックグラウンドで Wi-Fi 接続を維持';

  @override
  String get settingsHeartbeatTitle => 'PTP/IP ハートビート間隔';

  @override
  String get settingsHeartbeatValue => '15秒 (カメラのスリープ防止)';

  @override
  String get settingsShootTransferSection => '撮影時自動転送';

  @override
  String get settingsDownloadRawTitle => 'RAW ファイルを同期';

  @override
  String get settingsDownloadRawSub => 'NEF / NRW ファイルも同時にダウンロード';

  @override
  String get settingsDeleteConfirmSection => '削除と確認';

  @override
  String get settingsConfirmDeleteTitle => '削除前に再確認する';

  @override
  String get settingsConfirmDeleteSub => 'オフにすると、削除範囲を選択した時点で即座に削除されます';

  @override
  String get settingsPowerProtectionSection => '低バッテリー転送保護';

  @override
  String get settingsPowerProtectionToggle => '低バッテリー転送保護を有効化';

  @override
  String get settingsPowerThresholdTile => '一時停止しきい値';

  @override
  String get settingsHysteresisTitle => 'ヒステリシス自動再開 (+5%)';

  @override
  String get settingsHysteresisValue => 'しきい値 +5% まで回復すると自動再開';

  @override
  String get settingsActiveTransferRuleTitle => '転送中ファイルの扱い';

  @override
  String get settingsActiveTransferRuleValue => '現在のファイル書き込み完了後に一時停止（破損防止）';

  @override
  String get settingsLogsSection => 'プロトコル通信診断';

  @override
  String get settingsViewLogsTile => 'ハンドシェイクと通信ログを表示';

  @override
  String get settingsClearLogsTile => '通信診断ログをクリア';

  @override
  String get settingsClearedLogsToast => 'すべてのログをクリアしました';

  @override
  String get settingsLogsViewerTitle => '低レベル通信＆ハンドシェイクログ';

  @override
  String get settingsCopyAllLogsTooltip => '全ログをコピー';

  @override
  String get settingsCopiedLogsToast => 'すべての通信ログをクリップボードにコピーしました';

  @override
  String get settingsClearLogsTooltip => 'ログをクリア';

  @override
  String get settingsLogsEmpty => '通信ログはまだありません';

  @override
  String get settingsVersionSection => 'バージョンと更新';

  @override
  String get settingsAppVersionTile => 'アプリバージョン';

  @override
  String get settingsCheckUpdateTile => 'アップデートを確認';

  @override
  String get settingsCheckUpdateValue => 'オンライン確認 (GitHub)';

  @override
  String get settingsTechSection => '技術情報';

  @override
  String get settingsDriverArchTile => 'ドライバー構成';

  @override
  String get settingsUiSystemTile => 'デザインシステム';

  @override
  String get settingsUiSystemValue => 'Zync Pro Darkroom デザインシステム';

  @override
  String get settingsProjectSection => 'プロジェクトとライセンス';

  @override
  String get settingsRepoUrlTile => 'リポジトリ URL';

  @override
  String get settingsOpenSourceCreditsTile => 'オープンソース謝辞';

  @override
  String get settingsOpenSourceCreditsSub => '主要プロジェクト・プロトコル参考・ランタイム依存関係';

  @override
  String settingsCreditsCountValue(int count) {
    return '$count 件';
  }

  @override
  String get settingsLicenseDisclaimerTitle => 'ライセンスに関する注記';

  @override
  String get settingsLicenseDisclaimerBody => '各プロジェクトの著作権およびライセンスは原著作者に帰属します。';

  @override
  String get settingsCreditsCoreGroup => '主要プロジェクトとプロトコル参考';

  @override
  String get settingsCreditsRuntimeGroup => 'ランタイムと基盤ライブラリ';

  @override
  String get settingsAppLicenseTile => 'アプリケーションライセンス';

  @override
  String get settingsCannotOpenUrlToast => 'URL を開けませんでした';

  @override
  String get updateDefaultChangelog => '既知の問題を修正し、安定性を向上しました。';

  @override
  String get updateCheckingToast => '新しいバージョンを確認中...';

  @override
  String get updateCheckFailedTitle => 'アップデートの確認に失敗';

  @override
  String get updateCheckFailedBody =>
      '更新サーバーに接続できません。ネットワークを確認するか、GitHub Releases をご覧ください。';

  @override
  String get updateUpToDateTitle => '最新バージョンです';

  @override
  String updateUpToDateBody(String version, String source) {
    return '現在のバージョン v$version は最新です。\n確認元: $source';
  }

  @override
  String get updateCheckErrorTitle => 'アップデート確認エラー';

  @override
  String get updateOpenWebsite => 'GitHub を開く';

  @override
  String get updatePreparing => '準備中...';

  @override
  String get updateInstallerFailedToast =>
      'インストーラーを起動できません。提供元不明のアプリ権限を確認するかブラウザからダウンロードしてください';

  @override
  String get updateBrowserDownload => 'ブラウザでダウンロード';

  @override
  String updateSkippedVersionToast(String version) {
    return 'v$version をスキップしました。次回起動時は通知しません';
  }

  @override
  String get updateNewVersionTitle => '新しいバージョンがあります';

  @override
  String get updateSourceGithub => 'GitHub リリース';

  @override
  String get updateChangelogHeader => '更新内容';

  @override
  String updatePackageSizeLabel(String size) {
    return 'パッケージサイズ: $size';
  }

  @override
  String updateDownloadingPct(String percent) {
    return 'ダウンロード中: $percent%';
  }

  @override
  String get updateSkipThisVersion => 'この版をスキップ';

  @override
  String get updateLater => '後で';

  @override
  String get updateInstallNow => '今すぐインストール';

  @override
  String get updateDownloadAndInstall => 'ダウンロードしてインストール';

  @override
  String get updateOpenInBrowserTooltip => 'ブラウザでダウンロードを開く';

  @override
  String get updateSha256MismatchError =>
      'APK の SHA-256 検証に失敗したためインストールを中止しました';

  @override
  String get hubTitle => 'スタジオ';

  @override
  String get hubBentoQuickTransferTitle => '写真転送';

  @override
  String get hubBentoQuickTransferSub => 'カメラ内写真を閲覧・スマホへ転送';

  @override
  String get hubBentoWatermarkTitle => 'ウォーターマーク';

  @override
  String get hubBentoWatermarkSub => '額装フレームとフィルム現像';

  @override
  String get hubBentoCollageTitle => 'コラージュ工房';

  @override
  String get hubBentoCollageSub => '複数枚のレイアウトストーリー作成';

  @override
  String get hubBentoTransfersTitle => '転送センター';

  @override
  String get hubBentoTransfersIdle => '待機中';

  @override
  String hubBentoTransfersActive(int count) {
    return '$count 件進行中';
  }

  @override
  String get hubRecentPhotosTitle => '最近の写真';

  @override
  String get hubRecentPhotosEmpty => '最近の写真はありません';

  @override
  String get hubShootAndTransferQuick => '撮影時転送';

  @override
  String get hubHelpGuideTooltip => '接続ガイド';

  @override
  String get hubGuideTitle => 'カメラ接続ガイド';

  @override
  String get hubGuideWifiTitle => 'Wi-Fi 直結の手順';

  @override
  String get hubGuideWifiBody =>
      '1. カメラメニューで「スマートフォンと接続」または Wi-Fi をオンにします\n2. スマホの Wi-Fi 設定でカメラのアクセスポイント（NIKON_...）に接続します\n3. 本アプリに戻り「今すぐ接続」をタップして PTP/IP を開始します';

  @override
  String get hubGuideUsbTitle => 'USB OTG 接続の手順';

  @override
  String get hubGuideUsbBody =>
      '1. USB-C ケーブルまたは OTG アダプタでスマホとカメラを接続します\n2. カメラの電源を入れます\n3. USB 権限の確認画面で許可し、「今すぐ接続」をタップします';

  @override
  String get hubGuideClose => '了解';

  @override
  String get connectOneTapUsb => 'USBカメラを接続';

  @override
  String get connectSelectWifi => 'Wi-Fiを選択';

  @override
  String get connectQuickConnect => '今すぐ接続';

  @override
  String get connectUsbDetectedHeader => 'USBカメラを検出しました';

  @override
  String get connectWifiDetectedHeader => '現在のWi-Fiネットワーク';

  @override
  String get wmDockTemplate => 'フレーム';

  @override
  String get wmDockFilter => 'フィルム';

  @override
  String get wmDockGrade => 'パラメーター';

  @override
  String get wmDockGeometry => '切り抜き';

  @override
  String get wmSubPalette => '配色・余白';

  @override
  String get wmSubToggles => '項目・文字';

  @override
  String get wmSubTypography => 'フォント';

  @override
  String get wmSubLogo => 'ロゴ';

  @override
  String get wmHistogramHudTooltip => 'ヒストグラム HUD';

  @override
  String get wmDialResetAll => 'すべてリセット';

  @override
  String get wmDialTransferToGrade => '微調整へ';

  @override
  String get wmDialSaveAsPreset => 'プリセット保存';

  @override
  String get wmDialCategoryPreset => '★ プリセット';

  @override
  String get wmDialPresetCustomGroup => 'マイプリセット';

  @override
  String get wmDialSavePresetPrompt => 'プリセット名を入力';

  @override
  String wmDialSavePresetSuccess(String name) {
    return 'プリセット「$name」を保存しました';
  }

  @override
  String get wmDialActiveLutButton => '3D LUTファイルを選択';

  @override
  String get wmDialNoLutChosen => 'LUT未読み込み';

  @override
  String get wmExportMenuTitle => '書き出し画質';

  @override
  String get galleryTabCameraCard => 'カメラカード';

  @override
  String get galleryTabExportedPhoneShort => '端末内';

  @override
  String get galleryActionSelectAll => 'すべて選択';

  @override
  String get galleryActionDeselect => '解除';

  @override
  String get galleryExifDetailSheetTitle => '撮影詳細';

  @override
  String get galleryCollageDirectModeTitle => 'コラージュ写真を選択 (2-9枚)';

  @override
  String get wmViewModeListTooltip => '1行1種リスト（スクロールバー付き）';

  @override
  String get wmViewModePagedTooltip => '画面高さ適応ページ表示';

  @override
  String get wmTabletTuneAction => '微調整';

  @override
  String get wmTabletSectionTemplates => '形式';

  @override
  String get wmTabletSectionStyle => 'スタイル';

  @override
  String get wmTabletPagePrev => '前へ';

  @override
  String get wmTabletPageNext => '次へ';

  @override
  String wmTabletPageIndicator(Object current, Object total) {
    return '$current / $total ページ';
  }

  @override
  String get wmTabletPureGradeHint => '現在フィルターのみの純粋なカラー調整モード（透かしなし）';

  @override
  String get wmTabletPureGradeAction => '透かし形式を選択';
}
