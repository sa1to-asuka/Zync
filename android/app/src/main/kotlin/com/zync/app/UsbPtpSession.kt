package com.zync.app

import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbRequest
import android.os.Build
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.IdentityHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * PTP over USB Bulk-Only 会话。
 *
 * 协议依据：
 *  - ISO 15740 / PIMA 15740（Picture Transfer Protocol）；
 *  - USB Still Image Capture Device Definition 的 Bulk-Only 传输；
 *  - Android USB Host API（UsbDeviceConnection / UsbRequest）。
 *
 * 容器统一为 12 字节头 + 负载（小端）：
 *  - Command 容器：length(4) + type=1(2) + opcode(2) + transactionId(4) + params(4*N)
 *  - Data    容器：length(4) + type=2(2) + reserved(2) + transactionId(4) + payload
 *  - Response容器：length(4) + type=3(2) + responseCode(2) + transactionId(4) + params
 *
 * 本类使用 Android USB Host API 直接实现会话与容器收发，不依赖厂商 SDK。
 */
class UsbPtpSession(
    private val device: UsbDevice,
    private val connection: UsbDeviceConnection,
    private val iface: UsbInterface,
    private val epIn: UsbEndpoint,
    private val epOut: UsbEndpoint,
    private val epEvent: UsbEndpoint? = null,
    private val onEvent: ((ByteArray) -> Unit)? = null,
    private val onLog: ((String) -> Unit)? = null,
) {
    private companion object {
        const val RESPONSE_OK = 0x2001
        const val RESPONSE_SESSION_ALREADY_OPEN = 0x201E

        const val CONTAINER_COMMAND = 1
        const val CONTAINER_DATA = 2
        const val CONTAINER_RESPONSE = 3
        const val CONTAINER_HEADER_SIZE = 12

        const val OP_OPEN_SESSION = 0x1002
        const val OP_CLOSE_SESSION = 0x1003

        /** Nikon GetEventEx：用于会话建立后清空相机事件队列。 */
        const val OP_NIKON_GET_EVENT_EX = 0x941C

        const val OPEN_SESSION_TIMEOUT_MS = 2_000
        const val IO_TIMEOUT_MS = 15_000
        const val EVENT_DRAIN_TIMEOUT_MS = 2_000

        /** Android 8.0 及以下 usbfs 对单次请求缓冲区有 16 KiB 限制。 */
        const val LEGACY_REQUEST_MAX_BYTES = 16_384
        const val MAX_READ_CHUNK = 65_536

        /** 单次 Data 容器负载上限，防止损坏的长度字段触发超大分配。 */
        const val MAX_DATA_CONTAINER_BYTES = 128 * 1024 * 1024

        const val ZERO_LENGTH_PACKET_RETRIES = 2
        const val ZERO_LENGTH_PACKET_TIMEOUT_MS = 250

        const val REQUEST_POLL_TIMEOUT_MS = 50L
        const val CANCEL_GRACE_MS = 250L
    }

    private val transactionCounter = AtomicInteger(0)
    private val closed = AtomicBoolean(false)
    private val transportFailed = AtomicBoolean(false)

    @Volatile
    private var sessionOpen = false

    private var pump: TransferPump? = null

    private var buffered = ByteArray(0)
    private var bufferedOffset = 0

    private fun log(message: String) {
        onLog?.invoke(message)
    }

    // ============================================================
    // 会话生命周期
    // ============================================================

    /** 认领接口并启动 USB 传输泵。 */
    fun open() {
        if (!connection.claimInterface(iface, true)) {
            throw IllegalStateException(
                "无法 claim USB 接口 id=${iface.id} class=${iface.interfaceClass} " +
                    "alt=${iface.alternateSetting}"
            )
        }
        pump = TransferPump()
        log(
            "PTP endpoints device=${device.deviceName} interface=${iface.id} " +
                "bulkIn=0x${hexByte(epIn.address)}/${epIn.maxPacketSize} " +
                "bulkOut=0x${hexByte(epOut.address)}/${epOut.maxPacketSize} " +
                "interruptIn=${epEvent?.let { "0x${hexByte(it.address)}/${it.maxPacketSize}" } ?: "none"}"
        )
    }

    /**
     * 建立全新 PTP 会话。
     *
     * 返回 true 表示 OpenSession 成功；返回 false 表示相机侧已有残留会话，
     * 本方法已经发送 CloseSession，调用方应稍后重试一次。
     */
    fun openFreshSession(): Boolean {
        val code = executeOperationRaw(OP_OPEN_SESSION, intArrayOf(1), OPEN_SESSION_TIMEOUT_MS)
        if (code == RESPONSE_OK) {
            sessionOpen = true
            log("OpenSession ok")
            drainEventQueue()
            startEventPump()
            return true
        }
        if (code == RESPONSE_SESSION_ALREADY_OPEN) {
            log("OpenSession returned SessionAlreadyOpen，关闭相机侧残留会话")
            try {
                val closeCode = executeOperationRaw(OP_CLOSE_SESSION, IntArray(0), IO_TIMEOUT_MS)
                log("CloseSession stale response=0x${closeCode.toString(16)}")
            } catch (e: Exception) {
                log("CloseSession stale failed: ${e.message}")
            }
            sessionOpen = false
            return false
        }
        throw PtpUsbException(OP_OPEN_SESSION, code)
    }

    /** 会话已打开时直接复用；否则补一次 OpenSession。 */
    fun openSessionIfNeeded() {
        if (sessionOpen) return
        val code = executeOperationRaw(OP_OPEN_SESSION, intArrayOf(1), OPEN_SESSION_TIMEOUT_MS)
        if (code != RESPONSE_OK && code != RESPONSE_SESSION_ALREADY_OPEN) {
            throw PtpUsbException(OP_OPEN_SESSION, code)
        }
        sessionOpen = true
        log("OpenSession ok response=0x${code.toString(16)}")
        if (code == RESPONSE_OK) {
            drainEventQueue()
            startEventPump()
        }
    }

    /** 清空会话建立前相机可能积压的事件。失败不影响会话。 */
    private fun drainEventQueue() {
        try {
            val data = executeDataIn(OP_NIKON_GET_EVENT_EX, IntArray(0), EVENT_DRAIN_TIMEOUT_MS)
            log("Nikon GetEventEx drain bytes=${data.size}")
        } catch (e: IOException) {
            // 传输层 IO 失败不应被当作“可选步骤失败”，交给上层重建会话。
            throw e
        } catch (e: Exception) {
            log("Nikon GetEventEx drain ignored: ${e.message}")
        }
    }

    /** 启动中断端点的常驻读取，及时取走相机事件。 */
    private fun startEventPump() {
        val endpoint = epEvent
        if (endpoint == null) {
            log("没有中断 IN 端点，跳过 PTP 事件管道")
            return
        }
        runCatching { pump?.startInterrupt(endpoint) { bytes -> onEventBytes(bytes) } }
            .onFailure { log("启动 PTP 事件管道失败（忽略）：${it.message}") }
    }

    private fun onEventBytes(bytes: ByteArray) {
        if (bytes.size < 12) return
        val length = ByteBuffer.wrap(bytes, 0, 4).order(ByteOrder.LITTLE_ENDIAN).int
        if (length < 12 || length > bytes.size) {
            log("PTP 事件长度异常 length=$length bytes=${bytes.size}")
            return
        }
        val buffer = ByteBuffer.wrap(bytes, 0, length).order(ByteOrder.LITTLE_ENDIAN)
        buffer.int
        val type = buffer.short.toInt() and 0xFFFF
        val code = buffer.short.toInt() and 0xFFFF
        val transactionId = buffer.int
        log("PTP 事件 type=$type code=0x${code.toString(16)} tx=$transactionId bytes=$length")
        if (type != 4) return
        onEvent?.invoke(bytes.copyOf(length))
    }

    fun close() {
        if (!closed.compareAndSet(false, true)) return
        if (sessionOpen && !transportFailed.get()) {
            runCatching { sendCloseSession() }
        } else if (sessionOpen) {
            log("USB 传输层已失效，跳过 CloseSession")
        }
        sessionOpen = false
        runCatching { pump?.close() }
        pump = null
        runCatching { connection.releaseInterface(iface) }
        runCatching { connection.close() }
        log("PTP 会话已关闭")
    }

    /** 传输层出错后的恢复：清除端点 halt 并丢弃残留字节。 */
    fun recoverAfterTransportFailure() {
        clearHalt(epIn)
        clearHalt(epOut)
        buffered = ByteArray(0)
        bufferedOffset = 0
    }

    /** 只发送 CloseSession 并消费响应，不校验响应码。 */
    private fun sendCloseSession() {
        val tx = nextTransactionId()
        sendCommandContainer(OP_CLOSE_SESSION, tx, IntArray(0))
        val header = readContainerHeader(IO_TIMEOUT_MS)
        requireType(header.type, CONTAINER_RESPONSE, OP_CLOSE_SESSION)
        skipPayload(header.length, IO_TIMEOUT_MS)
    }

    // ============================================================
    // PTP 操作
    // ============================================================

    fun executeOperation(opCode: Int, params: IntArray = IntArray(0)) {
        checkResponse(opCode, executeOperationRaw(opCode, params, IO_TIMEOUT_MS))
    }

    private fun executeOperationRaw(
        opCode: Int,
        params: IntArray,
        readTimeoutMs: Int,
    ): Int {
        ensureAlive()
        val tx = nextTransactionId()
        sendCommandContainer(opCode, tx, params)

        var header = readContainerHeader(readTimeoutMs)
        if (header.type == CONTAINER_DATA) {
            // 少数相机在无数据阶段仍返回 Data 容器，先消费再读 Response。
            skipPayload(header.length, readTimeoutMs)
            header = readContainerHeader(readTimeoutMs)
        }
        requireType(header.type, CONTAINER_RESPONSE, opCode)
        skipPayload(header.length, readTimeoutMs)
        log("RESPONSE op=0x${opCode.toString(16)} tx=$tx code=0x${header.code.toString(16)}")
        return header.code
    }

    fun executeDataIn(opCode: Int, params: IntArray = IntArray(0)): ByteArray =
        executeDataIn(opCode, params, IO_TIMEOUT_MS)

    private fun executeDataIn(
        opCode: Int,
        params: IntArray,
        readTimeoutMs: Int,
    ): ByteArray {
        ensureAlive()
        val tx = nextTransactionId()
        sendCommandContainer(opCode, tx, params)

        val first = readContainerHeader(readTimeoutMs)
        if (first.type == CONTAINER_RESPONSE) {
            skipPayload(first.length, readTimeoutMs)
            checkResponse(opCode, first.code)
            return ByteArray(0)
        }
        requireType(first.type, CONTAINER_DATA, opCode)

        val payloadLength = first.length - CONTAINER_HEADER_SIZE
        if (payloadLength < 0 || payloadLength > MAX_DATA_CONTAINER_BYTES) {
            transportFailed.set(true)
            throw IOException("PTP 数据容器长度异常: $payloadLength")
        }
        val out = ByteArrayOutputStream(if (payloadLength > 0) payloadLength else 0)
        if (payloadLength > 0) {
            readInto(out, payloadLength.toLong(), readTimeoutMs)
        }

        val response = readContainerHeader(readTimeoutMs)
        requireType(response.type, CONTAINER_RESPONSE, opCode)
        skipPayload(response.length, readTimeoutMs)
        checkResponse(opCode, response.code)
        return out.toByteArray()
    }

    fun executeDataOut(
        opCode: Int,
        data: ByteArray,
        params: IntArray = IntArray(0),
    ) {
        ensureAlive()
        val tx = nextTransactionId()
        sendCommandContainer(opCode, tx, params)
        sendDataContainer(tx, data)

        var header = readContainerHeader(IO_TIMEOUT_MS)
        if (header.type == CONTAINER_DATA) {
            skipPayload(header.length, IO_TIMEOUT_MS)
            header = readContainerHeader(IO_TIMEOUT_MS)
        }
        requireType(header.type, CONTAINER_RESPONSE, opCode)
        skipPayload(header.length, IO_TIMEOUT_MS)
        checkResponse(opCode, header.code)
    }

    // ============================================================
    // 容器编解码
    // ============================================================

    private class ContainerHeader(
        val length: Int,
        val type: Int,
        val code: Int,
    )

    private fun nextTransactionId(): Int = transactionCounter.incrementAndGet()

    private fun sendCommandContainer(opCode: Int, tx: Int, params: IntArray) {
        val length = CONTAINER_HEADER_SIZE + params.size * 4
        val buffer = ByteBuffer.allocate(length).order(ByteOrder.LITTLE_ENDIAN)
        buffer.putInt(length)
        buffer.putShort(CONTAINER_COMMAND.toShort())
        buffer.putShort(opCode.toShort())
        buffer.putInt(tx)
        for (param in params) buffer.putInt(param)
        log("PTP_RAW_OUT op=0x${opCode.toString(16)} tx=$tx params=${params.joinToString(",")}")
        writeAll(buffer.array())
    }

    private fun sendDataContainer(tx: Int, data: ByteArray) {
        val length = CONTAINER_HEADER_SIZE + data.size
        val buffer = ByteBuffer.allocate(length).order(ByteOrder.LITTLE_ENDIAN)
        buffer.putInt(length)
        buffer.putShort(CONTAINER_DATA.toShort())
        buffer.putShort(0)
        buffer.putInt(tx)
        buffer.put(data)
        writeAll(buffer.array())
    }

    private fun readContainerHeader(timeoutMs: Int): ContainerHeader {
        val raw = readExact(CONTAINER_HEADER_SIZE, timeoutMs)
        val buffer = ByteBuffer.wrap(raw).order(ByteOrder.LITTLE_ENDIAN)
        val length = buffer.int
        val type = buffer.short.toInt() and 0xFFFF
        val code = buffer.short.toInt() and 0xFFFF
        buffer.int // transaction id
        if (length < CONTAINER_HEADER_SIZE) {
            transportFailed.set(true)
            throw IOException("PTP 容器长度非法: $length")
        }
        return ContainerHeader(length, type, code)
    }

    private fun skipPayload(containerLength: Int, timeoutMs: Int) =
        skipBytes((containerLength - CONTAINER_HEADER_SIZE).toLong(), timeoutMs)

    private fun requireType(actual: Int, expected: Int, opCode: Int) {
        if (actual != expected) {
            transportFailed.set(true)
            throw IOException(
                "操作 0x${opCode.toString(16)} 容器类型异常: $actual（期望 $expected）"
            )
        }
    }

    private fun checkResponse(opCode: Int, code: Int) {
        if (code == RESPONSE_OK) return
        throw PtpUsbException(opCode, code)
    }

    // ============================================================
    // 裸字节 IO
    // ============================================================

    private fun ensureAlive() {
        if (closed.get()) throw IllegalStateException("USB PTP 会话已关闭")
        if (transportFailed.get()) {
            throw IOException("USB 传输层已失效，请重新插拔数据线后重试")
        }
    }

    private fun readExact(count: Int, timeoutMs: Int): ByteArray {
        val out = ByteArray(count)
        var filled = 0
        while (filled < count) {
            val read = readChunk(out, filled, count - filled, timeoutMs)
            if (read <= 0) throw IOException("USB 读取失败（$read）：相机无响应")
            filled += read
        }
        return out
    }

    private fun readInto(out: ByteArrayOutputStream, count: Long, timeoutMs: Int) {
        var remaining = count
        while (remaining > 0) {
            val chunk = ByteArray(minOf(MAX_READ_CHUNK.toLong(), remaining).toInt())
            val read = readChunk(chunk, 0, chunk.size, timeoutMs)
            if (read <= 0) throw IOException("USB 读取失败（$read）：相机无响应")
            out.write(chunk, 0, read)
            remaining -= read
        }
    }

    private fun skipBytes(count: Long, timeoutMs: Int) {
        var remaining = count
        val sink = ByteArray(8_192)
        while (remaining > 0) {
            val want = minOf(8_192L, remaining).toInt()
            val read = readChunk(sink, 0, want, timeoutMs)
            if (read <= 0) throw IOException("USB 跳过数据失败（$read）")
            remaining -= read
        }
    }

    /**
     * 先消费内部缓冲，再提交一次 bulk IN 请求。
     * 请求长度按端点最大包大小向上取整，多读到的字节留到下一次。
     */
    private fun readChunk(dst: ByteArray, offset: Int, length: Int, timeoutMs: Int): Int {
        val available = buffered.size - bufferedOffset
        if (available > 0) {
            val read = minOf(length, available)
            System.arraycopy(buffered, bufferedOffset, dst, offset, read)
            bufferedOffset += read
            if (bufferedOffset >= buffered.size) {
                buffered = ByteArray(0)
                bufferedOffset = 0
            }
            return read
        }

        val requestSize = readSizeFor(length)
        val temp = ByteArray(requestSize)
        var read = transfer("bulkIn", epIn, temp, 0, temp.size, timeoutMs)

        // 零长度包（ZLP）在部分相机/主控上会短暂出现，重试后再判定失败。
        var retries = 0
        while (read == 0 && retries < ZERO_LENGTH_PACKET_RETRIES) {
            retries++
            log("Bulk IN 收到零长度包，重试 $retries/$ZERO_LENGTH_PACKET_RETRIES")
            read = transfer(
                "bulkIn",
                epIn,
                temp,
                0,
                temp.size,
                ZERO_LENGTH_PACKET_TIMEOUT_MS,
            )
        }
        if (read <= 0) {
            transportFailed.set(true)
            log(
                "Bulk IN 失败 result=$read timeout=${timeoutMs}ms " +
                    "endpoint=0x${hexByte(epIn.address)} zlp=$retries"
            )
            return read
        }

        val copied = minOf(read, length)
        System.arraycopy(temp, 0, dst, offset, copied)
        if (read > copied) {
            // 只保留真实读到的字节，避免把请求缓冲区尾部的零字节当成后续容器。
            buffered = temp.copyOf(read)
            bufferedOffset = copied
        }
        return copied
    }

    /** 单次 bulk IN 请求长度：至少 12 字节，按最大包大小向上取整。 */
    private fun readSizeFor(length: Int): Int {
        val maxPacket = epIn.maxPacketSize
        var wanted = maxOf(length, CONTAINER_HEADER_SIZE)
        if (maxPacket > 0) {
            wanted = ((wanted + maxPacket - 1) / maxPacket) * maxPacket
        }
        return minOf(maxOf(wanted, CONTAINER_HEADER_SIZE), MAX_READ_CHUNK)
    }

    private fun writeAll(data: ByteArray) {
        var offset = 0
        while (offset < data.size) {
            val written = transfer("bulkOut", epOut, data, offset, data.size - offset, IO_TIMEOUT_MS)
            if (written <= 0) {
                transportFailed.set(true)
                log(
                    "Bulk OUT 失败 result=$written offset=$offset " +
                        "endpoint=0x${hexByte(epOut.address)}"
                )
                throw IOException("USB 写入失败（$written）")
            }
            offset += written
        }
    }

    private fun transfer(
        label: String,
        endpoint: UsbEndpoint,
        buffer: ByteArray,
        offset: Int,
        length: Int,
        timeoutMs: Int,
    ): Int {
        val active = pump ?: throw IOException("USB 传输泵不可用")
        return active.transfer(label, endpoint, buffer, offset, length, timeoutMs)
    }

    /** CLEAR_FEATURE(ENDPOINT_HALT)：端点 stall 后必须清除，否则后续读写全部失败。 */
    private fun clearHalt(endpoint: UsbEndpoint): Boolean {
        return try {
            val result = connection.controlTransfer(0x02, 1, 0, endpoint.address, null, 0, 1_000)
            log("USB clear halt endpoint=0x${hexByte(endpoint.address)} result=$result")
            result >= 0
        } catch (e: Exception) {
            log("清除端点 halt 失败（0x${hexByte(endpoint.address)}）：${e.message}")
            false
        }
    }

    val deviceId: String
        get() = "usb:${device.vendorId}:${device.productId}:${device.deviceName}"

    /** 设备 USB 拓扑摘要，失败时随错误信息回传。 */
    fun describe(): String {
        val builder = StringBuilder()
        builder.append("device=").append(device.deviceName)
        builder.append(" vid=0x").append(hexByte(device.vendorId))
        builder.append(" pid=0x").append(hexByte(device.productId))
        builder.append(" iface=").append(iface.id)
            .append("/alt=").append(iface.alternateSetting)
            .append("/class=").append(iface.interfaceClass)
        builder.append(" bulkIn=0x").append(hexByte(epIn.address))
        builder.append(" bulkOut=0x").append(hexByte(epOut.address))
        epEvent?.let { builder.append(" irqIn=0x").append(hexByte(it.address)) }
        return builder.toString()
    }

    // ============================================================
    // USB 异步传输泵
    // ============================================================

    /**
     * 用 [UsbRequest] 提交 bulk 收发，由常驻线程调用
     * [UsbDeviceConnection.requestWait] 回收结果。
     *
     * 超时由提交方 cancel 并等待回收，避免端点数据翻转（toggle）与内核状态错位。
     * PTP 的 bulk 通道是半双工的，因此同一时刻只允许一个非中断请求在途。
     */
    private inner class TransferPump {
        private val lock = Object()
        private val sequence = AtomicLong(0)
        private val pending = IdentityHashMap<UsbRequest, Transfer>()
        private val sdkInt = Build.VERSION.SDK_INT

        @Volatile
        private var isClosed = false

        @Volatile
        private var failure: Throwable? = null

        private var interruptTransfer: Transfer? = null

        private val thread = Thread({ runLoop() }, "PtpUsbTransferPump").apply {
            isDaemon = true
            start()
        }

        private fun queue(request: UsbRequest, buffer: ByteBuffer): Boolean {
            return if (sdkInt >= Build.VERSION_CODES.O) {
                request.queue(buffer)
            } else {
                @Suppress("DEPRECATION")
                request.queue(buffer, buffer.remaining())
            }
        }

        fun transfer(
            label: String,
            endpoint: UsbEndpoint,
            buffer: ByteArray,
            offset: Int,
            length: Int,
            timeoutMs: Int,
        ): Int {
            if (offset < 0 || length < 0 || offset + length > buffer.size) {
                throw IllegalArgumentException(
                    "USB 请求范围非法 offset=$offset length=$length size=${buffer.size}"
                )
            }
            if (length == 0) return 0

            val wanted = if (sdkInt <= 27) minOf(length, LEGACY_REQUEST_MAX_BYTES) else length
            val direct = ByteBuffer.allocateDirect(wanted)
            val isIn = endpoint.direction == UsbConstants.USB_DIR_IN
            if (!isIn) {
                direct.put(buffer, offset, wanted)
                direct.flip()
            }

            val request = UsbRequest()
            if (!request.initialize(connection, endpoint)) {
                runCatching { request.close() }
                throw IOException("无法初始化 USB 请求 endpoint=0x${hexByte(endpoint.address)}")
            }

            val now = System.currentTimeMillis()
            val deadline = if (timeoutMs <= 0) Long.MAX_VALUE else now + maxOf(1, timeoutMs)
            val transfer = Transfer(
                id = sequence.incrementAndGet(),
                label = label,
                endpoint = endpoint,
                request = request,
                buffer = direct,
                target = if (isIn) buffer else null,
                targetOffset = offset,
                length = wanted,
                isIn = isIn,
                deadline = deadline,
                isInterrupt = false,
                onData = null,
            )
            request.clientData = transfer

            synchronized(lock) {
                ensurePumpAlive()
                val busy = pending.values.firstOrNull { !it.isInterrupt && it.state != STATE_DONE }
                if (busy != null) {
                    runCatching { request.close() }
                    throw IOException("不允许并发 PTP bulk 请求 label=$label")
                }
                if (!queue(request, direct)) {
                    runCatching {
                        request.clientData = null
                        request.close()
                    }
                    throw IOException(
                        "USB 请求入队失败 label=$label endpoint=0x${hexByte(endpoint.address)}"
                    )
                }
                transfer.state = STATE_QUEUED
                pending[request] = transfer
                lock.notifyAll()
            }
            log(
                "USB_REQUEST queued id=${transfer.id} label=$label " +
                    "endpoint=0x${hexByte(endpoint.address)} length=$wanted"
            )

            val completed = try {
                transfer.latch.await(timeoutMs + CANCEL_GRACE_MS * 4, TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
                throw IOException("USB 请求被中断 label=$label")
            }
            if (!completed) {
                // API < 26 的 requestWait 不会超时，提交方主动 cancel 并等待回收。
                transfer.state = STATE_CANCELLED
                runCatching { request.cancel() }
                val reclaimed = try {
                    transfer.latch.await(CANCEL_GRACE_MS * 4, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    Thread.currentThread().interrupt()
                    false
                }
                if (!reclaimed) {
                    failPump(IOException("USB 请求超时未回收 label=$label"))
                    throw IOException("USB 请求超时未回收 label=$label")
                }
            }
            transfer.error?.let {
                throw IOException("USB 请求失败 label=$label: ${it.message}", it)
            }
            return transfer.result
        }

        fun startInterrupt(endpoint: UsbEndpoint, onData: (ByteArray) -> Unit) {
            val size = maxOf(endpoint.maxPacketSize, 8)
            val buffer = ByteBuffer.allocateDirect(size)
            val request = UsbRequest()
            if (!request.initialize(connection, endpoint)) {
                runCatching { request.close() }
                throw IOException("无法初始化中断端点 endpoint=0x${hexByte(endpoint.address)}")
            }
            val transfer = Transfer(
                id = sequence.incrementAndGet(),
                label = "irqPersistent",
                endpoint = endpoint,
                request = request,
                buffer = buffer,
                target = null,
                targetOffset = 0,
                length = size,
                isIn = true,
                deadline = Long.MAX_VALUE,
                isInterrupt = true,
                onData = onData,
            )
            request.clientData = transfer
            synchronized(lock) {
                ensurePumpAlive()
                interruptTransfer = transfer
                if (!queue(request, buffer)) {
                    interruptTransfer = null
                    runCatching { request.close() }
                    throw IOException(
                        "无法提交中断端点请求 endpoint=0x${hexByte(endpoint.address)}"
                    )
                }
                pending[request] = transfer
                lock.notifyAll()
            }
            log("USB_REQUEST IRQ started endpoint=0x${hexByte(endpoint.address)} maxPacket=$size")
        }

        private fun runLoop() {
            while (true) {
                synchronized(lock) {
                    if (isClosed || failure != null) return
                }
                val request = try {
                    if (sdkInt >= Build.VERSION_CODES.O) {
                        connection.requestWait(REQUEST_POLL_TIMEOUT_MS)
                    } else {
                        connection.requestWait()
                    }
                } catch (_: TimeoutException) {
                    reclaimExpired()
                    continue
                } catch (t: Throwable) {
                    failPump(t)
                    return
                }
                if (request == null) {
                    try {
                        Thread.sleep(10)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        return
                    }
                    continue
                }
                complete(request)
            }
        }

        private fun complete(request: UsbRequest) {
            val transfer = synchronized(lock) {
                pending.remove(request) ?: (request.clientData as? Transfer)
            }
            if (transfer == null) {
                runCatching { request.close() }
                return
            }
            if (transfer.isInterrupt) {
                deliverInterrupt(transfer)
                return
            }

            val cancelled = transfer.state == STATE_CANCELLED || isClosed
            val transferred = when {
                cancelled -> -1
                transfer.isIn -> transfer.buffer.position()
                else -> transfer.length
            }
            val target = transfer.target
            if (!cancelled && transfer.isIn && target != null && transferred > 0) {
                transfer.buffer.flip()
                transfer.buffer.get(
                    target,
                    transfer.targetOffset,
                    minOf(transferred, target.size - transfer.targetOffset),
                )
            }
            runCatching {
                request.clientData = null
                request.close()
            }
            transfer.state = STATE_DONE
            transfer.result = transferred
            transfer.latch.countDown()
            log(
                "USB_REQUEST completed id=${transfer.id} label=${transfer.label} " +
                    "endpoint=0x${hexByte(transfer.endpoint.address)} transferred=$transferred"
            )
        }

        private fun deliverInterrupt(transfer: Transfer) {
            val size = transfer.buffer.position()
            if (size > 0) {
                val bytes = ByteArray(size)
                transfer.buffer.flip()
                transfer.buffer.get(bytes)
                runCatching { transfer.onData?.invoke(bytes) }
            }
            if (isClosed || failure != null) {
                runCatching { transfer.request.close() }
                return
            }
            val packet = maxOf(transfer.endpoint.maxPacketSize, 8)
            val buffer = ByteBuffer.allocateDirect(packet)
            transfer.buffer = buffer
            val queued = synchronized(lock) {
                if (isClosed || failure != null || interruptTransfer !== transfer) {
                    false
                } else {
                    transfer.state = STATE_QUEUED
                    val ok = queue(transfer.request, buffer)
                    if (ok) pending[transfer.request] = transfer
                    ok
                }
            }
            if (!queued) {
                runCatching { transfer.request.close() }
            }
        }

        /** 到期未完成的请求：标记取消、cancel，并给一个回收宽限。 */
        private fun reclaimExpired() {
            val now = System.currentTimeMillis()
            val toCancel = mutableListOf<Transfer>()
            synchronized(lock) {
                for (transfer in pending.values) {
                    if (transfer.isInterrupt) continue
                    if (transfer.state == STATE_QUEUED && transfer.deadline <= now) {
                        transfer.state = STATE_CANCELLED
                        transfer.reclaimDeadline = now + CANCEL_GRACE_MS
                        toCancel.add(transfer)
                    } else if (transfer.state == STATE_CANCELLED &&
                        transfer.reclaimDeadline <= now
                    ) {
                        failPump(IOException("USB 请求无法回收 label=${transfer.label}"))
                        return
                    }
                }
                for (transfer in toCancel) {
                    log(
                        "USB_REQUEST timeout id=${transfer.id} label=${transfer.label} " +
                            "endpoint=0x${hexByte(transfer.endpoint.address)}"
                    )
                    runCatching { transfer.request.cancel() }
                }
            }
        }

        private fun ensurePumpAlive() {
            failure?.let { throw IOException("USB 传输泵已失效: ${it.message}", it) }
            if (isClosed) throw IOException("USB 传输泵已关闭")
        }

        /** 传输泵/链路失败：唤醒所有等待方，避免调用方永久阻塞。 */
        private fun failPump(t: Throwable) {
            val snapshot = synchronized(lock) {
                if (failure == null && !isClosed) failure = t
                val list = pending.values.toList()
                for (transfer in list) {
                    transfer.state = STATE_CANCELLED
                    transfer.error = t
                    if (transfer.isInterrupt) {
                        runCatching { transfer.request.cancel() }
                        transfer.request.clientData = null
                        runCatching { transfer.request.close() }
                    } else {
                        transfer.result = -1
                        transfer.latch.countDown()
                    }
                }
                pending.clear()
                interruptTransfer = null
                lock.notifyAll()
                list
            }
            log("USB_REQUEST pump failed pending=${snapshot.size}: ${t.message}")
        }

        fun close() {
            val snapshot = synchronized(lock) {
                if (isClosed) return
                isClosed = true
                val list = pending.values.toList()
                pending.clear()
                interruptTransfer = null
                lock.notifyAll()
                list
            }
            for (transfer in snapshot) {
                transfer.state = STATE_CANCELLED
                if (!transfer.isInterrupt) {
                    transfer.result = -1
                    transfer.latch.countDown()
                }
                runCatching { transfer.request.cancel() }
            }
            if (Thread.currentThread() !== thread) {
                runCatching { thread.join(500) }
            }
            for (transfer in snapshot) {
                runCatching {
                    transfer.request.clientData = null
                    transfer.request.close()
                }
            }
            log("USB_REQUEST pump closed pending=${snapshot.size}")
        }
    }

    /** 在途 USB 请求。 */
    private class Transfer(
        val id: Long,
        val label: String,
        val endpoint: UsbEndpoint,
        val request: UsbRequest,
        var buffer: ByteBuffer,
        val target: ByteArray?,
        val targetOffset: Int,
        val length: Int,
        val isIn: Boolean,
        val deadline: Long,
        val isInterrupt: Boolean,
        val onData: ((ByteArray) -> Unit)?,
    ) {
        val latch = CountDownLatch(1)

        @Volatile
        var state: Int = STATE_QUEUED

        @Volatile
        var result: Int = -1

        @Volatile
        var error: Throwable? = null

        @Volatile
        var reclaimDeadline: Long = Long.MAX_VALUE
    }
}

private const val STATE_QUEUED = 0
private const val STATE_CANCELLED = 1
private const val STATE_DONE = 2

private fun hexByte(value: Int): String = value.toString(16).padStart(2, '0')

private fun ptpResponseName(code: Int): String = when (code) {
    0x2001 -> "OK"
    0x2002 -> "GeneralError"
    0x2003 -> "SessionNotOpen"
    0x2005 -> "OperationNotSupported"
    0x2006 -> "OperationNotAllowed"
    0x2019 -> "DeviceBusy"
    0x201E -> "SessionAlreadyOpen"
    0x201F -> "InvalidDevicePropFormat"
    0x2020 -> "DevicePropNotSupported"
    0xA001 -> "StoreNotAvailable"
    else -> "Unknown"
}

/** PTP over USB 响应码异常。 */
class PtpUsbException(val opCode: Int, val responseCode: Int) :
    Exception(
        "PTP USB 操作 0x${opCode.toString(16)} 失败，响应码 0x${responseCode.toString(16)}" +
            "（${ptpResponseName(responseCode)}）"
    )
