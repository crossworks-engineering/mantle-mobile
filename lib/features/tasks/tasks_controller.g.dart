// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TasksController)
final tasksControllerProvider = TasksControllerProvider._();

final class TasksControllerProvider
    extends $AsyncNotifierProvider<TasksController, List<TaskRow>> {
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

String _$tasksControllerHash() => r'0000000000000000000000000000000000000000';

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
