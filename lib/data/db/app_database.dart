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

@DriftDatabase(tables: [AppSettings])
class AppDatabase extends _$AppDatabase {
  /// Production database, backed by the on-device SQLite file.
  AppDatabase() : super(openConnection());

  /// Test database — pass `NativeDatabase.memory()` for a fast, isolated DB.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

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
}
