import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'agent.dart';

part 'agent_api.g.dart';

/// Mantle's own answer to "which agents may this login chat to, and which one
/// is it talking to by default" — from `GET /api/assistant/thread`.
///
/// Both halves are rules the app must not re-implement. [chattableSlugs] is
/// filtered to conversational roles AND `enabled`, which `/api/agents` is not;
/// [defaultSlug] is `resolveAgentForActor`, which since Mantle v0.224 prefers
/// the agent bound to THIS login (`agents.assigned_user_id`) over the
/// brain-wide priority default. The web client holds a sticky agent cookie and
/// needs an `assignedAt` watermark to adopt a new assignment; the app has no
/// such cookie, so the resolved agent is simply the answer.
class AssistantThreadInfo {
  const AssistantThreadInfo({
    required this.chattableSlugs,
    required this.defaultSlug,
  });

  final Set<String> chattableSlugs;
  final String? defaultSlug;
}

/// Reads the owner's agents from Mantle (`GET /api/agents`, priority-ordered).
class AgentApi {
  AgentApi(this._dio);

  final Dio _dio;

  Future<List<Agent>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/agents');
    final rows = (res.data?['agents'] as List?) ?? const [];
    return rows
        .map((e) => Agent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/assistant/thread?withMessages=0` — the picker list and the
  /// resolved active agent, WITHOUT the 100-message thread (the chat screen
  /// pages its own history through the Drift cache, so those rows would be
  /// fetched and dropped on every cold start).
  ///
  /// `withMessages` is additive: a server that predates it ignores the param
  /// and returns the thread as well, which we simply don't read. Returns null
  /// on any transport/HTTP failure — including a server old enough to lack the
  /// route entirely (pre-v0.79.0) — so the caller falls back to its previous
  /// behaviour rather than leaving the user with no agents at all.
  Future<AssistantThreadInfo?> threadInfo() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/assistant/thread',
        queryParameters: {'withMessages': 0},
      );
      final data = res.data;
      if (data == null) return null;
      final rows = (data['agents'] as List?) ?? const [];
      final slugs = <String>{
        for (final e in rows)
          if (e is Map && e['slug'] is String) e['slug'] as String,
      };
      final agent = data['agent'];
      final defaultSlug = agent is Map && agent['slug'] is String
          ? agent['slug'] as String
          : null;
      return AssistantThreadInfo(
        chattableSlugs: slugs,
        defaultSlug: defaultSlug,
      );
    } catch (_) {
      return null;
    }
  }
}

@Riverpod(keepAlive: true)
AgentApi agentApi(Ref ref) => AgentApi(ref.watch(dioProvider));

/// The agent's generated avatar as an SVG string (`GET /api/agents/{slug}/avatar`),
/// or `null` if the agent has none (404) or the fetch fails — the UI then shows
/// the initials fallback. Kept alive so avatars aren't re-fetched on rebuild.
@Riverpod(keepAlive: true)
Future<String?> agentAvatarSvg(Ref ref, String slug) async {
  try {
    final res = await ref.watch(dioProvider).get<String>(
      '/api/agents/$slug/avatar',
      queryParameters: {'size': 96},
      options: Options(responseType: ResponseType.plain),
    );
    final data = res.data;
    return (data != null && data.contains('<svg')) ? data : null;
  } catch (_) {
    return null;
  }
}
