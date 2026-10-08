// A tapped notification: what it opens, and on which login. Every arrival
// path (the iOS channel's map, a local payload, a bare path, an event alarm)
// becomes one NotificationTap; resolveTap then picks the login.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/events/event_alarms.dart';
import 'package:jackdaw/data/push/notification_tap.dart';

const _brainA = 'brain-a';
const _brainB = 'brain-b';

HeldLogin _held(
  String id, {
  String baseUrl = 'https://a.example',
  String? brainId = _brainA,
  String? loginId,
}) =>
    (id: id, baseUrl: baseUrl, brainId: brainId, loginId: loginId);

void main() {
  group('route mapping', () {
    test('a reminder push opens the event it names, not the chat', () {
      final tap = NotificationTap.parse({
        'deepLink': '/chat/ada',
        'itemLink': '/events/0f1e2d3c-aaaa',
        'brainId': _brainA,
        'loginId': 'admin-1',
      })!;
      expect(tap.route, '/events/0f1e2d3c-aaaa');
      expect(tap.namesLogin, isTrue);
    });

    test('a task push opens that task', () {
      final tap = NotificationTap.parse({'deepLink': '/tasks', 'itemLink': '/tasks/t-9'})!;
      expect(tap.route, '/tasks/t-9');
    });

    test('an item link the app does not own falls back to the chat link', () {
      expect(
        NotificationTap.parse({'deepLink': '/chat/ada', 'itemLink': '/portal/items/x'})!
            .route,
        '/chat/ada',
      );
      expect(
        NotificationTap.parse({'deepLink': '/chat/ada', 'itemLink': '/events/../pending'})!
            .route,
        '/chat/ada',
      );
    });

    test('a push from an older brain is its deep link, on no named login', () {
      final tap = NotificationTap.parse('/pending')!;
      expect(tap.route, '/pending');
      expect(tap.namesLogin, isFalse);
    });

    test('an event alarm opens its event', () {
      final payload = EventAlarms.payloadFor(
        'evt-42',
        DateTime.utc(2026, 10, 9, 8),
        'remind',
      );
      final tap = NotificationTap.parse(payload)!;
      expect(tap.route, '/events/evt-42');
      expect(tap.namesLogin, isFalse);
    });

    test('a local payload round-trips every field', () {
      const tap = NotificationTap(
        deepLink: '/chat/ada',
        itemLink: '/events/e1',
        brainId: _brainA,
        loginId: 'admin-1',
        sessionId: 'local-1',
      );
      final back = NotificationTap.parse(tap.toPayload())!;
      expect(back.deepLink, '/chat/ada');
      expect(back.itemLink, '/events/e1');
      expect(back.brainId, _brainA);
      expect(back.loginId, 'admin-1');
      expect(back.sessionId, 'local-1');
    });

    test('nothing to route is no tap', () {
      expect(NotificationTap.parse(null), isNull);
      expect(NotificationTap.parse(''), isNull);
      expect(NotificationTap.parse('{not json'), isNull);
      expect(NotificationTap.parse({'brainId': _brainA}), isNull);
      expect(NotificationTap.parse(42), isNull);
    });

    test('a login id alone does not name a login', () {
      expect(
        NotificationTap.parse({'deepLink': '/pending', 'loginId': 'admin-1'})!
            .namesLogin,
        isFalse,
      );
    });
  });

  group('which login', () {
    const push = NotificationTap(
      deepLink: '/chat/ada',
      itemLink: '/events/e1',
      brainId: _brainA,
      loginId: 'admin-2',
    );

    test('the login in use: follow the link on it', () {
      final d = resolveTap(
        push,
        held: [_held('s1', loginId: 'admin-1'), _held('s2', loginId: 'admin-2')],
        activeId: 's2',
      );
      expect(d, isA<FollowOnActive>());
      expect((d! as FollowOnActive).route, '/events/e1');
    });

    test('another held login: switch to it first', () {
      final d = resolveTap(
        push,
        held: [_held('s1', loginId: 'admin-1'), _held('s2', loginId: 'admin-2')],
        activeId: 's1',
      );
      expect(d, isA<SwitchThenFollow>());
      expect((d! as SwitchThenFollow).sessionId, 's2');
      expect((d as SwitchThenFollow).route, '/events/e1');
    });

    test('the same login id on another brain is not a match', () {
      final d = resolveTap(
        push,
        held: [
          _held('s1', loginId: 'admin-1'),
          _held('s3', brainId: _brainB, baseUrl: 'https://b.example', loginId: 'admin-2'),
        ],
        activeId: 's1',
      );
      expect(d, isA<OpenHome>());
    });

    test('one brain id at two addresses is ambiguous: open home', () {
      final d = resolveTap(
        push,
        held: [
          _held('s1', loginId: 'admin-1'),
          _held('s2', baseUrl: 'https://copy.example', loginId: 'admin-2'),
        ],
        activeId: 's1',
      );
      expect(d, isA<OpenHome>());
    });

    test('a login whose pair is not learned yet: ask first, when allowed', () {
      final held = [_held('s1', loginId: 'admin-1'), _held('s2', brainId: null)];
      expect(resolveTap(push, held: held, activeId: 's1', canAsk: true), isNull);
      expect(
        resolveTap(push, held: held, activeId: 's1'),
        isA<OpenHome>(),
      );
    });

    test('a single held login that could not be asked keeps the old behaviour',
        () {
      final d = resolveTap(
        push,
        held: [_held('s1', brainId: null)],
        activeId: 's1',
      );
      expect(d, isA<FollowOnActive>());
    });

    test('a push that names no login opens on the login in use', () {
      final d = resolveTap(
        const NotificationTap(deepLink: '/pending'),
        held: [_held('s1', loginId: 'admin-1'), _held('s2', loginId: 'admin-2')],
        activeId: 's1',
      );
      expect(d, isA<FollowOnActive>());
      expect((d! as FollowOnActive).route, '/pending');
    });

    test('a direct-connection notification goes to its own session', () {
      const tap = NotificationTap(deepLink: '/chat/ada', sessionId: 's2');
      final held = [_held('s1'), _held('s2')];
      expect(
        (resolveTap(tap, held: held, activeId: 's1')! as SwitchThenFollow)
            .sessionId,
        's2',
      );
      expect(
        resolveTap(tap, held: [_held('s1')], activeId: 's1'),
        isA<OpenHome>(),
      );
    });
  });
}
