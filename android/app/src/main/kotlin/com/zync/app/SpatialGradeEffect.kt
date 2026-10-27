package com.zync.app

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import org.json.JSONObject
import kotlin.math.abs

/**
 * 视频空间效果：暗角、颗粒、锐化。
 * 这些效果依赖像素位置，不能放进 RgbMatrix 或 3D LUT，因此在 GPU shader 中处理。
 */
@UnstableApi
class SpatialGradeEffect private constructor(
    private val vignette: Float,
    private val grain: Float,
    private val sharpening: Float,
) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram =
        SpatialGradeShaderProgram(vignette, grain, sharpening)

    override fun isNoOp(inputWidth: Int, inputHeight: Int): Boolean =
        abs(vignette) + abs(grain) + abs(sharpening) < 1e-4f

    companion object {
        fun fromGrade(grade: JSONObject?): SpatialGradeEffect? {
            if (grade == null) return null
            val base = grade.optJSONObject("base") ?: JSONObject()
            val vignette = base.optDouble("vignette", 0.0).toFloat() / 100f * 0.65f
            val grain = base.optDouble("grain", 0.0).toFloat() / 100f * 0.12f
            val sharpening = grade.optDouble("sharpening", 0.0).toFloat() / 100f * 1.2f
            if (abs(vignette) + abs(grain) + abs(sharpening) < 1e-4f) return null
            return SpatialGradeEffect(vignette, grain, sharpening)
        }
    }
}

@UnstableApi
private class SpatialGradeShaderProgram(
    private val vignette: Float,
    private val grain: Float,
    private val sharpening: Float,
) : BaseGlShaderProgram(false, 1) {
    private var program: GlProgram? = null
    private var width = 1
    private var height = 1

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        width = inputWidth.coerceAtLeast(1)
        height = inputHeight.coerceAtLeast(1)
        if (program == null) {
            program = try {
                GlProgram(VERTEX_SHADER, FRAGMENT_SHADER)
            } catch (e: Exception) {
                throw VideoFrameProcessingException(e)
            }
        }
        return Size(width, height)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        val glProgram = program ?: return
        try {
            glProgram.use()
            glProgram.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            glProgram.setFloatsUniform(
                "uTexelSize",
                floatArrayOf(1f / width, 1f / height),
            )
            glProgram.setFloatUniform("uVignette", vignette)
            glProgram.setFloatUniform("uGrain", grain)
            glProgram.setFloatUniform("uSharpening", sharpening)
            glProgram.setFloatUniform("uTime", presentationTimeUs / 1_000_000f)
            glProgram.setBufferAttribute("aFramePosition", VERTEX_BUFFER, 4)
            glProgram.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
            GlUtil.checkGlError()
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program?.delete()
        } catch (e: Exception) {
            throw VideoFrameProcessingException(e)
        } finally {
            program = null
        }
    }

    companion object {
        private val VERTEX_BUFFER = floatArrayOf(
            -1f, -1f, 0f, 1f,
            1f, -1f, 0f, 1f,
            -1f, 1f, 0f, 1f,
            1f, 1f, 0f, 1f,
        )

        private val VERTEX_SHADER = """
            #version 100
            attribute vec4 aFramePosition;
            varying vec2 vTexSamplingCoord;
            void main() {
              gl_Position = aFramePosition;
              vTexSamplingCoord = aFramePosition.xy * 0.5 + 0.5;
            }
        """.trimIndent()

        private val FRAGMENT_SHADER = """
            #version 100
            precision mediump float;
            uniform sampler2D uTexSampler;
            uniform vec2 uTexelSize;
            uniform float uVignette;
            uniform float uGrain;
            uniform float uSharpening;
            uniform float uTime;
            varying vec2 vTexSamplingCoord;

            float hash(vec2 p) {
              return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
            }

            void main() {
              vec2 uv = vTexSamplingCoord;
              vec3 color = texture2D(uTexSampler, uv).rgb;

              if (abs(uSharpening) > 0.001) {
                vec3 left = texture2D(uTexSampler, uv - vec2(uTexelSize.x, 0.0)).rgb;
                vec3 right = texture2D(uTexSampler, uv + vec2(uTexelSize.x, 0.0)).rgb;
                vec3 up = texture2D(uTexSampler, uv - vec2(0.0, uTexelSize.y)).rgb;
                vec3 down = texture2D(uTexSampler, uv + vec2(0.0, uTexelSize.y)).rgb;
                vec3 blur = (left + right + up + down) * 0.25;
                color += (color - blur) * uSharpening;
              }

              if (abs(uVignette) > 0.001) {
                vec2 centered = uv - vec2(0.5);
                float dist2 = dot(centered, centered) * 4.0;
                float factor = 1.0 - uVignette * smoothstep(0.15, 1.0, dist2);
                color *= factor;
              }

              if (abs(uGrain) > 0.001) {
                float noise = hash(uv * 2048.0 + uTime * 17.0) - 0.5;
                color += noise * uGrain;
              }

              gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
            }
        """.trimIndent()
    }
}
