// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'direct_push_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The direct-connection transport. A provider so tests can replace the
/// platform plugin with a fake.

@ProviderFor(directPush)
final directPushProvider = DirectPushProvider._();

/// The direct-connection transport. A provider so tests can replace the
/// platform plugin with a fake.

final class DirectPushProvider
    extends $FunctionalProvider<DirectPush, DirectPush, DirectPush>
    with $Provider<DirectPush> {
  /// The direct-connection transport. A provider so tests can replace the
  /// platform plugin with a fake.
  DirectPushProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directPushProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directPushHash();

  @$internal
  @override
  $ProviderElement<DirectPush> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DirectPush create(Ref ref) {
    return directPush(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectPush value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectPush>(value),
    );
  }
}

String _$directPushHash() => r'97b5af941b4fe12c48b0c3b0985f3efb5ac0783a';
