// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_token_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushTokenService)
final pushTokenServiceProvider = PushTokenServiceProvider._();

final class PushTokenServiceProvider
    extends
        $FunctionalProvider<
          PushTokenService,
          PushTokenService,
          PushTokenService
        >
    with $Provider<PushTokenService> {
  PushTokenServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushTokenServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushTokenServiceHash();

  @$internal
  @override
  $ProviderElement<PushTokenService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushTokenService create(Ref ref) {
    return pushTokenService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushTokenService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushTokenService>(value),
    );
  }
}

String _$pushTokenServiceHash() => r'89944be31640b021a03f7c5aa12894cd3ac13bd7';
