package com.zync.app

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * 视频抽帧工具。
 *
 * 单独成文件，避免把 [MediaMetadataRetriever] 的解码逻辑散落在通道类里。
 *
 * 性能约定：[MediaMetadataRetriever.getFrameAtTime] 会做解码，
 * 4K/HEVC 上单帧可达数十毫秒，因此所有抽帧都在 [frameExecutor] 上执行，
 * 主线程只负责发起请求和接收结果。
 */
object VideoFrameGrabber {
    /** 抽帧专用单线程执行器，避免并发解码打爆内存。 */
    private val frameExecutor: Executor = Executors.newSingleThreadExecutor()

    /** 打开文件并抽单帧（后台线程）。 */
    fun grab(path: String, timeUs: Long, maxEdge: Int): ByteArray? {
        if (path.isBlank() || !File(path).exists()) return null
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            grabFrom(retriever, timeUs, maxEdge)
        } catch (_: Throwable) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    /**
     * 在同一个已打开的 [retriever] 上依次抽多帧（后台线程）。
     *
     * 只 setDataSource 一次，避免重复打开文件。
     * 抽不到的时间点返回 null，不中断整体流程。
     */
    fun grabMany(
        path: String,
        timesUs: LongArray,
        maxEdge: Int,
    ): List<ByteArray?> {
        if (path.isBlank() || !File(path).exists()) return emptyList()
        if (timesUs.isEmpty()) return emptyList()
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            timesUs.map { timeUs ->
                runCatching { grabFrom(retriever, timeUs, maxEdge) }.getOrNull()
            }
        } catch (_: Throwable) {
            emptyList()
        } finally {
            runCatching { retriever.release() }
        }
    }

    /** 在后台执行器上跑一个抽帧任务。 */
    fun executeAsync(task: () -> Unit) {
        frameExecutor.execute {
            runCatching { task() }
        }
    }

    /** 复用同一 retriever 抽单帧并压成 JPEG（调用方保证在后台线程）。 */
    private fun grabFrom(
        retriever: MediaMetadataRetriever,
        timeUs: Long,
        maxEdge: Int,
    ): ByteArray? {
        val target = maxEdge.coerceIn(48, 720)
        val raw = retriever.getFrameAtTime(
            timeUs.coerceAtLeast(0L),
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
        ) ?: return null
        return try {
            val scale = target.toFloat() / max(raw.width, raw.height)
            val w = if (scale < 1f) max(1, (raw.width * scale).roundToInt()) else raw.width
            val h = if (scale < 1f) max(1, (raw.height * scale).roundToInt()) else raw.height
            val scaled = if (w == raw.width && h == raw.height) {
                raw
            } else {
                Bitmap.createScaledBitmap(raw, w, h, true)
            }
            val stream = ByteArrayOutputStream(w * h / 4 + 1024)
            scaled.compress(Bitmap.CompressFormat.JPEG, 85, stream)
            if (scaled !== raw) scaled.recycle()
            raw.recycle()
            stream.toByteArray()
        } catch (_: Throwable) {
            runCatching { raw.recycle() }
            null
        }
    }
}
