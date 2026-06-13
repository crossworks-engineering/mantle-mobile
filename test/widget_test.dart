// Smoke test: the app boots and renders its landing screen. The database is
// overridden with an in-memory Drift DB so no file/simulator is needed.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mantle_companion/data/db/app_database.dart';
import 'package:mantle_companion/data/db/database_provider.dart';
import 'package:mantle_companion/main.dart';

void main() {
  testWidgets('App boots and shows the landing screen', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MantleCompanionApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mantle Companion'), findsOneWidget);
    expect(find.text('Start a chat'), findsOneWidget);
  });
}
