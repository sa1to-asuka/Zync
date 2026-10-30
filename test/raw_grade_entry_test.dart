import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zync/core/utils/lru_image_cache.dart';
import 'package:zync/l10n/app_localizations.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/ui/design/theme.dart';
import 'package:zync/ui/screens/gallery_screen.dart';

import 'download_integrity_test.dart' show FakeDriver;

Uint8List _pngBytes() {
  final image = img.Image(width: 8, height: 8);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      image.setPixelRgb(x, y, 120, 130, 140);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('带 RAW 的照片组会显示「RAW 调色」并触发回调', (tester) async {
    final raw = CameraFileItem(
      handle: 0x2001,
      storageId: 1,
      format: 0x3801,
      size: 4096,
      fileName: 'DSC_0100.NEF',
      captureDate: '2026.10.11 10:00',
    );
    final group = CameraMediaGroup(baseName: 'DSC_0100', rawItem: raw);
    final driver = FakeDriver(payload: _pngBytes());

    CameraMediaGroup? opened;
    await tester.pumpWidget(MaterialApp(
      theme: ZyncTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: FullScreenPhotoViewer(
        groups: [group],
        initialIndex: 0,
        thumbCache: LruImageCache(maxEntries: 4),
        fullCache: LruImageCache(maxEntries: 4),
        driver: driver,
        resolveThumb: (_) async => _pngBytes(),
        onOpenProfessionalRaw: (g) => opened = g,
      ),
    ));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
    }

    final button = find.text('RAW 调色');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();

    expect(opened, same(group));
  });
}
