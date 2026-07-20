import 'dart:async' show unawaited;
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
import '../../data/chat/turn_meta.dart';
import '../../data/location/location_service.dart';
import '../conversations/conversations_controller.dart';
import '../settings/settings_repository.dart';

part 'chat_controller.g.dart';

/// The result of [ChatController.send] — lets the composer react: clear on
/// [sent], leave the failed bubble on [failed], or restore the text for editing
/// on [cancelled] (the user hit stop).
enum SendOutcome { sent, failed, cancelled, queued }

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
    this.startedAt,
    this.outboundId,
    this.inboundId,
    this.reply = '',
    this.reasoning = '',
    this.steps = const [],
    this.toolsStarted = 0,
    this.toolsDone = 0,
    this.toolsFailed = 0,
    this.tokens,
    this.tokensApprox = true,
    this.phase = TurnPhase.streaming,
    this.error,
  });

  /// The turn id (= the idempotency-key) — the live-stream correlation id.
  final String turnId;

  /// When the live subscription opened — the anchor each trail step's
  /// [ThoughtStep.elapsedMs] is stamped against. Null in tests that don't care.
  final DateTime? startedAt;

  /// Durable `assistant_messages` ids, captured from `turn-start`.
  final String? outboundId;
  final String? inboundId;

  /// Accumulated visible reply text from `text-delta` (the LATEST tool-loop
  /// round — a new round resets it, so tool-then-answer turns show only the
  /// final answer typing out). Advisory: the durable row reconciles it on done.
  final String reply;

  /// Accumulated model reasoning from `reasoning-delta` — the real thinking
  /// the model surfaced this turn. Accumulates across ALL rounds (unlike the
  /// round-scoped reply). Ephemeral: never persisted, so a reload shows none.
  final String reasoning;

  /// Ordered, consecutive-deduped trail of `status` steps seen this turn,
  /// upserted in place by [ThoughtStep.stepId] (a narrated line replaces its
  /// grounded predecessor). Becomes the "thought process" record the durable
  /// row persists. Mirrors the web's `trail`.
  final List<ThoughtStep> steps;

  /// Live tool tally from `tool-start` / `tool-end` — drives the
  /// "N tools · M failed" footer while the turn runs. (The persisted
  /// [ToolStats] on the durable row is the authoritative record.)
  final int toolsStarted;
  final int toolsDone;
  final int toolsFailed;

  /// Output tokens so far: a chars/4 ESTIMATE of all streamed output (reply +
  /// reasoning, across rounds) while the turn runs, swapped for the real
  /// `tokensOut` from `done` when the runner reports it. Null before output.
  final int? tokens;

  /// True while [tokens] is the streamed estimate; false once it's real.
  final bool tokensApprox;

  final TurnPhase phase;

  /// Failure reason once [phase] is [TurnPhase.error]; null otherwise.
  final String? error;

  /// Latest status label — the live typing line (null before any status).
  String? get stageLabel => steps.isEmpty ? null : steps.last.label;

  /// Tools currently running (started but not yet ended).
  int get toolsRunning =>
      toolsStarted > toolsDone ? toolsStarted - toolsDone : 0;

  ActiveTurn copyWith({
    String? outboundId,
    String? inboundId,
    String? reply,
    String? reasoning,
    List<ThoughtStep>? steps,
    int? toolsStarted,
    int? toolsDone,
    int? toolsFailed,
    int? tokens,
    bool? tokensApprox,
    TurnPhase? phase,
    String? error,
  }) {
    return ActiveTurn(
      turnId: turnId,
      startedAt: startedAt,
      outboundId: outboundId ?? this.outboundId,
      inboundId: inboundId ?? this.inboundId,
      reply: reply ?? this.reply,
      reasoning: reasoning ?? this.reasoning,
      steps: steps ?? this.steps,
      toolsStarted: toolsStarted ?? this.toolsStarted,
      toolsDone: toolsDone ?? this.toolsDone,
      toolsFailed: toolsFailed ?? this.toolsFailed,
      tokens: tokens ?? this.tokens,
      tokensApprox: tokensApprox ?? this.tokensApprox,
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
    this.offline = false,
  });

  final List<ChatMessage> messages;
  final bool hasMore;
  final bool loadingMore;
  final ActiveTurn? active;

  /// True when [messages] came from the on-device cache because the network
  /// was unreachable — the screen shows an offline banner and the next
  /// successful refetch clears it.
  final bool offline;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? hasMore,
    bool? loadingMore,
    ActiveTurn? active,
    bool clearActive = false,
    bool? offline,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      active: clearActive ? null : (active ?? this.active),
      offline: offline ?? this.offline,
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

  /// Running character count of ALL streamed output this turn (visible reply +
  /// reasoning, across rounds) — the chars/4 live token estimate. Kept outside
  /// [ActiveTurn] so the round-scoped reply reset doesn't shrink it.
  int _outChars = 0;

  /// True while [_watchPendingRows] is looping (one poll per thread at a time).
  bool _pollingPending = false;

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
        unawaited(_flushQueuedTurns());
      }
    });

    final repo = ref.read(chatRepositoryProvider);
    HistoryPage page;
    List<ChatMessage> queued;
    try {
      page = await repo.history(limit: chatPageSize, agentSlug: agentSlug);
      queued = await _queuedBubbles();
    } catch (e) {
      // Fully offline with an empty cache: if turns are queued, show THEM
      // (with the offline banner) rather than an error screen — the user's
      // unsent words matter more than the empty history.
      queued = await _queuedBubbles();
      if (queued.isEmpty) rethrow;
      page = const HistoryPage(messages: [], fromCache: true);
    }
    // A reply may be mid-turn from another surface (its row is `pending`) —
    // start the resolution poll once this state lands. If anything sits in
    // the offline outbox, try to flush it now too.
    Future.microtask(() {
      if (!ref.mounted) return;
      _watchPendingRows();
      if (queued.isNotEmpty) unawaited(_flushQueuedTurns());
    });
    return ChatState(
      messages: [...page.messages, ...queued],
      // A cache-served page can't promise older pages — offline loadMore
      // fetches are doomed anyway.
      hasMore: !page.fromCache && page.messages.length >= chatPageSize,
      offline: page.fromCache,
    );
  }

  /// The offline outbox rendered as trailing `queued` bubbles (oldest-first,
  /// after all server history — they haven't reached the server yet).
  Future<List<ChatMessage>> _queuedBubbles() async {
    final rows =
        await ref.read(chatRepositoryProvider).queuedTurns(agentSlug);
    return [
      for (final t in rows)
        ChatMessage(
          id: 'queued-${t.id}',
          direction: MessageDirection.inbound,
          text: t.body,
          createdAt: t.createdAt,
          status: MessageStatus.queued,
        ),
    ];
  }

  /// True while a flush is running — build, foreground resume, and send all
  /// trigger flushes, and two overlapping ones would replay the same outbox
  /// row concurrently (safe only if the server dedups in-flight same-key
  /// requests, which we must not rely on).
  bool _flushing = false;

  /// Replay the offline outbox, then refetch so delivered turns (and their
  /// replies) land as real history rows and the queued bubbles disappear.
  Future<void> _flushQueuedTurns() async {
    if (_flushing) return;
    _flushing = true;
    try {
      await _flushQueuedTurnsInner();
    } finally {
      _flushing = false;
    }
  }

  Future<void> _flushQueuedTurnsInner() async {
    final repo = ref.read(chatRepositoryProvider);
    final delivered = await repo.flushOutbox(agentSlug);
    if (!ref.mounted || delivered == 0) return;
    try {
      final latest =
          await repo.history(limit: chatPageSize, agentSlug: agentSlug);
      final queued = await _queuedBubbles();
      if (!ref.mounted) return;
      final now = state.value;
      if (now == null) return;
      final history = [
        for (final m in now.messages)
          if (m.status != MessageStatus.queued) m,
      ];
      state = AsyncData(now.copyWith(
        messages: [
          ..._mergeLatest(now.copyWith(messages: history), latest.messages),
          ...queued,
        ],
        offline: latest.fromCache,
      ));
      ref.invalidate(conversationsControllerProvider);
    } catch (_) {
      /* delivered turns will surface on the next refetch */
    }
  }

  /// A turn landed on this thread elsewhere — pull the latest page and merge it
  /// in: known rows are REPLACED with their latest version (a `pending` reply
  /// resolves to its final text/status) and unknown rows appended. Skipped
  /// while an optimistic send is in flight (that path reconciles itself, and
  /// refetching mid-send could briefly double the user's bubble).
  Future<void> _onRemoteTurn() async {
    final current = state.value;
    if (current == null) return;
    if (current.active != null) return; // a streamed turn reconciles itself
    if (current.messages.any((m) => m.status == MessageStatus.sending)) return;
    try {
      final latest = (await ref
              .read(chatRepositoryProvider)
              .history(limit: chatPageSize, agentSlug: agentSlug))
          .messages;
      if (!ref.mounted) return;
      final now = state.value;
      if (now == null) return;
      state = AsyncData(
        now.copyWith(messages: _mergeLatest(now, latest), offline: false),
      );
      _watchPendingRows();
    } catch (_) {
      /* keep what we have; the next event or refresh reconciles */
    }
  }

  /// Merge a freshly-fetched latest page into the thread: replace known rows
  /// with their latest version, append unknown ones, keep chronological order.
  /// `queued` bubbles are held out of the sort and re-appended TRAILING —
  /// they haven't reached the server, so they must never interleave into the
  /// middle of server history (their enqueue timestamps are older than rows
  /// that land after connectivity returns).
  List<ChatMessage> _mergeLatest(ChatState current, List<ChatMessage> latest) {
    final queued = [
      for (final m in current.messages)
        if (m.status == MessageStatus.queued) m,
    ];
    final rest = [
      for (final m in current.messages)
        if (m.status != MessageStatus.queued) m,
    ];
    final byId = {for (final m in latest) m.id: m};
    final merged = [
      for (final m in rest) byId.remove(m.id) ?? m,
      ...byId.values,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [...merged, ...queued];
  }

  /// The thread shows a server-`pending` reply whose turn is running elsewhere
  /// (another device, web, Telegram — or one we lost the stream for). The
  /// completion UPDATE fires no `conversation_changed` ping (the trigger is
  /// insert-only), so poll the latest page at a gentle cadence until the row
  /// resolves. Bounded (~2 min) — the foreground-resume refetch is the
  /// backstop beyond that.
  void _watchPendingRows() {
    if (_pollingPending) return;
    final hasPending = state.value?.messages
            .any((m) => m.status == MessageStatus.pending) ??
        false;
    if (!hasPending) return;
    _pollingPending = true;
    unawaited(() async {
      try {
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(seconds: 3));
          if (!ref.mounted) return;
          final current = state.value;
          if (current == null) return;
          if (current.active != null) continue; // live turn reconciles itself
          if (!current.messages
              .any((m) => m.status == MessageStatus.pending)) {
            return; // resolved
          }
          try {
            final latest = (await ref
                    .read(chatRepositoryProvider)
                    .history(limit: chatPageSize, agentSlug: agentSlug))
                .messages;
            if (!ref.mounted) return;
            final now = state.value;
            if (now == null) return;
            state = AsyncData(now.copyWith(messages: _mergeLatest(now, latest)));
          } catch (_) {
            /* transient — keep polling */
          }
        }
      } finally {
        _pollingPending = false;
      }
    }());
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
      final older = (await ref
              .read(chatRepositoryProvider)
              .history(before: oldest, limit: chatPageSize, agentSlug: agentSlug))
          .messages;

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
          offline: current.offline,
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

    // Anything still queued from an offline spell goes first, so the
    // conversation lands in the order it was written. If the network is
    // still down this fails fast and the new turn will queue behind it.
    // The full flush (not just replay): it refetches so delivered turns'
    // server rows replace their queued bubbles instead of both vanishing.
    try {
      await _flushQueuedTurns();
      final afterFlush = state.value;
      if (afterFlush != null && ref.mounted) {
        // Keep the new sending bubble last (the flush's merge re-appends
        // still-queued bubbles at the tail, after it).
        state = AsyncData(afterFlush.copyWith(messages: [
          for (final m in afterFlush.messages)
            if (m.id != tempId) m,
          for (final m in afterFlush.messages)
            if (m.id == tempId) m,
        ]));
      }
    } catch (_) {
      /* flush is best-effort here */
    }

    final turnId = _newIdempotencyKey();
    _stopRequested = false;
    _replyRound = -1;
    _outChars = 0;
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
      // Queued offline: the repository stored the turn (same idempotency
      // key) — swap the optimistic bubble for a `queued` one that survives
      // until a flush delivers it.
      if (e is TurnQueuedOffline) {
        final messages = [
          for (final m in current.messages)
            if (m.id == tempId)
              m.copyWith(id: 'queued-${e.turnId}', status: MessageStatus.queued)
            else
              m,
        ];
        state =
            AsyncData(current.copyWith(messages: messages, clearActive: true));
        return SendOutcome.queued;
      }
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
    state = AsyncData(current.copyWith(
      active: ActiveTurn(turnId: turnId, startedAt: DateTime.now()),
    ));

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
        final steps = _upsertStep(active, ev.stepId, ev.kind ?? 'tool', label);
        if (steps == null) return; // no change (duplicate label)
        next = active.copyWith(steps: steps);
      case kTurnToolStart:
        next = active.copyWith(toolsStarted: active.toolsStarted + 1);
      case kTurnToolEnd:
        next = active.copyWith(
          toolsDone: active.toolsDone + 1,
          toolsFailed:
              ev.toolOk == false ? active.toolsFailed + 1 : active.toolsFailed,
        );
      case kTurnReasoningDelta:
        final text = ev.text;
        if (text == null || text.isEmpty) return;
        // Surface the real reasoning (the collapsible "Thinking" trace) AND
        // count it toward the output estimate — it's billed output, kept out
        // of the visible reply buffer. Accumulates across rounds.
        _outChars += text.length;
        next = active.copyWith(
          reasoning: active.reasoning + text,
          tokens: _estimateTokens(_outChars),
        );
      case kTurnTextDelta:
        final text = ev.text;
        if (text == null) return;
        _outChars += text.length;
        final tokens = _estimateTokens(_outChars);
        if (ev.round > _replyRound) {
          // A fresh round (the final answer after tool calls) — replace the
          // buffer so intermediate-round text isn't shown beneath it.
          _replyRound = ev.round;
          next = active.copyWith(reply: text, tokens: tokens);
        } else {
          next = active.copyWith(reply: active.reply + text, tokens: tokens);
        }
      case kTurnDone:
        // Swap the streamed estimate for the real output-token total when the
        // runner reports one (>0); otherwise keep the estimate.
        final real = ev.tokensOut;
        next = real != null && real > 0
            ? active.copyWith(
                phase: TurnPhase.done, tokens: real, tokensApprox: false)
            : active.copyWith(phase: TurnPhase.done);
      case kTurnError:
        next = active.copyWith(
          phase: TurnPhase.error,
          error: ev.message ?? 'The turn failed.',
        );
      default:
        return; // an event type this client doesn't know — ignore (additive)
    }
    state = AsyncData(current.copyWith(active: next));
  }

  /// ~4 chars/token — the standard English heuristic, good enough for a live
  /// readout the real `tokensOut` supersedes the moment the turn finishes.
  static int _estimateTokens(int chars) => max(1, (chars / 4).round());

  /// Fold one `status` event into the trail. Upgrade in place when [stepId]
  /// matches an existing step (grounded → narrated, keeping the original
  /// elapsed stamp); otherwise append, collapsing a consecutive duplicate
  /// label. Returns null when the trail is unchanged. Mirrors the web.
  List<ThoughtStep>? _upsertStep(
    ActiveTurn active,
    String? stepId,
    String kind,
    String label,
  ) {
    final steps = active.steps;
    if (stepId != null) {
      final i = steps.indexWhere((s) => s.stepId == stepId);
      if (i >= 0) {
        if (steps[i].label == label) return null;
        return [
          for (var j = 0; j < steps.length; j++)
            if (j == i) steps[j].upgraded(label: label, kind: kind) else steps[j],
        ];
      }
    }
    if (steps.isNotEmpty && steps.last.label == label) return null;
    final startedAt = active.startedAt;
    return [
      ...steps,
      ThoughtStep(
        stepId: stepId,
        kind: kind,
        label: label,
        elapsedMs: startedAt == null
            ? null
            : DateTime.now().difference(startedAt).inMilliseconds,
      ),
    ];
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
      final latest = (await ref
              .read(chatRepositoryProvider)
              .history(limit: chatPageSize, agentSlug: agentSlug))
          .messages;
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
      final queued = await _queuedBubbles();
      return ChatState(
        messages: [...page.messages, ...queued],
        hasMore: !page.fromCache && page.messages.length >= chatPageSize,
        offline: page.fromCache,
      );
    });
  }
}
