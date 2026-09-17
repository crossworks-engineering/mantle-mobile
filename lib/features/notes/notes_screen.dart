import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/notes/notes_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'notes_controller.dart';

/// The notes list: quick-add on top, tag filter chips, then notes newest-
/// edited first (tap to open, long-press to delete). Backed by
/// `GET/POST /api/notes` via [NotesController].
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
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
                      child: ShadInput(
                        controller: _input,
                        focusNode: _inputFocus,
                        placeholder: const Text('Capture a note…'),
                        onSubmitted: (_) => _add(),
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
