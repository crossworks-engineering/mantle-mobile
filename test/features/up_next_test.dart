// "Up next" ordering: the next events soonest first; the tasks due overdue
// first, then today, then the next few days; each cut to a short list.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/events/events_models.dart';
import 'package:jackdaw/data/tasks/tasks_models.dart';
import 'package:jackdaw/features/dashboard/up_next.dart';

// Wednesday 8 October 2026, 10:00 local.
final _now = DateTime(2026, 10, 8, 10);

EventRow _event(String id, DateTime startsAt, {List<String> tags = const []}) =>
    EventRow(
      id: id,
      title: 'Event $id',
      body: '',
      startsAt: startsAt.toUtc(),
      endsAt: null,
      location: null,
      remindMinutesBefore: 0,
      remindAt: null,
      recur: 'none',
      tags: tags,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

TaskRow _task(
  String id,
  DateTime? due, {
  bool done = false,
  String priority = 'normal',
}) =>
    TaskRow(
      id: id,
      title: 'Task $id',
      body: '',
      done: done,
      priority: priority,
      dueAt: due?.toUtc(),
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

List<String> _ids(Iterable<dynamic> rows) =>
    [for (final r in rows) r.id as String];

void main() {
  group('events', () {
    test('soonest first, whatever order they came in', () {
      final up = buildUpNext(
        events: [
          _event('later', _now.add(const Duration(days: 2))),
          _event('soon', _now.add(const Duration(hours: 1))),
          _event('mid', _now.add(const Duration(days: 1))),
        ],
        tasks: const [],
        now: _now,
      );
      expect(_ids(up.events), ['soon', 'mid', 'later']);
    });

    test('done and already started events are left out', () {
      final up = buildUpNext(
        events: [
          _event('done', _now.add(const Duration(hours: 1)), tags: ['done']),
          _event('started', _now.subtract(const Duration(minutes: 5))),
          _event('next', _now.add(const Duration(hours: 2))),
        ],
        tasks: const [],
        now: _now,
      );
      expect(_ids(up.events), ['next']);
    });

    test('cut to the limit', () {
      final up = buildUpNext(
        events: [
          for (var i = 1; i <= 6; i++)
            _event('e$i', _now.add(Duration(hours: i))),
        ],
        tasks: const [],
        now: _now,
      );
      expect(_ids(up.events), ['e1', 'e2', 'e3']);
      expect(up.events, hasLength(kUpNextLimit));
    });
  });

  group('tasks', () {
    test('overdue first, then today, then the next few days', () {
      final up = buildUpNext(
        events: const [],
        tasks: [
          _task('thu', DateTime(2026, 10, 9, 9)),
          _task('today', DateTime(2026, 10, 8, 17)),
          _task('lastweek', DateTime(2026, 10, 1, 9)),
          _task('earlier', DateTime(2026, 10, 8, 8)),
        ],
        now: _now,
        limit: 10,
      );
      expect(_ids(up.tasks), ['lastweek', 'earlier', 'today', 'thu']);
      expect(taskDue(up.tasks[0], _now), TaskDue.overdue);
      expect(taskDue(up.tasks[1], _now), TaskDue.overdue);
      expect(taskDue(up.tasks[2], _now), TaskDue.today);
      expect(taskDue(up.tasks[3], _now), TaskDue.soon);
    });

    test('only through the third day after today', () {
      final up = buildUpNext(
        events: const [],
        tasks: [
          _task('sat-late', DateTime(2026, 10, 11, 23, 59)),
          _task('sun', DateTime(2026, 10, 12, 0, 0)),
        ],
        now: _now,
      );
      expect(_ids(up.tasks), ['sat-late']);
    });

    test('done tasks and tasks with no due date are left out', () {
      final up = buildUpNext(
        events: const [],
        tasks: [
          _task('done', DateTime(2026, 10, 8, 12), done: true),
          _task('someday', null),
          _task('due', DateTime(2026, 10, 8, 12)),
        ],
        now: _now,
      );
      expect(_ids(up.tasks), ['due']);
    });

    test('at the same time, high priority first, then by title', () {
      final at = DateTime(2026, 10, 9, 9);
      final up = buildUpNext(
        events: const [],
        tasks: [
          _task('b', at),
          _task('a', at),
          _task('c', at, priority: 'high'),
        ],
        now: _now,
      );
      expect(_ids(up.tasks), ['c', 'a', 'b']);
    });

    test('cut to the limit, keeping the most urgent', () {
      final up = buildUpNext(
        events: const [],
        tasks: [
          for (var i = 5; i >= 1; i--) _task('t$i', DateTime(2026, 10, 8, i)),
        ],
        now: _now,
      );
      expect(_ids(up.tasks), ['t1', 't2', 't3']);
    });
  });

  test('nothing due is empty', () {
    final up = buildUpNext(events: const [], tasks: const [], now: _now);
    expect(up.isEmpty, isTrue);
  });
}
