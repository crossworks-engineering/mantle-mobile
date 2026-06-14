import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../widgets/mantle_header.dart';
import '../auth/session_controller.dart';
import 'theme_mode_controller.dart';

/// Settings: appearance (theme) and account. Profile/account management beyond
/// sign-out is a TODO.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final mode = ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

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
                  ShadCard(
                    child: Column(
                      children: [
                        for (final option in _themeOptions)
                          _ThemeRow(
                            theme: theme,
                            label: option.label,
                            icon: option.icon,
                            selected: mode == option.mode,
                            onTap: () => ref
                                .read(themeModeControllerProvider.notifier)
                                .setMode(option.mode),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Notifications', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadCard(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.push('/settings/notifications'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(LucideIcons.bell, size: 18, color: scheme.mutedForeground),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('Push notifications', style: theme.textTheme.p),
                            ),
                            Icon(LucideIcons.chevronRight, size: 18, color: scheme.mutedForeground),
                          ],
                        ),
                      ),
                    ),
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

class _ThemeOption {
  const _ThemeOption(this.mode, this.label, this.icon);
  final ThemeMode mode;
  final String label;
  final IconData icon;
}

const _themeOptions = [
  _ThemeOption(ThemeMode.system, 'System', LucideIcons.sunMoon),
  _ThemeOption(ThemeMode.light, 'Light', LucideIcons.sun),
  _ThemeOption(ThemeMode.dark, 'Dark', LucideIcons.moon),
];

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final ShadThemeData theme;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.mutedForeground),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.textTheme.p)),
            if (selected)
              Icon(LucideIcons.check, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
