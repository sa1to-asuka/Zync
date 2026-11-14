/// 相机端文件夹操作所需的驱动能力。
abstract class CameraFolderDriver {
  bool get isConnected;

  /// 读 `0xD15B`，返回当前文件夹编号；读不到返回 null。
  Future<int?> readActiveFolder();

  /// 写 `0xD15B`；相机拒绝时抛异常。
  Future<void> writeActiveFolder(int folderNumber);
}

/// 相机存储卡上的文件夹。
///
/// 注意：Nikon 的 `ActiveFolder (0xD15B)` 在 libgphoto2 里标的是只读
/// （`_put_None`），libgphoto2 之外也没有找到可以新建文件夹的操作码。
/// 所以这里先做一次**同值写入探测**：只有相机真的接受写入才把界面放开，
/// 否则老老实实告诉用户去机身菜单里新建。
class CameraFolderController {
  CameraFolderController({required this.driver});

  final CameraFolderDriver driver;

  int? _current;
  int? get currentFolder => _current;

  /// null 表示尚未探测。
  bool? _writable;
  bool? get writable => _writable;

  bool get isConnected => driver.isConnected;

  Future<void> refresh() async {
    if (!driver.isConnected) {
      _current = null;
      _writable = null;
      return;
    }
    _current = await driver.readActiveFolder();
  }

  /// 探测是否允许第三方修改文件夹。
  ///
  /// 写入「当前值」本身是幂等的：相机接受就说明可写，拒绝则说明只读，
  /// 两种情况都不会改变机身上的任何设置。
  Future<bool> probeWritable() async {
    if (!driver.isConnected) {
      _writable = false;
      return false;
    }
    final current = _current ?? await driver.readActiveFolder();
    if (current == null) {
      _writable = false;
      return false;
    }
    try {
      await driver.writeActiveFolder(current);
      _writable = true;
    } catch (_) {
      _writable = false;
    }
    return _writable!;
  }

  /// 设置文件夹编号（Nikon 常见范围 100–999）。
  Future<bool> setFolder(int folderNumber) async {
    if (!driver.isConnected) return false;
    if (folderNumber < 100 || folderNumber > 999) return false;
    try {
      await driver.writeActiveFolder(folderNumber);
    } catch (_) {
      _writable = false;
      return false;
    }
    // 回读确认；相机可能把值吸附到已有文件夹。
    final readback = await driver.readActiveFolder();
    _current = readback ?? folderNumber;
    _writable = true;
    return _current == folderNumber;
  }
}
