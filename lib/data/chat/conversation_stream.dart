import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../core/network/auth_failure.dart';
import '../../core/network/dio_provider.dart';

part 'conversation_stream.g.dart';

/// One live conversation event from `GET /api/assistant/stream` (Server-Sent
/// Events). Mantle emits `data: {agentSlug, direction}` on every turn, on any
/// channel (the companion, web, Telegram, a heartbeat).
class ConversationEvent {
  const ConversationEvent({required this.agentSlug, required this.direction});

  final String agentSlug;

  /// `'inbound'` (from the user) or `'outbound'` (from the agent).
  final String direction;

  bool get fromUser => direction == 'inbound';

  static ConversationEvent? tryParse(Map<String, dynamic> json) {
    final slug = json['agentSlug'];
    if (slug is! String || slug.isEmpty) return null;
    final dir = json['direction'];
    return ConversationEvent(agentSlug: slug, direction: dir is String ? dir : '');
  }
}

/// Parse one SSE line into an event. Returns null for comments (`: ping`
/// heartbeats / `: connected`), non-`data:` lines, blank lines, or a malformed
/// payload. Pulled out as a pure function so it's unit-testable.
ConversationEvent? parseSseLine(String line) {
  if (!line.startsWith('data:')) return null;
  final body = line.substring(5).trim();
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return ConversationEvent.tryParse(decoded);
  } catch (_) {
    /* malformed payload — ignore this line */
  }
  return null;
}

const _initialBackoff = Duration(seconds: 1);
const _maxBackoff = Duration(seconds: 30);

/// Live conversation events while the app is foregrounded.
///
/// Opens the SSE stream through [dioProvider] (so the bearer is injected and a
/// 401/redirect is handled by the shared interceptor), decodes `data:` lines,
/// and reconnects with capped exponential backoff when the socket drops. It
/// **pauses** (closes the socket) while the app is backgrounded by watching
/// [appLifecycleProvider], and reconnects on resume. `autoDispose` tears the
/// connection down when nothing is listening (no chat/inbox on screen).
///
/// Consumers (`ChatController`, `ConversationsController`) `ref.listen` this and
/// refetch the affected thread / inbox on each event — the same
/// "ping-to-refetch" model Mantle's web realtime uses.
@riverpod
Stream<ConversationEvent> conversationEvents(Ref ref) async* {
  // Pause while backgrounded; resuming flips this and rebuilds the stream.
  if (ref.watch(appLifecycleProvider) != AppLifecycleState.resumed) return;

  final dio = ref.watch(dioProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);

  var backoff = _initialBackoff;
  while (true) {
    try {
      final res = await dio.get<ResponseBody>(
        '/api/assistant/stream',
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancel,
      );
      backoff = _initialBackoff; // reset after a clean open
      final lines = res.data!.stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in lines) {
        final event = parseSseLine(line);
        if (event != null) yield event;
      }
      // Server closed the stream cleanly (or it ended) — reconnect below.
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return; // provider disposed / app paused
      // A 401/redirect already triggered logout in the Dio interceptor, which
      // unmounts the chat/inbox → autoDisposes us; stop instead of hammering.
      if (isAuthFailure(e)) return;
      // otherwise a transient network/server error — fall through to backoff
    } catch (_) {
      /* unexpected — fall through to backoff */
    }
    await Future<void>.delayed(backoff);
    backoff = backoff * 2 > _maxBackoff ? _maxBackoff : backoff * 2;
  }
}
