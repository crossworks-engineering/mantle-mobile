// A "waiting for approval" push opens its item for an admin only. The brain
// says who the login in use is (whoami); a member, a client, a brain that
// cannot say and any failure follow the ordinary route, which carries no
// review id. The brains answer through a stub adapter.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/dio_provider.dart';
import 'package:jackdaw/data/push/notification_tap.dart';
import 'package:jackdaw/routing/notification_router.dart';

import '../helpers/stub_dio.dart';

const _id = '0f1e2d3c-1234-5678-9abc-def012345678';

void main() {
  late StubAdapter adapter;
  late ProviderContainer c;
  // What the brain answers, by path.
  late Map<String, StubAnswer> answers;

  setUp(() {
    answers = {};
    adapter = StubAdapter((o) => answers[o.path] ?? (status: 404, body: '{}'));
    c = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(stubDio(adapter))],
    );
    addTearDown(c.dispose);
  });

  void role(String r) => answers['/api/auth/whoami'] = (
        status: 200,
        body: jsonEncode({'role': r, 'brainId': 'b', 'loginId': 'l'}),
      );

  Future<String?> open(String link) {
    final tap = NotificationTap(deepLink: link);
    return c.read(notificationRouterProvider).routeFor(tap, tap.route);
  }

  test('an admin opens the item on the workspace screen', () async {
    role('admin');
    expect(await open('/pages?review=$_id'), '/pages?review=$_id');
    expect(await open('/notes?review=$_id'), '/notes?review=$_id');
    expect(await open('/files?review=$_id'), '/files?review=$_id');
  });

  test('an admin opens Home for a table or a drawing', () async {
    role('admin');
    expect(await open('/tables?review=$_id'), '/');
    expect(await open('/draw?review=$_id'), '/');
  });

  test("an admin's old link goes to the workspace of the kind the brain "
      'reports', () async {
    role('admin');
    answers['/api/team-admin/submissions/$_id'] =
        (status: 200, body: jsonEncode({'id': _id, 'type': 'note'}));
    expect(await open('/team-admin?view=review&item=$_id'), '/notes?review=$_id');
  });

  test("an admin's old link opens Home when the kind is not known", () async {
    role('admin');
    // The submission route answers 404: gone, or no longer waiting.
    expect(await open('/team-admin?view=review&item=$_id'), '/');
    expect(await open('/team-admin?view=review'), '/');
  });

  test('a member or a client ignores the review id, and is never sent to the '
      'admin route', () async {
    for (final r in ['member', 'client']) {
      role(r);
      adapter.requests.clear();
      expect(await open('/pages?review=$_id'), '/pages', reason: r);
      expect(await open('/team-admin?view=review&item=$_id'), '/', reason: r);
      expect(
        adapter.requests.map((o) => o.path),
        everyElement('/api/auth/whoami'),
        reason: r,
      );
    }
  });

  test('a brain that cannot say the role gets the ordinary route', () async {
    // whoami 404: an older brain.
    expect(await open('/pages?review=$_id'), '/pages');
    answers['/api/auth/whoami'] = (status: 500, body: '{}');
    expect(await open('/notes?review=$_id'), '/notes');
  });

  test('a push with no review link asks the brain nothing', () async {
    expect(await open('/pending'), '/pending');
    expect(await open('/pages?review=not-a-uuid'), '/pages');
    expect(adapter.requests, isEmpty);
  });
}
