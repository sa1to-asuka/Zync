package com.zync.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.media3.effect.SingleColorLut
import java.io.File
import kotlin.math.roundToInt

/** Parses .cube 1D/3D LUTs and 2D HALD-style PNG LUTs for Media3. */
object CubeLutLoader {

    fun load(path: String, strength: Float): SingleColorLut? {
        if (path.isBlank()) return null
        val file = File(path)
        if (!file.exists()) return null
        return when (file.extension.lowercase()) {
            "cube", "cube.txt" -> parseCube(file, strength)
            "png", "jpg", "jpeg", "webp" -> loadBitmap(file, strength)
            else -> parseCube(file, strength)
        }
    }

    private fun parseCube(file: File, strength: Float): SingleColorLut? {
        var size1d: Int? = null
        var size3d: Int? = null
        val rows = mutableListOf<Triple<Double, Double, Double>>()
        file.forEachLine { raw ->
            var line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) return@forEachLine
            val hash = line.indexOf('#')
            if (hash >= 0) line = line.substring(0, hash).trim()
            if (line.isEmpty()) return@forEachLine
            val upper = line.uppercase()
            if (upper.startsWith("TITLE")) return@forEachLine
            if (upper.startsWith("LUT_1D_SIZE")) {
                size1d = line.split(Regex("\\s+")).lastOrNull()?.toIntOrNull()
                return@forEachLine
            }
            if (upper.startsWith("LUT_3D_SIZE")) {
                size3d = line.split(Regex("\\s+")).lastOrNull()?.toIntOrNull()
                return@forEachLine
            }
            if (upper.startsWith("DOMAIN_")) return@forEachLine
            val parts = line.split(Regex("\\s+")).mapNotNull { it.toDoubleOrNull() }
            if (parts.size >= 3) rows += Triple(parts[0], parts[1], parts[2])
        }

        val s = strength.coerceIn(0f, 1f)
        val n3 = size3d
        if (n3 != null && n3 > 1) {
            val n = n3
            val expected = n * n * n
            if (rows.size < expected) return null
            val cube = Array(n) { Array(n) { IntArray(n) } }
            var index = 0
            for (r in 0 until n) {
                for (g in 0 until n) {
                    for (b in 0 until n) {
                        val row = rows[index++]
                        val identityR = r.toDouble() / (n - 1)
                        val identityG = g.toDouble() / (n - 1)
                        val identityB = b.toDouble() / (n - 1)
                        cube[r][g][b] = color(
                            identityR + (row.first - identityR) * s,
                            identityG + (row.second - identityG) * s,
                            identityB + (row.third - identityB) * s,
                        )
                    }
                }
            }
            return SingleColorLut.createFromCube(cube)
        }

        val n1 = size1d
        if (n1 != null && n1 > 1) {
            val n = n1
            if (rows.size < n) return null
            val red = DoubleArray(n)
            val green = DoubleArray(n)
            val blue = DoubleArray(n)
            for (i in 0 until n) {
                red[i] = rows[i].first
                green[i] = rows[i].second
                blue[i] = rows[i].third
            }
            val cubeSize = 33
            val cube = Array(cubeSize) { Array(cubeSize) { IntArray(cubeSize) } }
            for (r in 0 until cubeSize) {
                for (g in 0 until cubeSize) {
                    for (b in 0 until cubeSize) {
                        val ir = r.toDouble() / (cubeSize - 1)
                        val ig = g.toDouble() / (cubeSize - 1)
                        val ib = b.toDouble() / (cubeSize - 1)
                        cube[r][g][b] = color(
                            ir + (sample1d(red, ir) - ir) * s,
                            ig + (sample1d(green, ig) - ig) * s,
                            ib + (sample1d(blue, ib) - ib) * s,
                        )
                    }
                }
            }
            return SingleColorLut.createFromCube(cube)
        }
        return null
    }

    private fun loadBitmap(file: File, strength: Float): SingleColorLut? {
        val decoded = BitmapFactory.decodeFile(file.absolutePath) ?: return null
        val bitmap = if (decoded.config == Bitmap.Config.ARGB_8888) {
            decoded
        } else {
            decoded.copy(Bitmap.Config.ARGB_8888, false)
        }
        if (bitmap.width * bitmap.width != bitmap.height) return null
        if (strength >= 0.999f) return SingleColorLut.createFromBitmap(bitmap)

        val n = bitmap.width
        val cube = Array(n) { Array(n) { IntArray(n) } }
        for (r in 0 until n) {
            for (g in 0 until n) {
                for (b in 0 until n) {
                    val source = bitmap.getPixel(b, n * r + g)
                    val ir = r.toDouble() / (n - 1)
                    val ig = g.toDouble() / (n - 1)
                    val ib = b.toDouble() / (n - 1)
                    cube[r][g][b] = color(
                        ir + (((source shr 16) and 0xFF) / 255.0 - ir) * strength,
                        ig + (((source shr 8) and 0xFF) / 255.0 - ig) * strength,
                        ib + ((source and 0xFF) / 255.0 - ib) * strength,
                    )
                }
            }
        }
        return SingleColorLut.createFromCube(cube)
    }

    private fun sample1d(table: DoubleArray, value: Double): Double {
        if (table.isEmpty()) return value
        val x = value.coerceIn(0.0, 1.0) * (table.size - 1)
        val i = x.toInt().coerceIn(0, table.size - 1)
        val j = (i + 1).coerceIn(0, table.size - 1)
        val f = x - i
        return table[i] + (table[j] - table[i]) * f
    }

    private fun color(r: Double, g: Double, b: Double): Int {
        val rr = (r.coerceIn(0.0, 1.0) * 255).roundToInt()
        val gg = (g.coerceIn(0.0, 1.0) * 255).roundToInt()
        val bb = (b.coerceIn(0.0, 1.0) * 255).roundToInt()
        return (0xFF shl 24) or (rr shl 16) or (gg shl 8) or bb
    }
}