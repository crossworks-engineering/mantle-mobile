import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/format/dates.dart';
import '../../data/agents/agent.dart';
import '../../widgets/mantle_header.dart';
import '../agents/agent_avatar.dart';
import '../agents/agent_controller.dart';
import '../conversations/conversations_controller.dart';
import '../../data/chat/chat_message.dart';
import '../../data/chat/turn_meta.dart';
import 'attachment_view.dart';
import 'chat_composer.dart';
import 'chat_controller.dart';
import 'chat_timeline.dart';
import 'markdown/mantle_markdown.dart';
import 'turn_stage_controller.dart';
import 'turn_trail.dart';

/// One agent's conversation: history on top, a composer at the bottom.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.agentSlug});

  final String agentSlug;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final ChatControllerProvider _provider =
      chatControllerProvider(widget.agentSlug);

  /// Past this many pixels up the (reversed) list the newest message is out
  /// of view: show the jump button and stop following new replies.
  static const _scrolledUpThreshold = 300.0;

  bool _scrolledUp = false;

  /// Replies that landed while the user was scrolled up; shown on the jump
  /// button instead of yanking the list down.
  int _unseen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Opening the thread clears its unread badge in the inbox.
    Future.microtask(
      () => ref
          .read(conversationsControllerProvider.notifier)
          .markRead(widget.agentSlug),
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  // The list is reversed, so older messages sit toward maxScrollExtent. When the
  // user nears that end, page in the next older batch.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      ref.read(_provider.notifier).loadMore();
    }
    final up = position.pixels > _scrolledUpThreshold;
    if (up != _scrolledUp) {
      setState(() {
        _scrolledUp = up;
        if (!up) _unseen = 0;
      });
    }
  }

  void _jumpToLatest() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    setState(() => _unseen = 0);
  }

  /// New messages while scrolled up: the user's own send follows them down
  /// (they want to see it land); a reply from the agent is counted on the
  /// jump button and the list stays where it is.
  void _onMessages(
    AsyncValue<ChatState>? previous,
    AsyncValue<ChatState> next,
  ) {
    final before = previous?.value?.messages;
    final after = next.value?.messages;
    if (before == null || after == null || after.isEmpty) return;
    if (!_scrolledUp) return;
    final known = {for (final m in before) m.id};
    final horizon = before.isEmpty ? null : before.last.createdAt;
    var replies = 0;
    var sent = false;
    for (final m in after) {
      if (known.contains(m.id)) continue;
      // Paged-in history is older than anything we had; only the tail counts.
      if (horizon != null && !m.createdAt.isAfter(horizon)) continue;
      if (m.isFromUser) {
        sent = true;
      } else {
        replies++;
      }
    }
    if (sent) {
      _jumpToLatest();
    } else if (replies > 0) {
      setState(() => _unseen += replies);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final messages = ref.watch(_provider);
    ref.listen(_provider, _onMessages);
    final agent = agentBySlug(ref, widget.agentSlug);

    return Container(
      color: theme.colorScheme.background,
      child: Column(
        children: [
          _ChatHeader(agentSlug: widget.agentSlug),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: messages.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Couldn't load the conversation.",
                          style: theme.textTheme.muted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ShadButton.outline(
                          onPressed: () =>
                              ref.read(_provider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (chat) {
                  final list = chat.messages;
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'No messages yet. Say hello 👋',
                        style: theme.textTheme.muted,
                      ),
                    );
                  }
                  // A loader rides above the oldest message while paging older
                  // history — the highest index, since the list is reversed.
                  final showLoader = chat.loadingMore;
                  // Below the newest message (index 0, reversed) rides ONE
                  // overlay while a reply is being produced: the reply itself
                  // typing out live once tokens arrive, else a typing bubble
                  // (animated dots + stage label). The legacy blocking path has
                  // no live tokens, so it shows the typing bubble throughout.
                  final active = chat.active;
                  final streamingReply =
                      active != null && active.reply.trim().isNotEmpty;
                  final showTyping = !streamingReply &&
                      (active != null ||
                          chat.messages
                              .any((m) => m.status == MessageStatus.sending));
                  final overlay = (streamingReply || showTyping) ? 1 : 0;
                  final listView = ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: list.length + overlay + (showLoader ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (overlay == 1 && i == 0) {
                        return streamingReply
                            ? _StreamingBubble(theme: theme, active: active)
                            : _TypingBubble(
                                theme: theme,
                                agentSlug: widget.agentSlug,
                                active: active,
                              );
                      }
                      final adjusted = i - overlay;
                      if (showLoader && adjusted == list.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Loading earlier messages…',
                              style: theme.textTheme.muted,
                            ),
                          ),
                        );
                      }
                      // reverse:true → newest at the bottom.
                      final index = list.length - 1 - adjusted;
                      final message = list[index];
                      return _Bubble(
                        theme: theme,
                        message: message,
                        // In a reversed list the divider sits above the first
                        // message of its day, which is the item with the
                        // higher index; it is part of that item, so paging
                        // and the queued bubbles never see it.
                        showDay: startsDay(list, index),
                        showTime: showsTime(list, index),
                        onRetry: message.status == MessageStatus.failed
                            ? () => ref.read(_provider.notifier).retry(message)
                            : null,
                      );
                    },
                  );
                  final body = Stack(
                    children: [
                      listView,
                      if (_scrolledUp)
                        Positioned(
                          right: 16,
                          bottom: 12,
                          child: _JumpToLatestButton(
                            theme: theme,
                            unseen: _unseen,
                            onPressed: _jumpToLatest,
                          ),
                        ),
                    ],
                  );
                  if (!chat.offline) return body;
                  // Serving from the on-device cache — say so, and offer a
                  // manual reconnect.
                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: theme.colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Icon(LucideIcons.wifiOff,
                                size: 14,
                                color: theme.colorScheme.secondaryForeground),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Offline — showing saved messages',
                                style: theme.textTheme.small.copyWith(
                                  color:
                                      theme.colorScheme.secondaryForeground,
                                ),
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  ref.read(_provider.notifier).refresh(),
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                child: Text(
                                  'Retry',
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.secondaryForeground,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: body),
                    ],
                  );
                },
              ),
            ),
          ),
          ChatComposer(
            provider: _provider,
            textController: _input,
            agentName: agent?.name ?? widget.agentSlug,
          ),
        ],
      ),
    );
  }
}

