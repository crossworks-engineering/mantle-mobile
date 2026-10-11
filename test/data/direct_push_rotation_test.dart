// The Android direct connection runs in its own isolate, outside the app's
// refresh gate: the app marks a rotation, and the service neither connects
// nor fetches with the bearer while one runs, reading it again if one began
// as it read.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/direct_push_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 12, 9);

  group('rotationPending', () {
    test('holds only the login being rotated, only while fresh', () {
      final marker = rotationMarker('s1', now);
      expect(rotationPending(marker, 's1', now), isTrue);
      expect(
        rotationPending(marker, 's1', now.add(const Duration(seconds: 30))),
        isTrue,
      );
      expect(rotationPending(marker, 's2', now), isFalse);
      expect(rotationPending(marker, 's1', now.add(kRotationPauseMax)),
          isFalse);
      expect(rotationPending(null, 's1', now), isFalse);
      expect(rotationPending('', 's1', now), isFalse);
      expect(rotationPending('garbage', 's1', now), isFalse);
    });
  });

  group('readTokenWhenSettled', () {
    test('does not read (so does not reconnect) while a rotation runs, then '
        'reads the new token', () async {
      var rotating = true;
      var stored = 'tok-old';
      final reads = <String>[];
      final pending = readTokenWhenSettled(
        rotating: () async => rotating,
        read: () async {
          reads.add(stored);
          return stored;
        },
        poll: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(reads, isEmpty);
      stored = 'tok-new';
      rotating = false;
      expect(await pending, 'tok-new');
      expect(reads, ['tok-new']);
    });

    test('a rotation that began during the read means a second read',
        () async {
      var rotating = false;
      var stored = 'tok-old';
      var calls = 0;
      final token = await readTokenWhenSettled(
        rotating: () async {
          // Clear before the first read, marked right after it, then over.
          calls++;
          if (calls == 2) {
            rotating = true;
          } else if (calls == 3) {
            stored = 'tok-new';
            rotating = false;
          }
          return rotating;
        },
        read: () async => stored,
        poll: const Duration(milliseconds: 1),
      );
      expect(token, 'tok-new');
    });
  });
}
