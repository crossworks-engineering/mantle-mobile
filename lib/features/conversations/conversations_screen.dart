import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/conversations/conversation_models.dart';
import '../../widgets/mantle_header.dart';
import '../agents/agent_avatar.dart';
import 'conversations_controller.dart';

/// Tier 1: the conversations inbox — one card per agent (avatar, name, last
/// message preview, time, unread badge). Tap a card to open that thread.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(conversationsControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Chat', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () =>
                    ref.read(conversationsControllerProvider.notifier).refresh(),
                child: Icon(LucideIcons.refreshCw, size: 18, color: fg),
              ),
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: async.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't load conversations.",
                        style: theme.textTheme.muted,
                      ),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(conversationsControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet.',
                          style: theme.textTheme.muted,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _ConversationTile(theme: theme, conversation: list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _relativeTime(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${(d.inDays / 7).floor()}w';
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.theme, required this.conversation});

  final ShadThemeData theme;
  final AgentConversation conversation;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final c = conversation;
    // Flat `accent` card. Every text on it comes from the paired
    // `accentForeground` (tinted with opacity for secondary text) — never
    // `mutedForeground`/`foreground` — so contrast holds even on a theme whose
    // accent is a saturated tint. The unread badge brings its own
    // `primary`/`primaryForeground` pair. See the styling guide (Cards).
    final onAccent = scheme.accentForeground;
    final preview = c.lastText == null
        ? 'No messages yet'
        : '${c.lastFromUser ? 'You: ' : ''}${c.lastText}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/chat/${c.agent.slug}'),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.accent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AgentAvatar(agent: c.agent, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.agent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.p.copyWith(
                              color: onAccent,
                              fontWeight: c.hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _relativeTime(c.lastAt),
                          style: theme.textTheme.small.copyWith(
                            color: onAccent.withValues(
                              alpha: c.hasUnread ? 0.9 : 0.6,
                            ),
                            fontWeight: c.hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.muted.copyWith(
                              color: onAccent.withValues(
                                alpha: c.hasUnread ? 0.85 : 0.6,
                              ),
                            ),
                          ),
                        ),
                        if (c.hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.primaryForeground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
