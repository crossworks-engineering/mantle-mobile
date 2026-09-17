/// One vocabulary for every date the app shows. Three shapes, one style:
///
/// - [formatWhen] — a past instant, compact: `now`, `5m`, `3h`, `2d`,
///   `18 Sep`, `18 Sep 2025`. Inbox rows, note and search results, approvals.
/// - [formatDay] — a calendar day: `Today`, `Tomorrow`, `Yesterday`,
///   `Fri 18 Sep`, `Fri 18 Sep 2027`. Journal entries, event day headers.
/// - [formatDue] — a deadline relative to today: `Today`, `Tomorrow`,
///   `In 3 days`, `Yesterday`, `3 days overdue`, else [formatDay]. Task rows.
/// - [formatTime] — a clock time: `09:05`, `14:32`. Chat bubbles.
///
/// All work in the device's local time; the relative ones take `now` for tests.
library;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

String _dayMonth(DateTime t) => '${t.day} ${_months[t.month - 1]}';

/// A past instant, compact. Never more than a few characters until it is a
/// week old, then the date.
String formatWhen(DateTime at, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final t = at.toLocal();
  final diff = n.difference(t);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final md = _dayMonth(t);
  return t.year == n.year ? md : '$md ${t.year}';
}

/// A calendar day, named when it is near, dated when it is not.
String formatDay(DateTime at, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final t = at.toLocal();
  final diff = _dayOf(t).difference(_dayOf(n)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  final wd = _weekdays[t.weekday - 1];
  final md = _dayMonth(t);
  return t.year == n.year ? '$wd $md' : '$wd $md ${t.year}';
}

/// A deadline relative to today. Within a week either way it counts days;
/// beyond that it is the day itself.
String formatDue(DateTime due, {DateTime? now}) {
  final n = (now ?? DateTime.now()).toLocal();
  final t = due.toLocal();
  final diff = _dayOf(t).difference(_dayOf(n)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff < 0 && diff > -7) return '${-diff} days overdue';
  if (diff > 0 && diff < 7) return 'In $diff days';
  return formatDay(t, now: n);
}

/// A clock time in the device's local zone, 24-hour: `09:05`, `14:32`. Under
/// a chat bubble, next to a day name for a full stamp.
String formatTime(DateTime at) {
  final t = at.toLocal();
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
