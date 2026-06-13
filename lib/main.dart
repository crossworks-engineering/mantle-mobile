import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/settings/theme_mode_controller.dart';
import 'theme/mantle_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MantleCompanionApp()));
}

/// Root of the app. Uses [ShadApp] (the shadcn app type) rather than
/// `MaterialApp`, so no Material design language is pulled in. Theme mode comes
/// from [themeModeControllerProvider] (persisted via Drift); the palette is
/// Mantle's Clean Slate theme.
class MantleCompanionApp extends ConsumerWidget {
  const MantleCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fall back to system while the persisted value is still loading.
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;

    return ShadApp(
      title: 'Mantle Companion',
      themeMode: themeMode,
      theme: MantleTheme.light(),
      darkTheme: MantleTheme.dark(),
      home: const HomeScreen(),
    );
  }
}

/// Placeholder landing screen — exists to prove the stack renders natively and
/// that theme changes persist. Real features (chat, notifications,
/// message-attached location) replace this.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);

    return Container(
      color: theme.colorScheme.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Mantle Companion', style: theme.textTheme.h3),
                  ShadButton.ghost(
                    onPressed: () => ref
                        .read(themeModeControllerProvider.notifier)
                        .cycle(),
                    child: const Text('Theme'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chat, notifications, and location — for your Mantle assistant.',
                style: theme.textTheme.muted,
              ),
              const SizedBox(height: 24),
              ShadCard(
                title: Text('Hello 👋', style: theme.textTheme.h4),
                description: const Text(
                  'Your shadcn-themed starting point. No Material in sight.',
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ShadButton(
                        onPressed: () {},
                        child: const Text('Start a chat'),
                      ),
                      ShadButton.outline(
                        onPressed: () {},
                        child: const Text('Share location'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'v0.0.1 · open source',
                  style: theme.textTheme.small,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
