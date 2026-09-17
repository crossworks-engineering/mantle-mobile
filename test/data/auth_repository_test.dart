// AuthRepository orchestration, with the API and token store both mocked.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/auth_api.dart';
import 'package:jackdaw/data/auth/auth_repository.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockTokenStore extends Mock implements TokenStore {}

void main() {
  late MockAuthApi api;
  late MockTokenStore store;
  late AuthRepository repo;

  setUp(() {
    api = MockAuthApi();
    store = MockTokenStore();
    repo = AuthRepository(api, store);
  });

  test('login mints a token and stores it securely', () async {
    when(() => api.mobileLogin(
          email: any(named: 'email'),
          password: any(named: 'password'),
          deviceName: any(named: 'deviceName'),
        )).thenAnswer((_) async => 'tok_123');
    when(() => store.write(any())).thenAnswer((_) async {});

    await repo.login(email: 'jason@schoeman.me', password: 'pw');

    verify(() => store.write('tok_123')).called(1);
  });

  test('claimPairing stores the token, labels the device, returns the email',
      () async {
    when(() => api.claimPairing(
          code: any(named: 'code'),
          deviceName: any(named: 'deviceName'),
        )).thenAnswer(
      (_) async => const PairingClaim(token: 'tok_qr', email: 'o@example.com'),
    );
    when(() => store.write(any())).thenAnswer((_) async {});

    final email = await repo.claimPairing('the-code');

    expect(email, 'o@example.com');
    verify(() => store.write('tok_qr')).called(1);
    final label = verify(() => api.claimPairing(
          code: 'the-code',
          deviceName: captureAny(named: 'deviceName'),
        )).captured.single as String;
    expect(label, startsWith('Jackdaw ('));
    expect(label, endsWith('paired by QR'));
  });

  test('claimPairing stores nothing when the server refuses the code',
      () async {
    when(() => api.claimPairing(
          code: any(named: 'code'),
          deviceName: any(named: 'deviceName'),
        )).thenThrow(AuthException('no'));

    await expectLater(repo.claimPairing('x'), throwsA(isA<AuthException>()));
    verifyNever(() => store.write(any()));
  });

  test('logout revokes server-side and clears the local token', () async {
    when(() => api.mobileLogout()).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});

    await repo.logout();

    verify(() => api.mobileLogout()).called(1);
    verify(() => store.clear()).called(1);
  });

  test('logout still clears the local token when the revoke fails', () async {
    when(() => api.mobileLogout()).thenThrow(Exception('offline'));
    when(() => store.clear()).thenAnswer((_) async {});

    await repo.logout();

    verify(() => store.clear()).called(1);
  });

  test('logout propagates a failure to clear the local token', () async {
    when(() => api.mobileLogout()).thenAnswer((_) async {});
    when(() => store.clear()).thenThrow(Exception('keychain'));

    await expectLater(repo.logout(), throwsA(isA<Exception>()));
  });
}
