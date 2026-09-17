import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/journal/journal_models.dart';
import '../../core/format/dates.dart';
import '../../theme/mantle_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/mantle_header.dart';
import 'journal_controller.dart';

enum _VoiceState { idle, recording, transcribing }

/// The journal: a quick-capture composer above newest-first entries. The mic
/// makes the phone the brain's capture device — tap to record, tap to stop;
/// the recording transcribes server-side (the chat's STT pipeline) into the
/// text field for a quick review before saving. Tap an entry to edit or
/// delete it; an assistant's open question opens with an answer box instead.
/// Backed by `GET/POST/PATCH/DELETE /api/journal` via [JournalController].
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _input = TextEditingController();
  // An empty + focuses the field (see notes_screen.dart).
  final _inputFocus = FocusNode();
  final _recorder = AudioRecorder();
  var _voice = _VoiceState.idle;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Capture ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final body = _input.text.trim();
    if (_saving) return;
    if (body.isEmpty) {
      _inputFocus.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(journalControllerProvider.notifier).capture(body);
      _input.clear();
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't save the entry — try again.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Voice (mirrors the chat composer's mic flow) ─────────────────────────

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission is needed to record.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/journal-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _voice = _VoiceState.recording;
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      setState(() => _error = "Couldn't start recording.");
    }
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() => _voice = _VoiceState.idle);
  }

  /// Stop and transcribe INTO the text field (not straight to save) — spoken
  /// entries get a quick visual once-over before they land in the brain.
  Future<void> _stopAndTranscribe() async {
    _ticker?.cancel();
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    if (path == null) {
      setState(() => _voice = _VoiceState.idle);
      return;
    }
    setState(() => _voice = _VoiceState.transcribing);
    try {
      final text =
          await ref.read(journalControllerProvider.notifier).transcribe(path);
      if (!mounted) return;
      if (text.isEmpty) {
        setState(() => _error = "Couldn't hear anything — try again.");
      } else {
        final existing = _input.text.trim();
        final combined = existing.isEmpty ? text : '$existing\n$text';
        _input.text = combined;
        _input.selection = TextSelection.collapsed(offset: combined.length);
      }
    } catch (e) {
      if (mounted) setState(() => _error = _describeError(e));
    } finally {
      if (mounted) setState(() => _voice = _VoiceState.idle);
    }
  }

  String _describeError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
    }
    return "Couldn't transcribe the recording.";
  }

  String _elapsedLabel() {
    final m = _elapsed.inMinutes;
    final s = _elapsed.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(journalControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Journal', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () =>
                    ref.read(journalControllerProvider.notifier).refresh(),
              ),
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          _Composer(
            theme: theme,
            input: _input,
            inputFocus: _inputFocus,
            voice: _voice,
            saving: _saving,
            error: _error,
            elapsedLabel: _elapsedLabel(),
            onSave: _save,
            onMic: _startRecording,
            onStopRecording: _stopAndTranscribe,
            onCancelRecording: _cancelRecording,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: async.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Couldn't load the journal.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(journalControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? Center(
                        child: Text(
                          'No entries yet. Speak or type one above.',
                          style: theme.textTheme.muted,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: entries.length,
                        itemBuilder: (context, i) => _EntryCard(
                          theme: theme,
                          entry: entries[i],
                          onTap: () => showShadSheet<void>(
                            context: context,
                            builder: (_) => EntrySheet(entry: entries[i]),
                          ),
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


class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.theme,
    required this.entry,
    required this.onTap,
  });

  final ShadThemeData theme;
  final JournalRow entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final onAccent = scheme.accentForeground;
    final dim = onAccent.withValues(alpha: 0.6);
    // An open question gets a warning dot (status colours are fills only)
    // and says so; a resolved one is just a past entry with its label.
    final gapLabel = entry.isGap
        ? (entry.isOpenGap ? 'Open question' : 'Answered')
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.accent,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDay(entry.displayDate),
                    style: theme.textTheme.small.copyWith(color: dim),
                  ),
                ),
                if (gapLabel != null) ...[
                  if (entry.isOpenGap)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: MantleColors.of(context)
                              .warning(theme.brightness),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  Text(
                    gapLabel,
                    style: theme.textTheme.small.copyWith(
                      color: entry.isOpenGap ? onAccent : dim,
                    ),
                  ),
                ] else if (entry.fromAgent)
                  Text(
                    entry.agentSlug ?? 'agent',
                    style: theme.textTheme.small.copyWith(color: dim),
                  )
                else if (entry.mood != null && entry.mood!.isNotEmpty)
                  Text(
                    entry.mood!,
                    style: theme.textTheme.small.copyWith(color: dim),
                  ),
              ],
            ),
            if (entry.title.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.title,
                style: theme.textTheme.p.copyWith(
                  color: onAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (entry.body.isNotEmpty &&
                entry.body.trim() != entry.title.trim()) ...[
              const SizedBox(height: 4),
              Text(
                entry.body,
                style: theme.textTheme.muted.copyWith(
                  color: onAccent.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

/// One entry, opened from the list. A plain entry edits in place and can be
/// deleted (behind a confirm). An assistant's open question shows the
/// question and takes an answer instead: answering resolves it and files
/// the answer as an entry every agent carries from then on.
class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, required this.entry});

  final JournalRow entry;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  late final _text = TextEditingController(
    text: widget.entry.isOpenGap ? '' : widget.entry.body,
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() {
    final body = _text.text.trim();
    if (body.isEmpty) {
      setState(() => _error = 'Write something first.');
      return Future.value();
    }
    final notifier = ref.read(journalControllerProvider.notifier);
    return _run(
      () => notifier.edit(widget.entry.id, body: body),
      "Couldn't save the entry.",
    );
  }

  Future<void> _answer() {
    final answer = _text.text.trim();
    if (answer.isEmpty) {
      setState(() => _error = 'Write an answer first.');
      return Future.value();
    }
    final notifier = ref.read(journalControllerProvider.notifier);
    return _run(
      () => notifier.answerGap(widget.entry.id, answer: answer),
      "Couldn't save the answer.",
    );
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete entry?',
      description: 'This entry is removed from your brain.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    final notifier = ref.read(journalControllerProvider.notifier);
    await _run(() => notifier.delete(widget.entry.id), "Couldn't delete it.");
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final entry = widget.entry;
    final asking = entry.isOpenGap;
    return ShadSheet(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asking ? 'A question for you' : formatDay(entry.displayDate),
              style: theme.textTheme.h4,
            ),
            if (entry.fromAgent) ...[
              const SizedBox(height: 2),
              Text(
                'From ${entry.agentSlug ?? 'an agent'}',
                style: theme.textTheme.muted,
              ),
            ],
            const SizedBox(height: 12),
            if (asking) ...[
              Text(entry.body.isNotEmpty ? entry.body : entry.title,
                  style: theme.textTheme.p),
              const SizedBox(height: 12),
            ],
            ShadInput(
              controller: _text,
              placeholder: Text(asking ? 'Your answer…' : 'Entry'),
              minLines: asking ? 2 : 3,
              maxLines: 10,
              enabled: !_busy,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                onPressed: _busy ? null : (asking ? _answer : _save),
                child: Text(
                  _busy
                      ? 'Saving…'
                      : asking
                          ? 'Answer'
                          : 'Save',
                ),
              ),
            ),
            if (!asking) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ShadButton.outline(
                  onPressed: _busy ? null : _delete,
                  leading: const Icon(LucideIcons.trash2, size: 16),
                  child: const Text('Delete'),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The capture bar: text field + mic + save. While recording it swaps to a
/// timer with cancel/stop; while transcribing it shows progress.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.theme,
    required this.input,
    required this.inputFocus,
    required this.voice,
    required this.saving,
    required this.error,
    required this.elapsedLabel,
    required this.onSave,
    required this.onMic,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  final ShadThemeData theme;
  final TextEditingController input;
  final FocusNode inputFocus;
  final _VoiceState voice;
  final bool saving;
  final String? error;
  final String elapsedLabel;
  final VoidCallback onSave;
  final VoidCallback onMic;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      // Sits under the header like the Notes and Tasks quick-add rows, so
      // the keyboard never covers it.
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                error!,
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ),
          if (voice == _VoiceState.recording)
            Row(
              children: [
                Icon(LucideIcons.mic, size: 18, color: scheme.destructive),
                const SizedBox(width: 8),
                Text(elapsedLabel, style: theme.textTheme.p),
                const Spacer(),
                ShadButton.ghost(
                  onPressed: onCancelRecording,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: onStopRecording,
                  child: const Text('Use it'),
                ),
              ],
            )
          else if (voice == _VoiceState.transcribing)
            Row(
              children: [
                Icon(LucideIcons.audioLines,
                    size: 18, color: scheme.mutedForeground),
                const SizedBox(width: 8),
                Text('Transcribing…', style: theme.textTheme.muted),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ShadInput(
                    controller: input,
                    focusNode: inputFocus,
                    placeholder: const Text('What happened?'),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  onPressed: onMic,
                  child: Icon(LucideIcons.mic,
                      size: 20,
                      color: scheme.foreground,
                      semanticLabel: 'Dictate an entry'),
                ),
                ShadButton(
                  onPressed: saving ? null : onSave,
                  child: const Icon(LucideIcons.plus,
                      semanticLabel: 'Save entry'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
