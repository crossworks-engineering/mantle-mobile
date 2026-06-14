/// Who a message is from. Mirrors Mantle's `direction`:
/// `inbound` = from the user (us), `outbound` = from the assistant.
enum MessageDirection { inbound, outbound }

/// Delivery state for an outgoing message (optimistic UI).
enum MessageStatus { sending, sent, failed }

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
  });

  final String id;
  final MessageDirection direction;
  final String text;
  final DateTime createdAt;

  /// The model that produced an assistant reply (outbound only); null otherwise.
  final String? model;

  /// Only meaningful for an outgoing user message we're sending optimistically.
  final MessageStatus status;

  bool get isFromUser => direction == MessageDirection.inbound;

  ChatMessage copyWith({String? id, String? text, MessageStatus? status}) {
    return ChatMessage(
      id: id ?? this.id,
      direction: direction,
      text: text ?? this.text,
      createdAt: createdAt,
      model: model,
      status: status ?? this.status,
    );
  }
}
