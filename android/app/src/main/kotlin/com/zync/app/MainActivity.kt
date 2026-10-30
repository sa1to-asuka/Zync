package com.zync.app

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.media.MediaScannerConnection
import android.media.MediaMetadataRetriever
import android.graphics.Bitmap
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.util.Log
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.app.Activity
import android.content.ContentValues
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.provider.MediaStore
import java.util.UUID
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import androidx.core.content.FileProvider

/** 相机侧残留 PTP 会话关闭后，重新 OpenSession 前的等待时间。 */
private const val USB_PTP_FRESH_SESSION_DELAY_MS = 700L

/** 建立 USB PTP 会话的最大尝试次数（含首次）。 */
private const val USB_PTP_MAX_OPEN_ATTEMPTS = 3

/** 建立会话因传输错误重试前的基准退避时间，按尝试次数线性递增。 */
private const val USB_PTP_RETRY_DELAY_MS = 250L

private val USB_CAMERA_VENDOR_NAMES = mapOf(
    0x04B0 to "Nikon",
    0x04A9 to "Canon",
    0x054C to "Sony",
    0x04CB to "Fujifilm",
    0x04DA to "Panasonic",
    0x07B4 to "Olympus",
    0x1A98 to "Leica",
    0x2756 to "Hasselblad",
)

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.zync.app/native_camera"
    private val USB_EVENT_CHANNEL = "com.zync.app/usb_events"
    // 媒体 I/O 全局串行，最多一个任务；若并行导出成为瓶颈，可改为按 URI 串行。
    private val mediaExecutor = Executors.newSingleThreadExecutor()
    // USB PTP I/O 全局串行：bulk 传输是阻塞调用，绝不能占用平台主线程（否则连接期间 UI 会直接卡死）。
    private val usbExecutor = Executors.newSingleThreadExecutor()
    private val TAG = "ZyncNative"
    private val REQUEST_PICK_IMAGE = 1001
    private val REQUEST_PICK_FILE = 1003
    private val REQUEST_PICK_MULTI_FILES = 1004
    private val REQUEST_NOTIFICATION_PERMISSION = 1002
    private val ACTION_USB_PERMISSION = "com.zync.app.USB_PERMISSION"
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingPickFileResult: MethodChannel.Result? = null
    private var pendingPickMultiFilesResult: MethodChannel.Result? = null
    private val pendingIncomingFilePaths = mutableListOf<String>()
    private var methodChannel: MethodChannel? = null

    private var wifiLock: WifiManager.WifiLock? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var cameraNetworkCallback: ConnectivityManager.NetworkCallback? = null
    private var boundCameraNetwork: Network? = null

    // Bluetooth
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var activeGatt: BluetoothGatt? = null
    private var isScanning = false
    private val scannedDevices = mutableMapOf<String, Map<String, Any>>()
    private var bleStatus = "disconnected"
    private var bleConnectedDeviceName: String? = null

    // USB PTP
    private var usbManager: UsbManager? = null
    private val usbSessions = ConcurrentHashMap<String, UsbPtpSession>()
    private var pendingUsbPermissionResult: MethodChannel.Result? = null
    private var pendingUsbPermissionDeviceName: String? = null
    private var usbPermissionReceiver: BroadcastReceiver? = null
    private var usbEventSink: EventChannel.EventSink? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bm?.adapter
        usbManager = getSystemService(Context.USB_SERVICE) as? UsbManager
        registerUsbPermissionReceiver()

        // 请求关键运行时权限 (定位/近距离设备，以便系统允许读取 Wi-Fi SSID 与扫描 BLE)
        requestRuntimePermissions()

        // 预注册相机专用网络回调 (允许无外网 Wi-Fi 保持连接)
        requestCameraWifiNetwork()

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, USB_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    usbEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    usbEventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAppLocale" -> {
                    val code = call.argument<String>("locale") ?: "en"
                    TransferKeepAliveService.currentLocaleCode = code
                    result.success(true)
                }
                // Wi-Fi 强绑定与网络状态
                "bindCameraWifi" -> {
                    val targetHost = call.argument<String>("targetHost")
                    val res = bindProcessToCameraWifi(targetHost)
                    result.success(res)
                }
                "unbindWifi" -> {
                    unbindProcessWifi()
                    result.success(mapOf("success" to true))
                }
                "getWifiInfo" -> {
                    result.success(getWifiDetails())
                }
                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }


                // 蓝牙 BLE 操作
                "isBluetoothEnabled" -> {
                    result.success(bluetoothAdapter?.isEnabled == true)
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "startBleScan" -> {
                    startBleScan(result)
                }
                "stopBleScan" -> {
                    stopBleScan()
                    result.success(true)
                }
                "getScannedBleDevices" -> {
                    result.success(scannedDevices.values.toList())
                }
                "connectBleDevice" -> {
                    val address = call.argument<String>("address")
                    if (address.isNullOrBlank()) {
                        result.error("INVALID_ARG", "Device address cannot be empty", null)
                    } else {
                        connectBleDevice(address, result)
                    }
                }
                "disconnectBleDevice" -> {
                    disconnectBleDevice()
                    result.success(true)
                }
                "sendBleShutterCommand" -> {
                    val cmd = call.argument<String>("command") ?: "shutter"
                    val success = sendBleCommand(cmd)
                    result.success(mapOf("success" to success))
                }
                "sendBleLocationPayload" -> {
                    val geoBytes = call.argument<ByteArray>("geoPayload")
                    val timeBytes = call.argument<ByteArray>("timePayload")
                    if (geoBytes == null || geoBytes.size != 41) {
                        result.error("INVALID_PAYLOAD", "GEO 载荷必须为 41 字节", null)
                    } else {
                        val res = sendBleLocationPayload(geoBytes, timeBytes)
                        result.success(res)
                    }
                }
                "getCurrentLocation" -> {
                    result.success(getCurrentLocationFix())
                }
                "getBleStatus" -> {
                    result.success(mapOf(
                        "status" to bleStatus,
                        "deviceName" to (bleConnectedDeviceName ?: "")
                    ))
                }
                "getDevicePowerInfo" -> {
                    result.success(getDevicePowerInfo())
                }
                "notifyMediaScan" -> {
                    val path = call.argument<String>("path")
                    if (!path.isNullOrBlank()) {
                        MediaScannerConnection.scanFile(
                            applicationContext,
                            arrayOf(path),
                            null
                        ) { p, uri ->
                            Log.d(TAG, "MediaScanner scanned $p -> $uri")
                        }
                    }
                    result.success(true)
                }
                // 传输保活前台服务 (后台/锁屏不被回收)
                "startTransferKeepAlive" -> {
                    startTransferKeepAlive(call.argument<String>("title") ?: "Zync 正在传输")
                    result.success(true)
                }
                "updateTransferKeepAlive" -> {
                    updateTransferKeepAlive(
                        call.argument<Int>("completed") ?: 0,
                        call.argument<Int>("total") ?: 0,
                        call.argument<Boolean>("paused") ?: false
                    )
                    result.success(true)
                }
                "stopTransferKeepAlive" -> {
                    stopTransferKeepAlive()
                    result.success(true)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(true)
                }
                "writeTextFile" -> {
                    val text = call.argument<String>("text").orEmpty()
                    val suggested = call.argument<String>("fileName")?.takeIf { it.isNotBlank() }
                        ?: "zync_export.txt"
                    try {
                        val dir = File(getExternalFilesDir(null) ?: cacheDir, "exports")
                        if (!dir.exists()) dir.mkdirs()
                        val safe = suggested.replace(Regex("[^A-Za-z0-9._-]"), "_")
                        val target = File(dir, safe)
                        target.writeText(text)
                        result.success(target.absolutePath)
                    } catch (e: Exception) {
                        result.error("WRITE_TEXT_ERROR", e.localizedMessage, null)
                    }
                }
                "pickFile" -> {
                    pendingPickFileResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/octet-stream", "text/plain", "image/png", "image/jpeg", "video/*"))
                        }
                        startActivityForResult(intent, REQUEST_PICK_FILE)
                    } catch (e: Exception) {
                        pendingPickFileResult = null
                        result.error("PICK_FILE_ERROR", e.localizedMessage, null)
                    }
                }
                "pickMultipleFiles" -> {
                    pendingPickMultiFilesResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        }
                        startActivityForResult(intent, REQUEST_PICK_MULTI_FILES)
                    } catch (e: Exception) {
                        pendingPickMultiFilesResult = null
                        result.error("PICK_MULTI_FILE_ERROR", e.localizedMessage, null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    val title = call.argument<String>("title") ?: "Share"
                    if (filePath.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                result.success(false)
                            } else {
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "$packageName.fileprovider",
                                    file
                                )
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    type = "application/octet-stream"
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(shareIntent, title))
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }
                "consumeIncomingFiles" -> {
                    captureIntentFiles(intent)
                    val out = ArrayList(pendingIncomingFilePaths)
                    pendingIncomingFilePaths.clear()
                    result.success(out)
                }
                "pickImage" -> {
                    if (pendingPickResult != null) {
                        result.error("ALREADY_ACTIVE", "Pick operation in progress", null)
                    } else {
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
                        intent.type = "image/*"
                        try {
                            startActivityForResult(intent, REQUEST_PICK_IMAGE)
                        } catch (e: Exception) {
                            val fallback = Intent(Intent.ACTION_GET_CONTENT)
                            fallback.type = "image/*"
                            startActivityForResult(fallback, REQUEST_PICK_IMAGE)
                        }
                    }
                }
                "saveImageToGallery" -> {
                    val srcPath = call.argument<String>("srcPath")
                    if (srcPath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Path is empty", null)
                    } else {
                        val file = File(srcPath)
                        if (!file.exists()) {
                            result.error("NOT_FOUND", "File does not exist", null)
                        } else {
                            mediaTask(result) { saveImageToPublicPictures(file) ?: throw java.io.IOException("MediaStore 保存失败") }
                        }
                    }
                }
                "listSavedMedia" -> mediaTask(result) { listSavedMedia() }
                "materializeMedia" -> {
                    val uri = call.argument<String>("uri")
                    mediaTask(result) { materializeMedia(uri ?: "") }
                }
                "findMediaUris" -> {
                    val fileNames = call.argument<List<*>>("fileNames")?.filterIsInstance<String>() ?: emptyList()
                    result.success(findMediaUrisByNames(fileNames))
                }
                "overwriteMedia" -> {
                    val mediaUri = call.argument<String>("mediaUri")
                    val srcPath = call.argument<String>("srcPath")
                    if (mediaUri.isNullOrBlank() || srcPath.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        mediaTask(result) { overwriteMediaEntry(mediaUri, srcPath) }
                    }
                }
                "deleteMedia" -> {
                    val target = call.argument<String>("target")
                    if (target.isNullOrBlank()) {
                        result.error("INVALID_TARGET", "Target is empty", null)
                    } else {
                        result.success(deleteMediaTarget(target))
                    }
                }
                "saveMediaToGallery" -> {
                    val srcPath = call.argument<String>("srcPath")
                    val fileName = call.argument<String>("fileName")
                    if (srcPath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Path is empty", null)
                    } else {
                        val file = File(srcPath)
                        if (!file.exists()) {
                            result.error("NOT_FOUND", "File does not exist", null)
                        } else {
                            mediaTask(result) { saveMediaToPublic(file, fileName ?: file.name) ?: throw java.io.IOException("MediaStore 保存失败") }
                        }
                    }
                }
                "getVideoThumbnail" -> {
                    val path = call.argument<String>("path")
                    val width = call.argument<Int>("width") ?: 360
                    val height = call.argument<Int>("height") ?: 360
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Path is empty", null)
                    } else {
                        mediaTask(result) { extractVideoThumbnail(path, width, height) }
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrBlank()) {
                        result.error("INVALID_PATH", "Path is empty", null)
                    } else {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                result.error("NOT_FOUND", "File does not exist", null)
                            } else {
                                val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    FileProvider.getUriForFile(
                                        this,
                                        "${applicationContext.packageName}.fileprovider",
                                        file
                                    )
                                } else {
                                    Uri.fromFile(file)
                                }

                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(apkUri, "application/vnd.android.package-archive")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start APK installation", e)
                            result.error("INSTALL_ERROR", e.localizedMessage, null)
                        }
                    }
                }
                "openUrlInBrowser" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "URL is empty", null)
                    } else {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("BROWSER_ERROR", e.localizedMessage, null)
                        }
                    }
                }
                // USB PTP over OTG
                "listUsbDevices" -> result.success(listUsbDevices())
                "requestUsbPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    if (deviceName.isNullOrBlank()) {
                        result.error("INVALID_ARG", "deviceName 不能为空", null)
                    } else {
                        requestUsbPermission(deviceName, result)
                    }
                }
                "usbOpenSession" -> {
                    val deviceName = call.argument<String>("deviceName")
                    usbAsync(result, "USB_OPEN_FAILED") { openUsbSession(deviceName) }
                }
                "usbCloseSession" -> {
                    val deviceId = call.argument<String>("deviceId") ?: pendingUsbPermissionDeviceName
                    usbAsync(result, "USB_CLOSE_FAILED") {
                        closeUsbSession(deviceId)
                        true
                    }
                }
                "usbQueryDeviceInfo" -> {
                    val deviceId = call.argument<String>("deviceId")
                    usbAsync(result, "USB_QUERY_FAILED", deviceId) { queryUsbDeviceInfo(requireUsbSession(deviceId)) }
                }
                "usbExecuteOperation" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val opCode = call.argument<Int>("opCode") ?: 0
                    val params = intArrayOf(*(call.argument<List<Int>>("params")?.toIntArray() ?: IntArray(0)))
                    usbAsync(result, "USB_OPERATION_FAILED", deviceId) {
                        requireUsbSession(deviceId).executeOperation(opCode, params)
                        true
                    }
                }
                "usbExecuteDataIn" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val opCode = call.argument<Int>("opCode") ?: 0
                    val params = intArrayOf(*(call.argument<List<Int>>("params")?.toIntArray() ?: IntArray(0)))
                    usbAsync(result, "USB_DATA_IN_FAILED", deviceId) {
                        requireUsbSession(deviceId).executeDataIn(opCode, params)
                    }
                }
                "usbExecuteDataOut" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val opCode = call.argument<Int>("opCode") ?: 0
                    val params = intArrayOf(*(call.argument<List<Int>>("params")?.toIntArray() ?: IntArray(0)))
                    val data = call.argument<ByteArray>("data")
                    if (data == null) {
                        result.error("INVALID_ARG", "data 不能为空", null)
                    } else {
                        usbAsync(result, "USB_DATA_OUT_FAILED", deviceId) {
                            requireUsbSession(deviceId).executeDataOut(opCode, data, params)
                            true
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        // 专业照片/视频原生桥：RAW 解码与 Media3 视频导出。
        RawProcessorBridge(flutterEngine.dartExecutor.binaryMessenger)
        VideoEditorBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
    }
    // ==================== USB PTP over OTG ====================

    private fun findUsbDeviceByName(deviceName: String): UsbDevice? =
        usbManager?.deviceList?.values?.firstOrNull { it.deviceName == deviceName }

    /** 枚举可连接或可切换到 PTP 的 USB 相机。 */
    private fun listUsbDevices(): List<Map<String, Any>> {
        val mgr = usbManager ?: return emptyList()
        return mgr.deviceList.values
            .filter { isSupportedCameraDevice(it) }
            .map { device ->
                val productName = try { device.productName } catch (_: Exception) { null }
                val vendorName = USB_CAMERA_VENDOR_NAMES[device.vendorId]
                val ptpReady = hasPtpInterface(device)
                val storageOnly = !ptpReady && hasStorageInterface(device)
                mapOf(
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "name" to (productName ?: vendorName ?: "USB Camera"),
                    "hasPermission" to mgr.hasPermission(device),
                    "isNikon" to (device.vendorId == 0x04B0),
                    "isCamera" to true,
                    "vendorName" to (vendorName ?: "PTP Camera"),
                    "ptpReady" to ptpReady,
                    "storageOnly" to storageOnly,
                )
            }
    }

    private fun hasPtpInterface(device: UsbDevice): Boolean =
        (0 until device.interfaceCount).any { index ->
            val iface = device.getInterface(index)
            if (iface.interfaceClass != UsbConstants.USB_CLASS_STILL_IMAGE) return@any false
            var hasIn = false
            var hasOut = false
            for (epIndex in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(epIndex)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == UsbConstants.USB_DIR_IN) hasIn = true
                    if (ep.direction == UsbConstants.USB_DIR_OUT) hasOut = true
                }
            }
            hasIn && hasOut
        }

    private fun hasStorageInterface(device: UsbDevice): Boolean =
        (0 until device.interfaceCount).any { index ->
            device.getInterface(index).interfaceClass == UsbConstants.USB_CLASS_MASS_STORAGE
        }

    private fun isSupportedCameraDevice(device: UsbDevice): Boolean {
        if (USB_CAMERA_VENDOR_NAMES.containsKey(device.vendorId)) return true
        return (0 until device.interfaceCount).any { index ->
            device.getInterface(index).interfaceClass == UsbConstants.USB_CLASS_STILL_IMAGE
        }
    }

    private fun registerUsbPermissionReceiver() {
        if (usbPermissionReceiver != null) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_USB_PERMISSION -> {
                        val res = pendingUsbPermissionResult
                        val deviceName = pendingUsbPermissionDeviceName
                        pendingUsbPermissionResult = null
                        pendingUsbPermissionDeviceName = null
                        val fromIntent =
                            intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        // 部分 ROM 不回填 EXTRA_PERMISSION_GRANTED，以实际权限为准再判定。
                        val granted = fromIntent || deviceName?.let { name ->
                            findUsbDeviceByName(name)?.let { usbManager?.hasPermission(it) }
                        } == true
                        res?.success(granted)
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        @Suppress("DEPRECATION")
                        val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE) as? UsbDevice
                        }
                        if (device != null) closeUsbSessionForDevice(device)
                    }
                }
            }
        }
        usbPermissionReceiver = receiver
        val filter = IntentFilter(ACTION_USB_PERMISSION).apply {
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
    }

    private fun emitUsbEvent(deviceName: String, bytes: ByteArray) {
        val payload = bytes.copyOf()
        Handler(Looper.getMainLooper()).post {
            usbEventSink?.success(mapOf("deviceName" to deviceName, "data" to payload))
        }
    }

    private fun closeUsbSessionForDevice(device: UsbDevice) {
        val suffix = ":${device.deviceName}"
        val ids = usbSessions.keys.filter { it.endsWith(suffix) }
        for (id in ids) {
            try {
                usbSessions.remove(id)?.close()
            } catch (_: Exception) {}
        }
    }

    private fun requestUsbPermission(deviceName: String, result: MethodChannel.Result) {        val mgr = usbManager
        if (mgr == null) {
            result.error("USB_UNAVAILABLE", "UsbManager 不可用", null)
            return
        }
        val device = findUsbDeviceByName(deviceName)
        if (device == null) {
            result.error("USB_NOT_FOUND", "未找到设备: $deviceName", null)
            return
        }
        if (mgr.hasPermission(device)) {
            result.success(true)
            return
        }
        registerUsbPermissionReceiver()
        pendingUsbPermissionDeviceName = deviceName
        pendingUsbPermissionResult = result
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pi = PendingIntent.getBroadcast(
            this, 0, Intent(ACTION_USB_PERMISSION).setPackage(packageName), flags
        )
        mgr.requestPermission(device, pi)
    }

    /**
     * 把 USB PTP 操作丢到后台线程执行：bulk 读写是阻塞调用（单次超时最长 15s），
     * 在主线程执行会直接卡死 UI，甚至触发 ANR。
     */
    private fun <T> usbAsync(
        result: MethodChannel.Result,
        errorCode: String,
        recoverDeviceId: String? = null,
        block: () -> T,
    ) {
        usbExecutor.execute {
            val outcome = runCatching { block() }
            runOnUiThread {
                outcome
                    .onSuccess { value -> result.success(value) }
                    .onFailure { e ->
                        Log.e(TAG, "$errorCode: ${e.message}", e)
                        // 传输层错误（IO）时清除端点 halt 并丢弃会话，下次调用重建。
                        if (recoverDeviceId != null && e is IOException) {
                            runCatching { usbExecutor.execute { recoverUsbSession(recoverDeviceId) } }
                        }
                        result.error(errorCode, e.message ?: errorCode, null)
                    }
            }
        }
    }

    /** 传输层出错后的恢复：清 bulk IN/OUT 的 halt 并丢弃会话，等待下次重建。 */
    private fun recoverUsbSession(deviceId: String) {
        val session = usbSessions.remove(deviceId) ?: return
        Log.w(TAG, "[USB] 传输层错误，重建会话 id=$deviceId")
        runCatching { session.recoverAfterTransportFailure() }
        runCatching { session.close() }
    }

    /** 选中的 PTP 接口与端点。 */
    private class UsbPtpInterface(
        val iface: UsbInterface,
        val epIn: UsbEndpoint,
        val epOut: UsbEndpoint,
        val epEvent: UsbEndpoint?,
    )

    /**
     * 选择承载 PTP 的接口：优先「静态图像类 class 6 / subclass 1 / protocol 1」，
     * 其次 class 6、厂商自定义类，最后兜底任意含 Bulk IN + Bulk OUT 的接口。
     * 同时把每个接口/端点写进日志，方便现场判断相机是否真的处于 PTP 模式。
     */
    private fun selectBulkInterface(device: UsbDevice): UsbPtpInterface? {
        val candidates = (0 until device.interfaceCount).map { device.getInterface(it) }
        for (iface in candidates) {
            Log.d(
                TAG,
                "[USB] iface id=${iface.id} alt=${iface.alternateSetting} class=${iface.interfaceClass} " +
                    "subclass=${iface.interfaceSubclass} protocol=${iface.interfaceProtocol} " +
                    "endpoints=${iface.endpointCount}"
            )
        }
        val ranked = candidates.sortedByDescending { iface ->
            when {
                iface.interfaceClass == 6 && iface.interfaceSubclass == 1 && iface.interfaceProtocol == 1 -> 2
                iface.interfaceClass == 6 -> 1
                else -> 0
            }
        }
        for (iface in ranked) {
            var epIn: UsbEndpoint? = null
            var epOut: UsbEndpoint? = null
            var epEvent: UsbEndpoint? = null
            for (i in 0 until iface.endpointCount) {
                val ep = iface.getEndpoint(i)
                if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) {
                    if (ep.direction == UsbConstants.USB_DIR_IN && epIn == null) epIn = ep
                    if (ep.direction == UsbConstants.USB_DIR_OUT && epOut == null) epOut = ep
                } else if (ep.type == UsbConstants.USB_ENDPOINT_XFER_INT &&
                    ep.direction == UsbConstants.USB_DIR_IN && epEvent == null
                ) {
                    epEvent = ep
                }
            }
            if (epIn != null && epOut != null) {
                if (iface.interfaceClass != 6) {
                    Log.w(TAG, "[USB] 未找到静态图像类接口，回退使用 class=${iface.interfaceClass} 的 Bulk 接口")
                }
                return UsbPtpInterface(iface, epIn, epOut, epEvent)
            }
        }
        return null
    }

    /** 设备描述符摘要（接口/端点），失败时随错误信息一起回传，便于远程定位。 */
    private fun describeUsbDevice(device: UsbDevice): String {
        val ifaces = (0 until device.interfaceCount).joinToString(" ") { index ->
            val iface = device.getInterface(index)
            val eps = (0 until iface.endpointCount).joinToString(",") { i ->
                val ep = iface.getEndpoint(i)
                "0x${Integer.toHexString(ep.address)}/type${ep.type}"
            }
            "if${iface.id}alt${iface.alternateSetting}:c${iface.interfaceClass}/s${iface.interfaceSubclass}" +
                "/p${iface.interfaceProtocol}[$eps]"
        }
        return "vid=0x${Integer.toHexString(device.vendorId)} pid=0x${Integer.toHexString(device.productId)} " +
            "ifaces=${device.interfaceCount} $ifaces"
    }

    /**
     * 打开 USB PTP 会话：选择 Bulk 接口 -> claim -> OpenSession。
     * 失败时把现场信息（接口拓扑 + 步骤轨迹）一起带回 Flutter，便于定位问题。
     */
    private fun openUsbSession(deviceName: String?): String {
        if (deviceName.isNullOrBlank()) throw IllegalArgumentException("deviceName 不能为空")
        // 命中缓存时先确认会话仍然可用，避免返回半死会话。
        usbSessions.entries.firstOrNull { it.key.endsWith(":$deviceName") }?.let { (id, session) ->
            if (session.isAlive) return id
            usbSessions.remove(id)
            runCatching { session.close() }
        }
        val mgr = usbManager ?: throw IllegalStateException("UsbManager 不可用")
        val device = findUsbDeviceByName(deviceName) ?: throw IllegalStateException("未找到设备: $deviceName")
        if (!mgr.hasPermission(device)) throw IllegalStateException("缺少 USB 权限，请先授权")
        val selected = selectBulkInterface(device)
        if (selected == null) {
            val modeHint = if (hasStorageInterface(device)) {
                "相机当前处于大容量存储模式，请在相机菜单切换为 PTP"
            } else {
                "未找到可用的 PTP Bulk IN/OUT 端点"
            }
            throw IllegalStateException("$modeHint：${describeUsbDevice(device)}")
        }

        val trace = mutableListOf<String>()
        var lastError: Exception? = null
        // 相机冷启动时首次 OpenSession/事件清空可能超时，或残留会话需要先关闭；
        // 这里对传输类错误做有限次整会话重试（每次重新 openDevice + claim + OpenSession）。
        for (attempt in 1..USB_PTP_MAX_OPEN_ATTEMPTS) {
            var session: UsbPtpSession? = null
            try {
                val connection: UsbDeviceConnection = mgr.openDevice(device)
                    ?: throw IllegalStateException("openDevice 失败")
                val created = UsbPtpSession(
                    device = device,
                    connection = connection,
                    iface = selected.iface,
                    epIn = selected.epIn,
                    epOut = selected.epOut,
                    epEvent = selected.epEvent,
                    onEvent = { bytes -> emitUsbEvent(device.deviceName, bytes) },
                    onLog = { message ->
                        trace.add(message)
                        Log.d(TAG, "[USB] $message")
                    },
                )
                session = created
                created.open()
                if (created.openFreshSession()) {
                    val id = created.deviceId
                    usbSessions[id] = created
                    Log.d(TAG, "[USB] PTP 会话已建立 id=$id attempt=$attempt")
                    return id
                }
                Log.d(TAG, "[USB] 相机侧残留 PTP 会话已清理，attempt=$attempt")
                created.close()
                session = null
                if (attempt < USB_PTP_MAX_OPEN_ATTEMPTS) {
                    Thread.sleep(USB_PTP_FRESH_SESSION_DELAY_MS)
                }
            } catch (e: Exception) {
                lastError = e
                runCatching { session?.close() }
                Log.d(TAG, "[USB] 建立会话失败 attempt=$attempt: ${e.message}")
                if (attempt < USB_PTP_MAX_OPEN_ATTEMPTS) {
                    Thread.sleep(USB_PTP_RETRY_DELAY_MS * attempt)
                }
            }
        }
        val detail = if (trace.isEmpty()) "" else "；步骤: ${trace.joinToString(" | ")}"
        throw IllegalStateException(
            "USB PTP 会话建立失败（已重试 $USB_PTP_MAX_OPEN_ATTEMPTS 次）：" +
                "${lastError?.message ?: "unknown"}$detail；${describeUsbDevice(device)}",
            lastError
        )
    }

    private fun requireUsbSession(deviceId: String?): UsbPtpSession {
        val id = deviceId ?: usbSessions.keys.firstOrNull()
            ?: throw IllegalStateException("USB 会话未建立")
        return usbSessions[id] ?: throw IllegalStateException("USB 会话不存在: $id")
    }

    private fun closeUsbSession(deviceId: String?) {
        val ids = if (deviceId != null && usbSessions.containsKey(deviceId)) {
            listOf(deviceId)
        } else {
            usbSessions.keys.toList()
        }
        for (id in ids) {
            try {
                usbSessions.remove(id)?.close()
            } catch (_: Exception) {}
        }
    }

    private fun queryUsbDeviceInfo(session: UsbPtpSession): Map<String, Any> {
        val raw = session.executeDataIn(0x1001) // GetDeviceInfo
        return mapOf("raw" to raw)
    }

    private fun getDevicePowerInfo(): Map<String, Any> {
        var level = 100
        var isCharging = false
        var isPowerSaveMode = false

        try {
            val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && bm != null) {
                level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            } else {
                val ifilter = android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
                val batteryStatus = registerReceiver(null, ifilter)
                val rawLevel = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (rawLevel >= 0 && scale > 0) {
                    level = (rawLevel * 100 / scale.toFloat()).toInt()
                }
            }

            val ifilter = android.content.IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus = registerReceiver(null, ifilter)
            val status = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                    status == BatteryManager.BATTERY_STATUS_FULL

            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && pm != null) {
                isPowerSaveMode = pm.isPowerSaveMode
            }
        } catch (e: Exception) {
            Log.e(TAG, "getDevicePowerInfo error: $e")
        }

        return mapOf(
            "level" to level,
            "isCharging" to isCharging,
            "isPowerSaveMode" to isPowerSaveMode
        )
    }


    private fun requestRuntimePermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val list = mutableListOf<String>()
            if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                list.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) != PackageManager.PERMISSION_GRANTED) {
                    list.add(Manifest.permission.NEARBY_WIFI_DEVICES)
                }
            }

            if (list.isNotEmpty()) {
                requestPermissions(list.toTypedArray(), 1001)
            }
        }
    }

    /**
     * 注册无外网相机 Wi-Fi 网络请求，防止蜂窝数据把无网 Wi-Fi 顶掉。
     */
    private fun requestCameraWifiNetwork() {
        if (cameraNetworkCallback != null) return
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    Log.d(TAG, "[network-bind] requestNetwork onAvailable: $network")
                }

                override fun onLost(network: Network) {
                    Log.d(TAG, "[network-bind] requestNetwork onLost: $network")
                    if (boundCameraNetwork == network) {
                        boundCameraNetwork = null
                    }
                }
            }
            cameraNetworkCallback = callback
            try {
                cm.requestNetwork(request, callback)
            } catch (e: Exception) {
                Log.e(TAG, "requestNetwork exception: $e")
            }
        }
    }

    /**
     * 将当前 App 进程网络强行绑定到相机 Wi-Fi 接口
     * 针对 targetHost 智能匹配路由网段
     */
    private fun bindProcessToCameraWifi(targetHost: String?): Map<String, Any> {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        requestCameraWifiNetwork()
        val wifiNetwork = findWifiNetwork(cm, targetHost)
        var bound = false
        if (wifiNetwork != null) {
            bound = cm.bindProcessToNetwork(wifiNetwork)
            if (bound) boundCameraNetwork = wifiNetwork
        } else {
            cm.bindProcessToNetwork(null)
            boundCameraNetwork = null
        }
        Log.d(TAG, "[network-bind] bindProcessToNetwork=$bound target=$targetHost network=$wifiNetwork")
        acquireLocks()
        val res = getWifiDetails().toMutableMap()
        res["bound"] = bound
        return res
    }
    private fun unbindProcessWifi() {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            cameraNetworkCallback?.let {
                try {
                    cm.unregisterNetworkCallback(it)
                } catch (_: Exception) {}
            }
            cameraNetworkCallback = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                cm.bindProcessToNetwork(null)
            }
            boundCameraNetwork = null
            wifiLock?.let {
                if (it.isHeld) it.release()
            }
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "unbindProcessWifi error: $e")
        }
    }

    private fun acquireLocks() {
        try {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            if (wifiLock == null) {
                @Suppress("DEPRECATION")
                wifiLock = wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "Zync:WifiLock")
                wifiLock?.setReferenceCounted(false)
            }
            wifiLock?.acquire()

            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (wakeLock == null) {
                wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Zync:WakeLock")
                wakeLock?.setReferenceCounted(false)
            }
            wakeLock?.acquire(3600 * 1000L) // 最长保活 1 小时
        } catch (e: Exception) {
            Log.e(TAG, "acquireLocks error: $e")
        }
    }

    private fun getWifiDetails(): Map<String, Any> {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        var isConnected = false
        var ssid = "<unknown>"
        var gatewayIp = "192.168.1.1" // 默认优先匹配用户相机 192.168.1.1 网关
        var localIp = "192.168.1.2"

        try {
            @Suppress("DEPRECATION")
            val wifiInfo = wm.connectionInfo
            if (wifiInfo != null) {
                val currentSsid = wifiInfo.ssid
                if (!currentSsid.isNullOrBlank() && currentSsid != "<unknown ssid>" && currentSsid != "0x") {
                    ssid = currentSsid.replace("\"", "")
                    isConnected = true
                }
                val ipInt = wifiInfo.ipAddress
                if (ipInt != 0) {
                    localIp = formatIpAddress(ipInt)
                    isConnected = true
                }
            }

            @Suppress("DEPRECATION")
            val dhcp = wm.dhcpInfo
            if (dhcp != null && dhcp.gateway != 0) {
                gatewayIp = formatIpAddress(dhcp.gateway)
                isConnected = true
            }

            // Android 10+ 从 LinkProperties 读取路由网关
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                for (net in cm.allNetworks) {
                    val caps = cm.getNetworkCapabilities(net)
                    if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                        isConnected = true
                        val linkProps = cm.getLinkProperties(net)
                        if (linkProps != null) {
                            for (route in linkProps.routes) {
                                if (route.isDefaultRoute && route.gateway != null) {
                                    val gw = route.gateway?.hostAddress
                                    if (!gw.isNullOrBlank() && gw != "0.0.0.0") {
                                        gatewayIp = gw
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }

            // 如果 SSID 由于系统隐私权限返回 <unknown>，但已检测到相机网卡，友好显示机型网段
            if (ssid == "<unknown>" && isConnected) {
                ssid = "相机 Wi-Fi (${gatewayIp.substringBeforeLast(".")}.x)"
            }
        } catch (e: Exception) {
            Log.e(TAG, "getWifiDetails error: $e")
        }

        return mapOf(
            "connected" to isConnected,
            "ssid" to ssid,
            "gateway" to gatewayIp,
            "ip" to localIp
        )
    }

    private fun formatIpAddress(ip: Int): String {
        return String.format(
            "%d.%d.%d.%d",
            ip and 0xff,
            (ip shr 8) and 0xff,
            (ip shr 16) and 0xff,
            (ip shr 24) and 0xff
        )
    }


    private fun findWifiNetwork(cm: ConnectivityManager, targetHost: String?): Network? {
        for (network in cm.allNetworks) {
            val caps = cm.getNetworkCapabilities(network) ?: continue
            if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) continue
            val linkProperties = cm.getLinkProperties(network)
            if (targetHost.isNullOrBlank()) return network
            if (linkProperties != null && networkContainsHost(linkProperties, targetHost)) return network
        }
        if (targetHost.isNullOrBlank()) {
            val active = cm.activeNetwork
            val caps = active?.let { cm.getNetworkCapabilities(it) }
            if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) return active
        }
        return null
    }

    private fun networkContainsHost(linkProperties: LinkProperties, target: String): Boolean {
        val targetLong = ipv4ToLong(target) ?: return false
        for (linkAddress in linkProperties.linkAddresses) {
            val localLong = ipv4ToLong(linkAddress.address.hostAddress ?: continue) ?: continue
            val prefixLength = linkAddress.prefixLength
            if (prefixLength !in 0..32) continue
            val mask = if (prefixLength == 0) 0L else (0xFFFFFFFFL shl (32 - prefixLength)) and 0xFFFFFFFFL
            if ((targetLong and mask) == (localLong and mask)) return true
        }
        return false
    }

    private fun ipv4ToLong(ip: String): Long? {
        val parts = ip.split('.').map { it.toLongOrNull() ?: return null }
        if (parts.size != 4 || parts.any { it !in 0..255 }) return null
        return (parts[0] shl 24) or (parts[1] shl 16) or (parts[2] shl 8) or parts[3]
    }

    // ==========================================
    // 蓝牙 BLE 扫描与快门控制
    // ==========================================
    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.device?.let { device ->
                val name = try { device.name } catch (e: SecurityException) { null } ?: "未知设备"
                val address = device.address
                val rssi = result.rssi
                val isNikon = name.startsWith("NIKON", true) ||
                        name.startsWith("Nikon", true) ||
                        name.contains("Z ", true) ||
                        name.contains("Z6", true) ||
                        name.contains("Z7", true) ||
                        name.contains("Z5", true) ||
                        name.contains("Z8", true) ||
                        name.contains("Z9", true) ||
                        name.contains("Z50", true) ||
                        name.contains("Z30", true) ||
                        name.contains("Zfc", true) ||
                        name.contains("D850", true) ||
                        name.contains("D780", true) ||
                        name.contains("D7500", true) ||
                        name.contains("D5600", true) ||
                        name.contains("ML-L7", true) ||
                        name.contains("Camera", true)

                scannedDevices[address] = mapOf(
                    "name" to name,
                    "address" to address,
                    "rssi" to rssi,
                    "isNikon" to isNikon
                )
            }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "BLE Scan failed: $errorCode")
            isScanning = false
        }
    }

    private fun startBleScan(result: MethodChannel.Result) {
        val scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            result.error("NO_SCANNER", "Bluetooth LE Scanner 不可用或未开启蓝牙", null)
            return
        }
        scannedDevices.clear()
        try {
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()
            scanner.startScan(null, settings, scanCallback)
            isScanning = true
            result.success(true)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "缺少蓝牙扫描权限: ${e.message}", null)
        } catch (e: Exception) {
            result.error("SCAN_ERROR", e.message, null)
        }
    }

    private fun stopBleScan() {
        if (isScanning) {
            try {
                bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
            } catch (e: Exception) {
                Log.e(TAG, "stopBleScan error: $e")
            }
            isScanning = false
        }
    }

    private fun connectBleDevice(address: String, result: MethodChannel.Result) {
        stopBleScan()
        val device = try {
            bluetoothAdapter?.getRemoteDevice(address)
        } catch (e: Exception) {
            result.error("DEVICE_NOT_FOUND", e.message, null)
            return
        }

        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "设备不存在: $address", null)
            return
        }

        bleStatus = "connecting"
        bleConnectedDeviceName = try { device.name } catch (e: SecurityException) { null } ?: address

        try {
            activeGatt?.close()
            activeGatt = device.connectGatt(this, false, object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        bleStatus = "connected"
                        Log.d(TAG, "BLE 已连接，协商 MTU 517 并发现服务...")
                        try {
                            val mtuRequested = gatt?.requestMtu(517) ?: false
                            if (!mtuRequested) {
                                gatt?.discoverServices()
                            }
                        } catch (e: SecurityException) {
                            Log.e(TAG, "requestMtu/discoverServices SecurityException: $e")
                        }
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        bleStatus = "disconnected"
                        bleConnectedDeviceName = null
                        Log.d(TAG, "BLE 已断开连接")
                    }
                }

                override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
                    Log.d(TAG, "BLE MTU 已协商: mtu=$mtu, status=$status")
                    try {
                        gatt?.discoverServices()
                    } catch (e: SecurityException) {
                        Log.e(TAG, "discoverServices SecurityException: $e")
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                    Log.d(TAG, "BLE 服务发现完成: status=$status, count=${gatt?.services?.size}")
                }
            }, BluetoothDevice.TRANSPORT_LE)

            result.success(mapOf("status" to "connecting", "name" to bleConnectedDeviceName))
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "缺少蓝牙连接权限: ${e.message}", null)
        } catch (e: Exception) {
            result.error("CONNECT_ERROR", e.message, null)
        }
    }

    private fun disconnectBleDevice() {
        try {
            activeGatt?.disconnect()
            activeGatt?.close()
            activeGatt = null
            bleStatus = "disconnected"
            bleConnectedDeviceName = null
        } catch (e: Exception) {
            Log.e(TAG, "disconnectBleDevice error: $e")
        }
    }

    private fun findNikonCharacteristic(gatt: BluetoothGatt, targetUuidStr: String): BluetoothGattCharacteristic? {
        val targetUuid = runCatching { UUID.fromString(targetUuidStr) }.getOrNull() ?: return null
        val lssServiceUuid = UUID.fromString("0000de00-3dd4-4255-8d62-6dc7b9bd5561")
        gatt.getService(lssServiceUuid)?.getCharacteristic(targetUuid)?.let { return it }
        for (service in gatt.services) {
            service.getCharacteristic(targetUuid)?.let { return it }
        }
        return null
    }

    private fun writeGattBytes(gatt: BluetoothGatt, ch: BluetoothGattCharacteristic, data: ByteArray): Boolean {
        return try {
            @Suppress("DEPRECATION")
            ch.value = data
            @Suppress("DEPRECATION")
            gatt.writeCharacteristic(ch)
        } catch (e: SecurityException) {
            Log.e(TAG, "writeGattBytes SecurityException: $e")
            false
        } catch (e: Exception) {
            Log.e(TAG, "writeGattBytes error: $e")
            false
        }
    }

    private fun sendBleCommand(command: String): Boolean {
        val gatt = activeGatt ?: return false
        val data = when (command) {
            "half_press" -> byteArrayOf(0x01)
            "shutter" -> byteArrayOf(0x02)
            "record_video" -> byteArrayOf(0x03)
            "wifi_enable" -> byteArrayOf(0x01, 0x01, 0x00, 0x00)
            else -> byteArrayOf(0x00)
        }
        // 优先匹配尼康 LSS 控制特征 (0x2021 / 0x2008)
        val preferredUuids = if (command == "wifi_enable") {
            listOf(
                "00002008-3dd4-4255-8d62-6dc7b9bd5561",
                "00002021-3dd4-4255-8d62-6dc7b9bd5561"
            )
        } else {
            listOf(
                "00002021-3dd4-4255-8d62-6dc7b9bd5561",
                "00002008-3dd4-4255-8d62-6dc7b9bd5561"
            )
        }
        for (uuid in preferredUuids) {
            val ch = findNikonCharacteristic(gatt, uuid)
            if (ch != null && writeGattBytes(gatt, ch, data)) {
                return true
            }
        }
        for (service in gatt.services) {
            for (ch in service.characteristics) {
                val props = ch.properties
                if ((props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) ||
                    (props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)) {
                    if (writeGattBytes(gatt, ch, data)) return true
                }
            }
        }
        return false
    }

    /**
     * 向尼康 BLE LSS 0x2007 (charLocationInformation) 特征写入 41 字节 GPS 地理信息载荷，
     * 并可选向 0x2006 (charCurrentTime) 同步 7 字节时间载荷（参考 gkoh/furble 与 hurui200320/nsg）。
     */
    private fun sendBleLocationPayload(geoPayload: ByteArray, timePayload: ByteArray?): Map<String, Any> {
        val gatt = activeGatt ?: return mapOf(
            "success" to false,
            "reason" to "BLE_NOT_CONNECTED"
        )
        var timeWritten = false
        if (timePayload != null && timePayload.size == 7) {
            val timeCh = findNikonCharacteristic(gatt, "00002006-3dd4-4255-8d62-6dc7b9bd5561")
            if (timeCh != null) {
                timeWritten = writeGattBytes(gatt, timeCh, timePayload)
            }
        }

        val geoCh = findNikonCharacteristic(gatt, "00002007-3dd4-4255-8d62-6dc7b9bd5561")
        if (geoCh != null) {
            val ok = writeGattBytes(gatt, geoCh, geoPayload)
            return mapOf(
                "success" to ok,
                "characteristic" to "0x2007",
                "timeSynced" to timeWritten
            )
        }

        // 若目标设备使用通用可写特征（兼容测试外设），回退写入第一个可写特征
        for (service in gatt.services) {
            for (ch in service.characteristics) {
                val props = ch.properties
                if ((props and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) ||
                    (props and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0)) {
                    val ok = writeGattBytes(gatt, ch, geoPayload)
                    return mapOf(
                        "success" to ok,
                        "characteristic" to ch.uuid.toString(),
                        "timeSynced" to timeWritten
                    )
                }
            }
        }
        return mapOf(
            "success" to false,
            "reason" to "GEO_CHAR_NOT_FOUND"
        )
    }

    /**
     * 使用 Android 原生 LocationManager 读取手机最新定位（GPS / Network / Passive）。
     * 若尚未授予精确位置权限，会触发一次运行时权限申请。
     */
    private fun getCurrentLocationFix(): Map<String, Any> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val fineGranted = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarseGranted = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            if (!fineGranted && !coarseGranted) {
                requestPermissions(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    ),
                    1002
                )
                return mapOf("success" to false, "reason" to "PERMISSION_REQUIRED")
            }
        }
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                ?: return mapOf("success" to false, "reason" to "NO_LOCATION_SERVICE")
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER
            )
            var bestLocation: Location? = null
            for (provider in providers) {
                val loc = runCatching { lm.getLastKnownLocation(provider) }.getOrNull() ?: continue
                if (bestLocation == null || loc.time > bestLocation!!.time ||
                    (loc.hasAccuracy() && bestLocation!!.hasAccuracy() && loc.accuracy < bestLocation!!.accuracy)
                ) {
                    bestLocation = loc
                }
            }
            if (bestLocation == null) {
                return mapOf("success" to false, "reason" to "LOCATION_UNAVAILABLE")
            }
            mapOf(
                "success" to true,
                "latitude" to bestLocation.latitude,
                "longitude" to bestLocation.longitude,
                "altitude" to if (bestLocation.hasAltitude()) bestLocation.altitude else 0.0,
                "accuracy" to if (bestLocation.hasAccuracy()) bestLocation.accuracy.toDouble() else 0.0,
                "timestamp" to bestLocation.time
            )
        } catch (e: SecurityException) {
            mapOf("success" to false, "reason" to "PERMISSION_DENIED")
        } catch (e: Exception) {
            mapOf("success" to false, "reason" to (e.message ?: "UNKNOWN_ERROR"))
        }
    }

    private fun copyUriToCache(uri: Uri, fallbackName: String = "recipe.NP3"): String? {
        return try {
            val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
            } ?: uri.lastPathSegment ?: fallbackName
            val safe = name.replace(Regex("[^A-Za-z0-9._\\u4e00-\\u9fa5-]"), "_")
            val temp = File(cacheDir, "picked_${System.nanoTime()}_$safe")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(temp).use { output -> input.copyTo(output) }
            }
            if (temp.exists() && temp.length() > 0L) temp.absolutePath else null
        } catch (_: Exception) {
            null
        }
    }

    private fun captureIntentFiles(srcIntent: Intent?) {
        if (srcIntent == null) return
        val action = srcIntent.action ?: return
        val uris = mutableListOf<Uri>()
        when (action) {
            Intent.ACTION_VIEW -> {
                srcIntent.data?.let { uris.add(it) }
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val streamUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    srcIntent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    srcIntent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
                if (streamUri != null) uris.add(streamUri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    srcIntent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    srcIntent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }
                if (list != null) uris.addAll(list)
            }
        }
        for (u in uris) {
            val path = copyUriToCache(u)
            if (path != null && !pendingIncomingFilePaths.contains(path)) {
                pendingIncomingFilePaths.add(path)
            }
        }
        srcIntent.action = null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureIntentFiles(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_PICK_MULTI_FILES) {
            val res = pendingPickMultiFilesResult
            pendingPickMultiFilesResult = null
            if (resultCode == Activity.RESULT_OK && data != null) {
                val paths = mutableListOf<String>()
                val clip = data.clipData
                if (clip != null) {
                    for (i in 0 until clip.itemCount) {
                        val u = clip.getItemAt(i)?.uri ?: continue
                        copyUriToCache(u)?.let { paths.add(it) }
                    }
                } else {
                    data.data?.let { u ->
                        copyUriToCache(u)?.let { paths.add(it) }
                    }
                }
                res?.success(paths)
            } else {
                res?.success(emptyList<String>())
            }
        }
        if (requestCode == REQUEST_PICK_FILE) {
            val res = pendingPickFileResult
            pendingPickFileResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val name = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                        val idx = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0 && cursor.moveToFirst()) cursor.getString(idx) else null
                    } ?: "picked_lut.cube"
                    val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
                    val temp = File(cacheDir, "picked_${System.currentTimeMillis()}_$safe")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(temp).use { output -> input.copyTo(output) }
                    }
                    res?.success(temp.absolutePath)
                } catch (e: Exception) {
                    res?.error("PICK_FILE_ERROR", e.localizedMessage, null)
                }
            } else {
                res?.success(null)
            }
        }
        if (requestCode == REQUEST_PICK_IMAGE) {
            val res = pendingPickResult
            pendingPickResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                try {
                    val inputStream = contentResolver.openInputStream(uri)
                    val tempFile = File(cacheDir, "picked_photo_${System.currentTimeMillis()}.jpg")
                    val outputStream = FileOutputStream(tempFile)
                    inputStream?.copyTo(outputStream)
                    inputStream?.close()
                    outputStream.close()
                    res?.success(tempFile.absolutePath)
                } catch (e: Exception) {
                    res?.error("PICK_ERROR", e.localizedMessage, null)
                }
            } else {
                res?.success(null)
            }
        }
    }

    /**
     * 用本地文件字节覆盖已有 MediaStore 条目的内容。
     * 仅对本应用写入的条目可靠；异常或 0 字节写入返回 false，由 Dart 回退到另存。
     */
    private fun mediaTask(result: MethodChannel.Result, work: () -> Any?) {
        mediaExecutor.execute {
            try {
                val value = work()
                runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                val code = if (e is IllegalStateException) "OVERWRITE_RESTORE_FAILED" else "MEDIA_READ_FAILED"
                runOnUiThread { result.error(code, e.message, null) }
            }
        }
    }

    private fun listSavedMedia(): List<Map<String, Any>> {
        val collection = MediaStore.Files.getContentUri("external")
        val pathColumn = if (Build.VERSION.SDK_INT >= 29) MediaStore.MediaColumns.RELATIVE_PATH else MediaStore.MediaColumns.DATA
        val columns = arrayOf(MediaStore.MediaColumns._ID, MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.DATE_MODIFIED, pathColumn)
        val found = mutableListOf<Map<String, Any>>()
        val selection = "$pathColumn LIKE ? OR $pathColumn LIKE ?"
        contentResolver.query(collection, columns, selection, arrayOf("%/Zync/%", "Zync/%"), null)?.use { c ->
            while (c.moveToNext()) {
                val path = c.getString(4) ?: continue
                if (!path.replace('\\', '/').split('/').any { it.equals("Zync", true) }) continue
                val name = c.getString(1) ?: continue
                if (!Regex("(?i).*\\.(jpg|jpeg|png|nef|nrw|mov|mp4)$").matches(name)) continue
                val uri = if (Build.VERSION.SDK_INT < 29) path else
                    Uri.withAppendedPath(resolveSaveTarget(name).first, c.getLong(0).toString()).toString()
                found.add(mapOf("uri" to uri,
                    "name" to name, "size" to c.getLong(2), "modified" to c.getLong(3) * 1000L,
                    "path" to if (Build.VERSION.SDK_INT < 29) path else ""))
            }
        }
        return found
    }

    private fun materializeMedia(target: String): String? {
        val uri = Uri.parse(target)
        require(uri.scheme == "content" && uri.authority == "media") { "无效的媒体 URI" }
        val dir = File(cacheDir, "saved_media").apply { mkdirs() }
        val digest = MessageDigest.getInstance("SHA-256").digest(target.toByteArray()).joinToString("") { "%02x".format(it) }
        var size = 0L
        var modified = 0L
        var name = "image.jpg"
        contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.SIZE, MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (!c.moveToFirst()) return null
            size = c.getLong(0); modified = c.getLong(1); name = c.getString(2) ?: name
        } ?: return null
        val ext = name.substringAfterLast('.', "jpg").lowercase().filter { it.isLetterOrDigit() }
        val dest = File(dir, "${digest}_${modified}_${size}.$ext")
        if (dest.exists() && dest.length() == size && size > 0) {
            dest.setLastModified(System.currentTimeMillis())
            return dest.absolutePath
        }
        val partial = File(dir, dest.name + ".part")
        try {
            contentResolver.openInputStream(uri)?.use { input -> FileOutputStream(partial).use { input.copyTo(it) } } ?: return null
            if (partial.length() != size || size == 0L) throw java.io.IOException("本地媒体长度不完整")
            if (!partial.renameTo(dest)) throw java.io.IOException("本地缓存保存失败")
            // 仅删除此 URI 的旧缓存；其他照片由应用缓存生命周期管理。
            dir.listFiles()?.filter { it.name.startsWith(digest + "_") && it != dest }?.forEach { it.delete() }
            // 缓存上限 128MiB，单张更大的当前照片保留；严格限额需改为流式读取。
            val cached = dir.listFiles()?.filter { it.isFile }?.sortedBy { it.lastModified() } ?: emptyList()
            var total = cached.sumOf { it.length() }
            for (file in cached) {
                if (total <= 128L * 1024 * 1024) break
                if (file == dest) continue
                val length = file.length()
                if (file.delete()) total -= length
            }
            return dest.absolutePath
        } finally { partial.delete() }
    }

    private fun mediaMatchesFile(uri: Uri, file: File): Boolean {
        fun digest(input: java.io.InputStream): ByteArray {
            val hash = MessageDigest.getInstance("SHA-256")
            val buffer = ByteArray(64 * 1024)
            while (true) { val n = input.read(buffer); if (n < 0) break; hash.update(buffer, 0, n) }
            return hash.digest()
        }
        val expected = FileInputStream(file).use { digest(it) }
        val actual = contentResolver.openInputStream(uri)?.use { digest(it) } ?: return false
        return expected.contentEquals(actual)
    }

    private fun overwriteMediaEntry(mediaUri: String, srcPath: String): Boolean {
        val srcFile = File(srcPath)
        if (!srcFile.exists() || srcFile.length() == 0L) return false
        val uri = Uri.parse(mediaUri)
        if (uri.scheme != "content" || uri.authority != "media") return false
        if (Build.VERSION.SDK_INT >= 29) {
            contentResolver.query(uri, arrayOf(MediaStore.MediaColumns.OWNER_PACKAGE_NAME), null, null, null)?.use { c ->
                if (!c.moveToFirst() || c.getString(0) != packageName) return false
            } ?: return false
        }
        var keepBackup = false
        val backupDir = File(filesDir, "photo_backups").apply { mkdirs() }
        val backup = File.createTempFile("zync_original_", ".bak", backupDir)
        try {
            contentResolver.openInputStream(uri)?.use { input -> FileOutputStream(backup).use { input.copyTo(it) } } ?: return false
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { out -> FileInputStream(srcFile).use { it.copyTo(out) } }
                    ?: return false
                if (!mediaMatchesFile(uri, srcFile)) throw java.io.IOException("覆盖校验失败")
                val values = ContentValues().apply { put(MediaStore.MediaColumns.DATE_MODIFIED, System.currentTimeMillis() / 1000) }
                contentResolver.update(uri, values, null, null)
                val digest = MessageDigest.getInstance("SHA-256").digest(mediaUri.toByteArray()).joinToString("") { "%02x".format(it) }
                File(cacheDir, "saved_media").listFiles()?.filter { it.name.startsWith(digest + "_") }?.forEach { it.delete() }
                return true
            } catch (writeError: Exception) {
                try {
                    contentResolver.openOutputStream(uri, "wt")?.use { out -> FileInputStream(backup).use { it.copyTo(out) } }
                        ?: throw java.io.IOException("无法恢复原图")
                    if (!mediaMatchesFile(uri, backup)) throw java.io.IOException("原图恢复校验失败")
                } catch (restoreError: Exception) {
                    // 恢复失败时保留备份，供用户恢复；绝不能静默另存后报告成功。
                    keepBackup = true
                    throw IllegalStateException("原图恢复失败；备份位于 " + backup.absolutePath, restoreError)
                }
                return false
            }
        } catch (e: IllegalStateException) { throw e
        } catch (e: Exception) { Log.e(TAG, "overwrite failed", e); return false
        } finally { if (!keepBackup) backup.delete() }
    }

    /**
     * 批量按文件名反查 MediaStore URI。
     * 每个媒体集合只查询一次，返回 fileName -> URI；只接受 Zync 目录，避免误删同名系统文件。
     */
    private fun findMediaUrisByNames(fileNames: List<String>): Map<String, String> {
        if (fileNames.isEmpty()) return emptyMap()
        val wanted = fileNames.toSet()
        val result = mutableMapOf<String, String>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.RELATIVE_PATH
        )
        val collections = listOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Files.getContentUri("external")
        )
        for (collection in collections) {
            try {
                contentResolver.query(collection, projection, null, null, null)?.use { cursor ->
                    val idIdx = cursor.getColumnIndex(MediaStore.MediaColumns._ID)
                    val nameIdx = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                    val relIdx = cursor.getColumnIndex(MediaStore.MediaColumns.RELATIVE_PATH)
                    while (cursor.moveToNext()) {
                        if (idIdx < 0 || nameIdx < 0) continue
                        val name = cursor.getString(nameIdx) ?: continue
                        if (name !in wanted || result.containsKey(name)) continue
                        val relative = if (relIdx >= 0) cursor.getString(relIdx) else null
                        if (relative != null && !relative.contains("Zync", ignoreCase = true)) continue
                        result[name] = Uri.withAppendedPath(collection, cursor.getLong(idIdx).toString()).toString()
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "findMediaUrisByNames failed: " + e.message)
            }
        }
        return result
    }

    /**
     * 删除公共媒体库条目（content:// URI，Android 10+ 无需存储权限）或旧系统绝对路径文件。
     * 返回 true 表示条目/文件已不存在或删除成功。
     */
    private fun deleteMediaTarget(target: String): Boolean {
        return try {
            if (target.startsWith("content://")) {
                val uri = Uri.parse(target)
                val deleted = contentResolver.delete(uri, null, null)
                deleted > 0
            } else {
                val file = File(target)
                if (file.exists()) file.delete() else true
            }
        } catch (e: Exception) {
            Log.e(TAG, "deleteMediaTarget failed: " + e.message)
            false
        }
    }

    /**
     * 按媒体类型选择公共集合与目录。
     * 统一落在 DCIM/Zync：DCIM 是相机目录，系统与厂商相册一定会索引，
     * 也与应用内提示「保存路径: /DCIM/Zync」保持一致。
     */
    private fun resolveSaveTarget(fileName: String): Triple<Uri, String, String?> {
        val lower = fileName.lowercase()
        val mime = when {
            lower.endsWith(".png") -> "image/png"
            lower.endsWith(".nef") || lower.endsWith(".nrw") -> "image/x-nikon-nef"
            lower.endsWith(".mp4") -> "video/mp4"
            lower.endsWith(".mov") -> "video/quicktime"
            else -> "image/jpeg"
        }
        val isVideo = lower.endsWith(".mp4") || lower.endsWith(".mov")
        val isRaw = lower.endsWith(".nef") || lower.endsWith(".nrw")
        return when {
            isVideo -> Triple(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, "DCIM/Zync/", mime)
            // Android 10+ 分区存储：DCIM 仅允许 Images 与 Video 集合，NEF/NRW 属于原生 Raw 图片，归属 MediaStore.Images
            isRaw -> Triple(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "DCIM/Zync/", mime)
            else -> Triple(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, "DCIM/Zync/", mime)
        }
    }

    private fun mimeForFileName(fileName: String): String = resolveSaveTarget(fileName).third ?: "image/jpeg"

    /** 按调用方给定的文件名（可覆盖临时 .part 名）保存到公共媒体库。 */
    private fun saveMediaToPublic(srcFile: File, fileName: String): String? {
        return saveMediaToPublicInternal(srcFile, fileName)
    }

    /**
     * 将应用私有文件保存进系统公共媒体库（Android 10+ 走 MediaStore，无需存储权限）。
     * 返回公共 MediaStore Uri 字符串；失败返回 null，由调用方标记任务失败。
     */
    private fun saveImageToPublicPictures(srcFile: File): String? =
        saveMediaToPublicInternal(srcFile, srcFile.name)

    private fun saveMediaToPublicInternal(srcFile: File, fileName: String): String? {
        val (collection, relativePath, mime) = resolveSaveTarget(fileName)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime ?: "application/octet-stream")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                var uri = contentResolver.insert(collection, values)
                if (uri == null && (fileName.lowercase().endsWith(".nef") || fileName.lowercase().endsWith(".nrw"))) {
                    // 兼容少数对自定义 RAW MIME 过滤严格的 ROM，先尝试以通用 image/* 插入
                    values.put(MediaStore.MediaColumns.MIME_TYPE, "image/*")
                    uri = contentResolver.insert(collection, values)
                }
                if (uri == null) return null
                try {
                    contentResolver.openOutputStream(uri)?.use { out ->
                        FileInputStream(srcFile).use { input -> input.copyTo(out) }
                    } ?: run {
                        contentResolver.delete(uri, null, null)
                        return null
                    }
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                    // 部分 ROM 在 IS_PENDING 翻转时不会解析新文件元数据，
                    // 导致手机相册看不到拍摄参数（焦距/ISO/快门/光圈）；
                    // 这里按真实路径再走一次媒体扫描，与「用读卡器拷进 DCIM」完全同一条链路。
                    scanSavedMedia(relativePath, fileName)
                    return uri.toString()
                } catch (e: Exception) {
                    contentResolver.delete(uri, null, null)
                    throw e
                }
            } else {
                val targetDir = File("/storage/emulated/0/DCIM/Zync")
                if (!targetDir.exists()) targetDir.mkdirs()
                val targetFile = File(targetDir, fileName)
                FileInputStream(srcFile).use { input ->
                    FileOutputStream(targetFile).use { output -> input.copyTo(output) }
                }
                MediaScannerConnection.scanFile(applicationContext, arrayOf(targetFile.absolutePath), null, null)
                return targetFile.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "saveImageToPublicPictures failed: ${e.message}")
        }
        return null
    }

    /** 保存完成后按真实路径触发媒体扫描，让系统/厂商相册重新解析 EXIF 拍摄参数。 */
    private fun scanSavedMedia(relativePath: String, fileName: String) {
        try {
            val target = File(File(Environment.getExternalStorageDirectory(), relativePath), fileName)
            if (!target.exists()) {
                Log.w(TAG, "scanSavedMedia skipped, not found: ${target.absolutePath}")
                return
            }
            MediaScannerConnection.scanFile(applicationContext, arrayOf(target.absolutePath), null, null)
            Log.d(TAG, "media scan requested: ${target.absolutePath} hasExif=${fileHasExif(target)}")
        } catch (e: Exception) {
            Log.w(TAG, "scanSavedMedia skipped: ${e.message}")
        }
    }

    /** 粗略检测 JPEG 是否带 EXIF（APP1 "Exif\\0\\0"），仅用于日志定位导出丢失参数的问题。 */
    private fun fileHasExif(file: File): Boolean {
        return try {
            FileInputStream(file).use { input ->
                val head = ByteArray(minOf(file.length(), 128L * 1024L).toInt())
                val read = input.read(head)
                if (read <= 0) return false
                val marker = byteArrayOf(0x45, 0x78, 0x69, 0x66, 0x00, 0x00) // Exif\0\0
                for (i in 0..(read - marker.size)) {
                    var matched = true
                    for (j in marker.indices) {
                        if (head[i + j] != marker[j]) {
                            matched = false
                            break
                        }
                    }
                    if (matched) return true
                }
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    /** 提取视频首帧缩略图并缓存为 JPEG 文件，返回缩略图本地文件绝对路径。 */
    private fun extractVideoThumbnail(videoPath: String, width: Int, height: Int): String? {
        val thumbDir = File(cacheDir, "video_thumbs")
        if (!thumbDir.exists()) thumbDir.mkdirs()
        val hash = (videoPath + "_" + width + "_" + height).hashCode().toString()
        val target = File(thumbDir, "thumb_$hash.jpg")
        if (target.exists() && target.length() > 0) return target.absolutePath

        val retriever = MediaMetadataRetriever()
        return try {
            if (videoPath.startsWith("content://")) {
                retriever.setDataSource(applicationContext, Uri.parse(videoPath))
            } else {
                retriever.setDataSource(videoPath)
            }
            val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                retriever.getScaledFrameAtTime(
                    100000L, // 0.1s
                    MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
                    width,
                    height
                ) ?: retriever.frameAtTime
            } else {
                retriever.frameAtTime
            } ?: return null

            FileOutputStream(target).use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
            }
            target.absolutePath
        } catch (e: Exception) {
            Log.w(TAG, "extractVideoThumbnail failed: ${e.message}")
            null
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }

    /**
     * 传输保活：启动前台服务。
     * Android 12+ 禁止后台启动前台服务，此时静默降级为「仅进程内传输」，绝不中断传输流程。
     */
    private fun startTransferKeepAlive(title: String) {
        try {
            val intent = Intent(this, TransferKeepAliveService::class.java).apply {
                action = TransferKeepAliveService.ACTION_START
                putExtra(TransferKeepAliveService.EXTRA_TITLE, title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.w(TAG, "startTransferKeepAlive skipped: $e")
        }
    }

    private fun updateTransferKeepAlive(completed: Int, total: Int, paused: Boolean) {
        try {
            val intent = Intent(this, TransferKeepAliveService::class.java).apply {
                action = TransferKeepAliveService.ACTION_UPDATE
                putExtra(TransferKeepAliveService.EXTRA_COMPLETED, completed)
                putExtra(TransferKeepAliveService.EXTRA_TOTAL, total)
                putExtra(TransferKeepAliveService.EXTRA_PAUSED, paused)
                putExtra(TransferKeepAliveService.EXTRA_TITLE, "Zync 正在传输")
                putExtra(
                    TransferKeepAliveService.EXTRA_TEXT,
                    if (paused) "已暂停 · 返回应用可继续" else "已完成 $completed / $total"
                )
            }
            startService(intent)
        } catch (e: Exception) {
            Log.w(TAG, "updateTransferKeepAlive skipped: $e")
        }
    }

    private fun stopTransferKeepAlive() {
        try {
            val intent = Intent(this, TransferKeepAliveService::class.java).apply {
                action = TransferKeepAliveService.ACTION_STOP
            }
            startService(intent)
        } catch (e: Exception) {
            // 服务未在运行或系统限制时忽略即可（通知会随进程结束消失）
            Log.w(TAG, "stopTransferKeepAlive skipped: $e")
        }
    }

    /** Android 13+ 首次传输时申请通知权限；被拒绝也不影响前台服务继续运行。 */
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        try {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATION_PERMISSION
            )
        } catch (e: Exception) {
            Log.w(TAG, "requestNotificationPermission skipped: $e")
        }
    }

    override fun onDestroy() {
        mediaExecutor.shutdown()
        super.onDestroy()
        if (cameraNetworkCallback != null) {
            try {
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                cm.unregisterNetworkCallback(cameraNetworkCallback!!)
            } catch (_: Exception) {}
        }
        unbindProcessWifi()
        disconnectBleDevice()
        // USB 会话的关闭同样放到 USB 线程串行执行，避免与在途的 bulk 传输互相踩踏。
        runCatching { usbExecutor.execute { closeUsbSession(null) } }
        usbExecutor.shutdown()
        try {
            usbPermissionReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        usbPermissionReceiver = null
    }
}
