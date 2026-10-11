// The Android direct connection runs in its own isolate, outside the app's
// refresh gate: the app marks a rotation, and the service neither connects
// nor fetches with the bearer while one runs, reading it again if one began
// as it read. The service marks each send too, and a rotation waits for it:
// whichever side looks second sees the other.

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
  group('the send handshake', () {
    // The store both sides share, as the foreground task's data store is.
    late String? rotating;
    late String? sending;
    late String stored;
    late List<String> events;

    setUp(() {
      rotating = null;
      sending = null;
      stored = 'tok-old';
      events = [];
    });

    Future<bool> rotationNow() async =>
        rotationPending(rotating, 's1', DateTime.now());
    Future<bool> sendNow() async =>
        rotationPending(sending, 's1', DateTime.now());

    Future<String?> send() => beginSend(
          rotating: rotationNow,
          mark: () async {
            events.add('mark');
            sending = rotationMarker('s1', DateTime.now());
          },
          unmark: () async {
            events.add('unmark');
            sending = null;
          },
          read: () async {
            events.add('read $stored');
            return stored;
          },
          poll: const Duration(milliseconds: 2),
        );

    test('the send is marked before its bearer is read', () async {
      expect(await send(), 'tok-old');
      expect(events, ['mark', 'read tok-old']);
      expect(await sendNow(), isTrue, reason: 'cleared by the caller');
    });

    test('a rotation marked between the wait and the mark: the send stands '
        'down, waits it out, and goes with the new token', () async {
      var looks = 0;
      final token = await beginSend(
        rotating: () async {
          // Clear at the first look; marked by the app before the second.
          if (++looks == 2) {
            rotating = rotationMarker('s1', DateTime.now());
            Future<void>.delayed(const Duration(milliseconds: 10), () {
              stored = 'tok-new';
              rotating = null;
            });
          }
          return rotationNow();
        },
        mark: () async {
          events.add('mark');
          sending = rotationMarker('s1', DateTime.now());
        },
        unmark: () async {
          events.add('unmark');
          sending = null;
        },
        read: () async {
          events.add('read $stored');
          return stored;
        },
        poll: const Duration(milliseconds: 2),
      );
      expect(token, 'tok-new');
      expect(events, ['mark', 'unmark', 'mark', 'read tok-new']);
    });

    test('a rotation waits for a send already marked, then goes', () async {
      expect(await send(), 'tok-old');
      // The app marks its rotation, then looks for a send.
      rotating = rotationMarker('s1', DateTime.now());
      var clear = false;
      final wait = waitForSendToClear(
        sending: sendNow,
        poll: const Duration(milliseconds: 2),
      ).then((v) => clear = v);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(clear, isFalse, reason: 'the send has no answer yet');
      sending = null; // the headers are in
      expect(await wait, isTrue);
    });

    test('a send that never has its answer: the rotation is told no',
        () async {
      sending = rotationMarker('s1', DateTime.now());
      expect(
        await waitForSendToClear(
          sending: sendNow,
          timeout: const Duration(milliseconds: 20),
          poll: const Duration(milliseconds: 2),
        ),
        isFalse,
      );
    });

    test("another login's send, or one from a service long gone, holds "
        'nothing', () async {
      sending = rotationMarker('s2', DateTime.now());
      expect(await waitForSendToClear(sending: sendNow), isTrue);
      sending = rotationMarker(
        's1',
        DateTime.now().subtract(kRotationPauseMax),
      );
      expect(await waitForSendToClear(sending: sendNow), isTrue);
    });

    test('no bearer: nothing is left marked', () async {
      final token = await beginSend(
        rotating: rotationNow,
        mark: () async => sending = rotationMarker('s1', DateTime.now()),
        unmark: () async => sending = null,
        read: () async => null,
      );
      expect(token, isNull);
      expect(sending, isNull);
    });
  });

  group('a refused send', () {
    test('is judged once the rotation running is over: the store still '
        'holds the token being replaced in the middle of one', () async {
      var rotating = true;
      var stored = 'tok-old';
      Future<void>.delayed(const Duration(milliseconds: 20), () {
        stored = 'tok-new';
        rotating = false;
      });
      // A raw read now would see the token that was refused.
      expect(stored, 'tok-old');
      final replaced = await refusedTokenReplaced(
        used: 'tok-old',
        settled: () => readTokenWhenSettled(
          rotating: () async => rotating,
          read: () async => stored,
          poll: const Duration(milliseconds: 2),
        ),
      );
      expect(replaced, isTrue, reason: 'connect again with the new token');
    });

    test('with the token still in use is a refusal of it', () async {
      expect(
        await refusedTokenReplaced(
          used: 'tok-old',
          settled: () async => 'tok-old',
        ),
        isFalse,
      );
      expect(
        await refusedTokenReplaced(used: 'tok-old', settled: () async => null),
        isFalse,
      );
    });
  });
}
