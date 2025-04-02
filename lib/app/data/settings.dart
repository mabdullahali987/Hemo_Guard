/// App-wide user preferences.
enum AppThemeMode { system, light, dark }

class AppSettings {
  final AppThemeMode themeMode;
  final bool saveScansLocally;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.saveScansLocally = true,
  });

  AppSettings copyWith({AppThemeMode? themeMode, bool? saveScansLocally}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        saveScansLocally: saveScansLocally ?? this.saveScansLocally,
      );

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'saveScansLocally': saveScansLocally,
      };
}
