import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/db/app_database.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mantle_header.dart';
import 'session_controller.dart';
import '../workspaces/workspace_switcher.dart';

/// Settings → Logins: every login this phone holds, on one brain or many.
///
/// A list with three actions, not an editor: tap to switch, sign out, add.
/// That keeps it inside the phone's scope rule. The brain's own "Logins"
/// screen (who may sign in to that brain) is a different thing and lives on
/// the web.
class LoginsScreen extends ConsumerWidget {
  const LoginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final held = ref.watch(heldSessionsProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Logins', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    'The logins this phone holds. Tap one to switch to it '
                    'without signing in again.',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 16),
                  HeldLoginsList(held: held.value ?? const []),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton.outline(
                      leading: const Icon(LucideIcons.plus, size: 16),
                      onPressed: () => ref
                          .read(sessionControllerProvider.notifier)
                          .startAddLogin(),
                      child: const Text('Add login'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Adding a login steps out of this one while you sign in. '
                    'It stays signed in, and you can come straight back.',
                    style: theme.textTheme.muted,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The held logins as a card of rows. Shared by the Logins screen and the
/// quick-switch sheet, so the two can never disagree about what a row does.
class HeldLoginsList extends ConsumerStatefulWidget {
  const HeldLoginsList({super.key, required this.held, this.onSwitched});

  final List<HeldSession> held;

  /// Called after a switch was started (the sheet closes itself on it).
  final VoidCallback? onSwitched;

  @override
  ConsumerState<HeldLoginsList> createState() => _HeldLoginsListState();
}

class _HeldLoginsListState extends ConsumerState<HeldLoginsList> {
  String? _busyId;
  String? _error;

  Future<void> _switch(Session session) async {
    setState(() {
      _busyId = session.id;
      _error = null;
    });
    final controller = ref.read(sessionControllerProvider.notifier);
    widget.onSwitched?.call();
    if (session.needsSignIn) {
      await controller.signInAgain(session.id);
    } else {
      await controller.switchTo(session.id);
    }
    if (mounted) setState(() => _busyId = null);
  }

  Future<void> _signOut(HeldSession held) async {
    final name = _brainName(held.session);
    final confirmed = await confirmDestructive(
      context,
      title: 'Sign out of this login?',
      description: held.active
          ? 'You are using it now. Its cached and unsent messages are removed '
              'from this phone, and you move to the next login held here, or '
              'to the sign-in screen. Other logins are not affected.'
          : '$name is told to end it, and its cached and unsent messages are '
              'removed from this phone. Other logins are not affected.',
      action: 'Sign out',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busyId = held.session.id;
      _error = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .signOutOf(held.session.id);
      ref.invalidate(heldSessionsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't clear that login on this phone.");
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final held = widget.held;

    if (held.isEmpty) {
      return ShadCard(
        child: Text('No logins held yet.', style: theme.textTheme.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadCard(
          child: Column(
            children: [
              for (var i = 0; i < held.length; i++) ...[
                if (i > 0) Container(height: 1, color: scheme.border),
                _LoginRow(
                  held: held[i],
                  busy: _busyId == held[i].session.id,
                  enabled: _busyId == null,
                  onTap: held[i].active ? null : () => _switch(held[i].session),
                  onSignOut: () => _signOut(held[i]),
                ),
              ],
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: theme.textTheme.small.copyWith(color: scheme.destructive),
            ),
          ),
      ],
    );
  }
}

class _LoginRow extends StatelessWidget {
  const _LoginRow({
    required this.held,
    required this.busy,
    required this.enabled,
    required this.onTap,
    required this.onSignOut,
  });

  final HeldSession held;
  final bool busy;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final session = held.session;
    final who = session.displayName?.trim().isNotEmpty == true
        ? session.displayName!.trim()
        : (session.email.isEmpty ? 'Login' : session.email);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              held.active ? LucideIcons.circleCheck : LucideIcons.circleUser,
              size: 20,
              color: held.active ? scheme.primary : scheme.mutedForeground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p,
                  ),
                  Text(
                    _brainName(session),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted,
                  ),
                  if (session.needsSignIn)
                    Text(
                      'Signed out. Tap to sign in again.',
                      style: theme.textTheme.small.copyWith(
                        color: scheme.destructive,
                      ),
                    )
                  else if (held.active)
                    Text('In use', style: theme.textTheme.small),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: enabled ? onSignOut : null,
              child: Text(busy ? 'Working…' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

/// What to call a login's brain: its site name once known, else its host.
String _brainName(Session session) {
  final site = session.siteName?.trim();
  if (site != null && site.isNotEmpty) return site;
  return Uri.tryParse(session.baseUrl)?.host ?? session.baseUrl;
}

/// The quick switch: the same list in a bottom sheet, one tap from home.
class QuickSwitchSheet extends ConsumerWidget {
  const QuickSwitchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (_) => const QuickSwitchSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final held = ref.watch(heldSessionsProvider).value ?? const [];

    return ShadSheet(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The drawer's first part: which workspace the phone is in.
            WorkspaceSwitcher(
              onSwitched: () => Navigator.of(context).maybePop(),
            ),
            Text('Switch login', style: theme.textTheme.h4),
            const SizedBox(height: 12),
            HeldLoginsList(
              held: held,
              onSwitched: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ShadButton.outline(
                leading: const Icon(LucideIcons.plus, size: 16),
                onPressed: () {
                  Navigator.of(context).maybePop();
                  ref.read(sessionControllerProvider.notifier).startAddLogin();
                },
                child: const Text('Add login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
