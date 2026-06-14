import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/push/push_api.dart';

part 'push_prefs_controller.g.dart';

/// Loads + updates push preferences (per-trigger toggles + quiet hours). On
/// first load it adopts the device's IANA timezone so quiet hours are in local
/// time. Updates are optimistic (state reflects the change immediately, then
/// reconciles with the server's response).
@riverpod
class PushPrefsController extends _$PushPrefsController {
  @override
  Future<PushPreferences> build() async {
    final api = ref.read(pushApiProvider);
    final prefs = await api.getPreferences();
    if (prefs.timezone == 'UTC') {
      try {
        final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
        if (tz.isNotEmpty && tz != 'UTC') {
          return api.updatePreferences({'timezone': tz});
        }
      } catch (_) {
        /* keep UTC if detection fails */
      }
    }
    return prefs;
  }

  /// Apply a partial preference patch (optimistic, then reconcile).
  Future<void> save(Map<String, dynamic> patch) async {
    final current = state.value;
    if (current != null) state = AsyncData(current.merge(patch)); // optimistic
    try {
      state = AsyncData(await ref.read(pushApiProvider).updatePreferences(patch));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
