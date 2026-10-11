// AuthApi against a stubbed brain: device-login for every login, the frozen
// mobile-login only on a brain without it, and the refusals said plainly
// (426 update the app, 403 client-login).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/mobile_build.dart';
import 'package:jackdaw/data/auth/auth_api.dart';

import '../helpers/stub_dio.dart';

void main() {
  AuthApi apiFor(StubAdapter adapter) => AuthApi(stubDio(adapter));

  Future<SignInResult> signIn(AuthApi api) => api.signIn(
        email: 'mia@example.invalid',
        password: 'pw',
        deviceName: 'Jackdaw (Ios)',
      );

  test('a member signs in with device-login; the answer names the role',
      () async {
    final adapter = StubAdapter((o) => (
          status: 200,
          body: jsonEncode({
            'token': 'tok-m',
            'expiresIn': 2592000,
            'role': 'member',
            'loginId': 'login-m',
            'brainId': 'brain-1',
          }),
        ));
    final result = await signIn(apiFor(adapter));

    expect(adapter.requests.single.path, '/api/auth/device-login');
    expect(adapter.requests.single.data, {
      'email': 'mia@example.invalid',
      'password': 'pw',
      'deviceName': 'Jackdaw (Ios)',
    });
    expect(result.token, 'tok-m');
    expect(result.role, 'member');
    expect(result.loginId, 'login-m');
    expect(result.brainId, 'brain-1');
  });

  test('a brain without device-login (404) falls back to mobile-login',
      () async {
    final adapter = StubAdapter((o) => o.path == '/api/auth/device-login'
        ? (status: 404, body: jsonEncode({'error': 'not found'}))
        : (status: 200, body: jsonEncode({'token': 'tok-a'})));
    final result = await signIn(apiFor(adapter));

    expect(adapter.requests.map((r) => r.path),
        ['/api/auth/device-login', '/api/auth/mobile-login']);
    expect(result.token, 'tok-a');
    expect(result.role, isNull);
  });

  test('426 update-app says to update the app, with the minimum build',
      () async {
    final adapter = StubAdapter((o) => (
          status: 426,
          body: jsonEncode({
            'error': 'update the app',
            'reason': 'update-app',
            'minBuild': 27,
          }),
        ));
    await expectLater(
      signIn(apiFor(adapter)),
      throwsA(isA<AuthException>()
          .having((e) => e.updateRequired, 'updateRequired', isTrue)
          .having((e) => e.message, 'message', contains('Update Jackdaw'))
          .having((e) => e.message, 'message', contains('27'))),
    );
  });

  test('403 client-login shows the brain\'s own words', () async {
    final adapter = StubAdapter((o) => (
          status: 403,
          body: jsonEncode({
            'error': 'This login cannot use this app.',
            'reason': 'client-login',
          }),
        ));
    await expectLater(
      signIn(apiFor(adapter)),
      throwsA(isA<AuthException>()
          .having((e) => e.updateRequired, 'updateRequired', isFalse)
          .having(
              (e) => e.message, 'message', 'This login cannot use this app.')),
    );
  });

  test('a wrong password is the one plain line', () async {
    final adapter = StubAdapter((o) => (
          status: 401,
          body: jsonEncode({'error': 'Invalid email or password.'}),
        ));
    await expectLater(
      signIn(apiFor(adapter)),
      throwsA(isA<AuthException>().having(
          (e) => e.message, 'message', 'Invalid email or password.')),
    );
  });

  test('an older brain\'s 403 member-login is shown as the brain says it',
      () async {
    final adapter = StubAdapter((o) => o.path == '/api/auth/device-login'
        ? (status: 404, body: '{}')
        : (
            status: 403,
            body: jsonEncode({
              'error': 'Member logins use the web app.',
              'reason': 'member-login',
            }),
          ));
    await expectLater(
      signIn(apiFor(adapter)),
      throwsA(isA<AuthException>().having(
          (e) => e.message, 'message', 'Member logins use the web app.')),
    );
  });

  group('QR claim', () {
    test('a member\'s claim answers the bearer and who it is', () async {
      final adapter = StubAdapter((o) => (
            status: 200,
            body: jsonEncode({
              'token': 'tok-qr',
              'email': 'mia@example.invalid',
              'loginId': 'login-m',
              'brainId': 'brain-1',
            }),
          ));
      final claim = await apiFor(adapter)
          .claimPairing(code: 'c', deviceName: 'Jackdaw (Ios) · paired by QR');
      expect(claim.token, 'tok-qr');
      expect(claim.email, 'mia@example.invalid');
      expect(claim.loginId, 'login-m');
    });

    test('426 on a claim says to update the app', () async {
      final adapter = StubAdapter((o) => (
            status: 426,
            body: jsonEncode({'reason': 'update-app', 'minBuild': 27}),
          ));
      await expectLater(
        apiFor(adapter).claimPairing(code: 'c', deviceName: 'd'),
        throwsA(isA<AuthException>()
            .having((e) => e.updateRequired, 'updateRequired', isTrue)),
      );
    });

    test('any other refusal is the one generic line', () async {
      final adapter = StubAdapter((o) => (status: 401, body: '{}'));
      await expectLater(
        apiFor(adapter).claimPairing(code: 'c', deviceName: 'd'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains("didn't work"))),
      );
    });
  });

  group('the build header', () {
    tearDown(MobileBuild.debugReset);

    test('names version and build on every request it is put on', () async {
      MobileBuild.debugOverride('1.15.0+27');
      final adapter = StubAdapter((o) => (status: 200, body: '{}'));
      final dio = stubDio(adapter)..interceptors.add(MobileBuildInterceptor());
      await dio.get<void>('/api/x');
      await dio.post<void>('/api/auth/pair/claim');
      for (final r in adapter.requests) {
        expect(r.headers[kMobileBuildHeader], '1.15.0+27');
      }
    });

    test('an unreadable bundle sends no header rather than a guess', () async {
      MobileBuild.debugOverride(null);
      final adapter = StubAdapter((o) => (status: 200, body: '{}'));
      final dio = stubDio(adapter)..interceptors.add(MobileBuildInterceptor());
      await dio.get<void>('/api/x');
      expect(adapter.requests.single.headers.containsKey(kMobileBuildHeader),
          isFalse);
    });

    test('this build is 27 or newer (the brain\'s minimum for a member)', () {
      // pubspec.yaml is where the bundle's version comes from.
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      final build = int.parse(line.split('+').last.trim());
      expect(build, greaterThanOrEqualTo(27));
    });
  });
}
