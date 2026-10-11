import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/agents/agent.dart';
import '../../data/auth/login_access.dart';
import '../../data/auth/session_repository.dart';
import '../../data/db/database_provider.dart';
import '../../data/workspaces/workspaces_api.dart';
import '../agents/agent_controller.dart';
import '../auth/login_access_controller.dart';

part 'workspace_controller.g.dart';

/// The `app_settings` key the workspace in use is kept under, per login.
String workspaceKey(String sessionId) => 'workspace.$sessionId';

/// The workspace the phone is in, chosen in the drawer's switcher and kept
/// on the device per login. Null on a brain from before workspaces (whoami
/// lists none): the phone then is what it always was.
///
/// A choice the login no longer has (it left the workspace, or it was
/// archived) falls back to the default: an Admin user's Admin workspace,
/// anyone else's first shared one.
@Riverpod(keepAlive: true)
class CurrentWorkspace extends _$CurrentWorkspace {
  @override
  Future<ShellWorkspace?> build() async {
    final access = await ref.watch(loginAccessControllerProvider.future);
    if (access.workspaces.isEmpty) return null;
    final sessionId = await ref.read(sessionRepositoryProvider).activeId();
    String? stored;
    if (sessionId != null && sessionId.isNotEmpty) {
      stored = await ref
          .read(appDatabaseProvider)
          .getSetting(workspaceKey(sessionId));
    }
    return access.workspaceById(stored) ?? access.defaultWorkspace;
  }

  /// Use the workspace [id]. No-op for one the login is not in.
  Future<void> select(String id) async {
    final access = ref.read(loginAccessControllerProvider).value;
    final ws = access?.workspaceById(id);
    if (ws == null) return;
    final sessionId = await ref.read(sessionRepositoryProvider).activeId();
    if (sessionId != null && sessionId.isNotEmpty) {
      await ref
          .read(appDatabaseProvider)
          .setSetting(workspaceKey(sessionId), ws.id);
    }
    if (ref.mounted) state = AsyncData(ws);
  }
}

/// Every workspace row the login reads (`GET /api/workspaces`), for each
/// one's assistant. Empty when the brain cannot say (offline, an older
/// brain): the chat then keeps the owner surface's agent choice.
@Riverpod(keepAlive: true)
Future<List<WorkspaceRow>> workspaceRows(Ref ref) async {
  final api = ref.watch(workspacesApiProvider);
  // Rebuilt when whoami changes: a workspace joined or left on the web.
  await ref.watch(loginAccessControllerProvider.future);
  try {
    return await api.list();
  } catch (_) {
    return const [];
  }
}

/// The ids of the assistants of workspaces other than Admin. Such an
/// assistant runs the workspace turn engine: text only, for every login.
@Riverpod(keepAlive: true)
Future<Set<String>> workspaceAgentIds(Ref ref) async {
  final rows = await ref.watch(workspaceRowsProvider.future);
  return {
    for (final r in rows)
      if (!r.isAdmin && r.assistant != null) r.assistant!.id,
  };
}

/// Where the Chat button goes in the workspace in use.
sealed class ChatTarget {
  const ChatTarget();
}

/// The owner surface's inbox (the Admin workspace, or a brain from before
/// workspaces): every agent the login may chat with.
class ChatInbox extends ChatTarget {
  const ChatInbox();
}

/// The workspace's own assistant.
class ChatWithAssistant extends ChatTarget {
  const ChatWithAssistant(this.agent, this.workspace);
  final Agent agent;
  final ShellWorkspace workspace;
}

/// The workspace has no assistant this login may chat with.
class NoAssistantHere extends ChatTarget {
  const NoAssistantHere(this.workspace);
  final ShellWorkspace workspace;
}

/// Pure: the chat target for [workspace], given every workspace row and the
/// agents the login may chat with.
ChatTarget chatTargetFor({
  required ShellWorkspace? workspace,
  required List<WorkspaceRow> rows,
  required List<Agent> agents,
}) {
  if (workspace == null || workspace.isAdmin) return const ChatInbox();
  WorkspaceRow? row;
  for (final r in rows) {
    if (r.id == workspace.id) row = r;
  }
  final assistantId = row?.assistant?.id;
  if (assistantId == null) {
    // The brain could not list the workspaces: the inbox still lists the
    // assistants this login may reach.
    return rows.isEmpty ? const ChatInbox() : NoAssistantHere(workspace);
  }
  for (final a in agents) {
    if (a.id == assistantId) return ChatWithAssistant(a, workspace);
  }
  return NoAssistantHere(workspace);
}

/// Where the Chat button goes now.
@riverpod
Future<ChatTarget> chatTarget(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null || workspace.isAdmin) return const ChatInbox();
  final rows = await ref.watch(workspaceRowsProvider.future);
  final agents = (await ref.watch(agentControllerProvider.future)).agents;
  return chatTargetFor(workspace: workspace, rows: rows, agents: agents);
}
