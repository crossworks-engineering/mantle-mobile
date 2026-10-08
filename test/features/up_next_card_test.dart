// The home screen's "Up next" card: the next events and the tasks due, each
// row naming what it opens; one quiet line when nothing is due; a retry when
// the brain could not be read.

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/events/events_api.dart';
import 'package:jackdaw/data/events/events_models.dart';
import 'package:jackdaw/data/tasks/tasks_api.dart';
import 'package:jackdaw/data/tasks/tasks_models.dart';
import 'package:jackdaw/features/home/up_next_card.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_screen.dart';

class MockEventsApi extends Mock implements EventsApi {}

class MockTasksApi extends Mock implements TasksApi {}

EventRow _event(String id, Duration fromNow, {int remind = 0}) => EventRow(
      id: id,
      title: 'Event $id',
      body: '',
      startsAt: DateTime.now().toUtc().add(fromNow),
      endsAt: null,
      location: id == 'e1' ? 'Clinic' : null,
      remindMinutesBefore: remind,
      remindAt: null,
      recur: 'none',
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

TaskRow _task(String id, Duration fromNow) => TaskRow(
      id: id,
      title: 'Task $id',
      body: '',
      done: false,
      priority: 'normal',
      dueAt: DateTime.now().toUtc().add(fromNow),
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  late MockEventsApi events;
  late MockTasksApi tasks;

  setUp(() {
    events = MockEventsApi();
    tasks = MockTasksApi();
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        ListView(children: const [UpNextCard()]),
        container: ProviderContainer(
          overrides: [
            eventsApiProvider.overrideWithValue(events),
            tasksApiProvider.overrideWithValue(tasks),
          ],
        ),
      );

  testWidgets('shows the next events and the tasks due, each a button',
      (tester) async {
    when(() => events.list()).thenAnswer(
      (_) async => EventsPage(
        events: [
          _event('e2', const Duration(days: 1)),
          _event('e1', const Duration(hours: 2), remind: 15),
        ],
        total: 2,
      ),
    );
    when(() => tasks.listNotDone()).thenAnswer(
      (_) async => [
        _task('later', const Duration(days: 2)),
        _task('late', const Duration(days: -2)),
        _task('someday', const Duration(days: 30)),
      ],
    );
    await pump(tester);

    expect(find.text('Up next'), findsOneWidget);
    // Soonest first.
    final e1 = tester.getTopLeft(find.text('Event e1')).dy;
    final e2 = tester.getTopLeft(find.text('Event e2')).dy;
    expect(e1, lessThan(e2));
    // Overdue first; beyond the window left out.
    final late = tester.getTopLeft(find.text('Task late')).dy;
    final later = tester.getTopLeft(find.text('Task later')).dy;
    expect(late, lessThan(later));
    expect(find.text('Task someday'), findsNothing);
    expect(find.text('2 days overdue'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Event: Event e1,')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Task: Task late,')), findsOneWidget);
    expect(find.bySemanticsLabel('See all events'), findsOneWidget);
    expect(find.bySemanticsLabel('See all tasks'), findsOneWidget);
  });

  testWidgets('nothing due says so in one line', (tester) async {
    when(() => events.list())
        .thenAnswer((_) async => const EventsPage(events: [], total: 0));
    when(() => tasks.listNotDone()).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nothing due in the next few days.'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('a brain that cannot be read offers a retry', (tester) async {
    when(() => events.list()).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/api/events')),
    );
    when(() => tasks.listNotDone()).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text("Couldn't load what's coming up."), findsOneWidget);
    when(() => events.list())
        .thenAnswer((_) async => const EventsPage(events: [], total: 0));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing due in the next few days.'), findsOneWidget);
  });
}
