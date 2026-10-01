/// The item tree's wire shapes: one folder navigation for every kind.
///
/// Mirrors mantle `packages/client-types/src/tree.ts` by hand (the brain has
/// no OpenAPI). One file on purpose: when that file changes, this is the one
/// to re-read against it. The fixtures under `test/fixtures/tree/` are real
/// responses, and `test/data/tree_models_test.dart` parses each of them.
///
/// The same shapes serve all three readers. An admin and a member receive
/// everything below; a client's tree leaves out the staff fields (`level`,
/// `share`, `inherited`, `system`, `state`), which is why those are nullable
/// or defaulted here rather than required.
library;

/// The kinds the tree serves. The phone browses a few of them; the rest are
/// here so a response naming one still parses.
enum TreeKind {
  files,
  notes,
  pages,
  draw,
  tables,
  formulas,
  apps,
  tasks,
  events,
  contacts,
  secrets,
  recall;

  /// The path segment and the wire value (`/api/tree/<wire>`).
  String get wire => name;

  static TreeKind? tryParse(Object? v) {
    for (final k in values) {
      if (k.name == v) return k;
    }
    return null;
  }
}

/// The orders a folder's items can be listed in. Folders keep their own
/// manual order whatever the sort.
enum TreeSort {
  name,
  updated,
  start,
  due;

