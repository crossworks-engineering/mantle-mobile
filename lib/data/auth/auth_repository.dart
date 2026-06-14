import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_api.dart';
import 'token_store.dart';

part 'auth_repository.g.dart';

/// Orchestrates auth: logs in (mints a token, stores it securely) and logs out
/// (revokes server-side, clears local). Pure orchestration over [AuthApi] +
/// [TokenStore], so it's trivially testable with both mocked.
class AuthRepository {
  AuthRepository(this._api, this._tokenStore);

  final AuthApi _api;
  final TokenStore _tokenStore;

  Future<void> login({required String email, required String password}) async {
    final token = await _api.mobileLogin(
      email: email,
      password: password,
      deviceName: _deviceName(),
    );
    await _tokenStore.write(token);
  }

  Future<void> logout() async {
    await _api.mobileLogout();
    await _tokenStore.clear();
  }

  /// A human label for Mantle's device list, e.g. "Mantle Companion (Ios)".
  String _deviceName() {
    final os = Platform.operatingSystem;
    final pretty = os.isEmpty ? 'mobile' : '${os[0].toUpperCase()}${os.substring(1)}';
    return 'Mantle Companion ($pretty)';
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(authApiProvider), ref.watch(tokenStoreProvider));
}
