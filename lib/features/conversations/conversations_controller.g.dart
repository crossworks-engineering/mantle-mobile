// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh.

@ProviderFor(ConversationsController)
final conversationsControllerProvider = ConversationsControllerProvider._();

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh.
final class ConversationsControllerProvider
    extends
        $AsyncNotifierProvider<
          ConversationsController,
          List<AgentConversation>
        > {
  /// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
  /// unread optimistically then persists. ChatController invalidates this after a
  /// turn so previews/unread refresh.
  ConversationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsControllerHash();

  @$internal
  @override
  ConversationsController create() => ConversationsController();
}

String _$conversationsControllerHash() =>
    r'1ec47e5769c323cabd9d85cd3c59f715939108c2';

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh.

abstract class _$ConversationsController
    extends $AsyncNotifier<List<AgentConversation>> {
  FutureOr<List<AgentConversation>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<AgentConversation>>,
              List<AgentConversation>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<AgentConversation>>,
                List<AgentConversation>
              >,
              AsyncValue<List<AgentConversation>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
