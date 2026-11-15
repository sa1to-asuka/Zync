import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/exposure_bracketing_controller.dart';
import 'package:zync/engine/capture/focus_stacking_controller.dart';
import 'package:zync/protocol/camera_driver.dart';

class _FakeBracketPort implements BracketPort {
  _FakeBracketPort({
    this.current = 3,
    this.builtIn = 0,
  });

  List<int> options = const <int>[0, 1, 2, 3, 4, 5, 6];
  int? current;
  int? builtIn;
  bool acceptWrites = true;

  final List<int> writes = <int>[];
  int captures = 0;

  /// 挂住capture，便于测试在序列中途调用 stop()。
  Completer<void>? captureGate;

  @override
  bool get isConnected => true;

  @override
  Future<int?> readBuiltInBracketing() async => builtIn;

  @override
  Future<List<int>> optionsOf(BracketAxis axis) async => options;

  @override
  Future<int?> currentOf(BracketAxis axis) async => current;

  @override
  Future<bool> write(BracketAxis axis, int raw) async {
    writes.add(raw);
    if (!acceptWrites) return false;
    current = raw;
    return true;
  }

  @override
  Future<CameraFileItem?> capture() async {
    captures++;
    final gate = captureGate;
    if (gate != null) await gate.future;
    return null;
  }

  @override
  Future<void> settle(Duration duration) async {}
}

class _FakeFocusPort implements FocusStackPort {
  _FakeFocusPort({this.maxMoves = 100, this.missCaptures = false});

  final int maxMoves;
  final bool missCaptures;
  int moves = 0;
  int captures = 0;

  @override
  bool get isConnected => true;

  @override
  Future<bool> drive(MfDirection direction, int steps) async {
    moves++;
    return moves <= maxMoves;
  }

  @override
  Future<CameraFileItem?> capture() async {
    captures++;
    if (missCaptures) return null;
    return CameraFileItem(
      handle: 1000 + captures,
      storageId: 0x00010001,
      format: 0x3801,
      size: 4096,
      fileName: 'FS_$captures.JPG',
      captureDate: '20261115T120000',
    );
  }

  @override
  Future<void> settle(Duration duration) async {}
}

