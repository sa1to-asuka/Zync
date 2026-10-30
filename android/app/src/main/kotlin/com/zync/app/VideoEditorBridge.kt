package com.zync.app

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.DefaultGainProvider
import androidx.media3.common.audio.GainProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.VideoEncoderSettings
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

@UnstableApi
class VideoEditorBridge(
    private val context: Context,
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val CHANNEL = "com.zync.app/video_editor"
        private const val TAG = "ZyncVideo"

        /** 调色代理预览的输出高度上限；先缩放再跑 GL 效果，避免 4K 全分辨率失败。 */
        private const val PREVIEW_MAX_HEIGHT = 1080

        // MediaFormat 在 SDK 36 中没有暴露 KEY_COLOR_PRIMARIES / COLOR_PRIMARIES_* 常量，
        // 这里按 ISO/IEC 23091-2 与 Android CodecCapabilities 的取值直接定义。
        private const val KEY_COLOR_PRIMARIES = "color-primaries"
        private const val COLOR_TRANSFER_SMPTE_ST_2084 = 16
        private const val COLOR_PRIMARIES_BT709 = 1
        private const val COLOR_PRIMARIES_DISPLAY_P3 = 12
        private const val COLOR_PRIMARIES_BT2020 = 9
        private const val COLOR_PRIMARIES_BT2100_HLG = 10
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var transformer: Transformer? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingOutput: File? = null
    private var pendingDurationUs: Long = 0L
    private var progressRunnable: Runnable? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(capabilities())
            "importAsset" -> {
                val path = call.argument<String>("path").orEmpty()
                result.success(importAsset(path))
            }
            "createProxy" -> {
                val path = call.argument<String>("path").orEmpty()
                val height = call.argument<Int>("targetHeight") ?: 1080
                createProxy(path, height, result)
            }
            "renderPreview" -> {
                val projectJson = call.argument<String>("project").orEmpty()
                val clipId = call.argument<String>("clipId").orEmpty()
                val sourcePath = call.argument<String>("sourcePath").orEmpty()
                renderPreview(projectJson, clipId, sourcePath, result)
            }
            "export" -> {
                val projectJson = call.argument<String>("project").orEmpty()
                val outputPath = call.argument<String>("outputPath").orEmpty()
                export(projectJson, outputPath, result)
            }
            "captureFrame" -> {
                val path = call.argument<String>("path").orEmpty()
                val timeUs = call.argument<Number>("timeUs")?.toLong() ?: 0L
                val maxEdge = call.argument<Int>("maxEdge") ?: 480
                captureFrameAsync(path, timeUs, maxEdge, result)
            }
            "captureFrames" -> {
                val path = call.argument<String>("path").orEmpty()
                val times = call.argument<List<*>>("timesUs")
                    ?.mapNotNull { (it as? Number)?.toLong() }
                    ?.toLongArray()
                    ?: LongArray(0)
                val maxEdge = call.argument<Int>("maxEdge") ?: 160
                captureFrames(path, times, maxEdge, result)
            }
            "cancel" -> {
                cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun capabilities(): Map<String, Any> {
        var decodeHevc = false
        var decodeHevcMain10 = false
        var encodeH264 = false
        var encodeHevc = false
        try {
            val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
            for (info in list.codecInfos) {
                for (type in info.supportedTypes) {
                    val isHevc = type.equals(MimeTypes.VIDEO_H265, ignoreCase = true)
                    val isH264 = type.equals(MimeTypes.VIDEO_H264, ignoreCase = true)
                    if (info.isEncoder) {
                        if (isH264) encodeH264 = true
                        if (isHevc) encodeHevc = true
                    } else {
                        if (isHevc) {
                            decodeHevc = true
                            if (Build.VERSION.SDK_INT >= 29 && info.isHardwareAccelerated) {
                                decodeHevcMain10 = true
                            }
                        }
                    }
                }
            }
        } catch (_: Throwable) {
        }
        return mapOf(
            "available" to true,
            "media3Available" to true,
            "hardwareDecodeHevc" to decodeHevc,
            "hardwareDecodeHevcMain10" to decodeHevcMain10,
            "hardwareEncodeH264" to encodeH264,
            "hardwareEncodeHevc" to encodeHevc,
            "reason" to "",
        )
    }

    private fun importAsset(path: String): Map<String, Any>? {
        if (path.isBlank()) return null
        val file = File(path)
        if (!file.exists()) return null
        val retriever = MediaMetadataRetriever()
        var durationUs = 0L
        var width = 0
        var height = 0
        var rotation = 0
        var bitDepth = 8
        var videoMime = ""
        var audioMime = ""
        var colorTransfer = "sdr"
        var colorPrimaries = "bt709"
        var isHdr = false
        var isHlg = false
        var hasAudio = false
        try {
            retriever.setDataSource(path)
            durationUs = (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L) * 1000L
            width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            hasAudio = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) != null
        } catch (_: Throwable) {
        } finally {
            runCatching { retriever.release() }
        }

        try {
            val extractor = MediaExtractor()
            extractor.setDataSource(path)
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME).orEmpty()
                if (mime.startsWith("video/")) {
                    videoMime = mime
                    width = format.getIntegerOrDefault(MediaFormat.KEY_WIDTH, width)
                    height = format.getIntegerOrDefault(MediaFormat.KEY_HEIGHT, height)
                    if (format.containsKey(MediaFormat.KEY_COLOR_TRANSFER)) {
                        val transfer = format.getInteger(MediaFormat.KEY_COLOR_TRANSFER)
                        colorTransfer = transferLabel(transfer)
                        // HLG 与 PQ 都属于 HDR 输入，需要依赖源色彩元数据判定，
                        // 不能无条件套 LUT 或一律按 SDR 处理。
                        isHdr = transfer == MediaFormat.COLOR_TRANSFER_HLG ||
                            transfer == COLOR_TRANSFER_SMPTE_ST_2084
                        isHlg = transfer == MediaFormat.COLOR_TRANSFER_HLG
                    }
                    if (format.containsKey(MediaFormat.KEY_COLOR_STANDARD)) {
                        colorPrimaries = primariesLabel(format.getInteger(MediaFormat.KEY_COLOR_STANDARD))
                    }
                    if (!isHlg && format.containsKey(KEY_COLOR_PRIMARIES)) {
                        val primaries = format.getInteger(KEY_COLOR_PRIMARIES)
                        if (primaries == COLOR_PRIMARIES_BT2100_HLG) {
                            isHlg = true
                            isHdr = true
                            if (colorTransfer == "sdr") colorTransfer = "hlg"
                        }
                    }
                    if (format.containsKey("bit-depth-luma")) {
                        bitDepth = format.getInteger("bit-depth-luma")
                    }
                } else if (mime.startsWith("audio/")) {
                    audioMime = mime
                    hasAudio = true
                }
            }
            extractor.release()
        } catch (_: Throwable) {
        }

        val id = file.nameWithoutExtension + "_" + file.length()
        return mapOf(
            "id" to id,
            "path" to path,
            "fileName" to file.name,
            "durationUs" to durationUs,
            "width" to width,
            "height" to height,
            "fps" to 0.0,
            "videoCodec" to videoMime,
            "audioCodec" to audioMime,
            "colorTransfer" to colorTransfer,
            "colorPrimaries" to colorPrimaries,
            "isHdr" to isHdr,
            "isHlg" to isHlg,
            "bitDepth" to bitDepth,
            "rotationDegrees" to rotation,
            "hasAudio" to hasAudio,
        )
    }

    private fun transferLabel(transfer: Int): String = when (transfer) {
        MediaFormat.COLOR_TRANSFER_LINEAR -> "linear"
        COLOR_TRANSFER_SMPTE_ST_2084 -> "pq"
        MediaFormat.COLOR_TRANSFER_HLG -> "hlg"
        MediaFormat.COLOR_TRANSFER_SDR_VIDEO -> "sdr"
        else -> "unspecified"
    }

    private fun primariesLabel(primaries: Int): String = when (primaries) {
        COLOR_PRIMARIES_BT2020 -> "bt2020"
        COLOR_PRIMARIES_BT2100_HLG -> "bt2100_hlg"
        COLOR_PRIMARIES_DISPLAY_P3 -> "p3"
        COLOR_PRIMARIES_BT709 -> "bt709"
        else -> "unspecified"
    }

    private fun MediaFormat.getIntegerOrDefault(key: String, fallback: Int): Int =
        if (containsKey(key)) getInteger(key) else fallback

    private fun createProxy(path: String, targetHeight: Int, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("VIDEO_BUSY", "已有视频任务正在执行", null)
            return
        }
        val source = File(path)
        if (!source.exists()) {
            result.error("VIDEO_NOT_FOUND", "视频文件不存在", null)
            return
        }
        pruneProxyCache()
        val cacheKey = proxyCacheKey(source, targetHeight)
        val output = File(context.cacheDir, "zync_proxy_$cacheKey.mp4")
        if (output.exists() && output.length() > 0L) {
            result.success(
                mapOf(
                    "path" to output.absolutePath,
                    "width" to 0,
                    "height" to 0,
                    "durationUs" to 0L,
                    "isProxy" to true,
                    "cached" to true,
                )
            )
            return
        }
        if (output.exists()) output.delete()
        pendingResult = result
        pendingOutput = output
        pendingDurationUs = 0L

        val mediaItem = MediaItem.fromUri(Uri.fromFile(source))
        val effects = Effects(emptyList(), listOf<Effect>(Presentation.createForHeight(targetHeight.coerceAtLeast(360))))
        val edited = EditedMediaItem.Builder(mediaItem).setEffects(effects).build()
        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(listener(output, isProxy = true))
            .build()
        transformer?.start(edited, output.absolutePath)
    }

    private fun proxyCacheKey(source: File, targetHeight: Int): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val input = "${source.absolutePath}|${source.length()}|${source.lastModified()}|${targetHeight.coerceAtLeast(360)}"
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }.take(24)
    }

    private fun pruneProxyCache() {
        runCatching {
            val files = context.cacheDir.listFiles { file ->
                file.isFile && file.name.startsWith("zync_proxy_") && file.name.endsWith(".mp4")
            }?.sortedByDescending { it.lastModified() } ?: return
            files.drop(8).forEach { it.delete() }
        }
    }


    /**
     * 抓取一帧 JPEG，用于示波器（波形图 / 矢量示波器 / RGB Parade）。
     *
     */

    /**
     * 抽一帧 JPEG 供示波器使用。抽帧解码全部在后台线程，主线程只收发结果。
     */
    private fun captureFrameAsync(
        path: String,
        timeUs: Long,
        maxEdge: Int,
        result: MethodChannel.Result,
    ) {
        VideoFrameGrabber.executeAsync {
            val bytes = VideoFrameGrabber.grab(path, timeUs, maxEdge)
            mainHandler.post {
                result.success(mapOf("bytes" to bytes))
            }
        }
    }

    /**
     * 批量抽帧供时间线缩略图条使用。
     */
    private fun captureFrames(
        path: String,
        timesUs: LongArray,
        maxEdge: Int,
        result: MethodChannel.Result,
    ) {
        if (path.isBlank() || !File(path).exists()) {
            result.error("VIDEO_NOT_FOUND", "视频文件不存在", null)
            return
        }
        if (timesUs.isEmpty()) {
            result.success(mapOf("frames" to emptyList<ByteArray>()))
            return
        }
        VideoFrameGrabber.executeAsync {
            val frames = VideoFrameGrabber.grabMany(path, timesUs, maxEdge)
            mainHandler.post { result.success(mapOf("frames" to frames)) }
        }
    }

    private fun renderPreview(
        projectJson: String,
        clipId: String,
        sourcePath: String,
        result: MethodChannel.Result,
    ) {
        if (pendingResult != null) {
            result.error("VIDEO_BUSY", "已有视频任务正在执行", null)
            return
        }
        val project = runCatching { JSONObject(projectJson) }.getOrNull() ?: run {
            result.error("VIDEO_BAD_PROJECT", "视频项目 JSON 无效", null)
            return
        }
        val clips = project.optJSONArray("clips") ?: JSONArray()
        if (clips.length() == 0) {
            result.error("VIDEO_EMPTY", "时间线没有视频片段", null)
            return
        }
        var clip: JSONObject? = null
        for (i in 0 until clips.length()) {
            val candidate = clips.optJSONObject(i) ?: continue
            if (clipId.isBlank() || candidate.optString("id") == clipId) {
                clip = candidate
                break
            }
        }
        val selectedClip = clip ?: clips.optJSONObject(0) ?: run {
            result.error("VIDEO_EMPTY", "时间线没有可预览片段", null)
            return
        }
        // 预览优先使用 Dart 侧已生成的 proxy（H.264/720p-1080p），
        // 避免 4K 源直接跑 GL 效果导致解码/纹理失败。
        val clipPath = selectedClip.optString("path")
        val path =
            if (sourcePath.isNotBlank() && File(sourcePath).exists()) sourcePath
            else clipPath
        if (path.isBlank() || !File(path).exists()) {
            result.error("VIDEO_NOT_FOUND", "视频文件不存在", null)
            return
        }
        val startUs = selectedClip.optLong("sourceInUs", 0L)
        val sourceEndUs = selectedClip.optLong("sourceOutUs", startUs + 4_000_000L)
        val endUs = minOf(sourceEndUs, startUs + 4_000_000L)
        val mediaItem = MediaItem.Builder()
            .setUri(Uri.fromFile(File(path)))
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionUs(startUs.coerceAtLeast(0L))
                    .setEndPositionUs(endUs.coerceAtLeast(startUs + 1L))
                    .build()
            )
            .build()
        val grade = selectedClip.optJSONObject("grade")
        val effects = mutableListOf<Effect>()
        project.optJSONObject("globalGrade")?.let { globalGrade ->
            val globalEffect = KeyframedGradeEffect.fromGrade(globalGrade)
            if (!globalEffect.isNoOp(0, 0)) effects += globalEffect
            GradeLutFactory.create(globalGrade)?.let { effects += it }
            val globalLut = globalGrade.optJSONObject("lut")
            val globalLutPath = globalLut?.optString("path").orEmpty()
            val globalLutStrength = globalLut?.optDouble("strength", 1.0)?.toFloat() ?: 1f
            if (globalLutPath.isNotBlank()) {
                CubeLutLoader.load(globalLutPath, globalLutStrength)?.let { effects += it }
            }
            SpatialGradeEffect.fromGrade(globalGrade)?.let { effects += it }
        }
        effects += KeyframedGradeEffect.fromProject(selectedClip)
        GradeLutFactory.create(grade)?.let { effects += it }
        SpatialGradeEffect.fromGrade(grade)?.let { effects += it }
        val lut = grade?.optJSONObject("lut")
        val lutPath = lut?.optString("path").orEmpty()
        val lutStrength = lut?.optDouble("strength", 1.0)?.toFloat() ?: 1f
        if (lutPath.isNotBlank()) {
            CubeLutLoader.load(lutPath, lutStrength)?.let { effects += it }
        }
        // 与导出保持一致：先把画面限制到预览尺寸，再跑 LUT/空间效果，
        // 避免 4K 源在全分辨率下做 GL 处理导致失败。
        val itemEffects = mutableListOf<Effect>(
            Presentation.createForHeight(PREVIEW_MAX_HEIGHT),
        )
        itemEffects += effects
        val item = EditedMediaItem.Builder(mediaItem)
            .setEffects(Effects(emptyList(), itemEffects))
            .build()
        val sequence = EditedMediaItemSequence.withVideoFrom(listOf(item))
        val composition = Composition.Builder(sequence)
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
        pruneGradePreviewCache()
        val cacheKey = gradePreviewCacheKey(
            selectedClip,
            globalGrade = project.optJSONObject("globalGrade"),
            source = File(path),
            startUs = startUs,
            endUs = endUs,
        )
        val output = File(context.cacheDir, "zync_grade_preview_$cacheKey.mp4")
        if (output.exists() && output.length() > 0L) {
            result.success(
                mapOf(
                    "path" to output.absolutePath,
                    "durationUs" to (endUs - startUs).coerceAtLeast(0L),
                    "sizeBytes" to output.length(),
                    "mimeType" to "video/mp4",
                    "isProxy" to true,
                    "cached" to true,
                )
            )
            return
        }
        if (output.exists()) output.delete()
        pendingResult = result
        pendingOutput = output
        pendingDurationUs = (endUs - startUs).coerceAtLeast(0L)
        transformer = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(listener(output, isProxy = true))
            .build()
        startProgressPolling()
        transformer?.start(composition, output.absolutePath)
    }
    private fun gradePreviewCacheKey(
        clip: JSONObject,
        globalGrade: JSONObject?,
        source: File,
        startUs: Long,
        endUs: Long,
    ): String {
        val digest = MessageDigest.getInstance("SHA-256")
        val input = buildString {
            append("v2|")
            append(PREVIEW_MAX_HEIGHT)
            append('|')
            append(clip.toString())
            append('|').append(globalGrade?.toString().orEmpty())
            append('|').append(source.absolutePath)
            append('|').append(source.length())
            append('|').append(source.lastModified())
            append('|').append(startUs)
            append('|').append(endUs)
        }
        val bytes = digest.digest(input.toByteArray(Charsets.UTF_8))
        return bytes.joinToString("") { "%02x".format(it) }.take(24)
    }

    private fun pruneGradePreviewCache() {
        runCatching {
            val files = context.cacheDir.listFiles { file ->
                file.isFile && file.name.startsWith("zync_grade_preview_") && file.name.endsWith(".mp4")
            }?.sortedByDescending { it.lastModified() } ?: return
            files.drop(8).forEach { it.delete() }
        }
    }
    private fun export(projectJson: String, outputPath: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("VIDEO_BUSY", "已有视频任务正在执行", null)
            return
        }
        val project = runCatching { JSONObject(projectJson) }.getOrNull()
        if (project == null) {
            result.error("VIDEO_BAD_PROJECT", "视频项目 JSON 无效", null)
            return
        }
        val clips = project.optJSONArray("clips") ?: JSONArray()
        if (clips.length() == 0) {
            result.error("VIDEO_EMPTY", "时间线没有视频片段", null)
            return
        }
        val exportSpec = project.optJSONObject("exportSpec") ?: JSONObject()
        val fps = exportSpec.optDouble("fps", 30.0).toInt().coerceIn(1, 120)
        val output = if (outputPath.isBlank()) {
            File(context.cacheDir, "zync_video_${System.currentTimeMillis()}.mp4")
        } else {
            File(outputPath)
        }
        val items = mutableListOf<EditedMediaItem>()
        val globalGrade = project.optJSONObject("globalGrade")
        for (i in 0 until clips.length()) {
            val clip = clips.optJSONObject(i) ?: continue
            val path = clip.optString("path")
            if (path.isBlank() || !File(path).exists()) continue
            val startUs = clip.optLong("sourceInUs", 0L)
            val endUs = clip.optLong("sourceOutUs", 0L)
            val mediaItemBuilder = MediaItem.Builder().setUri(Uri.fromFile(File(path)))
            if (endUs > startUs) {
                mediaItemBuilder.setClippingConfiguration(
                    MediaItem.ClippingConfiguration.Builder()
                        .setStartPositionUs(startUs.coerceAtLeast(0L))
                        .setEndPositionUs(endUs)
                        .build()
                )
            }
            val grade = clip.optJSONObject("grade")
            val effects = mutableListOf<Effect>()
            globalGrade?.let {
                val globalEffect = KeyframedGradeEffect.fromGrade(it)
                if (!globalEffect.isNoOp(0, 0)) effects += globalEffect
                GradeLutFactory.create(it)?.let { lutEffect -> effects += lutEffect }
                val globalLut = it.optJSONObject("lut")
                val globalLutPath = globalLut?.optString("path").orEmpty()
                val globalLutStrength = globalLut?.optDouble("strength", 1.0)?.toFloat() ?: 1f
                if (globalLutPath.isNotBlank()) {
                    CubeLutLoader.load(globalLutPath, globalLutStrength)?.let { lutEffect -> effects += lutEffect }
                }
                SpatialGradeEffect.fromGrade(it)?.let { spatialEffect -> effects += spatialEffect }
            }
            effects += KeyframedGradeEffect.fromProject(clip)
            GradeLutFactory.create(grade)?.let { lutEffect -> effects += lutEffect }
            SpatialGradeEffect.fromGrade(grade)?.let { spatialEffect -> effects += spatialEffect }
            val lut = grade?.optJSONObject("lut")
            val lutPath = lut?.optString("path").orEmpty()
            val lutStrength = lut?.optDouble("strength", 1.0)?.toFloat() ?: 1f
            if (lutPath.isNotBlank()) {
                CubeLutLoader.load(lutPath, lutStrength)?.let { effects += it }
            }

            val audioProcessors = mutableListOf<androidx.media3.common.audio.AudioProcessor>()
            val audio = clip.optJSONObject("audio")
            val muted = audio?.optBoolean("muted", false) ?: false
            val volume = audio?.optDouble("volume", 1.0)?.toFloat()?.coerceIn(0f, 2f) ?: 1f
            val fadeInUs = audio?.optLong("fadeInUs", 0L) ?: 0L
            val fadeOutUs = audio?.optLong("fadeOutUs", 0L) ?: 0L
            val clipDurationUs = (endUs - startUs).coerceAtLeast(0L)
            val gainBuilder = DefaultGainProvider.Builder(if (muted) 0f else volume)
            if (fadeInUs > 1L && clipDurationUs > fadeInUs) {
                gainBuilder.addFadeAt(0L, fadeInUs, DefaultGainProvider.FADE_IN_LINEAR)
            }
            if (fadeOutUs > 1L && clipDurationUs > fadeOutUs) {
                gainBuilder.addFadeAt(clipDurationUs - fadeOutUs, fadeOutUs, DefaultGainProvider.FADE_OUT_LINEAR)
            }
            if (muted || volume != 1f || fadeInUs > 1L || fadeOutUs > 1L) {
                audioProcessors += GainProcessor(gainBuilder.build())
            }
            items += EditedMediaItem.Builder(mediaItemBuilder.build())
                .setFrameRate(fps)
                .setEffects(Effects(audioProcessors, effects))
                .build()
        }
        if (items.isEmpty()) {
            result.error("VIDEO_EMPTY", "时间线没有可导出的视频片段", null)
            return
        }

        val sequence = EditedMediaItemSequence.withAudioAndVideoFrom(items)
        val codec = exportSpec.optString("codec", "h264")
        val videoMime = if (codec == "hevc") MimeTypes.VIDEO_H265 else MimeTypes.VIDEO_H264
        val width = exportSpec.optInt("width", 3840).coerceAtLeast(2)
        val height = exportSpec.optInt("height", 2160).coerceAtLeast(2)
        val bitrate = exportSpec.optInt("bitrate", 40_000_000).coerceAtLeast(1_000_000)
        val presentation = Presentation.createForWidthAndHeight(
            width,
            height,
            Presentation.LAYOUT_SCALE_TO_FIT,
        )
        val composition = Composition.Builder(sequence)
            .setEffects(Effects(emptyList(), listOf(presentation)))
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
        val encoderFactory = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(
                VideoEncoderSettings.Builder().setBitrate(bitrate).build()
            )
            .build()

        pendingResult = result
        pendingOutput = output
        pendingDurationUs = projectDurationUs(clips)
        transformer = Transformer.Builder(context)
            .setVideoMimeType(videoMime)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoderFactory)
            .addListener(listener(output, isProxy = false))
            .build()
        startProgressPolling()
        transformer?.start(composition, output.absolutePath)
    }

    private fun projectDurationUs(clips: JSONArray): Long {
        var end = 0L
        for (i in 0 until clips.length()) {
            val clip = clips.optJSONObject(i) ?: continue
            val start = clip.optLong("timelineStartUs", 0L)
            val inUs = clip.optLong("sourceInUs", 0L)
            val outUs = clip.optLong("sourceOutUs", 0L)
            end = maxOf(end, start + (outUs - inUs).coerceAtLeast(0L))
        }
        return end
    }

    private fun startProgressPolling() {
        stopProgressPolling()
        val runnable = object : Runnable {
            override fun run() {
                val active = transformer ?: return
                val holder = ProgressHolder()
                val state = active.getProgress(holder)
                if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("videoProgress", mapOf("progress" to holder.progress / 100.0))
                }
                mainHandler.postDelayed(this, 500L)
            }
        }
        progressRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopProgressPolling() {
        progressRunnable?.let { mainHandler.removeCallbacks(it) }
        progressRunnable = null
    }
    private fun listener(output: File, isProxy: Boolean): Transformer.Listener =
        object : Transformer.Listener {
            override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                mainHandler.post {
                    stopProgressPolling()
                    val result = pendingResult
                    pendingResult = null
                    transformer = null
                    pendingOutput = null
                    if (result != null) {
                        result.success(mapOf(
                            "path" to output.absolutePath,
                            "width" to 0,
                            "height" to 0,
                            "durationUs" to pendingDurationUs,
                            "sizeBytes" to output.length(),
                            "mimeType" to "video/mp4",
                            "isProxy" to isProxy,
                        ))
                    }
                    pendingDurationUs = 0L
                }
            }

            override fun onError(
                composition: Composition,
                exportResult: ExportResult,
                exportException: ExportException,
            ) {
                mainHandler.post {
                    stopProgressPolling()
                    val result = pendingResult
                    pendingResult = null
                    transformer = null
                    pendingOutput = null
                    pendingDurationUs = 0L
                    result?.error("VIDEO_EXPORT", exportException.message ?: "视频导出失败", null)
                }
            }
        }

    private fun cancel() {
        stopProgressPolling()
        transformer?.cancel()
        transformer = null
        pendingResult = null
        pendingOutput = null
        pendingDurationUs = 0L
    }
}
