import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/lifecycle/app_lifecycle.dart';
import '../../data/tree/tree_api.dart';
import '../../data/tree/tree_models.dart';

part 'tree_controller.g.dart';

/// Kinds whose tree this brain does not serve (a 404 on the root: a brain
/// older than the tree). A screen that finds its kind here shows the list it
/// had before the tree and stops asking.
///
/// Per brain and per login: it watches the tree client, which is rebuilt
/// with the HTTP client whenever either changes, so a switch to a newer
/// brain starts clean.
///
/// Not for ever: the brain may be updated while the app runs. When the app
/// comes back to the front, a mark older than [reprobeAfter] is dropped, so
/// the screen asks for the tree once more.
@Riverpod(keepAlive: true)
class TreeUnavailableKinds extends _$TreeUnavailableKinds {
  /// How long a mark holds before a return to the app asks again.
  static Duration reprobeAfter = const Duration(minutes: 10);

  final _markedAt = <TreeKind, DateTime>{};
  TreeApi? _api;

  @override
  Set<TreeKind> build() {
    final api = ref.watch(treeApiProvider);
    final lifecycle = ref.watch(appLifecycleProvider);
    if (!identical(api, _api)) {
      // Another login or another brain: nothing known about it yet.
      _api = api;
      _markedAt.clear();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final now = DateTime.now();
      _markedAt.removeWhere((_, at) => now.difference(at) >= reprobeAfter);
    }
    return {..._markedAt.keys};
  }

  void mark(TreeKind kind) {
    _markedAt.putIfAbsent(kind, DateTime.now);
    if (!state.contains(kind)) state = {...state, kind};
  }
}

/// No automatic retry for the tree's reads. Riverpod retries a failed
/// provider with backoff by default, which suits a flaky connection but not
/// the tree: its two refusals are answers ("this brain has no tree", "this
/// folder is gone"), and a list that failed has a Retry button and a pull to
/// refresh. Asking again unprompted would only delay the screen saying so.
Duration? noTreeRetry(int retryCount, Object error) => null;

/// What one folder's screen renders: its subfolders, the items loaded so far
/// (possibly several pages deep) and the cursor for the next page.
class TreeFolderState {
  const TreeFolderState({
    required this.folder,
    required this.crumbs,
    required this.folders,
    required this.items,
    required this.nextCursor,
    this.loadingMore = false,
    this.moreFailed = false,
  });

  /// Null at the kind's root.
  final TreeFolder? folder;

  /// Top-down, not including [folder].
  final List<TreeCrumb> crumbs;
  final List<TreeFolder> folders;
  final List<TreeItem> items;
  final String? nextCursor;
  final bool loadingMore;

  /// The last page load failed. The list stops asking on its own (a scroll
  /// would otherwise ask again on every tick) until the person taps retry or
  /// refreshes.
  final bool moreFailed;

  bool get hasMore => nextCursor != null;
  bool get isEmpty => folders.isEmpty && items.isEmpty;

  TreeFolderState copyWith({
    List<TreeItem>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
    bool? moreFailed,
  }) {
    return TreeFolderState(
      folder: folder,
      crumbs: crumbs,
      folders: folders,
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      loadingMore: loadingMore ?? this.loadingMore,
      moreFailed: moreFailed ?? this.moreFailed,
    );
  }

  static TreeFolderState fromPage(TreeFolderPage page) => TreeFolderState(
        folder: page.folder,
        crumbs: page.crumbs,
        folders: page.folders,
        items: page.items,
        nextCursor: page.nextCursor,
      );
}

/// One folder of one kind's tree: a family by kind and folder id (null is the
/// root), so each level a person drills into keeps its own rows and going
/// back up shows them at once.
@Riverpod(retry: noTreeRetry)
class TreeFolderController extends _$TreeFolderController {
  @override
  Future<TreeFolderState> build(TreeKind kind, String? folderId) {
    // Rebuilt with the client: another login, or another brain.
    ref.watch(treeApiProvider);
    return _fetch();
  }

