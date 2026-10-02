// The logins a device holds: SessionRepository over in-memory Drift, and the
// real TokenStore over flutter_secure_storage's in-memory mock.
//
// Two promises are tested harder than the rest: the update from the
// single-login build keeps the person signed in (the old keychain item moves
// under session #1), and one login's trouble is its own.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';

const _brain = 'https://m.example.com';
const _other = 'https://other.example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TokenStore tokens;
  late SessionRepository sessions;
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tokens = TokenStore(
      storage,
      () => db.getSetting(AppDatabase.activeSessionKey),
    );
    sessions = SessionRepository(db, tokens);
  });
  tearDown(() => db.close());

  /// A finished sign-in, the way the controller drives it.
  Future<String> signIn(String baseUrl, String email, String token) async {
    final begun = await sessions.beginSignIn(baseUrl: baseUrl, email: email);
    await tokens.write(token);
    await sessions.completeSignIn(begun.session.id, email: email);
    return begun.session.id;
  }

  group('the update from the single-login build', () {
    test('the old keychain item moves under session #1 on first read',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        TokenStore.legacyKey: 'legacy-token',
      });
      final now = DateTime.now();
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's1',
              baseUrl: _brain,
              email: const Value('owner@example.com'),
              addedAt: now,
              lastUsedAt: now,
            ),
          );
      await db.setSetting(AppDatabase.activeSessionKey, 's1');

      expect(await tokens.read(), 'legacy-token');
      expect(await storage.read(key: TokenStore.keyFor('s1')), 'legacy-token');
      expect(await storage.read(key: TokenStore.legacyKey), isNull);
      // And again, from the session's own item now.
      expect(await tokens.read(), 'legacy-token');
    });

    test('with nobody active, the old item is NOT handed out', () async {
      FlutterSecureStorage.setMockInitialValues({
        TokenStore.legacyKey: 'legacy-token',
      });
      expect(await tokens.read(), isNull);
    });
  });

  group('signing in', () {
    test('makes the session active first, so the token lands under its id',
        () async {
      final id = await signIn(_brain, 'Owner@Example.com', 'tok-a');

      expect(await sessions.activeId(), id);
      expect(await storage.read(key: TokenStore.keyFor(id)), 'tok-a');
      expect(db.currentSessionId, id);
      // The two settings the rest of the app reads mirror the active login.
      expect(await db.getSetting('server_base_url'), _brain);
      expect(await db.getSetting('account_email'), 'owner@example.com');
    });

    test('again as the same login reuses its row', () async {
      final first = await signIn(_brain, 'owner@example.com', 'tok-1');
      final second = await signIn(_brain, 'OWNER@example.com', 'tok-2');
      expect(second, first);
      expect(await sessions.list(), hasLength(1));
      expect(await tokens.read(), 'tok-2');
    });

    test('two logins on one brain, and one email on two brains, stay apart',
        () async {
      final a = await signIn(_brain, 'a@example.com', 'tok-a');
      final b = await signIn(_brain, 'b@example.com', 'tok-b');
      final c = await signIn(_other, 'a@example.com', 'tok-c');

      expect({a, b, c}, hasLength(3));
      expect(await tokens.readFor(a), 'tok-a');
      expect(await tokens.readFor(b), 'tok-b');
      expect(await tokens.read(), 'tok-c');
      expect(await db.getSetting('server_base_url'), _other);
    });

    test('a failed sign-in removes the row made for it and nothing else',
        () async {
      final held = await signIn(_brain, 'a@example.com', 'tok-a');
      await sessions.stepOut();

      final begun =
          await sessions.beginSignIn(baseUrl: _brain, email: 'b@example.com');
      await sessions.abandonSignIn(
        sessionId: begun.session.id,
        created: begun.created,
        previousActiveId: null,
      );

      expect((await sessions.list()).map((s) => s.id), [held]);
      expect(await tokens.readFor(held), 'tok-a');
      expect(await sessions.activeId(), isNull);
    });

    test('a failed sign-in as an ALREADY held login leaves its row and bearer',
        () async {
      final held = await signIn(_brain, 'a@example.com', 'tok-a');
      await sessions.stepOut();

      final begun =
          await sessions.beginSignIn(baseUrl: _brain, email: 'a@example.com');
      expect(begun.created, isFalse);
      await sessions.abandonSignIn(
        sessionId: begun.session.id,
        created: begun.created,
        previousActiveId: null,
      );

      expect(await tokens.readFor(held), 'tok-a');
      expect(await sessions.list(), hasLength(1));
    });

    test('a QR sign-in that turns out to be a held login replaces the old row',
        () async {
      final old = await signIn(_brain, 'owner@example.com', 'tok-old');
      await sessions.stepOut();

      final begun = await sessions.beginSignIn(baseUrl: _brain); // no email yet
      await tokens.write('tok-qr');
      await sessions.completeSignIn(
        begun.session.id,
        email: 'owner@example.com',
      );

      final all = await sessions.list();
      expect(all, hasLength(1));
      expect(all.single.id, begun.session.id);
      expect(await tokens.readFor(old), isNull);
      expect(await tokens.read(), 'tok-qr');
    });
  });

  group('one login at a time', () {
    test('stepping out keeps every login held and hands out no bearer',
        () async {
      final a = await signIn(_brain, 'a@example.com', 'tok-a');
      await sessions.stepOut();

      expect(await sessions.activeId(), isNull);
      expect(await tokens.read(), isNull);
      expect(await tokens.readFor(a), 'tok-a');
      // The brain stays: the next screen is its login, not server setup.
      expect(await db.getSetting('server_base_url'), _brain);
      expect(db.currentSessionId, '');
    });

    test('activating another login moves the mirrors and the cache scope',
        () async {
      final a = await signIn(_brain, 'a@example.com', 'tok-a');
      await signIn(_other, 'b@example.com', 'tok-b');

      expect(await sessions.activate(a), isTrue);
      expect(await tokens.read(), 'tok-a');
      expect(await db.getSetting('server_base_url'), _brain);
      expect(await db.getSetting('account_email'), 'a@example.com');
      expect(db.currentSessionId, a);
    });

    test('a refused login keeps its row, loses its bearer and cache, and '
        'spares the others', () async {
      final idle = await signIn(_brain, 'idle@example.com', 'tok-idle');
      final active = await signIn(_brain, 'active@example.com', 'tok-dead');
      await db.enqueueOutboxTurn(id: 'k', agentSlug: 'x', body: 'unsent');

      await sessions.markNeedsSignIn(active);

      final row = await sessions.byId(active);
      expect(row?.needsSignIn, isTrue);
      expect(await tokens.readFor(active), isNull);
      expect(await db.select(db.outboxTurns).get(), isEmpty);
      expect(await tokens.readFor(idle), 'tok-idle');
      // Nothing is switched to behind the person's back.
      expect(await sessions.activeId(), isNull);
      // And it cannot be switched to until it is signed back in to.
      expect(await sessions.activate(active), isFalse);
    });

    test('signing back in to a refused login revives its row', () async {
      final id = await signIn(_brain, 'owner@example.com', 'tok-dead');
      await sessions.markNeedsSignIn(id);

      final again = await signIn(_brain, 'owner@example.com', 'tok-new');
      expect(again, id);
      expect((await sessions.byId(id))?.needsSignIn, isFalse);
      expect(await tokens.read(), 'tok-new');
    });

    test('removing a login forgets its row, bearer and unsent messages only',
        () async {
      final a = await signIn(_brain, 'a@example.com', 'tok-a');
      await db.enqueueOutboxTurn(id: 'ka', agentSlug: 'x', body: 'from a');
      final b = await signIn(_brain, 'b@example.com', 'tok-b');
      await db.enqueueOutboxTurn(id: 'kb', agentSlug: 'x', body: 'from b');

      await sessions.remove(a);

      expect((await sessions.list()).map((s) => s.id), [b]);
      expect(await tokens.readFor(a), isNull);
      final left = await db.select(db.outboxTurns).get();
      expect(left.map((t) => t.id), ['kb']);
      expect(await sessions.activeId(), b);
    });

    test('recording one identity field leaves the other as it was', () async {
      final id = await signIn(_brain, 'a@example.com', 'tok-a');
      await sessions.recordIdentity(id, displayName: const Value('Bee'));
      await sessions.recordIdentity(id, siteName: const Value('Home brain'));

      var row = await sessions.byId(id);
      expect(row?.displayName, 'Bee');
      expect(row?.siteName, 'Home brain');

      await sessions.recordIdentity(id, siteName: const Value(null));
      row = await sessions.byId(id);
      expect(row?.displayName, 'Bee');
      expect(row?.siteName, isNull);
    });

    test('hydrate points the cache at the active login after a restart',
        () async {
      final id = await signIn(_brain, 'a@example.com', 'tok-a');
      db.currentSessionId = ''; // a fresh process
      await sessions.hydrate();
      expect(db.currentSessionId, id);
    });
  });
}
