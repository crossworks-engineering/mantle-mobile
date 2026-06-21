import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import '../location/location_ping.dart';
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

  /// `GET /api/assistant/turn/stage` — the coarse label for the responder's
  /// currently-running step (e.g. "Thinking…", "Searching the web…"), or null
  /// between mapped steps / when no turn is running. Polled while a send is in
  /// flight to animate the wait. Mirrors the web's stage indicator.
  Future<String?> turnStage() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/assistant/turn/stage',
    );
    final label = res.data?['label'];
    return label is String && label.isNotEmpty ? label : null;
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
    CancelToken? cancelToken,
    String? idempotencyKey,
    LocationPing? location,
  }) async {
    // `idempotency-key` lets the server replay a cached result instead of
    // re-running the turn if the same request is retried (e.g. a timeout where
    // it actually completed server-side) — no duplicate turn.
    final options = Options(
      receiveTimeout: const Duration(seconds: 120),
      headers: idempotencyKey == null
          ? null
          : {'idempotency-key': idempotencyKey},
    );
    final Response<Map<String, dynamic>> res;
    if (attachment != null) {
      final field = attachment.isImage ? 'image' : 'file';
      final form = FormData.fromMap({
        if (text.isNotEmpty) 'text': text,
        'agentSlug': ?agentSlug,
        // Multipart: location rides as one JSON-encoded form field.
        if (location != null) 'location': jsonEncode(location.toJson()),
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
        cancelToken: cancelToken,
      );
    } else {
      res = await _dio.post<Map<String, dynamic>>(
        '/api/assistant/turn',
        data: {
          'text': text,
          'agentSlug': ?agentSlug,
          if (location != null) 'location': location.toJson(),
        },
        options: options,
        cancelToken: cancelToken,
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
        // Sidecar artifacts the agent's tools produced this turn — a voice
        // reply (TTS audio) or a generated image. They carry live base64 bytes
        // (not persisted for web turns), so we stash them on disk and play /
        // show them inline. Absent on a plain text reply.
        attachments: await _attachmentsFromArtifacts(data['artifacts'] as List?),
      ),
    );
  }

  /// Turn outbound `artifacts[]` (live base64 audio/image) into attachments by
  /// writing each blob to a temp file the player / image widget can read. Non-
  /// audio/image kinds and empty payloads are skipped.
  Future<List<ChatAttachment>> _attachmentsFromArtifacts(List? artifacts) async {
    if (artifacts == null || artifacts.isEmpty) return const [];
    final out = <ChatAttachment>[];
    var i = 0;
    for (final raw in artifacts) {
      if (raw is! Map) continue;
      final kind = raw['kind'] as String?;
      final base64Str = raw['base64'] as String?;
      if (base64Str == null || base64Str.isEmpty) continue;
      final mime = raw['mimeType'] as String?;
      final caption = raw['caption'] as String?;
      final AttachmentKind attachmentKind;
      final String ext;
      if (kind == 'audio') {
        attachmentKind = AttachmentKind.audio;
        ext = _extForMime(mime, 'mp3');
      } else if (kind == 'image') {
        attachmentKind = AttachmentKind.image;
        ext = _extForMime(mime, 'png');
      } else {
        continue;
      }
      try {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/artifact-${DateTime.now().microsecondsSinceEpoch}-${i++}.$ext';
        await File(path).writeAsBytes(base64Decode(base64Str));
        out.add(ChatAttachment(
          kind: attachmentKind,
          localPath: path,
          mime: mime,
          caption: caption,
        ));
      } catch (_) {
        /* a bad blob shouldn't sink the whole reply — skip it */
      }
    }
    return out;
  }

  /// Pick a file extension from a MIME subtype (`audio/mpeg` → `mp3`), with a
  /// sensible fallback when the MIME is missing or odd.
  String _extForMime(String? mime, String fallback) {
    final sub = (mime ?? '').split('/').last.toLowerCase();
    switch (sub) {
      case 'mpeg':
      case 'mp3':
        return 'mp3';
      case 'mp4':
      case 'm4a':
      case 'aac':
        return 'm4a';
      case 'ogg':
      case 'opus':
        return 'ogg';
      case 'wav':
      case 'x-wav':
        return 'wav';
      case 'jpeg':
      case 'jpg':
        return 'jpg';
      case 'png':
      case 'webp':
      case 'gif':
        return sub;
      default:
        return fallback;
    }
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
