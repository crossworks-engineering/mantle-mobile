import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/pending/pending_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'pending_controller.dart';

/// The agent-approval queue. One card per tool call awaiting a decision (tool
/// name + args preview); Approve dispatches it, Reject drops it. Mirrors the
/// conversations inbox styling. Backed by `GET /api/pending` +
/// `PATCH /api/pending/{id}` via [PendingController].
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(pendingControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Pending', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () =>
                    ref.read(pendingControllerProvider.notifier).refresh(),
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
                        "Couldn't load approvals.",
                        style: theme.textTheme.muted,
                      ),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(pendingControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.checkCheck,
                              size: 32,
                              color: scheme.mutedForeground,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nothing to approve.',
                              style: theme.textTheme.muted,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _PendingTile(theme: theme, call: list[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.theme, required this.call});

  final ShadThemeData theme;
  final PendingCall call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = theme.colorScheme;
    // Flat `accent` card; all text comes from the paired `accentForeground`
    // (tinted with opacity for secondary text) so contrast holds on any theme.
    // See conversations_screen + the styling guide (Cards).
    final onAccent = scheme.accentForeground;
    final preview = call.argsPreview;
    final notifier = ref.read(pendingControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.shieldCheck, size: 18, color: onAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    call.toolSlug,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  call.createdAt == null ? '' : formatWhen(call.createdAt!),
                  style: theme.textTheme.small.copyWith(
                    color: onAccent.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                preview,
                style: theme.textTheme.muted.copyWith(
                  color: onAccent.withValues(alpha: 0.7),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ShadButton.destructive(
                    onPressed: () async {
                      final ok = await confirmDestructive(
                        context,
                        title: 'Reject this request?',
                        description:
                            'The agent is told no and stops waiting on it.',
                        action: 'Reject',
                      );
                      if (ok) await notifier.reject(call.id);
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShadButton(
                    onPressed: () => notifier.approve(call.id),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
