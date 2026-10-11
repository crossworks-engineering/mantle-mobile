import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/auth/login_access.dart';
import '../auth/login_access_controller.dart';
import '../auth/logins_screen.dart';
import 'workspace_controller.dart';

/// Open the chat of the workspace in use: its own assistant's thread, the
/// owner surface's inbox in the Admin workspace (or on a brain from before
/// workspaces), and a short note when the workspace has no assistant this
/// login may chat with.
Future<void> openWorkspaceChat(BuildContext context, WidgetRef ref) async {
  ChatTarget target;
  try {
    target = await ref.read(chatTargetProvider.future);
  } catch (_) {
    target = const ChatInbox();
  }
  if (!context.mounted) return;
  switch (target) {
    case ChatInbox():
      context.push('/chat');
    case ChatWithAssistant(:final agent):
      context.push('/chat/${agent.slug}');
    case NoAssistantHere(:final workspace):
      ShadToaster.maybeOf(context)?.show(
        ShadToast(
          description: Text(
            '${workspaceLabel(workspace)} has no assistant to chat with.',
          ),
        ),
      );
  }
}

/// What to call a workspace in the phone's own words: a private workspace
/// is the login's own space.
String workspaceLabel(ShellWorkspace workspace) =>
    workspace.private ? 'Only you' : workspace.name;

/// The workspace the phone is in, on the home screen. A tap opens the
/// drawer (the quick switch sheet) where it is changed. Takes no room on a
/// brain from before workspaces.
class WorkspacePill extends ConsumerWidget {
  const WorkspacePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: 'Workspace: ${workspaceLabel(workspace)}',
          hint: 'Opens the workspace switcher',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => QuickSwitchSheet.show(context),
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    workspace.isAdmin
                        ? LucideIcons.shieldCheck
                        : workspace.private
                            ? LucideIcons.lock
                            : LucideIcons.users,
                    size: 15,
                    color: scheme.secondaryForeground,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      workspaceLabel(workspace),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(
                        color: scheme.secondaryForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 15,
                    color: scheme.secondaryForeground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The workspace switcher: every workspace the login is in, the one in use
/// ticked. Part of the drawer (the quick switch sheet). A login in one
/// workspace only, or a brain from before workspaces, shows nothing.
class WorkspaceSwitcher extends ConsumerWidget {
  const WorkspaceSwitcher({super.key, this.onSwitched});

  /// Called after a workspace was picked (the sheet closes itself on it).
  final VoidCallback? onSwitched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(currentAccessProvider);
    final current = ref.watch(currentWorkspaceProvider).value;
    final workspaces = access?.workspaces ?? const <ShellWorkspace>[];
    if (workspaces.length < 2) return const SizedBox.shrink();
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workspace', style: theme.textTheme.h4),
          const SizedBox(height: 12),
          ShadCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < workspaces.length; i++) ...[
                  if (i > 0) Container(height: 1, color: scheme.border),
                  _WorkspaceRow(
                    workspace: workspaces[i],
                    selected: workspaces[i].id == current?.id,
                    onTap: () async {
                      await ref
                          .read(currentWorkspaceProvider.notifier)
                          .select(workspaces[i].id);
                      onSwitched?.call();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.workspace,
    required this.selected,
    required this.onTap,
  });

  final ShellWorkspace workspace;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final detail = [
      if (workspace.isAdmin) 'Manages the brain',
      if (workspace.private) workspace.name,
      if (workspace.moderator && !workspace.isAdmin) 'Moderator',
    ].join(' · ');
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: 'Workspace ${workspaceLabel(workspace)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      workspaceLabel(workspace),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.p.copyWith(
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.muted,
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(LucideIcons.check, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
