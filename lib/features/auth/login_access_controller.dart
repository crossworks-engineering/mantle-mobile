import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../core/network/dio_provider.dart';
import '../../data/auth/login_access.dart';
import '../../data/auth/session_repository.dart';
import '../../data/auth/whoami_api.dart';
import '../../data/db/app_database.dart';
import '../../data/db/database_provider.dart';
import 'session_controller.dart';

part 'login_access_controller.g.dart';

/// The `app_settings` key a login's last whoami answer is cached under.
String loginAccessKey(String sessionId) => 'login_access.$sessionId';

/// Stored for a login signed in on this build whose sign-in named no role
/// (a QR claim): nothing is known yet, and nothing may be guessed.
const kAccessUnknown = '?';

/// Read one login's cached access, or null.
Future<LoginAccess?> readCachedAccess(AppDatabase db, String sessionId) async {
  final raw = await db.getSetting(loginAccessKey(sessionId));
  if (raw == null || raw.isEmpty || raw == kAccessUnknown) return null;
  try {
    return LoginAccess.fromWhoami(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  } catch (_) {
    return null;
  }
}

/// Cache [access] for [sessionId].
Future<void> writeCachedAccess(
  AppDatabase db,
  String sessionId,
  LoginAccess access,
) =>
    db.setSetting(loginAccessKey(sessionId), jsonEncode(access.toJson()));

/// Who the login in use is, and what the phone offers it ([LoginAccess]).
///
/// Cache first: the answer stored for this login (at sign-in, or the last
/// start) is the state at once, so a member never sees an Admin user's screen
/// while whoami is on its way; whoami then refreshes it. With nothing cached
/// (the first start after the update from a build that served Admin users
/// only) it waits for whoami, and falls back to the Admin user's surface when
/// whoami cannot be reached: every login on such a phone was one.
///
/// Rebuilt whenever the login in use changes. Never fails.
@Riverpod(keepAlive: true)
class LoginAccessController extends _$LoginAccessController {
  @override
  Future<LoginAccess> build() async {
    ref.watch(sessionEpochProvider);
    // Wait for the session to settle: an answer given before it would be a
    // guess, and a guess must never be an Admin user's surface.
    final status = await ref.watch(sessionControllerProvider.future);
    if (status != AuthStatus.loggedIn) return const LoginAccess.signedOut();
    final sessionId =
        await ref.read(sessionRepositoryProvider).activeId() ?? '';
    if (sessionId.isEmpty) return const LoginAccess.signedOut();
    // whoami again when the app comes back: a workspace joined on the web,
    // or an answer that could not be had before.
    ref.listen(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleState.resumed &&
          prev != AppLifecycleState.resumed) {
        unawaited(_refresh(sessionId));
      }
    });
    final db = ref.read(appDatabaseProvider);
    final cached = await readCachedAccess(db, sessionId);
    if (cached != null) {
      unawaited(_refresh(sessionId));
      return cached;
    }
    final fetched = await _fetch(sessionId);
    if (fetched != null) return fetched;
    // whoami could not be reached. A login signed in on this build without
    // a role gets only what every login has until it answers; a login from
    // the build that served Admin users only keeps that surface.
    final marker = await db.getSetting(loginAccessKey(sessionId));
    return marker == kAccessUnknown
        ? const LoginAccess(role: LoginRole.member)
        : const LoginAccess.legacyAdmin();
  }

  /// Ask whoami again (on demand: a pull to refresh, a workspace change on
  /// the web).
  Future<void> refresh() async {
    final sessionId = await ref.read(sessionRepositoryProvider).activeId();
    if (sessionId == null || sessionId.isEmpty) return;
    await _refresh(sessionId);
  }

  Future<void> _refresh(String sessionId) async {
    final fresh = await _fetch(sessionId);
    if (fresh == null || !ref.mounted) return;
    // A switch meanwhile: the answer is that login's, not the one in use.
    if (await ref.read(sessionRepositoryProvider).activeId() != sessionId) {
      return;
    }
    if (ref.mounted) state = AsyncData(fresh);
  }

  /// whoami for [sessionId], cached on success. Null when it could not be
  /// learned (offline, refused). A brain without whoami answers the legacy
  /// Admin user.
  Future<LoginAccess?> _fetch(String sessionId) async {
    try {
      final dio = ref.read(dioProvider);
      final access =
          await fetchWhoami(dio) ?? const LoginAccess.legacyAdmin();
      await writeCachedAccess(
        ref.read(appDatabaseProvider),
        sessionId,
        access,
      );
      return access;
    } catch (_) {
      return null;
    }
  }
}

/// The login in use's access as it stands: null while it is being worked
/// out (at start, and for the moment after a sign-in or a switch, when the
/// last answer is another login's). A screen then offers only what every
/// login has.
@Riverpod(keepAlive: true)
LoginAccess? currentAccess(Ref ref) {
  final async = ref.watch(loginAccessControllerProvider);
  return async.isLoading ? null : async.value;
}
