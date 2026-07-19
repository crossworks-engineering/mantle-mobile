import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'journal_models.dart';

part 'journal_api.g.dart';

/// The Mantle Journal over HTTP: `GET/POST /api/journal`. Entries are plain
/// text; the server derives a title from the body when none is given.
class JournalApi {
  JournalApi(this._dio);

  final Dio _dio;

  /// `GET /api/journal?page=…` — one page (50), newest first (by entryDate
  /// when set, else recency).
  Future<JournalPage> list({int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/journal',
      queryParameters: {'page': page},
    );
    final data = res.data ?? const {};
    final rows = ((data['journals'] as List?) ?? const [])
        .map((e) => JournalRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return JournalPage(
      journals: rows,
      total: (data['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `POST /api/journal` — capture an entry (201 → the saved row, title
  /// auto-derived server-side when blank).
  Future<JournalRow> create(String body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/journal',
      data: {'body': body},
    );
    return JournalRow.fromJson(
      (res.data?['journal'] as Map).cast<String, dynamic>(),
    );
  }
}

@Riverpod(keepAlive: true)
JournalApi journalApi(Ref ref) => JournalApi(ref.watch(dioProvider));
