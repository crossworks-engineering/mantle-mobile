// The one definition of "this session is dead", shared by the app client, the
// live SSE stream and the direct-push isolate.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jackdaw/core/network/auth_failure.dart';

DioException _err(int status, {String? location}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        if (location != null) 'location': [location],
      }),
    ),
  );
}

void main() {
  group('isLoginRedirect', () {
    test('a 3xx to /login is a logout, with or without a query or host', () {
      expect(isLoginRedirect(302, '/login'), isTrue);
      expect(isLoginRedirect(307, '/login?next=%2Fpages'), isTrue);
      expect(isLoginRedirect(302, 'https://m.example.com/login'), isTrue);
    });

    test('a redirect to a page that merely contains "login" is not', () {
      expect(isLoginRedirect(302, '/pages/login-notes'), isFalse);
      expect(isLoginRedirect(302, '/n/abc?from=/login'), isFalse);
    });

    test('non-3xx codes and missing locations are not', () {
      expect(isLoginRedirect(200, '/login'), isFalse);
      expect(isLoginRedirect(401, '/login'), isFalse);
      expect(isLoginRedirect(302, null), isFalse);
      expect(isLoginRedirect(302, ''), isFalse);
    });
  });

  group('isAuthFailure', () {
    test('401 counts', () => expect(isAuthFailure(_err(401)), isTrue));
    test('redirect to /login counts',
        () => expect(isAuthFailure(_err(302, location: '/login')), isTrue));
    test('other errors do not', () {
      expect(isAuthFailure(_err(500)), isFalse);
      expect(isAuthFailure(_err(403)), isFalse);
      expect(isAuthFailure(_err(302, location: '/pages/x')), isFalse);
    });
  });
}
