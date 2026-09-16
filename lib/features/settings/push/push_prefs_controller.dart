import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/push/push_api.dart';

part 'push_prefs_controller.g.dart';

/// Loads + updates push preferences (per-trigger toggles). Updates are optimistic
/// (state reflects the change immediately, then reconciles with the server's
/// response).
@riverpod
class PushPrefsController extends _$PushPrefsController {
  @override
  Future<PushPreferences> build() async {
    return ref.read(pushApiProvider).getPreferences();
  }

  /// Apply a partial preference patch (optimistic, then reconcile).
  Future<void> save(Map<String, dynamic> patch) async {
    final current = state.value;
    if (current != null) state = AsyncData(current.merge(patch)); // optimistic
    try {
      final saved = await ref.read(pushApiProvider).updatePreferences(patch);
      if (ref.mounted) state = AsyncData(saved);
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(e, st);
    }
  }
}
