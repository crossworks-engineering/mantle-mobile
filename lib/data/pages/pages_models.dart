/// Models for Mantle Pages (read-first client). Mirrors `PageRow` /
/// `Backlink` in `packages/content/src/pages.ts` — the list/tree endpoint
/// returns FLAT rows; the client builds the tree from [PageRow.parentId].
library;

/// One page row (no content — the doc ships separately, see [PagesApi]).
class PageRow {
  const PageRow({
    required this.id,
    required this.parentId,
    required this.title,
    required this.icon,
    required this.tags,
    required this.summary,
    required this.updatedAt,
    this.hasDraft = false,
  });

  final String id;
  final String? parentId;
  final String title;

  /// Optional emoji icon shown beside the title.
  final String? icon;
  final List<String> tags;
  final String? summary;
  final DateTime updatedAt;

  /// True when the page carries uncommitted draft changes (detail responses
  /// only — list rows don't ship draft state). The markdown export covers the
  /// COMMITTED doc, so a draft-only page exports empty; the viewer says so
  /// instead of showing a bare "empty page".
  final bool hasDraft;

  static PageRow fromJson(Map<String, dynamic> j) {
    return PageRow(
      id: j['id'] as String,
      parentId: j['parentId'] as String?,
      title: (j['title'] as String?) ?? 'Untitled',
      icon: j['icon'] as String?,
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      summary: j['summary'] as String?,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      hasDraft: j['draft'] != null,
    );
  }
}

/// The pages index: either the whole hierarchy (`mode: 'tree'`) or a flat
/// filtered list (`mode: 'list'`, when a search/tag filter is active).
class PagesIndex {
  const PagesIndex({
    required this.isTree,
    required this.pages,
    required this.total,
  });

  final bool isTree;
  final List<PageRow> pages;
  final int total;
}

/// One node of the client-built page tree (children ordered by title, matching
/// the web's tree ordering).
class PageTreeNode {
  const PageTreeNode({required this.row, required this.children});
  final PageRow row;
  final List<PageTreeNode> children;
}

/// Build the tree from flat rows. Rows whose parent isn't in the set (or is
/// null) become roots. Children sort by title, case-insensitively.
List<PageTreeNode> buildPageTree(List<PageRow> rows) {
  final byParent = <String?, List<PageRow>>{};
  final ids = rows.map((r) => r.id).toSet();
  for (final r in rows) {
    final parent = r.parentId != null && ids.contains(r.parentId)
        ? r.parentId
        : null;
    byParent.putIfAbsent(parent, () => []).add(r);
  }
  List<PageTreeNode> level(String? parent) {
    final rows = byParent[parent] ?? const <PageRow>[];
    final sorted = [...rows]..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return [
      for (final r in sorted) PageTreeNode(row: r, children: level(r.id)),
    ];
  }

  return level(null);
}

/// One inbound reference to a page (a node whose content links to it).
class Backlink {
  const Backlink({
    required this.id,
    required this.title,
    required this.type,
    required this.icon,
  });

  final String id;
  final String title;

  /// The referrer's node type ('page', 'note', …) — only 'page' referrers are
  /// navigable in this client.
  final String type;
  final String? icon;

  static Backlink fromJson(Map<String, dynamic> j) {
    return Backlink(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? 'Untitled',
      type: (j['type'] as String?) ?? '',
      icon: j['icon'] as String?,
    );
  }
}

/// Everything the page viewer needs: the row metadata, the content exported
/// as markdown, and the inbound links.
class PageContent {
  const PageContent({
    required this.meta,
    required this.markdown,
    required this.backlinks,
  });

  final PageRow meta;
  final String markdown;
  final List<Backlink> backlinks;
}
