import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/pages/pages_models.dart';
import '../../widgets/mantle_header.dart';
import 'pages_controller.dart';

/// The pages index: the brain's page hierarchy as a collapsible tree, with a
/// server-side search (title + content + summary). Read-first — tapping a row
/// opens the viewer. Backed by `GET /api/pages` via [PagesController].
class PagesScreen extends ConsumerStatefulWidget {
  const PagesScreen({super.key});

  @override
  ConsumerState<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends ConsumerState<PagesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// Collapsed node ids (default-expanded, so a fresh open shows the shape of
  /// the whole hierarchy; deep trees collapse per-branch).
  final _collapsed = <String>{};

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
                    : index.isTree
                        ? _Tree(
                            theme: theme,
                            roots: buildPageTree(index.pages),
                            collapsed: _collapsed,
                            onToggle: (id) => setState(() {
                              _collapsed.contains(id)
                                  ? _collapsed.remove(id)
                                  : _collapsed.add(id);
                            }),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: index.pages.length,
                            itemBuilder: (context, i) => _PageRowTile(
                              theme: theme,
                              row: index.pages[i],
                              depth: 0,
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The collapsible hierarchy, flattened for a ListView (depth drives indent).
class _Tree extends StatelessWidget {
  const _Tree({
    required this.theme,
    required this.roots,
    required this.collapsed,
    required this.onToggle,
  });

  final ShadThemeData theme;
  final List<PageTreeNode> roots;
  final Set<String> collapsed;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final rows = <(PageTreeNode, int)>[];
    void walk(List<PageTreeNode> nodes, int depth) {
      for (final n in nodes) {
        rows.add((n, depth));
        if (!collapsed.contains(n.row.id)) walk(n.children, depth + 1);
      }
    }

    walk(roots, 0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (node, depth) = rows[i];
        return _PageRowTile(
          theme: theme,
          row: node.row,
          depth: depth,
          hasChildren: node.children.isNotEmpty,
          isCollapsed: collapsed.contains(node.row.id),
          onToggle: node.children.isNotEmpty
              ? () => onToggle(node.row.id)
              : null,
        );
      },
    );
  }
}

class _PageRowTile extends StatelessWidget {
  const _PageRowTile({
    required this.theme,
    required this.row,
    required this.depth,
    this.hasChildren = false,
    this.isCollapsed = false,
    this.onToggle,
  });

  final ShadThemeData theme;
  final PageRow row;
  final int depth;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/pages/${row.id}'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4.0 + depth * 18, 0, 12, 0),
        child: Row(
          children: [
            // Chevron toggles the branch in a 44pt box; a leaf gets the same
            // width so titles line up.
            if (hasChildren)
              Semantics(
                button: true,
                label: isCollapsed ? 'Expand' : 'Collapse',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(
                        isCollapsed
                            ? LucideIcons.chevronRight
                            : LucideIcons.chevronDown,
                        size: 15,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44, height: 44),
            if (row.icon != null && row.icon!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(row.icon!, style: theme.textTheme.small),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 6),
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
