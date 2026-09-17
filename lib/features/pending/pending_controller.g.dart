// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the agent-approval queue. Loads the pending list on build; [approve] /
/// [reject] optimistically drop the row then persist via PATCH, reconciling on
/// failure. While mounted it listens to the live [conversationEventsProvider]
/// SSE and silently refetches — a tool call queued mid-turn coincides with a
/// conversation event, so the queue stays current without a pull.

@ProviderFor(PendingController)
final pendingControllerProvider = PendingControllerProvider._();

/// Owns the agent-approval queue. Loads the pending list on build; [approve] /
/// [reject] optimistically drop the row then persist via PATCH, reconciling on
/// failure. While mounted it listens to the live [conversationEventsProvider]
/// SSE and silently refetches — a tool call queued mid-turn coincides with a
/// conversation event, so the queue stays current without a pull.
final class PendingControllerProvider
    extends $AsyncNotifierProvider<PendingController, List<PendingCall>> {
  /// Owns the agent-approval queue. Loads the pending list on build; [approve] /
  /// [reject] optimistically drop the row then persist via PATCH, reconciling on
  /// failure. While mounted it listens to the live [conversationEventsProvider]
  /// SSE and silently refetches — a tool call queued mid-turn coincides with a
  /// conversation event, so the queue stays current without a pull.
  PendingControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingControllerHash();

  @$internal
  @override
  PendingController create() => PendingController();
}

String _$pendingControllerHash() => r'45e3bbbd103a58af9f0387f07f1339d892119a00';

/// Owns the agent-approval queue. Loads the pending list on build; [approve] /
/// [reject] optimistically drop the row then persist via PATCH, reconciling on
/// failure. While mounted it listens to the live [conversationEventsProvider]
/// SSE and silently refetches — a tool call queued mid-turn coincides with a
/// conversation event, so the queue stays current without a pull.

abstract class _$PendingController extends $AsyncNotifier<List<PendingCall>> {
  FutureOr<List<PendingCall>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<PendingCall>>, List<PendingCall>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<PendingCall>>, List<PendingCall>>,
              AsyncValue<List<PendingCall>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
