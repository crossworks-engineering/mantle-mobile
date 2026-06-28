import 'package:dio/dio.dart' show CancelToken;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../location/location_ping.dart';
import 'chat_api.dart';
import 'chat_attachment.dart';
import 'chat_message.dart';
import 'turn_event.dart';

part 'chat_repository.g.dart';

/// Messages fetched per page — the initial load and each scroll-up fetch.
const int chatPageSize = 30;

/// Seam between the chat UI and Mantle. Today it's a thin pass-through over
/// [ChatApi]; it's where an on-device Drift cache and an offline send-queue
/// will live (so history reads locally and outgoing messages survive offline).
class ChatRepository {
  ChatRepository(this._api);

  final ChatApi _api;

  Future<List<ChatMessage>> history({
    DateTime? before,
    int limit = chatPageSize,
    String? agentSlug,
  }) => _api.fetchHistory(before: before, limit: limit, agentSlug: agentSlug);

  Future<SendTurnResponse> send(
    String text, {
    String? agentSlug,
    OutgoingAttachment? attachment,
    CancelToken? cancelToken,
    String? idempotencyKey,
    LocationPing? location,
  }) =>
      _api.sendTurn(
        text,
        agentSlug: agentSlug,
        attachment: attachment,
        cancelToken: cancelToken,
        idempotencyKey: idempotencyKey,
        location: location,
      );

  /// Live events for one in-flight streamed turn (ends on `done`/`error`).
  Stream<TurnEvent> streamTurn(String turnId, {CancelToken? cancelToken}) =>
      _api.streamTurn(turnId, cancelToken: cancelToken);

  /// Ask the runner to stop an in-flight streamed turn (keeps the partial).
  Future<void> cancelTurn(String turnId) => _api.cancelTurn(turnId);

  /// The responder's current stage label (or null), for the typing indicator.
  Future<String?> turnStage() => _api.turnStage();

  /// Transcribe a recorded voice note to text (used by the composer's mic).
  Future<String> transcribe(String audioPath) => _api.transcribe(audioPath);
}

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return ChatRepository(ref.watch(chatApiProvider));
}
