/// Models for `GET /api/search` (added to Mantle in v0.148.0) — the HTTP
/// twin of the `search_nodes` tool. Results are relevance-ranked (hybrid
/// FTS + vector), NOT date-sorted.
library;

/// The living successor of a superseded hit — prefer it when present.
class SupersededRef {
  const SupersededRef({required this.id, required this.title, required this.url});

  final String id;
  final String title;
  final String url;

  static SupersededRef fromJson(Map<String, dynamic> j) => SupersededRef(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? '',
        url: (j['url'] as String?) ?? '',
      );
}

/// One node hit. `url` is the absolute `<server>/n/<id>` permalink (the
/// server's `/n/` route redirects to the right surface for the type).
class SearchResult {
  const SearchResult({
    required this.id,
    required this.type,
    required this.title,
    required this.path,
    required this.tags,
    required this.summary,
    required this.updatedAt,
    required this.url,
    this.supersededBy,
  });

  final String id;
  final String type;
  final String title;
  final String path;
  final List<String> tags;
  final String? summary;
  final DateTime? updatedAt;
  final String url;
  final SupersededRef? supersededBy;

  static SearchResult fromJson(Map<String, dynamic> j) {
    final updated = j['updatedAt'] as String?;
    final succ = j['supersededBy'];
    return SearchResult(
      id: j['id'] as String,
      type: (j['type'] as String?) ?? 'node',
      title: (j['title'] as String?) ?? '',
      path: (j['path'] as String?) ?? '',
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      summary: j['summary'] as String?,
      updatedAt: updated == null ? null : DateTime.tryParse(updated),
      url: (j['url'] as String?) ?? '',
      supersededBy: succ is Map
          ? SupersededRef.fromJson(succ.cast<String, dynamic>())
          : null,
    );
  }
}
