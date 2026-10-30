import 'package:get/get.dart';

import '../modules/home/bindings/home_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/auth/views/access_view.dart';
import '../modules/superadmin/views/superadmin_view.dart';
import '../services/auth_middleware.dart';
import '../modules/home/views/user_workspace_view.dart';
import '../modules/scanner/bindings/scanner_binding.dart';
import '../modules/scanner/views/scanner_view.dart';
import '../modules/settings/bindings/settings_binding.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.LOGIN;

  static final routes = [
    GetPage(name: _Paths.LOGIN, page: () => const LoginView()),
    GetPage(name: _Paths.ACCESS, page: () => const AccessView()),
    GetPage(name: _Paths.SUPERADMIN, page: () => const SuperadminView(),
      middlewares: [AdminOnlyMiddleware()]),
    GetPage(
      name: _Paths.HOME,
      page: () => const UserWorkspaceView(),
      binding: HomeBinding(),
      middlewares: [UserOnlyMiddleware()],
    ),
    GetPage(
      name: _Paths.SCANNER,
      page: () => const ScannerView(),
      binding: ScannerBinding(),
      middlewares: [UserOnlyMiddleware()],
    ),
    GetPage(name: _Paths.PATIENTS, page: () => const UserWorkspaceView(initialTab: 1), middlewares: [UserOnlyMiddleware()]),
    GetPage(
      name: _Paths.SETTINGS,
      page: () => const UserWorkspaceView(initialTab: 2),
      binding: SettingsBinding(),
      middlewares: [UserOnlyMiddleware()],
    ),
  ];
}
