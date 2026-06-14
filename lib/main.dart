import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/lifecycle/app_lifecycle.dart';
import 'data/push/push_notifier.dart';
import 'features/settings/theme_mode_controller.dart';
import 'routing/app_router.dart';
import 'theme/mantle_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android push is FCM: init Firebase + register the data-message handlers.
  // iOS uses raw APNs + the Notification Service Extension (no Firebase).
  if (Platform.isAndroid) {
    await setupAndroidPush();
  }
  runApp(const ProviderScope(child: MantleCompanionApp()));
}

/// Root of the app. Uses [ShadApp.router] (the shadcn app type) rather than
/// `MaterialApp`, so no Material design language is pulled in. Theme mode comes
/// from [themeModeControllerProvider]; navigation + the auth gate come from
/// [goRouterProvider]. The palette is Mantle's Clean Slate theme.
///
/// Stateful so it can observe app lifecycle and feed [appLifecycleProvider] —
/// the live chat SSE stream pauses while backgrounded and reconnects on resume.
class MantleCompanionApp extends ConsumerStatefulWidget {
  const MantleCompanionApp({super.key});

  @override
  ConsumerState<MantleCompanionApp> createState() => _MantleCompanionAppState();
}

class _MantleCompanionAppState extends ConsumerState<MantleCompanionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).set(state);
  }

  @override
  Widget build(BuildContext context) {
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
