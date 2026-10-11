import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/auth/auth_api.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/auth/login_access.dart';
import '../../data/auth/pairing_payload.dart';
import '../../data/auth/session_repository.dart';
import '../../data/auth/session_wipe.dart';
import '../../data/auth/token_refresh.dart' show tokenRefreshGateProvider;
import '../../data/auth/token_store.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import '../../data/push/push_keys.dart';
import '../../data/server/server_config.dart';
import '../agents/agent_controller.dart';
import '../settings/settings_repository.dart';
import 'login_access_controller.dart';
import 'session_identity.dart' show identityDioFactoryProvider;

part 'session_controller.g.dart';

/// The three states the app gate cares about.
enum AuthStatus { needsServer, loggedOut, loggedIn }

/// Single source of truth for "where should the app be?". Derived from the
/// persisted server URL + the presence of a bearer token; the router redirects
/// on it. Mutations (set server, sign in/out, switch) update it and the router
/// follows.
///
/// The device can hold SEVERAL logins ([SessionRepository]); this controller
/// is about the ACTIVE one. The server address and the bearer it reads are
/// the active session's, so the three states mean what they always meant.
///
/// Adding a login does not run alongside the one in use. It steps OUT of it
/// first (nobody active, so no bearer is attached to anything) and then walks
/// the same setup → login screens a first sign-in does. That is deliberate:
/// the Dio client is built from the active server address, and pointing it at
/// a second brain while the first login's bearer was still being attached
/// would send one brain's credential to another.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  /// The login to go back to if adding another is cancelled or fails.
  /// Kept in `app_settings` too ([AppDatabase.resumeSessionKey]), so a
  /// person who adds a login and has the app killed on the sign-in screen
  /// still has the way back after the restart.
  String? _resumeSessionId;

  @override
  Future<AuthStatus> build() async {
    final sessions = ref.read(sessionRepositoryProvider);
    await sessions.hydrate();
    final activeId = await sessions.activeId();
    await _loadResume(activeId);
    if (activeId != null) {
      // First launch after the update from the single-login build: its push
      // subscription belongs to the login it was signed in as, which the
      // database migration has just made the active session.
      try {
        final keys = await ref.read(pushKeyStoreProvider.future);
        await keys.adoptLegacySubscription(activeId);
      } catch (_) {
        /* no keychain yet, or push never set up */
      }
    }

    // Rebuilds when the server URL changes (e.g. after setup).
    final baseUrl = await ref.watch(serverConfigProvider.future);
    if (baseUrl == null || baseUrl.isEmpty) return AuthStatus.needsServer;

    final token = await ref.read(tokenStoreProvider).read();
    return (token == null || token.isEmpty)
        ? AuthStatus.loggedOut
        : AuthStatus.loggedIn;
  }

  /// True while a login is being added on top of ones already held: the
  /// sign-in screens then offer a way back.
  bool get isAddingLogin => _resumeSessionId != null;

  /// Restore the way back after a restart: only while nobody is active, and
  /// only to a login still held and still signed in.
  Future<void> _loadResume(String? activeId) async {
    final db = ref.read(appDatabaseProvider);
    final stored = await db.getSetting(AppDatabase.resumeSessionKey);
    String? resume;
    if (activeId == null && stored != null && stored.isNotEmpty) {
      final held = await ref.read(sessionRepositoryProvider).byId(stored);
      if (held != null && !held.needsSignIn) resume = held.id;
    }
    _resumeSessionId = resume;
    if (resume == null && stored != null && stored.isNotEmpty) {
      await db.setSetting(AppDatabase.resumeSessionKey, '');
    }
  }

  Future<void> _setResume(String? id) async {
    _resumeSessionId = id;
    await ref
        .read(appDatabaseProvider)
        .setSetting(AppDatabase.resumeSessionKey, id ?? '');
  }

  /// Save the Mantle server URL; `build()` re-runs via its watch and moves us
  /// from `needsServer` to `loggedOut`.
  Future<void> setServer(String url) =>
      ref.read(serverConfigProvider.notifier).setUrl(url);

  /// Logs in and flips to `loggedIn`. Throws [AuthException] on bad credentials.
  ///
  /// The session is made active BEFORE the token is minted, so the token is
  /// written under its id. A login this device already holds (same brain, same
  /// email) reuses its row. If the sign-in fails, a row made for it is removed
  /// and nothing else has changed.
  Future<void> signIn({required String email, required String password}) async {
    final baseUrl = ref.read(serverConfigProvider).value ?? '';
    final sessions = ref.read(sessionRepositoryProvider);
    final begun = await sessions.beginSignIn(baseUrl: baseUrl, email: email);
    final SignInResult result;
    try {
      result = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    } catch (_) {
      await sessions.abandonSignIn(
        sessionId: begun.session.id,
        created: begun.created,
        previousActiveId: null, // nobody was active: adding steps out first
      );
      rethrow;
    }
    await sessions.completeSignIn(begun.session.id, email: email);
    await _rememberRole(begun.session.id, result.role);
    await _signedIn();
  }

  /// Sign in from a scanned [PairingPayload]: the QR names the brain, so the
  /// server is set from it first (replacing whatever was typed, if anything),
  /// then the code is claimed for a bearer. Throws [AuthException] when the
  /// code is refused; the server stays set so the person can still type a
  /// password, and the router lands on login. Flips to `loggedIn` on success.
  ///
  /// A QR only says who it is once claimed, so the session starts without an
  /// email; if it turns out to be a login already held, the older row goes.
  Future<void> signInWithPairing(PairingPayload payload) async {
    final current = ref.read(serverConfigProvider).value;
    if (current != payload.server) {
      await ref.read(serverConfigProvider.notifier).setUrl(payload.server);
    }
    final sessions = ref.read(sessionRepositoryProvider);
    final begun = await sessions.beginSignIn(baseUrl: payload.server);
    final PairingClaim claim;
    try {
      claim = await ref.read(authRepositoryProvider).claimPairing(payload.code);
    } catch (_) {
      await sessions.abandonSignIn(
        sessionId: begun.session.id,
        created: begun.created,
        previousActiveId: null,
      );
      rethrow;
    }
    await sessions.completeSignIn(begun.session.id, email: claim.email);
    await _rememberRole(begun.session.id, claim.role);
    await _signedIn();
  }

  /// What the sign-in said the login is, until whoami says more: a member's
  /// phone must never offer an Admin user's screens, not even for the moment
  /// before whoami answers. A login held before keeps its fuller answer when
  /// the role is unchanged. A sign-in that names no role (a QR claim, an
  /// older brain's mobile-login) leaves nothing cached, so the screens wait
  /// for whoami instead of guessing.
  Future<void> _rememberRole(String sessionId, String? role) async {
    try {
      final db = ref.read(appDatabaseProvider);
      if (role == null) {
        await db.setSetting(loginAccessKey(sessionId), kAccessUnknown);
        return;
      }
      final hint = LoginAccess.fromRole(role);
      final cached = await readCachedAccess(db, sessionId);
      if (cached != null && cached.role == hint.role) return;
      await writeCachedAccess(db, sessionId, hint);
    } catch (_) {
      /* whoami fills it in */
    }
  }

  Future<void> _signedIn() async {
    await _setResume(null);
    _refreshAccountState();
    state = const AsyncData(AuthStatus.loggedIn);
  }

  // ─── Several logins ─────────────────────────────────────────────────────

  /// Step out of the login in use to add another. It stays held and signed
  /// in; [cancelAddLogin] goes back to it. Lands on the login screen for the
  /// same brain (the common case: a second login on it), from which "change
  /// server" leads to setup for a different one.
  Future<void> startAddLogin() async {
    final sessions = ref.read(sessionRepositoryProvider);
    final current = await sessions.activeId();
    if (current == null) return;
    await _setResume(current);
    await ref.read(sessionWipeProvider).stopActiveServices();
    await sessions.stepOut();
    _refreshAccountState();
    state = const AsyncData(AuthStatus.loggedOut);
  }

  /// Back to the login that was in use before [startAddLogin].
  Future<void> cancelAddLogin() async {
    final resume = _resumeSessionId;
    await _setResume(null);
    if (resume != null) await switchTo(resume);
  }

  /// Make a held login the one in use.
  ///
  /// Everything the app has in memory was learned as the login being left,
  /// so it is dropped: the server address (and with it the Dio client and
  /// every provider built on it) and the agent list are invalidated, and the
  /// alarms and background stream of the old login stop. The new login's
  /// start again from its own data.
  ///
  /// False when that login cannot be switched to (its brain signed it out):
  /// it is then the login screen's job, prefilled.
  Future<bool> switchTo(String sessionId) async {
    final sessions = ref.read(sessionRepositoryProvider);
    if (await sessions.activeId() == sessionId) return true;
    await ref.read(sessionWipeProvider).stopActiveServices();
    final ok = await sessions.activate(sessionId);
    if (!ok) {
      await signInAgain(sessionId);
      return false;
    }
    await _setResume(null);
    _refreshAccountState();
    state = const AsyncData(AuthStatus.loggedIn);
    return true;
  }

  /// Go to the login screen for a held login whose brain has signed it out:
  /// its brain becomes the server, and its email is what the screen prefills
  /// ([pendingLoginEmail]).
  Future<void> signInAgain(String sessionId) async {
    final sessions = ref.read(sessionRepositoryProvider);
    final session = await sessions.byId(sessionId);
    if (session == null) return;
    final current = await sessions.activeId();
    if (current != null && current != sessionId) {
      await _setResume(current);
      await ref.read(sessionWipeProvider).stopActiveServices();
      await sessions.stepOut();
    }
    await ref.read(serverConfigProvider.notifier).setUrl(session.baseUrl);
    ref.read(pendingLoginEmailProvider.notifier).set(session.email);
    _refreshAccountState();
    state = const AsyncData(AuthStatus.loggedOut);
  }

  /// Sign out of a held login that is NOT the one in use: revoke its bearer
  /// and push subscription on ITS brain, with ITS bearer, then forget it. The
  /// forgetting happens whatever the network did.
  Future<void> signOutOf(String sessionId) async {
    final sessions = ref.read(sessionRepositoryProvider);
    if (await sessions.activeId() == sessionId) return signOut();
    final session = await sessions.byId(sessionId);
    if (session == null) return;
    // Through the refresh gate: a rotation of this login still running (it
    // was in use a moment ago) is waited out, so the revoke goes with the
    // newest bearer, never the one being replaced.
    final gate = ref.read(tokenRefreshGateProvider);
    final token = await gate.acquire(
      sessionId,
      () => ref.read(tokenStoreProvider).readFor(sessionId),
    );
    if (token != null) {
      // The identity client: ITS brain only, no auth handler (a 401 here
      // must not sign out the login in use), and the build header.
      final dio = ref.read(identityDioFactoryProvider)(session.baseUrl);
      dio.options.headers['Authorization'] = 'Bearer $token';
      try {
        final keys = await ref.read(pushKeyStoreProvider.future);
        final subscription = await keys.subscriptionIdFor(sessionId);
        if (subscription != null && subscription.isNotEmpty) {
          await dio.delete<void>('/api/push/subscriptions/$subscription');
        }
      } catch (_) {
        /* offline, or never connected */
      }
      try {
        await dio.post<void>('/api/auth/mobile-logout');
      } catch (_) {
        /* offline: the bearer expires on its own, or is revoked on the brain */
      } finally {
        gate.release(sessionId);
        dio.close();
      }
    }
    await ref.read(sessionWipeProvider).wipeLocal(sessionId: sessionId);
    await sessions.remove(sessionId);
  }

  /// Leave this server: a full [signOut] (server revoke, local wipe), then
  /// forget the address so `build()` lands on `needsServer` and the router
  /// shows setup. A wipe that cannot clear the token throws before the
  /// address goes, so the user is never stranded half-way.
  ///
  /// With nobody signed in (the login screen's "change server", which is also
  /// how a login on ANOTHER brain is added) there is nothing to sign out of:
  /// only the address goes.
  Future<void> changeServer() async {
    final active = await ref.read(sessionRepositoryProvider).activeId();
    if (active != null) {
      await signOut();
      // signOut may have landed on another held login; leave that one be.
      if (state.value == AuthStatus.loggedIn) return;
    }
    // The brain's theme is the old server's; the next one announces its own.
    await ref.read(settingsRepositoryProvider).setBrainColorTheme(null);
    await ref.read(serverConfigProvider.notifier).setUrl('');
  }

  /// The user signs out of the login in use: unpair push (needs the token),
  /// revoke the token, wipe every local trace of THIS login and forget it.
  /// Then land on the most recently used other login held here, or flip to
  /// `loggedOut`. Throws only when the local token could not be cleared, in
  /// which case the session stays.
  Future<void> signOut() async {
    final sessions = ref.read(sessionRepositoryProvider);
    final leaving = await sessions.activeId();
    final wipe = ref.read(sessionWipeProvider);
    await wipe.unpairPush();
    await ref.read(authRepositoryProvider).logout();
    await wipe.wipeLocal(sessionId: leaving);
    if (leaving != null) await sessions.remove(leaving);
    _refreshAccountState();
    state = const AsyncData(AuthStatus.loggedOut);
    for (final next in await sessions.list()) {
      if (next.needsSignIn) continue;
      if (await switchTo(next.id)) return;
    }
  }

  /// The server says the token is dead (a 401, or a redirect to login). Flip
  /// to `loggedOut` at once so the router bounces, then wipe locally. No
  /// server calls: this runs from inside the failed request. Idempotent —
  /// a burst of failing requests wipes once.
  ///
  /// Only the ACTIVE login is affected. Its row stays, marked as needing a
  /// sign-in, so the login screen can say who to sign back in as; every other
  /// login held here is untouched, and none is switched to behind the
  /// person's back.
  Future<void> sessionInvalidated() async {
    if (state.value != AuthStatus.loggedIn) return;
    state = const AsyncData(AuthStatus.loggedOut);
    try {
      final sessions = ref.read(sessionRepositoryProvider);
      final refused = await sessions.active();
      await ref.read(sessionWipeProvider).wipeLocal(sessionId: refused?.id);
      if (refused != null) {
        await sessions.markNeedsSignIn(refused.id);
        ref.read(pendingLoginEmailProvider.notifier).set(refused.email);
      }
      _refreshAccountState();
    } catch (_) {
      /* the token clear failed; build() will re-read it on next launch */
    }
  }

  /// Everything in memory that is keyed to the login in use, not the device.
  ///
  /// [sessionEpochProvider] is the lever: the Dio client watches it, and every
  /// API provider watches the client, so one bump rebuilds all of them. It has
  /// to be its own signal because two logins on ONE brain share a server
  /// address, and a provider that only watched the address would keep serving
  /// the last login's data. The server address is re-read only when it really
  /// changed: this controller's own `build()` watches it, and re-running that
  /// for no reason would undo the idempotence [sessionInvalidated] relies on.
  void _refreshAccountState() {
    ref.read(sessionEpochProvider.notifier).bump();
    _syncServerConfig();
    ref.invalidate(agentControllerProvider);
    ref.invalidate(accountEmailProvider);
    ref.invalidate(heldSessionsProvider);
  }
  void _syncServerConfig() {
    final shown = ref.read(serverConfigProvider).value ?? '';
    ref
        .read(appDatabaseProvider)
        .getSetting(AppDatabase.legacyServerKey)
        .then((stored) {
      if (ref.mounted && (stored ?? '') != shown) {
        ref.invalidate(serverConfigProvider);
      }
    });
  }
}

