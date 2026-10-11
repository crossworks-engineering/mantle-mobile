// The tap router picks the login a push was for, learning the pair of held
// logins it does not know yet by asking each one's own brain with that
// login's own bearer. Real SessionRepository and TokenStore (in-memory Drift
// and the secure-storage mock); the brains answer through a stub adapter.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/token_refresh.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/push/notification_tap.dart';
import 'package:jackdaw/features/auth/session_identity.dart';
import 'package:jackdaw/routing/notification_router.dart';

import '../helpers/stub_dio.dart';

const _a = 'https://a.example';
const _b = 'https://b.example';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer c;
  late List<RequestOptions> asked;
  // What each brain answers to whoami, by address.
  late Map<String, StubAnswer> whoami;

  Future<void> hold(String id, String baseUrl, {String? brainId, String? loginId}) async {
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: id,
            baseUrl: baseUrl,
            addedAt: now,
            lastUsedAt: now,
            brainId: Value(brainId),
            loginId: Value(loginId),
          ),
        );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      TokenStore.keyFor('s1'): 'bearer-s1',
      TokenStore.keyFor('s2'): 'bearer-s2',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    asked = [];
    whoami = {};
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        identityDioFactoryProvider.overrideWithValue((baseUrl) {
          final adapter = StubAdapter((o) {
            asked.add(o);
            return whoami[baseUrl] ?? (status: 404, body: '{}');
          });
          return Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
        }),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(db.close);
    await db.setSetting(AppDatabase.activeSessionKey, 's1');
  });

  StubAnswer me(String brainId, String loginId) => (
        status: 200,
        body: jsonEncode({'role': 'admin', 'brainId': brainId, 'loginId': loginId}),
      );

  const push = NotificationTap(
    deepLink: '/chat/ada',
    itemLink: '/events/e1',
    brainId: 'brain-b',
    loginId: 'admin-9',
  );

  test('a push for a held login whose pair is known switches to it, asking no one',
      () async {
    await hold('s1', _a, brainId: 'brain-a', loginId: 'admin-1');
    await hold('s2', _b, brainId: 'brain-b', loginId: 'admin-9');

    final d = await c.read(notificationRouterProvider).decide(push);

    expect(d, isA<SwitchThenFollow>());
    expect((d as SwitchThenFollow).sessionId, 's2');
    expect(d.route, '/events/e1');
    expect(asked, isEmpty);
  });

  test("an unknown pair is learned from that login's own brain, with its own "
      'bearer, then matched', () async {
    await hold('s1', _a, brainId: 'brain-a', loginId: 'admin-1');
    await hold('s2', _b);
    whoami[_b] = me('brain-b', 'admin-9');

    final d = await c.read(notificationRouterProvider).decide(push);

    expect((d as SwitchThenFollow).sessionId, 's2');
    expect(asked, hasLength(1));
    expect(asked.single.uri.toString(), '$_b/api/auth/whoami');
    expect(asked.single.headers['Authorization'], 'Bearer bearer-s2');
    final s2 = await c.read(sessionRepositoryProvider).byId('s2');
    expect(s2!.brainId, 'brain-b');
    expect(s2.loginId, 'admin-9');
  });

  test('a push for a login this device does not hold opens home', () async {
    await hold('s1', _a, brainId: 'brain-a', loginId: 'admin-1');
    await hold('s2', _b);
    whoami[_b] = me('brain-b', 'admin-2');

    final d = await c.read(notificationRouterProvider).decide(push);
    expect(d, isA<OpenHome>());
  });

  test('a brain that cannot say (older, or offline) never gets a guess', () async {
    await hold('s1', _a, brainId: 'brain-a', loginId: 'admin-1');
    await hold('s2', _b); // whoami answers 404

    final d = await c.read(notificationRouterProvider).decide(push);
    expect(d, isA<OpenHome>());
    expect((await c.read(sessionRepositoryProvider).byId('s2'))!.brainId, isNull);
  });

  test('a push that names no login opens on the login in use, asking no one', () async {
    await hold('s1', _a);
    final d = await c
        .read(notificationRouterProvider)
        .decide(const NotificationTap(deepLink: '/pending'));
    expect((d as FollowOnActive).route, '/pending');
    expect(asked, isEmpty);
  });

  test('learning waits out a rotation of that login and asks with the new '
      'bearer, never the one being replaced', () async {
    await hold('s2', _b);
    whoami[_b] = me('brain-b', 'admin-9');
    final gate = c.read(tokenRefreshGateProvider);
    final rotate = Completer<void>();
    final rotation = gate.run('s2', () async {
      await rotate.future;
      await c.read(tokenStoreProvider).writeFor('s2', 'bearer-s2-new');
    });

    final session = (await c.read(sessionRepositoryProvider).byId('s2'))!;
    final learning = c.read(sessionIdentityProvider).learn(session);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(asked, isEmpty);

    rotate.complete();
    await rotation;
    expect(await learning, isTrue);
    expect(asked.single.headers['Authorization'], 'Bearer bearer-s2-new');
    expect(gate.sending('s2'), 0);
  });
}
