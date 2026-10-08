import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'deep_link.dart';

export 'notification_tap.dart' show kEventAlarmPayloadPrefix;

/// ONE local-notifications bootstrap for the whole app.
///
/// Both push display (PushNotifier, Android FCM data messages) and event
/// alarms (EventAlarms, both platforms) post through flutter_local_notifications
/// — which is a singleton with a SINGLE tap callback. Two features calling
/// `initialize` with their own handlers would silently overwrite each other
/// (last init wins), so they both route through here instead: one init, one
/// tap handler, one payload→tap translation ([NotificationTap.parse]).
final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _inited = false;

/// Initialize the shared plugin (idempotent). Android + iOS settings are both
/// registered so whichever feature initializes first, the other still works.
/// Permission prompts are NOT fired here — each feature requests what it
/// needs (push setup on enroll, EventAlarms.requestPermissions on first
/// events visit).
Future<void> ensureLocalNotificationsInit() async {
  if (_inited) return;
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await localNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: android, iOS: darwin),
    onDidReceiveNotificationResponse: (response) =>
        DeepLinkRouter.instance.offer(response.payload),
  );
  _inited = true;
}

/// If the app was cold-launched by tapping any local notification (a push or
/// an event alarm), surface its deep link. Call once at startup.
Future<void> consumeLocalNotificationLaunchDeepLink() async {
  await ensureLocalNotificationsInit();
  final details =
      await localNotificationsPlugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp ?? false) {
    DeepLinkRouter.instance.offer(details?.notificationResponse?.payload);
  }
}
