import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/session_repository.dart';
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
  // A new client, and so a rebuild of everything built on it, whenever the
  // login in use changes. The address alone would miss a switch between two
  // logins on the same brain.
  ref.watch(sessionEpochProvider);

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
        // A bearer goes ONLY to the brain it was minted by. This client is
        // built for one address and the active login can change under it (a
        // switch to a login on another brain re-reads the address a moment
        // after the login becomes active), so the two are checked against
        // each other on every request instead of trusting the order things
        // happen in. A mismatch sends the request bare, and it fails closed.
        // The bearer is read for THAT session, not "the active one" a
        // second time: a switch between the two reads would pair this
        // session's address check with another session's bearer.
        final active = await ref.read(sessionRepositoryProvider).active();
        if (active != null && active.baseUrl == baseUrl) {
          final token = await ref.read(tokenStoreProvider).readFor(active.id);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
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
