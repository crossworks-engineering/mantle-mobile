import 'dart:async' show Completer, TimeoutException, unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/session_identity.dart' show identityDioFactoryProvider;
import '../db/app_database.dart' show Session;
import '../push/direct_push_service.dart' show directPushProvider;
import 'session_repository.dart';
import 'token_store.dart';

part 'token_refresh.g.dart';

/// Holds requests while a token refresh is in flight, one login at a time.
///
/// A device-login bearer lasts 30 days and rotates through
/// `POST /api/auth/token/refresh`. When it rotates, the old token dies, and a
/// rotated token presented again AFTER its successor was used reads to the
/// brain as a stolen copy: it ends every session of the login. So nothing may
/// leave with the old bearer once the refresh has started, and nothing sent
/// with it may still be on its way when the refresh is posted:
///
/// * every client that attaches a login's bearer takes it through [acquire],
///   which waits out a refresh of THAT login and reads the bearer again if
///   one began while it was reading, and counts the request as in flight
///   until [release] (the answer's headers are in: the brain has read it);
/// * [run] closes the gate first, then waits for the count to reach zero
///   before the refresh is posted. When it does not drain in [drainTimeout]
///   the refresh is skipped (the next start, switch or resume tries again):
///   rotating under a request still on its way is the one thing never done.
///
/// The gate is keyed by session id: a refresh of one login never holds
/// another's requests, and a refresh asked for while another login's runs
/// (a switch mid-refresh) runs after it instead of joining it.
class TokenRefreshGate {
  TokenRefreshGate({this.drainTimeout = const Duration(seconds: 20)});

  /// How long [run] waits for requests already sent with the old bearer.
  final Duration drainTimeout;

  final Map<String, Completer<void>> _inFlight = {};
  final Map<String, int> _sending = {};
  final Map<String, Completer<void>> _drained = {};

  /// Resolves once no refresh is running for [sessionId] (for any login when
  /// null).
  Future<void> wait([String? sessionId]) async {
    while (true) {
      final pending = sessionId == null
          ? _inFlight.values.toList()
          : [?_inFlight[sessionId]];
      if (pending.isEmpty) return;
      await Future.wait([for (final c in pending) c.future]);
    }
  }

  /// Whether any refresh is running.
  bool get busy => _inFlight.isNotEmpty;

  /// Whether [sessionId]'s refresh is running.
  bool busyFor(String sessionId) => _inFlight.containsKey(sessionId);

  /// Requests sent with [sessionId]'s bearer that have no answer yet.
  int sending(String sessionId) => _sending[sessionId] ?? 0;

  /// The bearer to send for [sessionId], read by [read] once no refresh of
  /// that login runs. A refresh that began while it was being read means it
  /// may be the token being replaced: wait for the refresh and read again.
  /// A bearer handed out counts as one request in flight; the caller hands
  /// it back with [release] once the answer (or the failure) is in. Null
  /// (nothing counted) when the login holds no bearer.
  Future<String?> acquire(
    String sessionId,
    Future<String?> Function() read,
  ) async {
    while (true) {
      await wait(sessionId);
      final token = await read();
      // No await between this check and the count: [run] marks the gate
      // closed before it looks at the count, so the two cannot interleave.
      if (busyFor(sessionId)) continue;
      if (token == null || token.isEmpty) return null;
      _sending[sessionId] = sending(sessionId) + 1;
      return token;
    }
  }

  /// One request [acquire] counted has its answer.
  void release(String sessionId) {
    final left = sending(sessionId) - 1;
    if (left > 0) {
      _sending[sessionId] = left;
      return;
    }
    _sending.remove(sessionId);
    _drained.remove(sessionId)?.complete();
  }

