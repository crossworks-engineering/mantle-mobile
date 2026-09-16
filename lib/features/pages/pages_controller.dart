import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/pages/pages_api.dart';
import '../../data/pages/pages_models.dart';

part 'pages_controller.g.dart';

/// Owns the pages index. Loads the whole hierarchy on build (`mode:'tree'`,
/// flat rows — the screen builds the tree); [search] swaps in the server's
/// filtered flat list (`q` matches title, content text, and summary) and an
/// empty query restores the tree.
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
