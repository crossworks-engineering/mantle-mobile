import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/tree/tree_api.dart';
import '../../data/tree/tree_models.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/pull_to_refresh.dart';
import 'tree_controller.dart';
import 'tree_rows.dart';

/// Builds the row a kind puts above an open folder's contents: Notes' capture
/// field, Files' upload buttons. [folder] is null at the kind's root.
typedef TreeTopBuilder = Widget Function(
  BuildContext context,
  TreeFolder? folder,
);

/// One kind's folder tree, the same on every screen that has one: folders
/// first with their icon and colour, then items; tap a folder to drill in,
/// tap the trail to climb out; items page in as the list scrolls; pull down
/// to reload. A search field looks through the whole kind and says where
/// each hit lives.
///
/// It always opens on Folders. Recent is one tap away and is not remembered,
/// which is the web's rule too.
///
/// A brain older than the tree answers 404 for the root; the screen then
/// shows [legacy], the list it had before, and stops asking.
class TreeBrowser extends ConsumerStatefulWidget {
  const TreeBrowser({
    super.key,
    required this.kind,
    required this.title,
    required this.searchPlaceholder,
    required this.onOpenItem,
    required this.legacy,
    this.initialFolderId,
    this.onLongPressItem,
    this.top,
    this.showTags = false,
    this.emptyHere = 'Nothing here yet.',
  });

  final TreeKind kind;

  /// The kind's name: the root's header title and the first crumb.
  final String title;
  final String searchPlaceholder;

  /// Open an item in its own screen.
  final void Function(TreeItem item) onOpenItem;

  /// The pre-tree screen, whole (it draws its own header).
  final WidgetBuilder legacy;

  /// Open on this folder instead of the root (a search hit or a Folder index
  /// row led here).
  final String? initialFolderId;

  /// A row's long-press action; [folderId] is the folder whose list holds
  /// it, or null for a flat list (search, Recent).
  final void Function(TreeItem item, String? folderId)? onLongPressItem;
  final TreeTopBuilder? top;

  /// Offer the kind's tags as filter pills (Notes).
  final bool showTags;
  final String emptyHere;

  @override
  ConsumerState<TreeBrowser> createState() => _TreeBrowserState();
}

class _TreeBrowserState extends ConsumerState<TreeBrowser> {
  final _search = TextEditingController();

  /// The open folder; null is the root.
  String? _folderId;

  /// Where "up" goes before the open folder has loaded and can say itself.
  final _back = <String?>[];
  bool _recent = false;

  TreeKind get _kind => widget.kind;

  @override
  void initState() {
    super.initState();
    _folderId = widget.initialFolderId;
  }

