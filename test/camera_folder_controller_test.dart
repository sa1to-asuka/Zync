import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/camera_folder_controller.dart';

class _FakeFolderDriver implements CameraFolderDriver {
  _FakeFolderDriver({this.folder = 100});

  int? folder;
  bool writable = true;
  bool connected = true;

  /// 写入后回读返回的值（模拟相机把编号吸附到已有文件夹）。
  int? readbackOverride;

  @override
  bool get isConnected => connected;

  @override
  Future<int?> readActiveFolder() async => folder;

  @override
  Future<void> writeActiveFolder(int folderNumber) async {
    if (!writable) throw StateError('只读');
    folder = readbackOverride ?? folderNumber;
  }
}

void main() {
  test('读取当前相机文件夹', () async {
    final driver = _FakeFolderDriver(folder: 105);
    final controller = CameraFolderController(driver: driver);

    await controller.refresh();

    expect(controller.currentFolder, 105);
  });

  test('同值写入成功即判定可写', () async {
    final driver = _FakeFolderDriver(folder: 100);
    final controller = CameraFolderController(driver: driver);
    await controller.refresh();

    expect(await controller.probeWritable(), isTrue);
    expect(controller.writable, isTrue);
    expect(driver.folder, 100, reason: '探测不应改变原值');
  });

  test('只读机身探测后不放开输入', () async {
    final driver = _FakeFolderDriver(folder: 100)..writable = false;
    final controller = CameraFolderController(driver: driver);
    await controller.refresh();

    expect(await controller.probeWritable(), isFalse);
    expect(controller.writable, isFalse);
  });

  test('设置文件夹并回读确认', () async {
    final driver = _FakeFolderDriver(folder: 100);
    final controller = CameraFolderController(driver: driver);

    expect(await controller.setFolder(205), isTrue);
    expect(controller.currentFolder, 205);
    expect(driver.folder, 205);
  });

  test('相机把编号吸附到别处时返回 false', () async {
    final driver = _FakeFolderDriver(folder: 100)
      ..readbackOverride = 100;
    final controller = CameraFolderController(driver: driver);

    expect(await controller.setFolder(205), isFalse);
    expect(controller.currentFolder, 100);
  });

  test('编号越界直接拒绝', () async {
    final driver = _FakeFolderDriver();
    final controller = CameraFolderController(driver: driver);

    expect(await controller.setFolder(99), isFalse);
    expect(await controller.setFolder(1000), isFalse);
    expect(driver.folder, 100);
  });

  test('未连接时不写入', () async {
    final driver = _FakeFolderDriver()..connected = false;
    final controller = CameraFolderController(driver: driver);

    expect(await controller.setFolder(200), isFalse);
    expect(await controller.probeWritable(), isFalse);
  });
}
