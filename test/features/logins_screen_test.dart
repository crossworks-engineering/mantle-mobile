// LoginsScreen as a widget: every held login is listed with who and where, the
// one in use says so and cannot be "switched to", a login its brain signed out
// says that instead, and signing out asks first.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/features/auth/logins_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      TokenStore.keyFor('a'): 'tok-a',
      TokenStore.keyFor('b'): 'tok-b',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> seed(
    String id,
    String baseUrl,
    String email, {
    String? siteName,
    String? displayName,
    bool needsSignIn = false,
    int usedMinutesAgo = 0,
  }) {
    final used = DateTime(2026, 9, 21, 12).subtract(
      Duration(minutes: usedMinutesAgo),
    );
    return db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            baseUrl: baseUrl,
            email: Value(email),
            siteName: Value(siteName),
            displayName: Value(displayName),
            needsSignIn: Value(needsSignIn),
            addedAt: used,
            lastUsedAt: used,
          ),
        );
  }

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    await pumpScreen(tester, const LoginsScreen(), container: container);
    return container;
  }

  testWidgets('lists every held login, the one in use first', (tester) async {
    await seed('a', 'https://m.example.com', 'a@example.com',
        siteName: 'Home brain', usedMinutesAgo: 5);
    await seed('b', 'https://work.example.com', 'b@example.com',
        displayName: 'Bee', usedMinutesAgo: 1);
    await db.setSetting(AppDatabase.activeSessionKey, 'a');
    await pump(tester);

    // Who: a display name when there is one, else the email.
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('Bee'), findsOneWidget);
    // Where: the site name once known, else the host.
    expect(find.text('Home brain'), findsOneWidget);
    expect(find.text('work.example.com'), findsOneWidget);
    expect(find.text('In use'), findsOneWidget);

    final inUse = tester.getTopLeft(find.text('a@example.com')).dy;
    final other = tester.getTopLeft(find.text('Bee')).dy;
    expect(inUse, lessThan(other));
  });

  testWidgets('a login its brain signed out says so', (tester) async {
    await seed('a', 'https://m.example.com', 'a@example.com');
    await seed('b', 'https://m.example.com', 'b@example.com',
        needsSignIn: true);
    await db.setSetting(AppDatabase.activeSessionKey, 'a');
    await pump(tester);

    expect(find.text('Signed out. Tap to sign in again.'), findsOneWidget);
  });

  testWidgets('tapping another login switches to it', (tester) async {
    await seed('a', 'https://m.example.com', 'a@example.com',
        usedMinutesAgo: 5);
    await seed('b', 'https://m.example.com', 'b@example.com');
    await db.setSetting(AppDatabase.activeSessionKey, 'a');
    await db.setSetting('server_base_url', 'https://m.example.com');
    final container = await pump(tester);

    await tester.tap(find.text('b@example.com'));
    await tester.pumpAndSettle();

    expect(await container.read(sessionRepositoryProvider).activeId(), 'b');
  });

  testWidgets('signing out asks first, and Cancel changes nothing',
      (tester) async {
    await seed('a', 'https://m.example.com', 'a@example.com');
    await db.setSetting(AppDatabase.activeSessionKey, 'a');
    final container = await pump(tester);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out of this login?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await container.read(sessionRepositoryProvider).list(),
        hasLength(1));
  });

  testWidgets('offers to add a login, and says what that does', (tester) async {
    await seed('a', 'https://m.example.com', 'a@example.com');
    await db.setSetting(AppDatabase.activeSessionKey, 'a');
    await pump(tester);

    expect(find.text('Add login'), findsOneWidget);
    expect(find.textContaining('stays signed in'), findsOneWidget);
  });
}
