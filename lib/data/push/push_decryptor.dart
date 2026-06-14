import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sodium_libs/sodium_libs.dart';

import 'push_keys.dart';

/// Opens a libsodium sealed box on **Android**, where decryption happens in a
/// Dart background isolate (iOS does it natively in the Notification Service
/// Extension). Reads the device keypair from secure storage (Android
/// Keystore-backed) and runs `crypto_box_seal_open`. Self-contained so it works
/// inside the FCM background isolate, where Riverpod providers aren't available.
class PushDecryptor {
  PushDecryptor(this._sodium, this._storage);

  final Sodium _sodium;
  final FlutterSecureStorage _storage;

  /// Build one from scratch (initializes libsodium). Safe to call in a
  /// background isolate.
  static Future<PushDecryptor> create() async {
    final sodium = await SodiumInit.init();
    return PushDecryptor(sodium, const FlutterSecureStorage());
  }

  /// Open `ctBase64` (the sealed box from the push `ct` field) → the payload
  /// map, or null if there's no key or the box doesn't open.
  Future<Map<String, dynamic>?> open(String ctBase64) async {
    final secB64 = await _storage.read(key: PushKeyStore.secretKeyKey);
    final pubB64 = await _storage.read(key: PushKeyStore.publicKeyKey);
    if (secB64 == null || pubB64 == null) return null;

    SecureKey? secret;
    try {
      secret = SecureKey.fromList(_sodium, base64.decode(secB64));
      final opened = _sodium.crypto.box.sealOpen(
        cipherText: base64.decode(ctBase64),
        publicKey: base64.decode(pubB64),
        secretKey: secret,
      );
      return jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
    } catch (_) {
      return null; // bad key / tampered / not for us
    } finally {
      secret?.dispose();
    }
  }
}
