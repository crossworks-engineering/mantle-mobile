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

@ProviderFor(AgentController)
final agentControllerProvider = AgentControllerProvider._();

/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)
final class AgentControllerProvider
    extends $AsyncNotifierProvider<AgentController, AgentsState> {
  /// Loads the agent list and tracks the selected agent. Kept alive so the
  /// selection survives leaving the chat screen. (Persisting it across restarts
  /// is a TODO.)
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

String _$agentControllerHash() => r'3e12d0c6d09e9efb315fe29253fb91fcbb2ec07b';

/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)

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
