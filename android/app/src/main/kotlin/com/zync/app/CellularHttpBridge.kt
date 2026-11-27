package com.zync.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * 相机 AP 热点无外网直连场景下的蜂窝网络 HTTP 旁路通道：
 * 仅在单次请求期间通过 [Network.openConnection] 借道 4G/5G 移动数据，
 * 全程不触碰进程级的相机 Wi-Fi 绑定 (`bindProcessToNetwork`)。
 */
class CellularHttpBridge(private val context: Context) {
    private val executor = Executors.newCachedThreadPool()

    fun execute(
        method: String,
        urlString: String,
        headers: Map<String, String>,
        body: String?,
        timeoutMs: Int,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        executor.execute {
            val res = runRequest(method, urlString, headers, body, timeoutMs)
            callback(res)
        }
    }

    private fun runRequest(
        method: String,
        urlString: String,
        headers: Map<String, String>,
        body: String?,
        timeoutMs: Int,
    ): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return mapOf(
                "ok" to false,
                "statusCode" to 0,
                "errorCode" to "NO_CONNECTIVITY_MANAGER",
                "errorMessage" to "ConnectivityManager unavailable"
            )

        var cellNetwork: Network? = null
        val latch = CountDownLatch(1)
        val req = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_CELLULAR)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        val netCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                if (cellNetwork == null) {
                    cellNetwork = network
                    latch.countDown()
                }
            }

            override fun onUnavailable() {
                latch.countDown()
            }
        }

        return try {
            cm.requestNetwork(req, netCallback, 6000)
            latch.await(6, TimeUnit.SECONDS)
            val net = cellNetwork ?: return mapOf(
                "ok" to false,
                "statusCode" to 0,
                "errorCode" to "NO_CELLULAR_INTERNET",
                "errorMessage" to "Cellular internet is unavailable"
            )

            val url = URL(urlString)
            val conn = net.openConnection(url) as HttpURLConnection
            conn.requestMethod = method.uppercase()
            conn.connectTimeout = timeoutMs.coerceIn(3000, 60000)
            conn.readTimeout = timeoutMs.coerceIn(5000, 120000)
            conn.useCaches = false

            for ((k, v) in headers) {
                conn.setRequestProperty(k, v)
            }

            if (body != null && (conn.requestMethod == "POST" || conn.requestMethod == "PUT")) {
                conn.doOutput = true
                conn.outputStream.use { os ->
                    os.write(body.toByteArray(Charsets.UTF_8))
                }
            }

            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val respBody = if (stream != null) {
                BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
            } else {
                ""
            }
            conn.disconnect()
            mapOf(
                "ok" to (code in 200..299),
                "statusCode" to code,
                "body" to respBody,
            )
        } catch (e: Exception) {
            mapOf(
                "ok" to false,
                "statusCode" to 0,
                "errorCode" to "CELLULAR_HTTP_ERROR",
                "errorMessage" to (e.message ?: e.javaClass.simpleName),
            )
        } finally {
            try {
                cm.unregisterNetworkCallback(netCallback)
            } catch (_: Exception) {
            }
        }
    }
}
