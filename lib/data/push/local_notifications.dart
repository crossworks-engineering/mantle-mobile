import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'deep_link.dart';

/// Prefix identifying event-alarm payloads (`event-alarm:<id>:<ms>:<kind>`).
/// Lives here (not in event_alarms.dart) because the shared tap handler needs
/// it to translate payloads and the alarm service needs it to mint them.
const String kEventAlarmPayloadPrefix = 'event-alarm:';

/// ONE local-notifications bootstrap for the whole app.
///
/// Both push display (PushNotifier, Android FCM data messages) and event
/// alarms (EventAlarms, both platforms) post through flutter_local_notifications
/// — which is a singleton with a SINGLE tap callback. Two features calling
/// `initialize` with their own handlers would silently overwrite each other
/// (last init wins), so they both route through here instead: one init, one
/// tap handler, one payload→deep-link translation.
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
        DeepLinkRouter.instance.offer(deepLinkForPayload(response.payload)),
  );
  _inited = true;
}

/// A notification payload → the in-app route to open. Push payloads carry the
/// route itself (`/chat/<slug>`, `/pending`); event-alarm payloads carry the
/// schedule key (`event-alarm:<id>:<ms>:<kind>`), which maps to the events
/// screen. Null when there's nothing to route.
String? deepLinkForPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  if (payload.startsWith(kEventAlarmPayloadPrefix)) return '/events';
  return payload;
}

/// If the app was cold-launched by tapping any local notification (a push or
/// an event alarm), surface its deep link. Call once at startup.
Future<void> consumeLocalNotificationLaunchDeepLink() async {
  await ensureLocalNotificationsInit();
  final details =
      await localNotificationsPlugin.getNotificationAppLaunchDetails();
  if (details?.didNotificationLaunchApp ?? false) {
    DeepLinkRouter.instance.offer(
      deepLinkForPayload(details?.notificationResponse?.payload),
    );
  }
}
