// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_keys.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushKeyStore)
final pushKeyStoreProvider = PushKeyStoreProvider._();

final class PushKeyStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<PushKeyStore>,
          PushKeyStore,
          FutureOr<PushKeyStore>
        >
    with $FutureModifier<PushKeyStore>, $FutureProvider<PushKeyStore> {
  PushKeyStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushKeyStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushKeyStoreHash();

  @$internal
  @override
  $FutureProviderElement<PushKeyStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PushKeyStore> create(Ref ref) {
    return pushKeyStore(ref);
  }
}

String _$pushKeyStoreHash() => r'3e0dcf7c60a809526f5054f414ed2b9d093103aa';
