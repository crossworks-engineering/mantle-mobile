import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/events/events_api.dart';
import '../../data/tasks/tasks_api.dart';
import 'up_next.dart';

part 'up_next_controller.g.dart';

/// Loads the home screen's "Up next": the upcoming events and the tasks not
/// yet done, read through the brain's own event and task routes, cut by
/// [buildUpNext].
///
/// Fresh when the app comes back to the foreground, and when the events or
/// tasks screens change something ([refreshUpNextIfShown]). A refresh keeps
/// the rows on screen while it runs.
@riverpod
class UpNextController extends _$UpNextController {
  @override
  Future<UpNext> build() async {
    // Rebuilt with the client: another login, or another brain.
    final events = ref.watch(eventsApiProvider);
    final tasks = ref.watch(tasksApiProvider);
    ref.listen(appLifecycleProvider, (prev, next) {
      if (next == AppLifecycleState.resumed &&
          prev != AppLifecycleState.resumed) {
        ref.invalidateSelf();
      }
    });
    final (upcoming, notDone) =
        await (events.list(), tasks.listNotDone()).wait;
    return buildUpNext(
      events: upcoming.events,
      tasks: notDone,
      now: DateTime.now(),
    );
  }
}

/// Re-read "Up next" if the home screen holds it, after an event or a task
/// changed elsewhere. Rows stay on screen while it reloads.
void refreshUpNextIfShown(Ref ref) {
  if (ref.exists(upNextControllerProvider)) {
    ref.invalidate(upNextControllerProvider);
  }
}