/// The agent this thread belongs to, from the loaded agent list; null until
/// the list arrives (callers fall back to the slug).
Agent? agentBySlug(WidgetRef ref, String slug) {
  final agents = ref.watch(agentControllerProvider).value?.agents;
  for (final a in agents ?? const <Agent>[]) {
    if (a.slug == slug) return a;
  }
  return null;
}

/// Chat header for one agent: avatar + name; back on the right returns to the
/// conversations inbox.
class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.agentSlug});

  final String agentSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fg = ShadTheme.of(context).colorScheme.primaryForeground;
    final agent = agentBySlug(ref, agentSlug);

    return MantleHeader(
      leading: _AgentIdentity(
        name: agent?.name ?? agentSlug,
        avatar: agent,
        foreground: fg,
      ),
      trailing: [
        HeaderAction(
          icon: LucideIcons.arrowLeft,
          label: 'Back',
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

class _AgentIdentity extends StatelessWidget {
  const _AgentIdentity({
    required this.name,
    required this.avatar,
    required this.foreground,
  });

  final String name;
  final Agent? avatar;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[
            AgentAvatar(agent: avatar!, size: 26),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: headerTitleStyle(ShadTheme.of(context))
                  .copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.theme,
    required this.message,
    this.showDay = false,
    this.showTime = false,
    this.onRetry,
  });
  final ShadThemeData theme;
  final ChatMessage message;

  /// A day divider above this bubble (the first message of its day).
  final bool showDay;

  /// The clock time under this bubble (a gap since the previous message).
  final bool showTime;

  /// Set for failed user messages — resends this turn.
  final VoidCallback? onRetry;

  /// Long-press menu: the full time stamp, copy the text, and retry if this
  /// send failed.
  Future<void> _showActions(BuildContext context) async {
    final hasText = message.text.trim().isNotEmpty;
    final choice = await showShadSheet<String>(
      context: context,
      builder: (ctx) => ShadSheet(
        title: Text(
          '${formatDay(message.createdAt)} · ${formatTime(message.createdAt)}',
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                _sheetAction(ctx, LucideIcons.copy, 'Copy text', 'copy'),
              if (onRetry != null)
                _sheetAction(ctx, LucideIcons.refreshCw, 'Retry send', 'retry'),
            ],
          ),
        ),
      ),
    );
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.text));
    } else if (choice == 'retry') {
      onRetry?.call();
    }
  }

  Widget _sheetAction(
      BuildContext ctx, IconData icon, String label, String value) {
    return SizedBox(
      width: double.infinity,
      child: ShadButton.ghost(
        onPressed: () => Navigator.of(ctx).pop(value),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18),
            const SizedBox(width: 12),
            Text(label),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final fromUser = message.isFromUser;
    final failed = message.status == MessageStatus.failed;
    final sending = message.status == MessageStatus.sending;
    final queued = message.status == MessageStatus.queued;
    // A reply whose turn is still running elsewhere (server `pending` — e.g.
    // the thread was opened mid-turn started from web/Telegram). Renders as a
    // working bubble; the controller polls until the row resolves.
    final pendingReply = !fromUser && message.status == MessageStatus.pending;

    final hasText = message.text.trim().isNotEmpty;
    // User messages are plain text (they typed plain text); assistant replies
    // are GFM markdown rendered with our theme tokens. Attachments (images
    // inline, files as chips) stack above the text.
    final body = <Widget>[
      for (final attachment in message.attachments)
        Padding(
          padding: EdgeInsets.only(bottom: hasText ? 8 : 0),
          child: AttachmentView(
            attachment: attachment,
            theme: theme,
            onUserBubble: fromUser,
          ),
        ),
      if (hasText)
        fromUser
            ? Text(
                message.text,
                style:
                    theme.textTheme.p.copyWith(color: scheme.primaryForeground),
              )
            : MantleMarkdown(message.text, textColor: scheme.foreground),
      if (pendingReply)
        Padding(
          padding: EdgeInsets.only(top: hasText ? 6 : 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDots(color: scheme.mutedForeground),
              const SizedBox(width: 10),
              Text('Still working…', style: theme.textTheme.muted),
            ],
          ),
        ),
    ];

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fromUser ? scheme.primary : scheme.muted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: body,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showDay) _DayDivider(theme: theme, at: message.createdAt),
          GestureDetector(
            onLongPress: () => _showActions(context),
            child: Opacity(
              opacity: sending || queued || message.superseded ? 0.6 : 1,
              child: bubble,
            ),
          ),
          // A replaced pair (stopped and re-sent with a correction) stays in
          // the thread, dimmed and tagged; the brain keeps it out of prompts.
          if (message.superseded)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.listRestart,
                      size: 13, color: scheme.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    'Replaced',
                    style: theme.textTheme.small
                        .copyWith(color: scheme.mutedForeground),
                  ),
                ],
              ),
            ),
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                formatTime(message.createdAt),
                style: theme.textTheme.muted,
              ),
            ),
          // A failed USER send gets the retry affordance; a failed ASSISTANT
          // turn shows the server's failure reason instead (nothing to retry —
          // the user rephrases and sends again).
          if (failed && fromUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Failed to send',
                    style: theme.textTheme.small
                        .copyWith(color: scheme.destructive),
                  ),
                  if (onRetry != null) ...[
                    Text('  ·  ',
                        style: theme.textTheme.small
                            .copyWith(color: scheme.mutedForeground)),
                    Semantics(
                      button: true,
                      label: 'Retry send',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onRetry,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.refreshCw,
                                  size: 13, color: scheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Retry',
                                style: theme.textTheme.small
                                    .copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (failed && !fromUser)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                message.error?.isNotEmpty == true
                    ? 'Turn failed: ${message.error}'
                    : 'The turn failed.',
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ),
          if (queued)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.clock,
                      size: 13, color: scheme.mutedForeground),
                  const SizedBox(width: 4),
                  Text(
                    'Queued — sends when back online',
                    style: theme.textTheme.small
                        .copyWith(color: scheme.mutedForeground),
                  ),
                ],
              ),
            ),
          // The turn's persisted record: the thought trail (collapsed behind a
          // disclosure) and the deterministic tool tally. Mirrors the web's
          // "Thought process" + "N tool calls" footer under each reply.
          if (!fromUser &&
              (message.thoughts.isNotEmpty || message.toolStats != null))
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.thoughts.isNotEmpty)
                    TrailDisclosure(
                      title:
                          'Thought process · ${message.thoughts.length} ${message.thoughts.length == 1 ? 'step' : 'steps'}',
                      child:
                          TurnTrail(steps: message.thoughts, emphasizeLast: false),
                    ),
                  if (message.toolStats != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: ToolStatsLine(stats: message.toolStats!),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A centred day name between two days of messages: a rule either side of
/// `Today` / `Yesterday` / `Fri 18 Sep`, in the muted text style.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.theme, required this.at});

  final ShadThemeData theme;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final rule = Expanded(
      child: Container(height: 1, color: theme.colorScheme.border),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Row(
        children: [
          rule,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(formatDay(at), style: theme.textTheme.muted),
          ),
          rule,
        ],
      ),
    );
  }
}

