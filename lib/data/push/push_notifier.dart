import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'local_notifications.dart';
import 'notification_tap.dart';
import 'push_decryptor.dart';
import 'push_text.dart';

const _channelId = 'mantle_messages';
const _channelName = 'Messages';

/// Android push display. Decrypts an FCM **data** message's sealed `ct` and
/// posts a local notification (data messages don't auto-display). Shared by the
/// foreground listener and the background isolate handler.
///
/// Uses the app-wide shared plugin (local_notifications.dart) — one init and
/// one tap handler for push display AND event alarms, so neither feature's
/// `initialize` clobbers the other's callback.
class PushNotifier {
  PushNotifier._();

  static FlutterLocalNotificationsPlugin get _plugin =>
      localNotificationsPlugin;
  static bool _channelReady = false;

  static Future<void> _ensureInit() async {
    await ensureLocalNotificationsInit();
    if (_channelReady) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(_channelId, _channelName, importance: Importance.high),
        );
    _channelReady = true;
  }

  /// If the app was cold-launched by tapping a notification (a push OR an
  /// event alarm), surface its deep link. Call once at startup (Android).
  static Future<void> consumeLaunchDeepLink() async {
    await _ensureInit();
    await consumeLocalNotificationLaunchDeepLink();
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

    final text = pushNotificationText(payload);
    // The tap needs the item and the login the push names, not just its
    // link: they ride in the local notification's payload.
    final tap = NotificationTap.parse(payload);
    await showPlain(
      title: text.title,
      body: text.body,
      payload: tap?.toPayload(),
    );
  }

  /// Show a plaintext notification — used by the **direct connection** path
  /// (no-Google Android), where the message arrives over the user's own TLS SSE
  /// stream, so there's nothing to decrypt.
  ///
  /// [payload] is what a tap hands back ([NotificationTap.parse] reads it):
  /// a JSON tap, or a bare in-app path.
  static Future<void> showPlain({required String title, required String body, String? payload}) async {
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
      payload: payload,
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
