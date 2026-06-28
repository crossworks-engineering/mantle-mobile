import 'dart:math';

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/chat/chat_api.dart';
import '../../data/chat/chat_attachment.dart';
import '../../data/chat/chat_message.dart';
import '../../data/chat/chat_repository.dart';
import '../../data/chat/conversation_stream.dart';
import '../../data/chat/turn_event.dart';
import '../../data/location/location_service.dart';
import '../conversations/conversations_controller.dart';
import '../settings/settings_repository.dart';

part 'chat_controller.g.dart';

/// The result of [ChatController.send] — lets the composer react: clear on
/// [sent], leave the failed bubble on [failed], or restore the text for editing
/// on [cancelled] (the user hit stop).
enum SendOutcome { sent, failed, cancelled }

/// Where a streamed turn is in its lifecycle, driven by the terminal bus events.
enum TurnPhase { streaming, done, error }

/// The live state of one in-flight **streamed** turn, accumulated from the SSE
/// bus ([ChatRepository.streamTurn]). Mirrors the web's `TurnStream`: the reply
/// types out token by token into [reply], the typing line tracks [stageLabel],
/// and the durable [outboundId] is the handle we reconcile against on `done`.
/// Null whenever no streamed turn is running (the legacy blocking path never
/// sets it).
class ActiveTurn {
  const ActiveTurn({
    required this.turnId,
    this.outboundId,
    this.inboundId,
    this.reply = '',
    this.stageLabel,
    this.phase = TurnPhase.streaming,
    this.error,
  });

  /// The turn id (= the idempotency-key) — the live-stream correlation id.
  final String turnId;

  /// Durable `assistant_messages` ids, captured from `turn-start`.
  final String? outboundId;
  final String? inboundId;

  /// Accumulated visible reply text from `text-delta` (the LATEST tool-loop
  /// round — a new round resets it, so tool-then-answer turns show only the
  /// final answer typing out). Advisory: the durable row reconciles it on done.
  final String reply;

  /// Latest `status` label for the typing line (null before any status event).
  final String? stageLabel;

  final TurnPhase phase;

  /// Failure reason once [phase] is [TurnPhase.error]; null otherwise.
  final String? error;

  ActiveTurn copyWith({
    String? outboundId,
    String? inboundId,
    String? reply,
    String? stageLabel,
    TurnPhase? phase,
    String? error,
  }) {
    return ActiveTurn(
      turnId: turnId,
      outboundId: outboundId ?? this.outboundId,
      inboundId: inboundId ?? this.inboundId,
      reply: reply ?? this.reply,
      stageLabel: stageLabel ?? this.stageLabel,
      phase: phase ?? this.phase,
      error: error ?? this.error,
    );
  }
}

