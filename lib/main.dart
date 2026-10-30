//main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/services/auth_service.dart';
import 'app/services/system_appearance.dart';
import 'app/modules/settings/controllers/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = Get.put(AuthService(), permanent: true);
  await auth.restore();
  // Settings is displayed inside the persistent swipeable user workspace.
  // Keep its preference controller alive across GetX route changes (e.g. Scan).
  Get.put<SettingsController>(SettingsController(), permanent: true);
  // Read Android system appearance once before showing Login/Superadmin.
  await HemoGuardSystemAppearance.refresh();
  runApp(
    GetMaterialApp(
      title: "Hemo Guard",
      initialRoute: auth.landingRoute,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Keep every other HemoGuard screen visually light in either OS mode,
      // but allow MaterialApp to listen for system brightness changes.
      darkTheme: AppTheme.light,
      themeMode: ThemeMode.system,
      getPages: AppPages.routes,
    ),
  );
}
