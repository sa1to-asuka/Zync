import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../core/constants/ptp_opcodes.dart';
import '../core/settings/app_settings.dart';
import '../core/utils/byte_buffer_ext.dart';
import 'ptp_packet.dart';
import 'ptp_transport.dart';

/// PTP 通信异常
class PtpException implements Exception {
  final int opCode;
  final int responseCode;
  final String message;

  PtpException(this.opCode, this.responseCode, [this.message = 'PTP 操作异常']);

  @override
  String toString() =>
      'PtpException(opCode: 0x${opCode.toRadixString(16)}, code: 0x${responseCode.toRadixString(16)}, msg: $message)';
}

/// 纯 Dart PTP/IP 双通道 Socket 客户端。
///
/// 封包布局与握手流程遵循 PTP/IP 传输层规范；命令通道负责操作请求与响应，
/// 事件通道负责会话绑定后的异步事件。
class PtpIpClient implements PtpTransport {
  final String host;
  final int port;
  final void Function(String message)? onLog;
  final Uint8List? clientGuid;
  final String clientName;
  final int connectRetryCount;
  final Duration connectRetryDelay;

  Socket? _cmdSocket;
  Socket? _eventSocket;

  int _transactionId = 0;
  int _connectionNumber = 0;
  String _cameraName = '';
  String _cameraGuid = '';
  bool _isConnected = false;
  bool _disconnecting = false;
  Timer? _heartbeatTimer;

  final StreamController<PtpPacket> _eventController =
      StreamController<PtpPacket>.broadcast();
  final _PacketStreamBuffer _cmdReceiveBuffer = _PacketStreamBuffer();
  final _PacketStreamBuffer _eventReceiveBuffer = _PacketStreamBuffer();

  Completer<PtpPacket>? _pendingCmdAckCompleter;
  Completer<PtpPacket>? _pendingEventAckCompleter;
  Completer<PtpPacket>? _pendingResponseCompleter;
  BytesBuilder? _incomingDataBuffer;
  int _activeTransactionId = 0;
  int? _expectedDataLength;

  PtpIpClient({
    this.host = '192.168.0.1',
    this.port = 15740,
    this.onLog,
    this.clientGuid,
    this.clientName = 'Zync',
    this.connectRetryCount = 3,
    this.connectRetryDelay = const Duration(milliseconds: 600),
  });

  @override
  bool get isConnected => _isConnected;
  int get transactionId => _transactionId;
  @override
  Stream<PtpPacket> get events => _eventController.stream;
  String get cameraName => _cameraName;
  String get cameraGuid => _cameraGuid;

  void _log(String msg) {
    if (onLog != null) {
      onLog!(msg);
    }
  }

