import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    state = await AsyncValue.guard(() async {
      final direct = const DirectPush();
      await direct.requestPermissions();
      final baseUrl = ref.read(serverConfigProvider).value ?? '';
      final token = await ref.read(tokenStoreProvider).read();
      if (baseUrl.isEmpty || token == null || token.isEmpty) {
        throw const PushException('You need to be signed in to a server first.');
      }
      await direct.start(baseUrl: baseUrl, token: token);
      return true;
    });
  }

  Future<void> disable() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await const DirectPush().stop();
      return false;
    });
  }
}
