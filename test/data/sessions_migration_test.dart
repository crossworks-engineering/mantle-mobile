// The update from the single-login build (schema v2) to several logins (v3).
//
// The promise under test: updating the app signs nobody out and loses nothing
// a person wrote. The saved server becomes session #1 and is active; unsent
// messages keep their rows and gain that session; the read cache, which is
// only a cache, starts empty.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/db/app_database.dart';

/// A database exactly as v1.12.0 (schema v2) left it on disk.
NativeDatabase v2Database({
  String? server,
  String? email,
  bool withOutbox = false,
}) {
  return NativeDatabase.memory(
    setup: (raw) {
      raw.execute(
        'CREATE TABLE app_settings (key TEXT NOT NULL, value TEXT NOT NULL, '
        'PRIMARY KEY (key));',
      );
      raw.execute(
        'CREATE TABLE cached_messages (agent_slug TEXT NOT NULL, id TEXT NOT '
        'NULL, json TEXT NOT NULL, created_at INTEGER NOT NULL, '
        'PRIMARY KEY (agent_slug, id));',
      );
      raw.execute(
        'CREATE TABLE outbox_turns (id TEXT NOT NULL, agent_slug TEXT NOT '
        'NULL, body TEXT NOT NULL, location_json TEXT, created_at INTEGER NOT '
        'NULL, attempts INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (id));',
      );
      if (server != null) {
        raw.execute(
          "INSERT INTO app_settings VALUES ('server_base_url', ?)",
          [server],
        );
      }
      if (email != null) {
        raw.execute(
          "INSERT INTO app_settings VALUES ('account_email', ?)",
          [email],
        );
      }
      raw.execute(
        "INSERT INTO cached_messages VALUES ('assistant', 'm1', '{}', 1)",
      );
      if (withOutbox) {
        raw.execute(
          "INSERT INTO outbox_turns VALUES ('k1', 'assistant', 'written "
          "offline', NULL, 1700000000, 2)",
        );
      }
      raw.execute('PRAGMA user_version = 2;');
    },
  );
}

