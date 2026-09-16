// SessionController: the app's auth gate. Real ServerConfig over in-memory
// Drift; TokenStore, AuthRepository and SessionWipe mocked.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/auth_repository.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStore extends Mock implements TokenStore {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSessionWipe extends Mock implements SessionWipe {}

void main() {
  late AppDatabase db;
  late MockTokenStore tokenStore;
  late MockAuthRepository authRepo;
  late MockSessionWipe wipe;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tokenStore = MockTokenStore();
    authRepo = MockAuthRepository();
    wipe = MockSessionWipe();
    when(() => wipe.unpairPush()).thenAnswer((_) async {});
    when(() => wipe.wipeLocal()).thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokenStore),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionWipeProvider.overrideWithValue(wipe),
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
        .signIn(email: 'owner@example.com', password: 'pw');

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verify(() => authRepo.login(email: 'owner@example.com', password: 'pw'))
        .called(1);
  });

  test('signOut unpairs push, revokes, wipes, and flips to loggedOut', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // settle to loggedIn
    await c.read(sessionControllerProvider.notifier).signOut();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verifyInOrder([
      () => wipe.unpairPush(),
      () => authRepo.logout(),
      () => wipe.wipeLocal(),
    ]);
  });

  test('signOut keeps the session when the local wipe cannot clear the token',
      () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});
    when(() => wipe.wipeLocal()).thenThrow(Exception('keychain'));

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await expectLater(
      c.read(sessionControllerProvider.notifier).signOut(),
      throwsA(isA<Exception>()),
    );
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
  });

  test('sessionInvalidated flips to loggedOut and wipes locally, once', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    final n = c.read(sessionControllerProvider.notifier);
    await n.sessionInvalidated();
    await n.sessionInvalidated();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal()).called(1);
    verifyNever(() => wipe.unpairPush()); // no network from the 401 path
    verifyNever(() => authRepo.logout());
  });

  test('sessionInvalidated while already logged out does nothing', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => null);

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // loggedOut
    await c.read(sessionControllerProvider.notifier).sessionInvalidated();

    verifyNever(() => wipe.wipeLocal());
  });
}