  Future<TreeFolderState> _fetch() async {
    try {
      final page =
          await ref.read(treeApiProvider).folder(kind, folderId: folderId);
      return TreeFolderState.fromPage(page);
    } on TreeUnavailable {
      // After this build, not during it: a provider may not change another
      // while it is itself being built.
      final marker = ref.read(treeUnavailableKindsProvider.notifier);
      scheduleMicrotask(() => marker.mark(kind));
      rethrow;
    }
  }

  /// Reload from the first page. The rows on screen stay until the answer is
  /// in (a pull to refresh must not blank the list); a failure keeps them and
  /// is rethrown for the caller to mention (the pull says it could not
  /// refresh). With no rows yet the failure is the screen's error state.
  Future<void> refresh() async {
    final hadData = state.hasValue;
    if (!hadData) state = const AsyncLoading();
    try {
      final next = await _fetch();
      if (ref.mounted) state = AsyncData(next);
    } catch (e, st) {
      if (!ref.mounted) return;
      if (!hadData) {
        state = AsyncError(e, st);
        return;
      }
      rethrow;
    }
  }

  /// Append the next page of items (a no-op while one is loading, at the
  /// end, or after a failed page until [retryMore]). The cursor is keyset, so
  /// rows added meanwhile are neither skipped nor repeated.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        current.loadingMore ||
        current.moreFailed ||
        !current.hasMore) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(treeApiProvider).folder(
            kind,
            folderId: folderId,
            cursor: current.nextCursor,
          );
      if (!ref.mounted) return;
      // Rebase on the LIVE state: a row removed while the page was in flight
      // must not come back.
      final now = state.value ?? current;
      final seen = {for (final i in now.items) i.id};
      state = AsyncData(now.copyWith(
        items: [
          ...now.items,
          for (final i in page.items)
            if (!seen.contains(i.id)) i,
        ],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      final now = state.value;
      if (now != null) {
        state = AsyncData(now.copyWith(loadingMore: false, moreFailed: true));
      }
    }
  }

  /// Ask for the page that failed, once, because the person asked.
  Future<void> retryMore() async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(moreFailed: false));
    await loadMore();
  }

  /// Count one open of an item for this login (what Recent lists), and drop
  /// the cached Recent list so it is asked again next time it is shown.
  void opened(String itemId) {
    final api = ref.read(treeApiProvider);
    ref.invalidate(treeRecentProvider(kind));
    unawaited(api.opened(itemId));
  }

  /// Take a row out at once (a delete the screen just asked for). The caller
  /// reloads if the delete then fails.
  void removeItem(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: [
        for (final i in current.items)
          if (i.id != id) i,
      ],
    ));
  }
}

/// A search inside one kind: the words typed, an optional tag, and what the
/// brain found (folders first, then items, each with where it lives).
class TreeSearchState {
  const TreeSearchState({
    this.query = '',
    this.tag,
    this.folders = const [],
    this.items = const [],
    this.nextCursor,
    this.searching = false,
    this.loadingMore = false,
    this.failed = false,
    this.moreFailed = false,
  });

  final String query;
  final String? tag;
  final List<TreeFolder> folders;
  final List<TreeItem> items;
  final String? nextCursor;
  final bool searching;
  final bool loadingMore;
  final bool failed;

  /// The last page of results failed; see [TreeFolderState.moreFailed].
  final bool moreFailed;

  /// Whether the screen shows results instead of the folder.
  bool get active => query.isNotEmpty || tag != null;
  bool get isEmpty => folders.isEmpty && items.isEmpty;
}

const kTreeSearchDebounce = Duration(milliseconds: 350);

/// Search as you type within one kind, with the same stale-answer guard as
/// the global search: only the latest request may write results.
@riverpod
class TreeSearchController extends _$TreeSearchController {
  Timer? _debounce;
  int _seq = 0;

