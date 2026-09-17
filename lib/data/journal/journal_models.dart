/// Models for the Mantle Journal. Mirrors `JournalRow` in
/// `packages/content/src/journal.ts` — an entry is a short PLAIN-TEXT body
/// (not ProseMirror) with optional mood/category/entryDate metadata.
library;

class JournalRow {
  const JournalRow({
    required this.id,
    required this.title,
    required this.body,
    required this.mood,
    required this.category,
    required this.entryDate,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.kind,
    this.status,
    this.author = 'user',
    this.agentSlug,
  });

  final String id;
  final String title;
  final String body;
  final String? mood;
  final String? category;

  /// The entry's kind (`context`, `lesson`, `gap`, …); null on old rows.
  final String? kind;

  /// Gap lifecycle, `open` or `resolved`; only a `gap` carries one.
  final String? status;

  /// `user` or `agent`: who wrote it. The server stamps this.
  final String author;

  /// The writing agent's slug when [author] is `agent`.
  final String? agentSlug;

  /// An assistant's question that still wants an answer.
  bool get isOpenGap => kind == 'gap' && status != 'resolved';
  bool get isGap => kind == 'gap';
  bool get fromAgent => author == 'agent';

  /// The day the entry is about (may differ from when it was written).
  final DateTime? entryDate;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The date the list groups/labels by: entryDate when set, else created.
  DateTime get displayDate => entryDate ?? createdAt;

  JournalRow copyWith({String? body, String? title, String? status}) {
    return JournalRow(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      mood: mood,
      category: category,
      entryDate: entryDate,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      kind: kind,
      status: status ?? this.status,
      author: author,
      agentSlug: agentSlug,
    );
  }

  static JournalRow fromJson(Map<String, dynamic> j) {
    final entry = j['entryDate'] as String?;
    return JournalRow(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      mood: j['mood'] as String?,
      category: j['category'] as String?,
      entryDate: entry == null ? null : DateTime.tryParse(entry),
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      kind: j['kind'] as String?,
      status: j['status'] as String?,
      author: j['author'] == 'agent' ? 'agent' : 'user',
      agentSlug: j['agentSlug'] as String?,
    );
  }
}

/// One page of the journal (server page size 50, newest first).
class JournalPage {
  const JournalPage({required this.journals, required this.total});
  final List<JournalRow> journals;
  final int total;
}