void main() {
  group('包围序列生成', () {
    test('5 张居中，按 0, -, + 顺序', () {
      final seq = buildBracketSequence(
        options: const [0, 1, 2, 3, 4, 5, 6],
        anchorIndex: 3,
        shotCount: 5,
        step: 1,
      );
      expect(seq, [3, 2, 4, 1, 5]);
    });

    test('张数超出档位范围时截断并去重', () {
      final seq = buildBracketSequence(
        options: const [10, 20, 30],
        anchorIndex: 1,
        shotCount: 9,
        step: 1,
      );
      expect(seq, [20, 10, 30]);
      expect(seq.toSet().length, seq.length, reason: '不能重复拍同一档');
    });

    test('到达档位表末端时不会越界', () {
      final seq = buildBracketSequence(
        options: const [10, 20, 30],
        anchorIndex: 0,
        shotCount: 5,
        step: 2,
      );
      expect(seq.first, 10);
      expect(seq.every((v) => v >= 10 && v <= 30), isTrue);
    });

    test('从暗到亮排序', () {
      final seq = buildBracketSequence(
        options: const [0, 1, 2, 3, 4, 5, 6],
        anchorIndex: 3,
        shotCount: 5,
        step: 1,
        order: BracketOrder.darkToLight,
      );
      expect(seq, [1, 2, 3, 4, 5]);
    });

    test('空档位表返回空序列', () {
      expect(
        buildBracketSequence(
            options: const [], anchorIndex: 0, shotCount: 3, step: 1),
        isEmpty,
      );
    });
  });

  group('包围曝光执行', () {
    test('逐张写入并拍完整个序列，最后还原原始值', () async {
      final port = _FakeBracketPort(current: 3);
      final controller = ExposureBracketingController(port: port);

      final ok = await controller.start(const ExposureBracketConfig(
        axis: BracketAxis.exposureCompensation,
        shotCount: 5,
        step: 1,
      ));

      expect(ok, isTrue);
      expect(port.captures, 5);
      expect(port.writes, [3, 2, 4, 1, 5, 3], reason: '最后一个 3 是还原');
      expect(controller.state, BracketState.completed);
      expect(controller.restoreFailed, isFalse);
    });

    test('机身内置包围开启时直接拒绝', () async {
      final port = _FakeBracketPort(builtIn: 1);
      final controller = ExposureBracketingController(port: port);

      final ok = await controller.start(const ExposureBracketConfig(
        axis: BracketAxis.shutter,
        shotCount: 3,
        step: 1,
      ));

      expect(ok, isFalse);
      expect(port.captures, 0);
      expect(controller.state, BracketState.failed);
    });

    test('中途写入被拒也会还原原始参数', () async {
      final port = _FakeBracketPort(current: 3);
      final controller = ExposureBracketingController(port: port);
      // 第二张开始相机拒绝写入。
      port.acceptWrites = true;
      final future = controller.start(const ExposureBracketConfig(
        axis: BracketAxis.iso,
        shotCount: 5,
        step: 1,
      ));
      port.acceptWrites = false;
      await future;

      expect(port.writes.last, 3, reason: '无论如何都要还原');
      expect(controller.state, BracketState.failed);
    });

    test('stop 会中断并还原', () async {
      final port = _FakeBracketPort(current: 3);
      final controller = ExposureBracketingController(port: port);
      port.captureGate = Completer<void>();

      final future = controller.start(const ExposureBracketConfig(
        axis: BracketAxis.exposureCompensation,
        shotCount: 9,
        step: 1,
      ));
      // 让序列跑到第一张快门，再中断。
      await Future<void>.delayed(Duration.zero);
      controller.stop();
      port.captureGate!.complete();
      port.captureGate = null;
      await future;

      expect(port.captures, 1);
      expect(controller.state, BracketState.stopped);
      expect(port.writes.last, 3);
    });
  });

  group('焦点堆叠', () {
    test('张数到步长到张数换算', () {
      expect(stepForSpan(90, 10), 10);
      expect(shotsForSpan(90, 10), 10);
      expect(stepForSpan(0, 10), 1);
      expect(shotsForSpan(90, 0), 1);
    });

    test('按张数推进并在每张前拍一次', () async {
      final port = _FakeFocusPort();
      final controller = FocusStackingController(port: port);

      final ok = await controller.start(const FocusStackConfig(
        shotCount: 5,
        step: 16,
      ));

      expect(ok, isTrue);
      expect(port.captures, 5);
      expect(port.moves, 4, reason: '最后一张之后不再推进');
      expect(controller.state, FocusStackState.completed);
    });

    test('到达对焦行程尽头时提前结束而不是拍重复画面', () async {
      final port = _FakeFocusPort(maxMoves: 2);
      final controller = FocusStackingController(port: port);

      await controller.start(const FocusStackConfig(shotCount: 10, step: 32));

      expect(port.captures, lessThan(10));
      expect(controller.hitFocusEnd, isTrue);
      expect(controller.state, FocusStackState.completed);
    });

    test('连续两张没拍到就中止，不再空推焦点', () async {
      final port = _FakeFocusPort(missCaptures: true);
      final controller = FocusStackingController(port: port);

      await controller.start(const FocusStackConfig(shotCount: 10, step: 16));

      expect(controller.state, FocusStackState.failed);
      expect(controller.captureFailed, isTrue);
      expect(port.captures, 2, reason: '第二张失败后立即停止');
      expect(port.moves, lessThanOrEqualTo(1));
    });

    test('returnToStart 把对焦环退回起点', () async {
      final port = _FakeFocusPort();
      final controller = FocusStackingController(port: port);

      await controller.start(const FocusStackConfig(
        shotCount: 4,
        step: 10,
        returnToStart: true,
      ));

      // 3 次前进 + 1 次回退
      expect(port.moves, 4);
    });
  });
}
