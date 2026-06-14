import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'conversation_models.dart';

part 'conversations_api.g.dart';

/// The assistant conversations inbox + read cursor.
class ConversationsApi {
  ConversationsApi(this._dio);

  final Dio _dio;

  /// `GET /api/assistant/conversations` — agents with last-message previews and
  /// unread counts, most-recent first.
  Future<List<AgentConversation>> list() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/assistant/conversations',
    );
    final rows = (res.data?['conversations'] as List?) ?? const [];
    return rows
        .map((e) => AgentConversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /api/assistant/read` — mark an agent's thread read (clears unread).
  Future<void> markRead(String agentSlug) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/assistant/read',
      data: {'agentSlug': agentSlug},
    );
  }
}

@Riverpod(keepAlive: true)
ConversationsApi conversationsApi(Ref ref) =>
    ConversationsApi(ref.watch(dioProvider));