  static TreeSort? tryParse(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// The flat views beside the tree: this login's pins, recent and most used.
enum TreeMarkView { pinned, recent, used }

/// The 13 tints a folder or an item can carry. The brain stores the KEY; each
/// theme paints it (see `lib/theme/app_tints.dart`).
const List<String> kTreeTints = [
  'slate',
  'red',
  'orange',
  'amber',
  'lime',
  'green',
  'teal',
  'cyan',
  'sky',
  'blue',
  'indigo',
  'violet',
  'pink',
];

String? _tint(Object? v) => kTreeTints.contains(v) ? v as String : null;

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

/// One folder as the tree shows it. Counts are what THIS reader can see.
class TreeFolder {
  const TreeFolder({
    required this.id,
    required this.path,
    required this.name,
    required this.icon,
    required this.color,
    required this.depth,
    required this.parentId,
    required this.share,
    required this.inherited,
    required this.system,
    required this.folderCount,
    required this.itemCount,
    required this.own,
    this.crumbs = const [],
  });

  final String id;

  /// The folder's ltree path: what Files uploads name as `parentPath`.
  final String path;
  final String name;

  /// An emoji or `lucide:<name>`; null is the default folder glyph.
  final String? icon;

  /// One of [kTreeTints], or null.
  final String? color;

  /// 1 to 3 below the kind's root.
  final int depth;
  final String? parentId;

  /// The folder's own share (`team` or `client`); null is none. Never sent to
  /// a client login.
  final String? share;

  /// The share of the nearest shared folder above it.
  final String? inherited;

  /// Made by Mantle (Auto-filed): its name is locked.
  final bool system;
  final int folderCount;
  final int itemCount;

  /// A member's tree only: the member's own private folder.
  final bool own;

  /// Where it lives, top-down. Search results only.
  final List<TreeCrumb> crumbs;

  /// Who reads what is filed here: the folder's own share, else the one it
  /// takes from above.
  String? get sharedWith => share ?? inherited;

  static TreeFolder fromJson(Map<String, dynamic> j) => TreeFolder(
        id: j['id'] as String,
        path: (j['path'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        icon: _str(j['icon']),
        color: _tint(j['color']),
        depth: (j['depth'] as num?)?.toInt() ?? 1,
        parentId: _str(j['parentId']),
        share: _str(j['share']),
        inherited: _str(j['inherited']),
        system: j['system'] == true,
        folderCount: (j['folderCount'] as num?)?.toInt() ?? 0,
        itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
        own: j['own'] == true,
        crumbs: TreeCrumb.listFrom(j['crumbs']),
      );
}

/// Kind-specific facts a row draws: a task's done box and due date, an
/// event's start.
class TreeItemMeta {
  const TreeItemMeta({this.done = false, this.due, this.start});

  final bool done;
  final DateTime? due;
  final DateTime? start;

  static TreeItemMeta? fromJson(Object? raw) {
    if (raw is! Map) return null;
    DateTime? at(Object? v) => v is String ? DateTime.tryParse(v) : null;
    return TreeItemMeta(
      done: raw['done'] == true,
      due: at(raw['due']),
      start: at(raw['start']),
    );
  }
}

/// One item as the tree shows it: a title and what the status slot needs.
/// Summaries and tags live in the item's own view, not here.
class TreeItem {
  const TreeItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.subtype,
    required this.level,
    required this.inherited,
    required this.embedded,
    required this.state,
    required this.updatedAt,
    required this.meta,
    required this.source,
    required this.author,
    this.crumbs = const [],
  });

  final String id;
  final String title;

  /// The item's own icon when it has one (emoji or `lucide:<name>`).
  final String? icon;
  final String? color;

  /// A short token for the status slot: a file's extension, a secret's kind.
  final String? subtype;

  /// Who can read it (`admin`, `team`, `client`, `public`): the most open of
  /// its own level, its folder's share and what embeds it. Null for a client
  /// login, which is never told.
  final String? level;
  final String? inherited;
  final String? embedded;

  /// `private`, `draft`, `submitted`, `returned` or `with-admin`; null for an
  /// ordinary brain item.
  final String? state;
  final DateTime? updatedAt;
  final TreeItemMeta? meta;

  /// A member's tree only: `own` (the member's draft) or `team` (a
  /// teammate's draft shared with the team).
  final String? source;
  final String? author;

  /// Where it lives, top-down. Search results and mark lists only.
  final List<TreeCrumb> crumbs;

  static TreeItem fromJson(Map<String, dynamic> j) {
    final updated = j['updatedAt'];
    return TreeItem(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      icon: _str(j['icon']),
      color: _tint(j['color']),
      subtype: _str(j['subtype']),
      level: _str(j['level']),
      inherited: _str(j['inherited']),
      embedded: _str(j['embedded']),
      state: _str(j['state']),
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
      meta: TreeItemMeta.fromJson(j['meta']),
      source: _str(j['source']),
      author: _str(j['author']),
      crumbs: TreeCrumb.listFrom(j['crumbs']),
    );
  }
}

class TreeCrumb {
  const TreeCrumb({required this.id, required this.name});

  final String id;
  final String name;

  static List<TreeCrumb> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final c in raw)
        if (c is Map && c['id'] is String)
          TreeCrumb(id: c['id'] as String, name: (c['name'] as String?) ?? ''),
    ];
  }
}

List<TreeFolder> _folders(Object? raw) => [
      for (final f in (raw as List?) ?? const [])
        if (f is Map) TreeFolder.fromJson(f.cast<String, dynamic>()),
    ];

List<TreeItem> _items(Object? raw) => [
      for (final i in (raw as List?) ?? const [])
        if (i is Map) TreeItem.fromJson(i.cast<String, dynamic>()),
    ];

/// `GET /api/tree/:kind?folder=`: one folder's direct subfolders (all of
/// them, in order) and one page of its items. A null [folder] is the root.
class TreeFolderPage {
  const TreeFolderPage({
    required this.kind,
    required this.folder,
    required this.crumbs,
    required this.folders,
    required this.items,
    required this.sort,
    required this.nextCursor,
  });

  final TreeKind? kind;
  final TreeFolder? folder;

  /// Top-down, NOT including [folder] itself.
  final List<TreeCrumb> crumbs;
  final List<TreeFolder> folders;
  final List<TreeItem> items;
  final TreeSort? sort;

  /// Pass back as `cursor` for the next page of items; null at the end.
  final String? nextCursor;

