import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/data/db/app_database.dart';
import 'package:jackdaw/data/db/database_provider.dart';
import 'package:jackdaw/data/server/server_config.dart';

void main() {
  group('normalizeBaseUrl', () {
    test('trims whitespace and trailing slashes', () {
      expect(normalizeBaseUrl('  https://m.example.com/  '), 'https://m.example.com');
      expect(normalizeBaseUrl('https://m.example.com///'), 'https://m.example.com');
      expect(normalizeBaseUrl('https://m.example.com'), 'https://m.example.com');
    });
  });

  group('canonicalServerUrl', () {
    test('assumes https when no scheme is typed', () {
      expect(canonicalServerUrl('mantle.example.com'), 'https://mantle.example.com');
      expect(canonicalServerUrl(' mantle.example.com/ '), 'https://mantle.example.com');
    });
    test('keeps an explicit scheme', () {
      expect(canonicalServerUrl('http://10.0.0.5:3000/'), 'http://10.0.0.5:3000');
      expect(canonicalServerUrl('HTTPS://m.example.com'), 'HTTPS://m.example.com');
    });
  });

  group('serverUrlProblem', () {
    test('https anywhere is fine', () {
      expect(serverUrlProblem('https://m.example.com'), isNull);
      expect(serverUrlProblem('https://203.0.113.4:8443'), isNull);
    });
    test('http is fine only on a private network', () {
      for (final ok in [
        'http://localhost:3000',
        'http://127.0.0.1:3000',
        'http://10.1.2.3',
        'http://192.168.1.20:3000',
        'http://172.20.0.1',
        'http://brain.local',
        'http://brainbox',
        'http://[::1]:3000',
      ]) {
        expect(serverUrlProblem(ok), isNull, reason: ok);
      }
      for (final bad in [
        'http://m.example.com',
        'http://203.0.113.4',
        'http://172.32.0.1',
        'http://8.8.8.8',
      ]) {
        expect(serverUrlProblem(bad), contains('https://'), reason: bad);
      }
    });
    test('other schemes, credentials and junk are refused', () {
      expect(serverUrlProblem('ftp://m.example.com'), isNotNull);
      expect(serverUrlProblem('https://user:pw@m.example.com'), isNotNull);
      expect(serverUrlProblem('https://'), isNotNull);
      expect(serverUrlProblem('not a url'), isNotNull);
    });
  });

  test('ServerConfig defaults to null, then persists a normalized URL', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(serverConfigProvider.future), isNull);

    await container
        .read(serverConfigProvider.notifier)
        .setUrl('https://m.example.com/');

    expect(container.read(serverConfigProvider).value, 'https://m.example.com');
  });

  group('probeMantleServer', () {
    // A stand-in for one origin. `brain` serves /api/version; `clientAppFor`
    // serves only /env.js, the way the split-out owner app does.
    Future<(HttpServer, String)> serve(
      Future<void> Function(HttpRequest) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen(handler);
      return (server, 'http://127.0.0.1:${server.port}');
    }

    Future<void> Function(HttpRequest) brain() => (req) async {
      if (req.uri.path == '/api/version') {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'version': '0.224.13'}));
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    };

    Future<void> Function(HttpRequest) clientApp(String serverOrigin) => (req) async {
      if (req.uri.path == '/env.js') {
        req.response.headers.contentType = ContentType('application', 'javascript');
        req.response.write(
          'window.__MANTLE_ENV__ = '
          '${jsonEncode({'apiBase': serverOrigin, 'serverOrigin': serverOrigin, 'turnStreaming': ''})};',
        );
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    };

    test('a real brain resolves to its own (normalized) address', () async {
      final (_, url) = await serve(brain());
      final probe = await probeMantleServer('$url/');
      expect(probe, isA<ServerProbeBrain>());
      expect((probe as ServerProbeBrain).baseUrl, url);
    });

    test('the owner app resolves to the brain it advertises in /env.js', () async {
      final (_, brainUrl) = await serve(brain());
      final (_, appUrl) = await serve(clientApp(brainUrl));

      final probe = await probeMantleServer(appUrl);
      expect(probe, isA<ServerProbeClientApp>());
      expect((probe as ServerProbeClientApp).brainBaseUrl, brainUrl);
    });

    test('an advertised origin that is not a brain is not a recovery', () async {
      final (_, appUrl) = await serve(clientApp('http://127.0.0.1:1'));
      expect(await probeMantleServer(appUrl), isA<ServerProbeUnreachable>());
    });

    test('an empty serverOrigin is not a recovery', () async {
      // Empty means same-origin, where /api/version would already have
      // answered; re-probing would just hit the same dead address.
      final (_, appUrl) = await serve(clientApp(''));
      expect(await probeMantleServer(appUrl), isA<ServerProbeUnreachable>());
    });

    test('an origin pointing back at itself is not a recovery', () async {
      // Single-host installs advertise their OWN hostname (jason-prod and dev
      // both do). Without the self-check that is an infinite retry of a
      // address we have already established is not a brain.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final self = 'http://127.0.0.1:${server.port}';
      server.listen(clientApp(self));
      expect(await probeMantleServer(self), isA<ServerProbeUnreachable>());
    });

    test('a server that redirects the probe is not a brain here', () async {
      // http → https (or any 3xx): the app client never follows redirects,
      // so an address that passes only by following one would fail later.
      final (_, url) = await serve((req) async {
        req.response.statusCode = 301;
        req.response.headers.set('location', 'https://m.example.com${req.uri.path}');
        await req.response.close();
      });
      expect(await probeMantleServer(url), isA<ServerProbeUnreachable>());
    });

    test('something that is neither is unreachable', () async {
      final (_, url) = await serve((req) async {
        req.response.statusCode = 404;
        await req.response.close();
      });
      expect(await probeMantleServer(url), isA<ServerProbeUnreachable>());
    });
  });
}
