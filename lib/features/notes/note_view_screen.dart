import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/notes/notes_models.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/voice_text_field.dart';
import '../chat/markdown/mantle_markdown.dart';
import '../tree/tree_controller.dart';
import 'notes_controller.dart';

/// One note: title + tags, the content rendered as markdown, and an Edit
/// sheet (title / content / comma-separated tags → `PATCH /api/notes/{id}`).
/// Backed by [NoteViewController].
class NoteViewScreen extends ConsumerWidget {
  const NoteViewScreen({super.key, required this.noteId});

  final String noteId;

  Future<void> _edit(BuildContext context, WidgetRef ref, NoteRow note) async {
    final saved = await showShadSheet<NoteRow>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) => _NoteEditSheet(note: note),
    );
    // The save already updated this screen's state; sync the list's preview
    // only if the list is actually alive (a Search deep link reaches here
    // without it — instantiating it just to patch a row would kick off a
    // throwaway fetch that races the write).
    if (saved == null) return;
    if (ref.exists(notesControllerProvider)) {
      ref.read(notesControllerProvider.notifier).applyUpdated(saved);
    }
    // The folder tree shows titles: ask the open folders again (their rows
    // stay on screen while the answer is on its way).
    ref.invalidate(treeFolderControllerProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(noteViewControllerProvider(noteId));

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
                HeaderAction(
                  icon: LucideIcons.pencil,
                  label: 'Edit',
                  size: 18,
                  onPressed: () => _edit(context, ref, async.value!),
                ),
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
                      Text("Couldn't load the note.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () =>
                            ref.invalidate(noteViewControllerProvider(noteId)),
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
      final saved = await ref
          .read(noteViewControllerProvider(widget.note.id).notifier)
          .save(title: title, content: _content.text, tags: tags);
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
            VoiceTextField(
              controller: _title,
              placeholder: const Text('Title'),
              onError: (m) => setState(() => _error = m),
            ),
            const SizedBox(height: 8),
            VoiceTextField(
              controller: _content,
              placeholder: const Text('Write…'),
              style: theme.textTheme.p,
              minLines: 6,
              maxLines: 12,
              onError: (m) => setState(() => _error = m),
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
