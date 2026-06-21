import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/mantle_header.dart';
import '../auth/session_controller.dart';

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
                  Text('Account', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton.outline(
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).signOut(),
                      leading: const Icon(LucideIcons.logOut, size: 16),
                      child: const Text('Sign out'),
                    ),
                  ),
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
