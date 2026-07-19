import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'search_models.dart';

part 'search_api.g.dart';

/// Mantle search over HTTP: `GET /api/search` (v0.148.0+) — hybrid
/// FTS + vector node search. `mode=chunks` (passage-level) exists too but the
/// app consumes node hits for now.
class SearchApi {
  SearchApi(this._dio);

  final Dio _dio;

  /// `GET /api/search?q=…&type=…&limit=…` — relevance-ranked node hits.
  Future<List<SearchResult>> search(
    String query, {
    String? type,
    int limit = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/search',
      queryParameters: {
        'q': query,
        'type': ?type,
        'limit': limit,
      },
    );
    return ((res.data?['results'] as List?) ?? const [])
        .map((e) => SearchResult.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

@Riverpod(keepAlive: true)
SearchApi searchApi(Ref ref) => SearchApi(ref.watch(dioProvider));
