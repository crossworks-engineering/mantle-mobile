import '../agents/agent.dart';

/// One row in the conversations inbox: an agent plus a preview of its latest
/// message and an unread count (from `GET /api/assistant/conversations`).
class AgentConversation {
  const AgentConversation({
    required this.agent,
    this.lastText,
    this.lastDirection,
    this.lastAt,
    this.unreadCount = 0,
  });

  final Agent agent;
  final String? lastText;
  final String? lastDirection; // 'inbound' | 'outbound'
  final DateTime? lastAt;
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  /// True when the last message was the user's (so the preview reads "You: …").
  bool get lastFromUser => lastDirection == 'inbound';

  factory AgentConversation.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] is Map
        ? (json['lastMessage'] as Map).cast<String, dynamic>()
        : null;
    return AgentConversation(
      agent: Agent(
        slug: json['slug'] as String,
        name: (json['name'] as String?) ?? (json['slug'] as String),
        hasAvatar: json['avatar'] != null,
      ),
      lastText: last?['text'] as String?,
      lastDirection: last?['direction'] as String?,
      lastAt: last?['createdAt'] != null
          ? DateTime.tryParse(last!['createdAt'] as String)
          : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  AgentConversation copyWith({int? unreadCount}) => AgentConversation(
    agent: agent,
    lastText: lastText,
    lastDirection: lastDirection,
    lastAt: lastAt,
    unreadCount: unreadCount ?? this.unreadCount,
  );
}
