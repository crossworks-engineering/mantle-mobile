import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/auth_repository.dart';
import '../../data/auth/token_store.dart';
import '../../data/server/server_config.dart';

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
  Future<void> signIn({required String email, required String password}) async {
    await ref.read(authRepositoryProvider).login(email: email, password: password);
    state = const AsyncData(AuthStatus.loggedIn);
  }

  /// Revokes the token and flips to `loggedOut`.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthStatus.loggedOut);
  }
}
