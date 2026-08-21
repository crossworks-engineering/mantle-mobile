import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/lifecycle/app_lifecycle.dart';
import 'data/push/deep_link.dart';
import 'data/push/push_notifier.dart';
import 'features/events/events_controller.dart';
import 'features/settings/color_theme_controller.dart';
import 'features/settings/random_theme_controller.dart';
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
  // Listen for notification-tap deep links (iOS over the mantle/push channel;
  // Android via push_notifier). The root widget routes on each link.
  await DeepLinkRouter.instance.start();
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
    DeepLinkRouter.instance.pending.addListener(_onDeepLink);
    // A cold-launch tap may have queued a link before this listener attached.
    _onDeepLink();
  }

  @override
  void dispose() {
    DeepLinkRouter.instance.pending.removeListener(_onDeepLink);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Navigate to a tapped notification's deep link, then clear it. The router's
  /// auth redirect handles the not-logged-in case (it bounces to /login).
  void _onDeepLink() {
    final link = DeepLinkRouter.instance.pending.value;
    if (link == null) return;
    DeepLinkRouter.instance.pending.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(goRouterProvider).go(link);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appLifecycleProvider.notifier).set(state);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode =
        ref.watch(themeModeControllerProvider).value ?? ThemeMode.system;
    final themeId =
        ref.watch(colorThemeControllerProvider).value ?? MantleTheme.defaultId;
    // Activate random-rotation (side-effect-only provider; ignores the value).
    ref.watch(randomThemeSchedulerProvider);
    // Keep device event-alarms synced on login + every foreground resume —
    // an event added from the web or by the assistant still rings here.
    ref.watch(eventAlarmSyncProvider);
    final router = ref.watch(goRouterProvider);

    // MantleColors sits above ShadApp so every route can resolve the active
    // theme's chart ramp (the markdown renderer uses it).
    return MantleColors(
      def: MantleTheme.defFor(themeId),
      child: ShadApp.router(
        title: 'Jackdaw',
        themeMode: themeMode,
        theme: MantleTheme.light(themeId),
        darkTheme: MantleTheme.dark(themeId),
        routerConfig: router,
      ),
    );
  }
}
