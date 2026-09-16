import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/location/location_service.dart';
import 'settings_repository.dart';

part 'location_controller.g.dart';

/// Thrown when enabling location sharing but the OS permission was refused.
class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Owns the "share location with messages" opt-in. Enabling it first requests
/// the OS *when-in-use* permission and only persists `true` if granted; on
/// refusal the state surfaces a [LocationException] and stays off. Disabling
/// just clears the flag. Mirrors the other settings controllers.
@riverpod
class LocationController extends _$LocationController {
  @override
  Future<bool> build() => ref.watch(settingsRepositoryProvider).locationSharing();

  Future<void> setEnabled(bool enabled) async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() async {
      final repo = ref.read(settingsRepositoryProvider);
      if (!enabled) {
        await repo.setLocationSharing(false);
        return false;
      }
      final granted = await ref.read(locationServiceProvider).requestPermission();
      if (!granted) {
        throw const LocationException(
          'Location permission is off. Enable it for Jackdaw in your device '
          'settings to share location with messages.',
        );
      }
      await repo.setLocationSharing(true);
      return true;
    });
    // The permission dialog can outlive the settings screen.
    if (ref.mounted) state = next;
  }
}
