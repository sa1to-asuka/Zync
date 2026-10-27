import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/update/app_update_manager.dart';
import 'package:zync/core/settings/app_settings.dart';

void main() {
  test('AppUpdateManager.currentVersion 与 pubspec.yaml 保持一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)',
            multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml 必须包含 version: x.y.z+build');

    final versionName = match!.group(1)!;
    final versionCode = int.parse(match.group(2)!);

    expect(AppUpdateManager.currentVersion, equals(versionName),
        reason: '应用内更新检查的版本号必须与 pubspec.yaml 同步');
    expect(AppUpdateManager.currentVersionCode, equals(versionCode),
        reason: 'build number 必须与 pubspec.yaml 同步');
  });

  test('parseSha256 支持常见校验文件格式', () {
    final h = 'a' * 64;
    expect(AppUpdateManager.parseSha256(h), equals(h));
    expect(AppUpdateManager.parseSha256('$h  Zync-release.apk'), equals(h));
    expect(
        AppUpdateManager.parseSha256('$h *Zync-release.apk\n'), equals(h));
    expect(AppUpdateManager.parseSha256('not-a-hash'), equals(''));
  });

  test('更新后的设置默认值与实现保持一致', () {
    expect(AppSettings.defaultPowerThreshold, equals(15));
  });
}
