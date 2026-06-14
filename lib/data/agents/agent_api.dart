import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'agent.dart';

part 'agent_api.g.dart';

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
