//main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';
import 'app/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = Get.put(AuthService(), permanent: true);
  await auth.restore();
  runApp(
    GetMaterialApp(
      title: "Hemo Guard",
      initialRoute: auth.landingRoute,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      getPages: AppPages.routes,
    ),
  );
}
