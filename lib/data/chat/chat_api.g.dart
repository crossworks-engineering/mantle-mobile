// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(chatApi)
final chatApiProvider = ChatApiProvider._();

final class ChatApiProvider
    extends $FunctionalProvider<ChatApi, ChatApi, ChatApi>
    with $Provider<ChatApi> {
  ChatApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatApiHash();

  @$internal
  @override
  $ProviderElement<ChatApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatApi create(Ref ref) {
    return chatApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatApi>(value),
    );
  }
}

String _$chatApiHash() => r'137318d40b3ab5ba3df06f2aed38d72ef5faf1a4';
