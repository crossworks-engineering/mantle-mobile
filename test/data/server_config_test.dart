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

    test('something that is neither is unreachable', () async {
      final (_, url) = await serve((req) async {
        req.response.statusCode = 404;
        await req.response.close();
      });
      expect(await probeMantleServer(url), isA<ServerProbeUnreachable>());
    });
  });
}
