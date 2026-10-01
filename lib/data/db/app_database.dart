import 'dart:math';

import 'package:drift/drift.dart';

import 'connection.dart';

part 'app_database.g.dart';

/// Generic key/value store for small app-local settings (theme, flags, the
/// paired-device marker, last-sync timestamps…). Larger domain data (chat
/// messages, the outbound queue) gets its own typed tables as features land.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// The logins this device holds. A SESSION is one (brain address, login) pair;
/// its bearer is NOT here, it lives in secure storage under the session's id
/// ([TokenStore]). Exactly one is active (`active_session_id` in
/// [AppSettings]); the others are a tap away and stay signed in.
///
/// Two sessions may name the same brain with different logins, or different
/// brains with the same email. Both are ordinary.
class Sessions extends Table {
  /// Random, device-local. Not a secret, and unknown to any brain.
  TextColumn get id => text()();
  TextColumn get baseUrl => text()();

  /// Empty until known (a QR sign-in learns it from the claim, a session
  /// migrated from the single-login build from the saved account email).
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get displayName => text().nullable()();
  TextColumn get siteName => text().nullable()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime()();

  /// True once the brain has refused this session's bearer: it can be signed
  /// back in to, not switched to.
  BoolColumn get needsSignIn => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Offline read cache for chat threads: the latest server history rows per
/// agent, stored as the RAW `/api/assistant/messages` row JSON so reads
/// re-parse through the same [ChatApi] path as the wire (the cache can never
/// drift from the contract). Pruned to the newest [AppDatabase.chatCacheKeep]
/// rows per agent.
class CachedMessages extends Table {
  /// Whose cache this is. Two logins can both have an agent called
  /// `assistant`; their threads must never be read as each other's.
  TextColumn get sessionId => text().withDefault(const Constant(''))();
  TextColumn get agentSlug => text()();
  TextColumn get id => text()();
  TextColumn get json => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sessionId, agentSlug, id};
}

/// Offline send-queue: text-only turns that failed on a CONNECTIVITY error.
/// The row id is the turn's idempotency key, so a flush that races a
/// half-delivered send replays the same turn instead of duplicating it.
/// Attachment turns are never queued (they fail fast, as before).
class OutboxTurns extends Table {
  TextColumn get id => text()();

