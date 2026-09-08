//settings_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hemo_guard/app/data/settings.dart';
import 'package:hemo_guard/app/data/settings_store.dart';

void main() {
  test('copyWith overrides only the given fields', () {
    const base = AppSettings();
    final next = base.copyWith(themeMode: AppThemeMode.dark);
    expect(next.themeMode, AppThemeMode.dark);
    expect(next.saveScansLocally, base.saveScansLocally);
  });

  test('store keeps the latest applied settings', () {
    final store = SettingsStore();
    store.toggleTheme(AppThemeMode.light);
    expect(store.current.themeMode, AppThemeMode.light);
  });
}
