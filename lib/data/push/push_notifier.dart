import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'deep_link.dart';
import 'push_decryptor.dart';

const _channelId = 'mantle_messages';
const _channelName = 'Messages';

/// Android push display. Decrypts an FCM **data** message's sealed `ct` and
/// posts a local notification (data messages don't auto-display). Shared by the
/// foreground listener and the background isolate handler.
class PushNotifier {
  PushNotifier._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _ensureInit() async {
    if (_inited) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onTap,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName, importance: Importance.high),
        );
    _inited = true;
  }

  /// A tapped notification's payload is its deep link (set in [showPlain]).
  /// Route to it via the shared [DeepLinkRouter].
  static void _onTap(NotificationResponse response) {
    DeepLinkRouter.instance.offer(response.payload);
  }

  /// If the app was cold-launched by tapping a notification, surface that
  /// notification's deep link. Call once at startup (Android).
  static Future<void> consumeLaunchDeepLink() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      DeepLinkRouter.instance.offer(details?.notificationResponse?.payload);
    }
  }

  /// Decrypt an FCM data payload's sealed `ct` and show it. No-ops if there's no
  /// `ct` or it can't be opened (best-effort — the app reconciles over SSE/REST
  /// on next open).
  static Future<void> showFromData(Map<String, dynamic> data) async {
    final ct = data['ct'];
    if (ct is! String || ct.isEmpty) return;

    final decryptor = await PushDecryptor.create();
    final payload = await decryptor.open(ct);
    if (payload == null) return;

    await showPlain(
      title: (payload['t'] as String?) ?? 'Mantle',
      body: (payload['b'] as String?) ?? 'You have a new message.',
      deepLink: payload['deepLink'] as String?,
    );
  }

  /// Show a plaintext notification — used by the **direct connection** path
  /// (no-Google Android), where the message arrives over the user's own TLS SSE
  /// stream, so there's nothing to decrypt.
  static Future<void> showPlain({required String title, required String body, String? deepLink}) async {
    await _ensureInit();
    await _plugin.show(
      id: title.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: deepLink,
    );
  }
}

/// FCM background handler — runs in its own isolate, so it re-inits Firebase.
/// Must be top-level + AOT-entry annotated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotifier.showFromData(message.data);
}

/// Wire up Android FCM (called only on Android from main): init Firebase,
/// register the background handler, and surface foreground data messages.
Future<void> setupAndroidPush() async {
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((m) => PushNotifier.showFromData(m.data));
  // Cold-launch via a notification tap: surface its deep link for routing.
  await PushNotifier.consumeLaunchDeepLink();
}
