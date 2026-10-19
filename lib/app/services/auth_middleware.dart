import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../routes/app_pages.dart';
import 'auth_service.dart';

class UserOnlyMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthService>();
    if (!auth.signedIn) return const RouteSettings(name: Routes.LOGIN);
    if (auth.isSuperadmin) return const RouteSettings(name: Routes.SUPERADMIN);
    if (!auth.hasAccess) return const RouteSettings(name: Routes.ACCESS);
    return null;
  }
}

class AdminOnlyMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthService>();
    if (!auth.signedIn) return const RouteSettings(name: Routes.LOGIN);
    if (!auth.isSuperadmin) return RouteSettings(name: auth.landingRoute);
    return null;
  }
}
