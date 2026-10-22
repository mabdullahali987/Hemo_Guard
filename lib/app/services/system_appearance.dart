import 'dart:ui' show Brightness;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Android night mode, scoped to HemoGuard's Login and Superadmin screens.
/// All other screens retain the application's existing theme.
class HemoGuardSystemAppearance {
  HemoGuardSystemAppearance._();

  static const MethodChannel _channel =
      MethodChannel('hemoguard/system_appearance');
  static final ValueNotifier<bool?> _androidNightMode = ValueNotifier(null);
  static bool _listening = false;

  static bool get isDark => _androidNightMode.value ??
      (WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark);

  static void addListener(VoidCallback callback) =>
      _androidNightMode.addListener(callback);

  static void removeListener(VoidCallback callback) =>
      _androidNightMode.removeListener(callback);

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'appearanceChanged') {
        _androidNightMode.value = call.arguments as bool?;
      }
    });
  }

  static Future<void> refresh() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      _androidNightMode.value = null;
      return;
    }
    _ensureListening();
    try {
      _androidNightMode.value = await _channel.invokeMethod<bool>('isDarkMode');
    } on MissingPluginException {
      _androidNightMode.value = null;
    } on PlatformException {
      _androidNightMode.value = null;
    }
    assert(() {
      debugPrint('HemoGuard appearance: Android=${_androidNightMode.value}, '
          'Flutter=${WidgetsBinding.instance.platformDispatcher.platformBrightness}');
      return true;
    }());
  }
}
