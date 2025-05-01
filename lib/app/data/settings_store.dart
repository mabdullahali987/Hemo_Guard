import 'settings.dart';

/// Lightweight in-memory settings store. A real implementation would back this
/// with shared_preferences; kept dependency-free so it is host-testable.
class SettingsStore {
  AppSettings _current = const AppSettings();

  AppSettings get current => _current;

  void update(AppSettings next) => _current = next;

  void toggleTheme(AppThemeMode mode) =>
      _current = _current.copyWith(themeMode: mode);
}
