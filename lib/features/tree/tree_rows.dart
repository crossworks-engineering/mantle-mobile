import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/format/dates.dart';
import '../../data/tree/tree_models.dart';
import '../../theme/app_tints.dart';
import '../../theme/lucide_names.dart';

/// The glyph a folder or item names with `icon`: `lucide:<name>` from the
/// curated set, or null for an emoji, an unknown name, or none.
IconData? lucideIconFor(String? icon) {
  if (icon == null || !icon.startsWith('lucide:')) return null;
  return kLucideByName[icon.substring('lucide:'.length)];
}

/// An emoji icon, or null when [icon] is a lucide name or absent.
String? emojiIconFor(String? icon) {
  if (icon == null || icon.isEmpty || icon.startsWith('lucide:')) return null;
  return icon;
}

/// How a path of crumbs reads in one line: `Clients › Acme Corp`.
String crumbPath(List<TreeCrumb> crumbs) =>
    crumbs.map((c) => c.name).join(' › ');

/// What a share or a level is called on a badge.
String levelLabel(String level) => switch (level) {
      'team' => 'Team',
      'client' => 'Clients',
      'public' => 'Public',
      'admin' => 'Admin',
      _ => level,
    };

String stateLabel(String state) => switch (state) {
      'private' => 'Private',
      'draft' => 'Draft',
      'submitted' => 'Submitted',
      'returned' => 'Returned',
      'with-admin' => 'With admin',
      _ => state,
    };

/// The default glyph for an item of [kind] that names no icon of its own.
IconData defaultItemIcon(TreeKind kind, TreeItem item) {
  switch (kind) {
    case TreeKind.pages:
      return LucideIcons.fileText;
    case TreeKind.notes:
      return LucideIcons.stickyNote;
    case TreeKind.files:
      return _imageExtensions.contains(item.subtype)
          ? LucideIcons.image
          : LucideIcons.file;
    case TreeKind.draw:
      return LucideIcons.penTool;
    case TreeKind.tables:
      return LucideIcons.table2;
    default:
      return LucideIcons.file;
  }
}

const _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
  'svg',
};

/// Whether a file row's extension says the image screen can show it.
bool treeFileIsImage(TreeItem item) => _imageExtensions.contains(item.subtype);

/// A folder's tile: its tint as the fill, its icon (emoji, lucide, or the
/// default folder) in the tint's ink. With no tint it sits on `secondary`.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, required this.icon, required this.color});

  final String? icon;
  final String? color;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fill = AppTints.fill(color, scheme.background) ?? scheme.secondary;
    final ink =
        AppTints.ink(color, scheme.foreground) ?? scheme.secondaryForeground;
    final emoji = emojiIconFor(icon);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: theme.radius,
      ),
      child: emoji != null
          ? Text(emoji, style: theme.textTheme.small)
          : Icon(lucideIconFor(icon) ?? LucideIcons.folder, size: 17, color: ink),
    );
  }
}

/// A small pill: who a folder is shared with, an item's level or state.
class TreeBadge extends StatelessWidget {
  const TreeBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.small.copyWith(color: scheme.secondaryForeground),
      ),
    );
  }
}

/// One folder row: glyph, name, what it holds, and who it is shared with.
class TreeFolderTile extends StatelessWidget {
  const TreeFolderTile({super.key, required this.folder, required this.onTap});

  final TreeFolder folder;
  final VoidCallback onTap;

  String get _counts {
    final parts = [
      if (folder.folderCount == 1) '1 folder',
      if (folder.folderCount > 1) '${folder.folderCount} folders',
      if (folder.itemCount == 1) '1 item',
      if (folder.itemCount > 1) '${folder.itemCount} items',
    ];
    return parts.isEmpty ? 'Empty' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    final shared = folder.sharedWith;
    final where = crumbPath(folder.crumbs);
    return Semantics(
      button: true,
      label: 'Open folder ${folder.name}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FolderGlyph(icon: folder.icon, color: folder.color),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.p.copyWith(color: scheme.foreground),
                    ),
                    Text(
                      where.isEmpty ? _counts : 'in $where',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (shared != null) TreeBadge(levelLabel(shared)),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(LucideIcons.chevronRight, size: 16, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One item row: glyph, title, where it lives (search and Recent only), its
/// level when it is read below admin, and when it last changed.
class TreeItemTile extends StatelessWidget {
  const TreeItemTile({
    super.key,
    required this.kind,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.showWhere = false,
  });

  final TreeKind kind;
  final TreeItem item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Say where the item lives under its title. On for flat lists (search,
  /// Recent); off inside a folder, where the breadcrumb already says it.
  final bool showWhere;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    final emoji = emojiIconFor(item.icon);
    final ink = AppTints.ink(item.color, scheme.foreground) ?? muted;
    final level = item.level;
    final state = item.state;
    final where = crumbPath(item.crumbs);
    final updated = item.updatedAt;
    final under = [
      if (showWhere) where.isEmpty ? 'Top level' : where,
      if (item.source == 'team' && item.author != null) 'by ${item.author}',
    ].join(' · ');
    return Semantics(
      button: true,
      label: 'Open ${item.title}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 28,
                child: Align(
                  alignment: Alignment.center,
                  child: emoji != null
                      ? Text(emoji, style: theme.textTheme.small)
                      : Icon(
                          lucideIconFor(item.icon) ??
                              defaultItemIcon(kind, item),
                          size: 18,
                          color: ink,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? 'Untitled' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.p.copyWith(color: scheme.foreground),
                    ),
                    if (under.isNotEmpty)
                      Text(
                        under,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(color: muted),
                      ),
                  ],
                ),
              ),
              if (state != null) TreeBadge(stateLabel(state)),
              if (state == null && level != null && level != 'admin')
                TreeBadge(levelLabel(level)),
              if (updated != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    formatWhen(updated),
                    style: theme.textTheme.small.copyWith(color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trail above a folder's rows: the kind's root, each folder on the way
/// down, then the open folder. Every step but the last is a 44pt tap.
class TreeCrumbBar extends StatefulWidget {
  const TreeCrumbBar({
    super.key,
    required this.rootLabel,
    required this.crumbs,
    required this.current,
    required this.onRoot,
    required this.onCrumb,
  });

  final String rootLabel;
  final List<TreeCrumb> crumbs;

  /// The open folder's name (not tappable: it is where the reader is).
  final String current;
  final VoidCallback onRoot;
  final ValueChanged<TreeCrumb> onCrumb;

  @override
  State<TreeCrumbBar> createState() => _TreeCrumbBarState();
}

class _TreeCrumbBarState extends State<TreeCrumbBar> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _showEnd();
  }

  @override
  void didUpdateWidget(TreeCrumbBar old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) _showEnd();
  }

  /// The open folder is the end of the trail: a long trail starts scrolled
  /// to it, a short one stays at the left edge.
  void _showEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    Widget step(String label, VoidCallback onTap) => Semantics(
          button: true,
          label: 'Go to $label',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: theme.textTheme.small.copyWith(color: scheme.primary),
              ),
            ),
          ),
        );
    Widget sep() => Center(
          child: Icon(
            LucideIcons.chevronRight,
            size: 14,
            color: scheme.mutedForeground,
          ),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          step(widget.rootLabel, widget.onRoot),
          for (final c in widget.crumbs) ...[
            sep(),
            step(c.name, () => widget.onCrumb(c)),
          ],
          sep(),
          Container(
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              widget.current,
              style: theme.textTheme.small.copyWith(
                color: scheme.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
