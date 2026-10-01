import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/notes/notes_models.dart';
import '../../data/tree/tree_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/voice_text_field.dart';
import '../../widgets/confirm_dialog.dart';
import '../tree/tree_browser.dart';
import '../tree/tree_controller.dart';
import 'notes_controller.dart';

/// The brain's notes, in their folders: the shared [TreeBrowser] with a
/// capture field on top that saves into the OPEN folder, the kind's tags as
/// filter pills, tap to open and long-press to delete.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key, this.folderId});

  /// Open on this folder instead of the top level.
  final String? folderId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TreeItem note,
    String? inFolder,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete note?',
      description: '"${note.title}" is removed from your brain.',
      action: 'Delete',
    );
    if (!ok) return;
    // Out of the open folder's list at once; every other list (search,
    // Recent, the folders' counts) is asked again once the brain has done it.
    ref
        .read(treeFolderControllerProvider(TreeKind.notes, inFolder).notifier)
        .removeItem(note.id);
    try {
      await ref.read(noteFilingProvider).delete(note.id);
    } catch (_) {
      /* the reload below puts the row back */
    }
    if (!context.mounted) return;
    ref.invalidate(treeFolderControllerProvider);
    ref.invalidate(treeRecentProvider(TreeKind.notes));
    ref.invalidate(treeTagsProvider(TreeKind.notes));
    await ref
        .read(treeSearchControllerProvider(TreeKind.notes).notifier)
        .searchNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TreeBrowser(
      kind: TreeKind.notes,
      title: 'Notes',
      searchPlaceholder: 'Search notes…',
      initialFolderId: folderId,
      showTags: true,
      emptyHere: 'No notes here. Capture one above.',
      onOpenItem: (item) => context.push('/notes/${item.id}'),
      onLongPressItem: (item, inFolder) =>
          _confirmDelete(context, ref, item, inFolder),
      top: (context, folder) => _NoteCapture(folder: folder),
      legacy: (_) => const NotesListScreen(),
    );
  }
}

/// The capture row above a folder's notes: a title (typed or dictated) and
/// a button. The note lands in [folder], the folder on screen.
class _NoteCapture extends ConsumerStatefulWidget {
  const _NoteCapture({required this.folder});

  /// Null at the top level.
  final TreeFolder? folder;

  @override
  ConsumerState<_NoteCapture> createState() => _NoteCaptureState();
}

class _NoteCaptureState extends ConsumerState<_NoteCapture> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (_adding) return;
    if (title.isEmpty) {
      _focus.requestFocus();
      return;
    }
    final folder = widget.folder;
    final filing = ref.read(noteFilingProvider);
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await filing.capture(title, folderId: folder?.id);
      _input.clear();
    } on NoteNeedsConfirm catch (pending) {
      // The note is saved (at the top level). Filing it here shares it.
      _input.clear();
      // Only a capture into a folder can be refused this way.
      final target = folder;
      if (target == null) return;
      final to = pending.refusal.to;
      final ok = mounted &&
          await confirmAction(
            context,
            title: 'File it in a shared folder?',
            description: to == null
                ? '"${target.name}" is shared, so this note will be readable '
                    'by more people than you.'
                : '"${target.name}" is shared: this note will be readable '
                    'by ${_readers(to)}.',
            action: 'File it here',
          );
      if (ok) {
        try {
          await filing.fileConfirmed(
            pending.note.id,
            target.id,
            pending.refusal,
          );
        } catch (_) {
          if (mounted) {
            setState(() => _error =
                'Saved at the top level: it could not be filed here.');
          }
        }
      } else if (mounted) {
        setState(() => _error = 'Saved at the top level, not in this folder.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't add the note.");
    } finally {
      if (mounted) {
        setState(() => _adding = false);
        ref.invalidate(treeFolderControllerProvider);
        ref.invalidate(treeTagsProvider(TreeKind.notes));
      }
    }
  }

  static String _readers(String level) => switch (level) {
        'team' => 'the team',
        'client' => 'clients',
        'public' => 'anyone with the link',
        _ => level,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          // The add button tracks the input's height (guide: a button
          // beside an input is as tall as the input).
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: VoiceTextField(
                    controller: _input,
                    focusNode: _focus,
                    placeholder: Text(
                      widget.folder == null
                          ? 'Capture a note…'
                          : 'Capture a note in ${widget.folder!.name}…',
                    ),
                    onSubmitted: (_) => _add(),
                    onError: (m) => setState(() => _error = m),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _adding ? null : _add,
                  child:
                      const Icon(LucideIcons.plus, semanticLabel: 'Add note'),
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ),
          ),
      ],
    );
  }
}

