import 'package:flutter/foundation.dart';
import 'settings.dart';

/// Shared, in-memory preferences (same storage policy as before). The notifier
/// lets regular-user glass screens repaint when Light / Dark is selected.
class SettingsStore {
  SettingsStore();
  static final SettingsStore shared = SettingsStore();

  AppSettings _current = const AppSettings();
  final ValueNotifier<AppThemeMode> appearanceChanges =
      ValueNotifier<AppThemeMode>(AppThemeMode.system);

  AppSettings get current => _current;

  void update(AppSettings next) {
    _current = next;
    appearanceChanges.value = next.themeMode;
  }

  void toggleTheme(AppThemeMode mode) =>
      update(_current.copyWith(themeMode: mode));
}
