import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/engine/transfer/download_manager.dart';
import 'package:zync/engine/transfer/keep_alive_arbiter.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/transfer_center_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 离线驱动：让任务停在「排队中」，不触发真实下载。
class _OfflineDriver extends FakeDriver {
  _OfflineDriver() : super(payload: Uint8List(0)) {
    state = CameraConnectionState.disconnected;
  }
}

CameraFileItem _item(int i) => CameraFileItem(
      handle: 0x1000 + i,
      storageId: 1,
      format: 0x3801,
      size: 1024 * 1024,
      fileName: 'DSC_000$i.JPG',
      captureDate: '2026.10.14 10:00',
    );

void main() {
  setUp(() => KeepAliveArbiter.instance.resetForTest());
  tearDown(() => KeepAliveArbiter.instance.resetForTest());

  testWidgets('传输中心：空态 → 入队 → 取消/移除 → 暂停全部', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final dm = DownloadManager(driver: _OfflineDriver());
    addTearDown(dm.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: TransferCenterScreen(manager: dm),
    ));

    // 空态
    expect(find.text('暂无传输任务'), findsOneWidget);

    dm.enqueueAll([_item(1), _item(2)]);
    await tester.pump();

    expect(find.text('DSC_0001.JPG'), findsOneWidget);
    expect(find.text('DSC_0002.JPG'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('排队 2'), findsOneWidget);

    // 单条取消
    await tester.tap(find.text('取消').first);
    await tester.pump();
    expect(find.textContaining('已取消'), findsOneWidget);

    // 移除终态任务
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(find.text('DSC_0001.JPG'), findsNothing);
    expect(find.text('DSC_0002.JPG'), findsOneWidget);

    // 暂停全部 / 继续
    await tester.tap(find.text('暂停全部'));
    await tester.pump();
    expect(dm.isManualPaused, isTrue);
    expect(find.text('继续全部'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
