// SessionController with several logins held: add, cancel, switch, sign out,
// a refused bearer. Real SessionRepository and TokenStore (in-memory Drift and
// the secure-storage mock); AuthRepository and SessionWipe mocked, with the
// mocked login writing a token the way the real one does.

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/data/auth/auth_api.dart';
import 'package:jackdaw/data/auth/auth_repository.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSessionWipe extends Mock implements SessionWipe {}

const _brain = 'https://m.example.com';
const _other = 'https://other.example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthRepository authRepo;
  late MockSessionWipe wipe;
  late ProviderContainer c;
  var minted = 0;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    authRepo = MockAuthRepository();
    wipe = MockSessionWipe();
    minted = 0;
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionWipeProvider.overrideWithValue(wipe),
      ],
    );
    when(() => wipe.unpairPush()).thenAnswer((_) async {});
    when(() => wipe.stopActiveServices()).thenAnswer((_) async {});
    // The real wipe clears the login's bearer; the rest is not under test.
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')))
        .thenAnswer((inv) async {
      final id = inv.namedArguments[#sessionId] as String?;
      if (id != null) await c.read(tokenStoreProvider).clearFor(id);
    });
    when(() => authRepo.logout()).thenAnswer((_) async {});
    when(() => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {
      final token = 'tok-${++minted}';
      await c.read(tokenStoreProvider).write(token);
      return SignInResult(token: token, role: 'admin');
    });
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  SessionController controller() =>
      c.read(sessionControllerProvider.notifier);
  SessionRepository sessions() => c.read(sessionRepositoryProvider);

  Future<String> signInFresh(String server, String email) async {
    await controller().setServer(server);
    await c.read(sessionControllerProvider.future);
    await controller().signIn(email: email, password: 'pw');
    return (await sessions().activeId())!;
  }

  test('adding a login steps out first, so no bearer rides along, then holds '
      'both', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');

    await controller().startAddLogin();
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    expect(controller().isAddingLogin, isTrue);
    expect(await c.read(tokenStoreProvider).read(), isNull);
    verify(() => wipe.stopActiveServices()).called(1);

    await controller().signIn(email: 'b@example.com', password: 'pw');

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(controller().isAddingLogin, isFalse);
    final held = await c.read(heldSessionsProvider.future);
    expect(held.map((h) => h.session.email), ['b@example.com', 'a@example.com']);
    expect(held.first.active, isTrue);
    expect(await c.read(tokenStoreProvider).readFor(a), 'tok-1');
    expect(await c.read(accountEmailProvider.future), 'b@example.com');
  });

  test('cancelling goes back to the login that was in use', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');

    await controller().startAddLogin();
    await controller().cancelAddLogin();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(await sessions().activeId(), a);
    expect(await sessions().list(), hasLength(1));
  });

  test('a wrong password while adding leaves the held login untouched',
      () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    when(() => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(AuthException('no'));

    await expectLater(
      controller().signIn(email: 'b@example.com', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );

    expect((await sessions().list()).map((s) => s.id), [a]);
    expect(await c.read(tokenStoreProvider).readFor(a), 'tok-1');
    // Still on the login screen, still able to go back.
    expect(controller().isAddingLogin, isTrue);
    await controller().cancelAddLogin();
    expect(await sessions().activeId(), a);
  });

  test('switching to a login on the SAME brain builds a new client, so '
      'nothing fetched as the last login is served to this one', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    await controller().signIn(email: 'b@example.com', password: 'pw');

    final before = c.read(dioProvider);
    expect(await controller().switchTo(a), isTrue);

    expect(identical(c.read(dioProvider), before), isFalse);
    expect(await c.read(tokenStoreProvider).read(), 'tok-1');
    expect(await c.read(accountEmailProvider.future), 'a@example.com');
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
  });

  test('switching to a login on ANOTHER brain moves the server address',
      () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    await controller().changeServer(); // nobody active: only the address goes
    expect(await sessions().list(), hasLength(1));
    await signInFresh(_other, 'a@example.com');
    expect(await db.getSetting('server_base_url'), _other);

    await controller().switchTo(a);
    expect(await db.getSetting('server_base_url'), _brain);
    expect(await sessions().list(), hasLength(2));
  });

  test('a bearer is never attached to a request for a different brain',
      () async {
    await c.read(sessionControllerProvider.future);
    await signInFresh(_brain, 'a@example.com');
    final dio = c.read(dioProvider);
    // The client still points at the first brain; the active login no longer
    // does. This is the moment a switch between brains passes through.
    final begun = await sessions().beginSignIn(
      baseUrl: _other,
      email: 'a@example.com',
    );
    await c.read(tokenStoreProvider).write('tok-other');
    await sessions().completeSignIn(begun.session.id);

    final seen = <String?>[];
    dio.httpClientAdapter = _RecordingAdapter(seen);
    await dio.get<void>('/api/version');
    expect(dio.options.baseUrl, _brain);
    expect(seen, [null]);
  });

  test('signing out lands on the next login held here', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    await controller().signIn(email: 'b@example.com', password: 'pw');

    await controller().signOut();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(await sessions().activeId(), a);
    expect((await sessions().list()).map((s) => s.email), ['a@example.com']);
  });

  test('signing out of the last login lands on loggedOut, brain kept',
      () async {
    await c.read(sessionControllerProvider.future);
    await signInFresh(_brain, 'a@example.com');
    await controller().signOut();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    expect(await sessions().list(), isEmpty);
    expect(await db.getSetting('server_base_url'), _brain);
  });

  test('a refused bearer marks only the active login, switches to nobody, '
      'and tells the login screen who to sign back in as', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    await controller().signIn(email: 'b@example.com', password: 'pw');
    final b = (await sessions().activeId())!;

    await controller().sessionInvalidated();

    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    expect((await sessions().byId(b))?.needsSignIn, isTrue);
    expect((await sessions().byId(a))?.needsSignIn, isFalse);
    expect(await c.read(tokenStoreProvider).readFor(a), 'tok-1');
    expect(await sessions().activeId(), isNull);
    expect(c.read(pendingLoginEmailProvider), 'b@example.com');
  });

  // M2: the way back to a held login survives the app being killed.
  test('adding a login, then the app is killed: after the restart the way '
      'back is still offered and works', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();

    // A new process: a fresh container over the same storage.
    final restarted = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionWipeProvider.overrideWithValue(wipe),
      ],
    );
    addTearDown(restarted.dispose);
    expect(
      await restarted.read(sessionControllerProvider.future),
      AuthStatus.loggedOut,
    );
    final again = restarted.read(sessionControllerProvider.notifier);
    expect(again.isAddingLogin, isTrue);

    await again.cancelAddLogin();
    expect(restarted.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(await restarted.read(sessionRepositoryProvider).activeId(), a);
    expect(await db.getSetting(AppDatabase.resumeSessionKey), '');
  });

  test('after a refused bearer, another held login is a tap away, no '
      'password', () async {
    await c.read(sessionControllerProvider.future);
    final a = await signInFresh(_brain, 'a@example.com');
    await controller().startAddLogin();
    await controller().signIn(email: 'b@example.com', password: 'pw');

    await controller().sessionInvalidated();
    final held = await c.read(heldSessionsProvider.future);
    expect(held.map((h) => h.session.id), contains(a));

    expect(await controller().switchTo(a), isTrue);
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    expect(await sessions().activeId(), a);
  });

  test('a stored way back to a login that is no longer held is dropped',
      () async {
    await db.setSetting(AppDatabase.resumeSessionKey, 'gone');
    await c.read(sessionControllerProvider.future);
    expect(controller().isAddingLogin, isFalse);
    expect(await db.getSetting(AppDatabase.resumeSessionKey), '');
  });
}

/// Records the Authorization header of each request and answers 200.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.seen);

  final List<String?> seen;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options.headers['Authorization'] as String?);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
