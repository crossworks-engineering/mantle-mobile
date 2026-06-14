import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'chat_attachment.dart';
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

  /// `POST /api/assistant/turn` — send [text] (and optionally an [attachment]),
  /// get back the saved inbound message and the assistant's outbound reply.
  ///
  /// Text-only turns go as JSON; an attachment is posted as multipart
  /// (`image` for pictures, `file` for documents) so the bytes stream without
  /// base64 bloat — mirroring the web composer. Either text or an attachment
  /// must be present (the server fills a default prompt for attachment-only).
  /// Long receive timeout: the assistant generates inline.
  Future<TurnResult> sendTurn(
    String text, {
    String? agentSlug,
    OutgoingAttachment? attachment,
  }) async {
    final options = Options(receiveTimeout: const Duration(seconds: 120));
    final Response<Map<String, dynamic>> res;
    if (attachment != null) {
      final field = attachment.isImage ? 'image' : 'file';
      final form = FormData.fromMap({
        if (text.isNotEmpty) 'text': text,
        'agentSlug': ?agentSlug,
        field: await MultipartFile.fromFile(
          attachment.path,
          filename: attachment.filename,
          contentType: DioMediaType.parse(attachment.mime),
        ),
      });
      res = await _dio.post<Map<String, dynamic>>(
        '/api/assistant/turn',
        data: form,
        options: options,
      );
    } else {
      res = await _dio.post<Map<String, dynamic>>(
        '/api/assistant/turn',
        data: {'text': text, 'agentSlug': ?agentSlug},
        options: options,
      );
    }
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

  /// `POST /api/assistant/transcribe` — multipart audio in, transcript out.
  /// Routes through Mantle's default STT worker (same as Telegram voice notes).
  /// Returns the trimmed transcript; throws (DioException) on 4xx — notably 412
  /// "no STT worker configured" and 422 "couldn't transcribe", whose messages
  /// the composer surfaces verbatim.
  Future<String> transcribe(
    String audioPath, {
    String filename = 'recording.m4a',
    String mime = 'audio/mp4',
  }) async {
    final form = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        audioPath,
        filename: filename,
        contentType: DioMediaType.parse(mime),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/assistant/transcribe',
      data: form,
      options: Options(receiveTimeout: const Duration(seconds: 60)),
    );
    return (res.data?['text'] as String?)?.trim() ?? '';
  }

  ChatMessage _messageFromHistory(Map<String, dynamic> j) {
    final attachments = ((j['attachments'] as List?) ?? const [])
        .map((e) => ChatAttachment.fromHistoryJson(e as Map<String, dynamic>))
        .whereType<ChatAttachment>()
        .toList();
    return ChatMessage(
      id: j['id'] as String,
      direction: j['direction'] == 'inbound'
          ? MessageDirection.inbound
          : MessageDirection.outbound,
      text: (j['text'] as String?) ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      model: j['model'] as String?,
      attachments: attachments,
    );
  }
}

@Riverpod(keepAlive: true)
ChatApi chatApi(Ref ref) {
  return ChatApi(ref.watch(dioProvider));
}

/// Raw bytes of a Mantle file node (`GET /api/files/files/{nodeId}?raw=1`),
/// fetched through the authed [Dio]. Backs inline image attachments when
/// history reloads (the just-sent path renders from disk instead). Returns null
/// on any failure so the renderer falls back to a chip. Kept alive so an image
/// isn't re-fetched every time the list rebuilds while scrolling.
@Riverpod(keepAlive: true)
Future<Uint8List?> fileBytes(Ref ref, String nodeId) async {
  try {
    final res = await ref.watch(dioProvider).get<List<int>>(
      '/api/files/files/$nodeId',
      queryParameters: {'raw': 1},
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    return data == null ? null : Uint8List.fromList(data);
  } catch (_) {
    return null;
  }
}
