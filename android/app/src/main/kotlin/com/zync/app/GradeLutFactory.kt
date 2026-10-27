package com.zync.app

import androidx.media3.effect.SingleColorLut
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow

/**
 * 将视频调色中的非线性参数烘焙为 33x33x33 3D LUT。
 * 曝光/对比度/饱和度/色温/色调由 KeyframedGradeEffect 做时间插值，
 * 曲线、HSL、色轮、高光/阴影等静态参数在这里统一进入 GPU LUT。
 */
object GradeLutFactory {
    private const val SIZE = 33

    fun create(grade: JSONObject?): SingleColorLut? {
        if (grade == null) return null
        val base = grade.optJSONObject("base") ?: JSONObject()
        val highlights = base.optDouble("highlights", 0.0).toFloat()
        val shadows = base.optDouble("shadows", 0.0).toFloat()
        val whites = base.optDouble("whites", 0.0).toFloat()
        val blacks = base.optDouble("blacks", 0.0).toFloat()
        val vibrance = base.optDouble("vibrance", 0.0).toFloat()
        val curve = parseCurve(grade.optJSONObject("toneCurve"))
        val bands = parseBands(grade.optJSONObject("hsl"))
        val wheels = parseWheels(grade.optJSONObject("colorGrading"))
        val hasCurve = curve.size >= 2 && curve.any { abs(it.first - it.second) > 1e-6f }
        val hasBands = bands.any { abs(it[0]) + abs(it[1]) + abs(it[2]) > 1e-6f }
        val hasWheels = wheels.any { abs(it[0]) + abs(it[1]) + abs(it[2]) > 1e-6f }
        if (abs(highlights) + abs(shadows) + abs(whites) + abs(blacks) + abs(vibrance) < 1e-6f &&
            !hasCurve && !hasBands && !hasWheels
        ) {
            return null
        }

        val cube = Array(SIZE) { Array(SIZE) { IntArray(SIZE) } }
        for (b in 0 until SIZE) {
            val bf = b / (SIZE - 1f)
            for (g in 0 until SIZE) {
                val gf = g / (SIZE - 1f)
                for (r in 0 until SIZE) {
                    val rf = r / (SIZE - 1f)
                    var red = rf
                    var green = gf
                    var blue = bf
                    val baseAdjusted = applyBase(red, green, blue, highlights, shadows, whites, blacks, vibrance)
                    red = baseAdjusted[0]
                    green = baseAdjusted[1]
                    blue = baseAdjusted[2]
                    val curveAdjusted = applyCurve(curve, red, green, blue)
                    red = curveAdjusted[0]
                    green = curveAdjusted[1]
                    blue = curveAdjusted[2]
                    val hslAdjusted = applyHslAndWheels(bands, wheels, red, green, blue)
                    red = hslAdjusted[0]
                    green = hslAdjusted[1]
                    blue = hslAdjusted[2]
                    val ri = (red.coerceIn(0f, 1f) * 255f + 0.5f).toInt()
                    val gi = (green.coerceIn(0f, 1f) * 255f + 0.5f).toInt()
                    val bi = (blue.coerceIn(0f, 1f) * 255f + 0.5f).toInt()
                    cube[b][g][r] = (0xFF shl 24) or (ri shl 16) or (gi shl 8) or bi
                }
            }
        }
        return SingleColorLut.createFromCube(cube)
    }

    private fun parseCurve(json: JSONObject?): List<Pair<Float, Float>> {
        val points = json?.optJSONArray("points") ?: return emptyList()
        val result = mutableListOf<Pair<Float, Float>>()
        for (i in 0 until points.length()) {
            val point = points.optJSONObject(i) ?: continue
            result += point.optDouble("x", 0.0).toFloat() to point.optDouble("y", 0.0).toFloat()
        }
        return result.sortedBy { it.first }
    }

