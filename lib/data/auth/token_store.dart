import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';

part 'token_store.g.dart';

/// The Mantle bearer tokens, kept in the platform secure enclave (iOS Keychain /
/// Android Keystore) — never in plain prefs or the database.
///
/// One item per login this device holds, keyed by session id. [read], [write]
/// and [clear] are a VIEW over the active session, so everything that only
/// wants "the bearer to send" (the Dio client, sign-in, sign-out) never needs
/// to know there can be more than one.
class TokenStore {
  TokenStore(this._storage, this._activeSessionId);

  final FlutterSecureStorage _storage;

  /// Resolves the active session's id, or null when nobody is signed in.
  final Future<String?> Function() _activeSessionId;

  /// The single item every build before sessions wrote. Read once more, at
  /// start-up ([adoptLegacy]), to move it under the session it belongs to.
  static const legacyKey = 'mantle_bearer_token';

  /// The secure-storage key for one session's bearer. Public so a background
  /// isolate that has no provider container (the direct-push foreground
  /// service) can read the same item with [readDirect] instead of being handed
  /// a plain copy.
  static String keyFor(String sessionId) => '$legacyKey.$sessionId';

  /// The active session's bearer. Only ever that session's own item: the
  /// single-login build's item is never read here (see [adoptLegacy]).
  Future<String?> read() async {
    final id = await _activeSessionId();
    if (id == null || id.isEmpty) return null;
    final held = await _storage.read(key: keyFor(id));
    return (held == null || held.isEmpty) ? null : held;
  }

  /// The update from the single-login build: move its keychain item under
  /// [owner], the session the v3 migration made from that build's saved
  /// server, so updating the app signs nobody out. Written before the old
  /// item is deleted, so there is no moment at which the bearer is in
  /// neither place.
  ///
  /// With no [owner] (the session is gone) the old item is deleted and
  /// nothing adopts it. An iOS reinstall records no owner at all: the
  /// Keychain outlives the app, the database does not, and the item belongs
  /// to whatever brain the old install used. Adopting it for the next sign-in
  /// would send that brain's bearer to another.
  Future<void> adoptLegacy({String? owner}) async {
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null) return;
    if (owner != null && owner.isNotEmpty && legacy.isNotEmpty) {
      final held = await _storage.read(key: keyFor(owner));
      if (held == null || held.isEmpty) {
        await _storage.write(key: keyFor(owner), value: legacy);
      }
    }
    await _storage.delete(key: legacyKey);
  }

  /// Store the active session's bearer. The session layer makes a session
  /// active BEFORE a sign-in mints its token, so there is always one to write
  /// to; with none, the token is dropped rather than parked where a later
  /// login could adopt it as its own.
  ///
  /// A single-login build's item still here was never adopted (no migrated
  /// owner: an iOS reinstall), so it is another brain's and goes now.
  Future<void> write(String token) async {
    final id = await _activeSessionId();
    if (id == null || id.isEmpty) return;
    await _storage.write(key: keyFor(id), value: token);
    await _storage.delete(key: legacyKey);
  }

  /// Forget the active session's bearer, and the pre-session item if one is
  /// somehow still there. Other logins are not this call's to touch.
  Future<void> clear() async {
    final id = await _activeSessionId();
    if (id != null && id.isNotEmpty) await _storage.delete(key: keyFor(id));
    await _storage.delete(key: legacyKey);
  }

  Future<String?> readFor(String sessionId) => _storage.read(key: keyFor(sessionId));

  /// Store [token] as [sessionId]'s bearer, whichever login is active: a
  /// refreshed token belongs to the login that asked for it.
  Future<void> writeFor(String sessionId, String token) =>
      _storage.write(key: keyFor(sessionId), value: token);
  Future<void> clearFor(String sessionId) => _storage.delete(key: keyFor(sessionId));

  /// Read one session's token straight from secure storage, for isolates
  /// without a [Ref]. Same item, same enclave. The id is not a secret and
  /// travels to the isolate the way the base URL does.
  static Future<String?> readDirect(String sessionId) =>
      const FlutterSecureStorage().read(key: keyFor(sessionId));
}

@Riverpod(keepAlive: true)
TokenStore tokenStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return TokenStore(
    const FlutterSecureStorage(),
    () => db.getSetting(AppDatabase.activeSessionKey),
  );
}
