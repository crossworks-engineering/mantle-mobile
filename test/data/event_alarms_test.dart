// EventAlarms: the planning rule is pure (which alarms an event list wants at
// a given instant); the reconcile against the OS's pending list is exercised
// with a mocked plugin — cancel only OUR stale ones, schedule only what is
// missing, and never throw.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/events/event_alarms.dart';
import 'package:jackdaw/data/events/events_models.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

EventRow _event(
  String id, {
  required DateTime startsAt,
  int lead = 0,
  bool done = false,
}) =>
    EventRow(
      id: id,
      title: id,
      body: '',
      startsAt: startsAt.toUtc(),
      endsAt: null,
      location: null,
      remindMinutesBefore: lead,
      remindAt: lead > 0
          ? startsAt.toUtc().subtract(Duration(minutes: lead))
          : null,
      recur: 'none',
      tags: done ? const [kEventDoneTag] : const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  final now = DateTime.utc(2026, 9, 17, 10);
  final soon = now.add(const Duration(hours: 2));

  setUpAll(() {
    tzdata.initializeTimeZones();
    registerFallbackValue(tz.TZDateTime.from(now, tz.UTC));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexact);
  });

  group('plannedAlarms', () {
    test('a future event wants a start alarm; with a lead, a reminder too',
        () {
      final plain = _event('a', startsAt: soon);
      final led = _event('b', startsAt: soon, lead: 15);
      final plan = EventAlarms.plannedAlarms([plain, led], now: now);
      expect(plan.keys, {
        EventAlarms.payloadFor('a', soon, 'start'),
        EventAlarms.payloadFor('b', soon, 'start'),
        EventAlarms.payloadFor(
            'b', soon.subtract(const Duration(minutes: 15)), 'remind'),
      });
      expect(plan[EventAlarms.payloadFor('b', soon, 'start')]!.kind, 'start');
    });

    test('done and past events want nothing', () {
      final plan = EventAlarms.plannedAlarms([
        _event('done', startsAt: soon, done: true),
        _event('past', startsAt: now.subtract(const Duration(hours: 1))),
      ], now: now);
      expect(plan, isEmpty);
    });

    test('a reminder whose instant has passed is dropped, the start stays',
        () {
      final inTen = now.add(const Duration(minutes: 10));
      final plan =
          EventAlarms.plannedAlarms([_event('x', startsAt: inTen, lead: 30)],
              now: now);
      expect(plan.keys.single, EventAlarms.payloadFor('x', inTen, 'start'));
    });

    test('a moved event gets a different payload', () {
      final a = EventAlarms.payloadFor('x', soon, 'start');
      final b = EventAlarms.payloadFor(
          'x', soon.add(const Duration(minutes: 1)), 'start');
      expect(a, isNot(b));
      expect(a, startsWith('event-alarm:x:'));
    });
  });

  group('sync', () {
    late MockPlugin plugin;
    setUp(() {
      plugin = MockPlugin();
      EventAlarms.pluginForTesting = plugin;
      EventAlarms.resetForTesting();
      when(() => plugin.cancel(id: any(named: 'id'), tag: any(named: 'tag')))
          .thenAnswer((_) async {});
      when(() => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});
    });
    tearDown(() => EventAlarms.pluginForTesting = null);

    test('keeps a still-wanted schedule, cancels a stale one of ours, leaves '
        'other notifications alone, schedules what is missing', () async {
      final kept = _event('kept', startsAt: soon);
      final fresh = _event('fresh', startsAt: soon.add(const Duration(hours: 1)));
      final keptPayload = EventAlarms.payloadFor('kept', soon, 'start');
      when(() => plugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          PendingNotificationRequest(1, 'kept', null, keptPayload),
          PendingNotificationRequest(2, 'gone', null,
              EventAlarms.payloadFor('gone', soon, 'start')),
          const PendingNotificationRequest(3, 'push', null, '/chat/saskia'),
        ],
      );

      await EventAlarms.sync([kept, fresh]);

      verify(() => plugin.cancel(id: 2, tag: null)).called(1);
      verifyNever(() => plugin.cancel(id: 1, tag: any(named: 'tag')));
      verifyNever(() => plugin.cancel(id: 3, tag: any(named: 'tag')));
      final scheduled = verify(() => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: captureAny(named: 'payload'),
          )).captured;
      expect(scheduled, [
        EventAlarms.payloadFor('fresh', fresh.startsAt, 'start'),
      ]);
    });

    test('a reminder schedules with its lead in the body', () async {
      final led = _event('b', startsAt: soon, lead: 15);
      when(() => plugin.pendingNotificationRequests())
          .thenAnswer((_) async => const []);
      await EventAlarms.sync([led]);
      final bodies = verify(() => plugin.zonedSchedule(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: captureAny(named: 'body'),
            scheduledDate: any(named: 'scheduledDate'),
            notificationDetails: any(named: 'notificationDetails'),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            payload: any(named: 'payload'),
          )).captured;
      expect(bodies, containsAll([null, 'Starts in 15 min']));
    });

    test('cancelAll drops only our schedules', () async {
      when(() => plugin.pendingNotificationRequests()).thenAnswer(
        (_) async => [
          PendingNotificationRequest(
              7, 'ours', null, EventAlarms.payloadFor('e', soon, 'start')),
          const PendingNotificationRequest(8, 'push', null, '/pending'),
        ],
      );
      await EventAlarms.cancelAll();
      verify(() => plugin.cancel(id: 7, tag: null)).called(1);
      verifyNever(() => plugin.cancel(id: 8, tag: any(named: 'tag')));
    });

    test('a plugin failure never escapes', () async {
      when(() => plugin.pendingNotificationRequests())
          .thenThrow(Exception('no platform'));
      await expectLater(
          EventAlarms.sync([_event('a', startsAt: soon)]), completes);
      await expectLater(EventAlarms.cancelAll(), completes);
    });
  });
}