  @override
  void didUpdateWidget(TreeBrowser old) {
    super.didUpdateWidget(old);
    if (old.initialFolderId != widget.initialFolderId) {
      _folderId = widget.initialFolderId;
      _back.clear();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openFolder(String? id) {
    if (id == _folderId && !_recent) return;
    setState(() {
      _back.add(_folderId);
      _folderId = id;
      _recent = false;
    });
  }

  void _clearSearch() {
    _search.clear();
    ref.read(treeSearchControllerProvider(_kind).notifier).clear();
  }

  /// The screen is where it was opened, with nothing on top: back leaves it.
  /// That is the root, or the folder it was opened ON (a Folder index led
  /// here): from there back returns to where the reader came from, it does
  /// not climb a tree they never walked down.
  bool get _atEntry =>
      _folderId == null ||
      (_folderId == widget.initialFolderId && _back.isEmpty);

  /// One step back: out of a search, out of Recent, or up one folder. False
  /// where back leaves the screen ([_atEntry]).
  bool _stepBack() {
    final search = ref.read(treeSearchControllerProvider(_kind));
    if (search.active) {
      _clearSearch();
      return true;
    }
    if (_recent) {
      setState(() => _recent = false);
      return true;
    }
    if (_atEntry) return false;
    final loaded =
        ref.read(treeFolderControllerProvider(_kind, _folderId)).value;
    setState(() {
      if (loaded != null) {
        _folderId = loaded.crumbs.isEmpty ? null : loaded.crumbs.last.id;
        if (_back.isNotEmpty) _back.removeLast();
      } else {
        _folderId = _back.isEmpty ? null : _back.removeLast();
      }
    });
    return true;
  }

  void _openItem(TreeItem item) {
    ref
        .read(treeFolderControllerProvider(_kind, _folderId).notifier)
        .opened(item.id);
    widget.onOpenItem(item);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(treeUnavailableKindsProvider).contains(_kind)) {
      return widget.legacy(context);
    }
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(treeFolderControllerProvider(_kind, _folderId));
    if (async.hasError && async.error is TreeUnavailable) {
      return widget.legacy(context);
    }
    final search = ref.watch(treeSearchControllerProvider(_kind));
    final tags = widget.showTags
        ? (ref.watch(treeTagsProvider(_kind)).value ?? const <TreeTag>[])
        : const <TreeTag>[];
    final folder = async.value?.folder;
    final flat = _recent || search.active;

    return PopScope(
      canPop: _atEntry && !flat,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stepBack();
      },
      child: Container(
        color: scheme.background,
        child: Column(
          children: [
            MantleHeader(
              // A search and Recent look through the whole kind, so they are
              // titled by the kind, not by the folder that was open.
              leading: MantleHeaderTitle(
                flat || _folderId == null
                    ? widget.title
                    : (folder?.name ?? widget.title),
                wordmark: false,
              ),
              trailing: [
                HeaderAction(
                  icon: LucideIcons.refreshCw,
                  label: 'Refresh',
                  size: 18,
                  onPressed: _refresh,
                ),
                HeaderAction(
                  icon: LucideIcons.arrowLeft,
                  label: 'Back',
                  onPressed: () {
                    if (!_stepBack()) context.pop();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: ShadInput(
                controller: _search,
                placeholder: Text(widget.searchPlaceholder),
                onChanged: ref
                    .read(treeSearchControllerProvider(_kind).notifier)
                    .onQueryChanged,
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  ChoicePill(
                    label: 'Folders',
                    selected: !_recent && !search.active,
                    onTap: () {
                      _clearSearch();
                      setState(() => _recent = false);
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoicePill(
                    label: 'Recent',
                    selected: _recent && !search.active,
                    onTap: () {
                      _clearSearch();
                      setState(() => _recent = true);
                    },
                  ),
                  for (final t in tags) ...[
                    const SizedBox(width: 6),
                    ChoicePill(
                      label: '${t.tag} ${t.count}',
                      semanticLabel: 'Tag ${t.tag}, ${t.count}',
                      selected: search.tag == t.tag,
                      onTap: () => ref
                          .read(treeSearchControllerProvider(_kind).notifier)
                          .setTag(search.tag == t.tag ? null : t.tag),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: search.active
                    ? _SearchResults(
                        kind: _kind,
                        state: search,
                        onOpenFolder: (f) {
                          _clearSearch();
                          _openFolder(f.id);
                        },
                        onOpenItem: _openItem,
                        onLongPressItem: widget.onLongPressItem,
                      )
                    : _recent
                        ? _RecentList(
                            kind: _kind,
                            onOpenItem: _openItem,
                            onLongPressItem: widget.onLongPressItem,
                          )
                        : _folderView(theme, async),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    if (_recent) {
      ref.invalidate(treeRecentProvider(_kind));
      return;
    }
    if (ref.read(treeSearchControllerProvider(_kind)).active) {
      await ref
          .read(treeSearchControllerProvider(_kind).notifier)
          .searchNow();
      return;
    }
    if (widget.showTags) ref.invalidate(treeTagsProvider(_kind));
    await ref
        .read(treeFolderControllerProvider(_kind, _folderId).notifier)
        .refresh();
  }

  Widget _folderView(ShadThemeData theme, AsyncValue<TreeFolderState> async) {
    final state = async.value;
    if (state == null) {
      if (async.hasError) {
        final missing = async.error is TreeFolderMissing;
        return _Message(
          text: missing
              ? 'This folder is not here any more.'
              : "Couldn't load this folder.",
          action: missing ? 'Go to ${widget.title}' : 'Retry',
          onAction: missing
              ? () => setState(() {
                    _folderId = null;
                    _back.clear();
                  })
              : _refresh,
        );
      }
      return Center(child: Text('Loading…', style: theme.textTheme.muted));
    }
    final folder = state.folder;
    final rows = state.folders.length + state.items.length;
    // One extra row: the empty note, or the paging footer.
    final extra = state.isEmpty || state.hasMore ? 1 : 0;
    return Column(
      children: [
        if (folder != null)
          TreeCrumbBar(
            rootLabel: widget.title,
            crumbs: state.crumbs,
            current: folder.name,
            onRoot: () => _openFolder(null),
            onCrumb: (c) => _openFolder(c.id),
          ),
        if (widget.top != null) widget.top!(context, folder),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical &&
                  n.metrics.extentAfter < 400) {
                ref
                    .read(
                      treeFolderControllerProvider(_kind, _folderId).notifier,
                    )
                    .loadMore();
              }
              return false;
            },
            child: PullToRefreshList(
              storageKey: PageStorageKey('tree-${_kind.name}-$_folderId'),
              onRefresh: _refresh,
              padding: EdgeInsets.fromLTRB(
                12,
                4,
                12,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              itemCount: rows + extra,
              itemBuilder: (context, i) {
                if (i < state.folders.length) {
                  final f = state.folders[i];
                  return TreeFolderTile(
                    folder: f,
                    onTap: () => _openFolder(f.id),
                  );
                }
                final at = i - state.folders.length;
                if (at < state.items.length) {
                  final item = state.items[at];
                  final hold = widget.onLongPressItem;
                  return TreeItemTile(
                    kind: _kind,
                    item: item,
                    onTap: () => _openItem(item),
                    onLongPress:
                        hold == null ? null : () => hold(item, _folderId),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      state.isEmpty ? widget.emptyHere : 'Loading more…',
                      style: theme.textTheme.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// A centred line with one button under it: the screen's error states.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.muted,
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              ShadButton.outline(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.kind,
    required this.state,
    required this.onOpenFolder,
    required this.onOpenItem,
    required this.onLongPressItem,
  });

  final TreeKind kind;
  final TreeSearchState state;
  final ValueChanged<TreeFolder> onOpenFolder;
  final ValueChanged<TreeItem> onOpenItem;
  final void Function(TreeItem item, String? folderId)? onLongPressItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final notifier = ref.read(treeSearchControllerProvider(kind).notifier);
    if (state.failed) {
      return _Message(
        text: "Couldn't search right now.",
        action: 'Retry',
        onAction: notifier.searchNow,
      );
    }
    if (state.isEmpty) {
      return Center(
        child: Text(
          state.searching ? 'Searching…' : 'Nothing matches.',
          style: theme.textTheme.muted,
        ),
      );
    }
    final rows = state.folders.length + state.items.length;
    final more = state.nextCursor != null;
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          12,
          4,
          12,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        itemCount: rows + (more ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < state.folders.length) {
            final f = state.folders[i];
            return TreeFolderTile(folder: f, onTap: () => onOpenFolder(f));
          }
          final at = i - state.folders.length;
          if (at < state.items.length) {
            final item = state.items[at];
            final hold = onLongPressItem;
            return TreeItemTile(
              kind: kind,
              item: item,
              showWhere: true,
              onTap: () => onOpenItem(item),
              onLongPress: hold == null ? null : () => hold(item, null),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Loading more…', style: theme.textTheme.muted),
            ),
          );
        },
      ),
    );
  }
}

class _RecentList extends ConsumerWidget {
  const _RecentList({
    required this.kind,
    required this.onOpenItem,
    required this.onLongPressItem,
  });

  final TreeKind kind;
  final ValueChanged<TreeItem> onOpenItem;
  final void Function(TreeItem item, String? folderId)? onLongPressItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final async = ref.watch(treeRecentProvider(kind));
    final items = async.value;
    if (items == null) {
      if (async.hasError) {
        return _Message(
          text: "Couldn't load what you opened recently.",
          action: 'Retry',
          onAction: () => ref.invalidate(treeRecentProvider(kind)),
        );
      }
      return Center(child: Text('Loading…', style: theme.textTheme.muted));
    }
    return PullToRefreshList(
      onRefresh: () => ref.refresh(treeRecentProvider(kind).future),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: items.isEmpty ? 1 : items.length,
      itemBuilder: (context, i) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Nothing opened yet. What you open shows up here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.muted,
              ),
            ),
          );
        }
        final item = items[i];
        final hold = onLongPressItem;
        return TreeItemTile(
          kind: kind,
          item: item,
          showWhere: true,
          onTap: () => onOpenItem(item),
          onLongPress: hold == null ? null : () => hold(item, null),
        );
      },
    );
  }
}
