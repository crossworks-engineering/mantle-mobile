import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/mobile_build.dart';
import '../../data/auth/session_repository.dart';
import '../../data/auth/token_store.dart';
import '../../data/auth/whoami_api.dart';
import '../../data/db/app_database.dart';
import 'session_controller.dart';

part 'session_identity.g.dart';

/// A bare client for one brain, used to ask it who a held login is. Not the
/// app's client: that one is the login in use's, and its auth handler signs
/// that login out on a 401. A provider so tests can answer for the brain.
/// It names the phone build too, as every request does.
@Riverpod(keepAlive: true)
Dio Function(String baseUrl) identityDioFactory(Ref ref) => (baseUrl) => Dio(
      BaseOptions(
        baseUrl: baseUrl,
        followRedirects: false,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    )..interceptors.add(MobileBuildInterceptor());

/// Learns the (brain, login) pair of the logins this device holds, so a tap
/// on a push can find the login it was for ([resolveTap]).
///
/// Each login is asked about with ITS OWN bearer, sent only to ITS OWN
/// brain: the pair is recorded for the session that asked, whatever login is
/// in use by the time the answer comes.
class SessionIdentity {
  SessionIdentity(this._sessions, this._tokens, this._dioFor);

  final SessionRepository _sessions;
  final TokenStore _tokens;
  final Dio Function(String baseUrl) _dioFor;

  /// Ask [session]'s brain for its pair and record it. False when it could
  /// not be learned (no bearer, an older brain, offline). Never throws.
  Future<bool> learn(Session session) async {
    if (session.needsSignIn) return false;
    try {
      final token = await _tokens.readFor(session.id);
      if (token == null || token.isEmpty) return false;
      final dio = _dioFor(session.baseUrl);
      dio.options.headers['Authorization'] = 'Bearer $token';
      final pair = await fetchBrainIdentity(dio);
      if (pair == null) return false;
      await _sessions.recordBrainIdentity(
        session.id,
        brainId: pair.brainId,
        loginId: pair.loginId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Learn every held login whose pair is not known yet, together.
  Future<void> learnUnknown() async {
    final unknown = [
      for (final s in await _sessions.list())
        if (s.brainId == null && !s.needsSignIn) s,
    ];
    await Future.wait(unknown.map(learn));
  }
}

@Riverpod(keepAlive: true)
SessionIdentity sessionIdentity(Ref ref) => SessionIdentity(
      ref.watch(sessionRepositoryProvider),
      ref.watch(tokenStoreProvider),
      ref.watch(identityDioFactoryProvider),
    );

/// Learns the login in use's pair once it is signed in (a sign-in, a switch,
/// the first start after the update that added the pair). Watched once from
/// the app root; nothing reads its value.
@Riverpod(keepAlive: true)
class BrainIdentitySync extends _$BrainIdentitySync {
  @override
  void build() {
    final status = ref.watch(sessionControllerProvider).value;
    // A switch between two logins on one brain changes no status; the epoch
    // moves with every change of the login in use.
    ref.watch(sessionEpochProvider);
    if (status != AuthStatus.loggedIn) return;
    unawaited(_learnActive());
  }

  Future<void> _learnActive() async {
    final active = await ref.read(sessionRepositoryProvider).active();
    if (active == null || active.brainId != null) return;
    await ref.read(sessionIdentityProvider).learn(active);
  }
}
