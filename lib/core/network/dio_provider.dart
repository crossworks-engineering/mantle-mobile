import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/token_store.dart';
import '../../data/server/server_config.dart';
import '../../features/auth/session_controller.dart';

part 'dio_provider.g.dart';

/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it clears the token and invalidates the session,
/// so the router bounces to login.
///
/// Auth failure = HTTP 401, OR a 3xx redirect to /login. The latter happens for
/// a server-revoked-but-unexpired token: it clears Mantle's Edge gate (valid
/// signature) but `requireOwner()` redirects it (see the Phase 1 notes). We
/// disable redirect-following so we can see that and treat it as a logout.
@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final baseUrl = ref.watch(serverConfigProvider).value ?? '';

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      followRedirects: false,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStoreProvider).read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        // Login opts out (a 401 there means "wrong password", not "log out").
        final optedOut = e.requestOptions.extra['skipAuthHandler'] == true;
        final code = e.response?.statusCode ?? 0;
        final location = e.response?.headers.value('location') ?? '';
        final authFailed = code == 401 ||
            (code >= 300 && code < 400 && location.contains('/login'));
        if (!optedOut && authFailed) {
          await ref.read(tokenStoreProvider).clear();
          ref.invalidate(sessionControllerProvider);
        }
        handler.next(e);
      },
    ),
  );

  return dio;
}
