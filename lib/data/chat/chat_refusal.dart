import 'package:dio/dio.dart';

/// What to tell the person when the brain refused a message, from the
/// answer to `POST /api/assistant/turn`. Null for a failure that is not a
/// refusal (the network, a server error): the bubble then just says it
/// failed and offers a retry.
///
/// A login that is not an Admin user chats under limits the brain keeps
/// (workspaces W7c): six messages a minute, a daily message cap and a daily
/// token budget, text only. Each refusal says which, so the person knows
/// whether waiting a moment, waiting a day or asking an admin helps.
String? chatRefusalText(Object error) {
  if (error is! DioException) return null;
  final res = error.response;
  final code = res?.statusCode;
  if (code == null) return null;
  final data = res?.data;
  final reason = data is Map ? data['reason'] : null;
  final said = data is Map ? data['error'] : null;
  final brainSays = said is String && said.trim().isNotEmpty ? said.trim() : null;
  switch (code) {
    case 429:
      if (reason == 'daily_cap') {
        return "You have reached today's message limit. Try again tomorrow.";
      }
      if (reason == 'token_budget') {
        return "Today's chat budget is used up. Try again tomorrow, or ask "
            'an admin to raise it.';
      }
      return 'Too many messages at once. Wait a moment and send it again.';
    case 409:
      if (reason == 'idempotency-key-reused') {
        return 'That message was already sent with other words. Send it '
            'again.';
      }
      return brainSays;
    case 404:
      if (reason == 'no-chat-agent') {
        return 'There is no assistant to chat with in this workspace.';
      }
      return null;
    case 415:
      return 'This chat takes text only. Send the message without the file.';
    case 413:
      return brainSays ?? 'That file is too large.';
    case 400:
      return brainSays;
    case 403:
      return brainSays ?? 'This login cannot chat here.';
    default:
      return null;
  }
}
