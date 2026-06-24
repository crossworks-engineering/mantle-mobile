/// One queued tool call awaiting the operator's decision, from
/// `GET /api/pending` (the server's `PendingSummary`). The agent asked to run a
/// `requires_confirm` tool; approving dispatches it, rejecting drops it.
class PendingCall {
  const PendingCall({
    required this.id,
    required this.toolSlug,
    required this.args,
    required this.status,
    this.agentId,
    this.createdAt,
  });

  final String id;
  final String toolSlug;
  final Map<String, dynamic> args;
  final String status; // 'pending' | 'approved' | 'rejected' | 'expired'
  final String? agentId;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  /// A short, human-readable summary of the call's arguments for the card.
  /// Sensitive-looking keys are masked; values are truncated. The full payload
  /// lives on the web `/pending` page — this is the at-a-glance phone view.
  String get argsPreview {
    final keys = args.keys.toList();
    if (keys.isEmpty) return '';
    final sensitive = RegExp(
      r'secret|token|password|passwd|api[-_]?key|auth|bearer|credential',
      caseSensitive: false,
    );
    final parts = <String>[];
    for (final k in keys.take(4)) {
      if (sensitive.hasMatch(k)) {
        parts.add('$k=•••');
        continue;
      }
      final v = args[k];
      String shown;
      if (v == null) {
        shown = 'null';
      } else if (v is Map) {
        shown = '{…}';
      } else if (v is List) {
        shown = '[${v.length}]';
      } else {
        shown = v.toString();
      }
      if (shown.length > 60) shown = '${shown.substring(0, 57)}…';
      parts.add('$k=$shown');
    }
    if (keys.length > 4) parts.add('+${keys.length - 4} more');
    return parts.join('\n');
  }

  factory PendingCall.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['args'];
    return PendingCall(
      id: json['id'] as String,
      toolSlug: (json['toolSlug'] as String?) ?? 'tool',
      args: rawArgs is Map
          ? rawArgs.cast<String, dynamic>()
          : const <String, dynamic>{},
      status: (json['status'] as String?) ?? 'pending',
      agentId: json['agentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }
}
