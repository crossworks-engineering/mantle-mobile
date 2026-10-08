import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/tasks/tasks_api.dart';
import '../../data/tasks/tasks_models.dart';

import '../dashboard/up_next_controller.dart';

part 'tasks_controller.g.dart';

/// Owns the task list (first page, server-sorted: open before done, due date
/// asc, then recency). Check-off and quick-add are optimistic — the list
/// updates immediately, the server persists, and a failure reloads so the
/// screen never lies for long.
@riverpod
class TasksController extends _$TasksController {
  @override
  Future<List<TaskRow>> build() async {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(tasksApiProvider);
    return (await ref.read(tasksApiProvider).list()).tasks;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(
      () async => (await ref.read(tasksApiProvider).list()).tasks,
    );
    if (ref.mounted) state = next;
  }

  /// Flip open/done optimistically, then persist.
  Future<void> setDone(String id, {required bool done}) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final t in current)
          if (t.id == id) t.copyWith(done: done) else t,
      ]);
    }
    try {
      await ref.read(tasksApiProvider).setDone(id, done: done);
      if (ref.mounted) refreshUpNextIfShown(ref);
    } catch (_) {
      await _reloadSilently();
    }
  }

  /// Create an open task from the quick-add field and put the saved row at the
  /// top of the open section.
  Future<void> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    try {
      final row = await ref.read(tasksApiProvider).create(trimmed);
      if (!ref.mounted) return;
      refreshUpNextIfShown(ref);
      final current = state.value;
      if (current != null) {
        state = AsyncData([row, ...current]);
      }
    } catch (_) {
      await _reloadSilently();
      rethrow; // let the screen surface the failure
    }
  }

  /// Edit title, priority and due date from the edit sheet. Server first
  /// (the sheet shows the failure), then the row is swapped in place and the
  /// list re-fetched quietly so the server's due-date order holds.
  Future<void> edit(
    String id, {
    String? title,
    String? priority,
    DateTime? dueAt,
    bool clearDueAt = false,
  }) async {
    final updated = await ref.read(tasksApiProvider).update(
          id,
          title: title,
          priority: priority,
          dueAt: dueAt,
          clearDueAt: clearDueAt,
        );
    if (!ref.mounted) return;
    refreshUpNextIfShown(ref);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final t in current)
          if (t.id == id) updated else t,
      ]);
    }
    await _reloadSilently();
  }

  /// Delete a task (long-press action), optimistically.
  Future<void> delete(String id) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final t in current)
          if (t.id != id) t,
      ]);
    }
    try {
      await ref.read(tasksApiProvider).delete(id);
      if (ref.mounted) refreshUpNextIfShown(ref);
    } catch (_) {
      await _reloadSilently();
    }
  }

  Future<void> _reloadSilently() async {
    try {
      final rows = (await ref.read(tasksApiProvider).list()).tasks;
      if (ref.mounted) state = AsyncData(rows);
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}
