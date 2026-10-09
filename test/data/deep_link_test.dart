// A notification payload is data from the network. Only the app's own routes
// may come out of it.

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/push/deep_link.dart';

void main() {
  group('sanitizeDeepLink', () {
    test('passes the routes a push actually sends', () {
      expect(sanitizeDeepLink('/chat/saskia'), '/chat/saskia');
      expect(sanitizeDeepLink('/pending'), '/pending');
      expect(sanitizeDeepLink('/events'), '/events');
      expect(sanitizeDeepLink('/'), '/');
    });

    test('passes every other app route and trims whitespace', () {
      for (final r in [
        '/chat',
        '/pages',
        '/pages/0f1e2d3c-1234-5678-9abc-def012345678',
        '/search',
        '/files',
        '/notes',
        '/notes/abc',
        '/tasks',
        '/tasks/0f1e2d3c-1234-5678-9abc-def012345678',
        '/events/0f1e2d3c-1234-5678-9abc-def012345678',
        '/journal',
        '/settings',
        '/settings/appearance',
        '/settings/notifications',
      ]) {
        expect(sanitizeDeepLink('  $r  '), r, reason: r);
      }
    });

    test('keeps a query only on the Files routes', () {
      expect(sanitizeDeepLink('/files?path=files.work'), '/files?path=files.work');
      expect(sanitizeDeepLink('/files/image/abc?name=x.png'),
          '/files/image/abc?name=x.png');
      expect(sanitizeDeepLink('/chat/saskia?x=1'), '/chat/saskia');
      expect(sanitizeDeepLink('/pending#frag'), '/pending');
    });

    test('drops anything that is not an in-app path', () {
      expect(sanitizeDeepLink(null), isNull);
      expect(sanitizeDeepLink(''), isNull);
      expect(sanitizeDeepLink('https://evil.example/login'), isNull);
      expect(sanitizeDeepLink('//evil.example/x'), isNull);
      expect(sanitizeDeepLink('chat/saskia'), isNull);
      expect(sanitizeDeepLink('javascript:alert(1)'), isNull);
    });

    test('drops routes the app does not own, and odd slugs', () {
      expect(sanitizeDeepLink('/login'), isNull);
      expect(sanitizeDeepLink('/setup'), isNull);
      expect(sanitizeDeepLink('/splash'), isNull);
      expect(sanitizeDeepLink('/chat/a/b'), isNull);
      expect(sanitizeDeepLink('/chat/../settings'), isNull);
      expect(sanitizeDeepLink('/chat/..'), isNull);
      expect(sanitizeDeepLink('/chat/a b'), isNull);
      expect(sanitizeDeepLink('/settings/secret'), isNull);
      expect(sanitizeDeepLink('/pages/x\ny'), isNull);
      expect(sanitizeDeepLink('/pages/x%0a'), isNull);
    });
  });

  // A "waiting for approval" push: `/<workspace>?review=<id>` from a brain
  // with review in each workspace, `/team-admin?view=review&item=<id>` from
  // an older one.
  const id = '0f1e2d3c-1234-5678-9abc-def012345678';

  group('sanitizeDeepLink on review links', () {
    test('opens the workspace screen the phone has, without the id', () {
      expect(sanitizeDeepLink('/pages?review=$id'), '/pages');
      expect(sanitizeDeepLink('/notes?review=$id'), '/notes');
      expect(sanitizeDeepLink('/files?review=$id'), '/files');
      expect(sanitizeDeepLink('/files?path=files.work&review=$id'),
          '/files?path=files.work');
    });

    test('opens Home for Tables and Draw, which have no phone screen', () {
      expect(sanitizeDeepLink('/tables?review=$id'), '/');
      expect(sanitizeDeepLink('/draw?review=$id'), '/');
      expect(sanitizeDeepLink('/tables'), '/');
      expect(sanitizeDeepLink('/draw'), '/');
      expect(sanitizeDeepLink('/tables/$id'), isNull);
      expect(sanitizeDeepLink('/draw/x/y'), isNull);
    });

    test('opens Home for the old review link, and nothing else of Team admin',
        () {
      expect(sanitizeDeepLink('/team-admin?view=review&item=$id'), '/');
      expect(sanitizeDeepLink('/team-admin?view=review'), '/');
      expect(sanitizeDeepLink('/team-admin?view=requests'), isNull);
      expect(sanitizeDeepLink('/team-admin'), isNull);
    });
  });

  group('reviewLinkOf', () {
    test('reads the id and the workspace of each review link', () {
      for (final w in ['/pages', '/notes', '/files', '/tables', '/draw']) {
        expect(reviewLinkOf('$w?review=$id'), (id: id, workspace: w),
            reason: w);
      }
      expect(reviewLinkOf('  /pages?review=${id.toUpperCase()}  '),
          (id: id.toUpperCase(), workspace: '/pages'));
    });

    test('reads the old link with no workspace', () {
      expect(reviewLinkOf('/team-admin?view=review&item=$id'),
          (id: id, workspace: null));
      expect(reviewLinkOf('/team-admin?view=review'), isNull);
      expect(reviewLinkOf('/team-admin?view=requests&item=$id'), isNull);
    });

    test('takes only a UUID as the id', () {
      for (final bad in [
        '',
        'x',
        'a%20b',
        '$id-extra',
        '${id}0',
        id.substring(1),
        '../settings',
        '%2F%2Fevil.example',
        '//evil.example',
        'javascript:alert(1)',
        '$id%0a',
        '$id/x',
      ]) {
        expect(reviewLinkOf('/pages?review=$bad'), isNull, reason: bad);
        expect(reviewLinkOf('/team-admin?view=review&item=$bad'), isNull,
            reason: bad);
      }
    });

    test('takes no review id from a route that is not a workspace', () {
      expect(reviewLinkOf('/chat?review=$id'), isNull);
      expect(reviewLinkOf('/pages/$id?review=$id'), isNull);
      expect(reviewLinkOf('/settings?review=$id'), isNull);
      expect(reviewLinkOf(null), isNull);
    });

    test('refuses open-redirect and path tricks around a review link', () {
      for (final link in [
        '//evil.example/pages?review=$id',
        'https://evil.example/pages?review=$id',
        'javascript:alert(1)//pages?review=$id',
        '/pages/../settings?review=$id',
        '/pages%2F..%2Fsettings?review=$id',
        '/pages%2Fx?review=$id',
        '%2F%2Fevil.example/pages?review=$id',
        '/%2Fevil.example/pages?review=$id',
        r'/\evil.example/pages?review=' + id,
        '/pages\n?review=$id',
        'pages?review=$id',
      ]) {
        expect(reviewLinkOf(link), isNull, reason: link);
        expect(sanitizeDeepLink(link), isNull, reason: link);
      }
    });
  });

  group('reviewRoute', () {
    test('names the item on a workspace screen the phone has', () {
      expect(reviewRoute((id: id, workspace: '/pages')), '/pages?review=$id');
      expect(reviewRoute((id: id, workspace: '/notes')), '/notes?review=$id');
      expect(reviewRoute((id: id, workspace: '/files')), '/files?review=$id');
    });

    test('opens Home for Tables and Draw', () {
      expect(reviewRoute((id: id, workspace: '/tables')), '/');
      expect(reviewRoute((id: id, workspace: '/draw')), '/');
    });

    test('maps the old link by the kind the brain reports, else Home', () {
      const old = (id: id, workspace: null);
      expect(reviewRoute(old, kind: 'page'), '/pages?review=$id');
      expect(reviewRoute(old, kind: 'note'), '/notes?review=$id');
      expect(reviewRoute(old, kind: 'file'), '/files?review=$id');
      expect(reviewRoute(old, kind: 'table'), '/');
      expect(reviewRoute(old, kind: 'draw'), '/');
      expect(reviewRoute(old, kind: 'app'), '/');
      expect(reviewRoute(old), '/');
    });

    test('a link workspace wins over a reported kind', () {
      expect(reviewRoute((id: id, workspace: '/notes'), kind: 'page'),
          '/notes?review=$id');
    });

    test('what it builds passes the sanitizer as that screen', () {
      expect(sanitizeDeepLink(reviewRoute((id: id, workspace: '/pages'))),
          '/pages');
    });
  });

  test('DeepLinkRouter.offer only queues taps with an app route', () {
    final router = DeepLinkRouter.instance;
    router.pending.value = null;
    router.offer('https://evil.example/x');
    expect(router.pending.value, isNull);
    router.offer({'deepLink': '//evil.example/x', 'brainId': 'b'});
    expect(router.pending.value, isNull);
    router.offer('/pending?x=1');
    expect(router.pending.value?.route, '/pending');
    router.offer({'deepLink': '/chat/ada', 'itemLink': '/events/e1'});
    expect(router.pending.value?.route, '/events/e1');
    router.pending.value = null;
  });
}
