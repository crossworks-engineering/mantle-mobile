import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/tasks/tasks_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'tasks_controller.dart';

/// The task list: quick-add on top, open tasks (tap the circle to check off,
/// tap the row to edit title, due date and priority), then done tasks muted
/// below. Server-sorted; check-off and add are optimistic. Backed by
/// `GET/POST/PATCH /api/tasks` via [TasksController].
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _input = TextEditingController();
  // An empty + focuses the field (see notes_screen.dart).
  final _inputFocus = FocusNode();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _input.text.trim();
    if (_adding) return;
    if (title.isEmpty) {
      _inputFocus.requestFocus();
      return;
    }
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

  void _edit(TaskRow task) {
    showShadSheet<void>(
      context: context,
      builder: (_) => EditTaskSheet(task: task),
    );
  }

  Future<void> _confirmDelete(TaskRow task) async {
    final notifier = ref.read(tasksControllerProvider.notifier);
    final ok = await confirmDestructive(
      context,
      title: 'Delete task?',
      description: '"${task.title}" is removed from your brain.',
      action: 'Delete',
    );
    if (ok) await notifier.delete(task.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(tasksControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Tasks', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () =>
                    ref.read(tasksControllerProvider.notifier).refresh(),
              ),
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            // The add button tracks the input's height (guide: a button
            // beside an input is as tall as the input).
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                    Expanded(
                      child: ShadInput(
                        controller: _input,
                        focusNode: _inputFocus,
                        placeholder: const Text('Add a task…'),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton(
                      onPressed: _adding ? null : _add,
                      child: const Icon(LucideIcons.plus, semanticLabel: 'Add task'),
                    ),
                ],
              ),
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
                    // The tail rides above the keyboard, and a drag puts
                    // the keyboard away.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      12, 4, 12, 24 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    children: [
                      for (final t in open)
                        _TaskTile(
                          theme: theme,
                          task: t,
                          onToggle: () => ref
                              .read(tasksControllerProvider.notifier)
                              .setDone(t.id, done: true),
                          onTap: () => _edit(t),
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
                            onTap: () => _edit(t),
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


class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.theme,
    required this.task,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final TaskRow task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
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
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // A 44pt box around the 20pt circle: the target grows, the
            // mark does not.
            Semantics(
              button: true,
              label: task.done ? 'Mark not done' : 'Mark done',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      task.done
                          ? LucideIcons.circleCheckBig
                          : LucideIcons.circle,
                      size: 20,
                      color: task.done ? muted : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
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
                            formatDue(task.dueAt!),
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

/// Edit a task: title, due date (a calendar that unfolds on demand, with a
/// clear), and priority. Body, tags and comments stay on the web; the phone
/// edits what its list shows. Saves via [TasksController.edit].
class EditTaskSheet extends ConsumerStatefulWidget {
  const EditTaskSheet({super.key, required this.task});

  final TaskRow task;

  @override
  ConsumerState<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends ConsumerState<EditTaskSheet> {
  late final _title = TextEditingController(text: widget.task.title);
  late DateTime? _dueAt = widget.task.dueAt?.toLocal();
  late String _priority = widget.task.priority;
  bool _pickingDay = false;
  bool _saving = false;
  String? _error;

  static const _priorities = ['low', 'normal', 'high'];

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final task = widget.task;
    try {
      await ref.read(tasksControllerProvider.notifier).edit(
            task.id,
            title: title == task.title ? null : title,
            priority: _priority == task.priority ? null : _priority,
            dueAt: _dueAt,
            clearDueAt: _dueAt == null && task.dueAt != null,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't save the task.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final due = _dueAt;
    return ShadSheet(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit task', style: theme.textTheme.h4),
            const SizedBox(height: 12),
            ShadInput(
              controller: _title,
              placeholder: const Text('Title'),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text('Due', style: theme.textTheme.muted),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    due == null ? 'No due date' : formatDue(due),
                    style: theme.textTheme.p,
                  ),
                ),
                ShadButton.outline(
                  onPressed: () => setState(() => _pickingDay = !_pickingDay),
                  child: Text(_pickingDay ? 'Done' : 'Pick a day'),
                ),
                if (due != null) ...[
                  const SizedBox(width: 8),
                  ShadButton.ghost(
                    onPressed: () => setState(() {
                      _dueAt = null;
                      _pickingDay = false;
                    }),
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
            if (_pickingDay) ...[
              const SizedBox(height: 8),
              Center(
                child: ShadCalendar(
                  selected: due,
                  onChanged: (d) => setState(() {
                    // Midnight local: a day, not an instant.
                    if (d != null) _dueAt = DateTime(d.year, d.month, d.day);
                  }),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Priority', style: theme.textTheme.muted),
            const SizedBox(height: 2),
            Wrap(
              spacing: 6,
              children: [
                for (final p in _priorities)
                  ChoicePill(
                    label: p,
                    selected: _priority == p,
                    semanticLabel: '$p priority',
                    onTap: () => setState(() => _priority = p),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style:
                    theme.textTheme.small.copyWith(color: scheme.destructive),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
