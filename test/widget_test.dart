// Smoke test: with nothing configured, the app boots to the server-setup
// screen. In-memory Drift, empty — so the session resolves to `needsServer`
// without touching secure storage.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mantle_companion/data/db/database_provider.dart';
import 'package:mantle_companion/main.dart';

void main() {
  testWidgets('App boots to the server-setup screen when unconfigured',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MantleCompanionApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect to Mantle'), findsOneWidget);
  });
}
