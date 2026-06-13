import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'database_provider.g.dart';

/// App-wide singleton [AppDatabase]. Kept alive for the whole session and
/// closed on dispose. Tests override this with an in-memory database via
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(...))`.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
