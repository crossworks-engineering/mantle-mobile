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
///
/// When live streaming is on the reply types out token by token: `send` returns
/// **202**, this controller subscribes to the turn's SSE bus and accumulates the
/// reply into [ChatState.active], then reconciles to the durable row on `done`.
/// When it's off the server returns the finished rows and we swap them in. Both
/// shapes are handled, so the app degrades gracefully either way.

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerFamily._();

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
///
/// When live streaming is on the reply types out token by token: `send` returns
/// **202**, this controller subscribes to the turn's SSE bus and accumulates the
/// reply into [ChatState.active], then reconciles to the durable row on `done`.
/// When it's off the server returns the finished rows and we swap them in. Both
/// shapes are handled, so the app degrades gracefully either way.
final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, ChatState> {
  /// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
  /// build, pages older history on demand ([loadMore]), and sends messages
  /// optimistically: the user's message shows immediately as `sending`, then flips
  /// to `sent` (with the assistant's reply appended) or `failed`.
  ///
  /// When live streaming is on the reply types out token by token: `send` returns
  /// **202**, this controller subscribes to the turn's SSE bus and accumulates the
  /// reply into [ChatState.active], then reconciles to the durable row on `done`.
  /// When it's off the server returns the finished rows and we swap them in. Both
  /// shapes are handled, so the app degrades gracefully either way.
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

String _$chatControllerHash() => r'fe46b78d8bc6bf1aa1a68b69b2c85c64d8213917';

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
///
/// When live streaming is on the reply types out token by token: `send` returns
/// **202**, this controller subscribes to the turn's SSE bus and accumulates the
/// reply into [ChatState.active], then reconciles to the durable row on `done`.
/// When it's off the server returns the finished rows and we swap them in. Both
/// shapes are handled, so the app degrades gracefully either way.

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
  ///
  /// When live streaming is on the reply types out token by token: `send` returns
  /// **202**, this controller subscribes to the turn's SSE bus and accumulates the
  /// reply into [ChatState.active], then reconciles to the durable row on `done`.
  /// When it's off the server returns the finished rows and we swap them in. Both
  /// shapes are handled, so the app degrades gracefully either way.

  ChatControllerProvider call(String agentSlug) =>
      ChatControllerProvider._(argument: agentSlug, from: this);

  @override
  String toString() => r'chatControllerProvider';
}

/// Owns one agent's thread (keyed by [agentSlug]). Loads the latest page on
/// build, pages older history on demand ([loadMore]), and sends messages
/// optimistically: the user's message shows immediately as `sending`, then flips
/// to `sent` (with the assistant's reply appended) or `failed`.
///
/// When live streaming is on the reply types out token by token: `send` returns
/// **202**, this controller subscribes to the turn's SSE bus and accumulates the
/// reply into [ChatState.active], then reconciles to the durable row on `done`.
/// When it's off the server returns the finished rows and we swap them in. Both
/// shapes are handled, so the app degrades gracefully either way.

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
