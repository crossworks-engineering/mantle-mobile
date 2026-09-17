import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/app_version.dart';
import '../../data/db/database_provider.dart';
import '../../data/server/server_config.dart';
import '../../data/server/server_version.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mantle_header.dart';
import '../auth/session_controller.dart';
import '../chat/chat_controller.dart';
import 'location_controller.dart';

/// Settings: appearance, notifications, privacy, the account (who and where,
/// with sign out and change server), and storage (clear the on-device
/// cache).
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
                  _IdentityCard(theme: theme),
                  const SizedBox(height: 12),
                  _SignOutRow(theme: theme),
                  const SizedBox(height: 24),
                  Text('Storage', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  _ClearCacheRow(theme: theme),
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

/// Who and where: the server address, the signed-in email, this build and
/// the server's version. Facts, not controls; the one action is "Change
/// server" under the address, which signs out first and lands on setup.
class _IdentityCard extends ConsumerStatefulWidget {
  const _IdentityCard({required this.theme});

  final ShadThemeData theme;

  @override
  ConsumerState<_IdentityCard> createState() => _IdentityCardState();
}

class _IdentityCardState extends ConsumerState<_IdentityCard> {
  bool _busy = false;
  String? _error;

  Future<void> _changeServer() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Change server?',
      description: 'You are signed out of this server first: cached messages, '
          'unsent messages, push keys and event alarms are removed. Then you '
          'enter the new address.',
      action: 'Sign out and change',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionControllerProvider.notifier).changeServer();
      // The router moves to /setup; this widget is gone.
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
    final scheme = theme.colorScheme;
    final server = ref.watch(serverConfigProvider).value;
    final email = ref.watch(accountEmailProvider).value;
    final app = ref.watch(appVersionProvider).value;
    final mantle = ref.watch(serverVersionProvider);
    final mantleText = mantle.when(
      loading: () => 'Checking…',
      error: (_, _) => 'Unreachable',
      data: (v) => v == null ? 'Unreachable' : 'Mantle $v',
    );

    final divider = Container(height: 1, color: scheme.border);
    return ShadCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            theme: theme,
            icon: LucideIcons.server,
            label: 'Server',
            value: server ?? 'Not set',
            trailing: ShadButton.link(
              onPressed: _busy ? null : _changeServer,
              padding: EdgeInsets.zero,
              child: Text(_busy ? 'Signing out…' : 'Change server'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ),
          // A session signed in before the email was recorded has none to
          // show; the row appears from the next sign-in.
          if (email != null) ...[
            divider,
            _InfoRow(
              theme: theme,
              icon: LucideIcons.user,
              label: 'Signed in as',
              value: email,
            ),
          ],
          divider,
          _InfoRow(
            theme: theme,
            icon: LucideIcons.smartphone,
            label: 'App',
            value: app == null ? 'Jackdaw' : 'Jackdaw $app',
          ),
          divider,
          _InfoRow(
            theme: theme,
            icon: LucideIcons.brain,
            label: 'Server version',
            value: mantleText,
          ),
        ],
      ),
    );
  }
}

/// A label over a value, with an icon to the left; the value wraps rather
/// than truncates because a server address has to be readable in full.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final ShadThemeData theme;
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: scheme.mutedForeground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.muted),
                Text(value, style: theme.textTheme.p),
                if (trailing != null)
                  Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Clear what the app keeps on the device for this account: the saved
/// messages and the offline outbox. Settings and the session stay. Behind a
/// confirm because the outbox holds messages not yet delivered.
class _ClearCacheRow extends ConsumerStatefulWidget {
  const _ClearCacheRow({required this.theme});

  final ShadThemeData theme;

  @override
  ConsumerState<_ClearCacheRow> createState() => _ClearCacheRowState();
}

class _ClearCacheRowState extends ConsumerState<_ClearCacheRow> {
  bool _busy = false;
  String? _note;
  bool _failed = false;

  Future<void> _clear() async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Clear cache?',
      description: 'Removes the messages saved on this device and any unsent '
          'messages still waiting to go. Nothing on the server changes; '
          'threads reload from it.',
      action: 'Clear',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _note = null;
      _failed = false;
    });
    try {
      await ref.read(appDatabaseProvider).clearUserData();
      // Open threads hold the old rows in memory; make them reload.
      ref.invalidate(chatControllerProvider);
      if (mounted) setState(() => _note = 'Cache cleared.');
    } catch (_) {
      if (mounted) {
        setState(() {
          _note = "Couldn't clear the cache. Try again.";
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ShadButton.outline(
            onPressed: _busy ? null : _clear,
            leading: const Icon(LucideIcons.eraser, size: 16),
            child: Text(_busy ? 'Clearing…' : 'Clear cache'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Text(
            _note ?? 'Saved messages and the offline outbox. Your settings '
                'and sign-in stay.',
            style: theme.textTheme.muted.copyWith(
              color: _failed ? scheme.destructive : null,
            ),
          ),
        ),
      ],
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
    final confirmed = await confirmDestructive(
      context,
      title: 'Sign out?',
      description: 'This device forgets your session: cached messages, unsent '
          'messages, push keys and event alarms are all removed.',
      action: 'Sign out',
    );
    if (!confirmed || !mounted) return;
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
