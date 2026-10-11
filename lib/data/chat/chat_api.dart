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
import 'turn_event.dart';
import 'turn_meta.dart';

part 'chat_api.g.dart';

/// The pair of messages a single turn produces: the user's saved message and
/// the assistant's reply.
class TurnResult {
  const TurnResult({required this.inbound, required this.outbound});
  final ChatMessage inbound;
  final ChatMessage outbound;
}

/// What `POST /api/assistant/turn` returned, in either of the server's two modes:
///
/// - [TurnAccepted] — live streaming is on: the server replied **202** with just
///   the turn id and runs the turn durably in apps/api. The caller subscribes to
///   [ChatApi.streamTurn] and reconciles to the durable row on `done`.
/// - [TurnCompleted] — the legacy blocking path (streaming flag dark): the server
///   ran the turn inline and returned the saved inbound + outbound messages.
///
/// The two are told apart by the response body shape, so the client degrades
/// gracefully whichever way the server is configured.
sealed class SendTurnResponse {
  const SendTurnResponse();
}

/// Streaming accepted (202): the turn is running; drive the UI off the stream.
class TurnAccepted extends SendTurnResponse {
  const TurnAccepted(this.turnId, {this.warnings = const []});

  /// The turn id (= the idempotency-key we sent) — the live-stream correlation
  /// id and the durable reconciliation handle.
  final String turnId;

  /// Non-fatal notes from the server (e.g. an attachment that couldn't be read).
  final List<String> warnings;
}

/// Legacy blocking result (200): the inbound + outbound rows are already final.
class TurnCompleted extends SendTurnResponse {
  const TurnCompleted(this.result);
  final TurnResult result;
}