  /// The login that wrote it. A queued turn is sent as that login or not at
  /// all: flushing it under whoever is active now would post one person's
  /// words into another's thread.
  TextColumn get sessionId => text().withDefault(const Constant(''))();
  TextColumn get agentSlug => text()();
  TextColumn get body => text()();
  TextColumn get locationJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [AppSettings, Sessions, CachedMessages, OutboxTurns])
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by the on-device SQLite file.
  AppDatabase() : super(openConnection());

  /// Test database — pass `NativeDatabase.memory()` for a fast, isolated DB.
  AppDatabase.forTesting(super.executor);

  /// Newest rows kept per agent in the chat read cache.
  static const chatCacheKeep = 200;

  /// [AppSettings] key holding the active session's id.
  static const activeSessionKey = 'active_session_id';

  /// [AppSettings] key holding the login to go back to while another is
  /// being added (nobody is active then). Empty when there is none.
  static const resumeSessionKey = 'resume_session_id';

  /// The single-login build's settings, read once by the v3 migration.
  static const legacyServerKey = 'server_base_url';
  static const legacyEmailKey = 'account_email';

  /// The session whose rows the cache and outbox methods below read and
  /// write when no `sessionId` is given. Set by the session layer at start-up
  /// and on every switch ([SessionRepository]); empty means "nobody signed
  /// in", which matches no row a login ever wrote.
  ///
  /// Work that spans an await (a fetch, a send) must read this ONCE, when it
  /// starts, and pass that id to the write: by the time the answer comes the
  /// person may have switched, and the rows belong to the login that asked.
  String currentSessionId = '';

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // One transaction: an upgrade the app is killed in the middle of
        // leaves the old schema whole, and the next launch runs it again.
        // Drift records the new version only after this returns, so a re-run
        // is also possible after a complete one; every step below is safe to
        // repeat (tables are created IF NOT EXISTS, the legacy login is
        // adopted once).
        onUpgrade: (m, from, to) => transaction(() async {
          if (from < 2) {
            await m.createTable(cachedMessages);
            await m.createTable(outboxTurns);
          }
          if (from < 3) {
            await m.createTable(sessions);
            // The login this device already holds becomes session #1, so the
            // update signs nobody out. Its bearer moves to the session's own
            // secure-storage key at the next start-up (see TokenStore).
            final legacyId = await _adoptLegacyLogin();
            if (from >= 2) {
              // A read cache: cheaper to refetch than to carry across a
              // primary-key change.
              await m.deleteTable('cached_messages');
              await m.createTable(cachedMessages);
              // Unsent messages are NOT a cache. They keep their rows and
              // gain the login that wrote them.
              await m.alterTable(
                TableMigration(
                  outboxTurns,
                  columnTransformer: {
                    outboxTurns.sessionId: Constant(legacyId ?? ''),
                  },
                  newColumns: [outboxTurns.sessionId],
                ),
              );
            }
          }
        }),
      );

  /// [AppSettings] key naming the ONE session the single-login build's
  /// keychain item may move to: the session the v3 migration made from that
  /// build's saved server. Read and cleared at start-up
  /// ([SessionRepository.hydrate]). Without it the old item is deleted, never
  /// adopted: a keychain item that survived a reinstall belongs to whatever
  /// brain the old install used, not to the one being signed in to now.
  static const legacyBearerOwnerKey = 'legacy_bearer_owner';

  /// Turn the single-login build's saved server (and email, when it kept one)
  /// into a session row and make it active. Null when there was no server,
  /// which means there was no login either.
  ///
  /// A second run (see the migration) finds the session it made the first
  /// time, through the active id, and returns it instead of adding another.
  Future<String?> _adoptLegacyLogin() async {
    final baseUrl = await getSetting(legacyServerKey);
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final already = await getSetting(activeSessionKey);
    if (already != null && already.isNotEmpty) {
      final row = await (select(sessions)..where((s) => s.id.equals(already)))
          .getSingleOrNull();
      if (row != null) return row.id;
    }
    final id = newSessionId();
    final now = DateTime.now();
    await into(sessions).insert(
      SessionsCompanion.insert(
        id: id,
        baseUrl: baseUrl,
        email: Value(await getSetting(legacyEmailKey) ?? ''),
        addedAt: now,
        lastUsedAt: now,
      ),
    );
    await setSetting(activeSessionKey, id);
    await setSetting(legacyBearerOwnerKey, id);
    return id;
  }

  /// A fresh session id: 128 random bits, hex. Only letters and digits, so it
  /// is safe inside a secure-storage key.
  static String newSessionId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  /// Reads a raw setting value, or null if absent.
  Future<String?> getSetting(String key) {
    return (select(appSettings)..where((row) => row.key.equals(key)))
        .map((row) => row.value)
        .getSingleOrNull();
  }

  /// Inserts or updates a setting.
  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Drop everything that belongs to a signed-in user: the chat read cache
  /// and the offline send-queue. Settings (server URL, theme) stay — they are
  /// the device's, not the account's. Called when a session ends, so the next
  /// login never sees, or sends, the previous account's data.
  ///
  /// Scoped to ONE login ([sessionId], the active one by default): the other
  /// logins held on this device keep their cache and their unsent messages.
  Future<void> clearUserData({String? sessionId}) {
    final id = sessionId ?? currentSessionId;
    return transaction(() async {
      await (delete(cachedMessages)..where((r) => r.sessionId.equals(id))).go();
      await (delete(outboxTurns)..where((r) => r.sessionId.equals(id))).go();
    });
  }

  // ─── Chat read cache ────────────────────────────────────────────────────

  /// Upsert a fetched latest-page's rows for one agent, then prune that
  /// agent's cache to the newest [chatCacheKeep] rows. [sessionId] is the
  /// login the rows were fetched as (default: the active one).
  Future<void> cacheChatRows(
    String agentSlug,
    List<({String id, String json, DateTime createdAt})> rows, {
    String? sessionId,
  }) {
    final mine = sessionId ?? currentSessionId;
    return transaction(() async {
      for (final r in rows) {
        await into(cachedMessages).insertOnConflictUpdate(
          CachedMessagesCompanion.insert(
            sessionId: Value(mine),
            agentSlug: agentSlug,
            id: r.id,
            json: r.json,
            createdAt: r.createdAt,
          ),
        );
      }
      final keepIds = await ((select(cachedMessages)
                ..where((r) =>
                    r.sessionId.equals(mine) & r.agentSlug.equals(agentSlug))
                ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
                ..limit(chatCacheKeep))
              .map((r) => r.id))
          .get();
      await (delete(cachedMessages)
            ..where((r) =>
                r.sessionId.equals(mine) &
                r.agentSlug.equals(agentSlug) &
                r.id.isNotIn(keepIds)))
          .go();
    });
  }

  /// One agent's cached rows, oldest-first (render order). Raw JSON — the
  /// caller re-parses through [ChatApi]'s history parser.
  Future<List<String>> cachedChatRows(String agentSlug, {String? sessionId}) {
    final mine = sessionId ?? currentSessionId;
    return ((select(cachedMessages)
              ..where((r) =>
                  r.sessionId.equals(mine) &
                  r.agentSlug.equals(agentSlug))
              ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
            .map((r) => r.json))
        .get();
  }

  // ─── Offline send-queue ─────────────────────────────────────────────────

  /// Queue a text-only turn that failed on connectivity. `id` is the turn's
  /// idempotency key — replays are safe. [sessionId] is the login that
  /// wrote it (default: the active one).
  Future<void> enqueueOutboxTurn({
    required String id,
    required String agentSlug,
    required String body,
    String? locationJson,
    String? sessionId,
  }) {
    return into(outboxTurns).insertOnConflictUpdate(
      OutboxTurnsCompanion.insert(
        id: id,
        sessionId: Value(sessionId ?? currentSessionId),
        agentSlug: agentSlug,
        body: body,
        locationJson: Value(locationJson),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Queued turns for one agent, oldest-first (send order).
  Future<List<OutboxTurn>> outboxTurnsFor(
    String agentSlug, {
    String? sessionId,
  }) {
    final mine = sessionId ?? currentSessionId;
    return (select(outboxTurns)
          ..where((r) =>
              r.sessionId.equals(mine) &
              r.agentSlug.equals(agentSlug))
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();
  }

  Future<void> deleteOutboxTurn(String id) {
    return (delete(outboxTurns)..where((r) => r.id.equals(id))).go();
  }

  Future<void> bumpOutboxAttempts(String id) async {
    await customUpdate(
      'UPDATE outbox_turns SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {outboxTurns},
    );
  }
}
