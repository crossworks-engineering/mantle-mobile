/// Models for Mantle Tasks. Mirrors `TaskRow` in
/// `packages/content/src/tasks.ts`.
library;

/// One task. Status is `open|done`; priority `low|normal|high`.
class TaskRow {
  const TaskRow({
    required this.id,
    required this.title,
    required this.body,
    required this.done,
    required this.priority,
    required this.dueAt,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final bool done;
  final String priority;
  final DateTime? dueAt;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get overdue =>
      !done && dueAt != null && dueAt!.isBefore(DateTime.now());

  /// [clearDueAt] drops the due date; a null [dueAt] alone keeps it.
  TaskRow copyWith({
    bool? done,
    String? title,
    String? priority,
    DateTime? dueAt,
    bool clearDueAt = false,
  }) {
    return TaskRow(
      id: id,
      title: title ?? this.title,
      body: body,
      done: done ?? this.done,
      priority: priority ?? this.priority,
      dueAt: clearDueAt ? null : (dueAt ?? this.dueAt),
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static TaskRow fromJson(Map<String, dynamic> j) {
    final due = j['dueAt'] as String?;
    return TaskRow(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      body: (j['body'] as String?) ?? '',
      done: j['status'] == 'done',
      priority: (j['priority'] as String?) ?? 'normal',
      dueAt: due == null ? null : DateTime.tryParse(due),
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}

/// One page of the task list (server page size 50; open sorts before done,
/// then due date asc, then recency).
class TasksPage {
  const TasksPage({required this.tasks, required this.total});
  final List<TaskRow> tasks;
  final int total;
}
