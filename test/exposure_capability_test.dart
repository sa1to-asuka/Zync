import 'package:flutter_test/flutter_test.dart';
import 'package:zync/engine/capture/camera_property.dart';
import 'package:zync/engine/capture/exposure_capability.dart';

void main() {
  group('M 档', () {
    test('光圈 / 快门 / ISO / 曝光补偿都可写', () {
      for (final p in <CameraParameter>[
        CameraParameter.aperture,
        CameraParameter.shutter,
        CameraParameter.iso,
        CameraParameter.exposureCompensation,
      ]) {
        expect(isEditable(p, CameraExposureMode.manual), isTrue,
            reason: '$p 应可写');
      }
    });
  });

  group('A 档（用户的场景）', () {
    test('光圈与曝光补偿可写，快门与 ISO 被机身接管', () {
      expect(isEditable(CameraParameter.aperture, 3), isTrue);
      expect(isEditable(CameraParameter.exposureCompensation, 3), isTrue);
      expect(isEditable(CameraParameter.shutter, 3), isFalse);
      // 实测 Z 30 在 A 档下 ISO 是可写的；这里以前判错，把 ISO 一起锁了。
      expect(isEditable(CameraParameter.iso, 3), isTrue);
      expect(
        lockReasonFor(CameraParameter.shutter, 3),
        ExposureLockReason.bodyModeExcludes,
      );
    });

    test('lockedParameters 只列出真正被接管的参数', () {
      final locked = lockedParameters(3);
      expect(locked, contains(CameraParameter.shutter));
      expect(locked, isNot(contains(CameraParameter.iso)));
      expect(locked, isNot(contains(CameraParameter.aperture)));
      expect(locked, isNot(contains(CameraParameter.mode)));
    });
  });

  group('S 档', () {
    test('快门与 ISO 可写，光圈被机身接管', () {
      expect(isEditable(CameraParameter.shutter, 4), isTrue);
      expect(isEditable(CameraParameter.iso, 4), isTrue);
      expect(isEditable(CameraParameter.aperture, 4), isFalse);
    });
  });

  group('P 档', () {
    test('曝光补偿与 ISO 可写', () {
      expect(isEditable(CameraParameter.exposureCompensation, 2), isTrue);
      expect(isEditable(CameraParameter.iso, 2), isTrue);
      expect(isEditable(CameraParameter.aperture, 2), isFalse);
      expect(isEditable(CameraParameter.shutter, 2), isFalse);
    });
  });

  group('全自动', () {
    test('所有参数都不可写', () {
      for (final p in CameraParameter.values) {
        if (p == CameraParameter.mode) continue;
        expect(isEditable(p, CameraExposureMode.auto), isFalse);
        expect(lockReasonFor(p, CameraExposureMode.auto),
            ExposureLockReason.autoMode);
      }
    });
  });

  group('模式未知', () {
    test('允许尝试而不是全部锁死', () {
      expect(isEditable(CameraParameter.aperture, null), isTrue);
      expect(lockReasonFor(CameraParameter.aperture, null),
          ExposureLockReason.unknownMode);
    });
  });

  group('曝光模式本身', () {
    test('始终只读：本版本不主动改机身档位', () {
      for (final mode in <int?>[1, 2, 3, 4, 0x8010, null]) {
        expect(
          lockReasonFor(CameraParameter.mode, mode),
          ExposureLockReason.modeIsDisplayOnly,
          reason: 'mode=$mode',
        );
      }
    });
  });
}