  /// 建立命令与事件双通道并开启 PTP 会话。
  @override
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isConnected) return;
    _disconnecting = false;

    try {
      _log('【握手1/7】连接命令通道 TCP $host:$port ...');
      _cmdSocket = await _connectSocket('命令通道', timeout);
      _cmdSocket!.listen(
        _onCommandData,
        onError: (err) {
          _log('命令通道异常断开: $err');
          if (!_disconnecting) unawaited(disconnect());
        },
        onDone: () {
          _log('命令通道连接关闭');
          if (!_disconnecting) unawaited(disconnect());
        },
      );

      _log('【握手2/7】发送 InitCommandRequest ...');
      final initCmdPacket = PtpPacket.buildInitCommandRequest(
        clientName: clientName,
        guid: clientGuid ?? AppSettings.instance.ptpClientGuidBytes,
      );
      final cmdCompleter = Completer<PtpPacket>();
      _pendingCmdAckCompleter = cmdCompleter;
      _cmdSocket!.add(initCmdPacket.toBytes());

      final ack = await cmdCompleter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('等待 InitCommandAck 超时'),
      );
      _pendingCmdAckCompleter = null;

      if (ack.type == PtpOpCodes.ptpIpInitFail) {
        final code = ack.payload.length >= 4 ? ack.getUint32(0) : 0;
        throw PtpException(
            0, code, '相机拒绝 PTP/IP 连接 (Init_Fail 0x${code.toRadixString(16)})');
      }
      if (ack.type != PtpOpCodes.ptpIpInitCommandAck) {
        throw FormatException('命令通道握手响应类型异常: ${ack.type}');
      }

      final initAck = PtpIpInitAck.parse(ack);
      _connectionNumber = initAck.connectionNumber;
      _cameraGuid = initAck.cameraGuid;
      _cameraName = initAck.cameraName;
      _log(
          '【握手3/7】会话编号 0x${_connectionNumber.toRadixString(16)}，相机=${_cameraName.isEmpty ? '未命名' : _cameraName}');

      _log('【握手4/7】连接事件通道 TCP $host:$port ...');
      _eventSocket = await _connectSocket('事件通道', timeout);
      _eventSocket!.listen(
        _onEventData,
        onError: (err) {
          _log('事件通道异常断开: $err');
          if (!_disconnecting) unawaited(disconnect());
        },
        onDone: () {
          _log('事件通道连接关闭');
          if (!_disconnecting) unawaited(disconnect());
        },
      );

      _log('【握手5/7】发送 InitEventRequest ...');
      final eventCompleter = Completer<PtpPacket>();
      _pendingEventAckCompleter = eventCompleter;
      _eventSocket!
          .add(PtpPacket.buildInitEventRequest(_connectionNumber).toBytes());

      _log('【握手6/7】等待 InitEventAck ...');
      final eventAck = await eventCompleter.future.timeout(
        timeout,
        onTimeout: () => throw TimeoutException('等待 InitEventAck 超时'),
      );
      _pendingEventAckCompleter = null;
      if (eventAck.type == PtpOpCodes.ptpIpInitFail) {
        final code = eventAck.payload.length >= 4 ? eventAck.getUint32(0) : 0;
        throw PtpException(
            0, code, '相机拒绝事件通道绑定 (Init_Fail 0x${code.toRadixString(16)})');
      }
      if (eventAck.type != PtpOpCodes.ptpIpInitEventAck) {
        throw FormatException('事件通道握手响应类型异常: ${eventAck.type}');
      }

      _log('【握手7/7】开启 PTP 会话 ...');
      _isConnected = true;
      await executeOperation(PtpOpCodes.openSession, [1]);
      _startHeartbeat();
      _log('PTP/IP 会话已就绪');
    } catch (_) {
      _isConnected = false;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      await _closeSockets();
      rethrow;
    }
  }

  Future<Socket> _connectSocket(String label, Duration timeout) async {
    Object? lastError;
    for (var attempt = 1; attempt <= connectRetryCount; attempt++) {
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.setOption(SocketOption.tcpNoDelay, true);
        return socket;
      } catch (e) {
        lastError = e;
        if (attempt >= connectRetryCount) break;
        _log('$label连接失败 ($attempt/$connectRetryCount)，重试中: $e');
        await Future<void>.delayed(connectRetryDelay);
      }
    }
    throw TimeoutException('$label无法连接 $host:$port：$lastError');
  }

  Future<void> _closeSockets() async {
    final error = StateError('PTP/IP 连接已关闭');
    try {
      await _cmdSocket?.close();
    } catch (_) {}
    try {
      await _eventSocket?.close();
    } catch (_) {}
    _cmdSocket = null;
    _eventSocket = null;
    _cmdReceiveBuffer.clear();
    _eventReceiveBuffer.clear();

    if (_pendingCmdAckCompleter != null &&
        !_pendingCmdAckCompleter!.isCompleted) {
      _pendingCmdAckCompleter!.completeError(error);
    }
    if (_pendingEventAckCompleter != null &&
        !_pendingEventAckCompleter!.isCompleted) {
      _pendingEventAckCompleter!.completeError(error);
    }
    if (_pendingResponseCompleter != null &&
        !_pendingResponseCompleter!.isCompleted) {
      _pendingResponseCompleter!.completeError(error);
    }
    _pendingCmdAckCompleter = null;
    _pendingEventAckCompleter = null;
    _pendingResponseCompleter = null;
    _incomingDataBuffer = null;
  }

  Future<void>? _currentOpFuture;

  /// 严格的 PTP 命令互斥锁 (FIFO 串行化，防止并发请求冲撞导致 Socket 数据交织)
  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final prev = _currentOpFuture;
    final completer = Completer<void>();
    _currentOpFuture = completer.future;

    if (prev != null) {
      try {
        await prev;
      } catch (_) {}
    }

    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// 发送指令并接收 OperationResponse (不带数据包)
  @override
  Future<void> executeOperation(int opCode, [List<int> params = const []]) {
    return _synchronized(() async {
      _transactionId++;
      _activeTransactionId = _transactionId;
      _expectedDataLength = null;
      final req = PtpPacket.buildOperationRequest(
        opCode: opCode,
        transactionId: _transactionId,
        params: params,
      );

      final completer = Completer<PtpPacket>();
      _pendingResponseCompleter = completer;
      _cmdSocket!.add(req.toBytes());

      try {
        final resp = await completer.future.timeout(
          const Duration(seconds: 6),
          onTimeout: () => throw TimeoutException(
              '操作 0x${opCode.toRadixString(16)} 响应超时 (6秒未返回)'),
        );
        final respCode = resp.getUint16(0);
        // 0x2001 (OK) 或 0x201E (SessionAlreadyOpen) 均视为正常。
        if (respCode != PtpOpCodes.responseOk) {
          if (opCode == PtpOpCodes.openSession &&
              respCode == PtpOpCodes.responseSessionAlreadyOpen) {
            _log('相机主会话已处于开启状态 (0x201E)，直接复用。');
          } else {
            throw PtpException(
                opCode, respCode, '相机返回失败代码 0x${respCode.toRadixString(16)}');
          }
        }
      } finally {
        if (_pendingResponseCompleter == completer) {
          _pendingResponseCompleter = null;
        }
      }
    });
  }

  /// 发送指令并接收返回的大块二进制数据（例如照片分块）
  @override
  Future<Uint8List> executeDataIn(int opCode, [List<int> params = const []]) {
    return _synchronized(() async {
      _transactionId++;
      _activeTransactionId = _transactionId;
      _expectedDataLength = null;
      final req = PtpPacket.buildOperationRequest(
        opCode: opCode,
        transactionId: _transactionId,
        params: params,
      );

      final completer = Completer<PtpPacket>();
      _pendingResponseCompleter = completer;
      _incomingDataBuffer = BytesBuilder();

      _cmdSocket!.add(req.toBytes());

      try {
        final resp = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () =>
              throw TimeoutException('数据拉取 0x${opCode.toRadixString(16)} 响应超时'),
        );
        final respCode = resp.getUint16(0);
        if (respCode != PtpOpCodes.responseOk) {
          _incomingDataBuffer = null;
          throw PtpException(opCode, respCode,
              '数据读取指令 0x${opCode.toRadixString(16)} 失败 (代码 0x${respCode.toRadixString(16)})');
        }

        var data = _incomingDataBuffer?.toBytes() ?? Uint8List(0);
        final expectedLen = _expectedDataLength;
        _incomingDataBuffer = null;
        _expectedDataLength = null;
        if (expectedLen != null && expectedLen > 0) {
          if (data.length < expectedLen) {
            throw StateError(
              'PTP/IP 0x${opCode.toRadixString(16)} 数据包截断 (${data.length}/$expectedLen 字节)',
            );
          }
          if (data.length > expectedLen) {
            data = Uint8List.sublistView(data, 0, expectedLen);
          }
        }
        return data;
      } finally {
        if (_pendingResponseCompleter == completer) {
          _pendingResponseCompleter = null;
        }
        _incomingDataBuffer = null;
        _expectedDataLength = null;
      }
    });
  }

  /// 发送指令与待写入的数据负载 (Data-Out Phase, 用于 SetDevicePropValue 等属性设置)
  @override
  Future<void> executeDataOut(int opCode, Uint8List data,
      [List<int> params = const []]) {
    return _synchronized(() async {
      _transactionId++;
      _activeTransactionId = _transactionId;
      _expectedDataLength = null;

      // 1. 发送 OperationRequest (Type = 6, DataPhase = 2 代表下发数据)
      final req = PtpPacket.buildOperationRequest(
        opCode: opCode,
        transactionId: _transactionId,
        params: params,
        dataPhase: 2,
      );

      // 2. 构造 StartDataPacket (Type = 9, 20 字节)
      final startDataBuf = PtpByteBuffer();
      startDataBuf.writeUint32(20);
      startDataBuf.writeUint32(PtpOpCodes.ptpIpStartDataPacket);
      startDataBuf.writeUint32(_transactionId);
      startDataBuf.writeUint64(data.length);

      // 3. 构造 EndDataPacket (Type = 12, 12 + data.length 字节)
      final endDataBuf = PtpByteBuffer();
      endDataBuf.writeUint32(12 + data.length);
      endDataBuf.writeUint32(PtpOpCodes.ptpIpEndDataPacket);
      endDataBuf.writeUint32(_transactionId);
      endDataBuf.writeBytes(data);

      final completer = Completer<PtpPacket>();
      _pendingResponseCompleter = completer;

      _cmdSocket!.add(req.toBytes());
      _cmdSocket!.add(startDataBuf.toBytes());
      _cmdSocket!.add(endDataBuf.toBytes());

      try {
        final resp = await completer.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () =>
              throw TimeoutException('数据写入 0x${opCode.toRadixString(16)} 响应超时'),
        );
        final respCode = resp.getUint16(0);
        if (respCode != PtpOpCodes.responseOk) {
          throw PtpException(opCode, respCode,
              '数据下发指令 0x${opCode.toRadixString(16)} 失败 (代码 0x${respCode.toRadixString(16)})');
        }
      } finally {
        if (_pendingResponseCompleter == completer) {
          _pendingResponseCompleter = null;
        }
      }
    });
  }

  /// 处理命令通道收到的字节流与拆包（零拷贝线性滑动缓冲，消除 O(N^2) 内存拷贝）
  void _onCommandData(Uint8List chunk) {
    _cmdReceiveBuffer.add(chunk);

    while (true) {
      final packet = _cmdReceiveBuffer.parseNextPacket();
      if (packet == null) break; // 粘包未完整到达

      // 分发包类型
      if (packet.type == PtpOpCodes.ptpIpInitCommandAck ||
          packet.type == PtpOpCodes.ptpIpInitFail) {
        // InitCommandAck (Type = 2) 或 InitFail (Type = 5)
        if (_pendingCmdAckCompleter != null &&
            !_pendingCmdAckCompleter!.isCompleted) {
          _pendingCmdAckCompleter!.complete(packet);
        }
      } else if (packet.type == PtpOpCodes.ptpIpStartDataPacket) {
        // 数据流开始: [transactionId(4B), totalDataLength(8B)]
        if (packet.payload.length >= 12) {
          final txId = packet.getUint32(0);
          if (txId == _activeTransactionId) {
            final low = packet.getUint32(4);
            final high = packet.getUint32(8);
            if (high == 0 && low != 0xFFFFFFFF) {
              _expectedDataLength = low;
            }
          }
        }
      } else if (packet.type == PtpOpCodes.ptpIpDataPacket ||
          packet.type == PtpOpCodes.ptpIpEndDataPacket) {
        // 数据分片追加 (校验 4 字节事务 ID，避免前序超时请求串扰)
        if (packet.payload.length > 4) {
          final txId = packet.getUint32(0);
          if (txId == _activeTransactionId) {
            _incomingDataBuffer?.add(packet.payload.sublist(4));
          }
        }
      } else if (packet.type == PtpOpCodes.ptpIpOperationResponse) {
        // 操作完成响应 (Type = 7): [responseCode(2B), transactionId(4B), ...]
        final txId = packet.payload.length >= 6
            ? packet.getUint32(2)
            : _activeTransactionId;
        if (txId == _activeTransactionId &&
            _pendingResponseCompleter != null &&
            !_pendingResponseCompleter!.isCompleted) {
          _pendingResponseCompleter!.complete(packet);
        }
      }
    }
  }

  /// 处理事件通道推送的事件包 (接收 InitEventAck 与异步事件通知)
  void _onEventData(Uint8List chunk) {
    _eventReceiveBuffer.add(chunk);

    while (true) {
      final packet = _eventReceiveBuffer.parseNextPacket();
      if (packet == null) break;

      if (packet.type == PtpOpCodes.ptpIpInitEventAck ||
          packet.type == PtpOpCodes.ptpIpInitFail) {
        // InitEventAck (Type = 4) 或 InitFail (Type = 5)
        if (_pendingEventAckCompleter != null &&
            !_pendingEventAckCompleter!.isCompleted) {
          _pendingEventAckCompleter!.complete(packet);
        }
      } else if (packet.type == PtpOpCodes.ptpIpEvent) {
        // 相机推送的事件 (如 ObjectAdded 0x4002 拍摄完成)
        _eventController.add(packet);
      }
    }
  }

  /// 心跳定时保活（可由设置页关闭，默认 15 秒）
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (!AppSettings.instance.autoKeepAlive) {
      _log('心跳保活已按设置关闭');
      return;
    }
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      try {
        await executeOperation(PtpOpCodes.getStorageIDs);
      } catch (_) {}
    });
  }

  /// 断开连接并释放资源。
  @override
  Future<void> disconnect() async {
    if (_disconnecting) return;
    _disconnecting = true;
    final wasConnected = _isConnected;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    try {
      if (wasConnected && _cmdSocket != null) {
        await executeOperation(PtpOpCodes.closeSession);
      }
    } catch (_) {}
    await _closeSockets();
    _disconnecting = false;
  }

  void dispose() {
    unawaited(disconnect());
    _eventController.close();
  }
}

