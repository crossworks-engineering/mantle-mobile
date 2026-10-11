import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';

part 'workspaces_api.g.dart';

/// A workspace's one assistant, as `GET /api/workspaces` names it.
class WorkspaceAssistant {
  const WorkspaceAssistant({required this.id, required this.name});
  final String id;
  final String name;
}

/// One row of `GET /api/workspaces`, the parts the phone reads.
class WorkspaceRow {
  const WorkspaceRow({
    required this.id,
    required this.name,
    this.isAdmin = false,
    this.assistant,
  });

  final String id;
  final String name;
  final bool isAdmin;
  final WorkspaceAssistant? assistant;

  static WorkspaceRow? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final name = raw['name'];
    WorkspaceAssistant? assistant;
    final a = raw['assistant'];
    if (a is Map && a['id'] is String && (a['id'] as String).isNotEmpty) {
      final aName = a['name'];
      assistant = WorkspaceAssistant(
        id: a['id'] as String,
        name: aName is String && aName.isNotEmpty ? aName : 'Assistant',
      );
    }
    return WorkspaceRow(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      isAdmin: raw['isAdmin'] == true,
      assistant: assistant,
    );
  }
}

/// Reads `GET /api/workspaces`: for any login the live workspaces it is a
/// user of (an Admin user gets every workspace). The phone needs one thing
/// from it that whoami does not carry: each workspace's assistant, so the
/// chat can talk to the assistant of the workspace in use.
class WorkspacesApi {
  WorkspacesApi(this._dio);

  final Dio _dio;

  Future<List<WorkspaceRow>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/workspaces');
    final rows = (res.data?['workspaces'] as List?) ?? const [];
    return [
      for (final row in rows) ?WorkspaceRow.tryParse(row),
    ];
  }
}

@Riverpod(keepAlive: true)
WorkspacesApi workspacesApi(Ref ref) => WorkspacesApi(ref.watch(dioProvider));
