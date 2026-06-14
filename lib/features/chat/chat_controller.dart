import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_message.dart';
import '../../data/chat/chat_repository.dart';
import '../conversations/conversations_controller.dart';

part 'chat_controller.g.dart';

/// The chat thread plus its paging state. [messages] is oldest-first (the screen
/// reverses it for display). [hasMore] is true while older pages may still
/// exist; [loadingMore] is true while a scroll-up fetch is in flight.
class ChatState {
  const ChatState({
    required this.messages,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingMore;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
@riverpod
class ChatController extends _$ChatController {
  @override
  Future<ChatState> build(String agentSlug) async {
    final page = await ref
        .read(chatRepositoryProvider)
        .history(limit: chatPageSize, agentSlug: agentSlug);
    return ChatState(messages: page, hasMore: page.length >= chatPageSize);
  }

  /// Fetch the next older page and prepend it. No-op while one is in flight,
  /// when there's nothing older, or before the first page has loaded.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        !current.hasMore ||
        current.messages.isEmpty) {
      return;
    }

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final oldest = current.messages.first.createdAt;
      final older = await ref
          .read(chatRepositoryProvider)
          .history(before: oldest, limit: chatPageSize, agentSlug: agentSlug);

      final knownIds = current.messages.map((m) => m.id).toSet();
      final merged = [
        ...older.where((m) => !knownIds.contains(m.id)),
        ...current.messages,
      ];
      state = AsyncData(
        ChatState(messages: merged, hasMore: older.length >= chatPageSize),
      );
    } catch (_) {
      // Keep what we have and let the user try again.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final base =
        state.value ?? const ChatState(messages: [], hasMore: false);
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: tempId,
      direction: MessageDirection.inbound,
      text: trimmed,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    state = AsyncData(base.copyWith(messages: [...base.messages, pending]));

    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .send(trimmed, agentSlug: agentSlug);
      final current = state.value ?? base;
      final replaced = [
        for (final m in current.messages)
          if (m.id == tempId) result.inbound else m,
        result.outbound,
      ];
      state = AsyncData(current.copyWith(messages: replaced));
      // Refresh the inbox so this thread's preview + unread reflect the turn.
      ref.invalidate(conversationsControllerProvider);
    } catch (_) {
      final current = state.value ?? base;
      state = AsyncData(
        current.copyWith(
          messages: [
            for (final m in current.messages)
              if (m.id == tempId)
                m.copyWith(status: MessageStatus.failed)
              else
                m,
          ],
        ),
      );
    }
  }

  /// Re-fetch the thread from the latest page.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(chatRepositoryProvider)
          .history(limit: chatPageSize, agentSlug: agentSlug);
      return ChatState(messages: page, hasMore: page.length >= chatPageSize);
    });
  }
}
