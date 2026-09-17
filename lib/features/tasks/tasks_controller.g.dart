// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the task list (first page, server-sorted: open before done, due date
/// asc, then recency). Check-off and quick-add are optimistic — the list
/// updates immediately, the server persists, and a failure reloads so the
/// screen never lies for long.

@ProviderFor(TasksController)
final tasksControllerProvider = TasksControllerProvider._();

/// Owns the task list (first page, server-sorted: open before done, due date
/// asc, then recency). Check-off and quick-add are optimistic — the list
/// updates immediately, the server persists, and a failure reloads so the
/// screen never lies for long.
final class TasksControllerProvider
    extends $AsyncNotifierProvider<TasksController, List<TaskRow>> {
  /// Owns the task list (first page, server-sorted: open before done, due date
  /// asc, then recency). Check-off and quick-add are optimistic — the list
  /// updates immediately, the server persists, and a failure reloads so the
  /// screen never lies for long.
  TasksControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksControllerHash();

  @$internal
  @override
  TasksController create() => TasksController();
}

String _$tasksControllerHash() => r'e14601cfbc3214d7b60ef3f89478ee4450d0921e';

/// Owns the task list (first page, server-sorted: open before done, due date
/// asc, then recency). Check-off and quick-add are optimistic — the list
/// updates immediately, the server persists, and a failure reloads so the
/// screen never lies for long.

abstract class _$TasksController extends $AsyncNotifier<List<TaskRow>> {
  FutureOr<List<TaskRow>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<TaskRow>>, List<TaskRow>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TaskRow>>, List<TaskRow>>,
              AsyncValue<List<TaskRow>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
