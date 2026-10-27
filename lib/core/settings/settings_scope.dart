import 'package:flutter/material.dart';
import '../../core/settings/app_settings.dart';

/// 让任意 Widget 通过 `SettingsScope.of(context)` 订阅设置变化并自动重建。
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope 未注入：请在根 Widget 包裹 SettingsScope');
    return scope!.notifier!;
  }
}