// Capped exponential backoff for reconnecting a dropped turn stream.
const Duration _turnStreamInitialBackoff = Duration(seconds: 1);
const Duration _turnStreamMaxBackoff = Duration(seconds: 15);

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
    final rows = await fetchHistoryRaw(
      before: before,
      limit: limit,
      agentSlug: agentSlug,
    );
    return rows.map(messageFromHistory).toList();
  }

  /// The same page as [fetchHistory] but as the RAW server rows — the chat
  /// repository caches these verbatim so offline reads re-parse through
  /// [messageFromHistory] (cache and wire can never drift).
  Future<List<Map<String, dynamic>>> fetchHistoryRaw({
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
    return [for (final e in list) (e as Map).cast<String, dynamic>()];
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
  ///
  /// Returns a [TurnAccepted] when streaming is on (202 — drive off
  /// [streamTurn]) or a [TurnCompleted] for the legacy blocking path.
  Future<SendTurnResponse> sendTurn(
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

    // Streaming on: the server returns 202 with just { turnId } and runs the
    // turn durably in apps/api. Detect by the body shape (no inbound row) so
    // it's robust to how Dio surfaces the 202. The caller subscribes to the
    // live stream and reconciles to the durable row on `done`.
    final acceptedId = data['turnId'];
    if (data['inbound'] == null && acceptedId is String && acceptedId.isNotEmpty) {
      return TurnAccepted(acceptedId, warnings: _warningsOf(data));
    }

    final inbound = data['inbound'] as Map<String, dynamic>;
    final outbound = data['outbound'] as Map<String, dynamic>;
    return TurnCompleted(TurnResult(
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
    ));
  }

  static List<String> _warningsOf(Map<String, dynamic> data) {
    final raw = data['warnings'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  /// Subscribe to one turn's live event stream (`GET /api/assistant/turn/:id/
  /// stream`, Server-Sent Events). Yields each [TurnEvent] as it arrives and
  /// ENDS on the terminal `done`/`error` event. On a mid-turn socket drop it
  /// reconnects with capped backoff, sending `Last-Event-ID: <lastSeq>` so the
  /// server replays from its buffer (gap-free + duplicate-free). A 404 (the
  /// streaming flag is dark) or 401 (logged out) ends the stream so the caller
  /// falls back to the POST result / a history reconcile. Pass a [cancelToken]
  /// to tear it down (e.g. on screen dispose or Stop).
  Stream<TurnEvent> streamTurn(String turnId, {CancelToken? cancelToken}) async* {
    var lastSeq = -1;
    var backoff = _turnStreamInitialBackoff;
    while (true) {
      try {
        final res = await _dio.get<ResponseBody>(
          '/api/assistant/turn/$turnId/stream',
          options: Options(
            responseType: ResponseType.stream,
            // Resume from where we dropped; absent on the first connect so the
            // server replays this turn's whole buffer (seq starts at 0).
            headers: lastSeq >= 0 ? {'Last-Event-ID': '$lastSeq'} : null,
          ),
          cancelToken: cancelToken,
        );
        backoff = _turnStreamInitialBackoff; // reset after a clean open
        final lines = res.data!.stream
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final line in lines) {
          final event = parseTurnSseLine(line);
          if (event == null) continue;
          if (event.isUnsupportedSchema) {
            // The brain speaks a newer, breaking stream schema (`v` bumps only
            // on breaking changes) — don't risk misrendering its payloads.
            // Surface one status line saying why live streaming is off, then
            // end the stream; the caller falls back to the history reconcile,
            // exactly as when the streaming flag is dark.
            yield TurnEvent(
              v: kTurnEventSchemaVersion,
              turnId: turnId,
              seq: event.seq,
              round: 0,
              type: kTurnStatus,
              data: const {
                'label': 'Update the app to watch replies stream live',
              },
            );
            return;
          }
          lastSeq = event.seq;
          yield event;
          if (event.isTerminal) return; // turn finished — stop the stream
        }
        // Server closed without a terminal event — reconnect & resume below.
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) return; // torn down by the caller
        final code = e.response?.statusCode ?? 0;
        if (code == 404) return; // streaming flag dark → caller uses POST result
        if (code == 401) return; // interceptor handled logout
        // Not this login's route (a member has no live stream): asking again
        // would only be refused again. The caller reconciles from history.
        if (code == 403) return;
        // otherwise transient — fall through to backoff
      } catch (_) {
        /* unexpected — fall through to backoff */
      }
      await Future<void>.delayed(backoff);
      backoff =
          backoff * 2 > _turnStreamMaxBackoff ? _turnStreamMaxBackoff : backoff * 2;
    }
  }

  /// `POST /api/assistant/turn/:id/cancel` — ask the runner to stop an in-flight
  /// streamed turn. The runner aborts the LLM and finalizes whatever partial
  /// reply had streamed, so the turn ends with a normal `done` event (the caller
  /// reconciles as usual). Best-effort: a 404 (streaming flag dark) or any other
  /// error is swallowed — the caller's local teardown + the `done` reconcile
  /// cover the rest.
  Future<void> cancelTurn(String turnId) async {
    try {
      await _dio.post<Map<String, dynamic>>('/api/assistant/turn/$turnId/cancel');
    } catch (_) {
      /* fire-and-forget — the runner does the real abort */
    }
  }

  /// Stop an in-flight streamed turn AND mark its message pair replaced by
  /// [newTurnId], the combined turn about to be sent. The server stamps both
  /// rows before it cancels, so the caller must AWAIT this before posting the
  /// combined turn: that order keeps the abandoned pair out of the new turn's
  /// prompt. Unlike [cancelTurn] this throws on failure; the caller must not
  /// send the combined turn when the old pair was not stamped.
  Future<void> supersedeTurn(
    String turnId, {
    required String inboundId,
    required String outboundId,
    required String newTurnId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/assistant/turn/$turnId/cancel',
      data: {
        'supersede': {
          'inboundId': inboundId,
          'outboundId': outboundId,
          'newTurnId': newTurnId,
        },
      },
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

  /// Parse one raw `/api/assistant/messages` row. Public because the offline
  /// cache stores raw rows and re-parses them through this exact path.
  ChatMessage messageFromHistory(Map<String, dynamic> j) {
    final attachments = ((j['attachments'] as List?) ?? const [])
        .map((e) => ChatAttachment.fromHistoryJson(e as Map<String, dynamic>))
        .whereType<ChatAttachment>()
        .toList();
    // Server execution status (migration 0105): 'pending' while the durable
    // runner works, 'failed' when the turn errored, else complete. Missing on
    // older brains → sent.
    final status = switch (j['status']) {
      'pending' => MessageStatus.pending,
      'failed' => MessageStatus.failed,
      _ => MessageStatus.sent,
    };
    return ChatMessage(
      id: j['id'] as String,
      direction: j['direction'] == 'inbound'
          ? MessageDirection.inbound
          : MessageDirection.outbound,
      text: (j['text'] as String?) ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      model: j['model'] as String?,
      status: status,
      error: j['error'] as String?,
      attachments: attachments,
      thoughts: ThoughtStep.listFrom(j['thoughts']),
      toolStats: ToolStats.tryParse(j['toolStats']),
      superseded: j['superseded'] == true,
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
