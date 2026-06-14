import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sodium_libs/sodium_libs.dart';

import 'sodium_provider.dart';

part 'push_keys.g.dart';

/// The device's libsodium X25519 keypair for end-to-end push. The PUBLIC key
/// goes to Mantle (which seals each notification to it); the SECRET key stays in
/// the iOS Keychain under a **shared access group** so the Notification Service
/// Extension can read it to open the sealed box. We only ever GENERATE here —
/// sealing is Mantle's job, opening is the NSE's (Swift). Keys are STANDARD
/// base64 (matching Mantle's `base64_variants.ORIGINAL`).
class PushKeyStore {
  PushKeyStore(this._sodium);

  final Sodium _sodium;

  /// Shared iOS Keychain access group. MUST match the `keychain-access-groups`
  /// entitlement on BOTH the Runner and NotificationService targets —
  /// `$(AppIdentifierPrefix)crossworks.engineering.mantle.pushkeys` (the prefix
  /// resolves to team id `P6NLP32L8H`). See ios/PUSH_SETUP.md.
  static const _iosAccessGroup = 'P6NLP32L8H.crossworks.engineering.mantle.pushkeys';
  static const _secretKeyKey = 'mantle_push_secret_key';
  static const _publicKeyKey = 'mantle_push_public_key';
  static const _subscriptionIdKey = 'mantle_push_subscription_id';

  // first_unlock so the NSE (a background extension) can still read the key
  // after the device has been unlocked once since boot.
  FlutterSecureStorage get _storage => const FlutterSecureStorage(
        iOptions: IOSOptions(
          groupId: _iosAccessGroup,
          accessibility: KeychainAccessibility.first_unlock,
        ),
      );

  /// Return the device public key (base64), generating + persisting a fresh
  /// keypair the first time. Idempotent across repeated Connect taps.
  Future<String> ensureDeviceKeyPair() async {
    final existing = await _storage.read(key: _publicKeyKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final keyPair = _sodium.crypto.box.keyPair();
    final publicB64 = base64.encode(keyPair.publicKey);
    final secretB64 = base64.encode(keyPair.secretKey.extractBytes());
    keyPair.secretKey.dispose();
    await _storage.write(key: _secretKeyKey, value: secretB64);
    await _storage.write(key: _publicKeyKey, value: publicB64);
    return publicB64;
  }

  Future<String?> publicKey() => _storage.read(key: _publicKeyKey);

  /// The local id of THIS device's Mantle subscription — its presence is how we
  /// know this device is connected. Not a secret; kept alongside the keys.
  Future<String?> subscriptionId() => _storage.read(key: _subscriptionIdKey);
  Future<void> setSubscriptionId(String id) =>
      _storage.write(key: _subscriptionIdKey, value: id);

  /// Drop the keypair + subscription marker (on disconnect / reset) — the NSE
  /// can no longer decrypt.
  Future<void> clear() async {
    await _storage.delete(key: _secretKeyKey);
    await _storage.delete(key: _publicKeyKey);
    await _storage.delete(key: _subscriptionIdKey);
  }
}

@Riverpod(keepAlive: true)
Future<PushKeyStore> pushKeyStore(Ref ref) async {
  final sodium = await ref.watch(sodiumProvider.future);
  return PushKeyStore(sodium);
}
