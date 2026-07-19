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

/// Offline read cache for chat threads: the latest server history rows per
/// agent, stored as the RAW `/api/assistant/messages` row JSON so reads
/// re-parse through the same [ChatApi] path as the wire (the cache can never
/// drift from the contract). Pruned to the newest [AppDatabase.chatCacheKeep]
/// rows per agent.
class CachedMessages extends Table {
  TextColumn get agentSlug => text()();
  TextColumn get id => text()();
  TextColumn get json => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {agentSlug, id};
}

/// Offline send-queue: text-only turns that failed on a CONNECTIVITY error.
/// The row id is the turn's idempotency key, so a flush that races a
/// half-delivered send replays the same turn instead of duplicating it.
/// Attachment turns are never queued (they fail fast, as before).
class OutboxTurns extends Table {
  TextColumn get id => text()();
  TextColumn get agentSlug => text()();
  TextColumn get body => text()();
  TextColumn get locationJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [AppSettings, CachedMessages, OutboxTurns])
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by the on-device SQLite file.
  AppDatabase() : super(openConnection());

  /// Test database — pass `NativeDatabase.memory()` for a fast, isolated DB.
  AppDatabase.forTesting(super.executor);

  /// Newest rows kept per agent in the chat read cache.
  static const chatCacheKeep = 200;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cachedMessages);
            await m.createTable(outboxTurns);
          }
        },
      );

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

  // ─── Chat read cache ────────────────────────────────────────────────────

  /// Upsert a fetched latest-page's rows for one agent, then prune that
  /// agent's cache to the newest [chatCacheKeep] rows.
  Future<void> cacheChatRows(
    String agentSlug,
    List<({String id, String json, DateTime createdAt})> rows,
  ) {
    return transaction(() async {
      for (final r in rows) {
        await into(cachedMessages).insertOnConflictUpdate(
          CachedMessagesCompanion.insert(
            agentSlug: agentSlug,
            id: r.id,
            json: r.json,
            createdAt: r.createdAt,
          ),
        );
      }
      final keepIds = await ((select(cachedMessages)
                ..where((r) => r.agentSlug.equals(agentSlug))
                ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
                ..limit(chatCacheKeep))
              .map((r) => r.id))
          .get();
      await (delete(cachedMessages)
            ..where((r) =>
                r.agentSlug.equals(agentSlug) & r.id.isNotIn(keepIds)))
          .go();
    });
  }

  /// One agent's cached rows, oldest-first (render order). Raw JSON — the
  /// caller re-parses through [ChatApi]'s history parser.
  Future<List<String>> cachedChatRows(String agentSlug) {
    return ((select(cachedMessages)
              ..where((r) => r.agentSlug.equals(agentSlug))
              ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
            .map((r) => r.json))
        .get();
  }

  // ─── Offline send-queue ─────────────────────────────────────────────────

  /// Queue a text-only turn that failed on connectivity. `id` is the turn's
  /// idempotency key — replays are safe.
  Future<void> enqueueOutboxTurn({
    required String id,
    required String agentSlug,
    required String body,
    String? locationJson,
  }) {
    return into(outboxTurns).insertOnConflictUpdate(
      OutboxTurnsCompanion.insert(
        id: id,
        agentSlug: agentSlug,
        body: body,
        locationJson: Value(locationJson),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Queued turns for one agent, oldest-first (send order).
  Future<List<OutboxTurn>> outboxTurnsFor(String agentSlug) {
    return (select(outboxTurns)
          ..where((r) => r.agentSlug.equals(agentSlug))
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
