import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/transfer/keep_alive_arbiter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.zync.app/native_camera');
  late List<String> calls;

  setUp(() {
    calls = <String>[];
    KeepAliveArbiter.instance.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    KeepAliveArbiter.instance.resetForTest();
  });

  test('两个来源：只有全部释放后才停止前台服务', () async {
    final arbiter = KeepAliveArbiter.instance;

    arbiter.acquire('transfer', title: 'Zync 正在传输');
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c == 'startTransferKeepAlive').length, 1);
    expect(calls.contains('stopTransferKeepAlive'), isFalse);

    arbiter.acquire('capture', title: 'Zync 正在进行拍摄');
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c == 'startTransferKeepAlive').length, 1,
        reason: '同一时间只应有一个前台服务实例');
    expect(calls.contains('stopTransferKeepAlive'), isFalse);

    arbiter.release('capture');
    await Future<void>.delayed(Duration.zero);
    expect(calls.contains('stopTransferKeepAlive'), isFalse,
        reason: '传输仍在进行，不能停服务');

    arbiter.release('transfer');
    await Future<void>.delayed(Duration.zero);
    expect(calls.contains('stopTransferKeepAlive'), isTrue);
  });

  test('重复 acquire 不会重复启动服务', () async {
    final arbiter = KeepAliveArbiter.instance;
    arbiter.acquire('transfer', title: 'A');
    await Future<void>.delayed(Duration.zero);
    arbiter.acquire('transfer', title: 'A');
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((c) => c == 'startTransferKeepAlive').length, 1);
    arbiter.release('transfer');
  });
}