    private fun parseBands(json: JSONObject?): List<FloatArray> {
        val array = json?.optJSONArray("bands") ?: return emptyList()
        val result = mutableListOf<FloatArray>()
        for (i in 0 until array.length()) {
            val band = array.optJSONObject(i) ?: continue
            result += floatArrayOf(
                band.optDouble("hue", 0.0).toFloat(),
                band.optDouble("saturation", 0.0).toFloat(),
                band.optDouble("luminance", 0.0).toFloat(),
            )
        }
        return result
    }

    private fun parseWheels(json: JSONObject?): List<FloatArray> {
        if (json == null) return emptyList()
        return listOf("shadows", "midtones", "highlights").map { name ->
            val wheel = json.optJSONObject(name) ?: JSONObject()
            floatArrayOf(
                wheel.optDouble("hue", 0.0).toFloat(),
                wheel.optDouble("saturation", 0.0).toFloat(),
                wheel.optDouble("luminance", 0.0).toFloat(),
            )
        }
    }

    private fun applyBase(
        red: Float,
        green: Float,
        blue: Float,
        highlights: Float,
        shadows: Float,
        whites: Float,
        blacks: Float,
        vibrance: Float,
    ): FloatArray {
        var r = red
        var g = green
        var b = blue
        val luma = 0.299f * r + 0.587f * g + 0.114f * b
        val highWeight = smoothstep(0.5f, 1.0f, luma)
        val shadowWeight = 1f - smoothstep(0.0f, 0.5f, luma)
        r = (r + highlights / 100f * 0.22f * highWeight).coerceIn(0f, 1f)
        g = (g + highlights / 100f * 0.22f * highWeight).coerceIn(0f, 1f)
        b = (b + highlights / 100f * 0.22f * highWeight).coerceIn(0f, 1f)
        r = (r + shadows / 100f * 0.22f * shadowWeight).coerceIn(0f, 1f)
        g = (g + shadows / 100f * 0.22f * shadowWeight).coerceIn(0f, 1f)
        b = (b + shadows / 100f * 0.22f * shadowWeight).coerceIn(0f, 1f)
        r = (r + whites / 100f * 0.12f * luma).coerceIn(0f, 1f)
        g = (g + whites / 100f * 0.12f * luma).coerceIn(0f, 1f)
        b = (b + whites / 100f * 0.12f * luma).coerceIn(0f, 1f)
        r = (r + blacks / 100f * 0.12f * (1f - luma)).coerceIn(0f, 1f)
        g = (g + blacks / 100f * 0.12f * (1f - luma)).coerceIn(0f, 1f)
        b = (b + blacks / 100f * 0.12f * (1f - luma)).coerceIn(0f, 1f)
        if (abs(vibrance) > 1e-6f) {
            val maxV = max(r, max(g, b))
            val minV = min(r, min(g, b))
            val currentSat = maxV - minV
            val boost = 1f + vibrance / 100f * (1f - currentSat) * 0.6f
            val pixelLuma = 0.299f * r + 0.587f * g + 0.114f * b
            r = (pixelLuma + (r - pixelLuma) * boost).coerceIn(0f, 1f)
            g = (pixelLuma + (g - pixelLuma) * boost).coerceIn(0f, 1f)
            b = (pixelLuma + (b - pixelLuma) * boost).coerceIn(0f, 1f)
        }
        return floatArrayOf(r, g, b)
    }

    private fun applyCurve(curve: List<Pair<Float, Float>>, r: Float, g: Float, b: Float): FloatArray {
        return floatArrayOf(evaluateCurve(curve, r), evaluateCurve(curve, g), evaluateCurve(curve, b))
    }

    private fun evaluateCurve(curve: List<Pair<Float, Float>>, value: Float): Float {
        if (curve.size < 2) return value
        var x0 = curve[0].first
        var y0 = curve[0].second
        if (value <= x0) return y0.coerceIn(0f, 1f)
        for (i in 1 until curve.size) {
            val x1 = curve[i].first
            val y1 = curve[i].second
            if (value <= x1) {
                val span = x1 - x0
                return (if (span <= 1e-6f) y1 else y0 + (y1 - y0) * ((value - x0) / span)).coerceIn(0f, 1f)
            }
            x0 = x1
            y0 = y1
        }
        return y0.coerceIn(0f, 1f)
    }

