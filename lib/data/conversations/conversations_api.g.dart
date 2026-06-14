// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(conversationsApi)
final conversationsApiProvider = ConversationsApiProvider._();

final class ConversationsApiProvider
    extends
        $FunctionalProvider<
          ConversationsApi,
          ConversationsApi,
          ConversationsApi
        >
    with $Provider<ConversationsApi> {
  ConversationsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsApiHash();

  @$internal
  @override
  $ProviderElement<ConversationsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ConversationsApi create(Ref ref) {
    return conversationsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationsApi>(value),
    );
  }
}

String _$conversationsApiHash() => r'103950bc7789a4b08c0fafb94128ef2175d9cf1f';
