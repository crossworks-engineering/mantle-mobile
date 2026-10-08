import '../../data/events/events_models.dart';
import '../../data/tasks/tasks_models.dart';

/// How many rows each half of "Up next" shows before "See all".
const int kUpNextLimit = 3;

/// How far ahead "Up next" looks for tasks: overdue, today, and this many
/// days after today.
const int kUpNextTaskDays = 3;

/// What the home screen's "Up next" shows: the next events (each one's
/// reminder rings before it, so soonest event = soonest reminder) and the
/// tasks due soon, each cut to a short list.
class UpNext {
  const UpNext({required this.events, required this.tasks});

  /// Soonest first.
  final List<EventRow> events;

  /// Overdue first, then today, then the next few days.
  final List<TaskRow> tasks;

  bool get isEmpty => events.isEmpty && tasks.isEmpty;
}

/// Where a task falls in "Up next".
enum TaskDue { overdue, today, soon }

TaskDue taskDue(TaskRow task, DateTime now) {
  final due = task.dueAt!.toLocal();
  final n = now.toLocal();
  if (due.isBefore(n)) return TaskDue.overdue;
  if (due.year == n.year && due.month == n.month && due.day == n.day) {
    return TaskDue.today;
  }
  return TaskDue.soon;
}

/// Build "Up next" from the upcoming events and the not-done tasks.
///
/// Events: not marked done and not yet started, soonest first. Tasks: not
/// done, with a due date before the end of the [taskDays]th day after today
/// (local time), earliest due first, so the overdue lead, then today's, then
/// the next days'. Equal times keep a stable order: a high-priority task
/// first, then by title.
UpNext buildUpNext({
  required List<EventRow> events,
  required List<TaskRow> tasks,
  required DateTime now,
  int limit = kUpNextLimit,
  int taskDays = kUpNextTaskDays,
}) {
  final upcoming = [
    for (final e in events)
      if (!e.done && !e.startsAt.isBefore(now)) e,
  ]..sort((a, b) {
      final byTime = a.startsAt.compareTo(b.startsAt);
      return byTime != 0 ? byTime : a.title.compareTo(b.title);
    });

  final local = now.toLocal();
  final horizon = DateTime(local.year, local.month, local.day + taskDays + 1);
  final due = [
    for (final t in tasks)
      if (!t.done && t.dueAt != null && t.dueAt!.isBefore(horizon)) t,
  ]..sort((a, b) {
      final byDue = a.dueAt!.compareTo(b.dueAt!);
      if (byDue != 0) return byDue;
      final byPriority =
          _priorityRank(a.priority).compareTo(_priorityRank(b.priority));
      return byPriority != 0 ? byPriority : a.title.compareTo(b.title);
    });

  return UpNext(
    events: upcoming.take(limit).toList(),
    tasks: due.take(limit).toList(),
  );
}

int _priorityRank(String p) => switch (p) {
      'high' => 0,
      'normal' => 1,
      _ => 2,
    };
