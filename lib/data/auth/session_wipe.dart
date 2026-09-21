import 'dart:io' show Platform;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/database_provider.dart';
import '../events/event_alarms.dart';
import '../push/direct_push_service.dart';
import '../push/push_api.dart';
import '../push/push_keys.dart';
import 'session_repository.dart';
import 'token_store.dart';

part 'session_wipe.g.dart';

/// Everything that has to leave the device when a session ends.
///
/// A session ends two ways — the user signs out, or the server says the token
/// is dead (401 / redirect to login) — and both must leave the device clean:
/// no cached messages, no queued turns that would flush under the next login,
/// no push keypair that keeps decrypting the old account's notifications, no
/// alarms for its events, no background service holding its stream open.
///
/// With several logins on the device, "the session" is ONE of them. Its bearer,
/// its cached rows, its unsent messages and its push subscription go. The
/// other logins keep theirs. The things there is only one of (the event
/// alarms, the background stream) belong to whichever login is ACTIVE, so
/// they stop only when that is the one leaving.
///
/// Split in two because the 401 path runs INSIDE a failed request: it may make
/// no network calls of its own (a wipe that unsubscribes push would 401 again
/// and recurse), so [wipeLocal] is local-only and [unpairPush] is the one
/// server call, made by sign-out while the token is still valid.
class SessionWipe {
  SessionWipe(this._ref);

  final Ref _ref;

  /// Tell Mantle to drop this device's push subscription. Best-effort and
  /// needs the bearer, so call it BEFORE the token is cleared.
  Future<void> unpairPush() async {
    try {
      final keys = await _ref.read(pushKeyStoreProvider.future);
      final id = await keys.subscriptionId();
      if (id != null && id.isNotEmpty) {
        await _ref.read(pushApiProvider).unsubscribe(id);
      }
    } catch (_) {
      /* offline, or never paired — the local keys go regardless */
    }
  }

  /// Remove every local trace of the session. No network. Every step runs
  /// even when an earlier one fails; only a failure to clear the TOKEN is
  /// rethrown at the end, because that is the one that would leave the user
  /// signed in on the next launch.
  ///
  /// [sessionId] defaults to the active login. The session's ROW is not this
  /// class's business: a refused bearer keeps it (to sign back in to), a
  /// sign-out removes it, and the session controller decides which.
  Future<void> wipeLocal({String? sessionId}) async {
    final activeId = await _ref.read(sessionRepositoryProvider).activeId();
    final id = sessionId ?? activeId;
    if (id == null) return;
    Object? tokenError;
    try {
      await _ref.read(tokenStoreProvider).clearFor(id);
    } catch (e) {
      tokenError = e;
    }
    await _best(
      () => _ref.read(appDatabaseProvider).clearUserData(sessionId: id),
    );
    await _best(() async {
      final keys = await _ref.read(pushKeyStoreProvider.future);
      await keys.clearFor(id);
    });
    if (id == activeId) await stopActiveServices();
    if (tokenError != null) {
      // ignore: only_throw_errors
      throw tokenError;
    }
  }

  /// The device-wide things that follow the ACTIVE login: alarms for its
  /// events, the background stream to its brain. Stopped when it leaves and
  /// when another login takes its place; the new one starts its own.
  Future<void> stopActiveServices() async {
    await _best(EventAlarms.cancelAll);
    if (Platform.isAndroid) {
      await _best(const DirectPush().stop);
    }
  }

  Future<void> _best(Future<void> Function() step) async {
    try {
      await step();
    } catch (_) {
      /* keep going — the rest of the wipe is still worth doing */
    }
  }
}

@Riverpod(keepAlive: true)
SessionWipe sessionWipe(Ref ref) => SessionWipe(ref);
