import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device SQLite database, lazily and on a background isolate so
/// the first query doesn't jank the UI. The file lives in the app's documents
/// directory. Tests bypass this entirely via [AppDatabase.forTesting].
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'jackdaw.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
