// Where the chat's day dividers and time stamps fall, over the oldest-first
// message list the screen renders in reverse.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/chat/chat_message.dart';
import 'package:jackdaw/features/chat/chat_timeline.dart';

ChatMessage _at(DateTime t, [String id = '']) => ChatMessage(
  id: id.isEmpty ? t.toIso8601String() : id,
  direction: MessageDirection.outbound,
  text: 'x',
  createdAt: t,
);

void main() {
  final day1 = DateTime(2026, 9, 15, 22, 0);
  final day2 = DateTime(2026, 9, 16, 9, 0);

  group('startsDay', () {
    test('the oldest loaded message always starts a day', () {
      final list = [_at(day1), _at(day1.add(const Duration(minutes: 1)))];
      expect(startsDay(list, 0), isTrue);
      expect(startsDay(list, 1), isFalse);
    });

    test('a divider falls where the calendar day changes', () {
      final list = [
        _at(day1),
        _at(day1.add(const Duration(hours: 1))), // 23:00, same day
        _at(day1.add(const Duration(hours: 3))), // 01:00 next day
        _at(day2),
      ];
      expect(
        [for (var i = 0; i < list.length; i++) startsDay(list, i)],
        [true, false, true, false],
      );
    });

    test('compares calendar days, not 24-hour spans', () {
      final list = [
        _at(DateTime(2026, 9, 15, 23, 59)),
        _at(DateTime(2026, 9, 16, 0, 1)),
      ];
      expect(startsDay(list, 1), isTrue);
    });
  });

  group('showsTime', () {
    test('a burst carries one stamp at its head', () {
      final list = [
        _at(day2),
        _at(day2.add(const Duration(seconds: 30))),
        _at(day2.add(const Duration(minutes: 2))),
      ];
      expect(
        [for (var i = 0; i < list.length; i++) showsTime(list, i)],
        [true, false, false],
      );
    });

    test('a gap longer than the threshold gets a stamp', () {
      final list = [
        _at(day2),
        _at(day2.add(const Duration(minutes: 4))),
        _at(day2.add(const Duration(minutes: 10))),
      ];
      expect(showsTime(list, 1), isFalse);
      expect(showsTime(list, 2), isTrue);
      expect(showsTime(list, 2, gap: const Duration(minutes: 10)), isFalse);
    });

    test('the first message of a day is stamped even inside a short gap', () {
      final list = [
        _at(DateTime(2026, 9, 15, 23, 59)),
        _at(DateTime(2026, 9, 16, 0, 1)),
      ];
      expect(showsTime(list, 1), isTrue);
    });
  });
}
