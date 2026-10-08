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
