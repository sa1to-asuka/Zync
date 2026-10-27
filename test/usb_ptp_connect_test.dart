import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/protocol/camera_native_bridge.dart';
import 'package:zync/protocol/usb_ptp_transport.dart';

/// USB PTP 连接链路：原生失败原因必须原样回传到连接页日志，
/// 不能再退化成一句「USB PTP 会话建立失败」而无从排查。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.zync.app/native_camera');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('USB 连接失败时把原生失败原因带回日志', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'requestUsbPermission':
          return true;
        case 'usbOpenSession':
          throw PlatformException(
            code: 'USB_OPEN_FAILED',
            message: 'USB 读取失败（-1）：相机无响应；步骤: 接口就绪 id=0 alt=1',
          );
      }
      return null;
    });

    final logs = <String>[];
    final transport =
        UsbPtpTransport(deviceName: '/dev/bus/usb/001/002', onLog: logs.add);

    await expectLater(
      transport.connect(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('相机无响应'), contains('接口就绪')),
        ),
      ),
    );
    expect(calls,
        containsAllInOrder(<String>['requestUsbPermission', 'usbOpenSession']));
    expect(logs.any((line) => line.contains('OpenSession')), isTrue);
    expect(transport.isConnected, isFalse);
    transport.dispose();
  });

  test('授权被拒绝时不打开原生会话', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'requestUsbPermission') return false;
      return null;
    });

    final transport = UsbPtpTransport(deviceName: '/dev/bus/usb/001/002');
    await expectLater(transport.connect(), throwsA(isA<StateError>()));
    expect(calls, equals(<String>['requestUsbPermission']));
    transport.dispose();
  });

  test('USB 设备模型保留厂商与 PTP 模式信息', () {
    final device = UsbDeviceInfo.fromMap({
      'deviceName': '/dev/bus/usb/001/003',
      'vendorId': 0x04B0,
      'productId': 0x0430,
      'name': 'NIKON Z 30',
      'hasPermission': true,
      'isNikon': true,
      'isCamera': true,
      'vendorName': 'Nikon',
      'ptpReady': false,
      'storageOnly': true,
    });

    expect(device.isNikon, isTrue);
    expect(device.vendorName, 'Nikon');
    expect(device.modeLabel, '大容量存储模式');
    expect(device.vendorProductHex, '0x04B0:0x0430');
  });

  test('会话建立成功后 USB 传输层可用', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'requestUsbPermission':
          return true;
        case 'usbOpenSession':
          return 'usb:1200:100:/dev/bus/usb/001/002';
        case 'usbCloseSession':
          return true;
      }
      return null;
    });

    final logs = <String>[];
    final transport =
        UsbPtpTransport(deviceName: '/dev/bus/usb/001/002', onLog: logs.add);
    await transport.connect();

    expect(transport.isConnected, isTrue);
    expect(transport.deviceId, 'usb:1200:100:/dev/bus/usb/001/002');
    expect(logs.any((line) => line.contains('USB PTP 会话已建立')), isTrue);

    await transport.disconnect();
    expect(transport.isConnected, isFalse);
    transport.dispose();
  });
}
