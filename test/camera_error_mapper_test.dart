import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/utils/camera_error_mapper.dart';
import 'package:zync/l10n/app_localizations_en.dart';
import 'package:zync/l10n/app_localizations_ja.dart';
import 'package:zync/l10n/app_localizations_zh.dart';
import 'package:zync/protocol/ptp_ip_client.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();
  final ja = AppLocalizationsJa();

  group('responseCodeOf', () {
    test('从 PtpException 取出响应码', () {
      expect(
        CameraErrorMapper.responseCodeOf(PtpException(0x1016, 0x200F)),
        0x200F,
      );
    });

    test('从 USB PlatformException 的 message 里解析响应码', () {
      final error = PlatformException(
        code: 'USB_TRANSFER',
        message: '数据读取指令失败 (响应码 0xa00b)',
      );
      expect(CameraErrorMapper.responseCodeOf(error), 0xA00B);
    });

    test('同时含操作码与响应码时取响应码', () {
      final error = PlatformException(
        code: 'USB_DATA_OUT_FAILED',
        message: 'PTP USB 操作 0x1016 失败，响应码 0x201c（Unknown）',
      );
      expect(CameraErrorMapper.responseCodeOf(error), 0x201C);
    });

    test('普通异常返回 null', () {
      expect(CameraErrorMapper.responseCodeOf(StateError('x')), isNull);
    });
  });

  group('kindOf', () {
    test('PTP 响应码映射到语义分类', () {
      expect(
        CameraErrorMapper.kindOf(PtpException(0x100E, 0x2019)),
        CameraFailureKind.deviceBusy,
      );
      expect(
        CameraErrorMapper.kindOf(PtpException(0x9201, 0x2005)),
        CameraFailureKind.unsupported,
      );
      expect(
        CameraErrorMapper.kindOf(PtpException(0x1016, 0x200F)),
        CameraFailureKind.accessDenied,
      );
      expect(
        CameraErrorMapper.kindOf(PtpException(0x1002, 0x2003)),
        CameraFailureKind.disconnected,
      );
    });

    test('超时与 socket 异常', () {
      expect(
        CameraErrorMapper.kindOf(TimeoutException('slow')),
        CameraFailureKind.timeout,
      );
      expect(
        CameraErrorMapper.kindOf(const SocketException('gone')),
        CameraFailureKind.disconnected,
      );
    });

    test('未知异常归为 generic', () {
      expect(CameraErrorMapper.kindOf(ArgumentError()), CameraFailureKind.generic);
    });
  });

  group('describe', () {
    test('空数据块带上偏移量', () {
      const failure = CameraFailure(
        CameraFailureKind.emptyChunk,
        details: <String, Object?>{'offset': 1024},
      );
      expect(CameraErrorMapper.describe(failure, en), contains('1024'));
      expect(CameraErrorMapper.describe(failure, zh), contains('1024'));
    });

    test('不完整下载带上实际与总字节数', () {
      const failure = CameraFailure(
        CameraFailureKind.incomplete,
        details: <String, Object?>{'actual': 512, 'total': 4096},
      );
      expect(CameraErrorMapper.describe(failure, en), contains('512'));
      expect(CameraErrorMapper.describe(failure, en), contains('4096'));
    });

    test('保存失败带上文件名', () {
      const failure = CameraFailure(
        CameraFailureKind.saveFailed,
        details: <String, Object?>{'fileName': 'DSC_0001.JPG'},
      );
      expect(
        CameraErrorMapper.describe(failure, en),
        contains('DSC_0001.JPG'),
      );
    });

    test('三语都给出非空的本地化文案，英文界面不含中文', () {
      final cjk = RegExp(r'[一-鿿]');
      for (final kind in CameraFailureKind.values) {
        final failure = CameraFailure(kind);
        for (final l10n in <dynamic>[en, zh, ja]) {
          final text = CameraErrorMapper.describe(failure, l10n);
          expect(text.trim(), isNotEmpty, reason: '$kind / ${l10n.localeName}');
        }
        expect(
          cjk.hasMatch(CameraErrorMapper.describe(failure, en)),
          isFalse,
          reason: '英文界面不应出现中文异常文本：$kind',
        );
      }
    });
  });

  group('语义判定', () {
    test('isDeviceBusy / isOperationUnsupported / isAccessDenied', () {
      expect(
        CameraErrorMapper.isDeviceBusy(PtpException(0x100E, 0x2019)),
        isTrue,
      );
      expect(
        CameraErrorMapper.isOperationUnsupported(PtpException(0x9201, 0x2005)),
        isTrue,
      );
      expect(
        CameraErrorMapper.isAccessDenied(PtpException(0x1016, 0x200F)),
        isTrue,
      );
      expect(CameraErrorMapper.isDeviceBusy(StateError('x')), isFalse);
    });
  });
}
