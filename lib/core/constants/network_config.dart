/// 相机底层网络与 PTP/IP 握手配置
class NetworkConfig {
  NetworkConfig._();

  static String cameraIp = '192.168.0.1';
  static int cameraPort = 15740;
  static bool autoBindNetwork = true;
}