/// The notes list for a brain older than the folder tree: quick-add on top,
/// tag filter chips, then notes newest-edited first (tap to open, long-press
/// to delete). Backed by `GET/POST /api/notes` via [NotesController].
class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final _input = TextEditingController();
  // An empty + focuses the field: the row reads as a search bar at a
  // glance, and a button that does nothing looks broken (seen on the phone).
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) {
        ref.read(notesControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (_adding) return;
    if (title.isEmpty) {
      _inputFocus.requestFocus();
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(notesControllerProvider.notifier).add(title);
      _input.clear();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't add the note.");
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _confirmDelete(NoteRow note) async {
    final notifier = ref.read(notesControllerProvider.notifier);
    final ok = await confirmDestructive(
      context,
      title: 'Delete note?',
      description: '"${note.title}" is removed from your brain.',
      action: 'Delete',
    );
    if (ok) await notifier.delete(note.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(notesControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Notes', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () =>
                    ref.read(notesControllerProvider.notifier).refresh(),
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
            // The add button tracks the input's height (guide: a button
            // beside an input is as tall as the input).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Expanded(
                      child: VoiceTextField(
                        controller: _input,
                        focusNode: _inputFocus,
                        placeholder: const Text('Capture a note…'),
                        onSubmitted: (_) => _add(),
                        onError: (m) => setState(() => _error = m),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      onPressed: _adding ? null : _add,
                      child: const Icon(LucideIcons.plus, semanticLabel: 'Add note'),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style:
                      theme.textTheme.small.copyWith(color: scheme.destructive),
                ),
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
                      Text("Couldn't load notes.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(notesControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (s) {
                  if (s.notes.isEmpty && s.tag == null) {
                    return Center(
                      child: Text('No notes. Capture one above.',
                          style: theme.textTheme.muted),
                    );
                  }
                  return Column(
                    children: [
                      if (s.tags.isNotEmpty)
                        SizedBox(
                          height: 44,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              ChoicePill(
                                label: 'All',
                                selected: s.tag == null,
                                onTap: () => ref
                                    .read(notesControllerProvider.notifier)
                                    .setTag(null),
                              ),
                              for (final t in s.tags)
                                ChoicePill(
                                  label: '${t.tag} ${t.count}',
                                  selected: s.tag == t.tag,
                                  onTap: () => ref
                                      .read(notesControllerProvider.notifier)
                                      .setTag(s.tag == t.tag ? null : t.tag),
                                ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: s.notes.isEmpty
                            ? Center(
                                child: Text('No notes with this tag.',
                                    style: theme.textTheme.muted),
                              )
                            : ListView(
                                controller: _scroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  24 + MediaQuery.viewInsetsOf(context).bottom,
                                ),
                                children: [
                                  for (final n in s.notes)
                                    _NoteTile(
                                      theme: theme,
                                      note: n,
                                      onTap: () =>
                                          context.push('/notes/${n.id}'),
                                      onLongPress: () => _confirmDelete(n),
                                    ),
                                  if (s.loadingMore)
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Center(
                                        child: Text('Loading more…',
                                            style: theme.textTheme.muted),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.theme,
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final NoteRow note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
              child: Icon(LucideIcons.stickyNote, size: 18, color: muted),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(color: scheme.foreground),
                  ),
                  if (note.preview.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.small.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatWhen(note.updatedAt),
              style: theme.textTheme.small.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