    private fun applyHslAndWheels(
        bands: List<FloatArray>,
        wheels: List<FloatArray>,
        red: Float,
        green: Float,
        blue: Float,
    ): FloatArray {
        var r = red
        var g = green
        var b = blue
        val hsl = rgbToHsl(r, g, b)
        var hue = hsl[0]
        var sat = hsl[1]
        var lum = hsl[2]
        var hueShift = 0f
        var satShift = 0f
        var lumShift = 0f
        val centers = floatArrayOf(0f, 30f, 60f, 120f, 180f, 240f, 280f, 320f)
        bands.forEachIndexed { index, band ->
            if (index >= centers.size) return@forEachIndexed
            val distance = min(abs(hue - centers[index]), 360f - abs(hue - centers[index]))
            val weight = (1f - distance / 45f).coerceIn(0f, 1f)
            hueShift += band[0] * weight
            satShift += band[1] * weight
            lumShift += band[2] * weight
        }
        val shadowWeight = 1f - smoothstep(0f, 0.5f, lum)
        val highlightWeight = smoothstep(0.5f, 1f, lum)
        val midWeight = max(0f, 1f - abs(lum - 0.5f) * 2f)
        val wheelWeights = floatArrayOf(shadowWeight, midWeight, highlightWeight)
        wheels.forEachIndexed { index, wheel ->
            if (index >= wheelWeights.size) return@forEachIndexed
            hueShift += wheel[0] * wheelWeights[index]
            satShift += wheel[1] * wheelWeights[index]
            lumShift += wheel[2] * wheelWeights[index]
        }
        hue += hueShift
        sat = (sat * (1f + satShift / 100f)).coerceIn(0f, 1f)
        lum = (lum + lumShift / 100f * 0.18f).coerceIn(0f, 1f)
        return hslToRgb(hue, sat, lum)
    }

    private fun rgbToHsl(r: Float, g: Float, b: Float): FloatArray {
        val maxV = max(r, max(g, b))
        val minV = min(r, min(g, b))
        val l = (maxV + minV) * 0.5f
        val delta = maxV - minV
        if (delta < 1e-6f) return floatArrayOf(0f, 0f, l)
        val s = if (l > 0.5f) delta / max(1e-6f, 2f - maxV - minV) else delta / max(1e-6f, maxV + minV)
        val h = when (maxV) {
            r -> (g - b) / delta + (if (g < b) 6f else 0f)
            g -> (b - r) / delta + 2f
            else -> (r - g) / delta + 4f
        } * 60f
        return floatArrayOf(h, s, l)
    }

    private fun hslToRgb(h: Float, s: Float, l: Float): FloatArray {
        var hue = h % 360f
        if (hue < 0f) hue += 360f
        hue /= 360f
        if (s < 1e-6f) return floatArrayOf(l, l, l)
        val q = if (l < 0.5f) l * (1f + s) else l + s - l * s
        val p = 2f * l - q
        return floatArrayOf(
            hueToRgb(p, q, hue + 1f / 3f),
            hueToRgb(p, q, hue),
            hueToRgb(p, q, hue - 1f / 3f),
        )
    }

    private fun hueToRgb(p: Float, q: Float, t: Float): Float {
        var value = t
        if (value < 0f) value += 1f
        if (value > 1f) value -= 1f
        return when {
            value < 1f / 6f -> p + (q - p) * 6f * value
            value < 1f / 2f -> q
            value < 2f / 3f -> p + (q - p) * (2f / 3f - value) * 6f
            else -> p
        }
    }

    private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        val t = ((x - edge0) / max(1e-6f, edge1 - edge0)).coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }
}
