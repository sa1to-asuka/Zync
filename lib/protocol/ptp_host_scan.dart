import 'dart:async';
import 'dart:io';

/// 在手机所在的 /24 网段里并发探测 PTP/IP 端口。
///
/// 相机不一定广播 `_ptp._tcp`（尤其手机热点或开了 AP 隔离的路由器），
/// 所以「自动查找」在 mDNS 之外再用端口扫描兜底：只有相机会监听 15740。
Future<List<String>> scanPtpHosts(
  String localIp, {
  int port = 15740,
  Duration timeout = const Duration(milliseconds: 350),
  int concurrency = 48,
}) async {
  final parts = localIp.trim().split('.');
  if (parts.length != 4) return const <String>[];
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  final c = int.tryParse(parts[2]);
  if (a == null || b == null || c == null) return const <String>[];

  final prefix = '$a.$b.$c';
  final hosts = <String>[
    for (var i = 1; i <= 254; i++)
      if ('$prefix.$i' != localIp.trim()) '$prefix.$i',
  ];
  if (hosts.isEmpty) return const <String>[];

  final found = <String>[];
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next;
      next++;
      if (index >= hosts.length) return;
      final host = hosts[index];
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.destroy();
        found.add(host);
      } catch (_) {
        // 端口关闭 / 主机不存在都算未命中。
      }
    }
  }

  final workers = concurrency.clamp(1, 128);
  await Future.wait(List.generate(workers, (_) => worker()));
  found.sort((x, y) => _ipToInt(x).compareTo(_ipToInt(y)));
  return found;
}

/// 在多个本地 IPv4 所属的 `/24` 网段中并发探测 PTP/IP 端口，并优先尝试已知历史主机。
Future<List<String>> scanPtpSubnets(
  List<String> localIps, {
  List<String> preferredHosts = const <String>[],
  int port = 15740,
  Duration timeout = const Duration(milliseconds: 350),
  int concurrency = 48,
}) async {
  final ownIps = <String>{
    for (final ip in localIps)
      if (ip.trim().isNotEmpty) ip.trim(),
  };
  final prefixes = <String>{};
  for (final ip in ownIps) {
    final parts = ip.split('.');
    if (parts.length != 4) continue;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) continue;
    prefixes.add('$a.$b.$c');
  }

  final orderedTargets = <String>[];
  final seen = <String>{};

  for (final preferred in preferredHosts) {
    final h = preferred.trim();
    if (h.isEmpty || ownIps.contains(h)) continue;
    final parts = h.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      if (seen.add(h)) orderedTargets.add(h);
    }
  }

  for (final prefix in prefixes) {
    for (var i = 1; i <= 254; i++) {
      final candidate = '$prefix.$i';
      if (ownIps.contains(candidate)) continue;
      if (seen.add(candidate)) orderedTargets.add(candidate);
    }
  }

  if (orderedTargets.isEmpty) return const <String>[];

  final found = <String>[];
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next;
      next++;
      if (index >= orderedTargets.length) return;
      final host = orderedTargets[index];
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        socket.destroy();
        found.add(host);
      } catch (_) {}
    }
  }

  final workers = concurrency.clamp(1, 128);
  await Future.wait(List.generate(workers, (_) => worker()));
  found.sort((x, y) => _ipToInt(x).compareTo(_ipToInt(y)));
  return found;
}

int _ipToInt(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return 0;
  return (int.tryParse(parts[0]) ?? 0) << 24 |
      (int.tryParse(parts[1]) ?? 0) << 16 |
      (int.tryParse(parts[2]) ?? 0) << 8 |
      (int.tryParse(parts[3]) ?? 0);
}
