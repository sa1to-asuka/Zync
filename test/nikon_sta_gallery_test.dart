import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zync/core/constants/ptp_opcodes.dart';
import 'package:zync/core/utils/byte_buffer_ext.dart';
import 'package:zync/engine/capture/capture_controller.dart';
import 'package:zync/engine/liveview/live_view_controller.dart';
import 'package:zync/protocol/camera_driver.dart';
import 'package:zync/protocol/nikon_driver.dart';
import 'package:zync/protocol/ptp_ip_client.dart';
import 'package:zync/protocol/ptp_packet.dart';
import 'package:zync/protocol/ptp_transport.dart';

Uint8List _encodeUint32Array(List<int> values) {
  final buf = PtpByteBuffer()..writeUint32(values.length);
  for (final v in values) {
    buf.writeUint32(v);
  }
  return buf.toBytes();
}

Uint8List _buildDeviceInfo({
  required List<int> ops,
  String model = 'NIKON Z 30',
}) {
  final buf = PtpByteBuffer()
    ..writeUint16(100)
    ..writeUint32(0x0000000A)
    ..writeUint16(100)
    ..writePtpString('Nikon')
    ..writeUint16(0)
    ..writeUint32(ops.length);
  for (final op in ops) {
    buf.writeUint16(op);
  }
  buf
    ..writeUint32(0) // events
    ..writeUint32(0) // deviceProps
    ..writeUint32(0) // captureFormats
    ..writeUint32(0) // playbackFormats
    ..writePtpString('Nikon Corporation')
    ..writePtpString(model)
    ..writePtpString('V1.11')
    ..writePtpString('1234567');
  return buf.toBytes();
}

Uint8List _buildObjectInfo({
  int storageId = 0x00010001,
  int format = 0x3801,
  int size = 4096000,
  int width = 5568,
  int height = 3712,
  String fileName = 'DSC_0186.JPG',
  String captureDate = '20261122T124301',
}) {
  final buf = PtpByteBuffer()
    ..writeUint32(storageId) // 0
    ..writeUint16(format) // 4
    ..writeUint16(0) // 6 protection
    ..writeUint32(size) // 8
    ..writeUint16(0x3801) // 12 thumb format
    ..writeUint32(0) // 14 thumb size
    ..writeUint32(0) // 18 thumb w
    ..writeUint32(0) // 22 thumb h
    ..writeUint32(width) // 26 pix w
    ..writeUint32(height) // 30 pix h
    ..writeUint32(24) // 34 bit depth
    ..writeUint32(0) // 38 parent
    ..writeUint16(format == 0x3001 ? 1 : 0) // 42 assoc type
    ..writeUint32(0) // 44 assoc desc
    ..writeUint32(0) // 48 seq num
    ..writePtpString(fileName) // 52+
    ..writePtpString(captureDate);
  return buf.toBytes();
}

Uint8List _buildMtpPropList({
  required int handle,
  int storageId = 0x00010001,
  int format = 0x3801,
  int size = 5120000,
  String fileName = 'DSC_0186.NEF',
  String captureDate = '20261122T124301',
  int width = 5568,
  int height = 3712,
}) {
  final buf = PtpByteBuffer()..writeUint32(7);

  void writeProp(int code, int type, void Function() writeVal) {
    buf
      ..writeUint32(handle)
      ..writeUint16(code)
      ..writeUint16(type);
    writeVal();
  }

  writeProp(0xDC01, 0x0006, () => buf.writeUint32(storageId));
  writeProp(0xDC02, 0x0004, () => buf.writeUint16(format));
  writeProp(0xDC04, 0x0008, () => buf.writeUint64(size));
  writeProp(0xDC07, 0xFFFF, () => buf.writePtpString(fileName));
  writeProp(0xDC08, 0xFFFF, () => buf.writePtpString(captureDate));
  writeProp(0xDC87, 0x0006, () => buf.writeUint32(width));
  writeProp(0xDC88, 0x0006, () => buf.writeUint32(height));

  return buf.toBytes();
}

class _FakeStaMediaTransport implements PtpTransport {
  bool _connected = false;
  final List<String> ops = [];
  final Future<Uint8List> Function(int opCode, List<int> params) onDataIn;
  final StreamController<PtpPacket> _events =
      StreamController<PtpPacket>.broadcast();

  _FakeStaMediaTransport({required this.onDataIn});

