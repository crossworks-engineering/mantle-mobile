import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Surfaces notification-tap deep links into the app so a tap can jump to the
/// right screen (e.g. an approval push → `/pending`, a message → `/chat/<slug>`).
///
/// Two arrival paths feed one [pending] notifier:
///   - iOS: native taps come over the `mantle/push` MethodChannel — the
///     AppDelegate invokes `deepLink` with the tapped link, and a cold-launch
///     tap is fetched once via `getInitialDeepLink` (the tap fires before Dart
///     attaches its handler).
///   - Android: the SHARED flutter_local_notifications tap callback + app-
///     launch details feed [offer], with payload→route translation for event
///     alarms (see local_notifications.dart).
///
/// The root widget listens to [pending] and routes via go_router, then clears
/// it. Singleton so the platform channel handler and the Android notifier share
/// one queue.
class DeepLinkRouter {
  DeepLinkRouter._();

  static final DeepLinkRouter instance = DeepLinkRouter._();

  static const _channel = MethodChannel('mantle/push');

  /// The most recent un-consumed deep link, or null. The root widget watches
  /// this, navigates, and resets it to null.
  final ValueNotifier<String?> pending = ValueNotifier<String?>(null);

  bool _started = false;

  /// Begin listening for taps. Idempotent — safe to call once at startup.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Warm (foreground/background) taps: native → Dart over the shared channel.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink') {
        offer(call.arguments as String?);
      }
      return null;
    });

    // Cold launch via a notification tap: the native side stored the link
    // before Dart was ready, so pull it once now.
    try {
      final initial = await _channel.invokeMethod<String>('getInitialDeepLink');
      offer(initial);
    } on PlatformException {
      /* no initial link */
    } on MissingPluginException {
      /* not iOS / channel not wired (e.g. unit tests) */
    }
  }

  /// Queue a deep link for the root widget to consume. Ignores null/empty.
  void offer(String? link) {
    if (link != null && link.isNotEmpty) pending.value = link;
  }
}
