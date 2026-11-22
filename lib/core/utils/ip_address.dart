/// 把相机屏幕上常见的零填充地址（如 `010.151.169.075`）规范成十进制点分地址。
///
/// POSIX 的地址解析会把前导 0 当作八进制，直接把 `010` 传给 `Socket.connect`
/// 可能连到完全不同的主机，所以进入网络层之前必须先去掉前导零。
/// 返回 null 表示不是合法的 IPv4。
String? normalizeIpv4(String raw) {
  final parts = raw.trim().split('.');
  if (parts.length != 4) return null;
  final octets = <String>[];
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return null;
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) return null;
    octets.add(value.toString());
  }
  return octets.join('.');
}
