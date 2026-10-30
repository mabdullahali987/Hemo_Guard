import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../routes/app_pages.dart';
import 'api_client.dart';

/// Authenticated identity is validated on every backend request. Cached identity
/// only controls navigation and never authorizes a report.
class AuthService extends GetxService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'hemo_guard_session_v1';
  String? _token;
  final Rxn<Map<String, dynamic>> user = Rxn<Map<String, dynamic>>();

  bool get signedIn => _token != null && user.value != null;
  bool get isSuperadmin => user.value?['account_type'] == 'superadmin';
  bool get hasAccess => signedIn && !isSuperadmin && user.value?['status'] == 'active';
  String get displayName => user.value?['display_name']?.toString() ?? '';
  String get status => user.value?['status']?.toString() ?? 'unassigned';

  String get landingRoute {
    if (!signedIn) return Routes.LOGIN;
    if (isSuperadmin) return Routes.SUPERADMIN;
    return hasAccess ? Routes.HOME : Routes.ACCESS;
  }

  Future<void> restore() async {
    _token = await _storage.read(key: _tokenKey);
    if (_token == null) return;
    try {
      await refresh();
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _forget();
      // Fail closed if server is unavailable. Route to login.
    } catch (_) {
      // Retain token locally for a future online login, but grant no access.
    }
  }

  Future<void> refresh() async {
    if (_token == null) return;
    final response = await ApiClient.request('GET', '/api/auth/me', token: _token);
    user.value = Map<String, dynamic>.from(response['user'] as Map);
  }

  Future<void> login(String email, String password) async {
    final response = await ApiClient.request('POST', '/api/auth/login',
        body: {'email': email.trim(), 'password': password});
    _token = response['token'] as String;
    user.value = Map<String, dynamic>.from(response['user'] as Map);
    await _storage.write(key: _tokenKey, value: _token);
    Get.offAllNamed(landingRoute);
  }

  Future<Map<String, dynamic>> api(String method, String path,
      {Map<String, dynamic>? body}) async {
    if (_token == null) throw const ApiException('Please sign in.', 401);
    try {
      return await ApiClient.request(method, path, token: _token, body: body);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _forget();
        Get.offAllNamed(Routes.LOGIN);
      }
      rethrow;
    }
  }

  Future<String> downloadAdminFile(String path,String filename) async {
    if (_token==null || !isSuperadmin) throw const ApiException('Superadmin required',403);
    return ApiClient.downloadAdminFile(path,_token!,filename);
  }

  Future<void> changePassword(String current, String next) async {
    await api('POST', '/api/auth/change-password',
        body: {'old_password': current, 'new_password': next});
    await _forget();
    Get.offAllNamed(Routes.LOGIN);
  }

  Future<void> logout() async {
    if (_token != null) {
      try { await ApiClient.request('POST', '/api/auth/logout', token: _token); }
      catch (_) { /* Local logout must always work. */ }
    }
    await _forget();
    Get.offAllNamed(Routes.LOGIN);
  }

  Future<void> _forget() async {
    _token = null;
    user.value = null;
    await _storage.delete(key: _tokenKey);
  }
}
