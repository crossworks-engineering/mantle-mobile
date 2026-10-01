import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/pages/pages_api.dart';
import '../../data/pages/pages_models.dart';
import '../../data/tree/tree_api.dart';
import '../../data/tree/tree_models.dart';
import '../tree/tree_controller.dart' show noTreeRetry;

part 'pages_controller.g.dart';

/// Owns the flat pages index shown for a brain older than the tree. Loads
/// every page on build; [search] swaps in the server's filtered list (`q`
/// matches title, content text and summary) and an empty query restores it.
@riverpod
class PagesController extends _$PagesController {
  @override
  Future<PagesIndex> build() {
    return ref.read(pagesApiProvider).list();
  }

  /// Server-side search (or restore the tree when [q] is blank). Keeps the
  /// current index on failure so a flaky search doesn't blank the screen.
  Future<void> search(String q) async {
    final query = q.trim();
    try {
      final index =
          await ref.read(pagesApiProvider).list(q: query.isEmpty ? null : query);
      if (ref.mounted) state = AsyncData(index);
    } catch (_) {
      /* keep current; the user can retry */
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => ref.read(pagesApiProvider).list());
    if (ref.mounted) state = next;
  }
}

/// Everything the viewer needs for one page, fetched concurrently: metadata,
/// the markdown export, and backlinks. Backlinks are best-effort (a failure
/// yields an empty list rather than sinking the page).
@riverpod
Future<PageContent> pageContent(Ref ref, String pageId) async {
  final api = ref.watch(pagesApiProvider);
  final results = await Future.wait([
    api.meta(pageId),
    api.markdown(pageId),
    api.backlinks(pageId).catchError((_) => const <Backlink>[]),
  ]);
  return PageContent(
    meta: results[0] as PageRow,
    markdown: results[1] as String,
    backlinks: results[2] as List<Backlink>,
  );
}

/// What a Folder index block lists: one folder's pages by name.
class FolderIndex {
  const FolderIndex({
    required this.folder,
    required this.items,
    required this.more,
  });

  /// Null for the top level.
  final TreeFolder? folder;
  final List<TreeItem> items;

  /// The folder holds more pages than were read ([kFolderIndexMaxPages]).
  final bool more;
}

/// Folder pages read for one index, 50 items each. Past this the block says
/// the list was cut rather than reading on (the web's rule, and its number).
const kFolderIndexMaxPages = 10;

/// The pages of [folderId] (null is the top level) for a Folder index block:
/// title only, by name, read from the reader's own tree so it is always what
/// THIS reader may see. Never stored; asked again each time a page opens.
@Riverpod(retry: noTreeRetry)
Future<FolderIndex> folderIndex(Ref ref, String? folderId) async {
  final api = ref.watch(treeApiProvider);
  final items = <TreeItem>[];
  TreeFolder? folder;
  String? cursor;
  for (var i = 0; i < kFolderIndexMaxPages; i++) {
    final page = await api.folder(
      TreeKind.pages,
      folderId: folderId,
      sort: TreeSort.name,
      cursor: cursor,
    );
    if (i == 0) folder = page.folder;
    items.addAll(page.items);
    cursor = page.nextCursor;
    if (cursor == null) {
      return FolderIndex(folder: folder, items: items, more: false);
    }
  }
  return FolderIndex(folder: folder, items: items, more: true);
}
