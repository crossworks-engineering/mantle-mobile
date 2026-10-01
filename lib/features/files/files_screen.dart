import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/files/files_api.dart' show FileUploadException;
import '../../data/files/files_models.dart';
import '../../data/tree/tree_models.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'file_open_sheet.dart';
import '../tree/tree_browser.dart';
import '../tree/tree_controller.dart';
import '../tree/tree_rows.dart';
import 'files_controller.dart';

/// The brain's file library, in its folders: the shared [TreeBrowser] with
/// the upload row on top (camera, photo library, any document) that uploads
/// into the OPEN folder. Tap an image to preview it authed; anything else
/// gets the open sheet (download and hand to the phone's viewer, share, or
/// "Open in Mantle"). Long-press deletes.
class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key, this.folderId, this.legacyPath});

  /// Open on this folder instead of the top level.
  final String? folderId;

  /// The ltree path a brain older than the tree is drilled into
  /// (`/files?path=`); only the pre-tree screen reads it.
  final String? legacyPath;

  Future<void> _open(BuildContext context, WidgetRef ref, TreeItem item) async {
    if (treeFileIsImage(item)) {
      context.push(
        '/files/image/${item.id}?name=${Uri.encodeComponent(item.title)}',
      );
      return;
    }
    // A tree row knows a file's id and name. The open sheet wants its type
    // and size too, so fetch the row first.
    try {
      final row = await ref.read(fileFilingProvider).meta(item.id);
      if (context.mounted) await showFileOpenSheet(context, row);
    } catch (_) {
      if (context.mounted) {
        ShadToaster.maybeOf(context)?.show(
          const ShadToast(description: Text("Couldn't open that file.")),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TreeItem file,
    String? inFolder,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete file?',
      description: '"${file.title}" is removed from your brain.',
      action: 'Delete',
    );
    if (!ok) return;
    ref
        .read(treeFolderControllerProvider(TreeKind.files, inFolder).notifier)
        .removeItem(file.id);
    try {
      await ref.read(fileFilingProvider).delete(file.id);
    } catch (_) {
      /* the reload below puts the row back */
    }
    if (!context.mounted) return;
    ref.invalidate(treeFolderControllerProvider);
    ref.invalidate(treeRecentProvider(TreeKind.files));
    await ref
        .read(treeSearchControllerProvider(TreeKind.files).notifier)
        .searchNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TreeBrowser(
      kind: TreeKind.files,
      title: 'Files',
      searchPlaceholder: 'Search files…',
      initialFolderId: folderId,
      emptyHere: 'Nothing here yet. Upload something above.',
      onOpenItem: (item) => _open(context, ref, item),
      onLongPressItem: (item, inFolder) =>
          _confirmDelete(context, ref, item, inFolder),
      top: (context, folder) => _UploadRow(folder: folder),
      legacy: (_) => FilesListScreen(path: legacyPath ?? FileFiling.rootPath),
    );
  }
}

/// Picking a picture or a document and handing it to [upload]. Shared by the
/// tree's upload row and the pre-tree screen.
mixin _FilePicking<T extends StatefulWidget> on State<T> {
  final _imagePicker = ImagePicker();
  bool uploading = false;
  String? error;

  Future<void> upload(String localPath, String filename);

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (picked == null) return;
      await upload(picked.path, picked.name);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(
        () => error = e.code == 'camera_access_denied'
            ? 'Camera access is off, so you can upload a photo from your library instead.'
            : "Couldn't pick that image.",
      );
    } catch (_) {
      if (mounted) setState(() => error = "Couldn't pick that image.");
    }
  }

  Future<void> pickDocument() async {
    try {
      final file = await FilePicker.pickFile();
      final path = file?.path;
      if (file == null || path == null) return;
      await upload(path, file.name);
    } catch (_) {
      if (mounted) setState(() => error = "Couldn't pick that file.");
    }
  }

  /// The three upload buttons and what is going on under them.
  Widget uploadRow(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: ShadButton.outline(
                  onPressed:
                      uploading ? null : () => pickImage(ImageSource.camera),
                  child: const Icon(
                    LucideIcons.camera,
                    size: 16,
                    semanticLabel: 'Take a photo to upload',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed:
                      uploading ? null : () => pickImage(ImageSource.gallery),
                  child: const Icon(
                    LucideIcons.image,
                    size: 16,
                    semanticLabel: 'Upload from the photo library',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ShadButton.outline(
                  onPressed: uploading ? null : pickDocument,
                  child: const Icon(
                    LucideIcons.paperclip,
                    size: 16,
                    semanticLabel: 'Upload a document',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (uploading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Uploading…', style: theme.textTheme.muted),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                error!,
                style: theme.textTheme.small.copyWith(
                  color: scheme.destructive,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The upload row above a folder's files. Uploads land in [folder], the
/// folder on screen; a shared folder asks first, because the file becomes
/// readable by everyone the folder is shared with.
class _UploadRow extends ConsumerStatefulWidget {
  const _UploadRow({required this.folder});

  /// Null at the top level.
  final TreeFolder? folder;

  @override
  ConsumerState<_UploadRow> createState() => _UploadRowState();
}

class _UploadRowState extends ConsumerState<_UploadRow> with _FilePicking {
  @override
  Future<void> upload(String localPath, String filename) async {
    final folder = widget.folder;
    final filing = ref.read(fileFilingProvider);
    final parentPath = folder?.path ?? FileFiling.rootPath;
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      try {
        await filing.upload(
          parentPath: parentPath,
          localPath: localPath,
          filename: filename,
        );
      } on TreeVisibilityRefusal catch (refusal) {
        final to = refusal.to;
        final ok = mounted &&
            await confirmAction(
              context,
              title: 'Upload to a shared folder?',
              description: to == null
                  ? '"${folder?.name ?? 'This folder'}" is shared, so this '
                      'file will be readable by more people than you.'
                  : '"${folder?.name ?? 'This folder'}" is shared: this file '
                      'will be readable by ${_readers(to)}.',
              action: 'Upload',
            );
        if (!ok) return;
        await filing.upload(
          parentPath: parentPath,
          localPath: localPath,
          filename: filename,
          confirm: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FileUploadException
              ? e.message
              : "Couldn't upload the file.",
        );
      }
    } finally {
      if (mounted) {
        setState(() => uploading = false);
        ref.invalidate(treeFolderControllerProvider);
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
  Widget build(BuildContext context) => uploadRow(context);
}

/// One folder of the file library on a brain older than the folder tree:
/// child folders first, then files, each drilled folder its own route push.
class FilesListScreen extends ConsumerStatefulWidget {
  const FilesListScreen({super.key, this.path = 'files'});

  /// ltree path of the folder being shown (root = `files`).
  final String path;

  @override
  ConsumerState<FilesListScreen> createState() => _FilesListScreenState();
}

class _FilesListScreenState extends ConsumerState<FilesListScreen>
    with _FilePicking {
  String get _title {
    if (widget.path == 'files') return 'Files';
    final slug = widget.path.split('.').last;
    return slug.isEmpty ? 'Files' : slug[0].toUpperCase() + slug.substring(1);
  }

  String get _breadcrumb => widget.path.split('.').join(' / ');

  @override
  Future<void> upload(String localPath, String filename) async {
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      await ref
          .read(filesControllerProvider(widget.path).notifier)
          .upload(localPath: localPath, filename: filename);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FileUploadException
              ? e.message
              : "Couldn't upload the file.",
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
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

  void _openFile(FileRow f) {
    if (f.isImage) {
      context.push(
        '/files/image/${f.id}?name=${Uri.encodeComponent(f.filename)}',
      );
    } else {
      showFileOpenSheet(context, f);
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
          uploadRow(context),
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
                      Text(
                        "Couldn't load this folder.",
                        style: theme.textTheme.muted,
                      ),
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
                      child: Text(
                        'Nothing here yet. Upload something above.',
                        style: theme.textTheme.muted,
                      ),
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
                    Text(
                      counts,
                      style: theme.textTheme.small.copyWith(color: muted),
                    ),
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
                  Text(
                    file.sizeLabel,
                    style: theme.textTheme.small.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
