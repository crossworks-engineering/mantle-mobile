import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/format/dates.dart';
import '../../data/conversations/conversation_models.dart';
import '../../data/push/push_text.dart'
    show cutWithEllipsis, headForPlain, plainFromMarkdown;
import '../agents/agent_avatar.dart';
import '../chat/markdown/mantle_markdown.dart';
import '../conversations/conversations_controller.dart';

/// The latest message the person received, on top of the home screen: who it
/// is from, what it says (a few lines, rendered as the chat renders it) and
/// when. Tapping it opens the thread, which marks it read.
///
/// It is why the home screen is worth landing on after a notification: the
/// message is there to read at once. It draws from the inbox
/// ([ConversationsController]), which refetches when the app returns to the
/// foreground and whenever the conversation stream says a thread changed, so
/// a message that arrived while the app was closed shows without a refresh.
/// With nothing received yet it takes no room at all.
class LastMessageCard extends ConsumerWidget {
  const LastMessageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(conversationsControllerProvider).value;
    final latest = inbox == null ? null : latestReceived(inbox);
    if (latest == null) return const SizedBox.shrink();

    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final unread = latest.hasUnread;
    final name = latest.agent.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // One thing to a screen reader: who it is from and what it says, in
      // plain words, as a button that opens the conversation.
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: '${unread ? 'New message' : 'Latest message'} from $name: '
            '${_spoken(latest.lastText!)}',
        hint: 'Opens the conversation',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/chat/${latest.agent.slug}'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: scheme.card,
              borderRadius: theme.radius,
              // An unread message outlines the card in the brand colour: the
              // one thing on this screen asking to be read.
              border: Border.all(
                color: unread ? scheme.primary : scheme.border,
                width: unread ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AgentAvatar(agent: latest.agent, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.p.copyWith(
                          color: scheme.cardForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          latest.unreadCount > 1
                              ? '${latest.unreadCount > 99 ? '99+' : latest.unreadCount} new'
                              : 'New',
                          style: theme.textTheme.small.copyWith(
                            color: scheme.primaryForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        formatWhen(latest.lastAt!),
                        style: theme.textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Only the head of a long reply is laid out: the box shows a
                // few lines, and a whole reply can be very long.
                _Preview(
                  text: headForPlain(latest.lastText!),
                  fade: scheme.card,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The message as a screen reader says it: plain words, cut short.
String _spoken(String markdown) {
  final words =
      plainFromMarkdown(markdown).replaceAll(RegExp(r'\s+'), ' ').trim();
  return cutWithEllipsis(words, 240);
}

/// The message itself, cut to a few lines. Markdown has no `maxLines`, so the
/// rendered reply sits in a box of fixed maximum height; when it is taller,
/// the bottom fades into the card and a line says there is more. The whole
/// card is one tap target, so nothing inside takes a tap of its own.
class _Preview extends StatefulWidget {
  const _Preview({required this.text, required this.fade});

  final String text;

  /// The card's own fill, which the overflow fades into.
  final Color fade;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  static const _maxHeight = 132.0;

  bool _overflows = false;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _maxHeight),
          child: Stack(
            children: [
              // A scroll view that never scrolls: it lets the reply lay out
              // at its full height and reports how much of it is cut off.
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (n) {
                  final over = n.metrics.maxScrollExtent > 0;
                  if (over != _overflows) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _overflows = over);
                    });
                  }
                  return true;
                },
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: IgnorePointer(
                    child: MantleMarkdown(
                      widget.text,
                      textColor: scheme.cardForeground,
                      selectable: false,
                    ),
                  ),
                ),
              ),
              if (_overflows)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.fade.withValues(alpha: 0),
                            widget.fade,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_overflows)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Open to read the rest',
              style: theme.textTheme.small.copyWith(color: scheme.primary),
            ),
          ),
      ],
    );
  }
}
