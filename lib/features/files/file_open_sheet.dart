import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/files/file_open_service.dart';
import '../../data/files/files_models.dart';
import '../../data/server/server_config.dart';

/// The sheet for a file the phone cannot preview itself: what it is, and the
/// ways to get at it. "Open" downloads a copy to the phone and hands it to the
/// OS's viewer; "Share" sends that copy to another app; "Open in Mantle" is the
/// web app, which is also where editing lives.
Future<void> showFileOpenSheet(BuildContext context, FileRow file) {
  return showShadSheet<void>(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (_) => ShadSheet(child: FileOpenPanel(file: file)),
  );
}

enum _Phase { idle, downloading, failed }

class FileOpenPanel extends ConsumerStatefulWidget {
  const FileOpenPanel({super.key, required this.file});

  final FileRow file;

  @override
  ConsumerState<FileOpenPanel> createState() => _FileOpenPanelState();
}

class _FileOpenPanelState extends ConsumerState<FileOpenPanel> {
  _Phase _phase = _Phase.idle;
  double? _progress;
  String? _message;
  CancelToken? _cancel;

  FileRow get _f => widget.file;

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  /// Download (or reuse the cached copy), then either open or share it.
  Future<void> _run({required bool share}) async {
    final service = ref.read(fileOpenServiceProvider);
    final cancel = CancelToken();
    setState(() {
      _phase = _Phase.downloading;
      _progress = null;
      _message = null;
      _cancel = cancel;
    });
    try {
      final local = await service.download(
        _f,
        cancelToken: cancel,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (received / total).clamp(0.0, 1.0));
        },
      );
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      if (share) {
        if (!await service.share(local, _f) && mounted) {
          setState(() => _message = "Couldn't share that file.");
        }
        return;
      }
      final outcome = await service.open(local, _f);
      if (!mounted) return;
      setState(() {
        _message = switch (outcome) {
          FileOpenOutcome.opened => null,
          FileOpenOutcome.shared =>
            'No app on this phone opens this type, so it was offered to share instead.',
          FileOpenOutcome.failed => "Couldn't open that file on this phone.",
        };
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = CancelToken.isCancel(e) ? _Phase.idle : _Phase.failed;
        _message = CancelToken.isCancel(e)
            ? null
            : "Couldn't download the file.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _message = "Couldn't download the file.";
      });
    } finally {
      _cancel = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final base = ref.watch(serverConfigProvider).value;
    final busy = _phase == _Phase.downloading;
    final large = _f.sizeBytes > kLargeFileBytes;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _f.filename.isEmpty ? _f.title : _f.filename,
            style: theme.textTheme.h4.copyWith(color: scheme.foreground),
          ),
          const SizedBox(height: 4),
          Text(
            '${_f.mimeType} · ${_f.sizeLabel}',
            style: theme.textTheme.muted,
          ),
          if (_f.summary != null && _f.summary!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _f.summary!,
              style: theme.textTheme.p.copyWith(color: scheme.foreground),
            ),
          ],
          const SizedBox(height: 16),
          if (busy) ...[
            Semantics(
              label: _progress == null
                  ? 'Downloading'
                  : 'Downloading, ${(_progress! * 100).round()} percent',
              child: ShadProgress(value: _progress),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _progress == null
                        ? 'Downloading…'
                        : 'Downloading… ${(_progress! * 100).round()}%',
                    style: theme.textTheme.muted,
                  ),
                ),
                ShadButton.ghost(
                  onPressed: () => _cancel?.cancel(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                onPressed: () => _run(share: false),
                // A large file names its size on the button: the download is
                // then something chosen, not something a row tap started.
                child: Text(
                  large ? 'Download ${_f.sizeLabel} and open' : 'Open',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => _run(share: true),
                    child: const Text('Share'),
                  ),
                ),
                if (base != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () async {
                        final uri = Uri.tryParse('$base/n/${_f.id}');
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: const Text('Open in Mantle'),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(_message!, style: theme.textTheme.muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Opening or sharing downloads a copy to this phone. '
            'Copies are removed when you sign out.',
            style: theme.textTheme.muted,
          ),
        ],
      ),
    );
  }
}
