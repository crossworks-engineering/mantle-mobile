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

/// Owns one folder's listing (a family by ltree path — each drilled folder
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
    state = await AsyncValue.guard(_fetch);
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
    await _reloadSilently();
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
      await _reloadSilently();
    }
  }

  Future<void> _reloadSilently() async {
    try {
      state = AsyncData(await _fetch());
    } catch (_) {
      /* keep current; pull-to-refresh reconciles */
    }
  }
}
