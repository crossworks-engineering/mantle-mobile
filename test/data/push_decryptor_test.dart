// PushDecryptor opens the sealed box in a push's `ct` with this device's
// keypair. With libsodium and the keychain both mocked, this pins the
// contract: no keys → null without touching sodium; a box that will not
// open → null; a good one → the JSON payload; and the secret key is wiped
// from memory on every path.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/push_decryptor.dart';
import 'package:jackdaw/data/push/push_keys.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sodium/sodium.dart';

class MockSodium extends Mock implements Sodium {}

class MockCrypto extends Mock implements Crypto {}

class MockBox extends Mock implements Box {}

class MockSecureKey extends Mock implements SecureKey {}

class MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSodium sodium;
  late MockBox box;
  late MockSecureKey secret;
  late MockStorage storage;
  late PushDecryptor decryptor;

  final secretBytes = Uint8List.fromList(List.filled(32, 1));
  final publicBytes = Uint8List.fromList(List.filled(32, 2));
  final ct = base64.encode(Uint8List.fromList(List.filled(48, 3)));

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(MockSecureKey());
  });

  setUp(() {
    sodium = MockSodium();
    box = MockBox();
    secret = MockSecureKey();
    storage = MockStorage();
    final crypto = MockCrypto();
    when(() => sodium.crypto).thenReturn(crypto);
    when(() => crypto.box).thenReturn(box);
    when(() => sodium.secureCopy(any())).thenReturn(secret);
    when(() => secret.dispose()).thenReturn(null);
    decryptor = PushDecryptor(sodium, storage);
  });

  void keysPresent() {
    when(() => storage.read(key: PushKeyStore.secretKeyKey))
        .thenAnswer((_) async => base64.encode(secretBytes));
    when(() => storage.read(key: PushKeyStore.publicKeyKey))
        .thenAnswer((_) async => base64.encode(publicBytes));
  }

  test('no keypair on the device → null, and sodium is never asked', () async {
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    expect(await decryptor.open(ct), isNull);
    verifyNever(() => sodium.secureCopy(any()));
  });

  test('a box that opens → the JSON payload, secret wiped after', () async {
    keysPresent();
    when(() => box.sealOpen(
          cipherText: any(named: 'cipherText'),
          publicKey: any(named: 'publicKey'),
          secretKey: any(named: 'secretKey'),
        )).thenReturn(
      Uint8List.fromList(utf8.encode('{"title":"Hi","route":"/chat/saskia"}')),
    );
    final payload = await decryptor.open(ct);
    expect(payload, {'title': 'Hi', 'route': '/chat/saskia'});
    verify(() => sodium.secureCopy(secretBytes)).called(1);
    verify(() => box.sealOpen(
          cipherText: base64.decode(ct),
          publicKey: publicBytes,
          secretKey: secret,
        )).called(1);
    verify(() => secret.dispose()).called(1);
  });

  test('a box that will not open (wrong key, tampered) → null, secret wiped',
      () async {
    keysPresent();
    when(() => box.sealOpen(
          cipherText: any(named: 'cipherText'),
          publicKey: any(named: 'publicKey'),
          secretKey: any(named: 'secretKey'),
        )).thenThrow(Exception('sealOpen failed'));
    expect(await decryptor.open(ct), isNull);
    verify(() => secret.dispose()).called(1);
  });

  test('a box that opens to something that is not JSON → null', () async {
    keysPresent();
    when(() => box.sealOpen(
          cipherText: any(named: 'cipherText'),
          publicKey: any(named: 'publicKey'),
          secretKey: any(named: 'secretKey'),
        )).thenReturn(Uint8List.fromList(utf8.encode('not json')));
    expect(await decryptor.open(ct), isNull);
    verify(() => secret.dispose()).called(1);
  });
}
