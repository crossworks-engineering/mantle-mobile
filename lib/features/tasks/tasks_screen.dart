import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/tasks/tasks_models.dart';
import '../../widgets/mantle_header.dart';
import 'tasks_controller.dart';

/// The task list: quick-add on top, open tasks (tap the circle to check off),
/// then done tasks muted below. Server-sorted; check-off and add are
/// optimistic. Backed by `GET/POST/PATCH /api/tasks` via [TasksController].
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _input = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (title.isEmpty || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(tasksControllerProvider.notifier).add(title);
      _input.clear();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't add the task.");
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _confirmDelete(TaskRow task) async {
    final notifier = ref.read(tasksControllerProvider.notifier);
    final choice = await showShadSheet<String>(
      context: context,
      builder: (ctx) => ShadSheet(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ShadButton.ghost(
                  onPressed: () => Navigator.of(ctx).pop('delete'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(LucideIcons.trash2,
                          size: 18, color: ShadTheme.of(ctx).colorScheme.destructive),
                      const SizedBox(width: 12),
                      Text(
                        'Delete task',
                        style: TextStyle(
                            color: ShadTheme.of(ctx).colorScheme.destructive),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == 'delete') await notifier.delete(task.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(tasksControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Tasks', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () =>
                    ref.read(tasksControllerProvider.notifier).refresh(),
                child: Icon(LucideIcons.refreshCw, size: 18, color: fg),
              ),
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _input,
                    placeholder: const Text('Add a task…'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: _adding ? null : _add,
                  child: const Icon(LucideIcons.plus),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _error!,
                  style: theme.textTheme.small
                      .copyWith(color: scheme.destructive),
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              top: false,
              child: async.when(
                loading: () => Center(
                  child: Text('Loading…', style: theme.textTheme.muted),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Couldn't load tasks.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(tasksControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (tasks) {
                  final open = [
                    for (final t in tasks)
                      if (!t.done) t,
                  ];
                  final done = [
                    for (final t in tasks)
                      if (t.done) t,
                  ];
                  if (tasks.isEmpty) {
                    return Center(
                      child: Text('No tasks. Add one above.',
                          style: theme.textTheme.muted),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final t in open)
                        _TaskTile(
                          theme: theme,
                          task: t,
                          onToggle: () => ref
                              .read(tasksControllerProvider.notifier)
                              .setDone(t.id, done: true),
                          onLongPress: () => _confirmDelete(t),
                        ),
                      if (done.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                          child: Text(
                            'Done',
                            style: theme.textTheme.muted,
                          ),
                        ),
                        for (final t in done)
                          _TaskTile(
                            theme: theme,
                            task: t,
                            onToggle: () => ref
                                .read(tasksControllerProvider.notifier)
                                .setDone(t.id, done: false),
                            onLongPress: () => _confirmDelete(t),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dueLabel(DateTime due) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(due.year, due.month, due.day);
  final diff = day.difference(today).inDays;
  if (diff < -1) return '${-diff}d overdue';
  if (diff == -1) return 'yesterday';
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff < 7) return 'in ${diff}d';
  return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.theme,
    required this.task,
    required this.onToggle,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final TaskRow task;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    final titleStyle = task.done
        ? theme.textTheme.p.copyWith(
            color: muted,
            decoration: TextDecoration.lineThrough,
            decorationColor: muted,
          )
        : theme.textTheme.p.copyWith(color: scheme.foreground);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
                child: Icon(
                  task.done ? LucideIcons.circleCheckBig : LucideIcons.circle,
                  size: 20,
                  color: task.done ? muted : scheme.primary,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: titleStyle),
                  if (task.dueAt != null || task.priority == 'high') ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (task.priority == 'high' && !task.done)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'high',
                              style: theme.textTheme.small
                                  .copyWith(color: scheme.destructive),
                            ),
                          ),
                        if (task.dueAt != null)
                          Text(
                            _dueLabel(task.dueAt!),
                            style: theme.textTheme.small.copyWith(
                              color: task.overdue ? scheme.destructive : muted,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
