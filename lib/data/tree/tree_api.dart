import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'tree_models.dart';

part 'tree_api.g.dart';

/// The brain answered 404 for a kind's tree ROOT: it is older than the tree
/// (before Mantle v0.232.366), or it does not serve this kind. The screen
/// falls back to the list it had before the tree.
class TreeUnavailable implements Exception {
  const TreeUnavailable();
}

/// A folder the reader cannot see, or that is gone. Both answer 404; the
/// brain does not say which.
class TreeFolderMissing implements Exception {
  const TreeFolderMissing();
}

/// The brain's item tree over HTTP (mantle `docs/folder-tree.md`).
///
/// Reads are lazy: one folder's subfolders and one page of its items at a
/// time, paged by a keyset cursor. This client only reads and files items;
/// folders are made, named and shared on the web.
class TreeApi {
  TreeApi(this._dio);

  final Dio _dio;

  static const _base = '/api/tree';

  /// `GET /api/tree/:kind?folder=&cursor=&sort=&limit=`. No [folderId] is the
  /// kind's root.
  Future<TreeFolderPage> folder(
    TreeKind kind, {
    String? folderId,
    String? cursor,
    TreeSort? sort,
    int? limit,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_base/${kind.wire}',
        queryParameters: {
          'folder': ?folderId,
          'cursor': ?cursor,
          'sort': ?sort?.name,
          'limit': ?limit,
        },
      );
      return TreeFolderPage.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // With a folder named, the folder is what was not found. With none,
        // the route itself was not: an older brain.
        throw folderId == null
            ? const TreeUnavailable()
            : const TreeFolderMissing();
      }
      rethrow;
    }
  }

  /// `GET /api/tree/:kind/search?q=&cursor=&tag=`: matching folders, then
  /// items, each with its crumbs. An empty [q] with a [tag] lists the items
  /// carrying it; a filtered search has no folders.
  Future<TreeSearchResult> search(
    TreeKind kind,
    String q, {
    String? cursor,
    String? tag,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/${kind.wire}/search',
      queryParameters: {
        'q': q,
        'cursor': ?cursor,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    return TreeSearchResult.fromJson(res.data ?? const {});
  }

  /// `GET /api/tree/:kind/marks?view=`: this login's pinned, recent or most
  /// used items.
  Future<TreeMarkList> marks(TreeKind kind, TreeMarkView view) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_base/${kind.wire}/marks',
      queryParameters: {'view': view.name},
    );
    return TreeMarkList.fromJson(res.data ?? const {});
  }

  /// `GET /api/tree/:kind/tags`: the tags on the kind's items, most used
  /// first.
  Future<List<TreeTag>> tags(TreeKind kind) async {
    final res =
        await _dio.get<Map<String, dynamic>>('$_base/${kind.wire}/tags');
    return TreeTag.listFrom(res.data ?? const {});
  }

  /// `POST /api/tree/items/:id/opened`: count one open, which is what the
  /// Recent view lists. Best-effort; a failure is not worth telling anyone.
  Future<void> opened(String itemId) async {
    try {
      await _dio.post<Map<String, dynamic>>('$_base/items/$itemId/opened');
    } catch (_) {
      /* Recent is a convenience */
    }
  }

  /// `POST /api/tree/:kind/move`: file items into [folderId] (null is the
  /// root). Throws [TreeVisibilityRefusal] when the move would change who can
  /// read them; repeat with [confirm] and the refusal's `seen` once the
  /// person agreed. Returns the ids that could not be moved.
  Future<List<String>> move(
    TreeKind kind,
    List<String> ids,
    String? folderId, {
    bool confirm = false,
    int? seen,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$_base/${kind.wire}/move',
        data: {
          'ids': ids,
          'folderId': folderId,
          if (confirm) 'confirm': true,
          if (confirm) 'seen': ?seen,
        },
      );
      return [
        for (final f in (res.data?['failed'] as List?) ?? const [])
          if (f is Map && f['id'] is String) f['id'] as String,
      ];
    } on DioException catch (e) {
      final refusal = e.response?.statusCode == 409
          ? TreeVisibilityRefusal.tryParse(e.response?.data)
          : null;
      if (refusal != null) throw refusal;
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
TreeApi treeApi(Ref ref) => TreeApi(ref.watch(dioProvider));