void main() {
  test('the saved server and email become session #1, and it is active',
      () async {
    final db = AppDatabase.forTesting(
      v2Database(server: 'https://m.example.com', email: 'owner@example.com'),
    );
    addTearDown(db.close);

    final sessions = await db.select(db.sessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.baseUrl, 'https://m.example.com');
    expect(sessions.single.email, 'owner@example.com');
    expect(sessions.single.needsSignIn, isFalse);
    expect(
      await db.getSetting(AppDatabase.activeSessionKey),
      sessions.single.id,
    );
    // What the rest of the app reads is untouched.
    expect(await db.getSetting('server_base_url'), 'https://m.example.com');
    expect(await db.getSetting('account_email'), 'owner@example.com');
  });

  test('the migrated session is recorded as the one owner of the old '
      'keychain item', () async {
    final db = AppDatabase.forTesting(
      v2Database(server: 'https://m.example.com'),
    );
    addTearDown(db.close);
    final session = (await db.select(db.sessions).get()).single;
    expect(await db.getSetting(AppDatabase.legacyBearerOwnerKey), session.id);
  });

  // L4: Drift records the new version only after the upgrade returns, so an
  // upgrade can run twice. The second run must not add a second session.
  test('an upgrade that runs again adds no second session', () async {
    final dir = await Directory.systemTemp.createTemp('jdm-migration');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/app.sqlite');
    var rollBack = false;
    NativeDatabase open() => NativeDatabase(
          file,
          setup: (raw) {
            if (raw.userVersion == 0) {
              raw.execute(
                'CREATE TABLE app_settings (key TEXT NOT NULL, value TEXT NOT '
                'NULL, PRIMARY KEY (key));',
              );
              raw.execute(
                'CREATE TABLE cached_messages (agent_slug TEXT NOT NULL, id '
                'TEXT NOT NULL, json TEXT NOT NULL, created_at INTEGER NOT '
                'NULL, PRIMARY KEY (agent_slug, id));',
              );
              raw.execute(
                'CREATE TABLE outbox_turns (id TEXT NOT NULL, agent_slug TEXT '
                'NOT NULL, body TEXT NOT NULL, location_json TEXT, created_at '
                'INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, '
                'PRIMARY KEY (id));',
              );
              raw.execute(
                "INSERT INTO app_settings VALUES ('server_base_url', "
                "'https://m.example.com')",
              );
              raw.execute(
                "INSERT INTO outbox_turns VALUES ('k1', 'assistant', 'unsent', "
                'NULL, 1700000000, 0)',
              );
              raw.userVersion = 2;
            }
            // The app was killed after the upgrade but before the version
            // was written: the next launch sees v2 again.
            if (rollBack) raw.userVersion = 2;
          },
        );

    final first = AppDatabase.forTesting(open());
    final id = (await first.select(first.sessions).get()).single.id;
    await first.close();

    rollBack = true;
    final second = AppDatabase.forTesting(open());
    addTearDown(second.close);
    final sessions = await second.select(second.sessions).get();
    expect(sessions.map((s) => s.id), [id]);
    expect(await second.getSetting(AppDatabase.activeSessionKey), id);
    final turn = (await second.select(second.outboxTurns).get()).single;
    expect(turn.sessionId, id);
  });

  test('an unsent message keeps its row and gains the login that wrote it',
      () async {
    final db = AppDatabase.forTesting(
      v2Database(server: 'https://m.example.com', withOutbox: true),
    );
    addTearDown(db.close);

    final session = (await db.select(db.sessions).get()).single;
    final turn = (await db.select(db.outboxTurns).get()).single;
    expect(turn.id, 'k1');
    expect(turn.body, 'written offline');
    expect(turn.attempts, 2);
    expect(turn.sessionId, session.id);

    // And it is the active login's queue that finds it.
    db.currentSessionId = session.id;
    expect(await db.outboxTurnsFor('assistant'), hasLength(1));
    db.currentSessionId = 'someone-else';
    expect(await db.outboxTurnsFor('assistant'), isEmpty);
  });

  test('the read cache starts empty: it is refetched, not carried', () async {
    final db = AppDatabase.forTesting(
      v2Database(server: 'https://m.example.com'),
    );
    addTearDown(db.close);
    expect(await db.select(db.cachedMessages).get(), isEmpty);
  });

  test('a device that never set a server gets no session', () async {
    final db = AppDatabase.forTesting(v2Database(withOutbox: true));
    addTearDown(db.close);
    expect(await db.select(db.sessions).get(), isEmpty);
    expect(await db.getSetting(AppDatabase.activeSessionKey), isNull);
    // The stray turn survives, owned by nobody, so no login ever sends it.
    expect((await db.select(db.outboxTurns).get()).single.sessionId, '');
  });

  test('a fresh install creates the v3 tables directly', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await db.select(db.sessions).get(), isEmpty);
    db.currentSessionId = 's1';
    await db.enqueueOutboxTurn(id: 'k', agentSlug: 'a', body: 'hi');
    expect((await db.select(db.outboxTurns).get()).single.sessionId, 's1');
  });

  test('two logins with an agent of the same name never read each other',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final at = DateTime(2026, 9, 21);

    db.currentSessionId = 'a';
    await db.cacheChatRows('assistant', [
      (id: 'm1', json: '{"who":"a"}', createdAt: at),
    ]);
    db.currentSessionId = 'b';
    // Same agent slug, same message id: a different login's row, not a clash.
    await db.cacheChatRows('assistant', [
      (id: 'm1', json: '{"who":"b"}', createdAt: at),
    ]);

    expect(await db.cachedChatRows('assistant'), ['{"who":"b"}']);
    db.currentSessionId = 'a';
    expect(await db.cachedChatRows('assistant'), ['{"who":"a"}']);

    // Clearing one login's data leaves the other's alone.
    await db.clearUserData(sessionId: 'a');
    expect(await db.cachedChatRows('assistant'), isEmpty);
    db.currentSessionId = 'b';
    expect(await db.cachedChatRows('assistant'), ['{"who":"b"}']);
  });

  test('session ids are safe inside a secure-storage key', () {
    final ids = {for (var i = 0; i < 50; i++) AppDatabase.newSessionId()};
    expect(ids, hasLength(50));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    }
  });
}
