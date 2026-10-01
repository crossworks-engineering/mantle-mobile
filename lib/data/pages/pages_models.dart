/// Models for Mantle Pages (read-first client). Mirrors `PageRow` /
/// `PageDetail` / `Backlink` in mantle `packages/content/src/pages/`.
///
/// Pages do not nest: since Mantle v0.232.365 a page is never the parent of
/// another, `parentId` on the wire is always null, and a page's place is its
/// folder in the pages tree (`lib/data/tree/`). The detail carries
/// `folderId`; the list rows do not.
library;

/// One page row (no content — the doc ships separately, see [PagesApi]).
class PageRow {
  const PageRow({
    required this.id,
    required this.title,
    required this.icon,
    required this.tags,
    required this.summary,
    required this.updatedAt,
    this.hasDraft = false,
    this.folderId,
    this.folderKnown = false,
  });

  final String id;
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

  /// The folder the page sits in; null at the top level. Detail responses
  /// only, and only from a brain that files pages in folders: see
  /// [folderKnown].
  final String? folderId;

  /// Whether the response named the page's folder at all. A brain older than
  /// pages-in-folders sends no `folderId`, which must not be read as "the top
  /// level": a Folder index block for the page's own folder then shows its
  /// label alone rather than listing the root.
  final bool folderKnown;

  static PageRow fromJson(Map<String, dynamic> j) {
    return PageRow(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? 'Untitled',
      icon: j['icon'] as String?,
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      summary: j['summary'] as String?,
      updatedAt: DateTime.parse(j['updatedAt'] as String),
      hasDraft: j['draft'] != null,
      folderId: j['folderId'] as String?,
      folderKnown: j.containsKey('folderId'),
    );
  }
}

/// The pages index of `GET /api/pages`: every page as flat rows, or the
/// filtered list when a search or tag filter is active. Only the screen for
/// a brain older than the tree uses it.
class PagesIndex {
  const PagesIndex({
    required this.pages,
    required this.total,
  });

  final List<PageRow> pages;
  final int total;
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
