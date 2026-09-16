import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'token_store.g.dart';

/// The Mantle bearer token, kept in the platform secure enclave (iOS Keychain /
/// Android Keystore) — never in plain prefs or the database.
class TokenStore {
  TokenStore(this._storage);

  final FlutterSecureStorage _storage;

  /// The secure-storage key. Public so a background isolate that has no
  /// provider container (the direct-push foreground service) can read the
  /// same item with [readDirect] instead of being handed a plain copy.
  static const key = 'mantle_bearer_token';

  Future<String?> read() => _storage.read(key: key);
  Future<void> write(String token) => _storage.write(key: key, value: token);
  Future<void> clear() => _storage.delete(key: key);

  /// Read the token straight from secure storage, for isolates without a
  /// [Ref]. Same item, same enclave.
  static Future<String?> readDirect() =>
      const FlutterSecureStorage().read(key: key);
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) {
  return TokenStore(const FlutterSecureStorage());
}
