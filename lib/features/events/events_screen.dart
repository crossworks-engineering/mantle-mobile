import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/events/event_alarms.dart';
import '../../data/events/events_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import 'events_controller.dart';

/// Upcoming events, soonest first, grouped by day. Each row shows the time,
/// title, and reminder lead; the circle marks done (persisted as the `done`
/// tag — the server has no event status). The + opens the add sheet. Every
/// change re-syncs REAL device alarms (see EventAlarms) so events ring at
/// their start time even offline.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    // First visit: secure what alarms need (iOS notification permission,
    // Android 12+ exact-alarm grant; inexact fallback when declined).
    Future.microtask(EventAlarms.requestPermissions);
  }

  Future<void> _confirmDelete(EventRow event) async {
    final notifier = ref.read(eventsControllerProvider.notifier);
    final ok = await confirmDestructive(
      context,
      title: 'Delete event?',
      description:
          '"${event.title}" is removed, and its alarm on this phone with it.',
      action: 'Delete',
    );
    if (ok) await notifier.delete(event.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.primaryForeground;
    final async = ref.watch(eventsControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Events', wordmark: false),
            trailing: [
              ShadButton.ghost(
                onPressed: () => showShadSheet<void>(
                  context: context,
                  builder: (_) => const AddEventSheet(),
                ),
                child: Icon(LucideIcons.plus, size: 20, color: fg),
              ),
              ShadButton.ghost(
                onPressed: () =>
                    ref.read(eventsControllerProvider.notifier).refresh(),
                child: Icon(LucideIcons.refreshCw, size: 18, color: fg),
              ),
              ShadButton.ghost(
                onPressed: () => context.pop(),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: fg),
              ),
            ],
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
                      Text("Couldn't load events.",
                          style: theme.textTheme.muted),
                      const SizedBox(height: 12),
                      ShadButton.outline(
                        onPressed: () => ref
                            .read(eventsControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendarClock,
                              size: 32, color: scheme.mutedForeground),
                          const SizedBox(height: 12),
                          Text('Nothing coming up.',
                              style: theme.textTheme.muted),
                        ],
                      ),
                    );
                  }
                  final groups = _groupByDay(events);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Text(group.label,
                              style: theme.textTheme.muted),
                        ),
                        for (final e in group.events)
                          _EventTile(
                            theme: theme,
                            event: e,
                            onToggle: () => ref
                                .read(eventsControllerProvider.notifier)
                                .setDone(e.id, done: !e.done),
                            onLongPress: () => _confirmDelete(e),
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

class _DayGroup {
  const _DayGroup(this.label, this.events);
  final String label;
  final List<EventRow> events;
}


List<_DayGroup> _groupByDay(List<EventRow> events) {
  final groups = <_DayGroup>[];
  for (final e in events) {
    final label = formatDay(e.startsAt);
    if (groups.isEmpty || groups.last.label != label) {
      groups.add(_DayGroup(label, []));
    }
    groups.last.events.add(e);
  }
  return groups;
}

String _timeLabel(DateTime local) =>
    '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.theme,
    required this.event,
    required this.onToggle,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final EventRow event;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final muted = scheme.mutedForeground;
    final local = event.startsAt.toLocal();
    final titleStyle = event.done
        ? theme.textTheme.p.copyWith(
            color: muted,
            decoration: TextDecoration.lineThrough,
            decorationColor: muted,
          )
        : theme.textTheme.p.copyWith(color: scheme.foreground);

    final metaStyle = theme.textTheme.small.copyWith(color: muted);
    // Secondary line: location, reminder lead, recurrence. Icons, not emoji,
    // so the row reads as one typeset line in every theme.
    final meta = <Widget>[
      if (event.location != null && event.location!.isNotEmpty)
        _Meta(icon: LucideIcons.mapPin, text: event.location!, style: metaStyle),
      if (event.remindMinutesBefore > 0)
        _Meta(
          icon: LucideIcons.bellRing,
          text: '${event.remindMinutesBefore} min before',
          style: metaStyle,
        ),
      if (event.recurring)
        _Meta(icon: LucideIcons.repeat, text: event.recur, style: metaStyle),
    ];

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
                  event.done
                      ? LucideIcons.circleCheckBig
                      : LucideIcons.circle,
                  size: 20,
                  color: event.done ? muted : scheme.primary,
                ),
              ),
            ),
            // Fixed time column so titles line up down the list; tabular
            // digits so 08:00 and 11:30 take the same width.
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _timeLabel(local),
                  style: theme.textTheme.small.copyWith(
                    color: event.done ? muted : scheme.foreground,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: titleStyle),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(spacing: 12, runSpacing: 2, children: meta),
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

/// One icon + label pair on an event's secondary line.
class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.style});

  final IconData icon;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: style.color),
        const SizedBox(width: 4),
        Text(text, style: style),
      ],
    );
  }
}

/// Add an event: title, day (calendar), time (HH:MM), optional location and
/// reminder lead. Saves via [EventsController.add], which also arms the alarm.
class AddEventSheet extends ConsumerStatefulWidget {
  const AddEventSheet({super.key});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _title = TextEditingController();
  final _time = TextEditingController(text: '09:00');
  final _location = TextEditingController();
  DateTime _day = DateTime.now();
  int _remind = 0;
  bool _saving = false;
  String? _error;

  static const _remindChoices = [0, 5, 15, 30, 60];

  @override
  void dispose() {
    _title.dispose();
    _time.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime? _startsAt() {
    final parts = _time.text.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return DateTime(_day.year, _day.month, _day.day, h, m);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final startsAt = _startsAt();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a title.');
      return;
    }
    if (startsAt == null) {
      setState(() => _error = 'Time must be HH:MM (24h).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(eventsControllerProvider.notifier).add(
            title: title,
            startsAt: startsAt,
            location: _location.text.trim().isEmpty
                ? null
                : _location.text.trim(),
            remindMinutesBefore: _remind,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't save the event.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final scheme = theme.colorScheme;
    return ShadSheet(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New event', style: theme.textTheme.h4),
            const SizedBox(height: 12),
            ShadInput(
              controller: _title,
              placeholder: const Text('What is it?'),
            ),
            const SizedBox(height: 12),
            Center(
              child: ShadCalendar(
                selected: _day,
                onChanged: (d) => setState(() => _day = d ?? _day),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: ShadInput(
                    controller: _time,
                    placeholder: const Text('HH:MM'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShadInput(
                    controller: _location,
                    placeholder: const Text('Location (optional)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Remind me', style: theme.textTheme.muted),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in _remindChoices)
                  GestureDetector(
                    onTap: () => setState(() => _remind = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _remind == m ? scheme.primary : scheme.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        m == 0 ? 'at start' : '${m}m before',
                        style: theme.textTheme.small.copyWith(
                          color: _remind == m
                              ? scheme.primaryForeground
                              : scheme.foreground,
                        ),
                      ),
                    ),
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
                child: const Text('Add event'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
