import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/conversation_stream.dart';
import '../../data/pending/pending_api.dart';
import '../../data/pending/pending_models.dart';

part 'pending_controller.g.dart';

/// Owns the agent-approval queue. Loads the pending list on build; [approve] /
/// [reject] optimistically drop the row then persist via PATCH, reconciling on
/// failure. While mounted it listens to the live [conversationEventsProvider]
/// SSE and silently refetches — a tool call queued mid-turn coincides with a
/// conversation event, so the queue stays current without a pull.
@riverpod
class PendingController extends _$PendingController {
  @override
  Future<List<PendingCall>> build() {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(pendingApiProvider);
    ref.listen(conversationEventsProvider, (_, next) {
      if (next is AsyncData<ConversationEvent>) _reloadSilently();
    });
    return ref.read(pendingApiProvider).list();
  }

  /// Refetch without flipping to a loading state — for live updates that
  /// shouldn't blank the list. Keeps the current list on error.
  Future<void> _reloadSilently() async {
    try {
      final rows = await ref.read(pendingApiProvider).list();
      if (ref.mounted) state = AsyncData(rows);
    } catch (_) {
      /* keep current; the next event or pull-to-refresh reconciles */
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => ref.read(pendingApiProvider).list());
    if (ref.mounted) state = next;
  }

  Future<void> approve(String id) => _decide(id, approve: true);

  Future<void> reject(String id) => _decide(id, approve: false);

  /// Optimistically remove the row, then PATCH. On failure, refetch so the row
  /// reappears if it's actually still pending.
  Future<void> _decide(String id, {required bool approve}) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final c in current)
          if (c.id != id) c,
      ]);
    }
    try {
      await ref.read(pendingApiProvider).decide(id, approve: approve);
    } catch (_) {
      await _reloadSilently();
    }
  }
}
