import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'pages_models.dart';

part 'pages_api.g.dart';

/// Read-only client for Mantle Pages: the index (`GET /api/pages`), a page's
/// metadata (`GET /api/pages/{id}`), its content exported as markdown
/// (`GET /api/export/{id}?format=md` — the HTTP twin of the MCP `export_node`
/// tool, so no ProseMirror renderer is needed client-side), and backlinks.
class PagesApi {
  PagesApi(this._dio);

  final Dio _dio;

  /// `GET /api/pages` — the whole hierarchy as FLAT rows (`mode:'tree'`, up to
  /// 2000) when no filter is set, or a flat filtered list (`mode:'list'`)
  /// when [q] or [tag] is present. The client builds the tree from parentId.
  Future<PagesIndex> list({String? q, String? tag}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/pages',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
      },
    );
    final data = res.data ?? const {};
    final rows = ((data['pages'] as List?) ?? const [])
        .map((e) => PageRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return PagesIndex(
      isTree: data['mode'] == 'tree',
      pages: rows,
      total: (data['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `GET /api/pages/{id}` — the row metadata. The response also carries the
  /// ProseMirror `doc`, which this client ignores (content comes from
  /// [markdown]). Throws (404) when the page doesn't exist.
  Future<PageRow> meta(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/pages/$id');
    return PageRow.fromJson(
      (res.data?['page'] as Map).cast<String, dynamic>(),
    );
  }

  /// `GET /api/export/{id}?format=md` — the page content as markdown bytes
  /// (`text/markdown`). Rendered with the same MantleMarkdown the chat uses.
  Future<String> markdown(String id) async {
    final res = await _dio.get<String>(
      '/api/export/$id',
      queryParameters: {'format': 'md'},
      options: Options(responseType: ResponseType.plain),
    );
    return res.data ?? '';
  }

  /// `GET /api/pages/{id}/backlinks` — inbound references, newest first.
  Future<List<Backlink>> backlinks(String id) async {
    final res =
        await _dio.get<Map<String, dynamic>>('/api/pages/$id/backlinks');
    final rows = (res.data?['backlinks'] as List?) ?? const [];
    return rows
        .map((e) => Backlink.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

@Riverpod(keepAlive: true)
PagesApi pagesApi(Ref ref) => PagesApi(ref.watch(dioProvider));