/// A fresh 128-bit hex `idempotency-key` for one send. The server replays a
/// cached result for a repeated key, so a retried/replayed POST that already
/// completed server-side won't create a duplicate turn. It's also the turn id —
/// the live-stream correlation id and the durable reconciliation handle.
String _newIdempotencyKey() {
  final rand = Random.secure();
  return List<int>.generate(16, (_) => rand.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// The chat thread plus its paging state. [messages] is oldest-first (the screen
/// reverses it for display). [hasMore] is true while older pages may still
/// exist; [loadingMore] is true while a scroll-up fetch is in flight. [active]
/// is the live state of a streaming turn (null on the legacy blocking path).
class ChatState {
  const ChatState({
    required this.messages,
    required this.hasMore,
    this.loadingMore = false,
    this.active,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingMore;
  final ActiveTurn? active;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loadingMore,
    ActiveTurn? active,
    bool clearActive = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      active: clearActive ? null : (active ?? this.active),
    );
  }
}

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
///
/// When live streaming is on the reply types out token by token: `send` returns
/// **202**, this controller subscribes to the turn's SSE bus and accumulates the
/// reply into [ChatState.active], then reconciles to the durable row on `done`.
/// When it's off the server returns the finished rows and we swap them in. Both
/// shapes are handled, so the app degrades gracefully either way.
@riverpod
class ChatController extends _$ChatController {
  /// Token for the in-flight turn's SSE subscription (torn down on stop/dispose).
  CancelToken? _streamCancel;

  /// Token for the in-flight POST (the legacy blocking path's stop cancels it).
  CancelToken? _postCancel;

  /// Set by [stopTurn] so the awaited `send` returns [SendOutcome.cancelled]
  /// (the composer then restores the prompt for editing).
  bool _stopRequested = false;

  /// Highest `text-delta` round seen this turn — a higher round resets the reply
  /// buffer so only the final answer (after tool calls) types out.
  int _replyRound = -1;

  @override
  Future<ChatState> build(String agentSlug) async {
    // Tear the live turn stream down when the thread leaves the screen; the
    // turn still completes durably server-side and reconciles on return.
    ref.onDispose(() {
      _streamCancel?.cancel();
      _postCancel?.cancel();
    });

    // Live updates: when a turn lands on THIS agent's thread (any channel — a
    // proactive heartbeat, or a message you sent from web/Telegram), merge the
    // new messages in without disturbing scroll or paging.
    ref.listen(conversationEventsProvider, (_, next) {
      if (next is AsyncData<ConversationEvent> &&
          next.value.agentSlug == agentSlug) {
        _onRemoteTurn();
      }
    });

    // The SSE stream is paused while the app is backgrounded, so a turn that
    // landed meanwhile — e.g. the one a tapped notification is about — was
    // never streamed to us. Pull the latest when the app returns to the
    // foreground so the open thread catches up without a manual back-and-forth.
    ref.listen(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleState.resumed &&
          prev != AppLifecycleState.resumed) {
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
    if (current.active != null) return; // a streamed turn reconciles itself
    if (current.messages.any((m) => m.status == MessageStatus.sending)) return;
    try {
      final latest = await ref
          .read(chatRepositoryProvider)
          .history(limit: chatPageSize, agentSlug: agentSlug);
      final known = current.messages.map((m) => m.id).toSet();
      final fresh = latest.where((m) => !known.contains(m.id)).toList();
      if (fresh.isEmpty || !ref.mounted) return;
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
        ChatState(
          messages: merged,
          hasMore: older.length >= chatPageSize,
          active: current.active,
        ),
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
  /// With streaming on the reply types out live (see the class doc) and the
  /// composer's stop button calls [stopTurn] to halt it server-side, keeping the
  /// partial; either path returns [SendOutcome.cancelled] on stop so the composer
  /// restores the text for editing.
  Future<SendOutcome> send(String text, {OutgoingAttachment? attachment}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachment == null) return SendOutcome.sent;

    final base = state.value ?? const ChatState(messages: [], hasMore: false);
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

    final turnId = _newIdempotencyKey();
    _stopRequested = false;
    _replyRound = -1;
    final postCancel = CancelToken();
    _postCancel = postCancel;

    try {
      final resp = await ref.read(chatRepositoryProvider).send(
            trimmed,
            agentSlug: agentSlug,
            attachment: attachment,
            cancelToken: postCancel,
            idempotencyKey: turnId,
            location: location,
          );

      // Streaming on (202): drive the reply off the live SSE bus.
      if (resp is TurnAccepted) {
        return await _runStreamingTurn(resp.turnId, tempId, localAttachments);
      }

      // Legacy blocking result (200): swap the optimistic bubble for the rows.
      final result = (resp as TurnCompleted).result;
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
      state = AsyncData(current.copyWith(messages: messages, clearActive: true));
      return cancelled ? SendOutcome.cancelled : SendOutcome.failed;
    } finally {
      _postCancel = null;
    }
  }

  /// Drive a streamed turn: set [ChatState.active], consume the SSE bus until the
  /// terminal `done`/`error`, then reconcile to the durable rows. Never throws —
  /// a dead stream falls through to a history reconcile.
  Future<SendOutcome> _runStreamingTurn(
    String turnId,
    String tempId,
    List<ChatAttachment> localAttachments,
  ) async {
    final current = state.value;
    if (current == null) return SendOutcome.sent;
    // Switch the UI from the optimistic bubble to the live typing/streaming view.
    state = AsyncData(current.copyWith(active: ActiveTurn(turnId: turnId)));

    final streamCancel = CancelToken();
    _streamCancel = streamCancel;
    try {
      await for (final ev in ref
          .read(chatRepositoryProvider)
          .streamTurn(turnId, cancelToken: streamCancel)) {
        _applyTurnEvent(ev);
        if (ev.isTerminal) break;
      }
    } catch (_) {
      /* stream died — fall through to a history reconcile below */
    } finally {
      _streamCancel = null;
    }

    // The thread left the screen mid-stream — the turn finishes durably
    // server-side and reconciles on return; nothing more to do here.
    if (!ref.mounted) {
      return _stopRequested ? SendOutcome.cancelled : SendOutcome.sent;
    }

    final phase = state.value?.active?.phase ?? TurnPhase.done;
    // A genuine failure (not a user stop) — surface it on the user's bubble.
    if (phase == TurnPhase.error && !_stopRequested) {
      return _failStreamingTurn(tempId);
    }
    await _reconcileActiveTurn(tempId, localAttachments);
    return _stopRequested ? SendOutcome.cancelled : SendOutcome.sent;
  }

  /// Fold one live event into [ChatState.active] (no-op once the turn ended or
  /// for an event from a stale turn). Mirrors the web's `useTurnStream`.
  void _applyTurnEvent(TurnEvent ev) {
    if (!ref.mounted) return; // disposed mid-stream — drop the event
    final current = state.value;
    final active = current?.active;
    if (current == null || active == null) return;
    if (active.turnId != ev.turnId) return; // a stale event from a prior turn

    ActiveTurn next;
    switch (ev.type) {
      case kTurnStart:
        next = active.copyWith(
          outboundId: ev.outboundId,
          inboundId: ev.inboundId,
        );
      case kTurnStatus:
        final label = ev.label;
        if (label == null || label.isEmpty) return;
        next = active.copyWith(stageLabel: label);
      case kTurnTextDelta:
        final text = ev.text;
        if (text == null) return;
        if (ev.round > _replyRound) {
          // A fresh round (the final answer after tool calls) — replace the
          // buffer so intermediate-round text isn't shown beneath it.
          _replyRound = ev.round;
          next = active.copyWith(reply: text);
        } else {
          next = active.copyWith(reply: active.reply + text);
        }
      case kTurnDone:
        next = active.copyWith(phase: TurnPhase.done);
      case kTurnError:
        next = active.copyWith(
          phase: TurnPhase.error,
          error: ev.message ?? 'The turn failed.',
        );
      default:
        return; // reasoning-delta / tool-start / tool-end — not shown here
    }
    state = AsyncData(current.copyWith(active: next));
  }

  /// The streamed turn finished — pull the canonical rows (the durable inbound +
  /// the now-complete outbound) and swap them in for the optimistic temp bubble
  /// and the live streaming view. Mirrors the web's `syncLatest` (merge-by-id,
  /// keep our local image preview on the inbound — the server strips the bytes).
  Future<void> _reconcileActiveTurn(
    String tempId,
    List<ChatAttachment> localAttachments,
  ) async {
    try {
      final latest = await ref
          .read(chatRepositoryProvider)
          .history(limit: chatPageSize, agentSlug: agentSlug);
      final current = state.value;
      if (current == null || !ref.mounted) return;
      final inboundId = current.active?.inboundId;
      final withPreview = localAttachments.isEmpty || inboundId == null
          ? latest
          : [
              for (final m in latest)
                if (m.id == inboundId)
                  m.copyWith(attachments: localAttachments)
                else
                  m,
            ];
      // Drop the optimistic temp bubble; merge unknown canonical rows in.
      final kept = current.messages.where((m) => m.id != tempId).toList();
      final knownIds = kept.map((m) => m.id).toSet();
      final merged = [
        ...kept,
        ...withPreview.where((m) => !knownIds.contains(m.id)),
      ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = AsyncData(current.copyWith(messages: merged, clearActive: true));
      ref.invalidate(conversationsControllerProvider);
    } catch (_) {
      // History fetch failed — clear the streaming view but keep what we have;
      // the lifecycle / conversation-event reconcile catches up later.
      final current = state.value;
      if (current != null && ref.mounted) {
        state = AsyncData(current.copyWith(clearActive: true));
      }
    }
  }

  /// A streamed turn errored (not a user stop) — mark the optimistic bubble
  /// failed so the user can retry, and clear the streaming view.
  SendOutcome _failStreamingTurn(String tempId) {
    final current = state.value;
    if (current != null && ref.mounted) {
      final messages = [
        for (final m in current.messages)
          if (m.id == tempId) m.copyWith(status: MessageStatus.failed) else m,
      ];
      state = AsyncData(current.copyWith(messages: messages, clearActive: true));
    }
    return SendOutcome.failed;
  }

  /// Stop an in-flight turn. For a streamed turn this asks the runner to abort
  /// and keep the partial reply (which lands via the normal `done` reconcile);
  /// for the legacy blocking path it cancels the request. Either way `send`
  /// returns [SendOutcome.cancelled] so the composer restores the prompt.
  Future<void> stopTurn() async {
    if (!ref.mounted) return; // the turn finishes durably without us
    _stopRequested = true;
    final active = state.value?.active;
    if (active == null) {
      // Legacy blocking turn (or the brief pre-202 window) — abort the POST.
      _postCancel?.cancel('stopped by user');
      return;
    }
    // Streamed turn — server-side abort; the runner finalizes the partial and
    // emits `done`, which `send` reconciles as usual.
    await ref.read(chatRepositoryProvider).cancelTurn(active.turnId);
    // Backstop: if that `done` (with the partial) doesn't reach us shortly after
    // the abort, tear the stream down so `send` falls through to a history
    // reconcile (the row is finalized server-side by then).
    final cancel = _streamCancel;
    if (cancel != null) {
      Future.delayed(const Duration(seconds: 4), () {
        if (!cancel.isCancelled) cancel.cancel('stop backstop');
      });
    }
  }

  /// Resend a message that previously [MessageStatus.failed] (e.g. it went out
  /// on a flaky connection). Drops the failed bubble, then re-sends its text and
  /// attachment (reconstructed from the local preview) as a fresh turn.
  Future<SendOutcome> retry(ChatMessage failed) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        messages: current.messages.where((m) => m.id != failed.id).toList(),
      ));
    }

    // Rebuild the OutgoingAttachment from the bubble's local preview, if any.
    OutgoingAttachment? attachment;
    for (final a in failed.attachments) {
      if (a.localPath != null) {
        attachment = OutgoingAttachment(
          path: a.localPath!,
          filename: a.caption ?? 'attachment',
          mime: a.mime ?? 'application/octet-stream',
        );
        break;
      }
    }
    return send(failed.text, attachment: attachment);
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
