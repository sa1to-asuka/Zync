package com.zync.app

import androidx.media3.effect.RgbMatrix
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.pow

/**
 * Media3 RgbMatrix implementation with presentation-time keyframes.
 * This is the shared color evaluation used by preview and export.
 */
class KeyframedGradeEffect(
    private val baseExposure: Float,
    private val baseContrast: Float,
    private val baseSaturation: Float,
    private val baseTemperature: Float,
    private val baseTint: Float,
    private val keyframes: List<KeyframeValue>,
) : RgbMatrix {

    data class KeyframeValue(
        val parameter: String,
        val timeUs: Long,
        val value: Float,
        val easeInOut: Boolean,
    )

    private fun evaluate(parameter: String, timeUs: Long, fallback: Float): Float {
        val keys = keyframes.filter { it.parameter == parameter }.sortedBy { it.timeUs }
        if (keys.isEmpty()) return fallback
        if (timeUs <= keys.first().timeUs) return keys.first().value
        if (timeUs >= keys.last().timeUs) return keys.last().value
        for (i in 1 until keys.size) {
            val a = keys[i - 1]
            val b = keys[i]
            if (timeUs <= b.timeUs) {
                val span = (b.timeUs - a.timeUs).coerceAtLeast(1L)
                var f = ((timeUs - a.timeUs).toFloat() / span.toFloat()).coerceIn(0f, 1f)
                if (b.easeInOut) {
                    f = if (f < 0.5f) 2f * f * f else 1f - ((-2f * f + 2f).pow(2)) / 2f
                }
                return a.value + (b.value - a.value) * f
            }
        }
        return keys.last().value
    }

    override fun getMatrix(presentationTimeUs: Long, useHdr: Boolean): FloatArray {
        val exposure = evaluate("exposure", presentationTimeUs, baseExposure)
        val contrast = evaluate("contrast", presentationTimeUs, baseContrast)
        val saturation = evaluate("saturation", presentationTimeUs, baseSaturation)
        val temperature = evaluate("temperature", presentationTimeUs, baseTemperature)
        val tint = evaluate("tint", presentationTimeUs, baseTint)

        val ev = (exposure / 100f) * 1.8f
        val exposureGain = 2f.pow(ev).coerceIn(0.15f, 8f)
        val contrastValue = (contrast / 100f).coerceIn(-0.95f, 0.95f)
        val contrastFactor = (1f + contrastValue) / (1.0001f - contrastValue)
        val sat = (1f + saturation / 100f).coerceIn(0f, 2.5f)
        val sr = (1f - sat) * 0.299f
        val sg = (1f - sat) * 0.587f
        val sb = (1f - sat) * 0.114f

        val temp = (temperature / 100f).coerceIn(-1f, 1f)
        val tintValue = (tint / 100f).coerceIn(-1f, 1f)
        val rGain = exposureGain * (1f + temp * 0.22f) * (1f + tintValue * 0.10f)
        val gGain = exposureGain * (1f - tintValue * 0.18f)
        val bGain = exposureGain * (1f - temp * 0.22f) * (1f + tintValue * 0.10f)

        val offset = (1f - contrastFactor) * 0.5f
        return floatArrayOf(
            (sr + sat) * contrastFactor * rGain, sr * contrastFactor * rGain, sr * contrastFactor * rGain, 0f,
            sg * contrastFactor * gGain, (sg + sat) * contrastFactor * gGain, sg * contrastFactor * gGain, 0f,
            sb * contrastFactor * bGain, sb * contrastFactor * bGain, (sb + sat) * contrastFactor * bGain, 0f,
            offset, offset, offset, 1f,
        )
    }

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean =
        keyframes.isEmpty() &&
            baseExposure == 0f &&
            baseContrast == 0f &&
            baseSaturation == 0f &&
            baseTemperature == 0f &&
            baseTint == 0f

    companion object {
        fun fromGrade(grade: JSONObject): KeyframedGradeEffect {
            val base = grade.optJSONObject("base") ?: JSONObject()
            return KeyframedGradeEffect(
                baseExposure = base.optDouble("exposure", 0.0).toFloat(),
                baseContrast = base.optDouble("contrast", 0.0).toFloat(),
                baseSaturation = base.optDouble("saturation", 0.0).toFloat(),
                baseTemperature = base.optDouble("temperature", 0.0).toFloat(),
                baseTint = base.optDouble("tint", 0.0).toFloat(),
                keyframes = emptyList(),
            )
        }

        fun fromProject(clipJson: JSONObject): KeyframedGradeEffect {
            val grade = clipJson.optJSONObject("grade") ?: JSONObject()
            val base = grade.optJSONObject("base") ?: JSONObject()
            val keys = mutableListOf<KeyframeValue>()
            val tracks = clipJson.optJSONArray("keyframes") ?: JSONArray()
            for (i in 0 until tracks.length()) {
                val track = tracks.optJSONObject(i) ?: continue
                val parameter = track.optString("parameter")
                val keyArray = track.optJSONArray("keys") ?: continue
                for (j in 0 until keyArray.length()) {
                    val key = keyArray.optJSONObject(j) ?: continue
                    keys += KeyframeValue(
                        parameter = parameter,
                        timeUs = key.optLong("timeUs", 0L),
                        value = key.optDouble("value", 0.0).toFloat(),
                        easeInOut = key.optString("interpolation") == "easeInOut",
                    )
                }
            }
            return KeyframedGradeEffect(
                baseExposure = base.optDouble("exposure", 0.0).toFloat(),
                baseContrast = base.optDouble("contrast", 0.0).toFloat(),
                baseSaturation = base.optDouble("saturation", 0.0).toFloat(),
                baseTemperature = base.optDouble("temperature", 0.0).toFloat(),
                baseTint = base.optDouble("tint", 0.0).toFloat(),
                keyframes = keys,
            )
        }
    }
}