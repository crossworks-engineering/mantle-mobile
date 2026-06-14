import 'package:flutter/services.dart' show TextInputAction;
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
import 'chat_controller.dart';
import 'markdown/mantle_markdown.dart';

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

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(_provider.notifier).send(text);
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
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: list.length + (showLoader ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (showLoader && i == list.length) {
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
                      final message = list[list.length - 1 - i];
                      return _Bubble(theme: theme, message: message);
                    },
                  );
                },
              ),
            ),
          ),
          _Composer(theme: theme, controller: _input, onSend: _send),
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

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fromUser ? scheme.primary : scheme.muted,
        borderRadius: BorderRadius.circular(16),
      ),
      // User messages are plain text (they typed plain text); assistant replies
      // are GFM markdown rendered with our theme tokens.
      child: fromUser
          ? Text(
              message.text,
              style: theme.textTheme.p.copyWith(color: scheme.primaryForeground),
            )
          : MantleMarkdown(message.text, textColor: scheme.foreground),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.theme,
    required this.controller,
    required this.onSend,
  });

  final ShadThemeData theme;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      // Clear the keyboard when open, else the home indicator (the screen no
      // longer sits inside a bottom SafeArea — the header owns the top one).
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 +
            (MediaQuery.viewInsetsOf(context).bottom == 0
                ? MediaQuery.viewPaddingOf(context).bottom
                : MediaQuery.viewInsetsOf(context).bottom),
      ),
      // IntrinsicHeight + stretch keeps the Send button exactly as tall as the
      // input (general rule: buttons beside an input match its height).
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ShadInput(
                controller: controller,
                placeholder: const Text('Message Mantle…'),
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            ShadButton(onPressed: onSend, child: const Text('Send')),
          ],
        ),
      ),
    );
  }
}
