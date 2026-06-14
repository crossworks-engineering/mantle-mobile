/// A conversational agent exposed by Mantle (`GET /api/agents`). We only need
/// enough to identify and switch agents in the chat header.
class Agent {
  const Agent({
    required this.slug,
    required this.name,
    this.role,
    this.hasAvatar = false,
  });

  final String slug;
  final String name;
  final String? role;

  /// Whether the agent has a generated (boring-avatars) avatar on Mantle. When
  /// true the app fetches `/api/agents/{slug}/avatar`; otherwise it shows the
  /// initials fallback.
  final bool hasAvatar;

  factory Agent.fromJson(Map<String, dynamic> json) => Agent(
    slug: json['slug'] as String,
    name: (json['name'] as String?) ?? (json['slug'] as String),
    role: json['role'] as String?,
    hasAvatar: json['avatar'] != null,
  );

  /// Up to two initials from the name — Mantle's fallback avatar label.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Deterministic accent hue (0–360) derived from the slug — mirrors Mantle's
  /// `agentAccent`, so the same agent gets the same colour as on the web.
  int get accentHue {
    var h = 0;
    for (final code in slug.codeUnits) {
      h = (h * 31 + code) & 0xFFFFFFFF;
    }
    return h % 360;
  }
}
