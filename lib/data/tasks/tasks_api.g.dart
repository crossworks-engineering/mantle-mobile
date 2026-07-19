// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tasks_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tasksApi)
final tasksApiProvider = TasksApiProvider._();

final class TasksApiProvider
    extends $FunctionalProvider<TasksApi, TasksApi, TasksApi>
    with $Provider<TasksApi> {
  TasksApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tasksApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tasksApiHash();

  @$internal
  @override
  $ProviderElement<TasksApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TasksApi create(Ref ref) {
    return tasksApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TasksApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TasksApi>(value),
    );
  }
}

String _$tasksApiHash() => r'992221cc80fac3612b535ead563736087ebf6787';
