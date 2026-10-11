import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/agents/agent.dart';
import '../../data/agents/agent_api.dart';
import '../auth/login_access_controller.dart';

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
///
/// Both the list and the default come from Mantle rather than being derived
/// here. `/api/agents` carries the rich rows (avatar, role) but is filtered
/// only to conversational roles — it still includes DISABLED agents, which the
/// web picker hides. `/api/assistant/thread` supplies the server's own answer
/// to both questions, so the two are intersected: the app never re-implements
/// the eligibility rule, and its default matches the agent the server would
/// pick for this login when a turn omits `?agent=` (since v0.224 that is the
/// login's own assigned assistant, not just the highest-priority agent).
@Riverpod(keepAlive: true)
class AgentController extends _$AgentController {
  @override
  Future<AgentsState> build() async {
    final api = ref.read(agentApiProvider);
    // A login without the assistants area (a member, or an Admin user whose
    // area is off) cannot read `/api/agents`: its agents are the ones the
    // thread route names, the assistants of its own workspaces.
    final access = await ref.watch(loginAccessControllerProvider.future);
    if (!access.agentCatalog) {
      final info = await api.threadInfo();
      final agents = info?.agents ?? const <Agent>[];
      Agent? active;
      for (final a in agents) {
        if (a.slug == info?.defaultSlug) active = a;
      }
      return AgentsState(
        agents: agents,
        active: active ?? (agents.isEmpty ? null : agents.first),
      );
    }
    // Both in flight together — the thread call is best-effort, so a failure
    // there must not cost the user their agent list.
    final results = await (api.list(), api.threadInfo()).wait;
    final all = results.$1;
    final info = results.$2;

    // Intersect only when the server answered with a non-empty set; an older
    // route, a failed call, or an unrecognised shape leaves the previous
    // behaviour (every conversational agent) intact rather than emptying the
    // picker on a response we didn't understand.
    final eligible = info?.chattableSlugs ?? const <String>{};
    final agents = eligible.isEmpty
        ? all
        : [
            for (final a in all)
              if (eligible.contains(a.slug)) a,
          ];

    Agent? active;
    for (final a in agents) {
      if (a.slug == info?.defaultSlug) {
        active = a;
        break;
      }
    }

    return AgentsState(
      agents: agents,
      active: active ?? (agents.isEmpty ? null : agents.first),
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
