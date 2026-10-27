import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/open_source_credits.dart';

void main() {
  test('开源致谢条目具备名称、说明、许可证与有效 GitHub 地址', () {
    expect(openSourceCredits, isNotEmpty);
    final urls = <String>{};

    for (final credit in openSourceCredits) {
      expect(credit.name.trim(), isNotEmpty);
      expect(credit.description.trim(), isNotEmpty);
      expect(credit.license.trim(), isNotEmpty);
      expect(credit.url, startsWith('https://github.com/'));
      expect(urls.add(credit.url), isTrue, reason: '重复地址: ${credit.url}');
    }
  });

  test('重点感谢项目与许可证记录正确', () {
    final byName = {
      for (final credit in openSourceCredits) credit.name: credit
    };

    expect(
        byName['ImageToolbox']?.url, 'https://github.com/T8RIN/ImageToolbox');
    expect(byName['ImageToolbox']?.license, 'Apache-2.0');

    expect(byName['Recipe Lab']?.url,
        'https://github.com/voxivoid/recipe-lab-sony-pmca');
    expect(byName['Recipe Lab']?.license, 'GPL-3.0');

    expect(byName['SnapBridge-Enhanced']?.url,
        'https://github.com/MXWF0/SnapBridge-Enhanced');
    expect(byName['SnapBridge-Enhanced']?.license, '未声明许可证');

    expect(byName['nsg']?.url, 'https://github.com/hurui200320/nsg');
    expect(byName['nsg']?.license, 'AGPL-3.0');

    expect(byName['furble']?.url, 'https://github.com/gkoh/furble');
    expect(byName['furble']?.license, 'MIT');

    expect(byName['semi-utils']?.url, 'https://github.com/leslievan/semi-utils');
    expect(byName['semi-utils']?.license, 'Apache-2.0');

    expect(byName['Copicseal (可图匠)']?.url,
        'https://github.com/copicseal/copicseal');
    expect(byName['Copicseal (可图匠)']?.license, 'Apache-2.0');

    expect(byName['PicSeal']?.url, 'https://github.com/pipiqiang/PicSeal');
    expect(byName['PicSeal']?.license, 'MIT');

    expect(byName['camera-watermark']?.url,
        'https://github.com/myWsq/camera-watermark');
    expect(byName['camera-watermark']?.license, 'MIT');
  });
}
