import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/editor/color_grade_preset.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_models.dart';
import 'package:zync/engine/spektrafilm/spektrafilm_native.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/ui/design/design.dart';
import 'package:zync/ui/screens/watermark_screen.dart';

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(118, 126, 132));
  return Uint8List.fromList(img.encodeJpg(image));
}

Widget _app() => MaterialApp(
      theme: ZyncTheme.lightTheme,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WatermarkScreen(initialImageBytes: _png(48, 36)),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  setUp(() async {
    SpektrafilmNative.debugStocks = const [
      SpektraStockInfo(
        id: 'kodak_portra_400',
        name: 'Kodak Portra 400',
        targetPrint: 'kodak_portra_endura',
        use: 'still',
      ),
      SpektraStockInfo(
        id: 'kodak_vision3_500t',
        name: 'Kodak Vision3 500T',
        targetPrint: 'kodak_2383',
        use: 'cine',
      ),
    ];
    SpektrafilmNative.debugPapers = const [
      SpektraPaperInfo(
        id: 'kodak_portra_endura',
        name: 'Kodak Professional Portra Endura',
      ),
      SpektraPaperInfo(id: 'kodak_2383', name: 'Kodak Vision 2383'),
    ];
    final dir = await Directory.systemTemp.createTemp('zync_preset_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => dir.path,
    );
  });

  tearDown(() {
    SpektrafilmNative.debugStocks = null;
    SpektrafilmNative.debugPapers = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  testWidgets('水印工坊四栏顺序为 画框版式 / 预设调节 / 胶片模拟 / 裁切几何', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _settle(tester);

    const labels = ['画框版式', '预设调节', '胶片模拟', '裁切几何'];
    var previous = double.negativeInfinity;
    for (final label in labels) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '缺少 $label 栏');
      final dx = tester.getCenter(finder).dx;
      expect(dx, greaterThan(previous), reason: '$label 顺序不正确');
      previous = dx;
    }
  });

  testWidgets('胶片模拟：非 RAW 显示建议条，选中底片后接管预览', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(find.text('胶片模拟'));
    await _settle(tester);

    expect(find.text('建议使用 RAW 格式图片以获得最佳胶片模拟效果'), findsOneWidget);

    final portra = find.text('Kodak Portra 400');
    expect(portra, findsWidgets);
    await tester.tap(portra.first);
    await _settle(tester);

    // 选中后出现启用状态与关闭入口。
    expect(find.textContaining('Kodak Portra 400 · Kodak Professional Portra Endura'), findsOneWidget);
    expect(find.text('关闭胶片模拟'), findsOneWidget);
  });

  testWidgets('预设调节：应用预设会自动关闭胶片模拟', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await _settle(tester);

    await tester.tap(find.text('胶片模拟'));
    await _settle(tester);
    await tester.tap(find.text('Kodak Portra 400').first);
    await _settle(tester);
    expect(find.text('关闭胶片模拟'), findsOneWidget);

    await tester.tap(find.text('预设调节'));
    await _settle(tester);

    final preset = find.text('标准');
    expect(preset, findsWidgets);
    await tester.tap(preset.first);
    await _settle(tester);

    expect(find.text('已关闭胶片模拟，参数调节重新生效'), findsOneWidget);
    expect(find.text('关闭胶片模拟'), findsNothing);
  });

  test('用户预设支持重命名与删除', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final preset = ColorGradePreset(
      id: 'user_$now',
      name: '测试预设',
      createdAtMs: now,
      updatedAtMs: now,
    );
    await ColorGradePresetStore.upsert(preset);

    var presets = await ColorGradePresetStore.load();
    expect(presets.any((p) => p.id == preset.id), isTrue);

    presets = await ColorGradePresetStore.rename(preset.id, '重命名后');
    final renamed = presets.firstWhere((p) => p.id == preset.id);
    expect(renamed.name, '重命名后');

    presets = await ColorGradePresetStore.remove(preset.id);
    expect(presets.any((p) => p.id == preset.id), isFalse);
  });
}
