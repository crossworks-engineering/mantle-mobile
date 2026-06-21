import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../theme/mantle_theme.dart';
import '../../widgets/mantle_header.dart';
import 'color_theme_controller.dart';
import 'random_theme_controller.dart';
import 'theme_mode_controller.dart';

/// Appearance settings: light/dark mode, the color-theme picker (all themes
/// ported from the web app), and the optional random-rotation mode.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;

    final mode = ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final selectedId =
        ref.watch(colorThemeControllerProvider).value ?? MantleTheme.defaultId;
    final random = ref.watch(randomThemeControllerProvider).value;
    final randomOn = random?.enabled ?? false;

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Appearance', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft,
                    size: 20, color: scheme.primaryForeground),
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Mode', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadCard(
                    child: Column(
                      children: [
                        for (final option in _modeOptions)
                          _Tappable(
                            onTap: () => ref
                                .read(themeModeControllerProvider.notifier)
                                .setMode(option.mode),
                            child: Row(
                              children: [
                                Icon(option.icon,
                                    size: 18, color: scheme.mutedForeground),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(option.label,
                                        style: theme.textTheme.p)),
                                if (mode == option.mode)
                                  Icon(LucideIcons.check,
                                      size: 18, color: scheme.primary),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Random theme', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadCard(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Icon(LucideIcons.shuffle,
                                  size: 18, color: scheme.mutedForeground),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text('Shuffle themes',
                                    style: theme.textTheme.p),
                              ),
                              ShadSwitch(
                                value: randomOn,
                                onChanged: random == null
                                    ? null
                                    : (v) => ref
                                        .read(randomThemeControllerProvider
                                            .notifier)
                                        .setEnabled(v),
                              ),
                            ],
                          ),
                        ),
                        if (randomOn && random != null) ...[
                          Container(height: 1, color: scheme.border),
                          for (final interval in kRandomIntervals)
                            _Tappable(
                              onTap: () => ref
                                  .read(randomThemeControllerProvider.notifier)
                                  .setInterval(interval),
                              child: Row(
                                children: [
                                  const SizedBox(width: 30),
                                  Expanded(
                                    child: Text(_intervalLabel(interval),
                                        style: theme.textTheme.p),
                                  ),
                                  if (random.interval == interval)
                                    Icon(LucideIcons.check,
                                        size: 18, color: scheme.primary),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Theme', style: theme.textTheme.small),
                  const SizedBox(height: 8),
                  ShadCard(
                    child: Column(
                      children: [
                        for (final def in kMantleThemes)
                          _Tappable(
                            onTap: () {
                              // A manual pick turns rotation off so it sticks.
                              if (randomOn) {
                                ref
                                    .read(randomThemeControllerProvider.notifier)
                                    .setEnabled(false);
                              }
                              ref
                                  .read(colorThemeControllerProvider.notifier)
                                  .select(def.id);
                            },
                            child: Row(
                              children: [
                                _Swatches(colors: def.swatches),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(def.label,
                                        style: theme.textTheme.p)),
                                if (def.id == selectedId)
                                  Icon(LucideIcons.check,
                                      size: 18, color: scheme.primary),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption {
  const _ModeOption(this.mode, this.label, this.icon);
  final ThemeMode mode;
  final String label;
  final IconData icon;
}

const _modeOptions = [
  _ModeOption(ThemeMode.system, 'System', LucideIcons.sunMoon),
  _ModeOption(ThemeMode.light, 'Light', LucideIcons.sun),
  _ModeOption(ThemeMode.dark, 'Dark', LucideIcons.moon),
];

String _intervalLabel(Duration d) {
  if (d.inDays >= 7) return 'Every week';
  if (d.inDays >= 1) return 'Every day';
  if (d.inHours == 1) return 'Every hour';
  return 'Every ${d.inHours} hours';
}

/// Three small preview swatches for a theme row.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors});
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final border = ShadTheme.of(context).colorScheme.border;
    return SizedBox(
      width: 44,
      height: 20,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 12.0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A vertically-padded, full-width tappable row — matches the settings rows.
class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: child,
      ),
    );
  }
}
