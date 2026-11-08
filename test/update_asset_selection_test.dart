import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/update/app_update_manager.dart';

Map<String, dynamic> _json(List<Map<String, String>> assets) => <String, dynamic>{
      'tag_name': 'v2.5.0',
      'name': 'Zync 2.5.0',
      'body': 'notes',
      'assets': <Map<String, dynamic>>[
        for (final a in assets)
          <String, dynamic>{
            'name': a['name'],
            'browser_download_url': a['url'],
            'size': 100,
          },
      ],
    };

void main() {
  test('多个 APK 时优先选择正式包名，而不是第一个', () {
    final info = AppReleaseInfo.fromGitHubJson(_json(<Map<String, String>>[
      <String, String>{
        'name': 'Zync-release-2.5.0-armeabi-v7a.apk',
        'url': 'https://example.com/v7a',
      },
      <String, String>{
        'name': 'Zync-release-2.5.0.apk',
        'url': 'https://example.com/arm64',
      },
    ]));

    expect(info.downloadUrl, 'https://example.com/arm64');
  });

  test('只有 ABI 分包时退回到非 armeabi 的包', () {
    final info = AppReleaseInfo.fromGitHubJson(_json(<Map<String, String>>[
      <String, String>{
        'name': 'Zync-release-2.5.0-armeabi-v7a.apk',
        'url': 'https://example.com/v7a',
      },
      <String, String>{
        'name': 'Zync-release-2.5.0-arm64-v8a.apk',
        'url': 'https://example.com/arm64',
      },
    ]));

    expect(info.downloadUrl, 'https://example.com/arm64');
  });

  test('完全没有 APK 资产时回落到约定下载地址', () {
    final info = AppReleaseInfo.fromGitHubJson(_json(const <Map<String, String>>[]));

    expect(
      info.downloadUrl,
      'https://github.com/sa1to-asuka/Zync/releases/download/v2.5.0/Zync-release-2.5.0.apk',
    );
  });
}
