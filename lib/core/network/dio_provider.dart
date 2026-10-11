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

  // Read once, here, and never through [ref] from an interceptor: a switch
  // of login rebuilds this provider, and a request still on its way across
  // the switch answers into a client whose [ref] is gone. Each of these is
  // kept alive for the app's life, so the copies held here stay the ones in
  // use. The session controller is reached through the container when it
  // is needed: its notifier is recreated whenever it rebuilds.
  final gate = ref.read(tokenRefreshGateProvider);
  final tokens = ref.read(tokenStoreProvider);
  final sessions = ref.read(sessionRepositoryProvider);
  final container = ref.container;

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
        final active = await sessions.active();
        var bearer = false;
        if (active != null && active.baseUrl == baseUrl) {
          Future<String?> read() => tokens.readFor(active.id);
          // A token refresh of this login rotates the bearer: the gate holds
          // the request while one runs, reads the bearer again if one began
          // while it was being read, and counts the request until its answer
          // is in, so the refresh is never posted while a request with the
          // old bearer is still on its way (the brain reads a rotated token
          // used after its successor as stolen, and ends every session of
          // the login).
          final skipGate = options.extra['skipRefreshGate'] == true;
          final token =
              skipGate ? await read() : await gate.acquire(active.id, read);
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
        _release(gate, response.requestOptions);
        handler.next(response);
      },
      onError: (e, handler) async {
        final options = e.requestOptions;
        _release(gate, options);
        // Login opts out (a 401 there means "wrong password", not "log out").
        final optedOut = options.extra['skipAuthHandler'] == true;
        if (optedOut || !isAuthFailure(e)) return handler.next(e);
        Future<void> signOut() => container
            .read(sessionControllerProvider.notifier)
            .sessionInvalidated();
        final sessionId = options.extra[kBearerSessionExtra];
        if (sessionId is! String) {
          await signOut();
          return handler.next(e);
        }
        // Only the login in use is ever signed out, and only over its own
        // bearer: a refusal of a login switched away from meanwhile says
        // nothing about the one in use.
        if (await sessions.activeId() != sessionId) return handler.next(e);
        final retried = options.extra[_kRetried] == true;
        final sent = options.headers['Authorization'];

        // Ask once more with the login's bearer as it is now, as a retry
        // that never comes back here for another. A body that cannot be
        // sent twice (a form, a stream) is not asked again: it fails with
        // the refusal, and signs nobody out, as the refusal was of a bearer
        // that is no longer the login's.
        Future<void> askAgain() async {
          if (!_replayable(options)) return handler.next(e);
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

        bool replaced(String? current) =>
            current != null && current.isNotEmpty && sent != 'Bearer $current';

        // Refused with a bearer that is no longer the login's (a rotation
        // landed while it was on its way): that says nothing about the token
        // in use. Never sign anyone out over it.
        if (replaced(await tokens.readFor(sessionId))) {
          if (retried) return handler.next(e);
          return askAgain();
        }
        // Refused with the bearer in use. Before signing the login out, ask
        // the brain about that token once through a refresh: a new token
        // means the request is asked again with it, the same token back
        // means the token is alive and this refusal is not a sign-out.
        if (!retried) {
          final outcome =
              await container.read(tokenRefresherProvider).refreshActive();
          if (await sessions.activeId() != sessionId) return handler.next(e);
          if (replaced(await tokens.readFor(sessionId))) return askAgain();
          if (outcome == RefreshOutcome.unchanged) return handler.next(e);
        }
        await signOut();
        handler.next(e);
      },
    ),
  );

  return dio;
}

/// Whether [options]' body can be sent a second time. A form is spent once
/// it has been sent, and a stream once it has been read.
bool _replayable(RequestOptions options) {
  final data = options.data;
  return data is! FormData && data is! Stream;
}

/// The session whose bearer a request carries (in `RequestOptions.extra`).
const kBearerSessionExtra = 'bearerSession';

/// The request holds one count of the refresh gate's in-flight requests.
const _kCounted = 'bearerCounted';

/// The request is a retry with a bearer that was rotated under the first try.
const _kRetried = 'bearerRetried';

/// Hand the request's in-flight count back to the gate, once.
void _release(TokenRefreshGate gate, RequestOptions options) {
  if (options.extra[_kCounted] != true) return;
  options.extra = {...options.extra}..remove(_kCounted);
  final sessionId = options.extra[kBearerSessionExtra];
  if (sessionId is String) gate.release(sessionId);
}
