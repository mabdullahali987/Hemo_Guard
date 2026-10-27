import 'package:get/get.dart';

import '../../../data/settings.dart';
import '../../../data/settings_store.dart';

/// Drives the settings screen and keeps the [SettingsStore] in sync.
class SettingsController extends GetxController {
  final SettingsStore _store = SettingsStore.shared;

  final Rx<AppSettings> settings = const AppSettings().obs;

  @override
  void onInit() {
    super.onInit();
    settings.value = _store.current;
  }

  void setThemeMode(AppThemeMode mode) =>
      _apply(settings.value.copyWith(themeMode: mode));

  void setSaveScansLocally(bool value) =>
      _apply(settings.value.copyWith(saveScansLocally: value));

  void _apply(AppSettings next) {
    _store.update(next);
    settings.value = next;
  }
}