  void emitEvent(PtpPacket packet) => _events.add(packet);

  @override
  bool get isConnected => _connected;

  @override
  Stream<PtpPacket> get events => _events.stream;

  @override
  set onUnexpectedDisconnect(void Function()? callback) {}

  @override
  Future<void> connect() async {
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> executeOperation(int opCode,
      [List<int> params = const []]) async {
    ops.add('op:0x${opCode.toRadixString(16)}:${params.join(",")}');
  }

  @override
  Future<Uint8List> executeDataIn(int opCode,
      [List<int> params = const []]) async {
    ops.add('in:0x${opCode.toRadixString(16)}:${params.join(",")}');
    return onDataIn(opCode, params);
  }

  @override
  Future<void> executeDataOut(int opCode, Uint8List data,
      [List<int> params = const []]) async {}
}

void main() {
  group('STA 相册枚举与 GetObjectInfo 容错', () {
    test('优先使用 ISO 15740 扁平参数 0x0，一次返回全部照片而不误把 0xFFFFFFFF 根目录当全量',
        () async {
      const storage = 0x00010001;
      final photos = [0x291900ad, 0x291900ae, 0x291900af, 0x291900b0];
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getStorageIDs,
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.getObjectInfo,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([storage]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0) {
              return _encodeUint32Array([0x11000000, ...photos]);
            }
            if (parent == 0xFFFFFFFF) {
              return _encodeUint32Array([0x11000000]); // 仅根目录 DCIM
            }
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();

      expect(handles, containsAll(photos));
      // 一次 0x1007(storage, 0, 0) 即命中，无需再发 0xFFFFFFFF 或展开目录。
      final handleQueries =
          transport.ops.where((e) => e.startsWith('in:0x1007:')).toList();
      expect(handleQueries.length, equals(1));
      await driver.disconnect();
    });

    test(
        '目录树展开遇到 0x1008 失败且 0x1007 返回 0x201A 时，将叶目录照片句柄完整回收而非全部丢弃',
        () async {
      const storage = 0x00010001;
      const dcim = 0x11000000;
      const subFolder = 0x11004000;
      final photos = [
        0x291900ad,
        0x291900ae,
        0x291900af,
        0x291900b0,
        0x291900b1,
        0x291900b2,
        0x291900b3,
        0x291900b4,
        0x291900ba,
        0x091900ba,
      ];
      var invalidParentCalls = 0;

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getStorageIDs,
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.getObjectInfo,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([storage]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0) {
              // 模拟旧固件不支持 0x0 扁平查询，只返回 DCIM 根句柄
              return _encodeUint32Array([dcim]);
            }
            if (parent == 0xFFFFFFFF) {
              return _encodeUint32Array([dcim]);
            }
            if (parent == dcim) {
              return _encodeUint32Array([subFolder]);
            }
            if (parent == subFolder) {
              return _encodeUint32Array(photos);
            }
            invalidParentCalls++;
            throw PtpException(
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.responseInvalidParentObject,
              'InvalidParentObject',
            );
          }
          if (op == PtpOpCodes.getObjectInfo) {
            // 模拟 STA 下 0x1008 返回 0x200F AccessDenied
            throw PtpException(
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.responseAccessDenied,
              'AccessDenied',
            );
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();

      expect(handles, equals(photos));
      // 叶目录首条探测触发一次 0x201A 后整批收录，不再对剩余 9 条狂发 0x1007。
      expect(invalidParentCalls, equals(1));
      await driver.disconnect();
    });

    test('depth=1 目录含少量照片且 0x1008 失败时，连续 2 次 0x201A 后自动整批回收剩余兄弟句柄',
        () async {
      const storage = 0x00010001;
      const dcim = 0x11000000;
      final photos = [0x29190001, 0x29190002, 0x29190003, 0x29190004];
      var invalidParentCalls = 0;

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getStorageIDs,
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.getObjectInfo,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([storage]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0 || parent == 0xFFFFFFFF) {
              return _encodeUint32Array([dcim]);
            }
            if (parent == dcim) {
              return _encodeUint32Array(photos);
            }
            invalidParentCalls++;
            throw PtpException(
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.responseInvalidParentObject,
            );
          }
          if (op == PtpOpCodes.getObjectInfo) {
            throw PtpException(
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.responseOperationNotSupported,
            );
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();

      expect(handles, equals(photos));
      expect(invalidParentCalls, equals(2));
      await driver.disconnect();
    });

    test('getObjectInfo 遇到 0x2019 DeviceBusy 时自动重试并成功解析', () async {
      var attempts = 0;
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [PtpOpCodes.getObjectInfo]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            attempts++;
            if (attempts == 1) {
              throw PtpException(
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.responseDeviceBusy,
              );
            }
            return _buildObjectInfo(fileName: 'DSC_0186.JPG', size: 3456789);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final info = await driver.getObjectInfo(0x291900ba);

      expect(attempts, equals(2));
      expect(info, isNotNull);
      expect(info!.fileName, equals('DSC_0186.JPG'));
      expect(info.size, equals(3456789));
      await driver.disconnect();
    });

    test('0x1008 被拒时自动降级到 MTP 0x9805 GetObjectPropList 解析元数据', () async {
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.mtpGetObjectPropList,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            throw PtpException(
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.responseOperationNotSupported,
            );
          }
          if (op == PtpOpCodes.mtpGetObjectPropList) {
            return _buildMtpPropList(
              handle: params[0],
              format: 0x3000,
              size: 24500000,
              fileName: 'DSC_0186.NEF',
              captureDate: '20261122T124301',
              width: 5568,
              height: 3712,
            );
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final info = await driver.getObjectInfo(0x291900ba);

      expect(info, isNotNull);
      expect(info!.fileName, equals('DSC_0186.NEF'));
      expect(info.isRaw, isTrue);
      expect(info.size, equals(24500000));
      expect(info.pixelWidth, equals(5568));
      expect(info.pixelHeight, equals(3712));
      await driver.disconnect();
    });

    test('0x1008 与 0x9805 均被拒时自动降级到 MTP 0x9803 GetObjectPropValue',
        () async {
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.mtpGetObjectPropList,
              PtpOpCodes.mtpGetObjectPropValue,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectInfo ||
              op == PtpOpCodes.mtpGetObjectPropList) {
            throw PtpException(op, PtpOpCodes.responseOperationNotSupported);
          }
          if (op == PtpOpCodes.mtpGetObjectPropValue) {
            final propCode = params[1];
            final buf = PtpByteBuffer();
            switch (propCode) {
              case 0xDC01:
                buf.writeUint32(0x00010001);
              case 0xDC02:
                buf.writeUint16(0x3801);
              case 0xDC04:
                buf.writeUint64(6789012);
              case 0xDC07:
                buf.writePtpString('DSC_0186.JPG');
              case 0xDC08:
                buf.writePtpString('20261122T124301');
            }
            return buf.toBytes();
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final info = await driver.getObjectInfo(0x091900ba);

      expect(info, isNotNull);
      expect(info!.fileName, equals('DSC_0186.JPG'));
      expect(info.size, equals(6789012));
      expect(info.captureDate, equals('20261122T124301'));
      await driver.disconnect();
    });

    test('所有元信息接口受限时，已确认为文件的句柄可通过 0x9421 NikonGetObjectSize 兜底',
        () async {
      const storage = 0x00010001;
      const dcim = 0x11000000;
      const subFolder = 0x11004000;
      final photos = [
        0x291900ad,
        0x291900ae,
        0x291900af,
        0x291900b0,
        0x291900b1,
      ];

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getStorageIDs,
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.getObjectInfo,
              PtpOpCodes.nikonGetObjectSize,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([storage]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0 || parent == 0xFFFFFFFF) {
              return _encodeUint32Array([dcim]);
            }
            if (parent == dcim) return _encodeUint32Array([subFolder]);
            if (parent == subFolder) return _encodeUint32Array(photos);
            throw PtpException(op, PtpOpCodes.responseInvalidParentObject);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          if (op == PtpOpCodes.nikonGetObjectSize) {
            return (PtpByteBuffer()..writeUint32(4123456)).toBytes();
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();
      expect(handles, equals(photos));

      final info = await driver.getObjectInfo(0x291900ad);
      expect(info, isNotNull);
      expect(info!.size, equals(4123456));
      expect(info.isFolder, isFalse);
      await driver.disconnect();
    });

    test('进入相册枚举前若取景仍开启，自动先发 0x9202 退出取景', () async {
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(ops: [
              PtpOpCodes.getStorageIDs,
              PtpOpCodes.getObjectHandles,
              PtpOpCodes.nikonStartLiveView,
              PtpOpCodes.nikonEndLiveView,
              PtpOpCodes.nikonGetLiveViewImage,
            ]);
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            return _encodeUint32Array([0x291900ad, 0x291900ae, 0x291900af]);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      await driver.startLiveView();
      transport.ops.clear();

      final handles = await driver.listObjectHandles();
      expect(handles.length, equals(3));
      final endLvIdx = transport.ops.indexOf('op:0x9202:');
      final getHandlesIdx =
          transport.ops.indexWhere((e) => e.startsWith('in:0x1007:'));
      expect(endLvIdx, greaterThanOrEqualTo(0));
      expect(endLvIdx, lessThan(getHandlesIdx));
      await driver.disconnect();
    });

    test(
        'Z50II STA 扁平枚举遇到全量 0x1008 拒绝(0x200F)时：识别目录、降级 0x9421+魔数嗅探并实现 JPG+RAW 配对同干名',
        () async {
      const storage = 0x00010001;
      final flatHandles = [
        0x11004000,
        0x11194000,
        0x291944a6,
        0x091944a6,
        0x291944a7,
        0x091944a7,
      ];
      final jpgHead = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0, 16, 0, 0]);
      final nefHead = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 8, 0, 0, 0]);
      var infoCalls = 0;

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.getThumb,
                PtpOpCodes.getPartialObject,
                PtpOpCodes.nikonGetObjectSize,
                PtpOpCodes.nikonChangeAppMode,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([storage]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0) return _encodeUint32Array(flatHandles);
            if (parent == 0x11004000) return _encodeUint32Array([0x11194000]);
            if (parent == 0x11194000) {
              return _encodeUint32Array([0x291944a6, 0x091944a6]);
            }
            throw PtpException(op, PtpOpCodes.responseInvalidParentObject);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            infoCalls++;
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          if (op == PtpOpCodes.nikonGetObjectSize) {
            final h = params[0];
            final sz = ((h >> 24) & 0xFF) == 0x29 ? 24500000 : 8100000;
            return (PtpByteBuffer()..writeUint32(sz)).toBytes();
          }
          if (op == PtpOpCodes.getPartialObject) {
            final h = params[0];
            return ((h >> 24) & 0xFF) == 0x29 ? nefHead : jpgHead;
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();
      expect(handles, equals(flatHandles));

      final folderA = await driver.getObjectInfo(0x11004000);
      final folderB = await driver.getObjectInfo(0x11194000);
      expect(folderA?.isFolder, isTrue);
      expect(folderB?.isFolder, isTrue);

      final raw1 = await driver.getObjectInfo(0x291944a6);
      final jpg1 = await driver.getObjectInfo(0x091944a6);
      final raw2 = await driver.getObjectInfo(0x291944a7);
      final jpg2 = await driver.getObjectInfo(0x091944a7);

      expect(raw1?.isRaw, isTrue);
      expect(raw1?.size, equals(24500000));
      expect(jpg1?.isRaw, isFalse);
      expect(jpg1?.size, equals(8100000));
      // 同一对 RAW+JPG 剥离高 4 位前缀差异后主干名一致，供相册自动合组
      expect(
        raw1!.fileName.split('.').first,
        equals(jpg1!.fileName.split('.').first),
      );
      expect(raw2?.fileName, equals('DSC_1944A7.NEF'));
      expect(jpg2?.fileName, equals('DSC_1944A7.JPG'));
      // 连续 3 次 0x200F 后应短接跳过后续 0x1008 调用
      expect(infoCalls, lessThanOrEqualTo(3));
      await driver.disconnect();
    });

    test('Z50II 遥控拍摄：0x1008 全被拒时通过 0x9421 立即确认新照片而不卡死 30s 超时', () async {
      var captured = false;
      final beforeHandles = [0x11004000, 0x11194000, 0x291944a6, 0x091944a6];
      final afterHandles = [...beforeHandles, 0x291944a8, 0x091944a8];
      final jpgHead = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0, 16, 0, 0]);
      final nefHead = Uint8List.fromList([0x49, 0x49, 0x2A, 0x00, 8, 0, 0, 0]);

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.initiateCapture,
                PtpOpCodes.getPartialObject,
                PtpOpCodes.nikonGetObjectSize,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0) {
              return _encodeUint32Array(captured ? afterHandles : beforeHandles);
            }
            throw PtpException(op, PtpOpCodes.responseInvalidParentObject);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          if (op == PtpOpCodes.nikonGetObjectSize) {
            final sz = ((params[0] >> 24) & 0xFF) == 0x29 ? 22000000 : 7500000;
            return (PtpByteBuffer()..writeUint32(sz)).toBytes();
          }
          if (op == PtpOpCodes.getPartialObject) {
            return ((params[0] >> 24) & 0xFF) == 0x29 ? nefHead : jpgHead;
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final liveView = LiveViewController(driver: driver);
      final recorded = <CameraFileItem>[];
      final capture = CaptureController(
        driver: driver,
        liveView: liveView,
        confirmTimeout: const Duration(seconds: 2),
        pollInterval: const Duration(milliseconds: 20),
        onCaptured: recorded.add,
      );

      // 当 CaptureController 触发 initiateCapture (0x100E) 后立即模拟相机写卡产出新 handle
      final origExecuteOp = transport;
      expect(origExecuteOp.isConnected, isTrue);
      Future<void>.delayed(const Duration(milliseconds: 35), () {
        captured = true;
      });

      final outcome = await capture.capture();
      expect(outcome, isA<CaptureConfirmed>());
      final confirmed = outcome as CaptureConfirmed;
      expect(confirmed.file.handle, equals(0x091944a8));
      expect(confirmed.file.fileName, equals('DSC_1944A8.JPG'));
      expect(recorded.length, equals(2));
      await driver.disconnect();
    });

    test('空卡仅含 DCIM 根目录时目录判别返回空文件列表且不误触发 0x9435(1)', () async {
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.nikonChangeAppMode,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectHandles) {
            final parent = params[2];
            if (parent == 0) {
              return _encodeUint32Array([0x11004000, 0x11194000]);
            }
            if (parent == 0x11004000 || parent == 0x11194000) {
              return _encodeUint32Array([]);
            }
            throw PtpException(op, PtpOpCodes.responseInvalidParentObject);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final handles = await driver.listObjectHandles();
      expect(handles, isEmpty);
      expect(transport.ops.where((e) => e.startsWith('op:0x9435')), isEmpty);
      await driver.disconnect();
    });

    test('Tier 5 兜底：当 0x1008 与 0x9421 均被拒绝时，通过 0x101B 魔数+二分探测精准恢复文件信息',
        () async {
      final syntheticFile = Uint8List(5000);
      syntheticFile[0] = 0xFF;
      syntheticFile[1] = 0xD8;
      syntheticFile[2] = 0xFF;
      syntheticFile[3] = 0xE0;

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.getPartialObject,
                PtpOpCodes.nikonGetObjectSize,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectInfo ||
              op == PtpOpCodes.nikonGetObjectSize) {
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          if (op == PtpOpCodes.getPartialObject) {
            final offset = params[1];
            final maxBytes = params[2];
            if (offset >= syntheticFile.length) return Uint8List(0);
            final end = (offset + maxBytes).clamp(0, syntheticFile.length);
            return Uint8List.sublistView(syntheticFile, offset, end);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final info = await driver.getObjectInfo(0x091944b1);
      expect(info, isNotNull);
      expect(info!.isFolder, isFalse);
      expect(info.isRaw, isFalse);
      expect(info.size, equals(5000));
      expect(info.fileName, equals('DSC_1944B1.JPG'));
      await driver.disconnect();
    });

    test('downloadPartialObject：0x101B 返回 0x200F 时自动回退 5 参数 0x9431，并在 0x2006 时兼容 4 参数',
        () async {
      final captured64Params = <List<int>>[];
      var callCount9431 = 0;
      var partial101bCalls = 0;

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getPartialObject,
                PtpOpCodes.nikonGetPartialObject64,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getPartialObject) {
            partial101bCalls++;
            throw PtpException(op, PtpOpCodes.responseAccessDenied);
          }
          if (op == PtpOpCodes.nikonGetPartialObject64) {
            callCount9431++;
            captured64Params.add(List<int>.from(params));
            if (callCount9431 == 1 && params.length == 5) {
              throw PtpException(op, PtpOpCodes.responseParameterNotSupported);
            }
            return Uint8List.fromList([1, 2, 3, 4]);
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});

      final firstChunk = await driver.downloadPartialObject(0x091944a6, 0, 1024);
      expect(firstChunk, equals([1, 2, 3, 4]));
      // 第 1 次发 5 参数 [handle, 0, 0, 1024, 0]；遇 0x2006 后自动重试 4 参数。
      expect(captured64Params[0], equals([0x091944a6, 0, 0, 1024, 0]));
      expect(captured64Params[1], equals([0x091944a6, 0, 0, 1024]));

      // 锁存后后续分块直走 0x9431，不再浪费一轮被拒的 0x101B。
      final secondChunk =
          await driver.downloadPartialObject(0x091944a6, 1024, 512);
      expect(secondChunk, equals([1, 2, 3, 4]));
      expect(partial101bCalls, equals(1));
      await driver.disconnect();
    });

    test('getThumbnail 与 downloadFullObject：0x100A/0x90C4/0x101B/0x9431 全拒时兜底 0x1009 GetObject',
        () async {
      // 构造最小完整基线 JPEG（包含 SOI + SOF0 + SOS + EOI，长度 > 128）
      final validJpeg = Uint8List.fromList([
        0xFF, 0xD8,
        0xFF, 0xE0, 0x00, 0x10, ...List<int>.filled(14, 0),
        0xFF, 0xC0, 0x00, 0x0B, 8, 0, 16, 0, 16, 1, 1, 0x11, 0,
        0xFF, 0xDA, 0x00, 0x08, 1, 1, 0, 0, 0x3F, 0,
        ...List<int>.filled(100, 0x55),
        0xFF, 0xD9,
      ]);

      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
                PtpOpCodes.getObject,
                PtpOpCodes.getThumb,
                PtpOpCodes.nikonGetLargeThumb,
                PtpOpCodes.getPartialObject,
                PtpOpCodes.nikonGetPartialObject64,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObject) {
            return validJpeg;
          }
          throw PtpException(op, PtpOpCodes.responseAccessDenied);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});

      final thumb = await driver.getThumbnail(0x091944b2);
      expect(thumb, equals(validJpeg));

      final full =
          await driver.downloadFullObject(0x091944b3, validJpeg.length);
      expect(full, equals(validJpeg));
      await driver.disconnect();
    });

    test('相机端 0x4003 ObjectRemoved 事件与 clearMediaCaches 正确淘汰旧照片缓存',
        () async {
      var generation = 1;
      final transport = _FakeStaMediaTransport(
        onDataIn: (op, params) async {
          if (op == PtpOpCodes.getDeviceInfo) {
            return _buildDeviceInfo(
              model: 'NIKON Z50II',
              ops: [
                PtpOpCodes.getStorageIDs,
                PtpOpCodes.getObjectHandles,
                PtpOpCodes.getObjectInfo,
              ],
            );
          }
          if (op == PtpOpCodes.getStorageIDs) {
            return _encodeUint32Array([0x00010001]);
          }
          if (op == PtpOpCodes.getObjectInfo) {
            return _buildObjectInfo(fileName: 'DSC_000$generation.JPG');
          }
          return Uint8List(0);
        },
      );

      final driver = NikonDriver();
      await driver.connectTransport(transport, onLog: (_) {});
      final removed = <int>[];
      final sub = driver.onObjectRemoved.listen(removed.add);

      final first = await driver.getObjectInfo(0x091944c1);
      expect(first?.fileName, equals('DSC_0001.JPG'));

      // 模拟相机端删掉该照片后发送 0x4003 事件，并把同句柄复用到新照片
      generation = 2;
      final eventBuf = PtpByteBuffer()
        ..writeUint16(PtpOpCodes.eventObjectRemoved)
        ..writeUint32(1)
        ..writeUint32(0x091944c1);
      final eventPayload = eventBuf.toBytes();
      transport.emitEvent(PtpPacket(
        length: eventPayload.length + 8,
        type: PtpOpCodes.ptpIpEvent,
        payload: eventPayload,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(removed, equals([0x091944c1]));

      final reloaded = await driver.getObjectInfo(0x091944c1);
      expect(reloaded?.fileName, equals('DSC_0002.JPG'));

      generation = 3;
      driver.clearMediaCaches();
      final afterManualClear = await driver.getObjectInfo(0x091944c1);
      expect(afterManualClear?.fileName, equals('DSC_0003.JPG'));

      await sub.cancel();
      await driver.disconnect();
    });
  });
}
