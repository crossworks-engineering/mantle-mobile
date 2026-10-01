import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/pages/pages_models.dart';
import '../../widgets/mantle_header.dart';
import '../chat/markdown/mantle_markdown.dart';
import 'folder_index.dart';
import 'pages_controller.dart';

/// One page, read-only: title + tags, the content (the server's markdown
/// export rendered by MantleMarkdown), and a "Linked from" backlinks footer.
/// Backed by [pageContentProvider] (meta + markdown + backlinks in parallel).
class PageViewScreen extends ConsumerWidget {
  const PageViewScreen({super.key, required this.pageId});

  final String pageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(pageContentProvider(pageId));

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: MantleHeaderTitle(
              async.value?.meta.title ?? 'Page',
              wordmark: false,
            ),
            trailing: [
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
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
                      Text("Couldn't load the page.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () =>
                            ref.invalidate(pageContentProvider(pageId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (page) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (page.meta.icon != null &&
                            page.meta.icon!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 2),
                            child: Text(
                              page.meta.icon!,
                              style: theme.textTheme.h3,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            page.meta.title,
                            style: theme.textTheme.h3
                                .copyWith(color: scheme.foreground),
                          ),
                        ),
                      ],
                    ),
                    if (page.meta.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in page.meta.tags)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: scheme.secondary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.small.copyWith(
                                  color: scheme.secondaryForeground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (page.markdown.trim().isEmpty)
                      Text(
                        // The export covers the COMMITTED doc only — content
                        // still sitting in a web-editor draft isn't published.
                        page.meta.hasDraft
                            ? 'This page only has unsaved draft changes — '
                                'commit it on the web to read it here.'
                            : 'This page is empty.',
                        style: theme.textTheme.muted,
                      )
                    else
                      // Images (`media:` / `draw:` / http) and the reference
                      // chips are MantleMarkdown's own defaults now.
                      // The page's own folder, for a Folder index block that
                      // says `folder:here`.
                      PageFolderScope(
                        known: page.meta.folderKnown,
                        folderId: page.meta.folderId,
                        child: MantleMarkdown(
                          page.markdown,
                          textColor: scheme.foreground,
                          // The export hard-wraps prose; join it as the web
                          // does.
                          softLineBreak: false,
                        ),
                      ),
                    if (page.backlinks.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: scheme.border),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Linked from', style: theme.textTheme.muted),
                            const SizedBox(height: 6),
                            for (final link in page.backlinks)
                              _BacklinkRow(theme: theme, link: link),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BacklinkRow extends StatelessWidget {
  const _BacklinkRow({required this.theme, required this.link});

  final ShadThemeData theme;
  final Backlink link;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final navigable = link.type == 'page';
    return Semantics(
      link: navigable,
      label: link.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: navigable ? () => context.push('/pages/${link.id}') : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
          children: [
            if (link.icon != null && link.icon!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(link.icon!, style: theme.textTheme.small),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(LucideIcons.fileText,
                    size: 14, color: scheme.mutedForeground),
              ),
            Expanded(
              child: Text(
                link.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: navigable
                    ? theme.textTheme.p.copyWith(color: scheme.primary)
                    : theme.textTheme.p.copyWith(color: scheme.foreground),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
