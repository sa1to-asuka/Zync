import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/picture_control/builtin_np3_recipes.dart';
import 'package:zync/engine/picture_control/np3_codec.dart';
import 'package:zync/engine/picture_control/picture_control_store.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/picture_control_screen.dart';

Uint8List _fakeJpeg(int seedByte, {int size = 12 * 1024}) {
  final bytes = Uint8List(size);
  bytes[0] = 0xFF;
  bytes[1] = 0xD8;
  bytes[2] = 0xFF;
  bytes[3] = 0xE0;
  for (var i = 4; i < size - 2; i++) {
    bytes[i] = (seedByte + i) & 0xFF;
  }
  bytes[size - 2] = 0xFF;
  bytes[size - 1] = 0xD9;
  return bytes;
}

Widget _app(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
      theme: ZyncTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: child,
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zync_pc_v31_');
    PictureControlStore.debugSampleTransport = null;
    await PictureControlStore.instance.ensureInitialized(
      overrideDirectory: tempDir,
    );
  });

  tearDown(() async {
    PictureControlStore.debugSampleTransport = null;
    if (tempDir.existsSync()) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('11 个样片场景支持三语且「自然」不与中性风格冲突', () {
    expect(BuiltinNp3Catalog.sampleScenes.length, 11);
    final nature =
        BuiltinNp3Catalog.sampleScenes.firstWhere((s) => s.id == 'nature');
    expect(nature.localizedLabel('zh'), '自然');
    expect(nature.localizedLabel('en'), 'Nature');
    expect(nature.localizedLabel('ja'), '自然');

    final sunset =
        BuiltinNp3Catalog.sampleScenes.firstWhere((s) => s.id == 'sunset');
    final starry =
        BuiltinNp3Catalog.sampleScenes.firstWhere((s) => s.id == 'starry');
    expect(sunset.localizedLabel('en'), 'Sunset');
    expect(starry.localizedLabel('en'), 'Starry Sky');

    // 验证全部 11 张云端样片均为标准 JPEG 且与 manifest.json 及内置 SHA-256 严格一致
    final manifestFile = File('cloud_assets/pc_preview/manifest.json');
    expect(manifestFile.existsSync(), isTrue);
    final manifestJson =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final manifestScenes =
        (manifestJson['scenes'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(manifestScenes.length, 11);

    for (final scene in BuiltinNp3Catalog.sampleScenes) {
      expect(scene.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      final jpgFile = File('cloud_assets/pc_preview/${scene.fileName}');
      expect(jpgFile.existsSync(), isTrue, reason: '${scene.fileName} 必须存在');
      final bytes = jpgFile.readAsBytesSync();
      expect(bytes.length, greaterThan(8 * 1024));
      expect(bytes[0], 0xFF);
      expect(bytes[1], 0xD8);
      expect(bytes[2], 0xFF);
      final actualSha = sha256.convert(bytes).toString();
      expect(scene.sha256, equals(actualSha));
      final mEntry = manifestScenes.firstWhere((e) => e['id'] == scene.id);
      expect(mEntry['sha256'], equals(actualSha));
      expect(mEntry['revision'], equals(scene.revision));
      expect(mEntry['sizeBytes'], equals(bytes.length));
    }
  });

  test('云端样片缓存：自动淘汰旧版无元数据缓存，支持版本更新与镜像回退', () async {
    final store = PictureControlStore.instance;
    final sampleDir = Directory('${tempDir.path}/picture_controls/samples')
      ..createSync(recursive: true);
    // 模拟 3.0.x 遗留缓存：无 samples_meta.json 的旧版 portrait.jpg
    final legacyBytes = _fakeJpeg(1);
    await File('${sampleDir.path}/portrait.jpg').writeAsBytes(legacyBytes);

    final newBytes = _fakeJpeg(99);
    final newSha = sha256.convert(newBytes).toString();
    var requestedUrls = <String>[];
    PictureControlStore.debugSampleTransport = (uri) async {
      requestedUrls.add(uri.toString());
      // 第 1 个直链失败，自动切到 jsDelivr 镜像成功返回
      if (uri.host == 'raw.githubusercontent.com') return null;
      return newBytes;
    };

    final portraitScene = PictureControlSampleScene(
      id: 'portrait',
      fileName: 'portrait.jpg',
      revision: 2,
      sha256: newSha,
      labelZh: '人像',
      labelEn: 'Portrait',
      labelJa: 'ポートレート',
      sourceName: 'Test',
    );
    final loaded = await store.loadSampleSceneBytes(portraitScene);
    expect(loaded, equals(newBytes));
    expect(requestedUrls.length, greaterThanOrEqualTo(2));

    // 二次读取命中本地持久化缓存与元数据，不再触发网络请求
    requestedUrls.clear();
    final cachedAgain = await store.loadSampleSceneBytes(portraitScene);
    expect(cachedAgain, equals(newBytes));
    expect(requestedUrls, isEmpty);

    // 远端 manifest 升级版本号 + 新 SHA-256 时，自动作废旧缓存并通知刷新
    final hotBytes = _fakeJpeg(77);
    final hotSha = sha256.convert(hotBytes).toString();
    final prevVersion = store.sampleCacheVersion;
    PictureControlStore.debugSampleTransport = (uri) async {
      if (uri.path.endsWith('manifest.json')) {
        return Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'version': 2,
              'scenes': [
                {
                  'id': 'portrait',
                  'fileName': 'portrait.jpg',
                  'revision': 99,
                  'sha256': hotSha,
                },
              ],
            }),
          ),
        );
      }
      return hotBytes;
    };

    await store.refreshSampleManifestInBackground(force: true);
    expect(store.sampleCacheVersion, greaterThan(prevVersion));
    final refreshed = await store.loadSampleSceneBytes(portraitScene);
    expect(refreshed, equals(hotBytes));
  });

  test('1dlut-z30-filters 全部 121 套配方可正常解析、编码 NP3 且准确分类', () {
    final catalogFile = File('assets/recipes/z30_filters/catalog.json');
    expect(catalogFile.existsSync(), isTrue);

    final items = PictureControlStore.parseZ30FiltersCatalogJson(
      catalogFile.readAsStringSync(),
    );
    expect(items.length, 121);

    final validSceneIds =
        BuiltinNp3Catalog.sampleScenes.map((s) => s.id).toSet();
    final categories = <PictureControlCategory>{};

    for (final item in items) {
      expect(item.noteName, isNotEmpty);
      expect(item.category, isNot(PictureControlCategory.all));
      expect(validSceneIds.contains(item.recommendedSceneId), isTrue);
      expect(item.recipe.canWriteToCamera, isTrue);
      expect(item.recipe.hasCustomCurve, isTrue);
      expect(item.recipe.curveLut257.length, 257);

      final wire = Np3Codec.toWirePayload(item.recipe);
      expect(wire.length, Np3Codec.wireFullLength);
      final parsedBack = Np3Codec.fromWirePayload(wire);
      expect(parsedBack.cameraName, item.cameraName);
      categories.add(item.category);
    }

    // 应覆盖全部分类
    expect(categories.length, 8);
  });

  test('收藏与移除状态持久化，支持移除内置配方后随时恢复', () async {
    final store = PictureControlStore.instance;
    expect(store.items, isNotEmpty);
    final firstId = store.items.first.id;
    final secondId = store.items[1].id;

    expect(await store.toggleFavorite(firstId), isTrue);
    expect(store.isFavorite(firstId), isTrue);
    expect(store.favoriteCount, 1);

    await store.deleteItem(secondId);
    expect(store.items.any((e) => e.id == secondId), isFalse);

    // 重新初始化应保留收藏并维持已移除状态
    await store.ensureInitialized(overrideDirectory: tempDir);
    expect(store.isFavorite(firstId), isTrue);
    expect(store.items.any((e) => e.id == secondId), isFalse);

    // 恢复内置配方后，被移除的内置配方应回来
    await store.restoreBuiltInSeeds();
    expect(store.items.any((e) => e.id == secondId), isTrue);
  });

  testWidgets('UI：离线样片显示重试引导，收藏配方置顶并支持「我的收藏」筛选', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 模拟纯离线下载失败
    PictureControlStore.debugSampleTransport = (_) async => null;

    final driver = NikonDriver();
    addTearDown(driver.dispose);

    await tester.pumpWidget(_app(PictureControlScreen(driver: driver)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    // 离线提示与重试按钮可见
    expect(find.textContaining('暂未获取到云端样片'), findsOneWidget);
    expect(find.text('重试下载'), findsOneWidget);

    // 收藏筛选初始为空
    final favFilter = find.byKey(const ValueKey<String>('pc_filter_favorites'));
    expect(favFilter, findsOneWidget);
    await tester.tap(favFilter);
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无收藏配方'), findsOneWidget);

    // 切回「全部」，点击第二条配方的收藏星标
    await tester.tap(find.textContaining('全部').first);
    await tester.pumpAndSettle();
    final secondItem = PictureControlStore.instance.items[1];
    final favBtn = find.byKey(ValueKey<String>('pc_fav_${secondItem.id}'));
    expect(favBtn, findsOneWidget);
    await tester.tap(favBtn);
    await tester.pumpAndSettle();

    // 再次进入「我的收藏」，应显示已收藏的这一条
    await tester.tap(favFilter);
    await tester.pumpAndSettle();
    expect(find.text(secondItem.displayTitle), findsOneWidget);
  });
}
