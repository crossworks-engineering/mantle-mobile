// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sodium_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// libsodium, initialized once. Used only to generate the device's X25519
/// keypair for E2E push — sealing happens in Mantle (`crypto_box_seal`) and
/// opening in the iOS Notification Service Extension (`crypto_box_seal_open`),
/// never here. Using real libsodium guarantees the key format is byte-compatible
/// with both ends.

@ProviderFor(sodium)
final sodiumProvider = SodiumProvider._();

/// libsodium, initialized once. Used only to generate the device's X25519
/// keypair for E2E push — sealing happens in Mantle (`crypto_box_seal`) and
/// opening in the iOS Notification Service Extension (`crypto_box_seal_open`),
/// never here. Using real libsodium guarantees the key format is byte-compatible
/// with both ends.

final class SodiumProvider
    extends $FunctionalProvider<AsyncValue<Sodium>, Sodium, FutureOr<Sodium>>
    with $FutureModifier<Sodium>, $FutureProvider<Sodium> {
  /// libsodium, initialized once. Used only to generate the device's X25519
  /// keypair for E2E push — sealing happens in Mantle (`crypto_box_seal`) and
  /// opening in the iOS Notification Service Extension (`crypto_box_seal_open`),
  /// never here. Using real libsodium guarantees the key format is byte-compatible
  /// with both ends.
  SodiumProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sodiumProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sodiumHash();

  @$internal
  @override
  $FutureProviderElement<Sodium> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Sodium> create(Ref ref) {
    return sodium(ref);
  }
}

String _$sodiumHash() => r'a8b555c0cbe81fbca1321baf27e9b41167c5d769';
