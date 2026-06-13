import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shadcn_ui/shadcn_ui.dart';

void main() => runApp(const MantleCompanionApp());

/// Root of the app. Uses [ShadApp] (the shadcn app type) rather than
/// `MaterialApp`, so no Material design language is pulled in — the whole
/// surface is themed with shadcn/ui's Tailwind-style design tokens.
class MantleCompanionApp extends StatefulWidget {
  const MantleCompanionApp({super.key});

  @override
  State<MantleCompanionApp> createState() => _MantleCompanionAppState();
}

class _MantleCompanionAppState extends State<MantleCompanionApp> {
  // Follows the OS by default; the in-app toggle flips between light/dark.
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Mantle Companion',
      themeMode: _themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      ),
      home: HomeScreen(onToggleTheme: _toggleTheme),
    );
  }
}

/// Placeholder landing screen — exists to prove the theme system renders
/// natively in light/dark with no Material widgets. Real features (chat,
/// notifications, message-attached location) replace this.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onToggleTheme});

  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
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
                    onPressed: onToggleTheme,
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
