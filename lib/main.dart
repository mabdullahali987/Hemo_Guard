//main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

void main() {
  runApp(
    GetMaterialApp(
      title: "Hemo Guard",
      initialRoute: AppPages.INITIAL,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      getPages: AppPages.routes,
    ),
  );
}
