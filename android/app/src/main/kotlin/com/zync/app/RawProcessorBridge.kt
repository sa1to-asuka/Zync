package com.zync.app

import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/**
 * LibRaw-backed RAW processor channel. The native implementation is deliberately
 * isolated here so the Flutter side can fall back to embedded JPEG when a build
 * does not ship the RAW decoder.
 */
class RawProcessorBridge(
    private val messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "ZyncRaw"
        private const val CHANNEL = "com.zync.app/raw_processor"

        @Volatile
        private var nativeReady: Boolean? = null

        private fun ensureNative(): Boolean {
            nativeReady?.let { return it }
            synchronized(this) {
                nativeReady?.let { return it }
                val ok = try {
                    System.loadLibrary("zync_raw")
                    nativeIsAvailable()
                } catch (t: Throwable) {
                    Log.w(TAG, "RAW native library unavailable: ${t.message}")
                    false
                }
                nativeReady = ok
                return ok
            }
        }

        @JvmStatic private external fun nativeIsAvailable(): Boolean
        @JvmStatic private external fun nativeProbe(path: String): Map<String, Any>?
        @JvmStatic private external fun nativeRenderPreview(
            path: String,
            maxEdge: Int,
            params: FloatArray,
            lutPath: String,
            lutStrength: Float,
        ): Map<String, Any>?
        @JvmStatic private external fun nativeRenderFull(
            path: String,
            outputPath: String,
            jpegQuality: Int,
            params: FloatArray,
            lutPath: String,
            lutStrength: Float,
        ): Map<String, Any>?
        @JvmStatic private external fun nativeCancel()
    }

    private data class GradeArgs(
        val params: FloatArray,
        val lutPath: String,
        val lutStrength: Float,
    )

    private fun parseGrade(recipeJson: String): GradeArgs {
        return try {
            val root = JSONObject(recipeJson)
            val grade = root.optJSONObject("grade") ?: JSONObject()
            val base = grade.optJSONObject("base") ?: JSONObject()
            val lut = grade.optJSONObject("lut") ?: JSONObject()
            val params = FloatArray(64)
            fun put(index: Int, value: Double) {
                if (index in params.indices) params[index] = value.toFloat()
            }

            put(0, base.optDouble("exposure", 0.0))
            put(1, base.optDouble("contrast", 0.0))
            put(2, base.optDouble("saturation", 0.0))
            put(3, base.optDouble("temperature", 0.0))
            put(4, base.optDouble("tint", 0.0))
            put(5, base.optDouble("highlights", 0.0))
            put(6, base.optDouble("shadows", 0.0))
            put(7, base.optDouble("whites", 0.0))
            put(8, base.optDouble("blacks", 0.0))
            put(9, base.optDouble("vibrance", 0.0))
            put(10, base.optDouble("vignette", 0.0))
            put(11, base.optDouble("grain", 0.0))
            put(12, grade.optDouble("sharpening", 0.0))
            put(13, grade.optDouble("noiseReduction", 0.0))
            put(14, grade.optDouble("lensDistortion", 0.0))
            put(15, grade.optDouble("lensVignette", 0.0))
            put(16, grade.optDouble("chromaticAberration", 0.0))

            val curvePoints = grade.optJSONObject("toneCurve")?.optJSONArray("points")
            val curveCount = minOf(curvePoints?.length() ?: 0, 5)
            put(17, curveCount.toDouble())
            for (i in 0 until curveCount) {
                val point = curvePoints?.optJSONObject(i) ?: continue
                put(18 + i * 2, point.optDouble("x", 0.0))
                put(19 + i * 2, point.optDouble("y", 0.0))
            }

            val bands = grade.optJSONObject("hsl")?.optJSONArray("bands")
            val bandCount = minOf(bands?.length() ?: 0, 8)
            put(28, bandCount.toDouble())
            for (i in 0 until bandCount) {
                val band = bands?.optJSONObject(i) ?: continue
                put(29 + i * 3, band.optDouble("hue", 0.0))
                put(30 + i * 3, band.optDouble("saturation", 0.0))
                put(31 + i * 3, band.optDouble("luminance", 0.0))
            }

            val wheels = grade.optJSONObject("colorGrading")
            fun wheel(name: String, baseIndex: Int) {
                val wheel = wheels?.optJSONObject(name) ?: return
                put(baseIndex, wheel.optDouble("hue", 0.0))
                put(baseIndex + 1, wheel.optDouble("saturation", 0.0))
                put(baseIndex + 2, wheel.optDouble("luminance", 0.0))
            }
            wheel("shadows", 53)
            wheel("midtones", 56)
            wheel("highlights", 59)

            GradeArgs(
                params = params,
                lutPath = lut.optString("path", ""),
                lutStrength = lut.optDouble("strength", 1.0).toFloat(),
            )
        } catch (_: Throwable) {
            GradeArgs(FloatArray(64), "", 1f)
        }
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(ensureNative())
            "probe" -> {
                val path = call.argument<String>("path").orEmpty()
                if (!ensureNative()) {
                    result.success(mapOf(
                        "supported" to false,
                        "reason" to "当前构建未包含 LibRaw RAW 解码器，已回退到内嵌 JPEG",
                    ))
                } else {
                    result.success(nativeProbe(path))
                }
            }
            "renderPreview" -> {
                val path = call.argument<String>("path").orEmpty()
                val maxEdge = call.argument<Int>("maxEdge") ?: 2048
                val grade = parseGrade(call.argument<String>("recipe").orEmpty())
                if (!ensureNative()) {
                    result.error("RAW_UNAVAILABLE", "当前构建未包含 LibRaw RAW 解码器", null)
                } else {
                    result.success(nativeRenderPreview(
                        path,
                        maxEdge,
                        grade.params,
                        grade.lutPath,
                        grade.lutStrength,
                    ))
                }
            }
            "renderFull" -> {
                val path = call.argument<String>("path").orEmpty()
                val outputPath = call.argument<String>("outputPath").orEmpty()
                val quality = call.argument<Int>("jpegQuality") ?: 95
                val grade = parseGrade(call.argument<String>("recipe").orEmpty())
                if (!ensureNative()) {
                    result.error("RAW_UNAVAILABLE", "当前构建未包含 LibRaw RAW 解码器", null)
                } else {
                    val map = nativeRenderFull(
                        path,
                        outputPath,
                        quality,
                        grade.params,
                        grade.lutPath,
                        grade.lutStrength,
                    )
                    if (map != null && outputPath.isNotBlank()) {
                        val bytes = map["bytes"] as? ByteArray
                        if (bytes != null && bytes.isNotEmpty()) {
                            runCatching { File(outputPath).writeBytes(bytes) }
                        }
                    }
                    result.success(map)
                }
            }
            "cancel" -> {
                if (ensureNative()) nativeCancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}