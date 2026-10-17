import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
// ThemeMode is a Flutter enum that only ships via material.dart — import just
// the enum, not Material's widgets. The UI itself is built entirely on ShadApp.
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/lifecycle/app_lifecycle.dart';
import 'data/push/deep_link.dart';
import 'data/push/local_notifications.dart';
import 'data/push/push_notifier.dart';
import 'features/auth/session_identity.dart';
import 'features/events/events_controller.dart';
import 'features/settings/brain_appearance_sync.dart';
import 'features/settings/color_theme_controller.dart';
import 'features/settings/push/direct_push_controller.dart';
import 'features/settings/random_theme_controller.dart';
import 'features/settings/theme_mode_controller.dart';
import 'routing/app_router.dart';
import 'routing/notification_router.dart';
import 'theme/mantle_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android push is FCM: init Firebase + register the data-message handlers.
  // iOS uses raw APNs + the Notification Service Extension (no Firebase).
  if (Platform.isAndroid) {
    await setupAndroidPush();
  } else {
    // An event alarm tapped while the app was closed: the local-notification
    // plugin holds it (Android's comes through setupAndroidPush).
    await consumeLocalNotificationLaunchDeepLink();
  }
  // Listen for notification taps (iOS pushes over the mantle/push channel;
  // local notifications on both). The root widget routes on each tap.
  await DeepLinkRouter.instance.start();
  runApp(const ProviderScope(child: JackdawApp()));
}

/// Root of the app. Uses [ShadApp.router] (the shadcn app type) rather than
/// `MaterialApp`, so no Material design language is pulled in. Theme mode comes
/// from [themeModeControllerProvider]; navigation + the auth gate come from
/// [goRouterProvider]. The palette is Mantle's Clean Slate theme.
///
/// Stateful so it can observe app lifecycle and feed [appLifecycleProvider] —
/// the live chat SSE stream pauses while backgrounded and reconnects on resume.
class JackdawApp extends ConsumerStatefulWidget {
  const JackdawApp({super.key});

  @override
  ConsumerState<JackdawApp> createState() => _JackdawAppState();
}

class _JackdawAppState extends ConsumerState<JackdawApp>
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

  /// Act on a tapped notification, then clear it: the router picks the login
  /// it was for and opens its screen once the session has settled.
  void _onDeepLink() {
    final tap = DeepLinkRouter.instance.pending.value;
    if (tap == null) return;
    DeepLinkRouter.instance.pending.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationRouterProvider).open(tap);
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
    // Keep the Android direct connection on the login in use, when wanted.
    ref.watch(directPushFollowProvider);
    // Follow the brain's colour theme (unless this phone picked its own).
    ref.watch(brainAppearanceSyncProvider);
    // Learn which (brain, login) the login in use is, so a push names it.
    ref.watch(brainIdentitySyncProvider);
    final router = ref.watch(goRouterProvider);

    // MantleColors sits above ShadApp so every route can resolve the active
    // theme's chart ramp (the markdown renderer uses it).
    return MantleColors(
      def: MantleTheme.defFor(themeId),
      child: ShadApp.router(
        title: 'MantleOS',
        themeMode: themeMode,
        theme: MantleTheme.light(themeId),
        darkTheme: MantleTheme.dark(themeId),
        routerConfig: router,
      ),
    );
  }
}
