import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../push/local_notifications.dart';
import 'events_models.dart';

const _channelId = 'mantle_events';
const _channelName = 'Event alarms';

/// Real, OS-scheduled event alarms. Unlike the responder's push reminder
/// (which needs the relay, the network, and an enrolled device), these are
/// `zonedSchedule`d local notifications: Android's AlarmManager / iOS's
/// UNUserNotificationCenter fire them at the exact instant even with the app
/// killed or the phone offline. Boot persistence comes from the manifest's
/// ScheduledNotificationBootReceiver.
///
/// [sync] reconciles the OS's pending schedule against the latest upcoming
/// events after every fetch/mutation: per event, an alarm at `startsAt` plus
/// a heads-up at `remindAt` when a lead time is set (mirroring the server
/// worker's fields), skipping done-tagged and past entries. Recurring events
/// carry only their NEXT occurrence (the server rolls the row forward), so
/// each app open re-arms the following one.
class EventAlarms {
  EventAlarms._();

  /// The app-wide shared plugin (see local_notifications.dart — one init, one
  /// tap handler for push display AND alarms). Tests swap in a mock through
  /// [pluginForTesting]; the shared bootstrap is skipped for it.
  static FlutterLocalNotificationsPlugin get _plugin =>
      pluginForTesting ?? localNotificationsPlugin;

  @visibleForTesting
  static FlutterLocalNotificationsPlugin? pluginForTesting;

  static bool _channelReady = false;
  static bool _exactAllowed = false;

  static const _payloadPrefix = kEventAlarmPayloadPrefix;

  /// Forget the one-time init so a test starts clean.
  @visibleForTesting
  static void resetForTesting() {
    _channelReady = false;
    _exactAllowed = false;
  }

  static Future<void> _ensureInit() async {
    if (pluginForTesting == null) await ensureLocalNotificationsInit();
    if (_channelReady) return;
    tzdata.initializeTimeZones();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Alarms for your Mantle events',
        importance: Importance.max,
      ),
    );
    // Prompt-free capability check — the background sync (app root) may run
    // before the events screen ever requests the exact-alarm grant.
    _exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    _channelReady = true;
  }

  /// Ask for what alarms need. iOS: notification permission (idempotent —
  /// push setup usually granted it). Android: POST_NOTIFICATIONS (13+ — may
  /// never have been granted if push was skipped or the no-Google path is in
  /// use) AND the exact-alarm special permission (12+; falls back to inexact
  /// when declined). Call when the events screen first opens.
  static Future<void> requestPermissions() async {
    await _ensureInit();
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      _exactAllowed =
          await android?.canScheduleExactNotifications() ?? false;
      if (!_exactAllowed) {
        await android?.requestExactAlarmsPermission();
        _exactAllowed =
            await android?.canScheduleExactNotifications() ?? false;
      }
    }
  }

  /// What SHOULD be scheduled for [events] at [now]: payload → the event,
  /// the instant it fires and its kind (`start` or `remind`). Done events
  /// and past instants are left out; a reminder is only planned with a lead
  /// time, a future instant, and one that differs from the start. Pure, so
  /// the rule is testable without a plugin.
  static Map<String, ({EventRow event, DateTime at, String kind})>
      plannedAlarms(List<EventRow> events, {DateTime? now}) {
    final n = (now ?? DateTime.now()).toUtc();
    final wanted = <String, ({EventRow event, DateTime at, String kind})>{};
    for (final e in events) {
      if (e.done) continue;
      if (e.startsAt.isAfter(n)) {
        wanted[payloadFor(e.id, e.startsAt, 'start')] =
            (event: e, at: e.startsAt, kind: 'start');
      }
      final remind = e.remindAt;
      if (e.remindMinutesBefore > 0 &&
          remind != null &&
          remind.isAfter(n) &&
          remind != e.startsAt) {
        wanted[payloadFor(e.id, remind, 'remind')] =
            (event: e, at: remind, kind: 'remind');
      }
    }
    return wanted;
  }

  /// Reconcile the OS's scheduled alarms with [events] (the latest upcoming
  /// window). Cancels stale schedules (event deleted/moved/marked done),
  /// keeps unchanged ones, schedules the rest. Never throws — alarms are
  /// best-effort decoration over the durable server reminder.
  static Future<void> sync(List<EventRow> events) async {
    try {
      await _ensureInit();
      final wanted = plannedAlarms(events);

      // What IS scheduled (ours only, recognized by the payload prefix).
      final pending = await _plugin.pendingNotificationRequests();
      final existing = <String>{};
      for (final p in pending) {
        final payload = p.payload;
        if (payload == null || !payload.startsWith(_payloadPrefix)) continue;
        if (wanted.containsKey(payload)) {
          existing.add(payload); // still correct — keep it
        } else {
          await _plugin.cancel(id: p.id); // stale — event gone/moved/done
        }
      }

      for (final entry in wanted.entries) {
        if (existing.contains(entry.key)) continue;
        final plan = entry.value;
        await _schedule(entry.key, plan.event, plan.at, plan.kind);
      }
    } catch (_) {
      /* never let alarm bookkeeping break the caller */
    }
  }

  /// Cancel every alarm this app scheduled (recognised by the payload
  /// prefix). Used when a session ends: an alarm for the previous account's
  /// event must not ring for the next one. Never throws.
  static Future<void> cancelAll() async {
    try {
      await _ensureInit();
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload;
        if (payload != null && payload.startsWith(_payloadPrefix)) {
          await _plugin.cancel(id: p.id);
        }
      }
    } catch (_) {
      /* best-effort, like sync */
    }
  }

  static Future<void> _schedule(
    String payload,
    EventRow event,
    DateTime at,
    String kind,
  ) async {
    final title = kind == 'remind'
        ? 'Upcoming: ${event.title}'
        : '⏰ ${event.title}';
    final body = [
      if (kind == 'remind') 'Starts in ${event.remindMinutesBefore} min',
      if (event.location != null && event.location!.isNotEmpty)
        event.location!,
    ].join(' · ');
    await _plugin.zonedSchedule(
      id: _idFor(payload),
      title: title,
      body: body.isEmpty ? null : body,
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: _exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Payload identifies one (event, instant, kind) schedule — a moved event
  /// produces a different payload, so reconcile treats it as new + stale.
  static String payloadFor(String eventId, DateTime at, String kind) =>
      '$_payloadPrefix$eventId:${at.toUtc().millisecondsSinceEpoch}:$kind';

  /// Stable 31-bit notification id from the payload (FNV-1a — deterministic
  /// across runs, unlike String.hashCode).
  static int _idFor(String payload) {
    var hash = 0x811c9dc5;
    for (final unit in payload.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }
}
