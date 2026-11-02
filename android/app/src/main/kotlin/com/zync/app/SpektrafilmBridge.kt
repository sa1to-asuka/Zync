package com.zync.app

import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Bridge to the standalone GPL-3.0 Spektrafilm spectral engine.
 *
 * The engine is packaged as its own shared library (`libspektrafilm.so`) and
 * only exchanges plain pixel buffers and JSON with this app. See
 * third_party/spektrafilm_native for source, data, and license.
 */
class SpektrafilmBridge(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "ZyncSpektrafilm"
        private const val CHANNEL = "com.zync.app/spektrafilm"

        @Volatile
        private var nativeReady: Boolean? = null

        private fun ensureNative(): Boolean {
            nativeReady?.let { return it }
            synchronized(this) {
                nativeReady?.let { return it }
                val ok = try {
                    System.loadLibrary("spektrafilm")
                    true
                } catch (t: Throwable) {
                    Log.w(TAG, "Spektrafilm native library unavailable: ${t.message}")
                    false
                }
                nativeReady = ok
                return ok
            }
        }

        @JvmStatic private external fun nativeCatalog(dataDir: String): String?
        @JvmStatic private external fun nativeRender(
            dataDir: String,
            stockId: String,
            paperId: String,
            params: FloatArray,
            input: ByteArray,
            width: Int,
            height: Int,
        ): ByteArray?
        @JvmStatic private external fun nativeRenderRaw(
            dataDir: String,
            stockId: String,
            paperId: String,
            params: FloatArray,
            linearPath: String,
            width: Int,
            height: Int,
            quality: Int,
        ): ByteArray?
    }

    @Volatile
    private var renderGeneration = 0

    private val channel = MethodChannel(messenger, CHANNEL)
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureNative()) {
            result.error("unavailable", "Spektrafilm native library unavailable", null)
            return
        }
        when (call.method) {
            "catalog" -> {
                val dataDir = call.argument<String>("dataDir") ?: ""
                executor.execute {
                    val response = try {
                        Outcome.Success(nativeCatalog(dataDir))
                    } catch (t: Throwable) {
                        Outcome.Failure(t)
                    }
                    main.post { response.deliver(result) }
                }
            }
            "renderRaw" -> {
                val dataDir = call.argument<String>("dataDir") ?: ""
                val stockId = call.argument<String>("stockId") ?: ""
                val paperId = call.argument<String>("paperId") ?: ""
                val params = call.argument<FloatArray>("params") ?: FloatArray(0)
                val linearPath = call.argument<String>("linearPath") ?: ""
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val quality = call.argument<Int>("quality") ?: 95
                executor.execute {
                    val response = try {
                        Outcome.Success(
                            nativeRenderRaw(
                                dataDir, stockId, paperId, params,
                                linearPath, width, height, quality
                            )
                        )
                    } catch (t: Throwable) {
                        Outcome.Failure(t)
                    }
                    main.post { response.deliver(result) }
                }
            }
            "render" -> {
                val dataDir = call.argument<String>("dataDir") ?: ""
                val stockId = call.argument<String>("stockId") ?: ""
                val paperId = call.argument<String>("paperId") ?: ""
                val params = call.argument<FloatArray>("params") ?: FloatArray(0)
                val input = call.argument<ByteArray>("bytes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                if (input == null) {
                    result.error("bad_args", "Missing pixel buffer", null)
                    return
                }
                val generation = ++renderGeneration
                executor.execute {
                    if (generation != renderGeneration) {
                        // A newer preview request superseded this one.
                        main.post { result.success(null) }
                        return@execute
                    }
                    val response = try {
                        Outcome.Success(
                            nativeRender(dataDir, stockId, paperId, params, input, width, height)
                        )
                    } catch (t: Throwable) {
                        Outcome.Failure(t)
                    }
                    main.post { response.deliver(result) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private sealed class Outcome {
        class Success(val value: Any?) : Outcome()
        class Failure(val error: Throwable) : Outcome()

        fun deliver(result: MethodChannel.Result) {
            when (this) {
                is Success -> result.success(value)
                is Failure -> result.error("spektrafilm", error.message, null)
            }
        }
    }
}
