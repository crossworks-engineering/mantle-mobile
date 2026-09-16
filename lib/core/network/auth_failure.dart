import 'package:dio/dio.dart';

/// Whether a response means "this session is no longer valid".
///
/// Two shapes count. A plain **401** is the JSON gate's answer to a missing or
/// revoked bearer. A **3xx whose Location path is `/login`** is what Mantle's
/// page gate does for a token that still has a valid signature but has been
/// revoked server-side (the app client never follows redirects, so it can see
/// this). The check is on the redirect's PATH, not a substring: a redirect to
/// `/pages/login-notes` is a page, not a logout.
///
/// Kept free of Riverpod so the direct-push foreground isolate can share it.
bool isLoginRedirect(int? statusCode, String? location) {
  if (statusCode == null || statusCode < 300 || statusCode >= 400) return false;
  if (location == null || location.isEmpty) return false;
  final uri = Uri.tryParse(location.trim());
  if (uri == null) return false;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return path == '/login' || path.endsWith('/login');
}

/// [isLoginRedirect] plus the 401 case, read off a Dio error.
bool isAuthFailure(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401) return true;
  return isLoginRedirect(code, e.response?.headers.value('location'));
}
