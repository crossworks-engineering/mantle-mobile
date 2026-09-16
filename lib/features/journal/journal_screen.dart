import 'dart:async';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/journal/journal_models.dart';
import '../../widgets/mantle_header.dart';
import 'journal_controller.dart';

enum _VoiceState { idle, recording, transcribing }

/// The journal: newest-first entries above a quick-capture composer. The mic
/// makes the phone the brain's capture device — tap to record, tap to stop;
/// the recording transcribes server-side (the chat's STT pipeline) into the
/// text field for a quick review before saving. Backed by
/// `GET/POST /api/journal` via [JournalController].
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _input = TextEditingController();
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
    super.dispose();
  }

  // ── Capture ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final body = _input.text.trim();
    if (body.isEmpty || _saving) return;
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
    final fg = scheme.primaryForeground;
    final async = ref.watch(journalControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Journal', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () =>
                    ref.read(journalControllerProvider.notifier).refresh(),
                child: Icon(LucideIcons.refreshCw, size: 18, color: fg),
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
                          'No entries yet. Speak or type one below.',
                          style: theme.textTheme.muted,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        itemCount: entries.length,
                        itemBuilder: (context, i) =>
                            _EntryCard(theme: theme, entry: entries[i]),
                      ),
              ),
            ),
          ),
          _Composer(
            theme: theme,
            input: _input,
            voice: _voice,
            saving: _saving,
            error: _error,
            elapsedLabel: _elapsedLabel(),
            onSave: _save,
            onMic: _startRecording,
            onStopRecording: _stopAndTranscribe,
            onCancelRecording: _cancelRecording,
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.theme, required this.entry});

  final ShadThemeData theme;
  final JournalRow entry;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final onAccent = scheme.accentForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                    _dateLabel(entry.displayDate),
                    style: theme.textTheme.small.copyWith(
                      color: onAccent.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                if (entry.mood != null && entry.mood!.isNotEmpty)
                  Text(
                    entry.mood!,
                    style: theme.textTheme.small.copyWith(
                      color: onAccent.withValues(alpha: 0.6),
                    ),
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
    );
  }
}

/// The capture bar: text field + mic + save. While recording it swaps to a
/// timer with cancel/stop; while transcribing it shows progress.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.theme,
    required this.input,
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
      decoration: BoxDecoration(
        color: scheme.background,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      // Clear the keyboard when open, else the home indicator. There is no
      // Scaffold to resize the body, so the composer pads itself (same as
      // the chat composer).
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 +
            (MediaQuery.viewInsetsOf(context).bottom == 0
                ? MediaQuery.viewPaddingOf(context).bottom
                : MediaQuery.viewInsetsOf(context).bottom),
      ),
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
                    placeholder: const Text('What happened?'),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton.ghost(
                  onPressed: onMic,
                  child: Icon(LucideIcons.mic,
                      size: 20, color: scheme.foreground),
                ),
                ShadButton(
                  onPressed: saving ? null : onSave,
                  child: const Icon(LucideIcons.check),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
