// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pendingApi)
final pendingApiProvider = PendingApiProvider._();

final class PendingApiProvider
    extends $FunctionalProvider<PendingApi, PendingApi, PendingApi>
    with $Provider<PendingApi> {
  PendingApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingApiHash();

  @$internal
  @override
  $ProviderElement<PendingApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PendingApi create(Ref ref) {
    return pendingApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingApi>(value),
    );
  }
}

String _$pendingApiHash() => r'a7c3bdf8654bdafd46e74f47b7e26a29c4967c7f';