/// The round "back to the newest message" button that floats above the
/// composer once the user has scrolled up. With replies unseen it grows into
/// a pill carrying the count.
class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({
    required this.theme,
    required this.unseen,
    required this.onPressed,
  });

  final ShadThemeData theme;
  final int unseen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final label = unseen == 0
        ? 'Jump to latest'
        : 'Jump to latest, $unseen new ${unseen == 1 ? 'reply' : 'replies'}';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          height: 44,
          constraints: const BoxConstraints(minWidth: 44),
          padding: EdgeInsets.symmetric(horizontal: unseen == 0 ? 0 : 12),
          // A halo in the screen's own fill keeps the button legible when it
          // floats over a user bubble of the same primary colour.
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.background, width: 3),
            boxShadow: [
              BoxShadow(
                color: scheme.foreground.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (unseen > 0) ...[
                Text(
                  '$unseen',
                  style: theme.textTheme.small.copyWith(
                    color: scheme.primaryForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Icon(LucideIcons.arrowDown,
                  size: 20, color: scheme.primaryForeground),
            ],
          ),
        ),
      ),
    );
  }
}

/// The assistant reply typing out live, token by token (streaming path). Same
/// muted assistant bubble as the final reply (so the swap to the durable
/// [_Bubble] on `done` is seamless): an optional live "Thinking" trace above,
/// the markdown reply, then a footer with the typing dots, the live token
/// estimate, and the tool tally.
class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.theme, required this.active});

  final ShadThemeData theme;
  final ActiveTurn active;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (active.reasoning.isNotEmpty) ...[
                TrailDisclosure(
                  title: 'Thinking',
                  child: Text(
                    active.reasoning,
                    style: theme.textTheme.muted,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              // Selection is off mid-stream (it would fight the per-token
              // rebuild); the reconciled durable bubble is selectable.
              MantleMarkdown(active.reply,
                  textColor: scheme.foreground, selectable: false),
              const SizedBox(height: 6),
              _LiveTurnFooter(theme: theme, active: active),
            ],
          ),
        ),
      ),
    );
  }
}

