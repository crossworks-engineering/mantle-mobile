import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_store.g.dart';

/// The Mantle bearer token, kept in the platform secure enclave (iOS Keychain /
/// Android Keystore) — never in plain prefs or the database.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'mantle_bearer_token';

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) {
  return TokenStore(const FlutterSecureStorage());
}
