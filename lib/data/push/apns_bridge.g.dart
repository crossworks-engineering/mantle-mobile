// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apns_bridge.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(apnsBridge)
final apnsBridgeProvider = ApnsBridgeProvider._();

final class ApnsBridgeProvider
    extends $FunctionalProvider<ApnsBridge, ApnsBridge, ApnsBridge>
    with $Provider<ApnsBridge> {
  ApnsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apnsBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apnsBridgeHash();

  @$internal
  @override
  $ProviderElement<ApnsBridge> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApnsBridge create(Ref ref) {
    return apnsBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApnsBridge value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApnsBridge>(value),
    );
  }
}

String _$apnsBridgeHash() => r'717975c421710793eec55b474bb5a63d394ce3b6';