/// The assistant "typing" bubble shown while a reply is being produced before
/// any visible text. On a streamed turn ([active] non-null) it shows the live
/// thought trail — each step with its kind icon and elapsed stamp — plus the
/// tool tally; on the legacy path it falls back to polling [turnStageProvider]
/// for a single stage label. Dots only between mapped steps.
class _TypingBubble extends ConsumerWidget {
  const _TypingBubble({
    required this.theme,
    required this.agentSlug,
    this.active,
  });

  final ShadThemeData theme;
  final String agentSlug;
  final ActiveTurn? active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = theme.colorScheme;
    final active = this.active;
    final steps = active?.steps ?? const <ThoughtStep>[];
    // Streamed turns carry their own trail; only the legacy path polls.
    final polledLabel = active == null
        ? ref.watch(turnStageProvider(agentSlug)).value
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (steps.isNotEmpty) ...[
                TurnTrail(steps: steps),
                const SizedBox(height: 8),
              ],
              if (active != null && active.reasoning.isNotEmpty) ...[
                TrailDisclosure(
                  title: 'Thinking',
                  child: Text(
                    active.reasoning,
                    style: theme.textTheme.muted,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDots(color: scheme.mutedForeground),
                  if (polledLabel != null) ...[
                    const SizedBox(width: 10),
                    Text(polledLabel, style: theme.textTheme.muted),
                  ],
                  if (active != null) _LiveTallyText(theme: theme, active: active),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer for the live streaming bubble: dots + the token readout + tool tally.
class _LiveTurnFooter extends StatelessWidget {
  const _LiveTurnFooter({required this.theme, required this.active});

  final ShadThemeData theme;
  final ActiveTurn active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypingDots(color: theme.colorScheme.mutedForeground),
        _LiveTallyText(theme: theme, active: active),
      ],
    );
  }
}

/// "· ≈128 tokens · 3 tools (1 failed)" — the live tally riding beside the
/// typing dots. Empty until there's something to say.
class _LiveTallyText extends StatelessWidget {
  const _LiveTallyText({required this.theme, required this.active});

  final ShadThemeData theme;
  final ActiveTurn active;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    final tokens = active.tokens;
    if (tokens != null) {
      parts.add(active.tokensApprox ? '≈$tokens tokens' : '$tokens tokens');
    }
    if (active.toolsStarted > 0) {
      final tools =
          '${active.toolsStarted} ${active.toolsStarted == 1 ? 'tool' : 'tools'}';
      parts.add(
        active.toolsFailed > 0 ? '$tools (${active.toolsFailed} failed)' : tools,
      );
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        parts.join(' · '),
        style: theme.textTheme.muted,
      ),
    );
  }
}

/// Three dots pulsing in sequence — the wait animation for [_TypingBubble].
class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot's pulse is phase-shifted, giving a left-to-right wave.
            final t = (_controller.value + i * 0.2) % 1.0;
            final pulse = (0.5 - (t - 0.5).abs()) * 2; // 0 → 1 → 0 triangle
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
              child: Opacity(
                opacity: (0.3 + 0.7 * pulse).clamp(0.3, 1.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
