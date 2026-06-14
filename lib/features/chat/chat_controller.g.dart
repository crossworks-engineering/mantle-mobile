// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerFamily._();

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, ChatState> {
  /// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
  /// build, pages older history on demand ([loadMore]), and sends messages
  /// optimistically: the user's message shows immediately as `sending`, then flips
  /// to `sent` (with the assistant's reply appended) or `failed`.
  ChatControllerProvider._({
    required ChatControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @override
  String toString() {
    return r'chatControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatController create() => ChatController();

  @override
  bool operator ==(Object other) {
    return other is ChatControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatControllerHash() => r'9da106863cba6d807f5da66816a59d2e07183831';

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.

final class ChatControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatController,
          AsyncValue<ChatState>,
          ChatState,
          FutureOr<ChatState>,
          String
        > {
  ChatControllerFamily._()
    : super(
        retry: null,
        name: r'chatControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
  /// build, pages older history on demand ([loadMore]), and sends messages
  /// optimistically: the user's message shows immediately as `sending`, then flips
  /// to `sent` (with the assistant's reply appended) or `failed`.

  ChatControllerProvider call(String agentSlug) =>
      ChatControllerProvider._(argument: agentSlug, from: this);

  @override
  String toString() => r'chatControllerProvider';
}

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.

abstract class _$ChatController extends $AsyncNotifier<ChatState> {
  late final _$args = ref.$arg as String;
  String get agentSlug => _$args;

  FutureOr<ChatState> build(String agentSlug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ChatState>, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ChatState>, ChatState>,
              AsyncValue<ChatState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
