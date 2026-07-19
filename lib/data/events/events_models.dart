/// Models for Mantle Events. Mirrors `EventRow` in
/// `packages/content/src/events.ts` (camelCase on the wire).
///
/// The server has NO done/status concept for events (deletion is the only
/// terminal action). This client models "done" as the reserved tag
/// [kEventDoneTag] — persisted via `PATCH tags`, so it syncs across devices
/// and shows on the web as a plain tag. A done event keeps its history but
/// stops scheduling local alarms.
library;

/// The reserved tag that marks an event done on this client.
const String kEventDoneTag = 'done';

/// Simple fixed-frequency recurrence (`none` = one-shot). The server rolls a
/// recurring event's `startsAt` forward to the next occurrence after each
/// reminder fires — a row always carries its NEXT time.
const Set<String> kRecurFreqs = {'none', 'daily', 'weekly', 'monthly', 'yearly'};

class EventRow {
  const EventRow({
    required this.id,
    required this.title,
    required this.body,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.remindMinutesBefore,
    required this.remindAt,
    required this.recur,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;

  /// The event's start — a UTC instant (display in local time).
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;

  /// Reminder lead time in minutes (0 = none). The server's reminders worker
  /// pings at [remindAt] = [startsAt] − this; the app mirrors the same fields
  /// with a LOCAL alarm so the alert fires offline too.
  final int remindMinutesBefore;
  final DateTime? remindAt;

  /// `none|daily|weekly|monthly|yearly`.
  final String recur;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get done => tags.contains(kEventDoneTag);
  bool get recurring => recur != 'none';
  bool get past => startsAt.isBefore(DateTime.now());

  static EventRow fromJson(Map<String, dynamic> j) {
    final ends = j['endsAt'] as String?;
    final remind = j['remindAt'] as String?;
    return EventRow(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? 'Untitled event',
      body: (j['body'] as String?) ?? '',
      startsAt: DateTime.parse(j['startsAt'] as String).toUtc(),
      endsAt: ends == null ? null : DateTime.tryParse(ends)?.toUtc(),
      location: j['location'] as String?,
      remindMinutesBefore: (j['remindMinutesBefore'] as num?)?.toInt() ?? 0,
      remindAt: remind == null ? null : DateTime.tryParse(remind)?.toUtc(),
      recur: (j['recur'] as String?) ?? 'none',
      tags: ((j['tags'] as List?) ?? const []).whereType<String>().toList(),
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}

/// One page of the events list (server page size 50; `upcoming` sorts soonest
/// first).
class EventsPage {
  const EventsPage({required this.events, required this.total});
  final List<EventRow> events;
  final int total;
}
