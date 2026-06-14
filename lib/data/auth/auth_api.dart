import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'auth_api.g.dart';

/// A user-facing auth error with a message safe to show in the UI.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper over Mantle's mobile auth endpoints.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `POST /api/auth/mobile-login` → bearer token. Throws [AuthException] with a
  /// user-friendly message on bad credentials, rate-limiting, or a network/
  /// server problem.
  Future<String> mobileLogin({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/mobile-login',
        data: {'email': email, 'password': password, 'deviceName': deviceName},
        // A 401 here is "wrong password" — don't trip the global logout handler.
        options: Options(extra: const {'skipAuthHandler': true}),
      );
      final token = res.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Unexpected response from the server.');
      }
      return token;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401) throw AuthException('Invalid email or password.');
      if (code == 429) {
        throw AuthException('Too many attempts. Try again in a minute.');
      }
      throw AuthException(
        'Could not reach Mantle. Check the server URL and your connection.',
      );
    }
  }

  /// `POST /api/auth/mobile-logout` — revokes the token server-side. Best-effort;
  /// local sign-out proceeds even if this fails.
  Future<void> mobileLogout() async {
    try {
      await _dio.post<void>('/api/auth/mobile-logout');
    } on DioException {
      // Ignore — the device clears its token regardless.
    }
  }
}

@Riverpod(keepAlive: true)
AuthApi authApi(Ref ref) {
  return AuthApi(ref.watch(dioProvider));
}
