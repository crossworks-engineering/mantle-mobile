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

/// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
/// fetched through the authed [Dio]. Backs inline image attachments when
/// history reloads (the just-sent path renders from disk instead). Returns null
/// on any failure so the renderer falls back to a chip. Kept alive so an image
/// isn't re-fetched every time the list rebuilds while scrolling.

@ProviderFor(fileBytes)
final fileBytesProvider = FileBytesFamily._();

/// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
/// fetched through the authed [Dio]. Backs inline image attachments when
/// history reloads (the just-sent path renders from disk instead). Returns null
/// on any failure so the renderer falls back to a chip. Kept alive so an image
/// isn't re-fetched every time the list rebuilds while scrolling.

final class FileBytesProvider
    extends
        $FunctionalProvider<
          AsyncValue<Uint8List?>,
          Uint8List?,
          FutureOr<Uint8List?>
        >
    with $FutureModifier<Uint8List?>, $FutureProvider<Uint8List?> {
  /// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
  /// fetched through the authed [Dio]. Backs inline image attachments when
  /// history reloads (the just-sent path renders from disk instead). Returns null
  /// on any failure so the renderer falls back to a chip. Kept alive so an image
  /// isn't re-fetched every time the list rebuilds while scrolling.
  FileBytesProvider._({
    required FileBytesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'fileBytesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fileBytesHash();

  @override
  String toString() {
    return r'fileBytesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Uint8List?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Uint8List?> create(Ref ref) {
    final argument = this.argument as String;
    return fileBytes(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FileBytesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fileBytesHash() => r'78d916b39c1fbeec642f9ec04e430a9d86d5f38e';

/// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
/// fetched through the authed [Dio]. Backs inline image attachments when
/// history reloads (the just-sent path renders from disk instead). Returns null
/// on any failure so the renderer falls back to a chip. Kept alive so an image
/// isn't re-fetched every time the list rebuilds while scrolling.

final class FileBytesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Uint8List?>, String> {
  FileBytesFamily._()
    : super(
        retry: null,
        name: r'fileBytesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
  /// fetched through the authed [Dio]. Backs inline image attachments when
  /// history reloads (the just-sent path renders from disk instead). Returns null
  /// on any failure so the renderer falls back to a chip. Kept alive so an image
  /// isn't re-fetched every time the list rebuilds while scrolling.

  FileBytesProvider call(String nodeId) =>
      FileBytesProvider._(argument: nodeId, from: this);

  @override
  String toString() => r'fileBytesProvider';
}
