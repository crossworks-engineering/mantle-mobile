import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/mantle_header.dart';
import '../auth/session_controller.dart';
import 'location_controller.dart';

/// Settings: appearance (theme), notifications, and account. Profile/account
/// management beyond sign-out is a TODO.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Settings', wordmark: false),
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
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Appearance', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  _NavRow(
                    theme: theme,
                    icon: LucideIcons.palette,
                    label: 'Theme & appearance',
                    onTap: () => context.push('/settings/appearance'),
                  ),
                  const SizedBox(height: 24),
                  Text('Notifications', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  _NavRow(
                    theme: theme,
                    icon: LucideIcons.bell,
                    label: 'Push notifications',
                    onTap: () => context.push('/settings/notifications'),
                  ),
                  const SizedBox(height: 24),
                  Text('Privacy', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  _LocationToggle(theme: theme),
                  const SizedBox(height: 24),
                  Text('Account', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  _SignOutRow(theme: theme),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Account & profile settings coming soon.',
                      style: theme.textTheme.muted,
                    ),
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

/// A card that navigates to a subscreen — icon, label, chevron.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ShadThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return ShadCard(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.mutedForeground),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.p)),
              Icon(LucideIcons.chevronRight,
                  size: 18, color: scheme.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sign out, behind a confirm: it ends the session on this device and wipes
/// everything cached for the account (messages, queued turns, push keys,
/// alarms). A failure to clear the token is the one thing that keeps the
/// session, and it is shown inline.
class _SignOutRow extends ConsumerStatefulWidget {
  const _SignOutRow({required this.theme});

  final ShadThemeData theme;

  @override
  ConsumerState<_SignOutRow> createState() => _SignOutRowState();
}

class _SignOutRowState extends ConsumerState<_SignOutRow> {
  bool _busy = false;
  String? _error;

  Future<void> _signOut() async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Sign out?'),
        description: const Text(
          'This device forgets your session: cached messages, unsent '
          'messages, push keys and event alarms are all removed.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).signOut();
      // The router redirects to /login; this widget is gone.
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = "Couldn't clear the session on this device. Try again.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ShadButton.outline(
            onPressed: _busy ? null : _signOut,
            leading: const Icon(LucideIcons.logOut, size: 16),
            child: Text(_busy ? 'Signing out…' : 'Sign out'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructive,
            ),
          ),
        ],
      ],
    );
  }
}

/// Opt-in toggle for attaching device location to messages. Enabling it prompts
/// for the OS permission; a refusal shows an inline message and leaves it off.
class _LocationToggle extends ConsumerWidget {
  const _LocationToggle({required this.theme});

  final ShadThemeData theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = theme.colorScheme;
    final state = ref.watch(locationControllerProvider);
    final on = state.value ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShadCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(LucideIcons.mapPin, size: 18, color: scheme.mutedForeground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Share location with messages',
                      style: theme.textTheme.p),
                ),
                ShadSwitch(
                  value: on,
                  onChanged: state.isLoading
                      ? null
                      : (v) => ref
                          .read(locationControllerProvider.notifier)
                          .setEnabled(v),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Text(
            state.hasError
                ? state.error.toString()
                : 'Attaches your location to each message so your assistant '
                    'knows where a request is coming from. When-in-use only; '
                    'turn off any time.',
            style: theme.textTheme.muted.copyWith(
              color: state.hasError ? scheme.destructive : null,
            ),
          ),
        ),
      ],
    );
  }
}
