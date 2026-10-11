import 'dart:async' show Completer, unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/session_identity.dart' show identityDioFactoryProvider;
import 'session_repository.dart';
import 'token_store.dart';

part 'token_refresh.g.dart';

/// Holds requests while a token refresh is in flight.
///
/// A device-login bearer lasts 30 days and rotates through
/// `POST /api/auth/token/refresh`. When it rotates, the old token dies, and a
/// rotated token presented again AFTER its successor was used reads to the
/// brain as a stolen copy: it ends every session of the login. So nothing may
/// leave with the old bearer once the refresh has started; the app client
/// waits here before it attaches one.
class TokenRefreshGate {
  Completer<void>? _inFlight;

  /// Resolves once no refresh is running.
  Future<void> wait() => _inFlight?.future ?? Future<void>.value();

  bool get busy => _inFlight != null;

  /// Run [refresh] with the gate closed. A second call while one runs joins
  /// it instead of starting another.
  Future<void> run(Future<void> Function() refresh) async {
    final running = _inFlight;
    if (running != null) return running.future;
    final done = Completer<void>();
    _inFlight = done;
    try {
      await refresh();
    } finally {
      _inFlight = null;
      done.complete();
    }
  }
}

@Riverpod(keepAlive: true)
TokenRefreshGate tokenRefreshGate(Ref ref) => TokenRefreshGate();

/// What one refresh did.
enum RefreshOutcome {
  /// The brain answered the same token (more than 23 days left).
  unchanged,

  /// A new token was stored.
  rotated,

  /// The brain refused the token for good (401): the login must sign in.
  refused,

  /// Nothing learned: offline, an older brain without the route, a 429, a
  /// 403. The token is kept (none of these is a sign-out).
  skipped,
}

/// Rotates the bearer of the login in use (`POST /api/auth/token/refresh`).
///
/// Called at every start and after every switch: "too early" is a no-op on
/// the brain (the same token back, no row written), so it is cheap. A new
/// token only comes in the last 23 days of the 30. The answer's `token` is
/// always stored, so the app keeps only the newest one, and a lost answer is
/// safe to retry with the token still held (the brain hands the same new
/// token back until it is first used).
class TokenRefresher {
  TokenRefresher(this._sessions, this._tokens, this._dioFor, this._gate);

  final SessionRepository _sessions;
  final TokenStore _tokens;
  final Dio Function(String baseUrl) _dioFor;
  final TokenRefreshGate _gate;

  /// Refresh the active login's token. [onRefused] runs when the brain says
  /// the token is dead, and only while that login is still the one in use.
  Future<RefreshOutcome> refreshActive({
    Future<void> Function()? onRefused,
  }) async {
    var outcome = RefreshOutcome.skipped;
    await _gate.run(() async {
      outcome = await _refresh(onRefused: onRefused);
    });
    return outcome;
  }

  Future<RefreshOutcome> _refresh({
    Future<void> Function()? onRefused,
  }) async {
    final session = await _sessions.active();
    if (session == null || session.needsSignIn) return RefreshOutcome.skipped;
    final token = await _tokens.readFor(session.id);
    if (token == null || token.isEmpty) return RefreshOutcome.skipped;
    final dio = _dioFor(session.baseUrl);
    dio.options.headers['Authorization'] = 'Bearer $token';
    try {
      final res = await dio.post<Map<String, dynamic>>(
        '/api/auth/token/refresh',
      );
      final fresh = res.data?['token'];
      if (fresh is! String || fresh.isEmpty) return RefreshOutcome.skipped;
      if (fresh == token) return RefreshOutcome.unchanged;
      // Stored under THIS session, whatever is active by now: the token is
      // its login's, and the old one is already dead on the brain.
      final still = await _sessions.byId(session.id);
      if (still == null) return RefreshOutcome.skipped;
      await _tokens.writeFor(session.id, fresh);
      return RefreshOutcome.rotated;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if ((await _sessions.activeId()) == session.id) {
          await onRefused?.call();
        }
        return RefreshOutcome.refused;
      }
      return RefreshOutcome.skipped;
    } catch (_) {
      return RefreshOutcome.skipped;
    } finally {
      dio.close();
    }
  }
}

@Riverpod(keepAlive: true)
TokenRefresher tokenRefresher(Ref ref) => TokenRefresher(
      ref.watch(sessionRepositoryProvider),
      ref.watch(tokenStoreProvider),
      ref.watch(identityDioFactoryProvider),
      ref.watch(tokenRefreshGateProvider),
    );

/// Refreshes the login in use's token once it is signed in: at start, after
/// a sign-in and after a switch, and on a return to the foreground when the
/// last refresh is more than [_resumeEvery] old (a phone that keeps the app
/// alive for weeks still rotates in time). Watched once from the app root;
/// nothing reads its value.
@Riverpod(keepAlive: true)
class TokenRefreshSync extends _$TokenRefreshSync {
  static const _resumeEvery = Duration(hours: 6);

  int? _epoch;
  DateTime? _last;

  @override
  void build() {
    final status = ref.watch(sessionControllerProvider).value;
    final epoch = ref.watch(sessionEpochProvider);
    final lifecycle = ref.watch(appLifecycleProvider);
    if (status != AuthStatus.loggedIn) return;
    final last = _last;
    final changed = epoch != _epoch;
    final stale = last == null ||
        DateTime.now().difference(last) > _resumeEvery;
    if (!changed && !(lifecycle == AppLifecycleState.resumed && stale)) {
      return;
    }
    _epoch = epoch;
    _last = DateTime.now();
    unawaited(
      ref.read(tokenRefresherProvider).refreshActive(
            onRefused: () => ref
                .read(sessionControllerProvider.notifier)
                .sessionInvalidated(),
          ),
    );
  }
}
