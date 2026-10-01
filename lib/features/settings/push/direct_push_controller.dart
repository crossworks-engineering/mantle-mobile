import 'dart:async' show unawaited;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_provider.dart';
import '../../../data/auth/session_repository.dart';
import '../../../data/auth/token_store.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/database_provider.dart';
import '../../../data/push/direct_push_service.dart';
import '../../../data/server/server_config.dart';
import '../../auth/session_controller.dart';
import 'push_controller.dart';

part 'direct_push_controller.g.dart';

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it and
/// record the choice ([AppDatabase.directPushWantedKey]), which
/// [DirectPushFollow] keeps true across switches and restarts. Android only:
/// the UI hides it elsewhere.
@riverpod
class DirectPushController extends _$DirectPushController {
  @override
  Future<bool> build() => ref.read(directPushProvider).isRunning();

  Future<void> enable() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final direct = ref.read(directPushProvider);
      await direct.requestPermissions();
      final baseUrl = ref.read(serverConfigProvider).value ?? '';
      final token = await ref.read(tokenStoreProvider).read();
      final sessionId = await ref.read(sessionRepositoryProvider).activeId();
      if (baseUrl.isEmpty ||
          token == null ||
          token.isEmpty ||
          sessionId == null) {
        throw const PushException('You need to be signed in to a server first.');
      }
      await ref
          .read(appDatabaseProvider)
          .setSetting(AppDatabase.directPushWantedKey, '1');
      // The token stays in secure storage; the service reads it there, by the
      // id of the login whose stream this is. One stream: the ACTIVE login's.
      await direct.start(baseUrl: baseUrl, sessionId: sessionId);
      return true;
    });
    // This is an auto-dispose provider; if it was disposed during the await
    // (e.g. the caller isn't watching it), writing state would throw.
    if (ref.mounted) state = next;
  }

  Future<void> disable() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      await ref
          .read(appDatabaseProvider)
          .setSetting(AppDatabase.directPushWantedKey, '');
      await ref.read(directPushProvider).stop();
      return false;
    });
    if (ref.mounted) state = next;
  }
}

/// Keeps the direct connection on the login in use while the person wants
/// it on. A switch or a sign-out stops the service (the session wipe); this
/// starts it again for whoever is active next, at launch and whenever the
/// client changes (another login, or another brain).
///
/// It also carries the choice over from a build before several logins: that
/// build started the service without a login id, so the service stops itself
/// at its next start. Its leftover address means the person had it on.
///
/// keepAlive + watched once from the app root, like the alarm sync. Nothing
/// reads its (void) value.
@Riverpod(keepAlive: true)
class DirectPushFollow extends _$DirectPushFollow {
  @override
  void build() {
    final session = ref.watch(sessionControllerProvider).value;
    ref.watch(dioProvider);
    if (session != AuthStatus.loggedIn) return;
    unawaited(follow());
  }

  /// One check-and-start. Public so a test can await it.
  Future<void> follow() async {
    try {
      final direct = ref.read(directPushProvider);
      if (!direct.supported) return;
      final db = ref.read(appDatabaseProvider);
      var wanted = await db.getSetting(AppDatabase.directPushWantedKey) == '1';
      if (!wanted && await direct.startedByOlderBuild()) {
        wanted = true;
        await db.setSetting(AppDatabase.directPushWantedKey, '1');
      }
      if (!wanted) return;
      final active = await ref.read(sessionRepositoryProvider).active();
      final baseUrl = ref.read(serverConfigProvider).value ?? '';
      // Mid-switch to another brain the address catches up a moment later;
      // that rebuild starts it.
      if (active == null || active.baseUrl != baseUrl) return;
      final token = await ref.read(tokenStoreProvider).readFor(active.id);
      if (token == null || token.isEmpty) return;
      if (await direct.isRunningFor(baseUrl: baseUrl, sessionId: active.id)) {
        return;
      }
      await direct.start(baseUrl: baseUrl, sessionId: active.id);
    } catch (_) {
      /* the plugin refused; the Settings toggle shows it is off */
    }
  }
}
