// The auth interceptor: the one place a dead token turns into a signed-out,
// wiped device. Real ServerConfig + SessionController over in-memory Drift;
// the token store and the wipe are mocked; the network is a stub adapter.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/data/auth/session_wipe.dart';
import 'package:jackdaw/data/auth/token_store.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/server/server_config.dart';
import 'package:jackdaw/features/auth/session_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStore extends Mock implements TokenStore {}

class MockSessionWipe extends Mock implements SessionWipe {}

/// Answers every request with one fixed status + headers.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, {this.headers = const {}});

  final int status;
  final Map<String, List<String>> headers;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString('', status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late MockTokenStore tokenStore;
  late MockSessionWipe wipe;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.setSetting('server_base_url', 'https://m.example.com');
    // The login that server address belongs to: the client attaches a bearer
    // only when the active session is for the brain it is talking to.
    final now = DateTime.now();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 'session-1',
            baseUrl: 'https://m.example.com',
            addedAt: now,
            lastUsedAt: now,
          ),
        );
    await db.setSetting('active_session_id', 'session-1');
    tokenStore = MockTokenStore();
    when(() => tokenStore.read()).thenAnswer((_) async => 'tok');
    wipe = MockSessionWipe();
    when(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')))
        .thenAnswer((_) async {});
    when(() => wipe.stopActiveServices()).thenAnswer((_) async {});
    when(() => tokenStore.clearFor(any())).thenAnswer((_) async {});
    when(() => tokenStore.readFor(any())).thenAnswer((_) async => null);
  });
  tearDown(() => db.close());

  Future<(ProviderContainer, Dio)> boot(_StubAdapter adapter) async {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(tokenStore),
        sessionWipeProvider.overrideWithValue(wipe),
      ],
    );
    addTearDown(c.dispose);
    await c.read(serverConfigProvider.future);
    expect(await c.read(sessionControllerProvider.future), AuthStatus.loggedIn);
    final dio = c.read(dioProvider)..httpClientAdapter = adapter;
    return (c, dio);
  }

  test('injects the bearer on every request', () async {
    final adapter = _StubAdapter(200);
    final (_, dio) = await boot(adapter);
    await dio.get<void>('/api/x');
    expect(adapter.last?.headers['Authorization'], 'Bearer tok');
    expect(adapter.last?.uri.toString(), 'https://m.example.com/api/x');
  });

  test('a 401 ends the session and wipes the device', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });

  test('a redirect to /login ends the session too', () async {
    final (c, dio) = await boot(
      _StubAdapter(302, headers: {'location': ['/login?next=%2F']}),
    );
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });

  test('a redirect elsewhere is an ordinary error', () async {
    final (c, dio) = await boot(
      _StubAdapter(302, headers: {'location': ['/pages/login-notes']}),
    );
    await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });

  test('a 401 on a request that opted out (login) is left alone', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    await expectLater(
      dio.get<void>('/api/auth/mobile-login',
          options: Options(extra: {'skipAuthHandler': true})),
      throwsA(isA<DioException>()),
    );
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedIn);
    verifyNever(() => wipe.wipeLocal(sessionId: any(named: 'sessionId')));
  });

  test('a burst of 401s wipes once', () async {
    final (c, dio) = await boot(_StubAdapter(401));
    for (var i = 0; i < 3; i++) {
      await expectLater(dio.get<void>('/api/x'), throwsA(isA<DioException>()));
    }
    expect(c.read(sessionControllerProvider).value, AuthStatus.loggedOut);
    verify(() => wipe.wipeLocal(sessionId: any(named: 'sessionId'))).called(1);
  });
}
