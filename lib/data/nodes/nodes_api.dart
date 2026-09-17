import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'nodes_api.g.dart';

/// The type-blind node resolver behind the `/n/<id>` permalink and node
/// mentions: `GET /api/nodes/{id}` answers `{ node: { id, type, title… } }`
/// so a link that only carries an id can be routed to the right screen.
class NodeRef {
  const NodeRef({required this.id, required this.type, required this.title});

  final String id;
  final String type;
  final String? title;

  static NodeRef fromJson(Map<String, dynamic> j) => NodeRef(
        id: j['id'] as String,
        type: (j['type'] as String?) ?? '',
        title: j['title'] as String?,
      );
}

class NodesApi {
  NodesApi(this._dio);

  final Dio _dio;

  /// `GET /api/nodes/{id}`. Throws on 404 (an id from another brain, or a
  /// deleted node); callers fall back to opening the web permalink.
  Future<NodeRef> resolve(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/nodes/$id');
    return NodeRef.fromJson((res.data?['node'] as Map).cast<String, dynamic>());
  }
}

@Riverpod(keepAlive: true)
NodesApi nodesApi(Ref ref) => NodesApi(ref.watch(dioProvider));

/// `GET /api/draws/{id}/svg` — a drawing's committed SVG snapshot, as the
/// JSON form (`{ svg }`) so the bearer rides the request. Null when the
/// drawing has no snapshot or cannot be fetched; the renderer shows a chip.
/// Kept alive so a page rebuild does not re-fetch every embedded drawing.
@Riverpod(keepAlive: true)
Future<String?> drawSvg(Ref ref, String drawId) async {
  try {
    final res = await ref
        .watch(dioProvider)
        .get<Map<String, dynamic>>('/api/draws/$drawId/svg');
    final svg = res.data?['svg'];
    return svg is String && svg.isNotEmpty ? svg : null;
  } catch (_) {
    return null;
  }
}
