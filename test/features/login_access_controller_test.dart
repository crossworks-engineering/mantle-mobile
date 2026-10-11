// LoginAccessController: cache first, whoami after, per login; the sign-in's
// role stands in before whoami; a removed login's cache goes with it.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/data/auth/login_access.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/features/auth/login_access_controller.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/stub_dio.dart';

class MockTokenStore extends Mock implements TokenStore {}

class MockSessionWipe extends Mock implements SessionWipe {}

Map<String, dynamic> _memberWhoami() => {
      'role': 'member',
      'loginId': 'login-m',
      'email': 'mia@example.invalid',
      'displayName': null,
      'shell': '/api/shell',
      'pushBase': '/api/member/push',
      'brainId': 'brain-1',
      'workspaces': [
        {'id': 'ws-team', 'name': 'Team', 'isAdmin': false, 'moderator': false},
      ],
      'areas': <String>[],
      'isOwner': false,
    };

void main() {
  late AppDatabase db;
  late MockTokenStore tokens;
  late MockSessionWipe wipe;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.setSetting('server_base_url', 'http://brain.test');
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            baseUrl: 'http://brain.test',
            addedAt: now,
            lastUsedAt: now,
          ),
        );
    await db.setSetting('active_session_id', 's1');
    tokens = MockTokenStore();
    when(() => tokens.read()).thenAnswer((_) async => 'tok');
    when(() => tokens.readFor(any())).thenAnswer((_) async => 'tok');
    when(() => tokens.adoptLegacy(owner: any(named: 'owner')))
        .thenAnswer((_) async {});
    wipe = MockSessionWipe();
  });
  tearDown(() => db.close());

  ProviderContainer boot(StubAdapter adapter) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokens),
        sessionWipeProvider.overrideWithValue(wipe),
        dioProvider.overrideWithValue(stubDio(adapter)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('with nothing cached it asks whoami and caches the answer', () async {
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode(_memberWhoami())),
    );
    final c = boot(adapter);
    final access = await c.read(loginAccessControllerProvider.future);

    expect(access.role, LoginRole.member);
    expect(access.workspaces.single.name, 'Team');
    expect(adapter.requests.single.path, '/api/auth/whoami');
    final cached = await readCachedAccess(db, 's1');
    expect(cached?.loginId, 'login-m');
  });

  test('a cached answer is the state at once, then whoami refreshes it',
      () async {
    await writeCachedAccess(db, 's1', LoginAccess.fromRole('member'));
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode(_memberWhoami())),
    );
    final c = boot(adapter);
    c.listen(loginAccessControllerProvider, (_, _) {});

    final first = await c.read(loginAccessControllerProvider.future);
    expect(first.role, LoginRole.member);
    expect(first.workspaces, isEmpty, reason: 'the sign-in hint, at once');

    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
      if (c.read(loginAccessControllerProvider).value?.workspaces.isNotEmpty ??
          false) {
        break;
      }
    }
    expect(c.read(loginAccessControllerProvider).value?.workspaces.single.id,
        'ws-team');
  });

  test('whoami unreachable with nothing cached: the Admin user\'s surface of '
      'the build before (every login there was one)', () async {
    final adapter = StubAdapter((o) => (status: 500, body: '{}'));
    final c = boot(adapter);
    final access = await c.read(loginAccessControllerProvider.future);
    expect(access.legacy, isTrue);
    expect(await readCachedAccess(db, 's1'), isNull);
  });

  test('a QR sign-in on this build with whoami unreachable offers only what '
      'every login has', () async {
    await db.setSetting(loginAccessKey('s1'), kAccessUnknown);
    final adapter = StubAdapter((o) => (status: 500, body: '{}'));
    final c = boot(adapter);
    final access = await c.read(loginAccessControllerProvider.future);
    expect(access.isAdminUser, isFalse);
    expect(access.ownerContent, isFalse);
  });

  test('a brain without whoami (404) is the legacy Admin user', () async {
    final adapter = StubAdapter((o) => (status: 404, body: '{}'));
    final c = boot(adapter);
    final access = await c.read(loginAccessControllerProvider.future);
    expect(access.legacy, isTrue);
  });

  test('a login\'s cache and workspace go with its data', () async {
    await writeCachedAccess(db, 's1', LoginAccess.fromRole('member'));
    await db.setSetting('workspace.s1', 'ws-team');
    await writeCachedAccess(db, 's2', LoginAccess.fromRole('member'));

    await db.clearUserData(sessionId: 's1');

    expect(await readCachedAccess(db, 's1'), isNull);
    expect(await db.getSetting('workspace.s1'), isNull);
    expect(await readCachedAccess(db, 's2'), isNotNull,
        reason: 'another login keeps its own');
  });

  test('signed out: nothing is asked', () async {
    when(() => tokens.read()).thenAnswer((_) async => null);
    final adapter = StubAdapter((o) => (status: 200, body: '{}'));
    final c = boot(adapter);
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedOut);
    final access = await c.read(loginAccessControllerProvider.future);
    expect(access.isAdminUser, isFalse);
    expect(access.ownerContent, isFalse);
    expect(adapter.requests, isEmpty);
  });

  test("an answer for another login (a switch meanwhile) is dropped, not "
      "cached as this login's", () async {
    // s1 is known to be login-a; the brain answers for login-m.
    await (db.update(db.sessions)..where((s) => s.id.equals('s1')))
        .write(const SessionsCompanion(loginId: Value('login-a')));
    await writeCachedAccess(db, 's1', LoginAccess.fromRole('member'));
    final adapter = StubAdapter(
      (o) => (status: 200, body: jsonEncode(_memberWhoami())),
    );
    final c = boot(adapter);
    c.listen(loginAccessControllerProvider, (_, _) {});
    await c.read(loginAccessControllerProvider.future);
    await c.read(loginAccessControllerProvider.notifier).refresh();

    expect(adapter.requests, isNotEmpty);
    expect((await readCachedAccess(db, 's1'))?.loginId, isNull);
    expect(c.read(loginAccessControllerProvider).value?.loginId, isNull);
  });

  test('an answer that lands after a switch is not cached under the login '
      'that asked', () async {
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's2',
            baseUrl: 'http://brain.test',
            addedAt: now,
            lastUsedAt: now,
          ),
        );
    await writeCachedAccess(db, 's1', LoginAccess.fromRole('member'));
    final adapter = StubAdapter((o) {
      // The switch lands while whoami is on its way.
      db.setSetting('active_session_id', 's2');
      return (status: 200, body: jsonEncode(_memberWhoami()));
    });
    final c = boot(adapter);
    c.listen(loginAccessControllerProvider, (_, _) {});
    await c.read(loginAccessControllerProvider.future);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(adapter.requests, isNotEmpty);
    expect((await readCachedAccess(db, 's1'))?.loginId, isNull);
  });
}
