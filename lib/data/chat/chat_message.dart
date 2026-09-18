import 'chat_attachment.dart';
import 'turn_meta.dart';

/// Who a message is from. Mirrors Mantle's `direction`:
/// `inbound` = from the user (us), `outbound` = from the assistant.
enum MessageDirection { inbound, outbound }

/// Delivery / execution state for a message.
///
/// [sending] and [failed]-on-inbound are LOCAL optimistic states for a message
/// we're posting. [pending] and [failed]-on-outbound mirror the server's
/// execution `status` (migration 0105): an outbound row is `pending` while the
/// durable runner works — so a reload mid-turn renders a live "thinking"
/// bubble — and `failed` when the turn errored (with [ChatMessage.error]).
/// [queued] is a LOCAL state: the send hit a dead network and sits in the
/// offline outbox — it will replay (same idempotency key) on the next flush.
enum MessageStatus { sending, sent, pending, failed, queued }

/// A single assistant-thread message. Unified shape over the two Mantle
/// payloads (history rows and turn inbound/outbound) — see [ChatApi].
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.direction,
    required this.text,
    required this.createdAt,
    this.model,
    this.status = MessageStatus.sent,
    this.error,
    this.attachments = const [],
    this.thoughts = const [],
    this.toolStats,
    this.superseded = false,
  });

  final String id;
  final MessageDirection direction;
  final String text;
  final DateTime createdAt;

  /// The model that produced an assistant reply (outbound only); null otherwise.
  final String? model;

  /// Local optimistic state for outgoing sends, or the server's execution
  /// status for history rows (see [MessageStatus]).
  final MessageStatus status;

  /// Human-readable failure reason when [status] is [MessageStatus.failed] on
  /// an outbound row; null otherwise.
  final String? error;

  /// Images / files riding on this message — shown inline (images) or as a
  /// labeled chip (everything else). See [ChatAttachment].
  final List<ChatAttachment> attachments;

  /// Persisted thought trail (outbound rows, when the brain keeps it) — the
  /// "Thought process" record that survives a reload.
  final List<ThoughtStep> thoughts;

  /// The turn's persisted tool-outcome tally ("N tool calls · M failed");
  /// null when the turn ran no tools or the brain predates it.
  final ToolStats? toolStats;

  /// This row belongs to a replaced turn pair: the user stopped the turn
  /// mid-stream and re-sent it with a correction. The brain keeps the pair out
  /// of later prompts; the thread shows it dimmed with a "Replaced" tag.
  final bool superseded;

  bool get isFromUser => direction == MessageDirection.inbound;

  ChatMessage copyWith({
    String? id,
    String? text,
    MessageStatus? status,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      direction: direction,
      text: text ?? this.text,
      createdAt: createdAt,
      model: model,
      status: status ?? this.status,
      error: error,
      attachments: attachments ?? this.attachments,
      thoughts: thoughts,
      toolStats: toolStats,
      superseded: superseded,
    );
  }
}
