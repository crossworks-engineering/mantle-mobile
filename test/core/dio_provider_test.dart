// The auth interceptor: the one place a dead token turns into a signed-out,
// wiped device. Real ServerConfig + SessionController over in-memory Drift;
// the token store and the wipe are mocked; the network is a stub adapter.

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/core/network/mobile_build.dart';
import 'package:jackdaw/data/auth/token_refresh.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/server/server_config.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:jackdaw/features/auth/session_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/stub_dio.dart';

class MockTokenStore extends Mock implements TokenStore {}

class MockSessionWipe extends Mock implements SessionWipe {}

/// Answers every request with one fixed status + headers.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, {this.headers = const {}});

  final int status;
  final Map<String, List<String>> headers;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString('', status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

/// Answers each request with whatever [answer] decides, when it decides.
class _FnAdapter implements HttpClientAdapter {
  _FnAdapter(this.answer);

  final Future<int> Function(RequestOptions options) answer;
  final List<RequestOptions> seen = [];

  List<String?> get bearers => [
        for (final o in seen) o.headers['Authorization'] as String?,
      ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return ResponseBody.fromString('', await answer(options));
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late MockTokenStore tokenStore;
  late MockSessionWipe wipe;
  // The brain's answer to a token refresh, and every refresh asked for. By
  // default the token is dead (401), as for any token a request was refused.
  late StubAnswer Function(RequestOptions) refreshAnswer;
  late List<RequestOptions> refreshes;

  setUp(() async {
    refreshAnswer = (_) => (status: 401, body: '{}');
    refreshes = [];
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.setSetting('server_base_url', 'https://m.example.com');
    // The login that server address belongs to: the client attaches a bearer
    // only when the active session is for the brain it is talking to.
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'session-1',
            baseUrl: 'https://m.example.com',
            addedAt: now,
            lastUsedAt: now,
          ),
        );
    await db.setSetting('active_session_id', 'session-1');
    tokenStore = MockTokenStore();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    wipe = MockSessionWipe();
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async {});
    when(() => wipe.stopActiveServices()).thenAnswer((_) async {});
    when(() => tokenStore.clearFor(any())).thenAnswer((_) async {});
    when(() => tokenStore.readFor(any())).thenAnswer((_) async => null);
    when(() => tokenStore.adoptLegacy(owner: any(named: 'owner')))
        .thenAnswer((_) async {});
    when(() => tokenStore.readFor('session-1')).thenAnswer((_) async => 'tok');
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokenStore),
        sessionWipeProvider.overrideWithValue(wipe),
        identityDioFactoryProvider.overrideWithValue(
          (baseUrl) => Dio(BaseOptions(baseUrl: baseUrl))
            ..httpClientAdapter = StubAdapter((o) {
              refreshes.add(o);
              return refreshAnswer(o);
            }),
        ),
      ];

  Future<(ProviderContainer, Dio)> boot(_StubAdapter adapter) async {
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    await c.read(serverConfigProvider.future);
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedIn);
    final dio = c.read(dioProvider)..httpClientAdapter = adapter;
    return (c, dio);
  }

  test('names the phone build on every request', () async {
    MobileBuild.debugOverride('1.15.0+27');
    addTearDown(MobileBuild.debugReset);
    final adapter = _StubAdapter(200);
    final (_, dio) = await boot(adapter);
    await dio.get<void>('/api/x');
    expect(adapter.last?.headers[kMobileBuildHeader], '1.15.0+27');
  });

  test('a request waits while the bearer is being rotated', () async {
    final adapter = _StubAdapter(200);
    final (c, dio) = await boot(adapter);
    final release = Completer<void>();
    final rotation = c
        .read(tokenRefreshGateProvider)
        .run('session-1', () => release.future);
    var sent = false;
    final request = dio.get<void>('/api/x').then((_) => sent = true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(sent, isFalse);
    expect(adapter.last, isNull);
    release.complete();
    await rotation;
    await request;
    expect(sent, isTrue);
  });

  test('injects the bearer on every request', () async {
    final adapter = _StubAdapter(200);
    final (_, dio) = await boot(adapter);
    await dio.get<void>('/api/x');
    expect(adapter.last?.headers['Authorization'], 'Bearer tok');
    expect(adapter.last?.uri.toString(), 'https://m.example.com/api/x');
  });

  test('a 401 ends the session and wipes the device', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });

  test('a redirect to /login ends the session too', () async {
    final (c, dio) = await boot(
      _StubAdapter(302, headers: {'location': ['/login?next=%2F']}),
    );
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });

  test('a redirect elsewhere is an ordinary error', () async {
    final (c, dio) = await boot(
      _StubAdapter(302, headers: {'location': ['/pages/login-notes']}),
    );
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });

  test('a 401 on a request that opted out (login) is left alone', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    await expectLater(
      dio.get<void>('/api/auth/mobile-login',
          options: Options(extra: {'skipAuthHandler': true})),
      throwsA(isA<DioException>()),
    );
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });

  test('a burst of 401s wipes once', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    for (var i = 0; i < 3; i++) {
      await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    }
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });

  test('a 401 on a request that went out bare (mid-switch to another brain) '
      'signs nobody out', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    // The login in use is now on another brain; this client is the old one.
    await (db.update(db.sessions)..where((s) => s.id.equals('session-1')))
        .write(const SessionsCompanion(
            baseUrl: Value('https://other.example.com')));
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });

  group('a token rotation under requests on their way', () {
    late String current;

    setUp(() {
      current = 'tok';
      when(() => tokenStore.readFor('session-1'))
          .thenAnswer((_) async => current);
      when(() => tokenStore.writeFor('session-1', any()))
          .thenAnswer((inv) async => current = inv.positionalArguments[1] as String);
    });

    Future<(ProviderContainer, Dio)> bootFn(_FnAdapter adapter) async {
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      await c.read(serverConfigProvider.future);
      await c.read(sessionControllerProvider.future);
      final dio = c.read(dioProvider)..httpClientAdapter = adapter;
      return (c, dio);
    }

    test('concurrent requests during a refresh never send the old token once '
        'the rotation has started, and the refresh waits for the ones already '
        'sent', () async {
      final slow = Completer<void>();
      final adapter = _FnAdapter((o) async {
        if (o.path == '/api/slow') await slow.future;
        return 200;
      });
      final (c, dio) = await bootFn(adapter);
      final gate = c.read(tokenRefreshGateProvider);

      final inFlight = dio.get<void>('/api/slow');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.bearers, ['Bearer tok']);
      expect(gate.sending('session-1'), 1);

      var posted = false;
      final rotation = gate.run('session-1', () async {
        posted = true;
        current = 'tok-new';
      });
      final more = [dio.get<void>('/api/a'), dio.get<void>('/api/b')];
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // The old bearer is still on its way: no refresh, and nothing new
      // leaves while the gate is closed.
      expect(posted, isFalse);
      expect(adapter.seen, hasLength(1));

      slow.complete();
      await inFlight;
      await rotation;
      await Future.wait(more);

      expect(posted, isTrue);
      expect(adapter.bearers, ['Bearer tok', 'Bearer tok-new', 'Bearer tok-new']);
      expect(gate.sending('session-1'), 0);
    });

    test('a bearer read just before the rotation began is read again',
        () async {
      final adapter = _FnAdapter((o) async => 200);
      final (c, dio) = await bootFn(adapter);
      final gate = c.read(tokenRefreshGateProvider);
      final firstRead = Completer<void>();
      var reads = 0;
      when(() => tokenStore.readFor('session-1')).thenAnswer((_) async {
        final value = current;
        if (++reads == 1) await firstRead.future;
        return value;
      });

      final request = dio.get<void>('/api/x');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final rotate = Completer<void>();
      final rotation = gate.run('session-1', () async {
        await rotate.future;
        current = 'tok-new';
      });
      // The read returns the old token while the rotation runs.
      firstRead.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.seen, isEmpty);
      rotate.complete();
      await rotation;
      await request;

      expect(adapter.bearers, ['Bearer tok-new']);
    });

    test('a 401 sent with a bearer rotated meanwhile retries once with the '
        'new one, and signs nobody out', () async {
      final adapter = _FnAdapter((o) async {
        if (o.headers['Authorization'] == 'Bearer tok') {
          current = 'tok-new'; // the rotation landed while this was out
          return 401;
        }
        return 200;
      });
      final (c, dio) = await bootFn(adapter);

      final res = await dio.get<void>('/api/x');

      expect(res.statusCode, 200);
      expect(adapter.bearers, ['Bearer tok', 'Bearer tok-new']);
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
      verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
    });

    test('a stale-header retry happens once only', () async {
      var n = 0;
      final adapter = _FnAdapter((o) async {
        current = 'tok-${++n}'; // rotated under every try
        return 401;
      });
      final (c, dio) = await bootFn(adapter);

      await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));

      expect(adapter.seen, hasLength(2));
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    });

    test('a 401 with the bearer still in use ends the session as before',
        () async {
      final adapter = _FnAdapter((o) async => 401);
      final (c, dio) = await bootFn(adapter);

      await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));

      expect(adapter.seen, hasLength(1));
      // The brain was asked about the token once, and refused it too.
      expect(refreshes.single.headers['Authorization'], 'Bearer tok');
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
      expect(c.read(tokenRefreshGateProvider).sending('session-1'), 0);
    });

    test('a 401 with the bearer in use refreshes once first: a new token '
        'asks again with it, and signs nobody out', () async {
      refreshAnswer = (_) => (status: 200, body: '{"token":"tok-new"}');
      final adapter = _FnAdapter(
        (o) async => o.headers['Authorization'] == 'Bearer tok' ? 401 : 200,
      );
      final (c, dio) = await bootFn(adapter);

      final res = await dio.get<void>('/api/x');

      expect(res.statusCode, 200);
      expect(refreshes, hasLength(1));
      expect(adapter.bearers, ['Bearer tok', 'Bearer tok-new']);
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
      verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
    });

    test('a 401 with the bearer in use, which a refresh says is alive, is '
        'an error and not a sign-out', () async {
      refreshAnswer = (_) => (status: 200, body: '{"token":"tok"}');
      final adapter = _FnAdapter((o) async => 401);
      final (c, dio) = await bootFn(adapter);

      await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));

      expect(refreshes, hasLength(1));
      expect(adapter.seen, hasLength(1));
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    });

    test('a burst of 401s with the bearer in use asks for one refresh, and '
        'every request learns what it said', () async {
      refreshAnswer = (_) => (status: 200, body: '{"token":"tok"}');
      final adapter = _FnAdapter((o) async => 401);
      final (c, dio) = await bootFn(adapter);

      final burst = [
        for (var i = 0; i < 3; i++)
          expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>())),
      ];
      await Future.wait(burst);

      expect(refreshes, hasLength(1));
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    });

    test('a form refused with a bearer rotated meanwhile is not sent again, '
        'and signs nobody out', () async {
      var n = 0;
      final adapter = _FnAdapter((o) async {
        current = 'tok-${++n}'; // a rotation landed while each was out
        return 401;
      });
      final (c, dio) = await bootFn(adapter);

      await expectLater(
        dio.post<void>('/api/files', data: FormData.fromMap({'name': 'a.txt'})),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        dio.post<void>(
          '/api/files',
          data: Stream<List<int>>.fromIterable([
            [1, 2, 3],
          ]),
        ),
        throwsA(isA<DioException>()),
      );

      expect(adapter.seen, hasLength(2), reason: 'each sent once only');
      expect(refreshes, isEmpty);
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
      verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
    });

    test('a request on its way across a switch of login hands its count '
        'back, so the next refresh of that login goes ahead', () async {
      final slow = Completer<void>();
      final adapter = _FnAdapter((o) async {
        if (o.path == '/api/slow') await slow.future;
        return 200;
      });
      final (c, dio) = await bootFn(adapter);
      final gate = c.read(tokenRefreshGateProvider);

      final inFlight = dio.get<void>('/api/slow');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(gate.sending('session-1'), 1);

      // A switch: the client is built again, and the one the request went
      // out on is left behind.
      c.read(sessionEpochProvider.notifier).bump();
      expect(identical(c.read(dioProvider), dio), isFalse);

      slow.complete();
      final res = await inFlight;
      expect(res.statusCode, 200);
      expect(gate.sending('session-1'), 0);

      var posted = false;
      await gate
          .run('session-1', () async => posted = true)
          .timeout(const Duration(seconds: 2));
      expect(posted, isTrue);
    });

    test('a 401 across a switch, for the login switched away from, signs '
        'nobody out', () async {
      final slow = Completer<void>();
      final adapter = _FnAdapter((o) async {
        await slow.future;
        return 401;
      });
      final (c, dio) = await bootFn(adapter);
      final now = DateTime.now();
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 'session-2',
              baseUrl: 'https://m.example.com',
              addedAt: now,
              lastUsedAt: now,
            ),
          );

      final inFlight = dio.get<void>('/api/x');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await db.setSetting('active_session_id', 'session-2');
      c.read(sessionEpochProvider.notifier).bump();
      c.read(dioProvider);
      slow.complete();

      await expectLater(inFlight, throwsA(isA<DioException>()));
      expect(refreshes, isEmpty);
      expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
      verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
    });
  });
}
