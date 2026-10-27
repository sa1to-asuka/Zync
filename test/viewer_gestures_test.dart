import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/ui/design/theme.dart';
import 'package:zync/core/utils/lru_image_cache.dart';
import 'package:zync/engine/transfer/export_history_manager.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

/// 两张照片的假驱动，供相机查看器使用。
class _TwoItemDriver extends FakeDriver {
  _TwoItemDriver() : super(payload: _pngBytes());

  final List<CameraFileItem> items = [
    CameraFileItem(
      handle: 0x1001,
      storageId: 1,
      format: 0x3801,
      size: 4096,
      fileName: 'DSC_0001.JPG',
      captureDate: '2026.10.11 10:00',
    ),
    CameraFileItem(
      handle: 0x1002,
      storageId: 1,
      format: 0x3801,
      size: 4096,
      fileName: 'DSC_0002.JPG',
      captureDate: '2026.10.11 10:01',
    ),
  ];

  @override
  Future<List<int>> listObjectHandles([int? storageId]) async =>
      items.map((e) => e.handle).toList();

  @override
  Future<CameraFileItem?> getObjectInfo(int handle) async {
    for (final e in items) {
      if (e.handle == handle) return e;
    }
    return null;
  }

  @override
  Future<Uint8List> getThumbnail(int handle) async => _pngBytes();
}

Uint8List _pngBytes() {
  final image = img.Image(width: 40, height: 60);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(x, y, 180, 90, 40);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// 有界推进真实异步（图片解码）+ 帧，替代会卡死的 pumpAndSettle。
Future<void> _settle(WidgetTester tester, [int rounds = 40]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump();
  }
}

/// 记录发生了多少次 route pop，用来精确断言「没有触发返回」。
class _PopObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}

/// 打开查看器的宿主页，用于断言 route 是否被 pop。
class _Host extends StatelessWidget {
  const _Host({required this.viewer});

  final Widget viewer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => viewer)),
          child: const Text('打开大图'),
        ),
      ),
    );
  }
}

/// 读取当前页 InteractiveViewer 的缩放倍数。
double _scale(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer).first)
    .transformationController!
    .value
    .getMaxScaleOnAxis();

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.pump();
}