  @override
  TreeSearchState build(TreeKind kind) {
    ref.onDispose(() => _debounce?.cancel());
    return const TreeSearchState();
  }

  void onQueryChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    _seq++; // an answer for the previous words must never land under these
    if (q.isEmpty && state.tag == null) {
      state = const TreeSearchState();
      return;
    }
    state = TreeSearchState(
      query: q,
      tag: state.tag,
      folders: state.folders,
      items: state.items,
      searching: true,
    );
    _debounce = Timer(kTreeSearchDebounce, _run);
  }

  /// Narrow to one tag (null clears it). Runs at once: it is a tap.
  Future<void> setTag(String? tag) {
    _debounce?.cancel();
    _seq++;
    if (tag == null && state.query.isEmpty) {
      state = const TreeSearchState();
      return Future.value();
    }
    state = TreeSearchState(query: state.query, tag: tag, searching: true);
    return _run();
  }

  void clear() {
    _debounce?.cancel();
    _seq++;
    state = const TreeSearchState();
  }

  /// Run the current search now (keyboard submit, retry, and tests).
  Future<void> searchNow() {
    _debounce?.cancel();
    if (!state.active) return Future.value();
    return _run();
  }

  Future<void> _run() async {
    final seq = ++_seq;
    final q = state.query;
    final tag = state.tag;
    try {
      final found = await ref.read(treeApiProvider).search(kind, q, tag: tag);
      if (!ref.mounted || seq != _seq) return;
      state = TreeSearchState(
        query: q,
        tag: tag,
        folders: found.folders,
        items: found.items,
        nextCursor: found.nextCursor,
      );
    } catch (_) {
      if (!ref.mounted || seq != _seq) return;
      state = TreeSearchState(query: q, tag: tag, failed: true);
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current.nextCursor == null ||
        current.loadingMore ||
        current.moreFailed ||
        current.searching) {
      return;
    }
    final seq = _seq;
    state = TreeSearchState(
      query: current.query,
      tag: current.tag,
      folders: current.folders,
      items: current.items,
      nextCursor: current.nextCursor,
      loadingMore: true,
    );
    try {
      final found = await ref.read(treeApiProvider).search(
            kind,
            current.query,
            tag: current.tag,
            cursor: current.nextCursor,
          );
      if (!ref.mounted || seq != _seq) return;
      final seen = {for (final i in current.items) i.id};
      state = TreeSearchState(
        query: current.query,
        tag: current.tag,
        folders: current.folders,
        items: [
          ...current.items,
          for (final i in found.items)
            if (!seen.contains(i.id)) i,
        ],
        nextCursor: found.nextCursor,
      );
    } catch (_) {
      if (!ref.mounted || seq != _seq) return;
      state = TreeSearchState(
        query: current.query,
        tag: current.tag,
        folders: current.folders,
        items: current.items,
        nextCursor: current.nextCursor,
        moreFailed: true,
      );
    }
  }

  /// Ask for the page of results that failed, because the person asked.
  Future<void> retryMore() async {
    final current = state;
    state = TreeSearchState(
      query: current.query,
      tag: current.tag,
      folders: current.folders,
      items: current.items,
      nextCursor: current.nextCursor,
    );
    await loadMore();
  }
}

/// This login's recently opened items of a kind, newest first, each with the
/// crumbs of where it lives. Fetched when the Recent view is opened; the view
/// is never remembered, so every screen opens on Folders.
@Riverpod(retry: noTreeRetry)
Future<List<TreeItem>> treeRecent(Ref ref, TreeKind kind) async {
  final list =
      await ref.watch(treeApiProvider).marks(kind, TreeMarkView.recent);
  return list.items;
}

/// The tags on a kind's items, most used first, for the filter row. A brain
/// that cannot answer simply shows no row.
@riverpod
Future<List<TreeTag>> treeTags(Ref ref, TreeKind kind) async {
  try {
    return await ref.watch(treeApiProvider).tags(kind);
  } catch (_) {
    return const [];
  }
}
