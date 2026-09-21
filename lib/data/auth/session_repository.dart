import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'token_store.dart';

part 'session_repository.g.dart';

/// The logins this device holds, and which one is in use.
///
/// Storage only: rows in [Sessions], the active id in `app_settings`, bearers
/// in [TokenStore]. No network, no navigation. What a switch has to tear down
/// and rebuild around this (push, alarms, provider state) belongs to the
/// session controller.
///
/// Two settings are kept as MIRRORS of the active session, because the rest of
/// the app already reads them and has no reason to learn about sessions: the
/// server address (`server_base_url`, what the Dio client is built from) and
/// the account email (what Settings shows).
class SessionRepository {
  SessionRepository(this._db, this._tokens);

  final AppDatabase _db;
  final TokenStore _tokens;

  static const _emailMirrorKey = AppDatabase.legacyEmailKey;
  static const _serverMirrorKey = AppDatabase.legacyServerKey;

  /// Most recently used first.
  Future<List<Session>> list() {
    return (_db.select(_db.sessions)
          ..orderBy([(s) => OrderingTerm.desc(s.lastUsedAt)]))
        .get();
  }

  Future<Session?> byId(String id) {
    return (_db.select(_db.sessions)..where((s) => s.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String?> activeId() async {
    final id = await _db.getSetting(AppDatabase.activeSessionKey);
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<Session?> active() async {
    final id = await activeId();
    return id == null ? null : byId(id);
  }

  /// Point the database's cache scope at the active session. Called once at
  /// start-up, before anything reads the chat cache.
  Future<void> hydrate() async {
    _db.currentSessionId = await activeId() ?? '';
  }

  /// A sign-in is about to be attempted: make sure there is a session for it
  /// and make it active, so the token it mints is written under the right id.
  ///
  /// Signing in again as a login this device already holds reuses its row.
  /// With no [email] yet (a QR sign-in learns it from the claim) the row is
  /// always new; [completeSignIn] folds it into an existing one afterwards.
  ///
  /// Returns what [abandonSignIn] needs to put things back if it fails.
  Future<({Session session, bool created, String? previousActiveId})>
      beginSignIn({required String baseUrl, String email = ''}) async {
    final previous = await activeId();
    final wanted = email.trim().toLowerCase();
    Session? existing;
    if (wanted.isNotEmpty) {
      existing = await (_db.select(_db.sessions)
            ..where((s) => s.baseUrl.equals(baseUrl) & s.email.equals(wanted)))
          .getSingleOrNull();
    }
    final now = DateTime.now();
    final id = existing?.id ?? AppDatabase.newSessionId();
    if (existing == null) {
      await _db.into(_db.sessions).insert(
            SessionsCompanion.insert(
              id: id,
              baseUrl: baseUrl,
              email: Value(wanted),
              addedAt: now,
              lastUsedAt: now,
            ),
          );
    }
    await _setActive(id, baseUrl: baseUrl, email: wanted);
    return (
      session: (await byId(id))!,
      created: existing == null,
      previousActiveId: previous,
    );
  }

  /// The sign-in failed. A row made for it goes; a row that already existed
  /// stays exactly as it was. Whoever was active before is active again.
  Future<void> abandonSignIn({
    required String sessionId,
    required bool created,
    required String? previousActiveId,
  }) async {
    if (created) {
      await _tokens.clearFor(sessionId);
      await (_db.delete(_db.sessions)..where((s) => s.id.equals(sessionId)))
          .go();
    }
    final previous =
        previousActiveId == null ? null : await byId(previousActiveId);
    if (previous != null) {
      await _setActive(previous.id,
          baseUrl: previous.baseUrl, email: previous.email);
    } else {
      await _clearActive();
    }
  }

  /// The sign-in worked. Records who it turned out to be, and if that is a
  /// login the device ALREADY listed (a QR sign-in could not know beforehand)
  /// the older row and its bearer go, so a login is never listed twice.
  Future<void> completeSignIn(String sessionId, {String? email}) async {
    final session = await byId(sessionId);
    if (session == null) return;
    final known = (email ?? session.email).trim().toLowerCase();
    if (known.isNotEmpty) {
      final twins = await (_db.select(_db.sessions)
            ..where((s) =>
                s.id.isNotValue(sessionId) &
                s.baseUrl.equals(session.baseUrl) &
                s.email.equals(known)))
          .get();
      for (final twin in twins) {
        await remove(twin.id);
      }
    }
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(
      SessionsCompanion(
        email: Value(known),
        needsSignIn: const Value(false),
        lastUsedAt: Value(DateTime.now()),
      ),
    );
    await _db.setSetting(_emailMirrorKey, known);
  }

  /// Make a held login the active one. Storage only; see the class comment.
  /// False for an unknown id or a session whose brain has signed it out.
  Future<bool> activate(String sessionId) async {
    final session = await byId(sessionId);
    if (session == null || session.needsSignIn) return false;
    final token = await _tokens.readFor(sessionId);
    if (token == null || token.isEmpty) return false;
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(SessionsCompanion(lastUsedAt: Value(DateTime.now())));
    await _setActive(sessionId, baseUrl: session.baseUrl, email: session.email);
    return true;
  }

  /// What `/api/shell`-style identity the app has learned about the active
  /// login, for the list to show.
  Future<void> recordIdentity(
    String sessionId, {
    String? displayName,
    String? siteName,
  }) {
    return (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(
      SessionsCompanion(
        displayName: Value(displayName),
        siteName: Value(siteName),
      ),
    );
  }

  /// The brain refused this session's bearer. Its row stays, to sign back in
  /// to; its bearer and its cached rows go. No other session is touched, and
  /// none is made active: that is the controller's decision.
  Future<void> markNeedsSignIn(String sessionId) async {
    await _tokens.clearFor(sessionId);
    await _db.clearUserData(sessionId: sessionId);
    await (_db.update(_db.sessions)..where((s) => s.id.equals(sessionId)))
        .write(const SessionsCompanion(needsSignIn: Value(true)));
    if (await activeId() == sessionId) await _clearActive(keepServer: true);
  }

  /// Forget a login entirely: row, bearer, cache, unsent messages.
  Future<void> remove(String sessionId) async {
    await _tokens.clearFor(sessionId);
    await _db.clearUserData(sessionId: sessionId);
    await (_db.delete(_db.sessions)..where((s) => s.id.equals(sessionId))).go();
    if (await activeId() == sessionId) await _clearActive(keepServer: true);
  }

  /// Nobody is active, but every login stays held and signed in. What adding
  /// a login does first: with no active session no bearer is attached to
  /// anything, so the sign-in screens can point the app at another brain
  /// without one brain's credential being sent to another.
  Future<void> stepOut() => _clearActive();

  Future<void> _setActive(
    String id, {
    required String baseUrl,
    required String email,
  }) async {
    await _db.setSetting(AppDatabase.activeSessionKey, id);
    await _db.setSetting(_serverMirrorKey, baseUrl);
    await _db.setSetting(_emailMirrorKey, email);
    _db.currentSessionId = id;
  }

  /// Nobody is active. The server address stays by default: a person who was
  /// just signed out of a brain is about to sign back in to that brain, and
  /// should land on its login screen, not on server setup.
  Future<void> _clearActive({bool keepServer = true}) async {
    await _db.setSetting(AppDatabase.activeSessionKey, '');
    await _db.setSetting(_emailMirrorKey, '');
    if (!keepServer) await _db.setSetting(_serverMirrorKey, '');
    _db.currentSessionId = '';
  }
}

@Riverpod(keepAlive: true)
SessionRepository sessionRepository(Ref ref) {
  return SessionRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(tokenStoreProvider),
  );
}