void main() {
  late Directory dir;
  late List<ExportedMediaItem> items;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('zync_gesture_');
    items = [
      for (var i = 1; i <= 2; i++)
        (() {
          final file = File('${dir.path}/photo_$i.png')
            ..writeAsBytesSync(_pngBytes());
          return ExportedMediaItem(
            file: file,
            fileName: 'photo_$i.png',
            baseName: 'PHOTO_$i',
            size: file.lengthSync(),
            modifiedTime: DateTime(2026, 10, 14),
          );
        })(),
    ];
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Widget localViewer() => MaterialApp(
        theme: ZyncTheme.lightTheme,
        home: _Host(viewer: FullScreenLocalImageViewer(items: items, initialIndex: 0)),
      );

  testWidgets('双击放大到 2.2×，再次双击回到 1×', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localViewer());
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);

    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    expect(_scale(tester), closeTo(1.0, 0.01), reason: '初始不应放大');

    await _doubleTapAt(tester, center);
    expect(_scale(tester), greaterThan(2.0), reason: '双击应放大到 2.2×');

    await _doubleTapAt(tester, center);
    expect(_scale(tester), closeTo(1.0, 0.01), reason: '再次双击应还原');
    expect(tester.takeException(), isNull);
  });

  testWidgets('未放大时水平滑动仍能翻到下一张', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localViewer());
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.fling(
        find.byType(InteractiveViewer).first, const Offset(-320, 0), 1200);
    await _settle(tester, 20);

    expect(find.text('2 / 2'), findsOneWidget,
        reason: '未放大时水平滑动必须仍然翻页');
    expect(tester.takeException(), isNull);
  });

  testWidgets('未放大时向下拖超过阈值会关闭查看器', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localViewer());
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);
    expect(find.byType(FullScreenLocalImageViewer), findsOneWidget);

    await tester.timedDrag(find.byType(InteractiveViewer).first,
        const Offset(0, 200), const Duration(milliseconds: 300));
    await _settle(tester, 20);

    expect(find.byType(FullScreenLocalImageViewer), findsNothing,
        reason: '下拉 200dp 应关闭大图');
    expect(find.text('打开大图'), findsOneWidget, reason: '应回到宿主页');
    expect(tester.takeException(), isNull);
  });

  testWidgets('未放大时向下拖不足阈值不会关闭查看器', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localViewer());
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);

    await tester.timedDrag(find.byType(InteractiveViewer).first,
        const Offset(0, 60), const Duration(milliseconds: 300));
    await _settle(tester, 20);

    expect(find.byType(FullScreenLocalImageViewer), findsOneWidget,
        reason: '轻拖应回弹而不是关闭');
    expect(tester.takeException(), isNull);
  });

  testWidgets('放大后向下拖动是平移图片，不会关闭查看器', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(localViewer());
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);

    await _doubleTapAt(
        tester, tester.getCenter(find.byType(InteractiveViewer).first));
    expect(_scale(tester), greaterThan(2.0));

    await tester.timedDrag(find.byType(InteractiveViewer).first,
        const Offset(0, 200), const Duration(milliseconds: 300));
    await _settle(tester, 20);

    expect(find.byType(FullScreenLocalImageViewer), findsOneWidget,
        reason: '放大状态下下拉应平移图片而不是关闭');
    expect(tester.takeException(), isNull);
  });

  testWidgets('双指缩放不会触发返回（回归：一放大就退出）', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final observer = _PopObserver();
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      navigatorObservers: [observer],
      home: _Host(
          viewer: FullScreenLocalImageViewer(items: items, initialIndex: 0)),
    ));
    await tester.tap(find.text('打开大图'));
    await _settle(tester, 20);
    expect(find.byType(FullScreenLocalImageViewer), findsOneWidget);

    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    final g1 = await tester.startGesture(center - const Offset(60, 0), pointer: 1);
    final g2 = await tester.startGesture(center + const Offset(60, 0), pointer: 2);
    await tester.pump();

    // 双指张开：真实捏合放大
    await g1.moveBy(const Offset(-60, 0));
    await g2.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(_scale(tester), greaterThan(1.0), reason: '双指张开应放大');

    // 继续带明显向下分量移动：旧实现会在这里把两指位移误判成下拉关闭
    await g1.moveBy(const Offset(0, 160));
    await g2.moveBy(const Offset(0, 160));
    await tester.pump();

    await g1.up();
    await g2.up();
    await tester.pump();
    await _settle(tester, 20);

    expect(observer.pops, 0,
        reason: '双指缩放 / 双指平移绝不能触发返回上一级');
    expect(find.byType(FullScreenLocalImageViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('相机查看器可以一键导出当前这张', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final driver = _TwoItemDriver();
    final exported = <CameraMediaGroup>[];

    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: FullScreenPhotoViewer(
        groups: [
          CameraMediaGroup(baseName: 'DSC_0001', jpegItem: driver.items[0]),
          CameraMediaGroup(baseName: 'DSC_0002', jpegItem: driver.items[1]),
        ],
        initialIndex: 0,
        thumbCache: LruImageCache(),
        fullCache: LruImageCache(),
        driver: driver,
        resolveThumb: (file) => driver.getThumbnail(file.handle),
        onExportSingle: exported.add,
      ),
    ));
    await _settle(tester, 20);

    final exportButton = find.byIcon(Icons.download_outlined);
    expect(exportButton, findsOneWidget, reason: '相机大图应提供「导出这张」入口');

    await tester.tap(exportButton);
    await tester.pump();

    expect(exported.length, 1, reason: 'onExportSingle 必须真的被调用');
    expect(exported.single.baseName, 'DSC_0001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('本地查看器不显示导出按钮（图片已在本地）', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      home: FullScreenLocalImageViewer(items: items, initialIndex: 0),
    ));
    await _settle(tester, 20);

    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
