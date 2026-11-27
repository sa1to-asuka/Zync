import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/engine/ai/ai_camera_coach.dart';
import 'package:zync/engine/ai/ai_color_grader.dart';
import 'package:zync/engine/ai/ai_provider_config.dart';
import 'package:zync/engine/picture_control/picture_control_store.dart';
import 'package:zync/l10n/l10n.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/capture/ai_coach_overlay.dart';
import 'package:zync/ui/screens/watermark/ai_grade_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('zync_pc_store_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tmpDir.path);
    await PictureControlStore.instance.ensureInitialized();
  });

  tearDownAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  group('AiCameraCoach & NP3 真实库防幻觉校验', () {
    test('fromJson 过滤幻觉编造的 NP3 ID，仅保留真实存在配方', () {
      final catalog = PictureControlStore.instance.items;
      expect(catalog, isNotEmpty);
      final realId = catalog.first.id;

      final result = AiCameraCoachResult.fromJson(
        {
          'compositionScore': 88,
          'exposureScore': 82,
          'sceneSummary': '日落港湾风光',
          'guideType': 'golden_spiral',
          'subjectBox': [0.2, 0.3, 0.3, 0.4],
          'targetPoint': [0.618, 0.382],
          'np3Matches': [
            {
              'recipeId': 'non_existent_hallucinated_id',
              'matchScore': 99,
              'reason': 'fake'
            },
            {'recipeId': realId, 'matchScore': 91, 'reason': '真实库匹配'},
          ],
        },
        catalog: catalog,
        sceneHint: '日落风光',
      );

      expect(result.guideType, CompositionGuideType.goldenSpiral);
      expect(result.subjectBox, const Rect.fromLTWH(0.2, 0.3, 0.3, 0.4));
      expect(
        result.np3Matches
            .any((m) => m.recipeId == 'non_existent_hallucinated_id'),
        isFalse,
      );
      expect(result.np3Matches.any((m) => m.recipeId == realId), isTrue);
    });

    test('analyzeOfflineFallback 对真实编码 JPEG 进行直方图与重心估算并推荐 NP3', () {
      final catalog = PictureControlStore.instance.items;

      final canvas = img.Image(width: 64, height: 48);
      img.fill(canvas, color: img.ColorRgb8(245, 240, 235));
      img.fillRect(
        canvas,
        x1: 20,
        y1: 12,
        x2: 40,
        y2: 36,
        color: img.ColorRgb8(40, 60, 80),
      );
      final jpeg = Uint8List.fromList(img.encodeJpg(canvas, quality: 85));

      final coach = AiCameraCoach.analyzeOfflineFallback(
        jpeg,
        np3Catalog: catalog,
        sceneIntent: '风景',
        localeCode: 'zh',
      );

      expect(coach.isOfflineFallback, isTrue);
      expect(coach.exposureScore, inInclusiveRange(45, 95));
      expect(coach.np3Matches, isNotEmpty);
      expect(coach.np3Matches.first.resolvedItem, isNotNull);
      expect(coach.cropRecommendation, isNotNull);
      expect(coach.shootingTips, isNotEmpty);
      expect(coach.sceneSummary, isNot(contains('Highlight clipping')));
      expect(coach.cropRecommendation!.subjectTitle, isNot(contains('High-Contrast')));
    });

    test('fromJson 解析主体裁切框、横竖屏比例与场景化拍摄技巧并钳制越界坐标', () {
      final catalog = PictureControlStore.instance.items;
      final res = AiCameraCoachResult.fromJson(
        {
          'compositionScore': 92,
          'exposureScore': 86,
          'sceneSummary': '杂乱街头中的逆光自行车剪影',
          'guideType': 'rule_of_thirds',
          'cropRecommendation': {
            'cropBox': [0.35, 0.12, 0.45, 0.72],
            'orientation': 'portrait',
            'aspectRatio': '2:3',
            'subjectTitle': '逆光骑行剪影',
            'framingReason': '裁掉左侧杂乱广告牌，保留竖构图长影与光斑',
          },
          'shootingTips': [
            {
              'category': 'timing',
              'title': '等待亮色行人入画',
              'detail': '等穿浅色或亮黄色外套的路人走入右下交点再按下快门',
            },
            {
              'category': 'lighting',
              'title': '面向 45 度侧逆光',
              'detail': '人物微侧面向窗外/夕阳形成轮廓光',
            },
          ],
          'np3Matches': [
            {'recipeId': catalog.first.id, 'matchScore': 90, 'reason': '匹配'},
          ],
        },
        catalog: catalog,
        sceneHint: '街拍',
      );

      expect(res.cropRecommendation, isNotNull);
      expect(res.cropRecommendation!.isPortrait, isTrue);
      expect(res.cropRecommendation!.aspectRatio, '2:3');
      expect(res.cropRecommendation!.subjectTitle, '逆光骑行剪影');
      expect(
        res.effectiveCropRect,
        const Rect.fromLTWH(0.35, 0.12, 0.45, 0.72),
      );
      expect(res.shootingTips.length, 2);
      expect(res.shootingTips.first.category, AiTipCategory.timing);
      expect(res.shootingTips.last.category, AiTipCategory.lighting);
    });
  });

  group('AI 构图 AR 叠加与 AI 调色弹窗多端三语适配', () {
    testWidgets('AiCompositionOverlay 与 AiViewfinderTipBanner 渲染裁切框与比例标签',
        (tester) async {
      final ctrl = AiCoachController();
      addTearDown(ctrl.dispose);

      ctrl.updateResult(
        const AiCameraCoachResult(
          compositionScore: 90,
          exposureScore: 88,
          sceneSummary: '街道逆光',
          targetPoint: Offset(0.66, 0.66),
          horizonTiltDeg: 3.5,
          cropRecommendation: AiCropRecommendation(
            cropBox: Rect.fromLTWH(0.2, 0.1, 0.45, 0.75),
            orientation: 'portrait',
            aspectRatio: '2:3',
            subjectTitle: '逆光行人',
            framingReason: '去掉杂乱路牌',
          ),
          shootingTips: [
            AiShootingTip(
              category: AiTipCategory.timing,
              title: '等亮色衣物路人经过',
              detail: '走到右侧三分线交点按快门',
            ),
          ],
        ),
        frameSize: const Size(640, 480),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ZyncTheme.darkTheme,
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                AiCompositionOverlay(controller: ctrl),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AiViewfinderTipBanner(
                    result: ctrl.result!,
                    onOpenCoach: () {},
                    onClose: ctrl.clear,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('竖屏 2:3'), findsOneWidget);
      expect(find.text('等亮色衣物路人经过'), findsOneWidget);
    });

    testWidgets('AiGradeSheet 在手机与平板尺寸及中日英三语下无溢出并禁止静默伪装离线结果',
        (tester) async {
      final tmp = await tester.runAsync(
          () => Directory.systemTemp.createTemp('zync_ai_grade_ui_'));
      addTearDown(() async {
        try {
          if (tmp != null && tmp.existsSync()) tmp.deleteSync(recursive: true);
        } catch (_) {}
      });
      await tester.runAsync(() async {
        await AiSettingsStore.instance.ensureInitialized(overrideDirectory: tmp);
      });

      final tinyImg = img.Image(width: 16, height: 12);
      img.fill(tinyImg, color: img.ColorRgb8(120, 150, 190));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(tinyImg, quality: 80));

      for (final cfg in const [
        (locale: Locale('zh'), size: Size(390, 844)),
        (locale: Locale('en'), size: Size(1024, 768)),
        (locale: Locale('ja'), size: Size(1024, 768)),
      ]) {
        tester.view.physicalSize = cfg.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: cfg.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ZyncTheme.lightTheme,
            home: Scaffold(
              body: AiGradeSheet(
                imageBytes: jpgBytes,
                stats: const ImageColorStats(
                  avgLuma: 0.5,
                  shadowFraction: 0.1,
                  highlightFraction: 0.1,
                  dynamicSpread: 0.6,
                  warmBias: 0,
                  greenTint: 0,
                  avgSaturation: 0.3,
                ),
                onPreviewPayload: (_) {},
                onSavePreset: (_, __) async {},
                isDialog: cfg.size.width >= 640,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // 未配置 AI 时，不应悄悄显示「本地直方图智能方案」离线标签伪装成功
        expect(find.text('本地直方图智能方案'), findsNothing);
      }
    });
  });
}
