import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/agents/agent.dart';
import '../../data/agents/agent_api.dart';

part 'agent_controller.g.dart';

/// The owner's agents and which one the chat is currently talking to. [active]
/// defaults to the highest-priority agent (the API returns them priority-first).
class AgentsState {
  const AgentsState({required this.agents, this.active});

  final List<Agent> agents;
  final Agent? active;

  AgentsState copyWith({List<Agent>? agents, Agent? active}) =>
      AgentsState(agents: agents ?? this.agents, active: active ?? this.active);
}

/// Loads the agent list and tracks the selected agent. Kept alive so the
/// selection survives leaving the chat screen. (Persisting it across restarts
/// is a TODO.)
@Riverpod(keepAlive: true)
class AgentController extends _$AgentController {
  @override
  Future<AgentsState> build() async {
    final agents = await ref.read(agentApiProvider).list();
    return AgentsState(
      agents: agents,
      active: agents.isEmpty ? null : agents.first,
    );
  }

  /// Switch the active agent. The chat re-scopes to it (ChatController watches
  /// [activeAgentSlug]). No-op for an unknown slug or before agents load.
  void select(String slug) {
    final current = state.value;
    if (current == null) return;
    Agent? match;
    for (final a in current.agents) {
      if (a.slug == slug) {
        match = a;
        break;
      }
    }
    if (match == null || match.slug == current.active?.slug) return;
    state = AsyncData(current.copyWith(active: match));
  }
}

/// The active agent's slug — `null` while agents load or when there are none
/// (then Mantle uses its default agent). The chat reads this to scope history
/// and turns.
@riverpod
String? activeAgentSlug(Ref ref) =>
    ref.watch(agentControllerProvider).value?.active?.slug;
