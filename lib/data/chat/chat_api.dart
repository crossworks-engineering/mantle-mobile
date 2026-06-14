import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'chat_message.dart';

part 'chat_api.g.dart';

/// The pair of messages a single turn produces: the user's saved message and
/// the assistant's reply.
class TurnResult {
  const TurnResult({required this.inbound, required this.outbound});
  final ChatMessage inbound;
  final ChatMessage outbound;
}

/// Talks to Mantle's assistant endpoints over the authenticated [Dio].
class ChatApi {
  ChatApi(this._dio);

  final Dio _dio;

  /// `GET /api/assistant/messages` — the page of messages before [before]
  /// (default now), oldest-first within the page.
  Future<List<ChatMessage>> fetchHistory({
    DateTime? before,
    int limit = 100,
    String? agentSlug,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/assistant/messages',
      queryParameters: {
        'before': (before ?? DateTime.now()).toUtc().toIso8601String(),
        'limit': limit,
        'agent': ?agentSlug,
      },
    );
    final list = (res.data?['messages'] as List?) ?? const [];
    return list
        .map((e) => _messageFromHistory(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /api/assistant/turn` — send [text], get back the saved inbound
  /// message and the assistant's outbound reply. Uses a long receive timeout
  /// since the assistant generates inline.
  Future<TurnResult> sendTurn(String text, {String? agentSlug}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/assistant/turn',
      data: {'text': text, 'agentSlug': ?agentSlug},
      options: Options(receiveTimeout: const Duration(seconds: 120)),
    );
    final data = res.data ?? const {};
    final inbound = data['inbound'] as Map<String, dynamic>;
    final outbound = data['outbound'] as Map<String, dynamic>;
    return TurnResult(
      inbound: ChatMessage(
        id: inbound['id'] as String,
        direction: MessageDirection.inbound,
        text: (inbound['text'] as String?) ?? text,
        createdAt: DateTime.parse(inbound['createdAt'] as String),
      ),
      outbound: ChatMessage(
        id: outbound['id'] as String,
        direction: MessageDirection.outbound,
        text: (outbound['text'] as String?) ?? (data['reply'] as String? ?? ''),
        createdAt: DateTime.parse(outbound['createdAt'] as String),
        model: outbound['model'] as String?,
      ),
    );
  }

  ChatMessage _messageFromHistory(Map<String, dynamic> j) {
    return ChatMessage(
      id: j['id'] as String,
      direction: j['direction'] == 'inbound'
          ? MessageDirection.inbound
          : MessageDirection.outbound,
      text: (j['text'] as String?) ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      model: j['model'] as String?,
    );
  }
}

@Riverpod(keepAlive: true)
ChatApi chatApi(Ref ref) {
  return ChatApi(ref.watch(dioProvider));
}
