import 'dart:typed_data';

import 'ptp_packet.dart';

/// 相机 PTP 传输抽象：Wi-Fi（PTP/IP over TCP）与 USB（PTP over USB）共用同一套上层指令。
///
/// `NikonDriver` 只依赖本接口，因此切换 Wi-Fi / USB 通道时无需改动业务逻辑。
abstract class PtpTransport {
  bool get isConnected;

  /// 相机异步事件（如 ObjectAdded 0x4002）。
  Stream<PtpPacket> get events;

  Future<void> connect();

  Future<void> disconnect();

  /// 不带数据阶段的指令（读取响应容器）。
  Future<void> executeOperation(int opCode, [List<int> params = const []]);

  /// 数据输入阶段（相机 → 手机），返回数据容器负载。
  Future<Uint8List> executeDataIn(int opCode, [List<int> params = const []]);

  /// 数据输出阶段（手机 → 相机）。
  Future<void> executeDataOut(int opCode, Uint8List data, [List<int> params = const []]);
}
