import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/auth/session_repository.dart';
import '../../../data/auth/token_store.dart';
import '../../../data/push/direct_push_service.dart';
import '../../../data/server/server_config.dart';
import 'push_controller.dart';

part 'direct_push_controller.g.dart';

/// The direct-connection push transport (no-Google Android). State is whether
/// the foreground service is running; [enable]/[disable] start/stop it. Android
/// only — the UI hides it elsewhere.
@riverpod
class DirectPushController extends _$DirectPushController {
  @override
  Future<bool> build() => const DirectPush().isRunning();

  Future<void> enable() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final direct = const DirectPush();
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
      await const DirectPush().stop();
      return false;
    });
    if (ref.mounted) state = next;
  }
}
