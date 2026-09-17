// TasksController: the list is server-ordered; an edit swaps the row in and
// then re-fetches so the server's due-date order holds.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/tasks/tasks_api.dart';
import 'package:jackdaw/data/tasks/tasks_models.dart';
import 'package:jackdaw/features/tasks/tasks_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTasksApi extends Mock implements TasksApi {}

TaskRow _row(String id, {DateTime? due, String priority = 'normal'}) =>
    TaskRow(
      id: id,
      title: id,
      body: '',
      done: false,
      priority: priority,
      dueAt: due,
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  late MockTasksApi api;
  setUp(() {
    api = MockTasksApi();
    registerFallbackValue(DateTime(2000));
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [tasksApiProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('edit sends only what changed, swaps the row, then re-fetches',
      () async {
    final due = DateTime(2026, 9, 20);
    when(() => api.list()).thenAnswer(
      (_) async => TasksPage(tasks: [_row('a'), _row('b')], total: 2),
    );
    when(() => api.update('a',
            title: null,
            priority: 'high',
            dueAt: due,
            clearDueAt: false))
        .thenAnswer((_) async => _row('a', due: due, priority: 'high'));

    final c = make();
    await c.read(tasksControllerProvider.future);
    // The re-fetch after the edit returns the server's new order.
    when(() => api.list()).thenAnswer(
      (_) async => TasksPage(
        tasks: [_row('a', due: due, priority: 'high'), _row('b')],
        total: 2,
      ),
    );
    await c
        .read(tasksControllerProvider.notifier)
        .edit('a', priority: 'high', dueAt: due);

    final rows = c.read(tasksControllerProvider).value!;
    expect(rows.first.id, 'a');
    expect(rows.first.priority, 'high');
    expect(rows.first.dueAt, due);
    verify(() => api.list()).called(2);
  });

  test('edit rethrows so the sheet can say so, and the list stands',
      () async {
    when(() => api.list()).thenAnswer(
      (_) async => TasksPage(tasks: [_row('a')], total: 1),
    );
    when(() => api.update(any(),
            title: any(named: 'title'),
            priority: any(named: 'priority'),
            dueAt: any(named: 'dueAt'),
            clearDueAt: any(named: 'clearDueAt')))
        .thenThrow(Exception('offline'));

    final c = make();
    await c.read(tasksControllerProvider.future);
    await expectLater(
      c.read(tasksControllerProvider.notifier).edit('a', title: 'b'),
      throwsA(isA<Exception>()),
    );
    expect(c.read(tasksControllerProvider).value!.single.title, 'a');
  });

  test('copyWith clears the due date only when asked', () {
    final t = _row('a', due: DateTime(2026, 9, 20));
    expect(t.copyWith(priority: 'low').dueAt, isNotNull);
    expect(t.copyWith(clearDueAt: true).dueAt, isNull);
  });
}
