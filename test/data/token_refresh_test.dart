// TokenRefresher: the bearer of the login in use rotates through
// /api/auth/token/refresh; the newest token is always the one stored; a 401
// signs that login out; anything else keeps the token. The gate holds the
// app's requests while a rotation is in flight.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/token_refresh.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';

import '../helpers/stub_dio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TokenStore tokens;
  late SessionRepository sessions;
  late TokenRefreshGate gate;
  late String sessionId;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tokens = TokenStore(
      const FlutterSecureStorage(),
      () => db.getSetting(AppDatabase.activeSessionKey),
    );
    sessions = SessionRepository(db, tokens);
    gate = TokenRefreshGate();
    final begun = await sessions.beginSignIn(
      baseUrl: 'http://brain.test',
      email: 'mia@example.invalid',
    );
    sessionId = begun.session.id;
    await tokens.write('tok-old');
    await sessions.completeSignIn(sessionId, email: 'mia@example.invalid');
  });
  tearDown(() => db.close());

  TokenRefresher refresherFor(StubAdapter adapter) =>
      TokenRefresher(sessions, tokens, (_) => stubDio(adapter), gate);

  test('a rotation stores the new token, sent with the old one', () async {
    final adapter = StubAdapter((o) => (
          status: 200,
          body: jsonEncode({'token': 'tok-new', 'role': 'member'}),
        ));
    final outcome = await refresherFor(adapter).refreshActive();

    expect(outcome, RefreshOutcome.rotated);
    expect(adapter.requests.single.path, '/api/auth/token/refresh');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-old');
    expect(await tokens.readFor(sessionId), 'tok-new');
  });

  test('too early: the same token back, nothing changes', () async {
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode({'token': 'tok-old'})),
    );
    expect(await refresherFor(adapter).refreshActive(),
        RefreshOutcome.unchanged);
    expect(await tokens.readFor(sessionId), 'tok-old');
  });

  test('a 401 is final: the login in use is signed out', () async {
    final adapter = StubAdapter((o) => (status: 401, body: '{}'));
    var refused = 0;
    final outcome = await refresherFor(adapter).refreshActive(
      onRefused: () async => refused++,
    );
    expect(outcome, RefreshOutcome.refused);
    expect(refused, 1);
  });

  for (final status in [403, 404, 429, 500]) {
    test('a $status keeps the token and signs nobody out', () async {
      final adapter = StubAdapter((o) => (status: status, body: '{}'));
      var refused = 0;
      final outcome = await refresherFor(adapter).refreshActive(
        onRefused: () async => refused++,
      );
      expect(outcome, RefreshOutcome.skipped);
      expect(refused, 0);
      expect(await tokens.readFor(sessionId), 'tok-old');
    });
  }

  test('nobody signed in: nothing is asked', () async {
    await sessions.stepOut();
    final adapter = StubAdapter((o) => (status: 200, body: '{}'));
    expect(await refresherFor(adapter).refreshActive(),
        RefreshOutcome.skipped);
    expect(adapter.requests, isEmpty);
  });

  test('the gate holds requests until the rotation is stored', () async {
    final release = Completer<void>();
    var waited = false;
    final running = gate.run(sessionId, () => release.future);
    expect(gate.busy, isTrue);
    final waiter = gate.wait(sessionId).then((_) => waited = true);
    await Future<void>.delayed(Duration.zero);
    expect(waited, isFalse);
    release.complete();
    await running;
    await waiter;
    expect(waited, isTrue);
    expect(gate.busy, isFalse);
  });

  test('a second refresh while one runs joins it', () async {
    final release = Completer<void>();
    var runs = 0;
    final first = gate.run(sessionId, () {
      runs++;
      return release.future;
    });
    final second = gate.run(sessionId, () async => runs++);
    release.complete();
    await Future.wait([first, second]);
    expect(runs, 1);
  });

  test('the refresh is posted only once every request sent with the old '
      'bearer has its answer', () async {
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode({'token': 'tok-new'})),
    );
    final held = await gate.acquire(sessionId, () => tokens.readFor(sessionId));
    expect(held, 'tok-old');

    final refresh = refresherFor(adapter).refreshActive();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(adapter.requests, isEmpty);
    // Nothing new leaves with the old bearer meanwhile.
    var late = '';
    final next = gate
        .acquire(sessionId, () => tokens.readFor(sessionId))
        .then((t) => late = t ?? '');

    gate.release(sessionId);
    expect(await refresh, RefreshOutcome.rotated);
    await next;
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-old');
    expect(late, 'tok-new');
    gate.release(sessionId);
  });

  test('a request that never answers does not rotate under it: the refresh '
      'is skipped', () async {
    gate = TokenRefreshGate(drainTimeout: const Duration(milliseconds: 20));
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode({'token': 'tok-new'})),
    );
    await gate.acquire(sessionId, () => tokens.readFor(sessionId));

    expect(await refresherFor(adapter).refreshActive(),
        RefreshOutcome.skipped);
    expect(adapter.requests, isEmpty);
    expect(await tokens.readFor(sessionId), 'tok-old');
    expect(gate.busy, isFalse);
  });

  test("one login's refresh does not hold another login's requests", () async {
    final release = Completer<void>();
    final running = gate.run('login-a', () => release.future);
    final token = await gate
        .acquire('login-b', () async => 'tok-b')
        .timeout(const Duration(seconds: 1));
    expect(token, 'tok-b');
    gate.release('login-b');
    release.complete();
    await running;
  });

  test("a switch during another login's refresh runs the new login's "
      'refresh after it, instead of joining it', () async {
    final release = Completer<void>();
    final order = <String>[];
    final first = gate.run('login-a', () async {
      order.add('a');
      await release.future;
      order.add('a done');
    });
    final second = gate.run('login-b', () async => order.add('b'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(order, ['a']);
    release.complete();
    await Future.wait([first, second]);
    expect(order, ['a', 'a done', 'b']);
  });

  test('the direct connection is paused around the rotation', () async {
    final events = <String>[];
    final adapter = StubAdapter((o) {
      events.add('post');
      return (status: 200, body: jsonEncode({'token': 'tok-new'}));
    });
    final refresher = TokenRefresher(
      sessions,
      tokens,
      (_) => stubDio(adapter),
      gate,
      pauseStream: (id) async {
        events.add('pause $id');
        return true;
      },
      resumeStream: (id) async {
        events.add('resume $id');
        // Let go only once the new token is stored.
        expect(await tokens.readFor(sessionId), 'tok-new');
      },
    );
    expect(await refresher.refreshActive(), RefreshOutcome.rotated);
    expect(events, ['pause $sessionId', 'post', 'resume $sessionId']);
  });
  group('a refresh whose answer was lost', () {
    for (final lost in <DioException Function(RequestOptions)>[
      (o) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 8),
            requestOptions: o,
          ),
      (o) => DioException.connectionError(requestOptions: o, reason: 'reset'),
    ]) {
      test('is asked once more before the gate opens (${lost(RequestOptions()).type.name})',
          () async {
        var n = 0;
        var closedOnRetry = false;
        final adapter = StubAdapter((o) {
          if (++n == 1) throw lost(o);
          // Nothing gets the old bearer while the refresh is asked again.
          closedOnRetry = gate.busyFor(sessionId);
          return (status: 200, body: jsonEncode({'token': 'tok-new'}));
        });

        expect(await refresherFor(adapter).refreshActive(),
            RefreshOutcome.rotated);
        expect(adapter.requests, hasLength(2));
        expect(closedOnRetry, isTrue);
        expect(
          adapter.requests.map((o) => o.headers['Authorization']),
          everyElement('Bearer tok-old'),
        );
        expect(await tokens.readFor(sessionId), 'tok-new');
      });
    }

    test('is asked once more only', () async {
      final adapter = StubAdapter(
        (o) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 8),
          requestOptions: o,
        ),
      );
      expect(await refresherFor(adapter).refreshActive(),
          RefreshOutcome.skipped);
      expect(adapter.requests, hasLength(2));
      expect(await tokens.readFor(sessionId), 'tok-old');
      expect(gate.busy, isFalse);
    });

    test('an answer that came is not asked again', () async {
      final adapter = StubAdapter((o) => (status: 500, body: '{}'));
      expect(await refresherFor(adapter).refreshActive(),
          RefreshOutcome.skipped);
      expect(adapter.requests, hasLength(1));
    });
  });

  test('the direct connection with a send still on its way: the refresh is '
      'skipped, and the connection let go', () async {
    final events = <String>[];
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode({'token': 'tok-new'})),
    );
    final refresher = TokenRefresher(
      sessions,
      tokens,
      (_) => stubDio(adapter),
      gate,
      pauseStream: (id) async {
        events.add('pause');
        return false;
      },
      resumeStream: (id) async => events.add('resume'),
    );
    expect(await refresher.refreshActive(), RefreshOutcome.skipped);
    expect(adapter.requests, isEmpty);
    expect(events, ['pause', 'resume']);
    expect(await tokens.readFor(sessionId), 'tok-old');
  });

  test('a refresh asked for while one runs learns what that one did',
      () async {
    final answer = Completer<void>();
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode({'token': 'tok-old'})),
    );
    final refresher = TokenRefresher(
      sessions,
      tokens,
      (_) => stubDio(adapter),
      gate,
      pauseStream: (id) async {
        await answer.future;
        return true;
      },
    );
    final first = refresher.refreshActive();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final second = refresher.refreshActive();
    answer.complete();
    expect(await first, RefreshOutcome.unchanged);
    expect(await second, RefreshOutcome.unchanged);
    expect(adapter.requests, hasLength(1));
  });
}
