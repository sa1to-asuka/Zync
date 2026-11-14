import 'package:flutter/material.dart';

import '../../l10n/engine_l10n.dart';
import '../../l10n/l10n.dart';
import '../../protocol/camera_native_bridge.dart';
import '../design/design.dart';

/// USB 连接诊断对话框。
///
/// 「连不上相机」时这一步最关键：列表为空说明手机压根没进主机模式，
/// 有设备但没有 PTP 接口说明相机还在 MTP / 存储模式。
Future<void> showUsbDiagnosticsDialog(BuildContext context) async {
  final lang = L10n.current.localeName;
  final devices = await CameraNativeBridge.listUsbDiagnostics();
  if (!context.mounted) return;

  final zc = context.zc;
  final zt = context.zt;

  String hex(Object? value) =>
      (value is num ? value.toInt() : 0).toRadixString(16).padLeft(4, '0');

  final rows = <Widget>[];
  for (var i = 0; i < devices.length; i++) {
    final d = devices[i];
    final manufacturer = (d['manufacturerName'] ?? '').toString().trim();
    final product = (d['productName'] ?? '').toString().trim();
    final title =
        <String>[manufacturer, product].where((e) => e.isNotEmpty).join(' ');
    rows.addAll(<Widget>[
      Text(
        title.isEmpty ? 'USB device #$i' : title,
        style: zt.label.copyWith(color: zc.textPrimary),
      ),
      Text(
        '${hex(d['vendorId'])}:${hex(d['productId'])}'
        '  class=${d['deviceClass']}'
        '  ifaces=${d['interfaceCount']}'
        '  ptp=${d['hasPtp']}'
        '  storage=${d['hasStorage']}'
        '  perm=${d['hasPermission']}',
        style: zt.numericSmall.copyWith(color: zc.textSecondary),
      ),
      Text(
        '${d['deviceName']}',
        style: zt.numericSmall.copyWith(color: zc.textSecondary),
      ),
      if (d['hasPtp'] != true)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            EngineL10n.usbDiagNoPtp(lang),
            style: zt.caption.copyWith(color: zc.warning),
          ),
        ),
      const SizedBox(height: ZSpace.md),
    ]);
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => ZDialog(
      title: EngineL10n.usbDiagTitle(lang),
      content: SizedBox(
        width: 420,
        child: devices.isEmpty
            ? Text(
                '${EngineL10n.usbDiagEmpty(lang)}\n\n'
                '${EngineL10n.usbDiagEmptyHint(lang)}',
                style: zt.bodySmall,
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: rows,
                ),
              ),
      ),
      confirmLabel: EngineL10n.usbDiagClose(lang),
      onConfirm: () => Navigator.of(ctx).pop(),
    ),
  );
}
