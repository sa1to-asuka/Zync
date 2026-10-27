package com.zync.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

/**
 * 传输期间的前台服务：让下载 / 边拍边传在退到后台或锁屏后不被系统回收。
 *
 * 只做两件事：
 * 1. 挂一条常驻进度通知，用户可在通知栏看到传输进度；
 * 2. 持有一把 PARTIAL_WAKE_LOCK 保证 CPU 不被挂起（USB 传输没有 WifiLock 可依赖）。
 *
 * 业务判断全部在 Dart 侧 (DownloadManager)，本服务只按指令显示 / 更新 / 停止。
 */
class TransferKeepAliveService : Service() {

    companion object {
        const val ACTION_START = "com.zync.app.transfer.START"
        const val ACTION_UPDATE = "com.zync.app.transfer.UPDATE"
        const val ACTION_STOP = "com.zync.app.transfer.STOP"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_COMPLETED = "completed"
        const val EXTRA_TOTAL = "total"
        const val EXTRA_PAUSED = "paused"

        private const val TAG = "ZyncTransfer"
        private const val CHANNEL_ID = "zync_transfer"
        private const val NOTIFICATION_ID = 1001

        @Volatile
        var currentLocaleCode: String = "zh"

        // 最长保活 6 小时，与 Android 15 对 dataSync 前台服务的每日上限对齐，
        // 避免异常路径下永不放锁；正常在传输队列清空时由 Dart 侧主动停止。
        private const val WAKELOCK_TIMEOUT_MS = 6 * 60 * 60 * 1000L
    }

    private fun localizedContext(): Context {
        val locale = when (currentLocaleCode.lowercase()) {
            "en" -> Locale.ENGLISH
            "ja" -> Locale.JAPANESE
            else -> Locale.SIMPLIFIED_CHINESE
        }
        val config = Configuration(resources.configuration)
        config.setLocale(locale)
        return createConfigurationContext(config)
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        val lCtx = localizedContext()
        val title = intent?.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() }
            ?: lCtx.getString(R.string.transfer_default_title)
        val text = intent?.getStringExtra(EXTRA_TEXT).orEmpty()
        val completed = intent?.getIntExtra(EXTRA_COMPLETED, 0) ?: 0
        val total = intent?.getIntExtra(EXTRA_TOTAL, 0) ?: 0
        val paused = intent?.getBooleanExtra(EXTRA_PAUSED, false) ?: false

        val notification = buildNotification(title, text, completed, total, paused)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        acquireWakeLock()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Zync:TransferWakeLock")
                .apply { setReferenceCounted(false) }
            wakeLock?.acquire(WAKELOCK_TIMEOUT_MS)
        } catch (e: Exception) {
            Log.w(TAG, "acquireWakeLock failed: $e")
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val lCtx = localizedContext()
        val channel = NotificationChannel(
            CHANNEL_ID,
            lCtx.getString(R.string.transfer_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = lCtx.getString(R.string.transfer_channel_desc)
            setShowBadge(false)
        }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(
        title: String,
        text: String,
        completed: Int,
        total: Int,
        paused: Boolean
    ): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)

        packageManager.getLaunchIntentForPackage(packageName)?.let { launch ->
            launch.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            builder.setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }

        if (total > 0) {
            val percent = (completed * 100 / total).coerceIn(0, 100)
            builder.setProgress(100, percent, false)
        } else {
            builder.setProgress(0, 0, !paused)
        }
        return builder.build()
    }
}
