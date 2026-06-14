import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/mantle_header.dart';

/// Pending approvals — placeholder. The list + approve/reject flow
/// (`GET /api/pending`, `PATCH /api/pending/{id}`) is the next step.
class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Pending', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(
                  LucideIcons.arrowLeft,
                  size: 20,
                  color: scheme.primaryForeground,
                ),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.inbox,
                        size: 32,
                        color: scheme.mutedForeground,
                      ),
                      const SizedBox(height: 12),
                      Text('Approvals', style: theme.textTheme.h4),
                      const SizedBox(height: 4),
                      Text(
                        'Review and approve tool actions here — coming soon.',
                        style: theme.textTheme.muted,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
