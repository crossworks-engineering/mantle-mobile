import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'auth_api.g.dart';

/// A user-facing auth error with a message safe to show in the UI.
class AuthException implements Exception {
  AuthException(this.message, {this.updateRequired = false});
  final String message;

  /// The brain needs a newer app for this login (HTTP 426 `update-app`): the
  /// sign-in screen says "Update the app" rather than "try again".
  final bool updateRequired;

  @override
  String toString() => message;
}

/// What a sign-in hands back: the bearer and, from a brain that says so, who
/// it is. `role` is `admin` or `member`; null from the frozen `mobile-login`
/// of an older brain (which serves admins only).
class SignInResult {
  const SignInResult({
    required this.token,
    this.role,
    this.loginId,
    this.brainId,
    this.email,
  });

  final String token;
  final String? role;
  final String? loginId;
  final String? brainId;

  /// Only a QR claim learns the email here; a password sign-in typed it.
  final String? email;

  static SignInResult fromJson(Map<String, dynamic> data) {
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw AuthException('Unexpected response from the server.');
    }
    String? text(String key) {
      final v = data[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    return SignInResult(
      token: token,
      role: text('role'),
      loginId: text('loginId'),
      brainId: text('brainId'),
      email: text('email'),
    );
  }
}

/// What a successful pairing claim hands back.
typedef PairingClaim = SignInResult;

/// The message for a 426 `update-app`: the brain serves this login to a
/// newer build only.
String updateAppMessage(Object? minBuild) {
  final build = minBuild is num ? minBuild.toInt() : null;
  return build == null
      ? 'Update Jackdaw to sign in with this login.'
      : 'Update Jackdaw to sign in with this login. This brain needs app '
          'build $build or newer.';
}

/// The brain's own `error` line on a refusal, when it sent one.
String? _brainError(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) return error.trim();
  }
  return null;
}

String? _reason(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final reason = data['reason'];
    if (reason is String) return reason;
  }
  return null;
}

/// 426 `update-app` as an [AuthException], or null for any other answer.
AuthException? _updateRequired(DioException e) {
  if (e.response?.statusCode != 426) return null;
  final data = e.response?.data;
  return AuthException(
    updateAppMessage(data is Map ? data['minBuild'] : null),
    updateRequired: true,
  );
}

/// A client login cannot use this app yet (403 `client-login`): the brain's
/// own words, or a plain line when it sent none.
AuthException? _clientLogin(DioException e) {
  if (e.response?.statusCode != 403) return null;
  if (_reason(e) != 'client-login') return null;
  return AuthException(
    _brainError(e) ?? 'This login cannot use this app.',
  );
}

const _unreachable =
    'Could not reach Mantle. Check the server URL and your connection.';
const _tooMany = 'Too many attempts. Try again in a minute.';

/// Thin wrapper over Mantle's mobile auth endpoints.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// Sign in with email and password, for any login the phone serves (an
  /// Admin user or a member): `POST /api/auth/device-login`, a 30-day token
  /// that rotates through the refresh route. A brain older than that route
  /// answers 404, and then the frozen `mobile-login` (admins only) is used.
  Future<SignInResult> signIn({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/device-login',
        data: {'email': email, 'password': password, 'deviceName': deviceName},
        // A 401 here is "wrong password", not "log out".
        options: Options(extra: const {'skipAuthHandler': true}),
      );
      return SignInResult.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return mobileLogin(
          email: email,
          password: password,
          deviceName: deviceName,
        );
      }
      throw _signInError(e);
    }
  }

  /// `POST /api/auth/mobile-login`: the frozen admin route, 1-year token.
  /// Only for a brain without `device-login`.
  Future<SignInResult> mobileLogin({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/mobile-login',
        data: {'email': email, 'password': password, 'deviceName': deviceName},
        options: Options(extra: const {'skipAuthHandler': true}),
      );
      return SignInResult.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      throw _signInError(e);
    }
  }

  AuthException _signInError(DioException e) {
    final update = _updateRequired(e);
    if (update != null) return update;
    final client = _clientLogin(e);
    if (client != null) return client;
    final code = e.response?.statusCode;
    if (code == 401) return AuthException('Invalid email or password.');
    if (code == 429) return AuthException(_tooMany);
    // Any other refusal the brain explains (an older brain's 403
    // `member-login`, for one) is shown in its words.
    if (code == 403) {
      return AuthException(_brainError(e) ?? 'This login cannot use this app.');
    }
    return AuthException(_unreachable);
  }

  /// `POST /api/auth/pair/claim`: trade a scanned pairing code for a bearer.
  /// The brain answers one generic failure for an unknown, expired or used
  /// code, and so do we: nothing here says which. A member's code needs this
  /// build's header (sent on every request); without it, or from an older
  /// build, the brain answers 426 and keeps the code for the new app.
  Future<SignInResult> claimPairing({
    required String code,
    required String deviceName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/pair/claim',
        data: {'code': code, 'deviceName': deviceName},
        options: Options(extra: const {'skipAuthHandler': true}),
      );
      return SignInResult.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      final update = _updateRequired(e);
      if (update != null) throw update;
      final client = _clientLogin(e);
      if (client != null) throw client;
      final code = e.response?.statusCode;
      if (code == 429) throw AuthException(_tooMany);
      if (code != null && code >= 400 && code < 500) {
        throw AuthException(
          "That code didn't work. Show a fresh one on the web app and scan "
          'again.',
        );
      }
      throw AuthException(_unreachable);
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
