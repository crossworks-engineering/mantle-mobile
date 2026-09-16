import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/token_store.dart';
import '../../data/server/server_config.dart';
import '../../features/auth/session_controller.dart';
import 'auth_failure.dart';

part 'dio_provider.g.dart';

/// App-wide Dio for talking to Mantle. Base URL comes from [ServerConfig] (so
/// it rebuilds when the server changes); the bearer token is injected per
/// request. On an auth failure it ends the session (see
/// [SessionController.sessionInvalidated]), so the router bounces to login
/// and nothing of the account stays on the device.
///
/// Auth failure = HTTP 401, OR a 3xx redirect whose path is `/login`
/// ([isAuthFailure]). The latter happens for a server-revoked-but-unexpired
/// token: it clears Mantle's Edge gate (valid signature) but `requireOwner()`
/// redirects it. We disable redirect-following so we can see that.
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
        if (!optedOut && isAuthFailure(e)) {
          await ref.read(sessionControllerProvider.notifier).sessionInvalidated();
        }
        handler.next(e);
      },
    ),
  );

  return dio;
}
