// Riverpod 3 throws on `state =` after an autoDispose notifier is disposed.
// The screens call refresh() from a tap and never await it, so "tap refresh,
// then leave before the response" is an ordinary thing to do. This pins the
// pattern the controllers follow: guard every write after an await.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/tasks/tasks_api.dart';
import 'package:jackdaw/data/tasks/tasks_models.dart';
import 'package:jackdaw/features/tasks/tasks_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockTasksApi extends Mock implements TasksApi {}

void main() {
  test('a refresh that lands after the screen is gone does not throw', () async {
    final api = MockTasksApi();
    final first = Completer<TasksPage>();
    final second = Completer<TasksPage>();
    var calls = 0;
    when(() => api.list()).thenAnswer(
      (_) => (++calls == 1 ? first : second).future,
    );

    final container = ProviderContainer(
      overrides: [tasksApiProvider.overrideWithValue(api)],
    );
    // Keep the provider alive the way a screen would, then let it go.
    final sub = container.listen(tasksControllerProvider, (_, _) {});
    first.complete(const TasksPage(tasks: [], total: 0));
    await container.read(tasksControllerProvider.future);

    final refreshing = container.read(tasksControllerProvider.notifier).refresh();
    sub.close(); // the screen pops; the autoDispose notifier is disposed
    await Future<void>.delayed(Duration.zero);
    second.complete(const TasksPage(tasks: [], total: 0));

    // Before the guard this threw UnmountedRefException from inside refresh().
    await expectLater(refreshing, completes);
    container.dispose();
  });
}
