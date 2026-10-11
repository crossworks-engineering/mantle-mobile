// TokenRefresher: the bearer of the login in use rotates through
// /api/auth/token/refresh; the newest token is always the one stored; a 401
// signs that login out; anything else keeps the token. The gate holds the
// app's requests while a rotation is in flight.

import 'dart:async';
import 'dart:convert';

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
    final running = gate.run(() => release.future);
    expect(gate.busy, isTrue);
    final waiter = gate.wait().then((_) => waited = true);
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
    final first = gate.run(() {
      runs++;
      return release.future;
    });
    final second = gate.run(() async => runs++);
    release.complete();
    await Future.wait([first, second]);
    expect(runs, 1);
  });
}
