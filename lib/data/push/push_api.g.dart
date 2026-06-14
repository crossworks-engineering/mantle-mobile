// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushApi)
final pushApiProvider = PushApiProvider._();

final class PushApiProvider
    extends $FunctionalProvider<PushApi, PushApi, PushApi>
    with $Provider<PushApi> {
  PushApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushApiHash();

  @$internal
  @override
  $ProviderElement<PushApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushApi create(Ref ref) {
    return pushApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushApi>(value),
    );
  }
}

String _$pushApiHash() => r'cadefe35a8a97894937c92f7db219380f954f5c2';
