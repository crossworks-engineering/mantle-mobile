import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'notes_models.dart';

part 'notes_api.g.dart';

/// Mantle Notes over HTTP: `GET/POST /api/notes`, `GET/PATCH/DELETE
/// /api/notes/{id}`. Agent digests stay hidden (the server's default —
/// no `digests=1`). Sorted by `updatedAt` desc, server page size 50.
class NotesApi {
  NotesApi(this._dio);

  final Dio _dio;

  /// `GET /api/notes?page=…&q=…&tag=…` — one page + total + tag facets.
  Future<NotesPage> list({int page = 1, String? query, String? tag}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/notes',
      queryParameters: {
        'page': page,
        if (query != null && query.isNotEmpty) 'q': query,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    return NotesPage.fromJson(res.data ?? const {});
  }

  /// `POST /api/notes` — create (201 → the saved row).
  Future<NoteRow> create(
    String title, {
    String content = '',
    List<String> tags = const [],
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/notes',
      data: {'title': title, 'content': content, 'tags': tags},
    );
    return NoteRow.fromJson((res.data?['note'] as Map).cast<String, dynamic>());
  }

  /// `GET /api/notes/{id}` — one note.
  Future<NoteRow> get(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/notes/$id');
    return NoteRow.fromJson((res.data?['note'] as Map).cast<String, dynamic>());
  }

  /// `PATCH /api/notes/{id}` — partial update; returns the updated row.
  Future<NoteRow> update(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/notes/$id',
      data: {
        'title': ?title,
        'content': ?content,
        'tags': ?tags,
      },
    );
    return NoteRow.fromJson((res.data?['note'] as Map).cast<String, dynamic>());
  }

  /// `DELETE /api/notes/{id}`.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>('/api/notes/$id');
  }
}

@Riverpod(keepAlive: true)
NotesApi notesApi(Ref ref) => NotesApi(ref.watch(dioProvider));
