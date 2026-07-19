import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'files_models.dart';

part 'files_api.g.dart';

/// Mantle Files over HTTP: folder tree via `GET /api/files/folders?parent=`,
/// files via `GET /api/files/files?parent=`, uploads as multipart
/// `{parentPath, file}` (409 = duplicate name, 413 = too large). Bytes come
/// from the existing `GET /api/files/files/{id}?raw=1` (see
/// `fileBytesProvider`).
class FilesApi {
  FilesApi(this._dio);

  final Dio _dio;

  /// Direct child folders of `parentPath` (server sorts by slug).
  Future<List<FolderRow>> folders(String parentPath) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/files/folders',
      queryParameters: {'parent': parentPath},
    );
    return ((res.data?['folders'] as List?) ?? const [])
        .map((e) => FolderRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Files directly in `parentPath`.
  Future<List<FileRow>> files(String parentPath) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/files/files',
      queryParameters: {'parent': parentPath},
    );
    return ((res.data?['files'] as List?) ?? const [])
        .map((e) => FileRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Upload a local file into `parentPath`. Returns the saved row.
  Future<FileRow> upload({
    required String parentPath,
    required String localPath,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'parentPath': parentPath,
      'file': await MultipartFile.fromFile(localPath, filename: filename),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/files/files',
      data: form,
    );
    return FileRow.fromJson((res.data?['file'] as Map).cast<String, dynamic>());
  }

  /// `DELETE /api/files/files/{id}`.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>('/api/files/files/$id');
  }
}

@Riverpod(keepAlive: true)
FilesApi filesApi(Ref ref) => FilesApi(ref.watch(dioProvider));
