// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspaces_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(workspacesApi)
final workspacesApiProvider = WorkspacesApiProvider._();

final class WorkspacesApiProvider
    extends $FunctionalProvider<WorkspacesApi, WorkspacesApi, WorkspacesApi>
    with $Provider<WorkspacesApi> {
  WorkspacesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspacesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspacesApiHash();

  @$internal
  @override
  $ProviderElement<WorkspacesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkspacesApi create(Ref ref) {
    return workspacesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspacesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspacesApi>(value),
    );
  }
}

String _$workspacesApiHash() => r'1b167b8ee1edb8cbb99e743b85b1f8b260b77fe4';
