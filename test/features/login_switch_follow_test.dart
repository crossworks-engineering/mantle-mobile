// What follows the login in use across a switch: the Android direct
// connection (M3) and the data screens show (M5). Real SessionController,
// SessionRepository and TokenStore over in-memory Drift and the
// secure-storage mock; the sign-in, the wipe and the foreground-service
// plugin are faked.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/data/auth/auth_api.dart';
import 'package:jackdaw/data/auth/auth_repository.dart';
import 'package:jackdaw/data/auth/session_repository.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/dashboard/dashboard_api.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/push/direct_push_service.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:jackdaw/features/dashboard/dashboard_controller.dart';
import 'package:jackdaw/features/settings/push/direct_push_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSessionWipe extends Mock implements SessionWipe {}

/// The foreground service, without the plugin.
class FakeDirectPush implements DirectPush {
  ({String baseUrl, String sessionId})? running;
  bool leftByOlderBuild = false;
  final starts = <({String baseUrl, String sessionId})>[];

  @override
  bool get supported => true;

  @override
  Future<bool> isRunning() async => running != null;

  @override
  Future<bool> isRunningFor({
    required String baseUrl,
    required String sessionId,
  }) async =>
      running?.baseUrl == baseUrl && running?.sessionId == sessionId;

  @override
  Future<bool> startedByOlderBuild() async => leftByOlderBuild;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> start({
    required String baseUrl,
    required String sessionId,
  }) async {
    running = (baseUrl: baseUrl, sessionId: sessionId);
    starts.add(running!);
    leftByOlderBuild = false;
  }

  @override
  Future<void> stop() async {
    running = null;
    leftByOlderBuild = false;
  }

  @override
  Future<void> pauseForRotation(String sessionId) async {}

  @override
  Future<void> resumeAfterRotation(String sessionId) async {}
}

/// Answers the dashboard summary with a count that names the bearer it saw.
class _PerLoginAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String? ?? '';
    final n = int.tryParse(auth.replaceFirst('Bearer tok-', '')) ?? 0;
    return ResponseBody.fromString(
      jsonEncode({
        'brain': {'nodesTotal': n},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _brain = 'https://m.example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockAuthRepository authRepo;
  late MockSessionWipe wipe;
  late FakeDirectPush direct;
  late ProviderContainer c;
  var minted = 0;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    authRepo = MockAuthRepository();
    wipe = MockSessionWipe();
    direct = FakeDirectPush();
    minted = 0;
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(authRepo),
        sessionWipeProvider.overrideWithValue(wipe),
        directPushProvider.overrideWithValue(direct),
        dashboardApiProvider.overrideWith((ref) {
          final dio = ref.watch(dioProvider)
            ..httpClientAdapter = _PerLoginAdapter();
          return DashboardApi(dio);
        }),
      ],
    );
    // The real wipe stops the service; the rest is not under test here.
    when(() => wipe.stopActiveServices()).thenAnswer((_) => direct.stop());
    when(() => wipe.unpairPush()).thenAnswer((_) async {});
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async {});
    when(() => authRepo.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenAnswer((_) async {
      final token = 'tok-${++minted}';
      await c.read(tokenStoreProvider).write(token);
      return SignInResult(token: token, role: 'admin');
    });
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  SessionController controller() =>
      c.read(sessionControllerProvider.notifier);

  /// Two logins on one brain, b in use.
  Future<({String a, String b})> twoLogins() async {
    await controller().setServer(_brain);
    await c.read(sessionControllerProvider.future);
    await controller().signIn(email: 'a@example.com', password: 'pw');
    final a = (await c.read(sessionRepositoryProvider).activeId())!;
    await controller().startAddLogin();
    await controller().signIn(email: 'b@example.com', password: 'pw');
    final b = (await c.read(sessionRepositoryProvider).activeId())!;
    return (a: a, b: b);
  }

  /// Let the unawaited follow-ups run.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  group('the direct connection (M3)', () {
    test('an install updated from a build before several logins keeps it on, '
        'now for the login in use', () async {
      c.listen(directPushFollowProvider, (_, _) {});
      final logins = await twoLogins();
      direct.running = null; // the service stopped itself: no login id
      direct.leftByOlderBuild = true;

      await c.read(directPushFollowProvider.notifier).follow();

      expect(direct.running, (baseUrl: _brain, sessionId: logins.b));
      expect(await db.getSetting(AppDatabase.directPushWantedKey), '1');
    });

    test('a switch stops it and starts it again for the next login',
        () async {
      c.listen(directPushFollowProvider, (_, _) {});
      final logins = await twoLogins();
      await db.setSetting(AppDatabase.directPushWantedKey, '1');
      await c.read(directPushFollowProvider.notifier).follow();
      expect(direct.running?.sessionId, logins.b);

      expect(await controller().switchTo(logins.a), isTrue);
      await settle();

      expect(direct.running, (baseUrl: _brain, sessionId: logins.a));
    });

    test('off stays off: nothing is started without the choice', () async {
      c.listen(directPushFollowProvider, (_, _) {});
      final logins = await twoLogins();
      await controller().switchTo(logins.a);
      await settle();
      await c.read(directPushFollowProvider.notifier).follow();
      expect(direct.starts, isEmpty);
    });

    test('signed out, it is not started', () async {
      c.listen(directPushFollowProvider, (_, _) {});
      await db.setSetting(AppDatabase.directPushWantedKey, '1');
      await controller().setServer(_brain);
      await c.read(sessionControllerProvider.future);
      await c.read(directPushFollowProvider.notifier).follow();
      expect(direct.starts, isEmpty);
    });
  });

  group('screens after a switch on one brain (M5)', () {
    test('the dashboard is fetched again, as the new login', () async {
      final logins = await twoLogins();
      c.listen(dashboardControllerProvider, (_, _) {});
      expect(
        (await c.read(dashboardControllerProvider.future)).summary.brainNodes,
        2,
      );

      await controller().switchTo(logins.a);
      await settle();

      expect(
        (await c.read(dashboardControllerProvider.future)).summary.brainNodes,
        1,
      );
    });
  });
}
