// //app_theme.dart

// import 'package:flutter/material.dart';

// /// Clean-clinical palette: light neutral surfaces with a single deep-red brand
// /// accent used sparingly for branding, primary actions and alerts.
// class AppColors {
//   AppColors._();

//   static const Color brand = Color(0xFF9E1B1B); // deep clinical red
//   static const Color brandDark = Color(0xFF6E1414);
//   static const Color background = Color(0xFFF4F5F7);
//   static const Color surface = Color(0xFFFFFFFF);
//   static const Color onSurface = Color(0xFF1C1B1F);
//   static const Color muted = Color(0xFF6B7280);
//   static const Color border = Color(0xFFE3E5EA);

//   static const Color positive = Color(0xFF14803C); // "no thalassemia"
//   static const Color positiveBg = Color(0xFFE7F5EC);
//   static const Color danger = Color(0xFFB3261E); // "thalassemia detected"
//   static const Color dangerBg = Color(0xFFFCEBEA);
//   static const Color warn = Color(0xFFB26A00);
//   static const Color warnBg = Color(0xFFFDF3E5);
// }

// class AppTheme {
//   AppTheme._();

//   static ThemeData get light {
//     final scheme = ColorScheme.fromSeed(
//       seedColor: AppColors.brand,
//       brightness: Brightness.light,
//       primary: AppColors.brand,
//       surface: AppColors.surface,
//     );

//     return ThemeData(
//       useMaterial3: true,
//       colorScheme: scheme,
//       scaffoldBackgroundColor: AppColors.background,
//       fontFamily: 'Roboto',
//       appBarTheme: const AppBarTheme(
//         backgroundColor: AppColors.background,
//         foregroundColor: AppColors.onSurface,
//         elevation: 0,
//         centerTitle: true,
//         titleTextStyle: TextStyle(
//           color: AppColors.onSurface,
//           fontSize: 18,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//       cardTheme: CardThemeData(
//         color: AppColors.surface,
//         elevation: 0,
//         margin: EdgeInsets.zero,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//           side: const BorderSide(color: AppColors.border),
//         ),
//       ),
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.brand,
//           foregroundColor: Colors.white,
//           elevation: 0,
//           minimumSize: const Size(0, 52),
//           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//         ),
//       ),
//       outlinedButtonTheme: OutlinedButtonThemeData(
//         style: OutlinedButton.styleFrom(
//           foregroundColor: AppColors.brand,
//           minimumSize: const Size(0, 52),
//           side: const BorderSide(color: AppColors.brand),
//           textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(14),
//           ),
//         ),
//       ),
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.background,
//         isDense: true,
//         contentPadding:
//             const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: AppColors.border),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
//         ),
//       ),
//       snackBarTheme: const SnackBarThemeData(
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }
// }




//app_theme.dart

import 'package:flutter/material.dart';

/// Clean-clinical palette: soft mint surfaces with a single teal-green brand
/// accent used sparingly for branding, primary actions and alerts.
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFF1CBE6B); // clinical mint-green
  static const Color brandDark = Color(0xFF2E7D46);
  static const Color background = Color(0xFFE6F6EC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1C1B1F);
  static const Color muted = Color(0xFF7A7A7A);
  static const Color border = Color(0xFFBEE3CE);

  // Pale pink backdrop behind icon badges / the logo avatar circle.
  static const Color accentBg = Color(0xFFFCEBEA);
  // Amber outline used on the manual CBC value entry fields.
  static const Color inputAccent = Color(0xFFBC802D);

  static const Color positive = Color(0xFF14803C); // "no thalassemia"
  static const Color positiveBg = Color(0xFFE7F5EC);
  static const Color danger = Color(0xFFB3261E); // "thalassemia detected"
  static const Color dangerBg = Color(0xFFFCEBEA);
  static const Color warn = Color(0xFFB26A00);
  static const Color warnBg = Color(0xFFFDF3E5);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: Brightness.light,
      primary: AppColors.brand,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.brand),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.6),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}