// SessionController: the app's auth gate. Real ServerConfig over in-memory
// Drift; TokenStore, AuthRepository and SessionWipe mocked.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/auth_api.dart';
import 'package:jackdaw/data/auth/auth_repository.dart';
import 'package:jackdaw/data/auth/pairing_payload.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';
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
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async {});
    when(() => wipe.stopActiveServices()).thenAnswer((_) async {});
    when(() => tokenStore.clearFor(any())).thenAnswer((_) async {});
    when(() => tokenStore.readFor(any())).thenAnswer((_) async => null);
    when(() => tokenStore.adoptLegacy(owner: any(named: 'owner')))
        .thenAnswer((_) async {});
  });
  tearDown(() => db.close());

  /// A signed-in device as the app leaves it: a session row, made active,
  /// with the two settings that mirror it.
  Future<String> seedSignedIn({String email = 'owner@example.com'}) async {
    const id = 'session-1';
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            baseUrl: 'https://m.example.com',
            email: Value(email),
            addedAt: now,
            lastUsedAt: now,
          ),
        );
    await db.setSetting('active_session_id', id);
    await db.setSetting('server_base_url', 'https://m.example.com');
    await db.setSetting('account_email', email);
    return id;
  }

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
        )).thenAnswer((_) async => const SignInResult(token: 't'));

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // settle to loggedOut
    await c
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'owner@example.com', password: 'pw');

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verify(() => authRepo.login(email: 'owner@example.com', password: 'pw'))
        .called(1);
    // Settings shows who is signed in from this.
    expect(await db.getSetting('account_email'), 'owner@example.com');
    expect(await c.read(accountEmailProvider.future), 'owner@example.com');
  });

  test('a member\'s sign-in is remembered as a member before whoami answers',
      () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer(
      (_) async => const SignInResult(token: 't', role: 'member'),
    );

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await c
        .read(sessionControllerProvider.notifier)
        .signIn(email: 'mia@example.invalid', password: 'pw');

    final id = (await db.getSetting('active_session_id'))!;
    final hint = await readCachedAccess(db, id);
    expect(hint?.role, LoginRole.member);
    expect(hint?.ownerContent, isFalse);
  });

  test('a QR sign-in (no role in the answer) leaves nothing to guess from',
      () async {
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => authRepo.claimPairing(any())).thenAnswer(
      (_) async => const PairingClaim(token: 't', email: 'mia@example.invalid'),
    );
    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).signInWithPairing(
          const PairingPayload(server: 'https://qr.example.com', code: 'c1'),
        );
    final id = (await db.getSetting('active_session_id'))!;
    expect(await readCachedAccess(db, id), isNull);
  });

  test('signInWithPairing sets the server from the QR, claims, flips to '
      'loggedIn and remembers the email', () async {
    // Fresh install: no server yet.
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => authRepo.claimPairing(any())).thenAnswer(
      (_) async => const PairingClaim(token: 't', email: 'owner@example.com'),
    );

    final c = makeContainer();
    expect(await c.read(sessionControllerProvider.future),
        AuthStatus.needsServer);
    await c.read(sessionControllerProvider.notifier).signInWithPairing(
          const PairingPayload(server: 'https://qr.example.com', code: 'c1'),
        );

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(await db.getSetting('server_base_url'), 'https://qr.example.com');
    verify(() => authRepo.claimPairing('c1')).called(1);
    expect(await c.read(accountEmailProvider.future), 'owner@example.com');
  });

  test('signInWithPairing keeps the server but not the session when the '
      'code is refused', () async {
    when(() => tokenStore.read()).thenAnswer((_) async => null);
    when(() => authRepo.claimPairing(any())).thenThrow(AuthException('no'));

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await expectLater(
      c.read(sessionControllerProvider.notifier).signInWithPairing(
            const PairingPayload(server: 'https://qr.example.com', code: 'c1'),
          ),
      throwsA(isA<AuthException>()),
    );

    expect(await db.getSetting('server_base_url'), 'https://qr.example.com');
    // The server is set, so the gate lands on login, not setup.
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedOut);
    expect(await c.read(accountEmailProvider.future), isNull);
  });

  test('signOut unpairs push, revokes, wipes, and flips to loggedOut', () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // settle to loggedIn
    await c.read(sessionControllerProvider.notifier).signOut();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verifyInOrder([
      () => wipe.unpairPush(),
      () => authRepo.logout(),
      () => wipe.wipeLocal(sessionId: any(named: 'sessionId')),
    ]);
  });

  test('signOut forgets the account email', () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).signOut();

    expect(await c.read(accountEmailProvider.future), isNull);
  });

  test('changeServer signs out, forgets the address, and lands on needsServer',
      () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).changeServer();

    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
    expect(await db.getSetting('server_base_url'), '');
    expect(
      await c.read(sessionControllerProvider.future),
      AuthStatus.needsServer,
    );
  });

  test('changeServer keeps the address when the local wipe fails', () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).thenThrow(Exception('keychain'));

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await expectLater(
      c.read(sessionControllerProvider.notifier).changeServer(),
      throwsA(isA<Exception>()),
    );
    expect(await db.getSetting('server_base_url'), 'https://m.example.com');
  });

  test('signOut keeps the session when the local wipe cannot clear the token',
      () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    when(() => authRepo.logout()).thenAnswer((_) async {});
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).thenThrow(Exception('keychain'));

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    await expectLater(
      c.read(sessionControllerProvider.notifier).signOut(),
      throwsA(isA<Exception>()),
    );
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
  });

  test('sessionInvalidated flips to loggedOut and wipes locally, once', () async {
    await seedSignedIn();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');

    final c = makeContainer();
    await c.read(sessionControllerProvider.future);
    final n = c.read(sessionControllerProvider.notifier);
    await n.sessionInvalidated();
    await n.sessionInvalidated();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
    verifyNever(() => wipe.unpairPush()); // no network from the 401 path
    verifyNever(() => authRepo.logout());
  });

  test('sessionInvalidated while already logged out does nothing', () async {
    await db.setSetting('server_base_url', 'https://m.example.com');
    when(() => tokenStore.read()).thenAnswer((_) async => null);

    final c = makeContainer();
    await c.read(sessionControllerProvider.future); // loggedOut
    await c.read(sessionControllerProvider.notifier).sessionInvalidated();

    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });
}
