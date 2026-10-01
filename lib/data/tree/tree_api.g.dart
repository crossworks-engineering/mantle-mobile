// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(treeApi)
final treeApiProvider = TreeApiProvider._();

final class TreeApiProvider
    extends $FunctionalProvider<TreeApi, TreeApi, TreeApi>
    with $Provider<TreeApi> {
  TreeApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'treeApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$treeApiHash();

  @$internal
  @override
  $ProviderElement<TreeApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TreeApi create(Ref ref) {
    return treeApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TreeApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TreeApi>(value),
    );
  }
}

String _$treeApiHash() => r'9c891490452d7e72931ccd768254814e8a9b3061';
