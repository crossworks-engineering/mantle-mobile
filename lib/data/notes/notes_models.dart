/// Models for Mantle Notes. Mirrors `NoteRow` in
/// `packages/content/src/notes.ts` — the list rides the full content, sorted
/// by `updatedAt` desc, paged 50, with tag facets for the filter row.
library;

/// One note. `content` is markdown (Mantle's GFM-superset dialect).
class NoteRow {
  const NoteRow({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final String? summary;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// List-row preview: the summary when the server has one, else the first
  /// non-empty content line.
  String get preview {
    final s = summary;
    if (s != null && s.trim().isNotEmpty) return s.trim();
    for (final line in content.split('\n')) {
      final t = line.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static NoteRow fromJson(Map<String, dynamic> j) {
    return NoteRow(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      content: (j['content'] as String?) ?? '',
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      summary: j['summary'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}

/// One tag facet (`{tag, count}`) for the notes filter row.
class NoteTag {
  const NoteTag({required this.tag, required this.count});

  final String tag;
  final int count;

  static NoteTag fromJson(Map<String, dynamic> j) => NoteTag(
        tag: j['tag'] as String,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// One page of the notes list plus the total and the tag facets.
class NotesPage {
  const NotesPage({
    required this.notes,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.tags,
  });

  final List<NoteRow> notes;
  final int total;
  final int page;
  final int pageSize;
  final List<NoteTag> tags;

  static NotesPage fromJson(Map<String, dynamic> j) {
    final rows = ((j['notes'] as List?) ?? const [])
        .map((e) => NoteRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return NotesPage(
      notes: rows,
      total: (j['total'] as num?)?.toInt() ?? rows.length,
      page: (j['page'] as num?)?.toInt() ?? 1,
      pageSize: (j['pageSize'] as num?)?.toInt() ?? 50,
      tags: ((j['tags'] as List?) ?? const [])
          .map((e) => NoteTag.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
