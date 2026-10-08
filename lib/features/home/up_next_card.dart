import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/format/dates.dart';
import '../../data/events/events_models.dart';
import '../../data/tasks/tasks_models.dart';
import '../../theme/mantle_theme.dart';
import '../dashboard/up_next.dart';
import '../dashboard/up_next_controller.dart';

/// "Up next" on the home screen: the next few events (soonest first) and the
/// tasks due soon (overdue, today, the next few days), each row opening its
/// item, each half with "See all" for the full list. One quiet line when
/// nothing is due.
class UpNextCard extends ConsumerWidget {
  const UpNextCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final async = ref.watch(upNextControllerProvider);

    final Widget body = async.when(
      // A reload (another login) or a refresh keeps the rows it has.
      skipLoadingOnReload: true,
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Loading…', style: theme.textTheme.muted),
      ),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: Text(
              "Couldn't load what's coming up.",
              style: theme.textTheme.muted,
            ),
          ),
          ShadButton.outline(
            onPressed: () => ref.invalidate(upNextControllerProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (upNext) => upNext.isEmpty
          ? const _Empty()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (upNext.events.isNotEmpty)
                  _Section(
                    label: 'Events',
                    allRoute: '/events',
                    allLabel: 'See all events',
                    rows: [
                      for (final e in upNext.events) _EventRow(event: e),
                    ],
                  ),
                if (upNext.events.isNotEmpty && upNext.tasks.isNotEmpty)
                  const SizedBox(height: 8),
                if (upNext.tasks.isNotEmpty)
                  _Section(
                    label: 'Tasks',
                    allRoute: '/tasks',
                    allLabel: 'See all tasks',
                    rows: [
                      for (final t in upNext.tasks) _TaskRow(task: t),
                    ],
                  ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: theme.radius,
          border: Border.all(color: scheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendarClock,
                    size: 15,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text('Up next', style: theme.textTheme.small),
                ],
              ),
            ),
            const SizedBox(height: 4),
            body,
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        'Nothing due in the next few days.',
        style: theme.textTheme.muted,
      ),
    );
  }
}

/// A labelled half of the card: its rows, and "See all" to the full list.
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.allRoute,
    required this.allLabel,
    required this.rows,
  });

  final String label;
  final String allRoute;
  final String allLabel;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final ink = MantleColors.of(context).tokens(theme.brightness).primaryInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.muted)),
            Semantics(
              button: true,
              excludeSemantics: true,
              label: allLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(allRoute),
                // 44 tall: the target grows, the words do not.
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Center(
                      child: Text(
                        'See all',
                        style: theme.textTheme.small.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ...rows,
      ],
    );
  }
}

/// One tappable row: a leading mark, the title, and one line under it.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    required this.subColor,
    required this.semanticLabel,
    required this.route,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  final Color subColor;
  final String semanticLabel;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(route),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.p.copyWith(
                          color: scheme.cardForeground,
                        ),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(color: subColor),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: scheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final EventRow event;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final when = '${formatDay(event.startsAt)} ${formatTime(event.startsAt)}';
    final parts = [
      when,
      if (event.location != null && event.location!.isNotEmpty)
        event.location!,
    ];
    return _Row(
      // A bell when a reminder rings before it.
      icon: event.remindMinutesBefore > 0
          ? LucideIcons.bellRing
          : LucideIcons.calendarClock,
      iconColor: scheme.primary,
      title: event.title,
      sub: parts.join(' · '),
      subColor: scheme.mutedForeground,
      semanticLabel: 'Event: ${event.title}, $when',
      route: '/events/${event.id}',
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final TaskRow task;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final overdue = taskDue(task, now) == TaskDue.overdue;
    final due = formatDue(task.dueAt!, now: now);
    final sub = [
      if (overdue && due == 'Today') 'Due earlier today' else due,
      if (task.priority == 'high') 'high',
    ].join(' · ');
    // Text and marks on the card: the role's ink, not its fill.
    final late = MantleColors.of(context).tokens(theme.brightness).destructiveInk;
    return _Row(
      icon: LucideIcons.circle,
      iconColor: overdue ? late : scheme.primary,
      title: task.title,
      sub: sub,
      subColor: overdue ? late : scheme.mutedForeground,
      semanticLabel: 'Task: ${task.title}, $sub',
      route: '/tasks/${task.id}',
    );
  }
}
