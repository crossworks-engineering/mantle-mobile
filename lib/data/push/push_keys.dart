import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sodium/sodium.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'sodium_provider.dart';

part 'push_keys.g.dart';

/// The device's libsodium X25519 keypair for end-to-end push. The PUBLIC key
/// goes to Mantle (which seals each notification to it); the SECRET key stays in
/// the iOS Keychain under a **shared access group** so the Notification Service
/// Extension can read it to open the sealed box. We only ever GENERATE here —
/// sealing is Mantle's job, opening is the NSE's (Swift). Keys are STANDARD
/// base64 (matching Mantle's `base64_variants.ORIGINAL`).
///
/// The KEYPAIR is the device's: one, enrolled with every brain a login here
/// connects to, each brain sealing to the same public key. The SUBSCRIPTION ID
/// is a login's: each held login has its own, so connecting or disconnecting
/// notifications for one says nothing about the others.
class PushKeyStore {
  PushKeyStore(this._sodium, this._activeSessionId);

  final Sodium _sodium;

  /// Resolves the active session's id, or null when nobody is signed in.
  final Future<String?> Function() _activeSessionId;

  /// Shared iOS Keychain access group. MUST match the `keychain-access-groups`
  /// entitlement on BOTH the Runner and NotificationService targets —
  /// `$(AppIdentifierPrefix)crossworks.engineering.jackdaw.pushkeys` (the prefix
  /// resolves to team id `P6NLP32L8H`). See ios/PUSH_SETUP.md.
  static const _iosAccessGroup = 'P6NLP32L8H.crossworks.engineering.jackdaw.pushkeys';
  // Public so the Android background-isolate decryptor reads the same items.
  static const secretKeyKey = 'mantle_push_secret_key';
  static const publicKeyKey = 'mantle_push_public_key';
  /// The single marker every build before sessions wrote; adopted by the
  /// session migrated from that build (see [adoptLegacySubscription]).
  static const _legacySubscriptionIdKey = 'mantle_push_subscription_id';
  static String _subscriptionKeyFor(String sessionId) =>
      '$_legacySubscriptionIdKey.$sessionId';

  // first_unlock so the NSE (a background extension) can still read the key
  // after the device has been unlocked once since boot.
  // accountName fixes kSecAttrService to a known value ('mantle_push') so the
  // Swift NSE can query the exact same Keychain item (see ios/PUSH_SETUP.md).
  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        iOptions: IOSOptions(
          groupId: _iosAccessGroup,
          accountName: 'mantle_push',
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

  /// Return the device public key (base64), generating + persisting a fresh
  /// keypair the first time. Idempotent across repeated Connect taps.
  Future<String> ensureDeviceKeyPair() async {
    final existing = await _storage.read(key: publicKeyKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final keyPair = _sodium.crypto.box.keyPair();
    final publicB64 = base64.encode(keyPair.publicKey);
    final secretB64 = base64.encode(keyPair.secretKey.extractBytes());
    keyPair.secretKey.dispose();
    await _storage.write(key: secretKeyKey, value: secretB64);
    await _storage.write(key: publicKeyKey, value: publicB64);
    return publicB64;
  }

  Future<String?> publicKey() => _storage.read(key: publicKeyKey);

  /// The local id of THIS device's Mantle subscription — its presence is how we
  /// know this device is connected. Not a secret; kept alongside the keys.
  ///
  /// The ACTIVE login's, like everything the notifications screen shows.
  Future<String?> subscriptionId() async {
    final session = await _activeSessionId();
    if (session == null || session.isEmpty) return null;
    return _storage.read(key: _subscriptionKeyFor(session));
  }

  Future<void> setSubscriptionId(String id) async {
    final session = await _activeSessionId();
    if (session == null || session.isEmpty) return;
    await _storage.write(key: _subscriptionKeyFor(session), value: id);
  }

  /// One login's subscription id, for signing out of a login that is not the
  /// active one.
  Future<String?> subscriptionIdFor(String sessionId) =>
      _storage.read(key: _subscriptionKeyFor(sessionId));

  /// The update from the single-login build: its one marker belongs to the
  /// login that build was signed in as. Called once at start-up with THAT
  /// session (the migration makes it the active one), never lazily, so a login
  /// added later can not pick up someone else's subscription.
  Future<void> adoptLegacySubscription(String sessionId) async {
    final legacy = await _storage.read(key: _legacySubscriptionIdKey);
    if (legacy == null || legacy.isEmpty) return;
    final own = await _storage.read(key: _subscriptionKeyFor(sessionId));
    if (own == null || own.isEmpty) {
      await _storage.write(key: _subscriptionKeyFor(sessionId), value: legacy);
    }
    await _storage.delete(key: _legacySubscriptionIdKey);
  }

  /// Disconnect (or end) the ACTIVE login: its subscription marker goes. See
  /// [clearFor] for what happens to the keypair.
  Future<void> clear() async {
    final session = await _activeSessionId();
    if (session != null && session.isNotEmpty) await clearFor(session);
  }

  /// Drop one login's subscription marker. The keypair is the DEVICE's and
  /// stays while any other login is still connected; once none is, it goes
  /// too, and the NSE can no longer decrypt anything, exactly as before there
  /// were several logins.
  Future<void> clearFor(String sessionId) async {
    await _storage.delete(key: _subscriptionKeyFor(sessionId));
    await _storage.delete(key: _legacySubscriptionIdKey);
    final all = await _storage.readAll();
    final othersConnected = all.keys.any(
      (k) => k.startsWith('$_legacySubscriptionIdKey.'),
    );
    if (!othersConnected) {
      await _storage.delete(key: secretKeyKey);
      await _storage.delete(key: publicKeyKey);
    }
  }
}

@Riverpod(keepAlive: true)
Future<PushKeyStore> pushKeyStore(Ref ref) async {
  final sodium = await ref.watch(sodiumProvider.future);
  final db = ref.watch(appDatabaseProvider);
  return PushKeyStore(
    sodium,
    () => db.getSetting(AppDatabase.activeSessionKey),
  );
}