  static TreeFolderPage fromJson(Map<String, dynamic> j) {
    final folder = j['folder'];
    return TreeFolderPage(
      kind: TreeKind.tryParse(j['kind']),
      folder: folder is Map
          ? TreeFolder.fromJson(folder.cast<String, dynamic>())
          : null,
      crumbs: TreeCrumb.listFrom(j['crumbs']),
      folders: _folders(j['folders']),
      items: _items(j['items']),
      sort: TreeSort.tryParse(j['sort']),
      nextCursor: _str(j['nextCursor']),
    );
  }
}

/// `GET /api/tree/:kind/search?q=`: matching folders first, then items, each
/// carrying the crumbs of where it lives. An empty `q` is the A to Z view.
class TreeSearchResult {
  const TreeSearchResult({
    required this.folders,
    required this.items,
    required this.nextCursor,
  });

  final List<TreeFolder> folders;
  final List<TreeItem> items;
  final String? nextCursor;

  static TreeSearchResult fromJson(Map<String, dynamic> j) => TreeSearchResult(
        folders: _folders(j['folders']),
        items: _items(j['items']),
        nextCursor: _str(j['nextCursor']),
      );
}

/// `GET /api/tree/:kind/marks?view=`: this login's pinned, recent or most
/// used items of a kind, with the crumbs of where each lives.
class TreeMarkList {
  const TreeMarkList({required this.items});

  final List<TreeItem> items;

  static TreeMarkList fromJson(Map<String, dynamic> j) =>
      TreeMarkList(items: _items(j['items']));
}

/// `GET /api/tree/:kind/tags`: the tags on a kind's items, most used first.
class TreeTag {
  const TreeTag({required this.tag, required this.count});

  final String tag;
  final int count;

  static List<TreeTag> listFrom(Map<String, dynamic> j) => [
        for (final t in (j['tags'] as List?) ?? const [])
          if (t is Map && t['tag'] is String)
            TreeTag(
              tag: t['tag'] as String,
              count: (t['count'] as num?)?.toInt() ?? 0,
            ),
      ];
}

/// One item whose readers would change (`TreeVisibilityChange`).
class TreeVisibilityChange {
  const TreeVisibilityChange({
    required this.id,
    required this.title,
    required this.from,
    required this.to,
  });

  final String id;
  final String title;
  final String from;
  final String to;

  static List<TreeVisibilityChange> listFrom(Object? raw) => [
        for (final c in (raw as List?) ?? const [])
          if (c is Map && c['id'] is String)
            TreeVisibilityChange(
              id: c['id'] as String,
              title: (c['title'] as String?) ?? '',
              from: (c['from'] as String?) ?? '',
              to: (c['to'] as String?) ?? '',
            ),
      ];
}

/// The 409 a write gets when it would change who can see something
/// (`TreeVisibilityRefusal`). Nothing was written. The same call with
/// `confirm: true` and `seen:` [seen] goes ahead.
class TreeVisibilityRefusal implements Exception {
  const TreeVisibilityRefusal({
    required this.changes,
    required this.total,
    required this.embedsTotal,
  });

  /// The first changes (the brain lists at most 100).
  final List<TreeVisibilityChange> changes;

  /// How many items change in all.
  final int total;

  /// How many embedded items change with them.
  final int embedsTotal;

  /// What a confirm says it was shown, so a change that grew meanwhile is
  /// refused again instead of slipping through.
  int get seen => total + embedsTotal;

  /// The level the listed items become readable at, when they all agree.
  String? get to {
    final levels = {for (final c in changes) c.to};
    return levels.length == 1 ? levels.first : null;
  }

  /// Null unless [body] is a visibility refusal.
  static TreeVisibilityRefusal? tryParse(Object? body) {
    if (body is! Map || body['error'] != 'visibility') return null;
    return TreeVisibilityRefusal(
      changes: TreeVisibilityChange.listFrom(body['changes']),
      total: (body['total'] as num?)?.toInt() ?? 0,
      embedsTotal: (body['embedsTotal'] as num?)?.toInt() ?? 0,
    );
  }
}
