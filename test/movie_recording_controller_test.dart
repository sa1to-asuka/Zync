import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/engine/capture/movie_recording_controller.dart';

class _FakeMovieDriver implements MovieRecordingDriver {
  @override
  bool isConnected = true;

  @override
  bool supportsMovieRecording = true;

  int? selector = 0;
  int? prohibition = 0;
  bool rejectSelectorWrite = false;

  final List<String> calls = <String>[];
  final StreamController<int> _events = StreamController<int>.broadcast();

  @override
  Stream<int> get eventCodes => _events.stream;

  void emit(int code) => _events.add(code);

  @override
  Future<int?> readLiveViewSelector() async => selector;

  @override
  Future<int?> readMovieRecProhibition() async => prohibition;

  @override
  Future<void> setLiveViewSelector(int value) async {
    if (rejectSelectorWrite) throw StateError('拒绝写入');
    selector = value;
    calls.add('selector=$value');
  }

  @override
  Future<void> startMovieRecording() async {
    calls.add('start');
  }

  @override
  Future<void> stopMovieRecording() async {
    calls.add('stop');
  }

  Future<void> dispose() => _events.close();
}

void main() {
  late _FakeMovieDriver driver;
  late MovieRecordingController controller;
  late DateTime clock;

  setUp(() {
    driver = _FakeMovieDriver();
    clock = DateTime(2026, 1, 1, 12);
    controller = MovieRecordingController(
      driver: driver,
      finalizeTimeout: const Duration(milliseconds: 100),
      now: () => clock,
    );
    controller.attach();
  });

  tearDown(() async {
    controller.dispose();
    await driver.dispose();
  });

  test('切换录像模式会写 0xD1A6', () async {
    final ok = await controller.switchMode(CameraCaptureMode.video);
    expect(ok, isTrue);
    expect(driver.selector, 1);
    expect(controller.mode, CameraCaptureMode.video);
  });

  test('机身拒绝写入时进入物理拨杆状态', () async {
    driver.rejectSelectorWrite = true;
    final ok = await controller.switchMode(CameraCaptureMode.video);

    expect(ok, isFalse);
    expect(controller.mode, CameraCaptureMode.lockedByPhysicalLever);
    expect(controller.lastError, isNotNull);
  });

  test('写入被拒但回读已是录像档：视为切换成功', () async {
    // Z 30 的拨杆已经把 0xD1A6 改成 1，只是不接受 App 写入。
    driver.rejectSelectorWrite = true;
    driver.selector = 1;

    final ok = await controller.switchMode(CameraCaptureMode.video);

    expect(ok, isTrue);
    expect(controller.mode, CameraCaptureMode.video);
  });

  test('选择器读不到时不锁死界面，允许进入录像', () async {
    driver.rejectSelectorWrite = true;
    driver.selector = null;

    final ok = await controller.switchMode(CameraCaptureMode.video);

    expect(ok, isTrue, reason: '读不到 0xD1A6 的固件不该被永久卡在拍照档');
    expect(controller.mode, CameraCaptureMode.video);
  });

  test('轮询能把机身拨杆的状态反映到模式上', () async {
    driver.selector = 0;
    await controller.refresh();
    expect(controller.mode, CameraCaptureMode.photo);

    // 用户把拨杆拨到视频档。
    driver.selector = 1;
    await controller.refresh();
    expect(controller.mode, CameraCaptureMode.video);
    expect(controller.phase, MovieRecordingPhase.idle);
  });

  test('拨杆离开受限位置后不再卡在 lockedByPhysicalLever', () async {
    driver.selector = null;
    driver.prohibition = 1 << 13;
    await controller.refresh();
    expect(controller.mode, CameraCaptureMode.lockedByPhysicalLever);

    driver.prohibition = 0;
    await controller.refresh();
    expect(controller.mode, CameraCaptureMode.photo);
  });

  test('0xD0A4 bit 13 表示拨杆不在录像档', () async {
    driver.prohibition = 1 << 13;
    await controller.refresh();

    expect(controller.prohibition.needsPhysicalLever, isTrue);
    expect(controller.mode, CameraCaptureMode.lockedByPhysicalLever);
    expect(controller.prohibition.reasons, contains(13));
  });

  test('拨杆状态阻止开始录制', () async {
    driver.prohibition = 1 << 13;
    await controller.refresh();

    final ok = await controller.startRecording();
    expect(ok, isFalse);
    expect(driver.calls, isNot(contains('start')));
  });

  test('开始 → 录制中 → 停止并等待封盘完成', () async {
    await controller.switchMode(CameraCaptureMode.video);

    expect(await controller.startRecording(), isTrue);
    expect(controller.phase, MovieRecordingPhase.recording);
    expect(controller.isRecording, isTrue);

    final stopFuture = controller.stopRecording();
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, MovieRecordingPhase.finalizing);

    // 相机封盘完成事件到达后才回到待机。
    driver.emit(PtpOpCodes.eventNikonMovieRecComplete);
    await stopFuture;

    expect(controller.phase, MovieRecordingPhase.idle);
    expect(driver.calls, containsAllInOrder(<String>['start', 'stop']));
  });

  test('收不到 0xC108 时按超时兜底结束', () async {
    await controller.switchMode(CameraCaptureMode.video);
    await controller.startRecording();

    await controller.stopRecording();
    expect(controller.phase, MovieRecordingPhase.idle);
  });

  test('机身侧录像键：帧头标志切换 UI 状态', () {
    controller.syncRecordingFlag(true);
    expect(controller.phase, MovieRecordingPhase.recording);

    clock = clock.add(const Duration(seconds: 5));
    controller.syncRecordingFlag(false);
    expect(controller.phase, MovieRecordingPhase.idle);
  });

  test('刚进入录制时不采信帧头的 false', () {
    controller.syncRecordingFlag(true);
    controller.syncRecordingFlag(false);
    expect(controller.phase, MovieRecordingPhase.recording,
        reason: '帧头比指令晚一两帧，过早采信会把刚开始的录制打回待机');
  });

  test('录制中再次开始是空操作', () async {
    await controller.switchMode(CameraCaptureMode.video);
    await controller.startRecording();
    expect(await controller.startRecording(), isFalse);
    expect(driver.calls.where((c) => c == 'start').length, 1);
  });
}
