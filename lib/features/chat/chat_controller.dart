import 'dart:math';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/chat/chat_attachment.dart';
import '../../data/chat/chat_message.dart';
import '../../data/chat/chat_repository.dart';
import '../../data/chat/conversation_stream.dart';
import '../../data/location/location_service.dart';
import '../conversations/conversations_controller.dart';
import '../settings/settings_repository.dart';

part 'chat_controller.g.dart';

/// The result of [ChatController.send] — lets the composer react: clear on
/// [sent], leave the failed bubble on [failed], or restore the text for editing
/// on [cancelled] (the user hit stop).
enum SendOutcome { sent, failed, cancelled }

/// A fresh 128-bit hex `idempotency-key` for one send. The server replays a
/// cached result for a repeated key, so a retried/replayed POST that already
/// completed server-side won't create a duplicate turn.
String _newIdempotencyKey() {
  final rand = Random.secure();
  return List<int>.generate(16, (_) => rand.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

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
    // Live updates: when a turn lands on THIS agent's thread (any channel — a
    // proactive heartbeat, or a message you sent from web/Telegram), merge the
    // new messages in without disturbing scroll or paging.
    ref.listen(conversationEventsProvider, (_, next) {
      if (next is AsyncData<ConversationEvent> &&
          next.value.agentSlug == agentSlug) {
        _onRemoteTurn();
      }
    });

    final page = await ref
        .read(chatRepositoryProvider)
        .history(limit: chatPageSize, agentSlug: agentSlug);
    return ChatState(messages: page, hasMore: page.length >= chatPageSize);
  }

  /// A turn landed on this thread elsewhere — pull the latest page and append
  /// any messages we don't already have. Skipped while an optimistic send is in
  /// flight (that path reconciles itself, and refetching mid-send could briefly
  /// double the user's bubble).
  Future<void> _onRemoteTurn() async {
    final current = state.value;
    if (current == null) return;
    if (current.messages.any((m) => m.status == MessageStatus.sending)) return;
    try {
      final latest = await ref
          .read(chatRepositoryProvider)
          .history(limit: chatPageSize, agentSlug: agentSlug);
      final known = current.messages.map((m) => m.id).toSet();
      final fresh = latest.where((m) => !known.contains(m.id)).toList();
      if (fresh.isEmpty) return;
      final merged = [...current.messages, ...fresh]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = AsyncData(current.copyWith(messages: merged));
    } catch (_) {
      /* keep what we have; the next event or refresh reconciles */
    }
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

  /// Transcribe a recorded voice note to text (the composer then sends it as a
  /// normal turn). Throws on failure so the composer can surface the server's
  /// message (e.g. "no STT worker configured").
  Future<String> transcribe(String audioPath) =>
      ref.read(chatRepositoryProvider).transcribe(audioPath);

  /// Send a turn. [attachment] (optional) is an image or document picked
  /// locally; the user's bubble shows it immediately (from disk) and the turn
  /// posts it as multipart. Either [text] or [attachment] must be non-empty.
  ///
  /// Pass a [cancelToken] to allow the composer's stop button to abort the
  /// in-flight request: on cancel the optimistic bubble is removed (not marked
  /// failed) and [SendOutcome.cancelled] is returned so the composer can restore
  /// the text for editing. Note this only aborts the client request — the server
  /// may already have processed the turn (no server cancel endpoint yet), in
  /// which case it resurfaces on the next refresh/live event.
  Future<SendOutcome> send(
    String text, {
    OutgoingAttachment? attachment,
    CancelToken? cancelToken,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachment == null) return SendOutcome.sent;

    final base =
        state.value ?? const ChatState(messages: [], hasMore: false);
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    // The local preview rides on the optimistic bubble and is kept after the
    // turn lands (the server strips image bytes from the reply).
    final localAttachments = attachment != null
        ? [attachment.toChatAttachment()]
        : const <ChatAttachment>[];
    final pending = ChatMessage(
      id: tempId,
      direction: MessageDirection.inbound,
      text: trimmed,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
      attachments: localAttachments,
    );
    state = AsyncData(base.copyWith(messages: [...base.messages, pending]));

    // Best-effort location: only when the user has opted in. Fetched after the
    // optimistic bubble shows (so the UI stays snappy) and time-bounded by the
    // service, so it doesn't hold the turn waiting for a perfect fix.
    final location =
        await ref.read(settingsRepositoryProvider).locationSharing()
            ? await ref.read(locationServiceProvider).currentPing()
            : null;

    try {
      final result = await ref.read(chatRepositoryProvider).send(
            trimmed,
            agentSlug: agentSlug,
            attachment: attachment,
            cancelToken: cancelToken,
            idempotencyKey: _newIdempotencyKey(),
            location: location,
          );
      final current = state.value ?? base;
      final landed = localAttachments.isEmpty
          ? result.inbound
          : result.inbound.copyWith(attachments: localAttachments);
      final replaced = [
        for (final m in current.messages)
          if (m.id == tempId) landed else m,
        result.outbound,
      ];
      state = AsyncData(current.copyWith(messages: replaced));
      // Refresh the inbox so this thread's preview + unread reflect the turn.
      ref.invalidate(conversationsControllerProvider);
      return SendOutcome.sent;
    } catch (e) {
      final current = state.value ?? base;
      final cancelled =
          e is DioException && e.type == DioExceptionType.cancel;
      // On cancel, drop the optimistic bubble entirely (the composer restores
      // the text); on a real failure, keep it and mark it failed.
      final messages = <ChatMessage>[];
      for (final m in current.messages) {
        if (m.id != tempId) {
          messages.add(m);
        } else if (!cancelled) {
          messages.add(m.copyWith(status: MessageStatus.failed));
        }
      }
      state = AsyncData(current.copyWith(messages: messages));
      return cancelled ? SendOutcome.cancelled : SendOutcome.failed;
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
