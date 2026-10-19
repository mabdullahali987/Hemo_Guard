import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// HTTPS JSON transport used by authentication, report audit, and superadmin.
/// Set --dart-define=API_BASE_URL=https://your-domain.example at build time.
class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ApiClient {
  static const baseUrl = String.fromEnvironment('API_BASE_URL');

  static Future<Map<String, dynamic>> request(String method, String path,
      {String? token, Map<String, dynamic>? body}) async {
    final origin = baseUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (origin.isEmpty) {
      throw const ApiException(
          'Server URL is not configured. Set API_BASE_URL for this app build.', 0);
    }
    final uri = Uri.parse('$origin$path');
    if (uri.scheme != 'https' &&
        !(const bool.fromEnvironment('dart.vm.product') == false &&
          uri.scheme == 'http' &&
          ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host))) {
      throw const ApiException('A secure HTTPS server URL is required.', 0);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.openUrl(method, uri)
          .timeout(const Duration(seconds: 15));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close()
          .timeout(const Duration(seconds: 20));
      final raw = await utf8.decoder.bind(response).join()
          .timeout(const Duration(seconds: 20));
      final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Unexpected server response', response.statusCode);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          decoded['error']?.toString() ?? 'Request failed', response.statusCode);
      }
      return decoded;
    } on SocketException {
      throw const ApiException('Cannot connect to the server. Check your connection.', 0);
    } on HandshakeException {
      throw const ApiException('Secure connection failed. Check the server certificate.', 0);
    } on TimeoutException {
      throw const ApiException('The server did not respond in time.', 0);
    } on FormatException {
      throw const ApiException('Invalid response from the server.', 0);
    } finally {
      client.close(force: true);
    }
  }
}
