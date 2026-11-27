import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/watermark/watermark_font_manager.dart';

void main() {
  group('WatermarkFontManager 云端商店与完整性校验', () {
    test('candidateUrlsFor 生成 GitHub 直连与国内镜像回退候选列表', () {
      final urls = WatermarkFontManager.candidateUrlsFor(
        'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/manifest.json',
      );
      expect(urls.length, greaterThanOrEqualTo(2));
      expect(urls.first.host, 'github.com');
      expect(urls.any((u) => u.host == 'ghfast.top'), isTrue);
    });

    test('parseManifestJson 解析合规字体条目', () {
      final jsonStr = jsonEncode({
        'version': 1,
        'fonts': [
          {
            'id': 'ma_shan_zheng',
            'family': 'ZyncMaShanZheng',
            'displayName': '马善政毛笔楷书',
            'category': 'chinese_calligraphy',
            'license': 'SIL OFL-1.1',
            'fileName': 'MaShanZheng-Regular.ttf',
            'sizeBytes': 12345,
            'sha256': 'abcd',
            'downloadUrl':
                'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/MaShanZheng-Regular.ttf',
          },
        ],
      });
      final entries = WatermarkFontManager.parseManifestJson(jsonStr);
      expect(entries.length, 1);
      expect(entries.first.id, 'ma_shan_zheng');
      expect(entries.first.source, WatermarkFontSource.cloudStore);
    });

    test('downloadFont 校验 TTF 魔数与 SHA-256 并在不匹配时拒绝写入', () async {
      final tmp = await Directory.systemTemp.createTemp('zync_font_test_');
      try {
        final fakeTtf = Uint8List.fromList([
          0x00, 0x01, 0x00, 0x00, // sfnt TTF magic
          ...List<int>.filled(64, 0x42),
        ]);
        final goodHash = sha256.convert(fakeTtf).toString();
        final entry = WatermarkFontEntry(
          id: 'test_cloud_font',
          family: 'ZyncTestFont',
          displayName: 'Test Font',
          category: 'chinese_art',
          source: WatermarkFontSource.cloudStore,
          fileName: 'TestFont.ttf',
          sha256: goodHash,
          downloadUrl:
              'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/TestFont.ttf',
        );

        final badEntry = WatermarkFontEntry(
          id: 'bad_font',
          family: 'BadFont',
          displayName: 'Bad',
          category: 'chinese_art',
          source: WatermarkFontSource.cloudStore,
          fileName: 'Bad.ttf',
          sha256: '00000000',
          downloadUrl:
              'https://github.com/sa1to-asuka/Zync/releases/download/fonts-v1/Bad.ttf',
        );

        Future<Uint8List> mockTransport(
          Uri url, {
          void Function(int received, int total)? onProgress,
        }) async {
          onProgress?.call(fakeTtf.length, fakeTtf.length);
          return fakeTtf;
        }

        await expectLater(
          WatermarkFontManager.instance.downloadFont(
            badEntry,
            transport: mockTransport,
            overrideDirectory: tmp,
          ),
          throwsStateError,
        );

        await WatermarkFontManager.instance.downloadFont(
          entry,
          transport: mockTransport,
          overrideDirectory: tmp,
        );
        expect(
          await File('${tmp.path}/fonts_store/TestFont.ttf').exists(),
          isTrue,
        );
      } finally {
        await tmp.delete(recursive: true);
      }
    });
  });
}
