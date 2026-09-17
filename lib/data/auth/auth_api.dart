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

/// What a successful pairing claim hands back.
class PairingClaim {
  const PairingClaim({required this.token, this.email});
  final String token;

  /// The account the code belonged to, for Settings to show who is signed
  /// in; absent on a brain older than the pairing endpoint's email field.
  final String? email;
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

  /// `POST /api/auth/pair/claim` — trade a scanned pairing code for the same
  /// kind of bearer [mobileLogin] mints. The server answers one generic
  /// failure for an unknown, expired or already-used code, and so do we:
  /// nothing here says which. Returns the token and the account's email.
  Future<PairingClaim> claimPairing({
    required String code,
    required String deviceName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/pair/claim',
        data: {'code': code, 'deviceName': deviceName},
        options: Options(extra: const {'skipAuthHandler': true}),
      );
      final token = res.data?['token'] as String?;
      if (token == null || token.isEmpty) {
        throw AuthException('Unexpected response from the server.');
      }
      return PairingClaim(token: token, email: res.data?['email'] as String?);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 429) {
        throw AuthException('Too many attempts. Try again in a minute.');
      }
      if (code != null && code >= 400 && code < 500) {
        throw AuthException(
          "That code didn't work. Show a fresh one on the web app and scan "
          'again.',
        );
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
