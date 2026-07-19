import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/notes/notes_api.dart';
import '../../data/notes/notes_models.dart';
import '../../widgets/mantle_header.dart';
import '../chat/markdown/mantle_markdown.dart';
import 'notes_controller.dart';

/// One note: title + tags, the content rendered as markdown, and an Edit
/// sheet (title / content / comma-separated tags → `PATCH /api/notes/{id}`).
/// Backed by [noteContentProvider].
class NoteViewScreen extends ConsumerWidget {
  const NoteViewScreen({super.key, required this.noteId});

  final String noteId;

  Future<void> _edit(BuildContext context, WidgetRef ref, NoteRow note) async {
    final saved = await showShadSheet<NoteRow>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) => _NoteEditSheet(note: note),
    );
    if (saved != null) {
      // Refresh this screen and keep the list's preview in step.
      ref.invalidate(noteContentProvider(noteId));
      ref.read(notesControllerProvider.notifier).applyUpdated(saved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(noteContentProvider(noteId));

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: MantleHeaderTitle(
              async.value?.title ?? 'Note',
              wordmark: false,
            ),
            trailing: [
              if (async.value != null)
                ShadButton.ghost(
                  onPressed: () => _edit(context, ref, async.value!),
                  child: Icon(LucideIcons.pencil, size: 18, color: fg),
                ),
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
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
                      Text("Couldn't load the note.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () =>
                            ref.invalidate(noteContentProvider(noteId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (note) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    Text(
                      note.title,
                      style:
                          theme.textTheme.h3.copyWith(color: scheme.foreground),
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in note.tags)
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
                    if (note.content.trim().isEmpty)
                      Text('No content yet — tap the pencil to write.',
                          style: theme.textTheme.muted)
                    else
                      MantleMarkdown(note.content),
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

/// Bottom-sheet editor: title, multiline content, comma-separated tags.
/// Pops with the saved row (null = cancelled).
class _NoteEditSheet extends ConsumerStatefulWidget {
  const _NoteEditSheet({required this.note});

  final NoteRow note;

  @override
  ConsumerState<_NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends ConsumerState<_NoteEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note.title);
    _content = TextEditingController(text: widget.note.content);
    _tags = TextEditingController(text: widget.note.tags.join(', '));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final tags = _tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final saved = await ref.read(notesApiProvider).update(
            widget.note.id,
            title: title,
            content: _content.text,
            tags: tags,
          );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save the note.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return ShadSheet(
      child: Padding(
        padding: EdgeInsets.only(
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit note',
                style: theme.textTheme.h4.copyWith(color: scheme.foreground)),
            const SizedBox(height: 12),
            ShadInput(
              controller: _title,
              placeholder: const Text('Title'),
            ),
            const SizedBox(height: 8),
            ShadInput(
              controller: _content,
              placeholder: const Text('Write…'),
              style: theme.textTheme.p,
              minLines: 6,
              maxLines: 12,
            ),
            const SizedBox(height: 8),
            ShadInput(
              controller: _tags,
              placeholder: const Text('Tags (comma-separated)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShadButton.outline(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
