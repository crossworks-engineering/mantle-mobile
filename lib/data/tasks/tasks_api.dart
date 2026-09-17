import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/network/dio_provider.dart';
import 'tasks_models.dart';

part 'tasks_api.g.dart';

/// Mantle Tasks over HTTP: `GET/POST /api/tasks`, `PATCH/DELETE
/// /api/tasks/{id}`. Server sorts open before done, then due date asc (nulls
/// last), then recency — the list renders in server order.
class TasksApi {
  TasksApi(this._dio);

  final Dio _dio;

  /// `GET /api/tasks?status=…&page=…` — one page (50 rows) plus the total.
  Future<TasksPage> list({String status = 'all', int page = 1}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/api/tasks',
      queryParameters: {'status': status, 'page': page},
    );
    final data = res.data ?? const {};
    final rows = ((data['tasks'] as List?) ?? const [])
        .map((e) => TaskRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return TasksPage(
      tasks: rows,
      total: (data['total'] as num?)?.toInt() ?? rows.length,
    );
  }

  /// `POST /api/tasks` — create an open task (201 → the saved row).
  Future<TaskRow> create(String title, {DateTime? dueAt}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/tasks',
      data: {
        'title': title,
        if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
      },
    );
    return TaskRow.fromJson((res.data?['task'] as Map).cast<String, dynamic>());
  }

  /// `PATCH /api/tasks/{id}` — edit the fields the phone shows. Only the
  /// arguments given are sent; `clearDueAt` sends `dueAt: null`, which the
  /// server reads as "no due date". Returns the updated row.
  Future<TaskRow> update(
    String id, {
    String? title,
    String? priority,
    DateTime? dueAt,
    bool clearDueAt = false,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/tasks/$id',
      data: {
        'title': ?title,
        'priority': ?priority,
        if (clearDueAt)
          'dueAt': null
        else if (dueAt != null)
          'dueAt': dueAt.toUtc().toIso8601String(),
      },
    );
    return TaskRow.fromJson((res.data?['task'] as Map).cast<String, dynamic>());
  }

  /// `PATCH /api/tasks/{id}` — flip open/done. Returns the updated row.
  Future<TaskRow> setDone(String id, {required bool done}) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/tasks/$id',
      data: {'status': done ? 'done' : 'open'},
    );
    return TaskRow.fromJson((res.data?['task'] as Map).cast<String, dynamic>());
  }

  /// `DELETE /api/tasks/{id}` — remove the task.
  Future<void> delete(String id) async {
    await _dio.delete<Map<String, dynamic>>('/api/tasks/$id');
  }
}

@Riverpod(keepAlive: true)
TasksApi tasksApi(Ref ref) => TasksApi(ref.watch(dioProvider));
