import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/conversations/conversation_models.dart';
import '../../data/conversations/conversations_api.dart';

part 'conversations_controller.g.dart';

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh.
@riverpod
class ConversationsController extends _$ConversationsController {
  @override
  Future<List<AgentConversation>> build() =>
      ref.read(conversationsApiProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(conversationsApiProvider).list(),
    );
  }

  Future<void> markRead(String slug) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final c in current)
          if (c.agent.slug == slug) c.copyWith(unreadCount: 0) else c,
      ]);
    }
    try {
      await ref.read(conversationsApiProvider).markRead(slug);
    } catch (_) {
      // Best-effort; the next refresh will reconcile.
    }
  }
}
