// AuthRepository orchestration, with the API and token store both mocked.

import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/auth/auth_api.dart';
import 'package:mantle_companion/data/auth/auth_repository.dart';
import 'package:mantle_companion/data/auth/token_store.dart';
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

  test('logout revokes server-side and clears the local token', () async {
    when(() => api.mobileLogout()).thenAnswer((_) async {});
    when(() => store.clear()).thenAnswer((_) async {});

    await repo.logout();

    verify(() => api.mobileLogout()).called(1);
    verify(() => store.clear()).called(1);
  });
}
