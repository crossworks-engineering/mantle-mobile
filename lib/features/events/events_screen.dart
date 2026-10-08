import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../data/events/event_alarms.dart';
import '../../data/events/events_api.dart';
import '../../data/events/events_models.dart';
import '../../core/format/dates.dart';
import '../../widgets/choice_pill.dart';
import '../../widgets/mantle_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/voice_text_field.dart';
import '../settings/settings_repository.dart';
import 'events_controller.dart';

/// Upcoming events, soonest first, grouped by day. Each row shows the time,
/// title, and reminder lead; the circle marks done (persisted as the `done`
/// tag — the server has no event status). The + opens the add sheet; a tap
/// on a row opens the same sheet to edit it. Every change re-syncs REAL
/// device alarms (see EventAlarms) so events ring at their start time even
/// offline.
///
/// With [focusId] (`/events/<id>`: an "Up next" row, a reminder tap) it opens
/// that event's sheet over the list; an event that is gone, or not this
/// login's, leaves the list with a short message instead.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key, this.focusId});

  final String? focusId;

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      // The permission step first (its sheet would cover the event's), but
      // a failure there must not keep the named event shut.
      try {
        await _secureAlarms();
      } catch (_) {
        /* alarms are best-effort; the event still opens */
      }
      await _openFocused();
    });
  }

  /// Open the event the route names, read from the brain (it may not be in
  /// the list: a past one, or beyond the first page).
  Future<void> _openFocused() async {
    final id = widget.focusId;
    if (id == null) return;
    EventRow row;
    try {
      row = await ref.read(eventsApiProvider).get(id);
    } catch (e) {
      if (!mounted) return;
      ShadToaster.maybeOf(context)?.show(
        ShadToast(description: Text(itemMissingMessage(e, 'event'))),
      );
      return;
    }
    if (!mounted) return;
    await showShadSheet<void>(
      context: context,
      builder: (_) => EventSheet(existing: row),
    );
  }

  /// Secure what alarms need (iOS notification permission, Android 12+
  /// exact-alarm grant; inexact fallback when declined). The first time, a
  /// one-screen rationale comes before the OS prompt, because a cold
  /// permission dialog on a list of events explains nothing; "Not now" is
  /// remembered, and the phone's Settings remain the way back in.
  Future<void> _secureAlarms() async {
    final settings = ref.read(settingsRepositoryProvider);
    if (await settings.alarmRationaleShown()) {
      await EventAlarms.requestPermissions();
      return;
    }
    if (!mounted) return;
    final go = await showShadSheet<bool>(
      context: context,
      builder: (_) => const _AlarmRationaleSheet(),
    );
    await settings.setAlarmRationaleShown();
    if (go == true) await EventAlarms.requestPermissions();
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
    final async = ref.watch(eventsControllerProvider);

    return Container(
      color: scheme.background,
      child: Column(
        children: [
          MantleHeader(
            leading: const MantleHeaderTitle('Events', wordmark: false),
            trailing: [
              HeaderAction(
                icon: LucideIcons.plus,
                label: 'Add event',
                onPressed: () => showShadSheet<void>(
                  context: context,
                  builder: (_) => const EventSheet(),
                ),
              ),
              HeaderAction(
                icon: LucideIcons.refreshCw,
                label: 'Refresh',
                size: 18,
                onPressed: () =>
                    ref.read(eventsControllerProvider.notifier).refresh(),
              ),
              HeaderAction(
                icon: LucideIcons.arrowLeft,
                label: 'Back',
                onPressed: () => context.pop(),
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
                            onTap: () => showShadSheet<void>(
                              context: context,
                              builder: (_) => EventSheet(existing: e),
                            ),
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
    required this.onTap,
    required this.onLongPress,
  });

  final ShadThemeData theme;
  final EventRow event;
  final VoidCallback onToggle;
  final VoidCallback onTap;
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
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              button: true,
              label: event.done ? 'Mark not done' : 'Mark done',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Icon(
                      event.done
                          ? LucideIcons.circleCheckBig
                          : LucideIcons.circle,
                      size: 20,
                      color: event.done ? muted : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
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

/// Add or edit an event: title, day (calendar), time (a real picker), an
/// optional location and the reminder lead. With [existing] it edits that
/// event through [EventsController.edit]; without, it creates through
/// [EventsController.add]. Both re-arm the local alarm.
class EventSheet extends ConsumerStatefulWidget {
  const EventSheet({super.key, this.existing});

  final EventRow? existing;

  @override
  ConsumerState<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<EventSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _location =
      TextEditingController(text: widget.existing?.location);
  late DateTime _day = widget.existing?.startsAt.toLocal() ?? DateTime.now();
  late ShadTimeOfDay _time = widget.existing == null
      ? const ShadTimeOfDay(hour: 9, minute: 0, second: 0)
      : ShadTimeOfDay.fromDateTime(widget.existing!.startsAt.toLocal());
  late int _remind = widget.existing?.remindMinutesBefore ?? 0;
  bool _saving = false;
  String? _error;

  static const _remindChoices = [0, 5, 15, 30, 60];

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the event a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final location = _location.text.trim();
    final notifier = ref.read(eventsControllerProvider.notifier);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await notifier.add(
          title: title,
          startsAt: _startsAt,
          location: location.isEmpty ? null : location,
          remindMinutesBefore: _remind,
        );
      } else {
        final startsAt = _startsAt;
        await notifier.edit(
          existing.id,
          title: title == existing.title ? null : title,
          startsAt: startsAt.toUtc() == existing.startsAt ? null : startsAt,
          location: location.isEmpty || location == existing.location
              ? null
              : location,
          clearLocation:
              location.isEmpty && (existing.location ?? '').isNotEmpty,
          remindMinutesBefore:
              _remind == existing.remindMinutesBefore ? null : _remind,
        );
      }
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
            Text(_editing ? 'Edit event' : 'New event',
                style: theme.textTheme.h4),
            const SizedBox(height: 12),
            VoiceTextField(
              controller: _title,
              placeholder: const Text('What is it?'),
              onError: (m) => setState(() => _error = m),
            ),
            const SizedBox(height: 12),
            Center(
              child: ShadCalendar(
                selected: _day,
                onChanged: (d) => setState(() => _day = d ?? _day),
              ),
            ),
            const SizedBox(height: 12),
            Text('Time', style: theme.textTheme.muted),
            const SizedBox(height: 6),
            // Hours and minutes, 24h, each its own field: no more HH:MM
            // typed into a text box and parsed.
            ShadTimePicker(
              initialValue: _time,
              showSeconds: false,
              onChanged: (t) => _time = t,
            ),
            const SizedBox(height: 12),
            ShadInput(
              controller: _location,
              placeholder: const Text('Location (optional)'),
            ),
            const SizedBox(height: 12),
            Text('Remind me', style: theme.textTheme.muted),
            Wrap(
              spacing: 6,
              children: [
                for (final m in _remindChoices)
                  ChoicePill(
                    label: m == 0 ? 'at start' : '${m}m before',
                    semanticLabel: m == 0 ? 'At start' : '$m minutes before',
                    selected: _remind == m,
                    onTap: () => setState(() => _remind = m),
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
                child: Text(
                  _saving
                      ? 'Saving…'
                      : _editing
                          ? 'Save'
                          : 'Add event',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// The one screen before the OS asks: what alarms do, and that the phone
/// will ask for permission next. Pops `true` to go on, `false` for not now.
class _AlarmRationaleSheet extends StatelessWidget {
  const _AlarmRationaleSheet();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadSheet(
      title: const Text('Ring for your events?'),
      description: const Text(
        'Jackdaw can sound an alarm on this phone when an event starts, '
        'even with no signal. If your phone asks, allow notifications. You '
        "can change this any time in the phone's Settings.",
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            const SizedBox(height: 8),
            Text(
              'Reminders from your assistant still arrive as messages either way.',
              style: theme.textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The short line shown when an item a route names cannot be opened: gone
/// (or another login's) versus not reachable right now.
String itemMissingMessage(Object error, String kind) {
  final status = error is DioException ? error.response?.statusCode : null;
  if (status == 404 || status == 403 || status == 400) {
    return "That $kind is gone, or this login can't open it.";
  }
  return "Couldn't open that $kind. Check your connection.";
}
