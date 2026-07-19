// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'files_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(filesApi)
final filesApiProvider = FilesApiProvider._();

final class FilesApiProvider
    extends $FunctionalProvider<FilesApi, FilesApi, FilesApi>
    with $Provider<FilesApi> {
  FilesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filesApiHash();

  @$internal
  @override
  $ProviderElement<FilesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FilesApi create(Ref ref) {
    return filesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FilesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FilesApi>(value),
    );
  }
}

String _$filesApiHash() => r'92e2e5d4cfe82f38dabfe0618af8ba8033587ba2';
