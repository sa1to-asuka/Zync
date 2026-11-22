import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/utils/ip_address.dart';

void main() {
  group('normalizeIpv4', () {
    test('去掉相机屏幕上的前导零', () {
      expect(normalizeIpv4('010.151.169.075'), '10.151.169.75');
      expect(normalizeIpv4('192.168.001.001'), '192.168.1.1');
      expect(normalizeIpv4(' 010.000.000.001 '), '10.0.0.1');
    });

    test('正常地址保持不变', () {
      expect(normalizeIpv4('10.151.169.75'), '10.151.169.75');
    });

    test('拒绝非法地址', () {
      expect(normalizeIpv4('999.1.2.3'), isNull);
      expect(normalizeIpv4('10.1.2'), isNull);
      expect(normalizeIpv4('10..1.2'), isNull);
      expect(normalizeIpv4(''), isNull);
      expect(normalizeIpv4('abc.def.ghi.jkl'), isNull);
    });
  });
}
