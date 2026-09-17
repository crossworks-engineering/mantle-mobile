import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show TextInputAction, TextSelection;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/chat/chat_attachment.dart';
import 'chat_controller.dart';

/// Documents Mantle can ingest on a turn (mirrors the server's
/// `INGESTABLE_EXTS` / the web composer's file picker `accept`).
const _docExtensions = [
  'pdf', 'docx', 'xlsx', 'xls', 'csv', 'txt', 'md', 'json', 'yaml', 'yml',
];

enum _VoiceState { idle, recording, transcribing }

/// The chat composer: a text input flanked by an attach button (photo / camera
/// / document) and a mic. Attachments preview above the input and post as
/// multipart with the turn. The mic is tap-to-record → tap-to-send (the
/// recording is transcribed server-side, then sent) with a cancel.
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({
    super.key,
    required this.provider,
    required this.textController,
    required this.agentName,
  });

  final ChatControllerProvider provider;
  final TextEditingController textController;

  /// Who the message goes to; the placeholder names them.
  final String agentName;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();

  OutgoingAttachment? _attachment;
  int _attachmentBytes = 0;
  bool _sending = false;
  String? _error;

  _VoiceState _voice = _VoiceState.idle;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  TextEditingController get _input => widget.textController;
  ChatController get _notifier => ref.read(widget.provider.notifier);

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Attachments ──────────────────────────────────────────────────────────

  Future<void> _openAttachMenu() async {
    final choice = await showShadSheet<String>(
      context: context,
      builder: (ctx) => ShadSheet(
        title: const Text('Attach'),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _attachOption(ctx, LucideIcons.image, 'Photo library', 'photo'),
              _attachOption(ctx, LucideIcons.camera, 'Take photo', 'camera'),
              _attachOption(ctx, LucideIcons.fileText, 'File', 'file'),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'photo':
        await _pickImage(ImageSource.gallery);
      case 'camera':
        await _pickImage(ImageSource.camera);
      case 'file':
        await _pickFile();
    }
  }

  Widget _attachOption(
    BuildContext ctx,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: double.infinity,
        child: ShadButton.ghost(
          onPressed: () => Navigator.of(ctx).pop(value),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 12),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      final mime = picked.mimeType ??
          lookupMimeType(picked.path) ??
          'image/jpeg';
      _setAttachment(
        OutgoingAttachment(
          path: picked.path,
          filename: picked.name,
          mime: mime,
        ),
      );
    } catch (e) {
      _showError("Couldn't attach that image.");
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _docExtensions,
      );
      final file = result?.files.singleOrNull;
      final path = file?.path;
      if (file == null || path == null) return;
      final mime = lookupMimeType(file.name) ?? 'application/octet-stream';
      _setAttachment(
        OutgoingAttachment(path: path, filename: file.name, mime: mime),
      );
    } catch (e) {
      _showError("Couldn't attach that file.");
    }
  }

  void _setAttachment(OutgoingAttachment attachment) {
    final f = File(attachment.path);
    setState(() {
      _attachment = attachment;
      _attachmentBytes = f.existsSync() ? f.lengthSync() : 0;
      _error = null;
    });
  }

  void _clearAttachment() => setState(() => _attachment = null);

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    // The field stays editable while a turn is in flight (so the next message
    // can be drafted), but the keyboard's send key must not start a second
    // turn on top of the first.
    if (_sending) return;
    final text = _input.text;
    final attachment = _attachment;
    final attachmentBytes = _attachmentBytes;
    if (text.trim().isEmpty && attachment == null) return;
    _input.clear();
    setState(() {
      _attachment = null;
      _sending = true;
      _error = null;
    });
    var outcome = SendOutcome.failed;
    try {
      outcome = await _notifier.send(text, attachment: attachment);
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          // Stop pressed → put the message back so the user can fix and resend.
          if (outcome == SendOutcome.cancelled) {
            _input.text = text;
            _input.selection =
                TextSelection.collapsed(offset: text.length);
            _attachment = attachment;
            _attachmentBytes = attachmentBytes;
          }
        });
      }
    }
  }

  /// Stop the in-flight turn (a streamed turn aborts server-side, keeping the
  /// partial; a legacy turn cancels the request). [_send] then restores the text
  /// for editing when it returns [SendOutcome.cancelled].
  void _stop() => _notifier.stopTurn();

  // ── Voice ────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    setState(() => _error = null);
    try {
      if (!await _recorder.hasPermission()) {
        _showError('Microphone permission is needed to record.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      if (!mounted) return;
      setState(() {
        _voice = _VoiceState.recording;
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      _showError("Couldn't start recording.");
    }
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    await _recorder.cancel();
    if (mounted) setState(() => _voice = _VoiceState.idle);
  }

  Future<void> _stopAndSendRecording() async {
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
      final text = await _notifier.transcribe(path);
      if (!mounted) return;
      if (text.isEmpty) {
        _showError("Couldn't hear anything — try again.");
      } else {
        await _notifier.send(text);
      }
    } catch (e) {
      _showError(_describeError(e));
    } finally {
      if (mounted) setState(() => _voice = _VoiceState.idle);
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  /// Surface the server's own message for a failed transcribe — e.g. the 412
  /// "No default STT worker configured" hint, or a 422 provider error.
  String _describeError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is String) return data['error'] as String;
    }
    return "Couldn't transcribe the recording.";
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        border: Border(top: BorderSide(color: theme.colorScheme.border)),
      ),
      // Clear the keyboard when open, else the home indicator (the screen no
      // longer sits inside a bottom SafeArea — the header owns the top one).
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_attachment != null) _attachmentPreview(theme),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: theme.textTheme.small
                    .copyWith(color: theme.colorScheme.destructive),
              ),
            ),
          switch (_voice) {
            _VoiceState.recording => _recordingRow(theme),
            _VoiceState.transcribing => _transcribingRow(theme),
            _VoiceState.idle => _inputRow(theme),
          },
        ],
      ),
    );
  }

  /// Two-row composer: the text field gets its own full-width row, with the
  /// attach/mic actions and the send (or stop, while sending) button below.
  Widget _inputRow(ShadThemeData theme) {
    final muted = theme.colorScheme.mutedForeground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadInput(
          controller: _input,
          // ShadInput defaults to the `muted` token (smallest scale); promote
          // the input to body size so typed messages aren't cramped. Keep the
          // placeholder the same size but subdued.
          style: theme.textTheme.p,
          placeholderStyle: theme.textTheme.p.copyWith(color: muted),
          placeholder: Text(
            _attachment != null
                ? 'Add a caption…'
                : 'Message ${widget.agentName}…',
          ),
          maxLines: 6,
          minLines: 1,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _circleIcon(LucideIcons.paperclip, muted,
                onPressed: _sending ? null : _openAttachMenu),
            _circleIcon(LucideIcons.mic, muted,
                onPressed: _sending ? null : _startRecording),
            const Spacer(),
            if (_sending) ...[
              Text('Sending…', style: theme.textTheme.muted),
              const SizedBox(width: 8),
              ShadButton.destructive(
                onPressed: _stop,
                child: const Icon(LucideIcons.square, size: 16),
              ),
            ] else
              ShadButton(
                onPressed: _send,
                child: const Icon(LucideIcons.arrowUp, size: 18),
              ),
          ],
        ),
      ],
    );
  }

  Widget _recordingRow(ShadThemeData theme) {
    final scheme = theme.colorScheme;
    return Row(
      children: [
        _circleIcon(LucideIcons.x, scheme.destructive,
            onPressed: _cancelRecording),
        const SizedBox(width: 4),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: scheme.destructive,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recording  ${_fmt(_elapsed)}',
                style: theme.textTheme.p,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ShadButton(
          onPressed: _stopAndSendRecording,
          child: const Icon(LucideIcons.arrowUp, size: 18),
        ),
      ],
    );
  }

  Widget _transcribingRow(ShadThemeData theme) {
    return Row(
      children: [
        Icon(LucideIcons.loaderCircle,
            size: 18, color: theme.colorScheme.mutedForeground),
        const SizedBox(width: 10),
        Text('Transcribing…', style: theme.textTheme.muted),
      ],
    );
  }

  Widget _circleIcon(
    IconData icon,
    Color color, {
    required VoidCallback? onPressed,
  }) {
    return ShadButton.ghost(
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      child: Icon(icon, size: 22, color: color),
    );
  }

  Widget _attachmentPreview(ShadThemeData theme) {
    final a = _attachment!;
    final scheme = theme.colorScheme;
    // A flat accent card, like the inbox rows: every piece of text on it is
    // accentForeground, the meta line tinted with opacity.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: a.isImage
                  ? Image.file(File(a.path), fit: BoxFit.cover)
                  : Container(
                      color: scheme.background,
                      alignment: Alignment.center,
                      child: Icon(LucideIcons.fileText,
                          size: 22, color: scheme.foreground),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small
                      .copyWith(color: scheme.accentForeground),
                ),
                Text(
                  _attachmentBytes > 0
                      ? '${(_attachmentBytes / 1024).toStringAsFixed(0)} KB'
                      : (a.isImage ? 'Image' : 'File'),
                  style: theme.textTheme.muted.copyWith(
                    color: scheme.accentForeground.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          ShadButton.ghost(
            onPressed: _clearAttachment,
            padding: const EdgeInsets.all(6),
            child: Icon(LucideIcons.x,
                size: 16, color: scheme.accentForeground),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
