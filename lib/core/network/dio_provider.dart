import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/session_repository.dart';
import '../../data/auth/token_refresh.dart';
import '../../data/auth/token_store.dart';
import '../../data/server/server_config.dart';
import '../../features/auth/session_controller.dart';
import 'auth_failure.dart';
import 'mobile_build.dart';

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

  // The build header first: every request names the phone build, the
  // sign-in calls included (a member's QR claim needs it).
  dio.interceptors.add(MobileBuildInterceptor());

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // The bearer is this interceptor's to set, every time: a retry comes
        // back here with the header it was refused with.
        options.headers.remove('Authorization');
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
        var bearer = false;
        if (active != null && active.baseUrl == baseUrl) {
          Future<String?> read() =>
              ref.read(tokenStoreProvider).readFor(active.id);
          // A token refresh of this login rotates the bearer: the gate holds
          // the request while one runs, reads the bearer again if one began
          // while it was being read, and counts the request until its answer
          // is in, so the refresh is never posted while a request with the
          // old bearer is still on its way (the brain reads a rotated token
          // used after its successor as stolen, and ends every session of
          // the login).
          final skipGate = options.extra['skipRefreshGate'] == true;
          final token = skipGate
              ? await read()
              : await ref.read(tokenRefreshGateProvider).acquire(active.id, read);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            options.extra = {
              ...options.extra,
              kBearerSessionExtra: active.id,
              if (!skipGate) _kCounted: true,
            };
            bearer = true;
          }
        }
        // A request that went out bare says nothing about the login in use:
        // its 401 must not sign that login out. This is the moment of a
        // switch to another brain, when screens refetch before the address
        // has caught up with the new login.
        if (!bearer) {
          options.extra = {...options.extra, 'skipAuthHandler': true};
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        _release(ref, response.requestOptions);
        handler.next(response);
      },
      onError: (e, handler) async {
        final options = e.requestOptions;
        _release(ref, options);
        // Login opts out (a 401 there means "wrong password", not "log out").
        final optedOut = options.extra['skipAuthHandler'] == true;
        if (optedOut || !isAuthFailure(e)) return handler.next(e);
        // Refused with a bearer that is no longer the login's (a rotation
        // landed while it was on its way): that says nothing about the token
        // in use. Ask once more with the current one, while that login is
        // still the one in use; never sign anyone out over it.
        final sessionId = options.extra[kBearerSessionExtra];
        if (sessionId is String) {
          final current = await ref.read(tokenStoreProvider).readFor(sessionId);
          final sent = options.headers['Authorization'];
          if (current != null &&
              current.isNotEmpty &&
              sent != 'Bearer $current') {
            final retried = options.extra[_kRetried] == true;
            final stillActive =
                await ref.read(sessionRepositoryProvider).activeId() ==
                    sessionId;
            if (retried || !stillActive) return handler.next(e);
            try {
              final again = await dio.fetch<dynamic>(
                options.copyWith(
                  extra: {
                    ...options.extra,
                    _kRetried: true,
                  }..remove(_kCounted),
                ),
              );
              return handler.resolve(again);
            } on DioException catch (failed) {
              return handler.next(failed);
            }
          }
        }
        await ref.read(sessionControllerProvider.notifier).sessionInvalidated();
        handler.next(e);
      },
    ),
  );

  return dio;
}

/// The session whose bearer a request carries (in `RequestOptions.extra`).
const kBearerSessionExtra = 'bearerSession';

/// The request holds one count of the refresh gate's in-flight requests.
const _kCounted = 'bearerCounted';

/// The request is a retry with a bearer that was rotated under the first try.
const _kRetried = 'bearerRetried';

/// Hand the request's in-flight count back to the gate, once.
void _release(Ref ref, RequestOptions options) {
  if (options.extra[_kCounted] != true) return;
  options.extra = {...options.extra}..remove(_kCounted);
  final sessionId = options.extra[kBearerSessionExtra];
  if (sessionId is String) {
    ref.read(tokenRefreshGateProvider).release(sessionId);
  }
}
