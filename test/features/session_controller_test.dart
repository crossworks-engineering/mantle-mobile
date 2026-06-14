// SessionController: the app's auth gate. Real ServerConfig over in-memory
// Drift; TokenStore and AuthRepository mocked.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/auth/auth_repository.dart';
import 'package:mantle_companion/data/auth/token_store.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mantle_companion/data/db/database_provider.dart';
import 'package:mantle_companion/features/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStore extends Mock implements TokenStore {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AppDatabase db;
  late MockTokenStore tokenStore;
  late MockAuthRepository authRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tokenStore = MockTokenStore();
    authRepo = MockAuthRepository();
  });
  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokenStore),
        authRepositoryProvider.overrideWithValue(authRepo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('needsServer when no server URL is stored', () async {
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future), AuthStatus.needsServer);
  });

  test('loggedOut when the server is set but there is no token', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedOut);
  });

  test('loggedIn when both server and token are present', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedIn);
  });

  test('signIn delegates to the repository and flips to loggedIn', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // settle to loggedOut
    await c
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'jason@schoeman.me', password: 'pw');

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verify(() => authRepo.login(email: 'jason@schoeman.me', password: 'pw'))
        .called(1);
  });

  test('signOut revokes and flips to loggedOut', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // settle to loggedIn
    await c.read(sessionControllerProvider.notifier).signOut();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => authRepo.logout()).called(1);
  });
}
