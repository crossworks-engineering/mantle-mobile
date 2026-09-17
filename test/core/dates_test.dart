import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/format/dates.dart';

void main() {
  final now = DateTime(2026, 9, 16, 15, 0); // Wed 16 Sep 2026, 15:00 local

  group('formatWhen', () {
    test('counts up through minutes, hours and days', () {
      expect(formatWhen(now.subtract(const Duration(seconds: 20)), now: now), 'now');
      expect(formatWhen(now.subtract(const Duration(minutes: 5)), now: now), '5m');
      expect(formatWhen(now.subtract(const Duration(hours: 3)), now: now), '3h');
      expect(formatWhen(now.subtract(const Duration(days: 2)), now: now), '2d');
    });
    test('becomes a date after a week, with the year only when it differs', () {
      expect(formatWhen(DateTime(2026, 8, 30), now: now), '30 Aug');
      expect(formatWhen(DateTime(2025, 12, 24), now: now), '24 Dec 2025');
    });
  });

  group('formatDay', () {
    test('names the near days', () {
      expect(formatDay(now, now: now), 'Today');
      expect(formatDay(now.add(const Duration(days: 1)), now: now), 'Tomorrow');
      expect(formatDay(now.subtract(const Duration(days: 1)), now: now), 'Yesterday');
    });
    test('dates the rest, weekday first', () {
      expect(formatDay(DateTime(2026, 9, 18), now: now), 'Fri 18 Sep');
      expect(formatDay(DateTime(2027, 1, 1), now: now), 'Fri 1 Jan 2027');
    });
    test('compares calendar days, not 24-hour spans', () {
      // 23:30 yesterday is "Yesterday" even though it is under 24h ago.
      expect(formatDay(DateTime(2026, 9, 15, 23, 30), now: now), 'Yesterday');
    });
  });

  group('formatTime', () {
    test('is a zero-padded 24-hour clock', () {
      expect(formatTime(DateTime(2026, 9, 16, 9, 5)), '09:05');
      expect(formatTime(DateTime(2026, 9, 16, 14, 32)), '14:32');
      expect(formatTime(DateTime(2026, 9, 16, 0, 0)), '00:00');
    });
  });

  group('formatDue', () {
    test('counts days either side of today within a week', () {
      expect(formatDue(now, now: now), 'Today');
      expect(formatDue(now.add(const Duration(days: 3)), now: now), 'In 3 days');
      expect(formatDue(now.subtract(const Duration(days: 3)), now: now), '3 days overdue');
      expect(formatDue(now.subtract(const Duration(days: 1)), now: now), 'Yesterday');
    });
    test('falls back to the day beyond a week', () {
      expect(formatDue(DateTime(2026, 10, 2), now: now), 'Fri 2 Oct');
      expect(formatDue(DateTime(2026, 9, 1), now: now), 'Tue 1 Sep');
    });
  });
}