  Future<bool> _drain(String sessionId) async {
    if (sending(sessionId) == 0) return true;
    final drained = _drained.putIfAbsent(sessionId, Completer<void>.new);
    try {
      await drained.future.timeout(drainTimeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }

  /// Run [refresh] for [sessionId] with that login's gate closed, once every
  /// request already sent with its bearer has its answer. A second call for
  /// the same login while one runs joins it; a call for another login waits
  /// for the running one, then runs its own.
  Future<void> run(String sessionId, Future<void> Function() refresh) async {
    while (true) {
      final same = _inFlight[sessionId];
      if (same != null) return same.future;
      if (_inFlight.isEmpty) break;
      await wait();
    }
    final done = Completer<void>();
    _inFlight[sessionId] = done;
    try {
      if (await _drain(sessionId)) await refresh();
    } finally {
      _inFlight.remove(sessionId);
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
  TokenRefresher(
    this._sessions,
    this._tokens,
    this._dioFor,
    this._gate, {
    this.pauseStream,
    this.resumeStream,
  });

  final SessionRepository _sessions;
  final TokenStore _tokens;
  final Dio Function(String baseUrl) _dioFor;
  final TokenRefreshGate _gate;

  /// Holds the Android direct connection's reconnects while a rotation is
  /// posted (it runs in its own isolate, outside the gate), and lets them go
  /// once the new token is stored. [pauseStream] answers false when a send
  /// of the connection's, made with the bearer being replaced, has not had
  /// its answer in time: the refresh is then skipped, as for a request of
  /// the app's own that does not drain.
  final Future<bool> Function(String sessionId)? pauseStream;
  final Future<void> Function(String sessionId)? resumeStream;

  /// The refresh running per login, so a caller that joins it learns what
  /// it did.
  final Map<String, Future<RefreshOutcome>> _running = {};

  /// Refresh the active login's token. [onRefused] runs when the brain says
  /// the token is dead, and only while that login is still the one in use.
  /// A call while that login's refresh runs joins it, and answers its
  /// outcome.
  Future<RefreshOutcome> refreshActive({
    Future<void> Function()? onRefused,
  }) async {
    final session = await _sessions.active();
    if (session == null || session.needsSignIn) return RefreshOutcome.skipped;
    final joined = _running[session.id];
    if (joined != null) return joined;
    final running = _runFor(session, onRefused);
    _running[session.id] = running;
    try {
      return await running;
    } finally {
      if (identical(_running[session.id], running)) {
        _running.remove(session.id);
      }
    }
  }

  Future<RefreshOutcome> _runFor(
    Session session,
    Future<void> Function()? onRefused,
  ) async {
    var outcome = RefreshOutcome.skipped;
    await _gate.run(session.id, () async {
      outcome = await _refresh(session, onRefused: onRefused);
    });
    return outcome;
  }

  Future<RefreshOutcome> _refresh(
    Session session, {
    Future<void> Function()? onRefused,
  }) async {
    // Read now, with the gate closed and every request on the old bearer
    // answered: this is the token the refresh replaces.
    final held = await _sessions.byId(session.id);
    if (held == null || held.needsSignIn) return RefreshOutcome.skipped;
    final token = await _tokens.readFor(session.id);
    if (token == null || token.isEmpty) return RefreshOutcome.skipped;
    final dio = _dioFor(session.baseUrl);
    dio.options.headers['Authorization'] = 'Bearer $token';
    var paused = false;
    try {
      var clear = true;
      final pause = pauseStream;
      try {
        if (pause != null) {
          paused = true;
          clear = await pause(session.id);
        }
      } catch (_) {
        /* no direct connection here */
      }
      // The direct connection has a send on its way with this bearer: never
      // rotate under it. The next start, switch or resume tries again.
      if (!clear) return RefreshOutcome.skipped;
      // A refresh whose answer was lost on the way back (a timeout, a broken
      // connection) is asked once more before the gate opens: the brain hands
      // the same new token back until it is first used, so asking again is
      // safe, and letting requests go on the old bearer while a new one may
      // already be minted is what is avoided.
      Response<Map<String, dynamic>> res;
      try {
        res = await dio.post<Map<String, dynamic>>('/api/auth/token/refresh');
      } on DioException catch (e) {
        if (!_answerLost(e)) rethrow;
        res = await dio.post<Map<String, dynamic>>('/api/auth/token/refresh');
      }
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
      if (paused) {
        try {
          await resumeStream?.call(session.id);
        } catch (_) {
          /* the marker ages out on its own */
        }
      }
    }
  }
}

/// Whether [e] may have come after the refresh was posted, with its answer
/// lost: a timeout on the way out or back, or a connection that broke. A
/// connect that never happened, or any answer, is not.
bool _answerLost(DioException e) =>
    e.response == null &&
    switch (e.type) {
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.unknown =>
        true,
      _ => false,
    };

@Riverpod(keepAlive: true)
TokenRefresher tokenRefresher(Ref ref) {
  final direct = ref.watch(directPushProvider);
  return TokenRefresher(
    ref.watch(sessionRepositoryProvider),
    ref.watch(tokenStoreProvider),
    ref.watch(identityDioFactoryProvider),
    ref.watch(tokenRefreshGateProvider),
    pauseStream: direct.pauseForRotation,
    resumeStream: direct.resumeAfterRotation,
  );
}

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
