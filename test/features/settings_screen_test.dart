// SettingsScreen as a widget: the Account card states the facts (server,
// email, both versions), and the destructive actions open their confirms
// instead of acting on a tap.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/app_version.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/server/server_version.dart';
import 'package:jackdaw/features/settings/settings_screen.dart';

import '../helpers/pump_screen.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {String? serverVersion = '0.9.9'}) =>
      pumpScreen(
        tester,
        const SettingsScreen(),
        container: ProviderContainer(overrides: [
          appDatabaseProvider.overrideWithValue(db),
          appVersionProvider.overrideWith((ref) async => '1.2.3 (4)'),
          serverVersionProvider.overrideWith((ref) async => serverVersion),
        ]),
      );

  testWidgets('shows who and where: server, email, app and server version',
      (tester) async {
    await db.setSetting('server_base_url', 'https://brain.example.com');
    await db.setSetting('account_email', 'owner@example.com');
    await pump(tester);

    expect(find.text('https://brain.example.com'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('Jackdaw 1.2.3 (4)'), findsOneWidget);
    expect(find.text('Mantle 0.9.9'), findsOneWidget);
    expect(find.text('Change server'), findsOneWidget);
    expect(find.text('Account & profile settings coming soon.'), findsNothing);
  });

  testWidgets('a session with no recorded email hides the row; an unreachable '
      'server says so', (tester) async {
    await db.setSetting('server_base_url', 'https://brain.example.com');
    await pump(tester, serverVersion: null);

    expect(find.text('Signed in as'), findsNothing);
    expect(find.text('Unreachable'), findsOneWidget);
  });

  testWidgets('Clear cache and Change server ask first', (tester) async {
    await db.setSetting('server_base_url', 'https://brain.example.com');
    await pump(tester);

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    expect(find.text('Clear cache?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Clear cache?'), findsNothing);

    await tester.tap(find.text('Change server'));
    await tester.pumpAndSettle();
    expect(find.text('Change server?'), findsOneWidget);
    expect(find.text('Sign out and change'), findsOneWidget);
  });
}
