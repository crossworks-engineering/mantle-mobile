import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/files/files_api.dart' show FileUploadException;
import '../../data/files/files_models.dart';
import '../../data/server/server_config.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'files_controller.dart';

/// One folder of the brain's file library: child folders first, then files.
/// Tap a folder to drill in (each level is its own route push, so back just
/// works); tap an image to preview it authed; anything else gets a detail
/// sheet with "Open in Mantle". The bottom bar uploads into THIS folder —
/// camera, photo library, or any document.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key, this.path = 'files'});

  /// ltree path of the folder being shown (root = `files`).
  final String path;

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final _imagePicker = ImagePicker();
  bool _uploading = false;
  String? _error;

  String get _title {
    if (widget.path == 'files') return 'Files';
    final slug = widget.path.split('.').last;
    return slug.isEmpty ? 'Files' : slug[0].toUpperCase() + slug.substring(1);
  }

  String get _breadcrumb => widget.path.split('.').join(' / ');

  Future<void> _upload(String localPath, String filename) async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref
          .read(filesControllerProvider(widget.path).notifier)
          .upload(localPath: localPath, filename: filename);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is FileUploadException
            ? e.message
            : "Couldn't upload the file.");
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _upload(picked.path, picked.name);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't pick that image.");
    }
  }

  Future<void> _pickDocument() async {
    try {
      final file = await FilePicker.pickFile();
      final path = file?.path;
      if (file == null || path == null) return;
      await _upload(path, file.name);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't pick that file.");
    }
  }

  Future<void> _confirmDeleteFile(FileRow file) async {
    final notifier = ref.read(filesControllerProvider(widget.path).notifier);
    final ok = await confirmDestructive(
      context,
      title: 'Delete file?',
      description: '"${file.title}" is removed from your brain.',
      action: 'Delete',
    );
    if (ok) await notifier.deleteFile(file.id);
  }

  Future<void> _showFileDetails(FileRow f) async {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final base = ref.read(serverConfigProvider).value;
    await showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (ctx) => ShadSheet(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(f.filename,
                  style: theme.textTheme.h4.copyWith(color: scheme.foreground)),
              const SizedBox(height: 4),
              Text('${f.mimeType} · ${f.sizeLabel}',
                  style: theme.textTheme.muted),
              if (f.summary != null && f.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(f.summary!,
                    style:
                        theme.textTheme.p.copyWith(color: scheme.foreground)),
              ],
              const SizedBox(height: 16),
              if (base != null)
                SizedBox(
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: () async {
                      final uri = Uri.tryParse('$base/n/${f.id}');
                      if (uri != null) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Open in Mantle'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFile(FileRow f) {
    if (f.isImage) {
      context.push(
        '/files/image/${f.id}?name=${Uri.encodeComponent(f.filename)}',
      );
    } else {
      _showFileDetails(f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(filesControllerProvider(widget.path));

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: MantleHeaderTitle(_title, wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () => ref
                    .read(filesControllerProvider(widget.path).notifier)
                    .refresh(),
              ),
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_breadcrumb, style: theme.textTheme.muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                    child: const Icon(LucideIcons.camera, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.outline(
                    onPressed:
                        _uploading ? null : () => _pickImage(ImageSource.gallery),
                    child: const Icon(LucideIcons.image, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _uploading ? null : _pickDocument,
                    child: const Icon(LucideIcons.paperclip, size: 16),
                  ),
                ),
              ],
            ),
          ),
          if (_uploading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Uploading…', style: theme.textTheme.muted),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
                      Text("Couldn't load this folder.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(filesControllerProvider(widget.path).notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (c) {
                  if (c.isEmpty) {
                    return Center(
                      child: Text('Nothing here yet. Upload something above.',
                          style: theme.textTheme.muted),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final folder in c.folders)
                        _FolderTile(
                          theme: theme,
                          folder: folder,
                          onTap: () => context.push(
                            '/files?path=${Uri.encodeComponent(folder.path)}',
                          ),
                        ),
                      for (final file in c.files)
                        _FileTile(
                          theme: theme,
                          file: file,
                          onTap: () => _openFile(file),
                          onLongPress: () => _confirmDeleteFile(file),
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

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.theme,
    required this.folder,
    required this.onTap,
  });

  final ShadThemeData theme;
  final FolderRow folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    final counts = [
      if (folder.childFolderCount > 0) '${folder.childFolderCount} folders',
      if (folder.fileCount > 0) '${folder.fileCount} files',
    ].join(' · ');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
              child: Icon(LucideIcons.folder, size: 18, color: scheme.primary),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.title.isEmpty ? folder.slug : folder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(color: scheme.foreground),
                  ),
                  if (counts.isNotEmpty)
                    Text(counts,
                        style: theme.textTheme.small.copyWith(color: muted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: muted),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.theme,
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final FileRow file;
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
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
              child: Icon(
                file.isImage ? LucideIcons.image : LucideIcons.file,
                size: 18,
                color: muted,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.p.copyWith(color: scheme.foreground),
                  ),
                  Text(file.sizeLabel,
                      style: theme.textTheme.small.copyWith(color: muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
