import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/pages/pages_models.dart';
import '../../data/tree/tree_models.dart';
import '../../widgets/mantle_header.dart';
import '../tree/tree_browser.dart';
import 'pages_controller.dart';

/// The brain's pages, in their folders. Pages do not nest (a page is never
/// the parent of another); where a page sits is its folder in the pages
/// tree, so this screen is the shared [TreeBrowser]. Read-first: tapping a
/// page opens the viewer.
class PagesScreen extends StatelessWidget {
  const PagesScreen({super.key, this.folderId});

  /// Open on this folder (a Folder index row or a link led here).
  final String? folderId;

  @override
  Widget build(BuildContext context) {
    return TreeBrowser(
      kind: TreeKind.pages,
      title: 'Pages',
      searchPlaceholder: 'Search pages…',
      initialFolderId: folderId,
      emptyHere: 'No pages here.',
      onOpenItem: (item) => context.push('/pages/${item.id}'),
      legacy: (_) => const PagesListScreen(),
    );
  }
}

/// The pages index for a brain older than the tree: every page in one list,
/// with the server-side search (title, content and summary). Backed by
/// `GET /api/pages` via [PagesController].
class PagesListScreen extends ConsumerStatefulWidget {
  const PagesListScreen({super.key});

  @override
  ConsumerState<PagesListScreen> createState() => _PagesListScreenState();
}

class _PagesListScreenState extends ConsumerState<PagesListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(pagesControllerProvider.notifier).search(q);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(pagesControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Pages', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () =>
                    ref.read(pagesControllerProvider.notifier).refresh(),
              ),
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: ShadInput(
              controller: _search,
              placeholder: const Text('Search pages…'),
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: async.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Couldn't load pages.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(pagesControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (index) => index.pages.isEmpty
                    ? Center(
                        child: Text(
                          _search.text.trim().isEmpty
                              ? 'No pages yet.'
                              : 'No pages match.',
                          style: theme.textTheme.muted,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: index.pages.length,
                        itemBuilder: (context, i) =>
                            _PageRowTile(theme: theme, row: index.pages[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageRowTile extends StatelessWidget {
  const _PageRowTile({required this.theme, required this.row});

  final ShadThemeData theme;
  final PageRow row;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/pages/${row.id}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        child: Row(
          children: [
            if (row.icon != null && row.icon!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(row.icon!, style: theme.textTheme.small),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(LucideIcons.fileText,
                    size: 15, color: scheme.mutedForeground),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.p.copyWith(color: scheme.foreground),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
