// TasksScreen as a widget: open tasks above, done ones under a heading; the
// circle checks off through the API; a tap on the row opens the edit sheet
// prefilled.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/tasks/tasks_api.dart';
import 'package:jackdaw/data/tasks/tasks_models.dart';
import 'package:jackdaw/features/tasks/tasks_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../helpers/pump_screen.dart';

class MockTasksApi extends Mock implements TasksApi {}

TaskRow _task(String id, {bool done = false, DateTime? due}) => TaskRow(
      id: id,
      title: 'Task $id',
      body: '',
      done: done,
      priority: 'normal',
      dueAt: due,
      tags: const [],
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  late MockTasksApi api;
  setUp(() {
    api = MockTasksApi();
    when(() => api.list()).thenAnswer(
      (_) async => TasksPage(
        tasks: [_task('a'), _task('b', done: true)],
        total: 2,
      ),
    );
  });

  Future<void> pump(WidgetTester tester) => pumpScreen(
        tester,
        const TasksScreen(),
        container: ProviderContainer(
          overrides: [tasksApiProvider.overrideWithValue(api)],
        ),
      );

  testWidgets('lists open tasks, then done ones under a heading',
      (tester) async {
    await pump(tester);
    expect(find.text('Task a'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Task b'), findsOneWidget);
    expect(find.bySemanticsLabel('Mark done'), findsOneWidget);
    expect(find.bySemanticsLabel('Mark not done'), findsOneWidget);
  });

  testWidgets('the circle checks a task off through the API', (tester) async {
    when(() => api.setDone('a', done: true))
        .thenAnswer((_) async => _task('a', done: true));
    await pump(tester);

    await tester.tap(find.bySemanticsLabel('Mark done'));
    await tester.pumpAndSettle();

    verify(() => api.setDone('a', done: true)).called(1);
    // Optimistic: both rows now sit under Done.
    expect(find.bySemanticsLabel('Mark not done'), findsNWidgets(2));
  });

  testWidgets('an empty + focuses the field instead of doing nothing',
      (tester) async {
    await pump(tester);
    final input = tester.widget<ShadInput>(find.byType(ShadInput).first);
    expect(input.focusNode!.hasFocus, isFalse);

    await tester.tap(find.bySemanticsLabel('Add task'));
    await tester.pumpAndSettle();

    expect(input.focusNode!.hasFocus, isTrue);
    verifyNever(() => api.create(any(), dueAt: any(named: 'dueAt')));
  });

  testWidgets('a tap on the row opens the edit sheet, prefilled',
      (tester) async {
    await pump(tester);
    await tester.tap(find.text('Task a'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.widgetWithText(EditTaskSheet, 'Task a'), findsOneWidget);
    expect(find.text('No due date'), findsOneWidget);
    expect(find.text('Pick a day'), findsOneWidget);
  });
}
