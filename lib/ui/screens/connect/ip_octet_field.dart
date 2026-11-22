import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';

/// 四段式 IPv4 输入框。
///
/// 相机屏幕经常显示 `010.151.169.075` 这种补零地址，逐段输入比一个长输入框
/// 更好核对；每段满 3 位自动跳到下一段，并顺手去掉前导零。
class IpOctetField extends StatefulWidget {
  const IpOctetField({
    super.key,
    required this.initialIp,
    required this.onChanged,
  });

  final String initialIp;
  final ValueChanged<String> onChanged;

  @override
  IpOctetFieldState createState() => IpOctetFieldState();
}

class IpOctetFieldState extends State<IpOctetField> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _apply(widget.initialIp);
    for (final node in _focusNodes) {
      node.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get ip => _controllers.map((c) => c.text).join('.');

  void setIp(String value) {
    _apply(value);
    widget.onChanged(ip);
  }

  void _apply(String value) {
    final parts = value.trim().split('.');
    for (var i = 0; i < 4; i++) {
      final raw = i < parts.length ? parts[i] : '';
      _controllers[i].text = _cleanOctet(raw);
    }
  }

  /// 只清掉非数字并截到 3 位；保留用户输入的 `010`，归一化交给连接层。
  static String _cleanOctet(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 3 ? digits.substring(0, 3) : digits;
  }

  /// 只处理用户输入。焦点变化不会走到这里，因此不会在已有值上误跳段。
  void _onUserEdited(int index, String text) {
    // 粘贴完整 IP（或手动输入点号）：从当前段开始铺开。
    if (text.contains('.')) {
      final parts = text.split('.');
      for (var i = 0; i < parts.length && index + i < 4; i++) {
        _controllers[index + i].text = _cleanOctet(parts[i]);
      }
      final next = (index + parts.length).clamp(0, 3);
      _focusNodes[next].requestFocus();
      widget.onChanged(ip);
      return;
    }

    var digits = text;
    if (digits.length > 3) {
      digits = digits.substring(0, 3);
      _controllers[index].text = digits;
    }
    if (digits.length >= 3 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged(ip);
  }

  @override
  Widget build(BuildContext context) {
    final zc = context.zc;
    final zt = context.zt;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                '.',
                style: zt.display.copyWith(
                  fontSize: 22,
                  color: zc.textTertiary,
                ),
              ),
            ),
          Expanded(child: _octetBox(context, i)),
        ],
      ],
    );
  }

  Widget _octetBox(BuildContext context, int index) {
    final zc = context.zc;
    final zt = context.zt;
    final baseStyle = DefaultTextStyle.of(context).style;
    final focused = _focusNodes[index].hasFocus;
    return AnimatedContainer(
      duration: ZMotion.of(context, ZMotion.short),
      height: 52,
      decoration: BoxDecoration(
        color: zc.surfaceHighest,
        borderRadius: ZRadius.brSm,
        border: Border.all(
          color: focused ? zc.accent : zc.outlineVariant,
          width: focused ? 1.4 : 0.8,
        ),
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _focusNodes[index].requestFocus(),
        child: EditableText(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          style: baseStyle.merge(zt.numeric).copyWith(
            fontSize: 18,
            letterSpacing: 0.5,
            color: zc.textPrimary,
          ),
          cursorColor: zc.accent,
          backgroundCursorColor: zc.outline,
          selectionColor: zc.accentContainer,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          maxLines: 1,
          onChanged: (value) => _onUserEdited(index, value),
          onSubmitted: (_) {
            if (index < 3) _focusNodes[index + 1].requestFocus();
          },
        ),
      ),
    );
  }
}