/// 高性能零拷贝环形/线性滑动切片缓冲区，消除网络粘包解析时的 O(N^2) 内存拷贝与 GC 停顿
class _PacketStreamBuffer {
  Uint8List _buffer = Uint8List(128 * 1024);
  int _writeOffset = 0;
  int _readOffset = 0;

  int get length => _writeOffset - _readOffset;

  void add(Uint8List chunk) {
    final needed = chunk.length;
    if (_writeOffset + needed > _buffer.length) {
      final unread = length;
      if (unread + needed <= _buffer.length) {
        if (unread > 0) {
          _buffer.setRange(0, unread, _buffer, _readOffset);
        }
        _readOffset = 0;
        _writeOffset = unread;
      } else {
        var newCap = _buffer.length * 2;
        while (unread + needed > newCap) {
          newCap *= 2;
        }
        final newBuf = Uint8List(newCap);
        if (unread > 0) {
          newBuf.setRange(0, unread, _buffer, _readOffset);
        }
        _buffer = newBuf;
        _readOffset = 0;
        _writeOffset = unread;
      }
    }
    _buffer.setRange(_writeOffset, _writeOffset + needed, chunk);
    _writeOffset += needed;
  }

  PtpPacket? parseNextPacket() {
    if (length < 8) return null;
    final bd = ByteData.sublistView(_buffer, _readOffset, _readOffset + 8);
    final totalLen = bd.getUint32(0, Endian.little);
    if (totalLen < 8 || length < totalLen) return null;

    final type = bd.getUint32(4, Endian.little);
    final payload = Uint8List.fromList(
      _buffer.sublist(_readOffset + 8, _readOffset + totalLen),
    );
    _readOffset += totalLen;
    if (_readOffset == _writeOffset) {
      _readOffset = 0;
      _writeOffset = 0;
    }
    return PtpPacket(length: totalLen, type: type, payload: payload);
  }

  void clear() {
    _readOffset = 0;
    _writeOffset = 0;
  }
}
