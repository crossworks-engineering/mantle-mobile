import 'package:flutter/widgets.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/tree/tree_api.dart';
import '../../data/tree/tree_models.dart';
import '../chat/markdown/mantle_refs.dart';
import '../tree/tree_rows.dart';
import 'pages_controller.dart';

/// The folder the page being read sits in, for a Folder index block that
/// says `folder:here`. Placed by the page viewer around the page's markdown.
///
/// [known] is false when the brain did not say (one older than pages in
/// folders): "not known" must not be read as "the top level", so the block
/// then shows its label alone rather than listing the root. Markdown with no
/// scope above it (a chat reply) is the same case.
class PageFolderScope extends InheritedWidget {
  const PageFolderScope({
    super.key,
    required this.known,
    required this.folderId,
    required super.child,
  });

  final bool known;

  /// Null at the top level.
  final String? folderId;

  static PageFolderScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageFolderScope>();

  @override
  bool updateShouldNotify(PageFolderScope old) =>
      old.known != known || old.folderId != folderId;
}

/// Renders a `mantleFolderIndex` element (see [FolderIndexSyntax]).
class FolderIndexBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return FolderIndexBlock(
      target: element.attributes['folder'] ?? kFolderHere,
      label: element.attributes['label'] ?? 'Folder index',
    );
  }
}

/// The Folder index block: the pages of one folder, title only, live. Tap a
/// title to open the page, tap the heading to open the folder in Pages.
///
/// The faces follow the web's `folder-index-face.ts`: the label alone when
/// the folder is not known, a line saying so when the folder cannot be read
/// or loaded, "No pages here yet" when it is empty, else the list.
class FolderIndexBlock extends ConsumerWidget {
  const FolderIndexBlock({super.key, required this.target, required this.label});

  /// A folder id, or [kFolderHere] for the folder the page sits in.
  final String target;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final here = target == kFolderHere;
    final scope = here ? PageFolderScope.maybeOf(context) : null;
    final known = !here || (scope != null && scope.known);
    final folderId = here ? scope?.folderId : target;

    final async = known ? ref.watch(folderIndexProvider(folderId)) : null;
    // A brain with no tree cannot list anything: the label alone, as for a
    // folder that is not known.
    final quiet = async == null ||
        (async.hasError && async.error is TreeUnavailable);
    final index = async?.value;
    final name = index?.folder?.name ??
        (known && folderId == null && index != null ? 'Pages' : null);

    return _Card(
      heading: name == null ? label : 'In $name',
      onHeading: quiet || index == null
          ? null
          : () => context.push(
                folderId == null ? '/pages' : '/pages?folder=$folderId',
              ),
      child: quiet
          ? null
          : index == null
              ? _Line(
                  async.hasError
                      ? (async.error is TreeFolderMissing
                          ? 'This folder is not shared with you.'
                          : 'Could not load this folder.')
                      : 'Loading…',
                )
              : index.items.isEmpty
                  ? const _Line('No pages here yet.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in index.items) _PageLine(item: item),
                        if (index.more)
                          _Line(
                            'and more: the first ${index.items.length} are '
                            'listed; open the folder for the rest.',
                          ),
                      ],
                    ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.heading, required this.onHeading, this.child});

  final String heading;
  final VoidCallback? onHeading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final head = Row(
      children: [
        Icon(LucideIcons.folderOpen, size: 16, color: scheme.mutedForeground),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            heading,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(
              color: scheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onHeading != null)
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: scheme.mutedForeground,
          ),
      ],
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border.all(color: scheme.border),
        borderRadius: theme.radius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: onHeading != null,
            label: onHeading != null ? 'Open folder: $heading' : heading,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onHeading,
              child: SizedBox(height: 44, child: head),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: theme.textTheme.muted),
    );
  }
}

class _PageLine extends StatelessWidget {
  const _PageLine({required this.item});

  final TreeItem item;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final emoji = emojiIconFor(item.icon);
    final title = item.title.isEmpty ? 'Untitled' : item.title;
    return Semantics(
      link: true,
      label: 'Open page $title',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/pages/${item.id}'),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: emoji != null
                    ? Text(emoji, style: theme.textTheme.small)
                    : Icon(
                        lucideIconFor(item.icon) ?? LucideIcons.fileText,
                        size: 16,
                        color: scheme.mutedForeground,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.p.copyWith(color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
