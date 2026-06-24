import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/chat/conversation_stream.dart';
import '../../data/conversations/conversation_models.dart';
import '../../data/conversations/conversations_api.dart';

part 'conversations_controller.g.dart';

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh. While mounted it also listens to the live
/// [conversationEventsProvider] SSE and silently refetches when any thread gets
/// a turn (from any channel), so previews + unread stay current with no pull.
@riverpod
class ConversationsController extends _$ConversationsController {
  @override
  Future<List<AgentConversation>> build() {
    ref.listen(conversationEventsProvider, (_, next) {
      if (next is AsyncData<ConversationEvent>) _reloadSilently();
    });
    // The SSE pauses while backgrounded, so anything that arrived meanwhile was
    // missed. Refetch on return to the foreground so previews + unread catch up.
    ref.listen(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleState.resumed &&
          prev != AppLifecycleState.resumed) {
        _reloadSilently();
      }
    });
    return ref.read(conversationsApiProvider).list();
  }

  /// Refetch without flipping to a loading state — for live updates that
  /// shouldn't blank the inbox. Keeps the current list on error.
  Future<void> _reloadSilently() async {
    try {
      state = AsyncData(await ref.read(conversationsApiProvider).list());
    } catch (_) {
      /* keep current; the next event or pull-to-refresh reconciles */
    }
  }

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
