import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/agents/agent.dart';
import '../../widgets/mantle_header.dart';
import '../agents/agent_avatar.dart';
import '../agents/agent_controller.dart';
import '../conversations/conversations_controller.dart';
import '../../data/chat/chat_message.dart';
import 'attachment_view.dart';
import 'chat_composer.dart';
import 'chat_controller.dart';
import 'markdown/mantle_markdown.dart';
import 'turn_stage_controller.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final messages = ref.watch(_provider);

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
                  // A typing bubble rides below the newest message (index 0,
                  // reversed) while a reply is being produced.
                  final typing = chat.messages
                          .any((m) => m.status == MessageStatus.sending)
                      ? 1
                      : 0;
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: list.length + typing + (showLoader ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (typing == 1 && i == 0) {
                        return _TypingBubble(
                          theme: theme,
                          agentSlug: widget.agentSlug,
                        );
                      }
                      final adjusted = i - typing;
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
                      final message = list[list.length - 1 - adjusted];
                      return _Bubble(theme: theme, message: message);
                    },
                  );
                },
              ),
            ),
          ),
          ChatComposer(provider: _provider, textController: _input),
        ],
      ),
    );
  }
}

/// Chat header for one agent: avatar + name (in Mantle's wordmark font); back on
/// the right returns to the conversations inbox.
class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({required this.agentSlug});

  final String agentSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fg = ShadTheme.of(context).colorScheme.primaryForeground;
    final agents = ref.watch(agentControllerProvider).value?.agents;
    Agent? agent;
    for (final a in agents ?? const <Agent>[]) {
      if (a.slug == agentSlug) {
        agent = a;
        break;
      }
    }

    return MantleHeader(
      leading: _AgentIdentity(
        name: agent?.name ?? agentSlug,
        avatar: agent,
        foreground: fg,
      ),
      trailing: [
        ShadButton.ghost(
          onPressed: () => context.pop(),
          child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
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
              style: TextStyle(
                fontFamily: 'BukhariScript',
                fontSize: 24,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.theme, required this.message});
  final ShadThemeData theme;
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final fromUser = message.isFromUser;
    final failed = message.status == MessageStatus.failed;
    final sending = message.status == MessageStatus.sending;

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
          Opacity(opacity: sending ? 0.6 : 1, child: bubble),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                'Failed to send',
                style: theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ),
        ],
      ),
    );
  }
}

/// The assistant "typing" bubble shown while a reply is being produced: animated
/// dots plus the responder's current stage label ("Thinking…", "Searching the
/// web…") from [turnStageProvider]. The label is null between mapped steps, in
/// which case only the dots show.
class _TypingBubble extends ConsumerWidget {
  const _TypingBubble({required this.theme, required this.agentSlug});

  final ShadThemeData theme;
  final String agentSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = theme.colorScheme;
    final label = ref.watch(turnStageProvider(agentSlug)).value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TypingDots(color: scheme.mutedForeground),
              if (label != null) ...[
                const SizedBox(width: 10),
                Text(label, style: theme.textTheme.muted),
              ],
            ],
          ),
        ),
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