/// Bumped whenever the login in use changes (sign-in, sign-out, switch, a
/// refused bearer). Watched by the Dio client, and through it by everything
/// that holds data fetched as a particular login.
@Riverpod(keepAlive: true)
class SessionEpoch extends _$SessionEpoch {
  @override
  int build() => 0;

  void bump() => state++;
}

/// The signed-in email for display, null when signed out. Invalidated by the
/// session controller whenever the account changes.
@Riverpod(keepAlive: true)
Future<String?> accountEmail(Ref ref) =>
    ref.watch(settingsRepositoryProvider).accountEmail();

/// A login the device holds, as the Logins screen and the quick-switch sheet
/// show it.
typedef HeldSession = ({Session session, bool active});

/// Every login held on this device, the one in use first, then most recently
/// used. Invalidated by the session controller on every change.
@Riverpod(keepAlive: true)
Future<List<HeldSession>> heldSessions(Ref ref) async {
  final sessions = ref.watch(sessionRepositoryProvider);
  final activeId = await sessions.activeId();
  final all = await sessions.list();
  return [
    for (final s in all)
      if (s.id == activeId) (session: s, active: true),
    for (final s in all)
      if (s.id != activeId) (session: s, active: false),
  ];
}

/// The email the login screen should start with: set when the person is sent
/// there to sign BACK in to a login the device still lists, read once.
@Riverpod(keepAlive: true)
class PendingLoginEmail extends _$PendingLoginEmail {
  @override
  String? build() => null;

  void set(String? email) =>
      state = (email == null || email.isEmpty) ? null : email;

  /// Read and clear.
  String? take() {
    final value = state;
    state = null;
    return value;
  }
}
