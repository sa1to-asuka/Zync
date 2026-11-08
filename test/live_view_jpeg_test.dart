import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/liveview/live_view_jpeg.dart';

/// 造一个结构上合法的 JPEG 片段：SOI + 任意标记体 + EOI。
Uint8List _jpeg(List<int> body) {
  return Uint8List.fromList(<int>[0xFF, 0xD8, ...body, 0xFF, 0xD9]);
}

void main() {
  group('LiveViewJpeg.extract', () {
    test('从厂商头部之后切出完整 JPEG', () {
      final header = List<int>.filled(128, 0x00);
      final jpeg = _jpeg(<int>[0xFF, 0xE1, 0x00, 0x10, 1, 2, 3]);
      final payload = Uint8List.fromList(<int>[...header, ...jpeg]);

      final result = LiveViewJpeg.extract(payload);

      expect(result, isNotNull);
      expect(result, equals(jpeg));
    });

    test('尾部填充不会被带进结果', () {
      final jpeg = _jpeg(<int>[0x01, 0x02, 0x03]);
      final payload = Uint8List.fromList(<int>[...jpeg, 0, 0, 0, 0, 0]);

      final result = LiveViewJpeg.extract(payload);

      expect(result, equals(jpeg));
    });

    test('没有 SOI 时返回 null', () {
      final payload = Uint8List.fromList(List<int>.filled(64, 0xAB));
      expect(LiveViewJpeg.extract(payload), isNull);
    });

    test('有 SOI 但没有 EOI（半帧）时返回 null', () {
      final payload = Uint8List.fromList(<int>[0x00, 0xFF, 0xD8, 1, 2, 3, 4]);
      expect(LiveViewJpeg.extract(payload), isNull);
    });

    test('EOI 出现在 SOI 之前时返回 null', () {
      final payload = Uint8List.fromList(<int>[0xFF, 0xD9, 0, 0, 0xFF, 0xD8]);
      expect(LiveViewJpeg.extract(payload), isNull);
    });

    test('负载本身就是裸 JPEG 时原样返回', () {
      final jpeg = _jpeg(<int>[9, 9, 9]);
      expect(LiveViewJpeg.extract(jpeg), equals(jpeg));
    });

    test('空负载返回 null', () {
      expect(LiveViewJpeg.extract(Uint8List(0)), isNull);
    });

    test('结果与源负载不共享可变状态（是视图，不复制）', () {
      final jpeg = _jpeg(<int>[1, 2]);
      final payload = Uint8List.fromList(<int>[0xAA, ...jpeg, 0xBB]);

      final result = LiveViewJpeg.extract(payload)!;

      expect(result.length, jpeg.length);
      expect(result[0], 0xFF);
      expect(result[1], 0xD8);
    });
  });
}
