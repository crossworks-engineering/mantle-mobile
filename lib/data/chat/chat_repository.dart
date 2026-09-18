import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import '../location/location_ping.dart';
import 'chat_api.dart';
import 'chat_attachment.dart';
import 'chat_message.dart';
import 'turn_event.dart';

part 'chat_repository.g.dart';

/// Messages fetched per page — the initial load and each scroll-up fetch.
const int chatPageSize = 30;

/// True when an error means "the network is unreachable" rather than "the
/// server answered badly". Only these enqueue to the offline outbox / serve
/// the read cache — a 4xx/5xx keeps the existing failed-bubble path.
/// `receiveTimeout` is deliberately NOT offline: the server may have received
/// the turn, and the idempotent retry path already covers it.
bool isOfflineError(Object e) {
  if (e is! DioException) return false;
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
      return true;
    case DioExceptionType.unknown:
      return e.error is SocketException;
    default:
      return false;
  }
}

/// Thrown by [ChatRepository.send] when a text-only turn couldn't reach the
/// server and was queued instead — the controller renders a `queued` bubble
/// rather than a failed one.
class TurnQueuedOffline implements Exception {
  const TurnQueuedOffline(this.turnId);

  /// The queued turn's idempotency key (= its outbox row id).
  final String turnId;
}

/// One fetched history page, plus where it came from — [fromCache] is true
/// only when the network was unreachable and the on-device cache answered.
class HistoryPage {
  const HistoryPage({required this.messages, this.fromCache = false});

  final List<ChatMessage> messages;
  final bool fromCache;
}

/// Seam between the chat UI and Mantle. Network-first with an on-device
/// Drift fallback:
///
/// - **Read cache** — every fetched latest page is cached as RAW server rows
///   (re-parsed through [ChatApi.messageFromHistory], so cache and wire share
///   one parser). When the network is unreachable the cache answers instead,
///   flagged via [HistoryPage.fromCache].
/// - **Send-queue** — a text-only turn that fails on connectivity is queued
///   (keyed by its idempotency key) and [TurnQueuedOffline] is thrown;
///   [flushOutbox] replays queued turns oldest-first. Attachment turns are
///   never queued — their bytes' lifetime on disk isn't ours to manage.
class ChatRepository {
  ChatRepository(this._api, this._db);

  final ChatApi _api;
  final AppDatabase _db;

  Future<HistoryPage> history({
    DateTime? before,
    int limit = chatPageSize,
    String? agentSlug,
  }) async {
    final isLatestPage = before == null;
    try {
      final rows = await _api.fetchHistoryRaw(
        before: before,
        limit: limit,
        agentSlug: agentSlug,
      );
      final messages = rows.map(_api.messageFromHistory).toList();
      if (isLatestPage && agentSlug != null) {
        await _cacheRows(agentSlug, rows, messages);
      }
      return HistoryPage(messages: messages);
    } catch (e) {
      // Only the latest page falls back to cache (older pages beyond the
      // cached window can't be answered honestly offline).
      if (isLatestPage && agentSlug != null && isOfflineError(e)) {
        final cached = await _db.cachedChatRows(agentSlug);
        if (cached.isNotEmpty) {
          return HistoryPage(
            messages: [
              for (final json in cached)
                _api.messageFromHistory(
                  (jsonDecode(json) as Map).cast<String, dynamic>(),
                ),
            ],
            fromCache: true,
          );
        }
      }
      rethrow;
    }
  }

  Future<void> _cacheRows(
    String agentSlug,
    List<Map<String, dynamic>> rows,
    List<ChatMessage> messages,
  ) async {
    try {
      await _db.cacheChatRows(agentSlug, [
        for (var i = 0; i < rows.length; i++)
          (
            id: messages[i].id,
            json: jsonEncode(rows[i]),
            createdAt: messages[i].createdAt,
          ),
      ]);
    } catch (_) {
      /* cache writes are best-effort — never fail a successful fetch */
    }
  }

  Future<SendTurnResponse> send(
    String text, {
    String? agentSlug,
    OutgoingAttachment? attachment,
    CancelToken? cancelToken,
    String? idempotencyKey,
    LocationPing? location,
  }) async {
    try {
      return await _api.sendTurn(
        text,
        agentSlug: agentSlug,
        attachment: attachment,
        cancelToken: cancelToken,
        idempotencyKey: idempotencyKey,
        location: location,
      );
    } catch (e) {
      final queueable = attachment == null &&
          agentSlug != null &&
          idempotencyKey != null &&
          isOfflineError(e);
      if (!queueable) rethrow;
      await _db.enqueueOutboxTurn(
        id: idempotencyKey,
        agentSlug: agentSlug,
        body: text,
        locationJson: location == null ? null : jsonEncode(location.toJson()),
      );
      throw TurnQueuedOffline(idempotencyKey);
    }
  }

  /// Queued turns for one agent, oldest-first — the controller renders these
  /// as `queued` bubbles at the end of the thread.
  Future<List<OutboxTurn>> queuedTurns(String agentSlug) =>
      _db.outboxTurnsFor(agentSlug);

  /// Replay queued turns oldest-first with their original idempotency keys.
  /// Stops at the first connectivity failure (still offline). A turn the
  /// server REJECTS (4xx/5xx) is retried on later flushes and dropped after
  /// [maxAttempts] so one poisoned row can't wedge the queue forever.
  /// Returns how many turns were delivered.
  Future<int> flushOutbox(String agentSlug, {int maxAttempts = 3}) async {
    var delivered = 0;
    for (final turn in await _db.outboxTurnsFor(agentSlug)) {
      try {
        await _api.sendTurn(
          turn.body,
          agentSlug: agentSlug,
          idempotencyKey: turn.id,
          location: _decodeLocation(turn.locationJson),
        );
        await _db.deleteOutboxTurn(turn.id);
        delivered++;
      } catch (e) {
        if (isOfflineError(e)) return delivered; // still offline — stop
        if (turn.attempts + 1 >= maxAttempts) {
          await _db.deleteOutboxTurn(turn.id); // poisoned — give up on it
        } else {
          await _db.bumpOutboxAttempts(turn.id);
        }
      }
    }
    return delivered;
  }

  LocationPing? _decodeLocation(String? json) {
    if (json == null) return null;
    try {
      return LocationPing.fromJson(
        (jsonDecode(json) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Live events for one in-flight streamed turn (ends on `done`/`error`).
  Stream<TurnEvent> streamTurn(String turnId, {CancelToken? cancelToken}) =>
      _api.streamTurn(turnId, cancelToken: cancelToken);

  /// Ask the runner to stop an in-flight streamed turn (keeps the partial).
  Future<void> cancelTurn(String turnId) => _api.cancelTurn(turnId);

  /// Stop an in-flight turn and mark its pair replaced by [newTurnId]. Throws
  /// on failure (see [ChatApi.supersedeTurn]).
  Future<void> supersedeTurn(
    String turnId, {
    required String inboundId,
    required String outboundId,
    required String newTurnId,
  }) =>
      _api.supersedeTurn(
        turnId,
        inboundId: inboundId,
        outboundId: outboundId,
        newTurnId: newTurnId,
      );

  /// The responder's current stage label (or null), for the typing indicator.
  Future<String?> turnStage() => _api.turnStage();

  /// Transcribe a recorded voice note to text (used by the composer's mic).
  Future<String> transcribe(String audioPath) => _api.transcribe(audioPath);
}

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(
    ref.watch(chatApiProvider),
    ref.watch(appDatabaseProvider),
  );
}
