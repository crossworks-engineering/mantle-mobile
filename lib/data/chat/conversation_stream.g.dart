// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_stream.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Live conversation events while the app is foregrounded.
///
/// Opens the SSE stream through [dioProvider] (so the bearer is injected and a
/// 401/redirect is handled by the shared interceptor), decodes `data:` lines,
/// and reconnects with capped exponential backoff when the socket drops. It
/// **pauses** (closes the socket) while the app is backgrounded by watching
/// [appLifecycleProvider], and reconnects on resume. `autoDispose` tears the
/// connection down when nothing is listening (no chat/inbox on screen).
///
/// Consumers (`ChatController`, `ConversationsController`) `ref.listen` this and
/// refetch the affected thread / inbox on each event — the same
/// "ping-to-refetch" model Mantle's web realtime uses.

@ProviderFor(conversationEvents)
final conversationEventsProvider = ConversationEventsProvider._();

/// Live conversation events while the app is foregrounded.
///
/// Opens the SSE stream through [dioProvider] (so the bearer is injected and a
/// 401/redirect is handled by the shared interceptor), decodes `data:` lines,
/// and reconnects with capped exponential backoff when the socket drops. It
/// **pauses** (closes the socket) while the app is backgrounded by watching
/// [appLifecycleProvider], and reconnects on resume. `autoDispose` tears the
/// connection down when nothing is listening (no chat/inbox on screen).
///
/// Consumers (`ChatController`, `ConversationsController`) `ref.listen` this and
/// refetch the affected thread / inbox on each event — the same
/// "ping-to-refetch" model Mantle's web realtime uses.

final class ConversationEventsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ConversationEvent>,
          ConversationEvent,
          Stream<ConversationEvent>
        >
    with
        $FutureModifier<ConversationEvent>,
        $StreamProvider<ConversationEvent> {
  /// Live conversation events while the app is foregrounded.
  ///
  /// Opens the SSE stream through [dioProvider] (so the bearer is injected and a
  /// 401/redirect is handled by the shared interceptor), decodes `data:` lines,
  /// and reconnects with capped exponential backoff when the socket drops. It
  /// **pauses** (closes the socket) while the app is backgrounded by watching
  /// [appLifecycleProvider], and reconnects on resume. `autoDispose` tears the
  /// connection down when nothing is listening (no chat/inbox on screen).
  ///
  /// Consumers (`ChatController`, `ConversationsController`) `ref.listen` this and
  /// refetch the affected thread / inbox on each event — the same
  /// "ping-to-refetch" model Mantle's web realtime uses.
  ConversationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationEventsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationEventsHash();

  @$internal
  @override
  $StreamProviderElement<ConversationEvent> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ConversationEvent> create(Ref ref) {
    return conversationEvents(ref);
  }
}

String _$conversationEventsHash() =>
    r'6b981870cd06a97aa58b1d0a213bd2956fe4d8d2';
