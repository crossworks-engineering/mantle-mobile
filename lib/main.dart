import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'features/settings/theme_mode_controller.dart';
import 'routing/app_router.dart';
import 'theme/mantle_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MantleCompanionApp()));
}

/// Root of the app. Uses [ShadApp.router] (the shadcn app type) rather than
/// `MaterialApp`, so no Material design language is pulled in. Theme mode comes
/// from [themeModeControllerProvider]; navigation + the auth gate come from
/// [goRouterProvider]. The palette is Mantle's Clean Slate theme.
class MantleCompanionApp extends ConsumerWidget {
  const MantleCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final router = ref.watch(goRouterProvider);

    return ShadApp.router(
      title: 'Mantle Companion',
      themeMode: themeMode,
      theme: MantleTheme.light(),
      darkTheme: MantleTheme.dark(),
      routerConfig: router,
    );
  }
}
