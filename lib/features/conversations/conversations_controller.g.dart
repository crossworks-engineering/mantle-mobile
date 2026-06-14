// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh. While mounted it also listens to the live
/// [conversationEventsProvider] SSE and silently refetches when any thread gets
/// a turn (from any channel), so previews + unread stay current with no pull.

@ProviderFor(ConversationsController)
final conversationsControllerProvider = ConversationsControllerProvider._();

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh. While mounted it also listens to the live
/// [conversationEventsProvider] SSE and silently refetches when any thread gets
/// a turn (from any channel), so previews + unread stay current with no pull.
final class ConversationsControllerProvider
    extends
        $AsyncNotifierProvider<
          ConversationsController,
          List<AgentConversation>
        > {
  /// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
  /// unread optimistically then persists. ChatController invalidates this after a
  /// turn so previews/unread refresh. While mounted it also listens to the live
  /// [conversationEventsProvider] SSE and silently refetches when any thread gets
  /// a turn (from any channel), so previews + unread stay current with no pull.
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
    r'80098bd92e28e7b276fe7a550bb23a90aaea1ab5';

/// Owns the conversations inbox. Loads on build; [markRead] zeroes an agent's
/// unread optimistically then persists. ChatController invalidates this after a
/// turn so previews/unread refresh. While mounted it also listens to the live
/// [conversationEventsProvider] SSE and silently refetches when any thread gets
/// a turn (from any channel), so previews + unread stay current with no pull.

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
