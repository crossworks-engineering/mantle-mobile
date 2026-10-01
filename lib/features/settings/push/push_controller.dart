import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/push/push_api.dart';
import '../../../data/push/push_keys.dart';
import '../../../data/push/push_token_service.dart';

part 'push_controller.g.dart';

enum PushConnectionStatus { disconnected, connected }

/// A user-facing failure in the Connect flow (permission declined, relay
/// unreachable, …). The message is shown inline under the button.
class PushException implements Exception {
  const PushException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PushState {
  const PushState({required this.status, this.devices = const []});
  final PushConnectionStatus status;
  final List<PushDevice> devices;

  bool get isConnected => status == PushConnectionStatus.connected;
}

/// Drives push notifications setup. `build()` reflects current state (is THIS
/// device connected + the owner's device list); [connect]/[disconnect] run the
/// one-tap flow against Mantle + the relay (push-notifications.md §5.1).
@riverpod
class PushController extends _$PushController {
  @override
  Future<PushState> build() {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(pushApiProvider);
    return _load();
  }

  Future<PushState> _load() async {
    final keyStore = await ref.read(pushKeyStoreProvider.future);
    final subId = await keyStore.subscriptionId();
    var devices = const <PushDevice>[];
    try {
      devices = await ref.read(pushApiProvider).list();
    } catch (_) {
      /* server unreachable — show no devices rather than fail the screen */
    }
    return PushState(
      status: (subId != null && subId.isNotEmpty)
          ? PushConnectionStatus.connected
          : PushConnectionStatus.disconnected,
      devices: devices,
    );
  }

  /// One-tap Connect: permission → APNs token → device keypair → Mantle
  /// `/connect` (ticket) → relay `/enroll` (routing token) → Mantle `/subscribe`.
  Future<void> connect() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final api = ref.read(pushApiProvider);
      // Each step has a timeout so a silent native stall surfaces as a labelled
      // error instead of an endless "Connecting…" spinner (which steps blocks).
      final keyStore = await ref.read(pushKeyStoreProvider.future).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw const PushException('Timed out initialising libsodium.'),
          );

      final pushToken = await ref.read(pushTokenServiceProvider).requestToken().timeout(
            const Duration(seconds: 20),
            onTimeout: () =>
                throw const PushException('Timed out requesting notification permission / APNs token.'),
          );
      if (pushToken == null || pushToken.token.isEmpty) {
        throw const PushException('Notification permission was declined.');
      }
      final platform = pushToken.platform;
      final token = pushToken.token;

      final publicKey = await keyStore.ensureDeviceKeyPair().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw const PushException('Timed out generating/saving the device key.'),
          );

      final conn = await api.connect(platform: platform, osPushToken: token, publicKey: publicKey);
      final enrolled = await api.enroll(
        relayUrl: conn.relayUrl,
        ticket: conn.ticket,
        platform: platform,
        osPushToken: token,
      );
      final id = await api.subscribe(
        routingToken: enrolled.routingToken,
        publicKey: publicKey,
        platform: platform,
        label: platform == 'android' ? 'Android device' : 'iPhone',
        deviceId: enrolled.deviceId,
      );
      await keyStore.setSubscriptionId(id);
      return _load();
    });
    if (ref.mounted) state = next;
  }

  /// Unpair this device: drop the Mantle subscription (which also tells the
  /// relay), then clear the local keypair so the NSE can no longer decrypt.
  Future<void> disconnect() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final api = ref.read(pushApiProvider);
      final keyStore = await ref.read(pushKeyStoreProvider.future);
      final id = await keyStore.subscriptionId();
      if (id != null && id.isNotEmpty) {
        try {
          await api.unsubscribe(id);
        } catch (_) {
          /* best-effort — clear locally regardless */
        }
      }
      await keyStore.clear();
      return _load();
    });
    if (ref.mounted) state = next;
  }

  /// Reset push for this whole install: roll Mantle's instance token (which
  /// invalidates every enrolled device) and clear this device's local keys.
  /// Everyone must re-Connect afterwards.
  Future<void> reset() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final api = ref.read(pushApiProvider);
      final keyStore = await ref.read(pushKeyStoreProvider.future);
      try {
        await api.resetInstance();
      } catch (_) {
        /* best-effort — still clear locally */
      }
      await keyStore.clear();
      return _load();
    });
    if (ref.mounted) state = next;
  }
}
