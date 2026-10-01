import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/files/files_api.dart';
import '../../data/files/files_models.dart';

part 'files_controller.g.dart';

/// One folder's contents: child folders + files, fetched together.
class FolderContents {
  const FolderContents({required this.folders, required this.files});

  final List<FolderRow> folders;
  final List<FileRow> files;

  bool get isEmpty => folders.isEmpty && files.isEmpty;

  FolderContents copyWith({List<FolderRow>? folders, List<FileRow>? files}) {
    return FolderContents(
      folders: folders ?? this.folders,
      files: files ?? this.files,
    );
  }
}

/// Uploading into and deleting from the folder tree. A folder is named to
/// the upload route by its ltree path (`TreeFolder.path`; the root is
/// `files`), which is also its directory on the brain's disk.
///
/// It holds the client itself, not a `Ref`: the provider is auto-disposed as
/// soon as nothing reads it, and an upload is still running then.
class FileFiling {
  FileFiling(this._files);

  final FilesApi _files;

  /// The ltree path of the Files root.
  static const rootPath = 'files';

  /// Upload a picked local file into [parentPath]. Throws
  /// `TreeVisibilityRefusal` when the folder is shared (nothing was stored);
  /// repeat with [confirm] once the person agreed.
  Future<FileRow> upload({
    required String parentPath,
    required String localPath,
    required String filename,
    bool confirm = false,
  }) {
    return _files.upload(
          parentPath: parentPath,
          localPath: localPath,
          filename: filename,
          confirm: confirm,
        );
  }

  /// One file's row (type and size), for a tree row that only knows its id
  /// and name.
  Future<FileRow> meta(String id) => _files.meta(id);

  Future<void> delete(String id) => _files.delete(id);
}

@riverpod
FileFiling fileFiling(Ref ref) => FileFiling(ref.watch(filesApiProvider));

/// Owns one folder's listing for a brain older than the folder tree (a
/// family by ltree path: each drilled folder
/// screen gets its own instance). Upload refreshes; delete is optimistic
/// with a silent reload on failure.
@riverpod
class FilesController extends _$FilesController {
  @override
  Future<FolderContents> build(String path) => _fetch();

  Future<FolderContents> _fetch() async {
    final api = ref.read(filesApiProvider);
    final (folders, files) = await (api.folders(path), api.files(path)).wait;
    return FolderContents(folders: folders, files: files);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_fetch);
    if (ref.mounted) state = next;
  }

  /// Upload a picked local file into this folder, then reload so the new
  /// row (and its server-derived metadata) appears. Rethrows so the screen
  /// can surface duplicate-name (409) and too-large (413) messages.
  Future<void> upload({
    required String localPath,
    required String filename,
  }) async {
    await ref.read(filesApiProvider).upload(
          parentPath: path,
          localPath: localPath,
          filename: filename,
        );
    if (ref.mounted) await _reloadSilently();
  }

  /// Delete a file (long-press action), optimistically.
  Future<void> deleteFile(String id) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(
        files: [
          for (final f in current.files)
            if (f.id != id) f,
        ],
      ));
    }
    try {
      await ref.read(filesApiProvider).delete(id);
    } catch (_) {
      if (ref.mounted) await _reloadSilently();
    }
  }

  Future<void> _reloadSilently() async {
    try {
      final next = await _fetch();
      if (ref.mounted) state = AsyncData(next);
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}
