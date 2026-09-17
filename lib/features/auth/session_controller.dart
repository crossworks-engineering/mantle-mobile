import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/auth/session_wipe.dart';
import '../../data/auth/token_store.dart';
import '../../data/server/server_config.dart';
import '../agents/agent_controller.dart';
import '../settings/settings_repository.dart';

part 'session_controller.g.dart';

/// The three states the app gate cares about.
enum AuthStatus { needsServer, loggedOut, loggedIn }

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out) update it and the router follows.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  Future<AuthStatus> build() async {
    // Rebuilds when the server URL changes (e.g. after setup).
    final baseUrl = await ref.watch(serverConfigProvider.future);
    if (baseUrl == null || baseUrl.isEmpty) return AuthStatus.needsServer;

    final token = await ref.read(tokenStoreProvider).read();
    return (token == null || token.isEmpty)
        ? AuthStatus.loggedOut
        : AuthStatus.loggedIn;
  }

  /// Save the Mantle server URL; `build()` re-runs via its watch and moves us
  /// from `needsServer` to `loggedOut`.
  Future<void> setServer(String url) =>
      ref.read(serverConfigProvider.notifier).setUrl(url);

  /// Logs in and flips to `loggedIn`. Throws [AuthException] on bad credentials.
  /// The email is remembered so Settings can say who is signed in.
  Future<void> signIn({required String email, required String password}) async {
    await ref.read(authRepositoryProvider).login(email: email, password: password);
    await ref.read(settingsRepositoryProvider).setAccountEmail(email);
    ref.invalidate(accountEmailProvider);
    state = const AsyncData(AuthStatus.loggedIn);
  }

  /// Leave this server: a full [signOut] (server revoke, local wipe), then
  /// forget the address so `build()` lands on `needsServer` and the router
  /// shows setup. A wipe that cannot clear the token throws before the
  /// address goes, so the user is never stranded half-way.
  Future<void> changeServer() async {
    await signOut();
    await ref.read(serverConfigProvider.notifier).setUrl('');
  }

  /// The user signs out: unpair push (needs the token), revoke the token,
  /// then wipe every local trace and flip to `loggedOut`. Throws only when the
  /// local token could not be cleared, in which case the session stays.
  Future<void> signOut() async {
    final wipe = ref.read(sessionWipeProvider);
    await wipe.unpairPush();
    await ref.read(authRepositoryProvider).logout();
    await wipe.wipeLocal();
    await _forgetAccountState();
    state = const AsyncData(AuthStatus.loggedOut);
  }

  /// The server says the token is dead (a 401, or a redirect to login). Flip
  /// to `loggedOut` at once so the router bounces, then wipe locally. No
  /// server calls: this runs from inside the failed request. Idempotent —
  /// a burst of failing requests wipes once.
  Future<void> sessionInvalidated() async {
    if (state.value != AuthStatus.loggedIn) return;
    state = const AsyncData(AuthStatus.loggedOut);
    try {
      await ref.read(sessionWipeProvider).wipeLocal();
      await _forgetAccountState();
    } catch (_) {
      /* the token clear failed; build() will re-read it on next launch */
    }
  }

  /// Caches keyed to the account, not the device.
  Future<void> _forgetAccountState() async {
    ref.invalidate(agentControllerProvider);
    await ref.read(settingsRepositoryProvider).clearAccountEmail();
    ref.invalidate(accountEmailProvider);
  }
}

/// The signed-in email for display, null when signed out. Invalidated by the
/// session controller whenever the account changes.
@Riverpod(keepAlive: true)
Future<String?> accountEmail(Ref ref) =>
    ref.watch(settingsRepositoryProvider).accountEmail();
