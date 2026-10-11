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

  /// Sign in with email and password (device-login, or the older brain's
  /// mobile-login) and store the bearer. Returns who the brain said it is.
  Future<SignInResult> login({
    required String email,
    required String password,
  }) async {
    final result = await _api.signIn(
      email: email,
      password: password,
      deviceName: _deviceName(),
    );
    await _tokenStore.write(result.token);
    return result;
  }

  /// Sign in with a pairing code scanned from the web app: same storage as
  /// [login]; the device label says how it got here. The answer carries the
  /// account email when the server sends one.
  Future<PairingClaim> claimPairing(String code) async {
    final claim = await _api.claimPairing(
      code: code,
      deviceName: '${_deviceName()} · paired by QR',
    );
    await _tokenStore.write(claim.token);
    return claim;
  }

  /// Revoke the token server-side, then clear it locally. The revoke is
  /// best-effort: with no network the user must still be able to sign out of
  /// the device, and the token expires on its own server-side. Clearing the
  /// local copy is the part that must succeed, so its failure propagates.
  Future<void> logout() async {
    try {
      await _api.mobileLogout();
    } catch (_) {
      /* offline or already revoked — the local wipe still goes ahead */
    }
    await _tokenStore.clear();
  }

  /// A human label for Mantle's device list, e.g. "Jackdaw (Ios)".
  String _deviceName() {
    final os = Platform.operatingSystem;
    final pretty = os.isEmpty ? 'mobile' : '${os[0].toUpperCase()}${os.substring(1)}';
    return 'Jackdaw ($pretty)';
  }
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepository(ref.watch(authApiProvider), ref.watch(tokenStoreProvider));
}
