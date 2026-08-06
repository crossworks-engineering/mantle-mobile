// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)
///
/// Both the list and the default come from Mantle rather than being derived
/// here. `/api/agents` carries the rich rows (avatar, role) but is filtered
/// only to conversational roles — it still includes DISABLED agents, which the
/// web picker hides. `/api/assistant/thread` supplies the server's own answer
/// to both questions, so the two are intersected: the app never re-implements
/// the eligibility rule, and its default matches the agent the server would
/// pick for this login when a turn omits `?agent=` (since v0.224 that is the
/// login's own assigned assistant, not just the highest-priority agent).

@ProviderFor(AgentController)
final agentControllerProvider = AgentControllerProvider._();

/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)
///
/// Both the list and the default come from Mantle rather than being derived
/// here. `/api/agents` carries the rich rows (avatar, role) but is filtered
/// only to conversational roles — it still includes DISABLED agents, which the
/// web picker hides. `/api/assistant/thread` supplies the server's own answer
/// to both questions, so the two are intersected: the app never re-implements
/// the eligibility rule, and its default matches the agent the server would
/// pick for this login when a turn omits `?agent=` (since v0.224 that is the
/// login's own assigned assistant, not just the highest-priority agent).
final class AgentControllerProvider
    extends $AsyncNotifierProvider<AgentController, AgentsState> {
  /// Loads the agent list and tracks the selected agent. Kept alive so the
  /// selection survives leaving the chat screen. (Persisting it across restarts
  /// is a TODO.)
  ///
  /// Both the list and the default come from Mantle rather than being derived
  /// here. `/api/agents` carries the rich rows (avatar, role) but is filtered
  /// only to conversational roles — it still includes DISABLED agents, which the
  /// web picker hides. `/api/assistant/thread` supplies the server's own answer
  /// to both questions, so the two are intersected: the app never re-implements
  /// the eligibility rule, and its default matches the agent the server would
  /// pick for this login when a turn omits `?agent=` (since v0.224 that is the
  /// login's own assigned assistant, not just the highest-priority agent).
  AgentControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'agentControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$agentControllerHash();

  @$internal
  @override
  AgentController create() => AgentController();
}

String _$agentControllerHash() => r'fd1ac314c5579a1badd38f4bbb54e3fc426872bf';

/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)
///
/// Both the list and the default come from Mantle rather than being derived
/// here. `/api/agents` carries the rich rows (avatar, role) but is filtered
/// only to conversational roles — it still includes DISABLED agents, which the
/// web picker hides. `/api/assistant/thread` supplies the server's own answer
/// to both questions, so the two are intersected: the app never re-implements
/// the eligibility rule, and its default matches the agent the server would
/// pick for this login when a turn omits `?agent=` (since v0.224 that is the
/// login's own assigned assistant, not just the highest-priority agent).

abstract class _$AgentController extends $AsyncNotifier<AgentsState> {
  FutureOr<AgentsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AgentsState>, AgentsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AgentsState>, AgentsState>,
              AsyncValue<AgentsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The active agent's slug — `null` while agents load or when there are none
/// (then Mantle uses its default agent). The chat reads this to scope history
/// and turns.

@ProviderFor(activeAgentSlug)
final activeAgentSlugProvider = ActiveAgentSlugProvider._();

/// The active agent's slug — `null` while agents load or when there are none
/// (then Mantle uses its default agent). The chat reads this to scope history
/// and turns.

final class ActiveAgentSlugProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// The active agent's slug — `null` while agents load or when there are none
  /// (then Mantle uses its default agent). The chat reads this to scope history
  /// and turns.
  ActiveAgentSlugProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeAgentSlugProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeAgentSlugHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return activeAgentSlug(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$activeAgentSlugHash() => r'29fdbf2348088f7b8c9655a7273e1c8eb2f69962';
